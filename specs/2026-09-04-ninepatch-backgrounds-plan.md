# 9-Patch / Image-Backed Widget Backgrounds Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let `Theme.backgroundColor`'s flat fill be replaced with a stretchable 9-patch image background, without breaking any existing flat-color widget.

**Architecture:** A new standalone `BGE.UI.NinePatchImage` class pre-slices a source `roRegion` into 9 sub-regions once at construction, then blits all 9 (4 fixed corners, 4 stretched edges, 1 stretched center) via existing `Renderer.drawObjectTo`/`drawScaledObjectTo` calls. `Theme.backgroundImage` (default `invalid`) opts a container/widget in; every widget's `draw()` gains one `if theme.backgroundImage <> invalid` branch ahead of its existing flat-fill call, which stays untouched.

**Tech Stack:** BrighterScript, Rooibos, native `roRegion`/`ifDraw2d`.

**Spec:** `specs/2026-09-04-ui-followups-design.md` (section 2). Depends on `examples/ui` existing — run this plan after `specs/2026-09-04-analog-cursor-plan.md` (Task 1 scaffolds it).

## Global Constraints

- One `@suite` class per `*.spec.bs` file.
- `assertEqual` is type-strict — Integer vs Float mismatches are the most common test-writing mistake here.
- Compare a stable scalar (e.g. region width/height), never two `roRegion`/`roBitmap` instances with `=` — that's a runtime `Type Mismatch` crash, not a compile error (CLAUDE.md).
- `npm run validate` after engine changes; `npm run check` before done.
- New public methods get JSDoc-style `'` doc comments.

---

### Task 1: `NinePatchImage` class — construction and slicing

**Files:**
- Create: `src/source/engine/ui/NinePatchImage.bs`
- Test: `src/source/engine/ui/NinePatchImage.spec.bs`

**Interfaces:**
- Produces: `BGE.UI.NinePatchImage.new(sourceRegion as roRegion, left as integer, top as integer, right as integer, bottom as integer)`, with 9 protected sliced sub-region fields consumed by Task 2's `draw()`.

- [ ] **Step 1: Write the failing test — slices have correct dimensions**

```brightscript
' src/source/engine/ui/NinePatchImage.spec.bs
import "pkg:/source/engine/ui/NinePatchImage.bs"

namespace tests
  @suite("NinePatchImage")
  class NinePatchImageTest extends BaseTestSuite

    @beforeEach
    sub before()
      m.bmp = CreateObject("roBitmap", {width: 30, height: 30, AlphaEnable: true})
      m.bmp.Clear(&hFFFFFFFF)
      m.region = CreateObject("roRegion", m.bmp, 0, 0, 30, 30)
    end sub

    @it("computes corner slice dimensions from the insets")
    function _()
      np = new BGE.UI.NinePatchImage(m.region, 8, 8, 8, 8)
      m.assertEqual(8, np.getTopLeft().GetWidth())
      m.assertEqual(8, np.getTopLeft().GetHeight())
    end function

    @it("computes center slice dimensions as source minus all insets")
    function _()
      np = new BGE.UI.NinePatchImage(m.region, 8, 8, 8, 8)
      m.assertEqual(14, np.getCenter().GetWidth()) ' 30 - 8 - 8
      m.assertEqual(14, np.getCenter().GetHeight())
    end function

  end class
end namespace
```

`getTopLeft()`/`getCenter()` are small test-only accessors (or make the 9 slice fields `public`/no access modifier rather than `protected`, matching whichever pattern lets the spec verify them without excess indirection — check how other engine classes with internal-but-testable state handle this, e.g. `Renderer.resources`, and follow the same convention).

- [ ] **Step 2: Run test to verify it fails**

Run: `npm run build-tests && npm run test:ci`
Expected: FAIL — class/file doesn't exist.

- [ ] **Step 3: Implement**

```brightscript
' src/source/engine/ui/NinePatchImage.bs
namespace BGE.UI

  ' A 9-patch ("scale-9") stretchable background image: a source region is
  ' sliced once (at construction) into 9 pieces - 4 corners (drawn at fixed
  ' size), 4 edges (stretched along one axis), and a center (stretched both
  ' axes) - so a single small source texture can back a background of any
  ' width/height without visibly stretching its corners. Assign to
  ' Theme.backgroundImage to opt a widget's background fill into this
  ' instead of a flat color - see Theme.backgroundImage's own doc comment.
  class NinePatchImage

    protected topLeft as roRegion
    protected topEdge as roRegion
    protected topRight as roRegion
    protected leftEdge as roRegion
    protected center as roRegion
    protected rightEdge as roRegion
    protected bottomLeft as roRegion
    protected bottomEdge as roRegion
    protected bottomRight as roRegion

    protected left as integer
    protected top as integer
    protected right as integer
    protected bottom as integer

    ' @param {roRegion} sourceRegion - the full source image
    ' @param {integer} left - px from the left edge that stay unstretched
    ' @param {integer} top - px from the top edge that stay unstretched
    ' @param {integer} right - px from the right edge that stay unstretched
    ' @param {integer} bottom - px from the bottom edge that stay unstretched
    sub new(sourceRegion as roRegion, left as integer, top as integer, right as integer, bottom as integer)
      m.left = left
      m.top = top
      m.right = right
      m.bottom = bottom

      srcW = sourceRegion.GetWidth()
      srcH = sourceRegion.GetHeight()
      midW = srcW - left - right
      midH = srcH - top - bottom

      m.topLeft = sourceRegion.GetRegion(0, 0, left, top)
      m.topEdge = sourceRegion.GetRegion(left, 0, midW, top)
      m.topRight = sourceRegion.GetRegion(srcW - right, 0, right, top)
      m.leftEdge = sourceRegion.GetRegion(0, top, left, midH)
      m.center = sourceRegion.GetRegion(left, top, midW, midH)
      m.rightEdge = sourceRegion.GetRegion(srcW - right, top, right, midH)
      m.bottomLeft = sourceRegion.GetRegion(0, srcH - bottom, left, bottom)
      m.bottomEdge = sourceRegion.GetRegion(left, srcH - bottom, midW, bottom)
      m.bottomRight = sourceRegion.GetRegion(srcW - right, srcH - bottom, right, bottom)
    end sub

    ' Test-only accessors - not part of the public API surface, no JSDoc.
    function getTopLeft() as roRegion
      return m.topLeft
    end function

    function getCenter() as roRegion
      return m.center
    end function

  end class

end namespace
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npm run build-tests && npm run test:ci`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add src/source/engine/ui/NinePatchImage.bs src/source/engine/ui/NinePatchImage.spec.bs
git commit -m "feat: add BGE.UI.NinePatchImage slicing"
```

---

### Task 2: `NinePatchImage.draw()`

**Files:**
- Modify: `src/source/engine/ui/NinePatchImage.bs`
- Test: `src/source/engine/ui/NinePatchImage.spec.bs`

**Interfaces:**
- Consumes: `Renderer.drawObjectTo(draw2d, x, y, src, rgba)`, `Renderer.drawScaledObjectTo(draw2d, x, y, scaleX, scaleY, src, rgba)` (both already exist, `src/source/engine/renderer/Renderer.bs`).
- Produces: `NinePatchImage.draw(renderer as BGE.Renderer, x as float, y as float, width as float, height as float) as void` — consumed by Task 3's widget `draw()` branches.

- [ ] **Step 1: Write the failing test — draw() doesn't crash and issues 9 draw calls**

```brightscript
@it("draw() issues exactly 9 draw calls for one background fill")
function _()
  game = new BGE.Game({width: 200, height: 200}, {width: 200, height: 200})
  np = new BGE.UI.NinePatchImage(m.region, 8, 8, 8, 8)
  before = game.canvas.renderer.getDrawCallsLastFrame()
  np.draw(game.canvas.renderer, 10, 10, 100, 60)
  after = game.canvas.renderer.getDrawCallsLastFrame()
  m.assertEqual(9, after - before)
end function
```

Check `Renderer.getDrawCallsLastFrame()`'s exact semantics first (`grep -n "getDrawCallsLastFrame\|drawCallsLastFrame" src/source/engine/renderer/Renderer.bs`) — confirm it's a running per-frame counter incremented by each `draw*` call (used already by `examples/rendererTest`) and not reset by constructing a region, so the before/after delta is valid without an explicit frame boundary. If it only updates at `drawScene()`, count draw calls a different way (e.g. temporarily stub/wrap `drawObjectTo`/`drawScaledObjectTo` counts via a local counter object passed nowhere - simplest: skip the call-count assertion and instead assert no exception is thrown plus assert the destination canvas isn't blank via a corner-pixel color check, adjusting this test to whichever is actually feasible once you've read `getDrawCallsLastFrame`'s real behavior).

- [ ] **Step 2: Run test to verify it fails**

Run: `npm run build-tests && npm run test:ci`
Expected: FAIL — `draw` is not a member.

- [ ] **Step 3: Implement**

```brightscript
' Draws this 9-patch at (x, y) stretched to fill width x height. width/height
' must each be >= left+right / top+bottom respectively or the edges will
' overlap oddly - same caveat as any 9-patch implementation, not checked here.
'
' @param {BGE.Renderer} renderer
' @param {float} x
' @param {float} y
' @param {float} width
' @param {float} height
' @return {void}
sub draw(renderer as BGE.Renderer, x as float, y as float, width as float, height as float)
  midW = width - m.left - m.right
  midH = height - m.top - m.bottom

  renderer.drawObjectTo(renderer.canvas, x, y, m.topLeft)
  renderer.drawScaledObjectTo(renderer.canvas, x + m.left, y, midW / m.topEdge.GetWidth(), 1.0, m.topEdge)
  renderer.drawObjectTo(renderer.canvas, x + width - m.right, y, m.topRight)

  renderer.drawScaledObjectTo(renderer.canvas, x, y + m.top, 1.0, midH / m.leftEdge.GetHeight(), m.leftEdge)
  renderer.drawScaledObjectTo(renderer.canvas, x + m.left, y + m.top, midW / m.center.GetWidth(), midH / m.center.GetHeight(), m.center)
  renderer.drawScaledObjectTo(renderer.canvas, x + width - m.right, y + m.top, 1.0, midH / m.rightEdge.GetHeight(), m.rightEdge)

  renderer.drawObjectTo(renderer.canvas, x, y + height - m.bottom, m.bottomLeft)
  renderer.drawScaledObjectTo(renderer.canvas, x + m.left, y + height - m.bottom, midW / m.bottomEdge.GetWidth(), 1.0, m.bottomEdge)
  renderer.drawObjectTo(renderer.canvas, x + width - m.right, y + height - m.bottom, m.bottomRight)
end sub
```

Check `Renderer`'s actual field name for its own destination surface first (`grep -n "canvas as\|protected.*ifDraw2d\|m\.canvas" src/source/engine/renderer/Renderer.bs | head`) — `renderer.canvas` above is a placeholder name; use whatever the real field/method is (likely something like `renderer.getScreen()` or a stored `draw2d` field) so `drawObjectTo`'s `draw2d` param targets the renderer's actual backing surface, not a new one.

- [ ] **Step 4: Run test to verify it passes**

Run: `npm run build-tests && npm run test:ci`
Expected: PASS

- [ ] **Step 5: Validate and commit**

Run: `npm run validate`

```bash
git add src/source/engine/ui/NinePatchImage.bs src/source/engine/ui/NinePatchImage.spec.bs
git commit -m "feat: NinePatchImage.draw() blits all 9 slices"
```

---

### Task 3: `Theme.backgroundImage` + widget `draw()` branches

**Files:**
- Modify: `src/source/engine/ui/Theme.bs`
- Modify: `src/source/engine/ui/Button.bs`, `Checkbox.bs`, `Select.bs`, `Slider.bs` (their `draw()` methods)
- Test: `src/source/engine/ui/Theme.spec.bs`, and one new assertion per widget spec (`Button.spec.bs` etc.)

**Interfaces:**
- Consumes: `NinePatchImage.draw(renderer, x, y, width, height)` from Task 2.
- Produces: `Theme.backgroundImage as BGE.UI.NinePatchImage = invalid`.

- [ ] **Step 1: Write the failing test — Theme defaults to invalid**

```brightscript
' Theme.spec.bs - add to the existing suite
@it("backgroundImage defaults to invalid")
function _()
  theme = new BGE.UI.Theme()
  m.assertEqual(true, theme.backgroundImage = invalid)
end function
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm run build-tests && npm run test:ci`
Expected: FAIL — field doesn't exist (BrighterScript would actually likely compile-error here since `backgroundImage` isn't declared; either way, confirm red before green).

- [ ] **Step 3: Add the field**

In `src/source/engine/ui/Theme.bs`:

```brightscript
' A 9-patch background image, drawn instead of a flat backgroundColor fill
' when set. invalid (the default) means "flat color" - exactly today's
' behavior, so this is purely additive. See BGE.UI.NinePatchImage.
backgroundImage as BGE.UI.NinePatchImage = invalid
```

Add `import "NinePatchImage.bs"` to `Theme.bs`.

- [ ] **Step 4: Run test to verify it passes**

Run: `npm run build-tests && npm run test:ci`

- [ ] **Step 5: Write the failing test — Button.draw() uses backgroundImage when set**

This is a draw-doesn't-crash-and-uses-the-right-branch test, not a pixel-diff test (no existing widget spec does pixel comparison). Add to `Button.spec.bs`:

```brightscript
@it("draw() does not throw when theme.backgroundImage is set")
function _()
  bmp = CreateObject("roBitmap", {width: 24, height: 24, AlphaEnable: true})
  bmp.Clear(&hFFFFFFFF)
  region = CreateObject("roRegion", bmp, 0, 0, 24, 24)
  m.game.defaultTheme.backgroundImage = new BGE.UI.NinePatchImage(region, 6, 6, 6, 6)

  button = new BGE.UI.Button(m.game)
  button.width = 80
  button.height = 30
  button.position = BGE.Math.VectorOps.create(0, 0)
  button.draw() ' must not throw
end function
```

Check `Button.spec.bs`'s existing `beforeEach` for how `m.game` is constructed and how a `Button`'s `position`/`canvas` get set up before `draw()` is callable, and match that setup exactly rather than guessing.

- [ ] **Step 6: Run test to verify it fails**

Run: `npm run build-tests && npm run test:ci`
Expected: FAIL if `draw()` currently always calls `drawRectangle` unconditionally with no branch (it should still "pass" functionally today since nothing reads `backgroundImage` yet, but the point is to lock in behavior before changing `draw()` - if this test technically passes before Step 7, that's fine, note it and proceed; the real regression check is Step 8's flat-color test).

- [ ] **Step 7: Add the branch to Button.draw() (and Checkbox/Select/Slider identically)**

In each widget's `draw()`, replace only the background-fill lines (leave the focused-border `drawRectangle` call above it untouched):

```brightscript
if theme.backgroundImage <> invalid
  theme.backgroundImage.draw(m.canvas.renderer, m.position.x, m.position.y, m.width, m.height)
else
  m.canvas.renderer.drawRectangle(m.position.x, m.position.y, m.width, m.height, backgroundColor)
end if
```

Note `backgroundColor` above already accounts for hovered/focused state (`theme.hoveredBackgroundColor` vs `theme.backgroundColor`) in the existing code - the 9-patch branch intentionally does NOT vary the image by hover/focus state in this first pass (a themeable "hoveredBackgroundImage"/"focusedBackgroundImage" is a reasonable future follow-up, not in scope here - note this as a non-goal in the PR description, matching the design doc's convention of calling out explicit non-goals).

- [ ] **Step 8: Write the regression test — flat color still works when backgroundImage is invalid**

Add (if not already covered by an existing test) one assertion per widget confirming `draw()` still calls the flat-fill path when `theme.backgroundImage = invalid` (the default) - reuse whatever existing `Button.spec.bs`/etc. draw test already exists rather than duplicating; just confirm it still passes unmodified.

- [ ] **Step 9: Run the full suite**

Run: `npm run build-tests && npm run test:ci`
Expected: PASS, all widgets

- [ ] **Step 10: Validate and commit**

Run: `npm run validate`

```bash
git add src/source/engine/ui/Theme.bs src/source/engine/ui/Theme.spec.bs src/source/engine/ui/Button.bs src/source/engine/ui/Button.spec.bs src/source/engine/ui/Checkbox.bs src/source/engine/ui/Checkbox.spec.bs src/source/engine/ui/Select.bs src/source/engine/ui/Select.spec.bs src/source/engine/ui/Slider.bs src/source/engine/ui/Slider.spec.bs
git commit -m "feat: Theme.backgroundImage lets widgets use a 9-patch background"
```

---

### Task 4: `examples/ui` demo room + on-device verification

**Files:**
- Create: `examples/ui/src/source/Rooms/NinePatchRoom.bs`
- Create: `examples/ui/src/source/images/` — a small hand-authored or generated 9-patch PNG (e.g. 24x24, 6px insets, a rounded-rect panel look)
- Modify: `examples/ui/src/source/main.bs`

**Interfaces:**
- Consumes: `Game.load*` image-loading path used elsewhere for `roRegion` creation from a packaged image (check `Game.bs`/an existing example for the exact "load a pkg: image into a roRegion" call - likely `CreateObject("roBitmap", "pkg:/...")` then wrap in `roRegion`, matching whatever `Image` drawables already do in `src/source/engine/drawables/Image.bs`).

- [ ] **Step 1: Produce a demo 9-patch asset**

Create (or ask the user for) a simple 24x24 PNG panel graphic with a 6px border that tiles cleanly - a flat-colored rounded rectangle with a 1-2px outline is sufficient for demo purposes. Save to `examples/ui/src/source/images/panel-9patch.png`.

- [ ] **Step 2: Scaffold and build the room**

Run: `npm run create-room -- ui NinePatchRoom`

In `onCreate()`: load the PNG into a `roRegion` (following the exact pattern `Image`/an existing example uses for loading a packaged bitmap - check `examples/*/src/source/Rooms/*.bs` for a `CreateObject("roBitmap", "pkg:/images/...")` precedent before writing this from scratch), construct a `BGE.UI.NinePatchImage`, assign it to `m.game.defaultTheme.backgroundImage`, then add 2-3 `Button`s at different sizes to show the background stretching correctly at each size. Add a Back-button handler (guarded with `input.press`) to `MainRoom`.

- [ ] **Step 3: Register in main.bs**

Same pattern as the analog-cursor room.

- [ ] **Step 4: Sideload and screenshot**

Per `rokubot-examples`: sideload, launch, navigate to `NinePatchRoom`, screenshot. Visually confirm corners stay crisp/unstretched at multiple button sizes and the center/edges tile without visible seams. This is the on-device check CLAUDE.md requires for example-level behavior - Rooibos doesn't cover it.

- [ ] **Step 5: Commit**

```bash
git add examples/ui
git commit -m "feat: add NinePatchRoom demo to examples/ui"
```

---

### Task 5: Docs + issue close-out

**Files:**
- Modify: `docs/engine-internals.md` or `docs/game-engine-overview.md` (whichever documents `BGE.UI.Theme` today - confirm via `grep -rn "Theme" docs/`)

- [ ] **Step 1: Document `NinePatchImage`/`Theme.backgroundImage`**

Cover: how to construct a `NinePatchImage` from a packaged image, the insets convention, and that it's purely additive (existing flat-color themes are unaffected).

- [ ] **Step 2: `npm run docs`**

Run: `npm run docs`
Expected: no errors.

- [ ] **Step 3: Final check**

Run: `npm run check`

- [ ] **Step 4: Commit and open the PR**

```bash
git add docs/
git commit -m "docs: document 9-patch widget backgrounds"
```

Push and open a PR closing #180.
