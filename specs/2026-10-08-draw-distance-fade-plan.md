# Draw-Distance Fade Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Objects fade out across a band near `Camera3d`'s far-clip instead of popping, and a change to the effective draw distance (quality level, override, `maxDrawDistance`) eases over ~0.75s instead of snapping.

**Architecture:** `Camera3d` owns an eased *current* draw distance (driven by its own `roTimespan` from `checkMovement()`) and turns a point's forward distance into a 0-1 fade alpha across the last `drawDistanceFadeFraction` of it. Each `SceneObject` recomputes `distanceFadeAlpha` in `update()` only when its depth or the far distance changed, and applies it **only at the final draw to the canvas** (the temp-bitmap blit's rgba, or the canvas color of a direct draw) - never into a cached raster. A far-distance change no longer bumps `projectionVersion`; it only bypasses the cull latch.

**Tech Stack:** BrighterScript (`bsc`), Rooibos v6 tests run headlessly via `brs-cli` (`npm run test:ci`), `bslint`.

**Spec:** `specs/2026-10-08-draw-distance-fade-design.md`

## Global Constraints

- Branch: `feature/issue-125-draw-distance-fade` (already created from `origin/main`). Never commit to `main`.
- Defaults: `drawDistanceFadeFraction as float = 0.15`, `drawDistanceTransitionSeconds as float = 0.75`; per-frame dt for the transition clamped to `0.1` seconds.
- Fade alpha is linear: `1.0` up to `current * (1 - fraction)`, `0.0` at and beyond `current`. Fraction `<= 0` means no fading; fraction `> 1` is treated as `1`.
- The fade is never baked into a cached bitmap. `getDrawColorRGBA()`/`getOutlineDrawColorRGBA()` stay un-faded; canvas draws use the new `getCanvasDrawColorRGBA()`/`getCanvasOutlineDrawColorRGBA()`.
- `SceneObjectPlane`, `SceneObjectSkybox`, `SceneObjectParallaxLayer` opt out (always `1.0`). `Camera2d` is unaffected (base `Camera` returns `1.0`).
- Every `*.spec.bs` file holds exactly **one** `@suite` class (Rooibos v6 corrupts metadata otherwise).
- `assertEqual` is type-strict: compare float results with a tolerance helper or against float literals; packed colors as integer literals.
- Never compare two class instances or native components with `=` (runtime Type Mismatch). Compare scalar fields.
- Any file referencing another file's symbol must `import` it.
- Prefer real types; no new `as object`/`as dynamic` except test spies (which already use `m.renderer as dynamic`).
- Doc comments are for game developers; inline comments terse (1-3 sentences, the "why").
- After each task: `npm run check` (lint + validate + headless tests) must pass before committing. Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- **Existing tests broken by the default fade band:** if an existing spec unrelated to fading fails because an object now sits inside the default 15% band (alpha < 1 changes an asserted color or draw count) or exactly at the limit, set `(<renderer>.camera as BGE.Camera3d).drawDistanceFadeFraction = 0` in that test (or its suite's `beforeEach` if every test in it is affected) with a one-line comment `' fading isn't under test here`. Do not move objects or loosen assertions instead.

## Review Focus

1. **A game-set `Drawable.alpha` combined with the fade** - expect the two to multiply (alpha 128 at fade 0.5 draws at 64), not the fade replacing it. Pinned in Task 4.
2. **The target changes mid-transition** (adaptive quality steps twice quickly) - expect the distance to continue from where it is toward the new target, no jump back. Pinned in Task 2.
3. **Out-of-range `drawDistanceFadeFraction`** (`-1`, `2`) - expect `-1` to mean no fading and `2` to fade across the whole distance, never a divide-by-zero or alpha outside 0-1. Pinned in Task 2.
4. **A camera swapped in mid-game** (`game.setCamera(new BGE.Camera3d())` / `renderer.camera = cam`) - expect it to start at its full draw distance on its first frame, not ease up from zero. Pinned in Task 2.
5. **A stationary, already far-culled object as the limit grows** (camera parked, quality steps up) - expect it to reappear once inside the limit, even though neither it nor the camera moved. Pinned in Task 3.

Not unit-testable (brs-engine doesn't show it): whether real Roku hardware honors the rgba alpha on `DrawObject`/`DrawTransformedObject` blits of a temp bitmap. Task 7 checks this on a device.

---

### Task 1: `applyAlphaFade` helper

**Files:**
- Modify: `src/source/engine/renderer/RendererHelpers.bs` (append before the final `end namespace`)
- Create: `src/source/engine/renderer/AlphaFade.spec.bs`

**Interfaces:**
- Produces: `BGE.RendererHelpers.applyAlphaFade(rgba as integer, fade as float) as integer` - scales the low (alpha) byte of a packed RGBA by `fade`, rounding to nearest. `fade >= 1` returns `rgba` unchanged; `fade < 0` is treated as `0`. `-1` (Renderer's "white, no tint") is a normal packed `&hFFFFFFFF` so it fades like any other color.

- [ ] **Step 1: Write the failing test**

Create `src/source/engine/renderer/AlphaFade.spec.bs`:

```brighterscript
namespace tests

  @suite("BGE.RendererHelpers.applyAlphaFade")
  class AlphaFadeTests extends rooibos.BaseTestSuite

    @describe("applyAlphaFade")

    @it("returns the color unchanged at a fade of 1")
    function _()
      m.assertEqual(&hFF000080, BGE.RendererHelpers.applyAlphaFade(&hFF000080, 1.0))
    end function

    @it("returns the color unchanged above a fade of 1")
    function _()
      m.assertEqual(&h00FF00FF, BGE.RendererHelpers.applyAlphaFade(&h00FF00FF, 1.5))
    end function

    @it("halves the alpha byte at a fade of 0.5, rounding to nearest")
    function _()
      ' 255 * 0.5 = 127.5 -> 128
      m.assertEqual(&h00FF0080, BGE.RendererHelpers.applyAlphaFade(&h00FF00FF, 0.5))
    end function

    @it("fades the -1 'no tint' sentinel as opaque white")
    function _()
      m.assertEqual(&hFFFFFF80, BGE.RendererHelpers.applyAlphaFade(-1, 0.5))
    end function

    @it("multiplies an existing partial alpha rather than replacing it")
    function _()
      ' 128 * 0.5 = 64
      m.assertEqual(&h12345640, BGE.RendererHelpers.applyAlphaFade(&h12345680, 0.5))
    end function

    @it("clears the alpha at a fade of 0 and below")
    function _()
      m.assertEqual(&hABCDEF00, BGE.RendererHelpers.applyAlphaFade(&hABCDEFFF, 0.0))
      m.assertEqual(&hABCDEF00, BGE.RendererHelpers.applyAlphaFade(&hABCDEFFF, -0.5))
    end function

  end class

end namespace
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm run validate`
Expected: FAIL - `cannot-find-name` / unknown function `applyAlphaFade`.

- [ ] **Step 3: Write minimal implementation**

Append to `src/source/engine/renderer/RendererHelpers.bs`, inside `namespace BGE.RendererHelpers`, just before `end namespace`:

```brighterscript
  ' Scales the alpha byte of a packed RGBA color by `fade` (0-1), keeping the RGB.
  ' Used to apply a distance fade at draw time on top of whatever alpha the color
  ' already has.
  '
  ' @param {integer} rgba packed 0xRRGGBBAA color (-1 is opaque white)
  ' @param {float} fade 1 leaves the color unchanged, 0 makes it fully transparent
  ' @return {integer} the faded packed color
  function applyAlphaFade(rgba as integer, fade as float) as integer
    if fade >= 1
      return rgba
    end if
    if fade < 0
      fade = 0
    end if
    fadedAlpha = Int((rgba and &hFF) * fade + 0.5)
    return (rgba and &hFFFFFF00) or fadedAlpha
  end function
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `npm run check`
Expected: lint and validate clean; `[Rooibos Result]: PASS`.

- [ ] **Step 5: Commit**

```bash
git add src/source/engine/renderer/RendererHelpers.bs src/source/engine/renderer/AlphaFade.spec.bs
git commit -m "Add RendererHelpers.applyAlphaFade (#125)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Camera fade band and eased draw distance

**Files:**
- Modify: `src/source/engine/renderer/cameras/Camera.bs` (add three base methods after `distanceFromCameraFront`)
- Modify: `src/source/engine/renderer/cameras/Camera3d.bs` (fields near `maxDrawDistance` ~line 108-118; `checkMovement` ~line 140; `isInView` ~line 204; `projectionChangedThisFrame` ~line 637; new methods after `getEffectiveMaxDrawDistance`)
- Modify: `src/source/engine/renderer/cameras/Camera3d.spec.bs` (replace the `"maxDrawDistance and the projection version"` describe block at ~lines 129-153 and the `"bumps projectionVersion when drawDistanceScale changes"` test at ~lines 331-338)

**Interfaces:**
- Consumes: nothing new.
- Produces (on base `BGE.Camera`, overridden in `BGE.Camera3d`):
  - `function getDistanceFadeAlpha(point as BGE.Math.Vector) as float` - base returns `1.0`.
  - `function farDistanceChangedThisFrame() as boolean` - base returns `false`.
  - `function getDrawDistanceTransitionSeconds() as float` - base returns `0.0`.
- Produces (on `BGE.Camera3d` only):
  - fields `drawDistanceFadeFraction as float = 0.15`, `drawDistanceTransitionSeconds as float = 0.75`
  - `function getCurrentDrawDistance() as float`
  - `sub snapDrawDistance()`
  - `sub advanceDrawDistance(dt as float)` - public so specs can drive easing; `checkMovement()` calls it with real elapsed time.

- [ ] **Step 1: Write the failing tests**

In `src/source/engine/renderer/cameras/Camera3d.spec.bs`, add this private helper right after `beforeEach`:

```brighterscript
    ' Camera at the origin looking down -z, so a point's forward distance is just -z.
    private sub lookDownNegativeZ()
      m.camera.position = BGE.Math.VectorOps.create(0, 0, 0)
      m.camera.setTarget(BGE.Math.VectorOps.create(0, 0, -1))
    end sub

    private sub assertNear(expected as float, actual as float)
      m.assertTrue(abs(expected - actual) < 0.001, `expected ${expected} but got ${actual}`)
    end sub
```

Replace the whole `@describe("maxDrawDistance and the projection version")` block (its two tests) with:

```brighterscript
    @describe("maxDrawDistance and the projection version")

    ' The far-clip doesn't affect how points project, so a draw-distance change must not
    ' force every SceneObject to recompute its canvas geometry.
    @it("does not bump projectionVersion when maxDrawDistance changes")
    function _()
      m.camera.setFrameSize(200, 200)
      m.camera.checkMovement()
      before = m.camera.projectionVersion

      m.camera.maxDrawDistance = 250
      m.camera.checkMovement()

      m.assertEqual(before, m.camera.projectionVersion)
    end function

    @it("reports farDistanceChangedThisFrame when the draw distance moves")
    function _()
      m.camera.drawDistanceTransitionSeconds = 0
      m.camera.checkMovement()
      m.camera.checkMovement()
      m.assertFalse(m.camera.farDistanceChangedThisFrame())

      m.camera.maxDrawDistance = 250
      m.camera.checkMovement()
      m.assertTrue(m.camera.farDistanceChangedThisFrame())

      m.camera.checkMovement()
      m.assertFalse(m.camera.farDistanceChangedThisFrame())
    end function

    @it("reports farDistanceChangedThisFrame when the fade fraction changes")
    function _()
      m.camera.checkMovement()
      m.camera.checkMovement()
      m.camera.drawDistanceFadeFraction = 0.3
      m.camera.checkMovement()
      m.assertTrue(m.camera.farDistanceChangedThisFrame())
    end function
```

Replace the `@it("bumps projectionVersion when drawDistanceScale changes")` test with:

```brighterscript
    @it("does not bump projectionVersion when drawDistanceScale changes")
    function _()
      m.camera.checkMovement()
      before = m.camera.projectionVersion
      m.camera.drawDistanceScale = 0.5
      m.camera.checkMovement()
      m.assertEqual(before, m.camera.projectionVersion)
    end function
```

Then add these two new describe blocks at the end of the class (before `end class`):

```brighterscript
    @describe("getDistanceFadeAlpha")

    @it("is fully opaque before the fade band, half way through it, and clear at the limit")
    function _()
      m.lookDownNegativeZ()
      m.camera.maxDrawDistance = 500
      m.camera.drawDistanceFadeFraction = 0.5
      m.camera.checkMovement()

      ' band runs from 250 to 500
      m.assertNear(1.0, m.camera.getDistanceFadeAlpha(BGE.Math.VectorOps.create(0, 0, -100)))
      m.assertNear(1.0, m.camera.getDistanceFadeAlpha(BGE.Math.VectorOps.create(0, 0, -250)))
      m.assertNear(0.5, m.camera.getDistanceFadeAlpha(BGE.Math.VectorOps.create(0, 0, -375)))
      m.assertNear(0.0, m.camera.getDistanceFadeAlpha(BGE.Math.VectorOps.create(0, 0, -500)))
      m.assertNear(0.0, m.camera.getDistanceFadeAlpha(BGE.Math.VectorOps.create(0, 0, -800)))
    end function

    @it("fades across the last 15% by default")
    function _()
      m.lookDownNegativeZ()
      m.camera.maxDrawDistance = 400
      m.camera.checkMovement()
      ' band runs from 340 to 400
      m.assertNear(1.0, m.camera.getDistanceFadeAlpha(BGE.Math.VectorOps.create(0, 0, -340)))
      m.assertNear(0.5, m.camera.getDistanceFadeAlpha(BGE.Math.VectorOps.create(0, 0, -370)))
    end function

    @it("doesn't fade at all with a fraction of 0 or below")
    function _()
      m.lookDownNegativeZ()
      m.camera.maxDrawDistance = 500
      for each fraction in [0.0, -1.0]
        m.camera.drawDistanceFadeFraction = fraction
        m.camera.checkMovement()
        m.assertNear(1.0, m.camera.getDistanceFadeAlpha(BGE.Math.VectorOps.create(0, 0, -499)))
      end for
    end function

    @it("treats a fraction above 1 as fading across the whole distance")
    function _()
      m.lookDownNegativeZ()
      m.camera.maxDrawDistance = 500
      m.camera.drawDistanceFadeFraction = 2.0
      m.camera.checkMovement()
      m.assertNear(0.5, m.camera.getDistanceFadeAlpha(BGE.Math.VectorOps.create(0, 0, -250)))
      m.assertNear(1.0, m.camera.getDistanceFadeAlpha(BGE.Math.VectorOps.create(0, 0, 10)))
    end function

    @describe("eased draw distance")

    @it("starts at the full draw distance on the first frame instead of easing up to it")
    function _()
      m.camera.maxDrawDistance = 500
      m.camera.checkMovement()
      m.assertNear(500.0, m.camera.getCurrentDrawDistance())
    end function

    @it("eases linearly to a new target over drawDistanceTransitionSeconds")
    function _()
      m.camera.maxDrawDistance = 500
      m.camera.drawDistanceTransitionSeconds = 1.0
      m.camera.advanceDrawDistance(0)
      m.camera.maxDrawDistance = 300

      m.camera.advanceDrawDistance(0.05)
      m.camera.advanceDrawDistance(0.05)
      m.assertNear(480.0, m.camera.getCurrentDrawDistance())

      for i = 1 to 9
        m.camera.advanceDrawDistance(0.1)
      end for
      m.assertNear(300.0, m.camera.getCurrentDrawDistance())
    end function

    @it("stops exactly on the target")
    function _()
      m.camera.maxDrawDistance = 500
      m.camera.drawDistanceTransitionSeconds = 1.0
      m.camera.advanceDrawDistance(0)
      m.camera.maxDrawDistance = 300
      for i = 1 to 20
        m.camera.advanceDrawDistance(0.1)
      end for
      m.assertNear(300.0, m.camera.getCurrentDrawDistance())
      m.assertFalse(m.camera.farDistanceChangedThisFrame())
    end function

    @it("clamps one long frame so it can't finish the transition at once")
    function _()
      m.camera.maxDrawDistance = 500
      m.camera.drawDistanceTransitionSeconds = 1.0
      m.camera.advanceDrawDistance(0)
      m.camera.maxDrawDistance = 300
      m.camera.advanceDrawDistance(5.0)
      ' clamped to 0.1s -> 20 units of a 200-unit change
      m.assertNear(480.0, m.camera.getCurrentDrawDistance())
    end function

    @it("continues from where it is when the target changes mid-transition")
    function _()
      m.camera.maxDrawDistance = 500
      m.camera.drawDistanceTransitionSeconds = 1.0
      m.camera.advanceDrawDistance(0)
      m.camera.maxDrawDistance = 300
      for i = 1 to 5
        m.camera.advanceDrawDistance(0.1)
      end for
      m.assertNear(400.0, m.camera.getCurrentDrawDistance())

      m.camera.maxDrawDistance = 600
      m.camera.advanceDrawDistance(0.1)
      ' new transition: 200 units over 1s from 400
      m.assertNear(420.0, m.camera.getCurrentDrawDistance())
    end function

    @it("snaps when drawDistanceTransitionSeconds is 0")
    function _()
      m.camera.maxDrawDistance = 500
      m.camera.drawDistanceTransitionSeconds = 0
      m.camera.advanceDrawDistance(0)
      m.camera.maxDrawDistance = 300
      m.camera.advanceDrawDistance(0.01)
      m.assertNear(300.0, m.camera.getCurrentDrawDistance())
    end function

    @it("snapDrawDistance jumps straight to the target")
    function _()
      m.camera.maxDrawDistance = 500
      m.camera.drawDistanceTransitionSeconds = 1.0
      m.camera.advanceDrawDistance(0)
      m.camera.maxDrawDistance = 300
      m.camera.snapDrawDistance()
      m.assertNear(300.0, m.camera.getCurrentDrawDistance())
      m.camera.advanceDrawDistance(0.01)
      m.assertNear(300.0, m.camera.getCurrentDrawDistance())
    end function

    @it("eases a quality-scale change rather than applying it at once")
    function _()
      m.camera.maxDrawDistance = 500
      m.camera.drawDistanceTransitionSeconds = 1.0
      m.camera.advanceDrawDistance(0)
      m.camera.drawDistanceScale = 0.5
      m.camera.advanceDrawDistance(0.1)
      m.assertNear(475.0, m.camera.getCurrentDrawDistance())
      m.assertNear(250.0, m.camera.getEffectiveMaxDrawDistance())
    end function

    @it("far-clips at the current, eased distance")
    function _()
      m.lookDownNegativeZ()
      m.camera.maxDrawDistance = 500
      m.camera.drawDistanceTransitionSeconds = 1.0
      m.camera.checkMovement()
      m.camera.maxDrawDistance = 300
      m.camera.advanceDrawDistance(0.1)
      ' current is 480: a point at 450 is still in view mid-transition
      m.assertTrue(m.camera.isInView(BGE.Math.VectorOps.create(0, 0, -450)))
      m.assertFalse(m.camera.isInView(BGE.Math.VectorOps.create(0, 0, -490)))
    end function

    @it("reports its transition time through the base Camera API")
    function _()
      m.camera.drawDistanceTransitionSeconds = 0.6
      cam = m.camera as BGE.Camera
      m.assertNear(0.6, cam.getDrawDistanceTransitionSeconds())
    end function
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `npm run validate`
Expected: FAIL - unknown members `drawDistanceFadeFraction`, `advanceDrawDistance`, `getCurrentDrawDistance`, etc.

- [ ] **Step 3: Add the base `Camera` methods**

In `src/source/engine/renderer/cameras/Camera.bs`, after `distanceFromCameraFront()`:

```brighterscript
    ' How visible a point is given the draw-distance fade band, from 1 (fully visible)
    ' to 0 (at or past the draw distance). Only a 3D camera has a draw distance, so
    ' this is always 1 here.
    '
    ' @param {BGE.Math.Vector} point world position
    ' @return {float}
    function getDistanceFadeAlpha(point as BGE.Math.Vector) as float
      return 1.0
    end function

    ' Whether the draw distance or its fade band changed this frame, so every object's
    ' fade (and far-clip) needs checking again. Always false for a camera with no draw distance.
    '
    ' @return {boolean}
    function farDistanceChangedThisFrame() as boolean
      return false
    end function

    ' How long a change in draw distance takes to finish easing in, in seconds. 0 for a
    ' camera with no draw distance.
    '
    ' @return {float}
    function getDrawDistanceTransitionSeconds() as float
      return 0.0
    end function
```

- [ ] **Step 4: Implement the `Camera3d` side**

In `src/source/engine/renderer/cameras/Camera3d.bs`:

(a) Above `class Camera3d extends Camera` (inside `namespace BGE`), add:

```brighterscript
  ' Longest frame step the draw-distance transition advances by, so one slow frame
  ' can't finish a transition in a single jump.
  const MAX_DRAW_DISTANCE_TRANSITION_STEP_SECONDS = 0.1
```

(b) Replace the field `private lastEffectiveMaxDrawDistance as float = -1` (and its comment) with:

```brighterscript
    ' The far end of the draw distance over which objects fade out instead of popping
    ' out of view, as a fraction of it: 0.15 fades across the last 15%. 0 turns fading off.
    drawDistanceFadeFraction as float = 0.15

    ' Seconds a change in draw distance (a quality level change, or a new
    ' maxDrawDistance) takes to ease in, so distant objects fade in or out gradually
    ' instead of all at once. 0 applies a change immediately.
    drawDistanceTransitionSeconds as float = 0.75

    ' Eased draw distance; -1 until the first frame, which starts at the target.
    private currentDrawDistance as float = -1
    private drawDistanceTransitionTarget as float = -1
    private drawDistanceTransitionSpeed as float = 0
    private lastDrawDistanceFadeFraction as float = -1
    private farDistanceChanged as boolean = false
    private drawDistanceClock as roTimespan = invalid
```

(c) In `checkMovement()`, make the first line of the method:

```brighterscript
      m.advanceDrawDistance(m.getDrawDistanceClockSeconds())
```

(d) In `isInView()`, change the last line to:

```brighterscript
      return forwardDistance <= m.getCurrentDrawDistance()
```

(e) In `projectionChangedThisFrame()`, delete the block:

```brighterscript
      effective = m.getEffectiveMaxDrawDistance()
      if m.lastEffectiveMaxDrawDistance <> effective
        m.lastEffectiveMaxDrawDistance = effective
        changed = true
      end if
```

(f) After `getEffectiveMaxDrawDistance()`, add:

```brighterscript
    ' The draw distance actually used for clipping and fading this frame. Follows
    ' `getEffectiveMaxDrawDistance()`, easing toward it over
    ' `drawDistanceTransitionSeconds` whenever it changes.
    '
    ' @return {float}
    function getCurrentDrawDistance() as float
      if m.currentDrawDistance < 0
        return m.getEffectiveMaxDrawDistance()
      end if
      return m.currentDrawDistance
    end function

    ' Jumps straight to the target draw distance, skipping any transition in progress -
    ' e.g. after a camera cut, where easing the horizon would look odd.
    sub snapDrawDistance()
      m.currentDrawDistance = -1
    end sub

    ' Moves the current draw distance toward its target by `dt` seconds' worth of the
    ' transition. Called every frame by `checkMovement()`; only call it yourself in tests.
    '
    ' @param {float} dt elapsed seconds (clamped to 0-0.1)
    sub advanceDrawDistance(dt as float)
      if dt < 0
        dt = 0
      else if dt > MAX_DRAW_DISTANCE_TRANSITION_STEP_SECONDS
        dt = MAX_DRAW_DISTANCE_TRANSITION_STEP_SECONDS
      end if
      target = m.getEffectiveMaxDrawDistance()
      previous = m.currentDrawDistance
      if m.currentDrawDistance < 0 or m.drawDistanceTransitionSeconds <= 0
        m.currentDrawDistance = target
        m.drawDistanceTransitionTarget = target
      else if m.currentDrawDistance <> target
        if target <> m.drawDistanceTransitionTarget
          ' a new target restarts the transition from wherever it is now
          m.drawDistanceTransitionTarget = target
          m.drawDistanceTransitionSpeed = abs(target - m.currentDrawDistance) / m.drawDistanceTransitionSeconds
        end if
        stepSize = m.drawDistanceTransitionSpeed * dt
        if abs(target - m.currentDrawDistance) <= stepSize
          m.currentDrawDistance = target
        else if target > m.currentDrawDistance
          m.currentDrawDistance = m.currentDrawDistance + stepSize
        else
          m.currentDrawDistance = m.currentDrawDistance - stepSize
        end if
      end if
      fractionChanged = m.drawDistanceFadeFraction <> m.lastDrawDistanceFadeFraction
      m.lastDrawDistanceFadeFraction = m.drawDistanceFadeFraction
      m.farDistanceChanged = fractionChanged or previous <> m.currentDrawDistance
    end sub

    override function farDistanceChangedThisFrame() as boolean
      return m.farDistanceChanged
    end function

    override function getDrawDistanceTransitionSeconds() as float
      return m.drawDistanceTransitionSeconds
    end function

    ' 1 inside the draw distance, falling linearly to 0 across the last
    ' `drawDistanceFadeFraction` of it, 0 at or beyond it.
    '
    ' @param {BGE.Math.Vector} point world position
    ' @return {float}
    override function getDistanceFadeAlpha(point as BGE.Math.Vector) as float
      fraction = m.drawDistanceFadeFraction
      if fraction <= 0
        return 1.0
      end if
      if fraction > 1
        fraction = 1.0
      end if
      far = m.getCurrentDrawDistance()
      forwardDistance = BGE.Math.VectorOps.dotProduct(BGE.Math.VectorOps.subtract(point, m.position), m.orientation)
      if forwardDistance >= far
        return 0.0
      end if
      bandStart = far * (1 - fraction)
      if forwardDistance <= bandStart
        return 1.0
      end if
      return (far - forwardDistance) / (far - bandStart)
    end function

    ' Seconds since the last call, from this camera's own clock (0 on the first call).
    private function getDrawDistanceClockSeconds() as float
      if invalid = m.drawDistanceClock
        m.drawDistanceClock = CreateObject("roTimespan")
        return 0.0
      end if
      seconds = m.drawDistanceClock.TotalMilliseconds() / 1000.0
      m.drawDistanceClock.Mark()
      return seconds
    end function
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `npm run check`
Expected: PASS. If an unrelated existing spec now fails, apply the "Existing tests broken by the default fade band" rule from Global Constraints (here the most likely cause is a spec that changed `maxDrawDistance` mid-test and expected an immediate far-clip - fix that one by setting `drawDistanceTransitionSeconds = 0` on its camera, with the comment `' easing isn't under test here'`).

- [ ] **Step 6: Commit**

```bash
git add src/source/engine/renderer/cameras/
git commit -m "Camera3d: eased draw distance and a fade band near the far-clip (#125)

A draw-distance change no longer bumps projectionVersion.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: `SceneObject.distanceFadeAlpha` and the cull latch

**Files:**
- Modify: `src/source/engine/renderer/sceneObjects/SceneObject.bs` (field near `negDistanceFromCamera` ~line 154; `update()` ~line 335; `draw()` ~line 394; `isPotentiallyOnScreen()` ~line 576; new method near `participatesInOverlapDetection()` ~line 645)
- Modify: `src/source/engine/renderer/sceneObjects/SceneObjectPlane.bs`, `SceneObjectSkybox.bs`, `SceneObjectParallaxLayer.bs` (one override each)
- Create: `src/source/engine/renderer/sceneObjects/SceneObjectDistanceFade.spec.bs`

**Interfaces:**
- Consumes: `Camera.getDistanceFadeAlpha(point)`, `Camera.farDistanceChangedThisFrame()` (Task 2).
- Produces:
  - `SceneObject.distanceFadeAlpha as float = 1.0` (public, read by subclasses and specs)
  - `function participatesInDistanceFade() as boolean` (default `true`)

- [ ] **Step 1: Write the failing tests**

Create `src/source/engine/renderer/sceneObjects/SceneObjectDistanceFade.spec.bs`:

```brighterscript
namespace tests

  ' Draw-distance fading (issue #125): a Camera3d at the origin looking down -z, with a
  ' 500-unit draw distance whose last half (250-500) is the fade band, and no easing.
  @suite("BGE.SceneObject distance fade")
  class SceneObjectDistanceFadeTests extends rooibos.BaseTestSuite

    game as BGE.Game
    entity as BGE.GameEntity
    bitmap as roBitmap
    renderer as BGE.Renderer
    camera as BGE.Camera3d

    protected override function beforeEach()
      m.game = new BGE.Game(320, 240)
      m.entity = new BGE.GameEntity(m.game, {name: "TestEntity"})
      m.bitmap = CreateObject("roBitmap", {width: 200, height: 200, alphaEnable: true})
      m.camera = new BGE.Camera3d()
      m.camera.position = BGE.Math.VectorOps.create(0, 0, 0)
      m.camera.setTarget(BGE.Math.VectorOps.create(0, 0, -1))
      m.camera.maxDrawDistance = 500
      m.camera.drawDistanceFadeFraction = 0.5
      m.camera.drawDistanceTransitionSeconds = 0
      m.renderer = new BGE.Renderer(m.bitmap, m.game, m.camera)
    end function

    private function newImage(args = {} as roAssociativeArray) as BGE.Image
      sourceBitmap = CreateObject("roBitmap", {width: 64, height: 64, alphaEnable: true})
      region = CreateObject("roRegion", sourceBitmap, 0, 0, 64, 64)
      return new BGE.Image(m.entity, region, args)
    end function

    ' One Game-loop frame: camera setup then render. Returns the draw calls it took.
    private function drawFrame() as integer
      m.entity.updateTransformationMatrix()
      m.renderer.resetDrawCallCounter()
      m.renderer.setupCameraForFrame()
      m.renderer.render()
      return m.renderer.getDrawCallsLastFrame()
    end function

    private sub assertNear(expected as float, actual as float)
      m.assertTrue(abs(expected - actual) < 0.001, `expected ${expected} but got ${actual}`)
    end sub

    @describe("distanceFadeAlpha")

    @it("is 1 well inside the draw distance")
    function _()
      m.entity.position = BGE.Math.VectorOps.create(0, 0, -100)
      sceneObj = m.newImage().addToRenderer(m.renderer)
      m.drawFrame()
      m.assertNear(1.0, sceneObj.distanceFadeAlpha)
    end function

    @it("is 0.5 half way through the fade band")
    function _()
      m.entity.position = BGE.Math.VectorOps.create(0, 0, -375)
      sceneObj = m.newImage().addToRenderer(m.renderer)
      m.drawFrame()
      m.assertNear(0.5, sceneObj.distanceFadeAlpha)
    end function

    @it("follows a change to the draw distance even though nothing moved")
    function _()
      m.entity.position = BGE.Math.VectorOps.create(0, 0, -375)
      sceneObj = m.newImage().addToRenderer(m.renderer)
      m.drawFrame()
      m.drawFrame()
      m.camera.maxDrawDistance = 750
      m.drawFrame()
      ' band now 375-750: right at its start
      m.assertNear(1.0, sceneObj.distanceFadeAlpha)
    end function

    @describe("fully faded objects")

    @it("draws nothing and counts as culled at the limit")
    function _()
      m.entity.position = BGE.Math.VectorOps.create(0, 0, -500)
      sceneObj = m.newImage().addToRenderer(m.renderer)
      m.drawFrame()
      m.assertEqual(0, m.drawFrame())
      m.assertTrue(sceneObj.isCulled())
    end function

    @it("reappears once the limit grows past a stationary, already culled object")
    function _()
      m.entity.position = BGE.Math.VectorOps.create(0, 0, -600)
      sceneObj = m.newImage().addToRenderer(m.renderer)
      m.drawFrame()
      m.drawFrame()
      m.assertTrue(sceneObj.isCulled())

      m.camera.maxDrawDistance = 900
      m.assertTrue(m.drawFrame() > 0)
      m.assertFalse(sceneObj.isCulled())
    end function

    @describe("types without a single distance")

    @it("leaves a ground plane unfaded")
    function _()
      bmp = CreateObject("roBitmap", {width: 8, height: 8, AlphaEnable: true})
      region = CreateObject("roRegion", bmp, 0, 0, 8, 8)
      plane = new BGE.DrawablePlane(m.entity, region, {normal: {x: 0, y: 1, z: 0}, point: {x: 0, y: 0, z: -2000}})
      sceneObj = plane.addToRenderer(m.renderer)
      m.drawFrame()
      m.assertFalse(sceneObj.participatesInDistanceFade())
      m.assertNear(1.0, sceneObj.distanceFadeAlpha)
    end function

  end class

end namespace
```

> If `Drawable.addToRenderer()` is declared to return a type without `distanceFadeAlpha`/`isCulled()` (it should return the `SceneObject`), cast: `sceneObj = m.newImage().addToRenderer(m.renderer) as BGE.SceneObject`. Check its declaration in `src/source/engine/drawables/Drawable.bs` first.

- [ ] **Step 2: Run tests to verify they fail**

Run: `npm run validate`
Expected: FAIL - `distanceFadeAlpha` / `participatesInDistanceFade` unknown.

- [ ] **Step 3: Implement**

In `SceneObject.bs`:

(a) After the `negDistanceFromCamera as float = 0` field:

```brighterscript
    ' How faded this object is by the camera's draw-distance fade band, from 1 (fully
    ' visible) to 0 (at or past the draw distance). Applied on top of `Drawable.alpha`.
    distanceFadeAlpha as float = 1.0
```

(b) In `update()`, immediately after the `if m.depthChangedThisFrame ... end if` block and before `m.wasEnabledLastFrame = m.isEnabled()`:

```brighterscript
      if m.participatesInDistanceFade() and (m.depthChangedThisFrame or cameraObj.farDistanceChangedThisFrame())
        m.distanceFadeAlpha = cameraObj.getDistanceFadeAlpha(m.depthPosition)
      end if
```

(c) In `draw()`, change the `enteredDrawPath` line to:

```brighterscript
      ' A fully faded object is treated exactly like a frustum cull.
      enteredDrawPath = m.distanceFadeAlpha > 0 and (modeChanged or projectionChanged or m.isPotentiallyOnScreen(rendererObj.camera))
```

(d) In `isPotentiallyOnScreen()`, change the shortcut condition to:

```brighterscript
      if not m.objMovedInRelationToCamera(cameraObj) and not m.geometryChanged() and not cameraObj.farDistanceChangedThisFrame()
```

and add to the end of that method's doc comment block (before the `' @param` line):

```brighterscript
    ' A draw-distance change also re-runs the check, so a stationary object comes back
    ' into view as the limit grows past it.
```

(e) Next to `participatesInOverlapDetection()`:

```brighterscript
    ' Whether this object fades out near a 3D camera's draw distance. Fading uses the
    ' object's depth position, the same point depth sorting uses. Override to return
    ' false for a type with no single meaningful distance.
    '
    ' @return {boolean}
    function participatesInDistanceFade() as boolean
      return true
    end function
```

In each of `SceneObjectPlane.bs`, `SceneObjectSkybox.bs`, `SceneObjectParallaxLayer.bs`, add inside the class:

```brighterscript
    ' Has no single distance from the camera, so it never fades.
    override function participatesInDistanceFade() as boolean
      return false
    end function
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `npm run check`
Expected: PASS. Apply the Global Constraints rule to any unrelated spec the default band breaks.

- [ ] **Step 5: Commit**

```bash
git add src/source/engine/renderer/sceneObjects/
git commit -m "SceneObject: per-object draw-distance fade alpha (#125)

Fully faded objects count as culled, and a draw-distance change
re-checks latched culls.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Apply the fade at the final draw

**Files:**
- Modify: `src/source/engine/renderer/sceneObjects/SceneObjectBillboard.bs` (`performDraw` temp-bitmap blits ~lines 97, 113, 123; `drawFastPath` ~232; `drawToCanvas` ~328 and ~352; `drawOutlineToCanvas` ~443; new getters after `getOutlineDrawColorRGBA` ~555)
- Modify: `src/source/engine/renderer/sceneObjects/SceneObjectRectangle.bs` (`drawToCanvas` ~128, `drawOutlineToCanvas` ~142 - **not** `drawToTempBitmap` ~81)
- Modify: `src/source/engine/renderer/sceneObjects/SceneObjectPolygon.bs` (`drawToCanvas` ~32/34 - **not** `drawToTempBitmap` ~63/65)
- Modify: `src/source/engine/renderer/sceneObjects/SceneObjectLine.bs` (`performDraw`; add `import "../RendererHelpers.bs"`)
- Modify: `src/source/engine/renderer/sceneObjects/SceneObjectModel.bs` (`drawFaceToCanvas` ~105)
- Modify: `src/source/engine/renderer/sceneObjects/SceneObjectParticle.bs` (`performDraw` ~72; add `import "../RendererHelpers.bs"`)
- Modify: `src/source/engine/renderer/sceneObjects/SceneObjectDistanceFade.spec.bs` (add tests)

**Interfaces:**
- Consumes: `BGE.RendererHelpers.applyAlphaFade` (Task 1), `SceneObject.distanceFadeAlpha` (Task 3).
- Produces: `protected function getCanvasDrawColorRGBA(rendererObj as BGE.Renderer) as integer` and `protected function getCanvasOutlineDrawColorRGBA(rendererObj as BGE.Renderer) as integer` on `SceneObjectBillboard`.

- [ ] **Step 1: Write the failing tests**

Append to `SceneObjectDistanceFade.spec.bs`, before `end class`. Every test compares a faded frame against an unfaded one, so shading/tint details don't matter:

```brighterscript
    ' Replaces `methodName` on the renderer with a spy that records each call's rgba
    ' into `spy.rgbaCalls` and returns true without drawing.
    private function spyOnRgba(methodName as string) as dynamic
      spy = m.renderer as dynamic
      spy.rgbaCalls = []
      if methodName = "drawRegionTo"
        spy.drawRegionTo = function(canvasDrawTo as object, regionToDraw as object, x as float, y as float, scaleX = 1 as float, scaleY = 1 as float, rotation = 0 as float, rgba = -1 as integer) as boolean
          m.rgbaCalls.push(rgba)
          return true
        end function
      else if methodName = "drawObjectTo"
        spy.drawObjectTo = function(draw2d as object, x as integer, y as integer, src as object, rgba = -1 as integer) as boolean
          m.rgbaCalls.push(rgba)
          return true
        end function
      else if methodName = "drawLineTo"
        spy.drawLineTo = function(draw2d as object, x as float, y as float, endX as float, endY as float, rgba as integer) as boolean
          m.rgbaCalls.push(rgba)
          return true
        end function
      else if methodName = "drawRectangleTo"
        spy.drawRectangleTo = function(draw2d as object, x as float, y as float, width as float, height as float, rgba as integer) as boolean
          m.rgbaCalls.push(rgba)
          return true
        end function
      end if
      return spy
    end function

    ' The alpha byte of the last rgba the spy recorded.
    private function lastAlpha(spy as dynamic) as integer
      m.assertTrue(spy.rgbaCalls.count() > 0, "expected at least one recorded draw")
      return spy.rgbaCalls[spy.rgbaCalls.count() - 1] and &hFF
    end function

    ' Draws two frames with fading off, records the alpha, then turns the band on
    ' (object at 375 -> fade 0.5) and records the alpha of the next frame.
    private function alphaBeforeAndAfterFade(spy as dynamic) as integer[]
      m.camera.drawDistanceFadeFraction = 0
      m.drawFrame()
      m.drawFrame()
      before = m.lastAlpha(spy)
      m.camera.drawDistanceFadeFraction = 0.5
      m.drawFrame()
      return [before, m.lastAlpha(spy)]
    end function

    @describe("applying the fade at draw time")

    @it("fades an image drawn directly to the canvas")
    function _()
      m.entity.position = BGE.Math.VectorOps.create(0, 0, -375)
      spy = m.spyOnRgba("drawRegionTo")
      m.newImage().addToRenderer(m.renderer)
      alphas = m.alphaBeforeAndAfterFade(spy)
      m.assertEqual(255, alphas[0])
      m.assertEqual(128, alphas[1])
    end function

    @it("multiplies a game-set Drawable.alpha rather than replacing it")
    function _()
      m.entity.position = BGE.Math.VectorOps.create(0, 0, -375)
      spy = m.spyOnRgba("drawRegionTo")
      m.newImage({alpha: 128}).addToRenderer(m.renderer)
      alphas = m.alphaBeforeAndAfterFade(spy)
      m.assertEqual(128, alphas[0])
      m.assertEqual(64, alphas[1])
    end function

    @it("fades a cached temp bitmap's blit")
    function _()
      m.entity.position = BGE.Math.VectorOps.create(0, 0, -375)
      spy = m.spyOnRgba("drawObjectTo")
      rect = new BGE.DrawableRectangle(m.entity, 40, 40, {color: BGE.ColorsRGB.Red})
      rect.addToRenderer(m.renderer)
      alphas = m.alphaBeforeAndAfterFade(spy)
      m.assertEqual(255, alphas[0])
      m.assertEqual(128, alphas[1])
    end function

    @it("reuses the cached temp bitmap while only the fade changes")
    function _()
      m.entity.position = BGE.Math.VectorOps.create(0, 0, -375)
      rect = new BGE.DrawableRectangle(m.entity, 40, 40, {color: BGE.ColorsRGB.Red})
      rect.addToRenderer(m.renderer)
      m.drawFrame()
      m.drawFrame()
      ' baseline: a frame with nothing changed is just the blit
      m.assertEqual(1, m.drawFrame())

      m.camera.maxDrawDistance = 450
      ' still one blit - no re-rasterizing for a fade change
      m.assertEqual(1, m.drawFrame())
    end function

    @it("fades a line")
    function _()
      spy = m.spyOnRgba("drawLineTo")
      line = new BGE.DrawableLine(m.entity, BGE.Math.VectorOps.create(-10, 0, -375), BGE.Math.VectorOps.create(10, 0, -375), {color: BGE.ColorsRGB.White})
      line.addToRenderer(m.renderer)
      alphas = m.alphaBeforeAndAfterFade(spy)
      m.assertEqual(255, alphas[0])
      m.assertEqual(128, alphas[1])
    end function

    @it("fades particles by their emitter's distance")
    function _()
      m.entity.position = BGE.Math.VectorOps.create(0, 0, -375)
      spy = m.spyOnRgba("drawRectangleTo")
      emitter = new BGE.DrawableParticles(m.entity, BGE.ParticleShape.Rectangle, {lifetime: 100})
      emitter.addToRenderer(m.renderer)
      m.entity.updateTransformationMatrix()
      emitter.burst(1)
      alphas = m.alphaBeforeAndAfterFade(spy)
      m.assertEqual(Int(alphas[0] * 0.5 + 0.5), alphas[1])
    end function
```

> If a `DrawableRectangle`/`DrawableLine` constructor rejects the `color` arg key, check `src/source/engine/drawables/DrawableRectangle.bs`/`DrawableLine.bs`'s `new()` for the args it reads and use that key. If the "reuses the cached temp bitmap" baseline isn't exactly 1 draw call, read `SceneObjectBillboard.performDraw()` to see what else is drawn and assert that the count is **unchanged** between the two frames instead (the point is no extra raster calls).

- [ ] **Step 2: Run tests to verify they fail**

Run: `npm run check`
Expected: the new "applying the fade at draw time" tests FAIL (faded alpha still 255/128), everything else PASS.

- [ ] **Step 3: Implement**

`SceneObjectBillboard.bs`:

(a) After `getOutlineDrawColorRGBA()`:

```brighterscript
    ' The fill color for a draw straight to the canvas: getDrawColorRGBA() with this
    ' object's draw-distance fade applied. Never use this for a temp-bitmap raster -
    ' the fade belongs on the blit, or the cached bitmap would have to be redrawn
    ' every frame the fade changes.
    '
    ' @param {BGE.Renderer} rendererObj
    ' @return {integer} packed RGBA color
    protected function getCanvasDrawColorRGBA(rendererObj as BGE.Renderer) as integer
      return BGE.RendererHelpers.applyAlphaFade(m.getDrawColorRGBA(rendererObj), m.distanceFadeAlpha)
    end function

    ' The outline color for a draw straight to the canvas, faded like getCanvasDrawColorRGBA().
    '
    ' @param {BGE.Renderer} rendererObj
    ' @return {integer} packed RGBA color
    protected function getCanvasOutlineDrawColorRGBA(rendererObj as BGE.Renderer) as integer
      return BGE.RendererHelpers.applyAlphaFade(m.getOutlineDrawColorRGBA(rendererObj), m.distanceFadeAlpha)
    end function
```

(b) In `performDraw()`, right after `m.captureFastDrawTolerances(rendererObj)` at its top:

```brighterscript
      ' The cached temp bitmap never includes the distance fade; it's applied to the blit.
      blitColor = BGE.RendererHelpers.applyAlphaFade(-1, m.distanceFadeAlpha)
```

and pass `blitColor` as the final argument of its three temp-bitmap blits:

```brighterscript
            retVal = rendererObj.drawTransformedObject(transformDetails.origin.x, transformDetails.origin.y, transformDetails.scaleX, transformDetails.scaleY, transformDetails.rotation, m.tempBitmapRegion, blitColor)
```
```brighterscript
              retVal = rendererObj.drawObject(canvasBounds[0].x, canvasBounds[0].y, m.tempBitmapRegion, blitColor)
```
```brighterscript
        retVal = rendererObj.drawObject(canvasBounds[0].x, canvasBounds[0].y, m.tempBitmapRegion, blitColor)
```

(c) Switch the canvas call sites (leave `drawToTempBitmap()`'s `m.getDrawColorRGBA(rendererObj)` alone):
- `drawFastPath()`: `color = m.getCanvasDrawColorRGBA(rendererObj)`
- `drawToCanvas()`: `color = m.getCanvasDrawColorRGBA(rendererObj)` and the wireFrame branch's `m.getOutlineDrawColorRGBA(rendererObj)` -> `m.getCanvasOutlineDrawColorRGBA(rendererObj)`
- `drawOutlineToCanvas()`: `m.getOutlineDrawColorRGBA(rendererObj)` -> `m.getCanvasOutlineDrawColorRGBA(rendererObj)`

`SceneObjectRectangle.bs` - in `drawToCanvas()` `fillColor = m.getCanvasDrawColorRGBA(rendererObj)`; in `drawOutlineToCanvas()` `outlineColor = m.getCanvasOutlineDrawColorRGBA(rendererObj)`. Leave `drawToTempBitmap()` and `didRegionToDrawChange()` alone.

`SceneObjectPolygon.bs` - in `drawToCanvas()` only: `m.getOutlineDrawColorRGBA(rendererObj)` -> `m.getCanvasOutlineDrawColorRGBA(rendererObj)` and `m.getDrawColorRGBA(rendererObj)` -> `m.getCanvasDrawColorRGBA(rendererObj)`.

`SceneObjectLine.bs` - add `import "../RendererHelpers.bs"`; in `performDraw()`:

```brighterscript
        rgba = BGE.RendererHelpers.applyAlphaFade(m.drawable.getFillColorRGBA(), m.distanceFadeAlpha)
        return rendererObj.drawLine(m.canvasStart.x, m.canvasStart.y, m.canvasEnd.x, m.canvasEnd.y, rgba)
```

`SceneObjectModel.bs` - in `drawFaceToCanvas()` (only ever draws to the live canvas):

```brighterscript
      shadedColor = BGE.RendererHelpers.applyAlphaFade(BGE.colorBrightness(face.color, face.brightness), m.distanceFadeAlpha)
```

`SceneObjectParticle.bs` - add `import "../RendererHelpers.bs"`; in `performDraw()` after the `rgba = BGE.RGBAtoRGBA(...)` line:

```brighterscript
        rgba = BGE.RendererHelpers.applyAlphaFade(rgba, m.distanceFadeAlpha)
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `npm run check`
Expected: PASS. Apply the Global Constraints rule to any unrelated spec the default band breaks.

- [ ] **Step 5: Commit**

```bash
git add src/source/engine/renderer/sceneObjects/
git commit -m "Apply the draw-distance fade at the final draw, not the cached raster (#125)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Adaptive quality settle covers the transition

**Files:**
- Modify: `src/source/engine/quality/QualityController.bs` (`notifyLevelChanged()` ~line 179, `resetWindow()` ~line 188)
- Modify: `src/source/engine/quality/RenderQualityManager.bs` (`setLevel()` ~line 45)
- Modify: `src/source/engine/quality/QualityController.spec.bs` (add to the `"ignored frames"` describe)
- Modify: `src/source/engine/quality/RenderQualityManager.spec.bs` (one test)

**Interfaces:**
- Consumes: `Camera.getDrawDistanceTransitionSeconds()` (Task 2).
- Produces: `sub notifyLevelChanged(extraSettleSeconds = 0.0 as float)` on `BGE.QualityController`.

- [ ] **Step 1: Write the failing tests**

In `QualityController.spec.bs`, after `"ignores slow frames during the settle period after a scene change"`:

```brighterscript
    @it("extends the settle after a level change to cover a longer draw-distance transition")
    function _()
      c = new BGE.QualityController({targetFps: 30, stepUpSustainSeconds: 5.0, windowSeconds: 2.0, settleSeconds: 0.25, stepDownCooldownSeconds: 2.0, probeFailWindowSeconds: 4.0, probeBackoffSeconds: 30, stepUpJumpFraction: 0})
      level = m.simulate(c, BGE.RenderQualityLevel.medium, 30, 3)
      c.notifyLevelChanged(0.75)
      ' 0.7s of 10fps: past the 0.25s settle but inside the 0.75s transition
      for i = 1 to 7
        level = c.update(0.1, level)
      end for
      m.assertEqual(BGE.RenderQualityLevel.medium, level)
    end function

    @it("keeps its own settle when it is longer than the transition")
    function _()
      c = new BGE.QualityController({targetFps: 30, stepUpSustainSeconds: 5.0, windowSeconds: 2.0, settleSeconds: 0.5, stepDownCooldownSeconds: 2.0, probeFailWindowSeconds: 4.0, probeBackoffSeconds: 30, stepUpJumpFraction: 0})
      level = m.simulate(c, BGE.RenderQualityLevel.medium, 30, 3)
      c.notifyLevelChanged(0.1)
      level = m.simulate(c, level, 10, 0.4)
      level = m.simulate(c, level, 30, 2)
      m.assertEqual(BGE.RenderQualityLevel.medium, level)
    end function
```

In `RenderQualityManager.spec.bs`, read its `beforeEach` first, then add (adapting the renderer variable name to the one the suite uses):

```brighterscript
    @it("setLevel holds adaptive tuning off for the camera's draw-distance transition")
    function _()
      cam = new BGE.Camera3d()
      cam.drawDistanceTransitionSeconds = 0.75
      m.renderer.camera = cam
      manager = new BGE.RenderQualityManager(m.renderer, BGE.RenderQualityLevel.medium)
      manager.enableAdaptive({targetFps: 30, settleSeconds: 0.25, stepDownCooldownSeconds: 0.1})
      for i = 1 to 60
        manager.update(1.0 / 30)
      end for
      manager.setLevel(BGE.RenderQualityLevel.low)
      ' 0.6s of 10fps right after the change: inside the transition, so no further drop
      for i = 1 to 6
        manager.update(0.1)
      end for
      m.assertEqual(BGE.RenderQualityLevel.low, manager.getLevel())
    end function
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `npm run validate` then `npm run test:ci`
Expected: validate FAILS on `notifyLevelChanged(0.75)` (too many args), or, once that compiles, the two "extends"/"holds" tests FAIL by dropping a level.

- [ ] **Step 3: Implement**

`QualityController.bs`:

```brighterscript
    ' Call after a new level has been applied: clears the average and waits out the
    ' settle period so one-off rebuild costs don't count against the new level.
    '
    ' @param {float} [extraSettleSeconds=0] a longer settle to use if it exceeds the
    '   configured one - e.g. while the camera's draw distance eases to the new level
    sub notifyLevelChanged(extraSettleSeconds = 0.0 as float)
      m.resetWindow()
      if extraSettleSeconds > m.settleRemaining
        m.settleRemaining = extraSettleSeconds
      end if
    end sub
```

`RenderQualityManager.setLevel()`:

```brighterscript
      if invalid <> m.controller
        ' the draw distance eases to the new level, so wait for it before judging fps
        m.controller.notifyLevelChanged(m.renderer.camera.getDrawDistanceTransitionSeconds())
      end if
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `npm run check`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/source/engine/quality/
git commit -m "Adaptive quality waits out the draw-distance transition after a level change (#125)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Docs

**Files:**
- Modify: `CLAUDE.md` (the `Camera3d.maxDrawDistance` bullet, ~line 125, and the `Render quality` bullet's level-change sentence)
- Modify: `docs/drawables-and-scene-objects.md` (new `## Draw-distance fade` section after `## SceneObjectDrawMode`, before `## How \`Renderer.render()\` actually draws a frame`)

- [ ] **Step 1: Update CLAUDE.md**

In the `Camera3d.maxDrawDistance` bullet, after the sentence ending `...treated as out of view everywhere in the renderer.`, insert:

```markdown
That effective value is the *target*: `Camera3d.getCurrentDrawDistance()` eases toward it over `drawDistanceTransitionSeconds` (default 0.75s, driven by the camera's own `roTimespan` in `checkMovement()`, per-frame step clamped to 0.1s; first frame and `snapDrawDistance()` start at the target), and that current value is what `isInView` clips at. Objects fade out across the last `drawDistanceFadeFraction` (default 0.15, 0 = off) of it (issue #125): `SceneObject.update()` sets `distanceFadeAlpha` from `Camera.getDistanceFadeAlpha(depthPosition)` when depth or `farDistanceChangedThisFrame()` changed, alpha 0 counts as a cull, and the fade is applied only at the final draw (the temp-bitmap blit's rgba, or `SceneObjectBillboard.getCanvasDrawColorRGBA()`/`getCanvasOutlineDrawColorRGBA()` for direct draws) - never baked into a cached raster, so `getDrawColorRGBA()` stays un-faded for raster paths. A draw-distance change does **not** bump `projectionVersion` (projection doesn't depend on it); `farDistanceChangedThisFrame()` only bypasses `isPotentiallyOnScreen()`'s cull latch. Planes, skyboxes and parallax layers opt out via `participatesInDistanceFade()`.
```

In the `Render quality` bullet, after `Level changes call \`onQualityChanged(level)\` on entities, the scene and \`gameUi\` (which forwards it to its children).`, insert:

```markdown
`RenderQualityManager.setLevel()` passes the camera's `getDrawDistanceTransitionSeconds()` to `QualityController.notifyLevelChanged()`, extending the settle so the controller doesn't judge a level while its draw distance is still easing in.
```

- [ ] **Step 2: Add the guide section**

In `docs/drawables-and-scene-objects.md`, add:

````markdown
## Draw-distance fade

With a `Camera3d`, nothing past the camera's draw distance is drawn. Instead of popping
out of view at that limit, objects fade out across the far end of it:

```brighterscript
camera = new BGE.Camera3d()
camera.maxDrawDistance = 1000
' fade across the last 20% (800-1000) instead of the default 15%
camera.drawDistanceFadeFraction = 0.2
game.setCamera(camera)
```

Set `drawDistanceFadeFraction = 0` for a hard cut-off. The fade multiplies whatever
`Drawable.alpha` you've set, so an image at alpha 128 halfway through the band draws at 64.

When the draw distance changes - a new render quality level, or your game changing
`maxDrawDistance` - the camera eases to the new distance over
`drawDistanceTransitionSeconds` (default 0.75), so distant objects fade in or out
gradually. Call `camera.snapDrawDistance()` after a camera cut to skip the transition.

Ground planes, skyboxes and parallax layers don't fade: they have no single distance from
the camera. An object fades by its depth position (its centre for a billboard), so a large
object whose centre is past the limit disappears even if its near edge is inside it.
````

- [ ] **Step 3: Verify the docs build**

Run: `npm run docs`
Expected: completes without errors.

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md docs/drawables-and-scene-objects.md
git commit -m "Document the draw-distance fade (#125)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: On-device verification

No code unless a check fails. Use the `rokubot-examples` skill for sideloading/launching/screenshots. Don't try to fly the camera in real time with rokubot - ask the user to play and report.

- [ ] **Step 1: Full gate**

Run: `npm run check:all`
Expected: PASS, every example validates.

- [ ] **Step 2: `examples/terrain` on a real Roku**

Build and sideload `examples/terrain` (`npm run build-examples` or `cd examples/terrain && npm run build`). Ask the user to:
- fly toward and away from the trees and confirm they fade in/out at the horizon rather than popping,
- toggle the debug overlay, note FPS, and report it.

Screenshot with a tree mid-band and check it is visibly translucent. **This is the check that real hardware honors the rgba alpha on `DrawObject`/`DrawTransformedObject` blits of a temp bitmap.** If an oriented-mode tree in the band draws fully opaque on hardware (while working headless), change `SceneObjectBillboard.performDraw()`'s two `drawObject(...)` blits so that when `m.distanceFadeAlpha < 1` they call `rendererObj.drawTransformedObject(canvasBounds[0].x, canvasBounds[0].y, 1, 1, 0, m.tempBitmapRegion, blitColor)` instead (`DrawTransformedObject` is known to honor rgba - issue #197), add a comment saying why, rerun `npm run check`, and commit.

- [ ] **Step 3: FPS cost of the band**

Temporarily set `drawDistanceFadeFraction = 0` on the terrain camera (local edit, don't commit), sideload, and have the user compare FPS at the same spot. Report both numbers in the PR. If the band costs more than ~2 fps, raise it with the user before shipping rather than changing defaults unilaterally.

- [ ] **Step 4: Quality transitions**

With adaptive quality on in terrain (or force levels via the example's debug controls, if present), have the user confirm that a level change sweeps the tree line in/out over under a second instead of popping, and that adaptive quality doesn't drop two levels in a row right after a step down.

- [ ] **Step 5: Static BSP and other 3D examples**

Sideload `examples/collisions3d` and `examples/3d`; screenshot each and confirm walls/balls/models render as before.

- [ ] **Step 6: Open the PR**

Use the `pr-voice` skill for the description; include the FPS numbers from Step 3 and link issue #125 (`Closes #125`). Push the branch with an explicit refspec (`git push -u origin feature/issue-125-draw-distance-fade:feature/issue-125-draw-distance-fade`) and open the PR against `main`.
