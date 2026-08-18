# Particle System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `DrawableParticles` emitter (line/rectangle/image particles with velocity spread, acceleration, lifetime fade/color interpolation, a population cap, and `start()`/`stop()`/`burst()`) that plugs into `GameEntity` like any other drawable, plus a runnable `examples/particles` demo.

**Architecture:** One `SceneObjectParticle` per emitter (not per particle) draws its owner `DrawableParticles`'s entire live-particle array in a single `performDraw` loop, so spawning/expiring particles never touches `Renderer.addSceneObject`/`removeSceneObject` and never defeats the depth-sort skip-optimization. `DrawableParticles.update()` (the existing per-frame `Drawable` hook `AnimatedImage` already uses) runs the whole simulation: spawn accumulator, physics integration, lifetime-driven color/alpha/size interpolation, expiry.

**Tech Stack:** BrighterScript (`bsc`), Rooibos v6 (`rooibos-roku`) for unit tests, `brs-cli` for headless CI test runs, `rokubot` for on-device/simulator verification.

**Spec:** `specs/2026-08-18-particle-system-design.md`

## Global Constraints

- One `@suite` class per `*.spec.bs` file (Rooibos v6 corrupts test metadata otherwise).
- `assertEqual` is type-strict (Integer vs Float) — match the literal type the code under test actually produces.
- Compare `SceneObject`/custom-class instances by a stable identity field (e.g. `id`), never with `=` — that's a runtime `Type Mismatch` crash, uncaught by `bsc`/lint.
- Any discrete/one-shot `onInput` check (e.g. the `examples/particles` demo room's shape-cycling) must guard with `input.press and input.isButton(...)`.
- Run `npm run validate` after any engine-code change (`src/source/`) before moving to the next task.
- Rectangle particles are fill-only (no outline) and never rotate; line particles never rotate; only the `"image"` shape rotates/scales. This is deliberate, not an oversight — see the design spec's "Per-shape draw cost, by design" section.

---

## File Structure

| File | Responsibility |
|---|---|
| `src/source/math/math.bs` (modify) | Add scalar `lerp(a, b, t)` helper. |
| `src/source/math/math.spec.bs` (modify) | Test `lerp`. |
| `src/source/utils/colors.bs` (modify) | Add `lerpColorRGB(colorA, colorB, t)` channel-wise packed-RGB interpolation. |
| `src/source/utils/colors.spec.bs` (modify) | Test `lerpColorRGB`. |
| `src/source/engine/renderer/sceneObjects/SceneObject.bs` (modify) | Add `Particle` to the `SceneObjectType` enum. |
| `src/source/engine/drawables/DrawableParticles.bs` (create) | Emitter config, particle-record array, simulation (`update()`), `start()`/`stop()`/`burst()`, `addToScene()`. |
| `src/source/engine/drawables/DrawableParticles.spec.bs` (create) | Simulation/config behavior: spawn accounting, expiry, cap, burst, color/alpha/size interpolation. |
| `src/source/engine/renderer/sceneObjects/SceneObjectParticle.bs` (create) | The one-per-emitter `SceneObject`; `performDraw` loops the owning `DrawableParticles`'s particles and issues one direct draw call per particle, branching by shape. |
| `src/source/engine/renderer/sceneObjects/SceneObjectParticle.spec.bs` (create) | Draw-call-count behavior against a real `Renderer`/`roBitmap`, isolation-tested like `SceneObjectCircle.spec.bs`. |
| `src/source/engine/GameEntity.bs` (modify) | Add `addParticles(...)` convenience method, mirroring `addCircle`/`addRectangle`. |
| `examples/particles/` (create, via scaffolding scripts) | Runnable demo: one room per shape, one contrasting continuous emission vs. `burst()`, one "stress" room near `maxParticles` for on-device fps/draw-call numbers. |
| `examples/particles/src/sprites/fireball.png` (added mid-plan — Task 6/7) | opengameart.org "Fireball Particle Sheet" sprite sheet, CC-BY 3.0, for the animated sprite-sheet particle demo. |
| `examples/particles/src/sprites/CREDITS.md` (added mid-plan — Task 7) | Attribution for `fireball.png`, following `examples/parallax/src/sprites/CREDITS.md`'s existing convention. |
| `examples/particles/src/source/Rooms/AnimatedImageParticlesRoom.bs` (added mid-plan — Task 7) | Demonstrates sprite-sheet-animated image particles. |
| `docs/drawables-and-scene-objects.md` (modify) | Document the `DrawableParticles`/`SceneObjectParticle` pair, following its existing per-pair walkthrough structure. |
| `CLAUDE.md` (modify) | Add `DrawableParticles`/`SceneObjectParticle` to the existing drawable/scene-object subclass lists. |

**Added mid-execution (not in the original design spec):** Tasks 6-7 below (animated sprite-sheet image particles) were added after Task 5 completed, per a direct user request mid-plan. See the SDD ledger for the ruling. `DrawableParticles.bs`/`DrawableParticles.spec.bs`/`SceneObjectParticle.bs`/`SceneObjectParticle.spec.bs` above get a second round of changes in Task 6, on top of Tasks 2-3's original ones.

---

### Task 1: Scalar `lerp` and `lerpColorRGB` helpers

**Files:**
- Modify: `src/source/math/math.bs`
- Modify: `src/source/math/math.spec.bs`
- Modify: `src/source/utils/colors.bs`
- Modify: `src/source/utils/colors.spec.bs`

**Interfaces:**
- Produces: `BGE.Math.lerp(a as float, b as float, t as float) as float` — used by Task 2 (particle size/alpha interpolation) and Task 3 (draw-time color/alpha interpolation).
- Produces: `BGE.lerpColorRGB(colorA as integer, colorB as integer, t as float) as integer` — packed-RGB (`0xRRGGBB`) input/output, used by Task 3.

Neither helper exists anywhere in the codebase today (confirmed by grep across `src/source`) — `BGE.Math` has no parametric lerp, and `colors.bs`'s `colorBrightness`/`colorOpacity` scale one existing color's channels, they don't blend between two distinct colors.

- [ ] **Step 1: Write the failing tests**

Add to `src/source/math/math.spec.bs` (inside the existing `@suite` class, alongside its other `@it` blocks — do not create a second `@suite` class in this file):

```brighterscript
@describe("lerp")
@it("returns the start value at t=0")
function _()
  m.assertEqual(10.0, BGE.Math.lerp(10, 20, 0))
end function

@it("returns the end value at t=1")
function _()
  m.assertEqual(20.0, BGE.Math.lerp(10, 20, 1))
end function

@it("returns the midpoint at t=0.5")
function _()
  m.assertEqual(15.0, BGE.Math.lerp(10, 20, 0.5))
end function

@it("extrapolates past the end value for t>1")
function _()
  m.assertEqual(30.0, BGE.Math.lerp(10, 20, 2))
end function
```

Add to `src/source/utils/colors.spec.bs` (same rule — one existing `@suite` class, append `@it` blocks):

```brighterscript
@describe("lerpColorRGB")
@it("returns colorA at t=0")
function _()
  m.assertEqual(&hFF0000, BGE.lerpColorRGB(&hFF0000, &h0000FF, 0))
end function

@it("returns colorB at t=1")
function _()
  m.assertEqual(&h0000FF, BGE.lerpColorRGB(&hFF0000, &h0000FF, 1))
end function

@it("blends each channel independently at t=0.5")
function _()
  ' red 0xFF->0x00, green 0x00->0x00, blue 0x00->0xFF
  m.assertEqual(&h800080, BGE.lerpColorRGB(&hFF0000, &h0000FF, 0.5))
end function
```

- [ ] **Step 2: Build the tests and confirm they fail**

Run: `npm run build-tests`
Expected: FAIL — `lerp` and `lerpColorRGB` are undefined.

- [ ] **Step 3: Implement `BGE.Math.lerp`**

In `src/source/math/math.bs`, inside the existing `namespace BGE.Math` block, add:

```brighterscript
  ' Linearly interpolates between two scalars.
  '
  ' @param {float} a - start value (returned at t=0)
  ' @param {float} b - end value (returned at t=1)
  ' @param {float} t - interpolation factor, typically 0-1 (not clamped - values outside
  '   0-1 extrapolate past a/b)
  ' @return {float} the interpolated value
  function lerp(a as float, b as float, t as float) as float
    return a + (b - a) * t
  end function
```

- [ ] **Step 4: Implement `BGE.lerpColorRGB`**

In `src/source/utils/colors.bs`, inside the existing `namespace BGE` block, add (near `colorBrightness`/`colorOpacity`):

```brighterscript
  ' Linearly interpolates between two packed RGB colors (0xRRGGBB), channel-wise.
  '
  ' @param {integer} colorA - start color, packed RGB (returned at t=0)
  ' @param {integer} colorB - end color, packed RGB (returned at t=1)
  ' @param {float} t - interpolation factor, clamped to 0-1
  ' @return {integer} the interpolated packed RGB color
  function lerpColorRGB(colorA as integer, colorB as integer, t as float) as integer
    t = BGE.Math.Clamp(t, 0, 1)
    aR% = (colorA >> 16) and &hFF
    aG% = (colorA >> 8) and &hFF
    aB% = colorA and &hFF
    bR% = (colorB >> 16) and &hFF
    bG% = (colorB >> 8) and &hFF
    bB% = colorB and &hFF
    r% = cint(BGE.Math.lerp(aR%, bR%, t))
    g% = cint(BGE.Math.lerp(aG%, bG%, t))
    b% = cint(BGE.Math.lerp(aB%, bB%, t))
    return (r% << 16) + (g% << 8) + b%
  end function
```

- [ ] **Step 5: Run the tests and confirm they pass**

Run: `npm run build-tests && npm run test:ci`
Expected: PASS for all six new `@it` blocks; `[Rooibos Result]: PASS`.

- [ ] **Step 6: Validate and commit**

Run: `npm run validate`
Expected: no type errors.

```bash
git add src/source/math/math.bs src/source/math/math.spec.bs src/source/utils/colors.bs src/source/utils/colors.spec.bs
git commit -m "Add BGE.Math.lerp and BGE.lerpColorRGB helpers

Neither a scalar lerp nor an RGB color-blend helper existed anywhere in
BGE.Math/colors.bs - colorBrightness/colorOpacity only scale one color's
own channels, they don't blend two distinct colors. Needed by the
upcoming particle system's size/alpha/color-over-lifetime interpolation.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 2: `DrawableParticles` — config, spawn/expiry simulation, `start()`/`stop()`/`burst()`

**Files:**
- Create: `src/source/engine/drawables/DrawableParticles.bs`
- Create: `src/source/engine/drawables/DrawableParticles.spec.bs`

**Interfaces:**
- Consumes: `BGE.Math.lerp` (Task 1, used indirectly — not in this task's own code, but this task's `particles` array shape is what Task 1's helpers get applied to in Task 3).
- Consumes: `Drawable` base class — `sub new(owner as GameEntity, args as roAssociativeArray)`, `protected function addSceneObjectToRenderer(sceneObj as SceneObject, renderScene as Renderer) as SceneObject`, `function getSceneObjectName(prefix as string) as string`, `function getWorldPosition() as BGE.Math.Vector`, `sub update()` (override point).
- Consumes: `GameTimer` — `sub new()`, `sub mark()`, `function totalMilliseconds() as integer`.
- Consumes: `BGE.Math.VectorOps.{create, copy, scale, plusEquals, isZero, getNormalizedCopy}`, `BGE.Math.{RotateVectorAroundPoint2d, DegreesToRadians, Max, Clamp}`.
- Produces (for Task 3): a public `particles as object[]` field on every `DrawableParticles` instance, where each element is a plain associative array with these exact keys — `position` (`BGE.Math.Vector`), `velocity` (`BGE.Math.Vector`), `age` (`float`), `lifetime` (`float`), `startColor`/`endColor` (`integer`, packed RGB), `startAlpha`/`endAlpha` (`float`, 0-255), `startSize`/`endSize` (`float`), `rotation` (`float`, degrees, image shape only). Also produces public fields `shape as string` and `optional image as dynamic` that Task 3 reads directly.
- Produces (for Task 4/5): `DrawableParticles.new(owner as GameEntity, shape as string, args = {} as roAssociativeArray)` and the public config fields listed in Step 3 below (`spawnRate`, `lifetime`, `lifetimeSpread`, `velocity`, `velocitySpreadAngleDegrees`, `velocitySpreadMagnitude`, `acceleration`, `startColor`, `endColor`, `startAlpha`, `endAlpha`, `startSize`, `endSize`, `rotationSpeed`, `maxParticles`), plus `start()`, `stop()`, `burst(count as integer)`.
- **Note on this task's scope:** `addToScene()` is implemented here (it must exist for the class to compile as a `Drawable` and so this task's own tests can call it), but it constructs a `SceneObjectParticle` — Task 3's class. Steps below stub `SceneObjectParticle` with a two-line placeholder file first so Task 2 compiles and tests independently; Task 3 replaces that stub with the real implementation. This keeps each task's own test cycle isolated per the "Task Right-Sizing" rule, while avoiding a forward reference to a class that doesn't exist yet.

- [ ] **Step 1: Write a temporary `SceneObjectParticle` stub so this task compiles**

Create `src/source/engine/renderer/sceneObjects/SceneObjectParticle.bs`:

```brighterscript
namespace BGE
  ' TEMPORARY STUB - replaced with the real implementation in Task 3.
  class SceneObjectParticle extends SceneObject
    drawable as DrawableParticles

    sub new(name as string, drawableObj as DrawableParticles)
      super(name, drawableObj, BGE.SceneObjectType.Particle)
    end sub
  end class
end namespace
```

Add `Particle` to the `SceneObjectType` enum in `src/source/engine/renderer/sceneObjects/SceneObject.bs`:

```brighterscript
  enum SceneObjectType
    Line = "Line"
    Rectangle = "Rectangle"
    Text = "Text"
    Bitmap = "Bitmap"
    Polygon = "Polygon"
    Billboard = "Billboard"
    Model = "Model"
    Plane = "Plane"
    ParallaxLayer = "ParallaxLayer"
    Circle = "Circle"
    Particle = "Particle"
  end enum
```

- [ ] **Step 2: Write the failing tests**

Create `src/source/engine/drawables/DrawableParticles.spec.bs`:

```brighterscript
namespace tests
  @suite("BGE.DrawableParticles")
  class DrawableParticlesTests extends rooibos.BaseTestSuite
    game as BGE.Game
    entity as BGE.GameEntity

    protected override function beforeEach()
      m.game = new BGE.Game(320, 240)
      m.entity = new BGE.GameEntity(m.game, {name: "TestEntity"})
    end function

    @describe("construction")
    @it("takes its shape from the constructor")
    function _()
      emitter = new BGE.DrawableParticles(m.entity, "rectangle")
      m.assertEqual("rectangle", emitter.shape)
    end function

    @it("starts with no live particles")
    function _()
      emitter = new BGE.DrawableParticles(m.entity, "rectangle")
      m.assertEqual(0, emitter.particles.count())
    end function

    @describe("burst")
    @it("immediately spawns the requested count regardless of start/stop state")
    function _()
      emitter = new BGE.DrawableParticles(m.entity, "rectangle")
      emitter.burst(5)
      m.assertEqual(5, emitter.particles.count())
    end function

    @it("does not spawn past maxParticles")
    function _()
      emitter = new BGE.DrawableParticles(m.entity, "rectangle", {maxParticles: 3})
      emitter.burst(10)
      m.assertEqual(3, emitter.particles.count())
    end function

    @describe("continuous emission")
    @it("does not spawn while stopped")
    function _()
      emitter = new BGE.DrawableParticles(m.entity, "rectangle", {spawnRate: 100})
      emitter.update()
      m.assertEqual(0, emitter.particles.count())
    end function

    @it("spawns particles once started, at spawnRate accounting for elapsed time")
    function _()
      emitter = new BGE.DrawableParticles(m.entity, "rectangle", {spawnRate: 10})
      emitter.start()
      ' First update() call establishes the timer's baseline (elapsed time since
      ' construction is unpredictable in a test), so it may spawn 0+ particles.
      emitter.update()
      countAfterFirstUpdate = emitter.particles.count()
      sleep(200) ' ~2 particles at 10/sec
      emitter.update()
      m.assertTrue(emitter.particles.count() > countAfterFirstUpdate)
    end function

    @it("stops spawning new particles after stop(), but keeps existing ones alive")
    function _()
      emitter = new BGE.DrawableParticles(m.entity, "rectangle", {spawnRate: 1000, lifetime: 100})
      emitter.start()
      emitter.update()
      sleep(50)
      emitter.update()
      countWhileEmitting = emitter.particles.count()
      m.assertTrue(countWhileEmitting > 0)
      emitter.stop()
      sleep(50)
      emitter.update()
      m.assertEqual(countWhileEmitting, emitter.particles.count())
    end function

    @describe("lifetime expiry")
    @it("removes a particle once its age reaches its lifetime")
    function _()
      emitter = new BGE.DrawableParticles(m.entity, "rectangle", {lifetime: 0.05})
      emitter.burst(1)
      m.assertEqual(1, emitter.particles.count())
      sleep(100)
      emitter.update()
      m.assertEqual(0, emitter.particles.count())
    end function

    @describe("physics")
    @it("integrates velocity into position over time")
    function _()
      emitter = new BGE.DrawableParticles(m.entity, "rectangle", {velocity: BGE.Math.VectorOps.create(100, 0), lifetime: 10})
      emitter.burst(1)
      startX = emitter.particles[0].position.x
      sleep(100)
      emitter.update()
      m.assertTrue(emitter.particles[0].position.x > startX)
    end function

    @it("integrates acceleration into velocity over time")
    function _()
      emitter = new BGE.DrawableParticles(m.entity, "rectangle", {acceleration: BGE.Math.VectorOps.create(0, -50), lifetime: 10})
      emitter.burst(1)
      startVelocityY = emitter.particles[0].velocity.y
      sleep(100)
      emitter.update()
      m.assertTrue(emitter.particles[0].velocity.y < startVelocityY)
    end function

    @describe("radial spread with zero base velocity")
    @it("gives a stationary emitter's particles nonzero velocity when velocitySpreadMagnitude is set")
    function _()
      emitter = new BGE.DrawableParticles(m.entity, "rectangle", {velocitySpreadMagnitude: 50})
      emitter.burst(1)
      m.assertFalse(BGE.Math.VectorOps.isZero(emitter.particles[0].velocity))
    end function
  end class
end namespace
```

- [ ] **Step 3: Build the tests and confirm they fail**

Run: `npm run build-tests`
Expected: FAIL — `BGE.DrawableParticles` is undefined.

- [ ] **Step 4: Implement `DrawableParticles`**

Create `src/source/engine/drawables/DrawableParticles.bs`:

```brighterscript
namespace BGE
  ' Emits and simulates lightweight particles (lines, rectangles, or images) with
  ' randomized velocity, constant acceleration, and lifetime-driven fade/color/size
  ' interpolation. Draws through a single SceneObjectParticle per emitter rather than
  ' one SceneObject per particle, so spawning/expiring particles never touches
  ' Renderer.addSceneObject/removeSceneObject - see
  ' specs/2026-08-18-particle-system-design.md for why that matters for depth-sort
  ' performance.
  class DrawableParticles extends Drawable
    ' Shape drawn for every particle: "line", "rectangle", or "image".
    shape as string = "rectangle"

    ' Bitmap or region drawn for each particle when shape = "image". Ignored for other
    ' shapes.
    optional image as dynamic = invalid

    ' Particles spawned per second while emitting (see start()/stop()).
    spawnRate as float = 0.0

    ' Base lifetime in seconds each particle survives, randomized by +/- lifetimeSpread.
    lifetime as float = 1.0
    lifetimeSpread as float = 0.0

    ' Base emission velocity (world units/second) shared by every particle before
    ' randomization is applied.
    velocity as BGE.Math.Vector = BGE.Math.VectorOps.create()

    ' Randomizes each particle's velocity direction by +/- this many degrees around
    ' `velocity`.
    velocitySpreadAngleDegrees as float = 0.0

    ' Randomizes each particle's velocity magnitude by +/- this amount. If `velocity`
    ' is zero, particles instead radiate outward in a uniformly random direction at this
    ' magnitude - this is what makes a stationary emitter usable for an explosion/burst
    ' effect.
    velocitySpreadMagnitude as float = 0.0

    ' Constant acceleration (world units/second^2) applied to every particle every
    ' frame, e.g. gravity.
    acceleration as BGE.Math.Vector = BGE.Math.VectorOps.create()

    ' Packed RGB (0xRRGGBB) color interpolated over each particle's lifetime.
    startColor as integer = &hFFFFFF
    endColor as integer = &hFFFFFF

    ' Alpha (0-255) interpolated over each particle's lifetime.
    startAlpha as float = 255.0
    endAlpha as float = 255.0

    ' Size interpolated over each particle's lifetime - a line's length, a rectangle's
    ' side length, or an image's scale multiplier (1.0 = the image's native size),
    ' depending on `shape`.
    startSize as float = 4.0
    endSize as float = 4.0

    ' Degrees/second of rotation applied to each particle. Only used when shape = "image"
    ' - see the design spec for why line/rectangle particles never rotate.
    rotationSpeed as float = 0.0

    ' Hard cap on live particles. Once reached, further spawns (continuous emission or
    ' burst()) are silently dropped until a slot frees up via natural expiry.
    maxParticles as integer = 100

    ' Live particle records, each a plain associative array with keys: position
    ' (BGE.Math.Vector), velocity (BGE.Math.Vector), age (float), lifetime (float),
    ' startColor/endColor (integer, packed RGB), startAlpha/endAlpha (float, 0-255),
    ' startSize/endSize (float), rotation (float, degrees, image shape only).
    particles as object[] = []

    protected emitting as boolean = false
    protected spawnAccumulator as float = 0.0
    protected timer = new GameTimer()

    sub new(owner as GameEntity, shape as string, args = {} as roAssociativeArray)
      super(owner, args)
      m.shape = shape
      m.append(args)
      m.timer.mark()
    end sub

    ' Starts continuous emission at `spawnRate` particles/second.
    sub start()
      m.emitting = true
    end sub

    ' Stops continuous emission. Already-live particles keep simulating and drawing
    ' until they expire naturally.
    sub stop()
      m.emitting = false
    end sub

    ' Immediately spawns `count` particles, regardless of start()/stop() state.
    '
    ' @param {integer} count - number of particles to spawn right now
    sub burst(count as integer)
      for i = 1 to count
        m.spawnParticle()
      end for
    end sub

    override function addToScene(rendererScene as Renderer) as BGE.SceneObject
      return m.addSceneObjectToRenderer(new SceneObjectParticle(m.getSceneObjectName("particles"), m), rendererScene)
    end function

    override sub update()
      elapsedMs = m.timer.totalMilliseconds()
      m.timer.mark()
      dt = elapsedMs / 1000.0

      if m.emitting and m.spawnRate > 0
        m.spawnAccumulator += m.spawnRate * dt
        while m.spawnAccumulator >= 1.0
          m.spawnParticle()
          m.spawnAccumulator -= 1.0
        end while
      end if

      remaining = []
      for each particle in m.particles
        particle.age += dt
        if particle.age < particle.lifetime
          BGE.Math.VectorOps.plusEquals(particle.velocity, BGE.Math.VectorOps.scale(m.acceleration, dt))
          BGE.Math.VectorOps.plusEquals(particle.position, BGE.Math.VectorOps.scale(particle.velocity, dt))
          if m.shape = "image"
            particle.rotation += m.rotationSpeed * dt
          end if
          remaining.push(particle)
        end if
      end for
      m.particles = remaining
    end sub

    private sub spawnParticle()
      if m.particles.count() >= m.maxParticles
        return
      end if

      spawnVelocity = BGE.Math.VectorOps.copy(m.velocity)
      spreadMagnitude = (rnd(0) * 2.0 - 1.0) * m.velocitySpreadMagnitude

      if BGE.Math.VectorOps.isZero(spawnVelocity)
        ' No base direction to spread around - radiate outward uniformly at random,
        ' so a stationary emitter with velocitySpreadMagnitude set still produces an
        ' explosion/burst-style spread instead of doing nothing.
        randomAngle = rnd(0) * 360.0
        direction = BGE.Math.RotateVectorAroundPoint2d(BGE.Math.VectorOps.create(1, 0), BGE.Math.VectorOps.create(), BGE.Math.DegreesToRadians(randomAngle))
        spawnVelocity = BGE.Math.VectorOps.scale(direction, spreadMagnitude)
      else
        spreadAngle = (rnd(0) * 2.0 - 1.0) * m.velocitySpreadAngleDegrees
        spawnVelocity = BGE.Math.RotateVectorAroundPoint2d(spawnVelocity, BGE.Math.VectorOps.create(), BGE.Math.DegreesToRadians(spreadAngle))
        direction = BGE.Math.VectorOps.getNormalizedCopy(spawnVelocity)
        BGE.Math.VectorOps.plusEquals(spawnVelocity, BGE.Math.VectorOps.scale(direction, spreadMagnitude))
      end if

      lifetimeVariance = (rnd(0) * 2.0 - 1.0) * m.lifetimeSpread
      particleLifetime = BGE.Math.Max(0.01, m.lifetime + lifetimeVariance)

      m.particles.push({
        position: BGE.Math.VectorOps.copy(m.getWorldPosition())
        velocity: spawnVelocity
        age: 0.0
        lifetime: particleLifetime
        startColor: m.startColor
        endColor: m.endColor
        startAlpha: m.startAlpha
        endAlpha: m.endAlpha
        startSize: m.startSize
        endSize: m.endSize
        rotation: 0.0
      })
    end sub
  end class
end namespace
```

- [ ] **Step 5: Run the tests and confirm they pass**

Run: `npm run build-tests && npm run test:ci`
Expected: PASS for every `@it` block above.

If the "spawns particles once started" or "stops spawning" tests are flaky under `brs-cli` timing (real wall-clock `sleep()` inside a headless interpreter can jitter), widen the `sleep()` durations and the `spawnRate` used in that specific test rather than loosening the assertion — the behavior being tested (spawn rate accounting over real elapsed time) is the point of the test.

- [ ] **Step 6: Validate and commit**

Run: `npm run validate`
Expected: no type errors (the temporary `SceneObjectParticle` stub and new `Particle` enum value are enough for this to pass).

```bash
git add src/source/engine/drawables/DrawableParticles.bs src/source/engine/drawables/DrawableParticles.spec.bs src/source/engine/renderer/sceneObjects/SceneObjectParticle.bs src/source/engine/renderer/sceneObjects/SceneObject.bs
git commit -m "Add DrawableParticles emitter simulation (#86)

Config, particle-record spawn/physics/expiry simulation, start()/stop()/
burst(), and a maxParticles cap. SceneObjectParticle is a temporary stub
here - Task 3 replaces it with the real per-emitter draw loop.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 3: `SceneObjectParticle` — the one-per-emitter draw loop

**Files:**
- Modify (replace stub): `src/source/engine/renderer/sceneObjects/SceneObjectParticle.bs`
- Create: `src/source/engine/renderer/sceneObjects/SceneObjectParticle.spec.bs`

**Interfaces:**
- Consumes: `DrawableParticles.particles as object[]`, `DrawableParticles.shape as string`, `DrawableParticles.image as dynamic` (all from Task 2).
- Consumes: `BGE.Math.lerp`, `BGE.lerpColorRGB` (Task 1).
- Consumes: `SceneObject` base class extension points — `protected function performDraw(rendererObj as Renderer, drawMode as SceneObjectDrawMode) as boolean`, `function participatesInOverlapDetection() as boolean`.
- Consumes: `Renderer.{worldPointToCanvasPoint, drawLine, drawRectangle, drawRegion}`, `BGE.RGBAtoRGBA`.
- Consumes: `BGE.Math.VectorOps.{getNormalizedCopy, isZero, create, add, scale}`.
- Produces: nothing new for later tasks — this is the leaf of the render path. `SceneObjectParticle.new(name as string, drawableObj as DrawableParticles)` is used by Task 2's `addToScene()` (already written).

- [ ] **Step 1: Write the failing tests**

Create `src/source/engine/renderer/sceneObjects/SceneObjectParticle.spec.bs`, following the `SceneObjectCircle.spec.bs` isolation pattern (a real second `Renderer` wrapping a real `roBitmap`, driven directly rather than through a full game loop):

```brighterscript
namespace tests
  @suite("BGE.SceneObjectParticle")
  class SceneObjectParticleTests extends rooibos.BaseTestSuite
    game as BGE.Game
    entity as BGE.GameEntity
    bitmap as roBitmap
    renderer as BGE.Renderer

    protected override function beforeEach()
      m.game = new BGE.Game(320, 240)
      m.entity = new BGE.GameEntity(m.game, {name: "TestEntity"})
      m.bitmap = CreateObject("roBitmap", {width: 200, height: 200, alphaEnable: true})
      m.renderer = new BGE.Renderer(m.bitmap)
      m.entity.position = BGE.Math.VectorOps.create(100, 100, 0)
    end function

    private function drawOnce(emitter as BGE.DrawableParticles) as integer
      sceneObj = emitter.addToScene(m.renderer)
      m.entity.updateTransformationMatrix()
      m.renderer.resetDrawCallCounter()
      sceneObj.update(m.renderer.camera)
      sceneObj.draw(m.renderer)
      return m.renderer.getDrawCallsLastFrame()
    end function

    @describe("draw call count scales with live particle count")
    @it("issues zero draw calls with zero live particles")
    function _()
      emitter = new BGE.DrawableParticles(m.entity, "rectangle")
      m.assertEqual(0, m.drawOnce(emitter))
    end function

    @it("issues one draw call per live rectangle particle")
    function _()
      emitter = new BGE.DrawableParticles(m.entity, "rectangle")
      emitter.burst(5)
      m.assertEqual(5, m.drawOnce(emitter))
    end function

    @it("issues one draw call per live line particle")
    function _()
      emitter = new BGE.DrawableParticles(m.entity, "line", {velocity: BGE.Math.VectorOps.create(10, 0)})
      emitter.burst(3)
      m.assertEqual(3, m.drawOnce(emitter))
    end function

    @it("registers exactly one SceneObject regardless of live particle count")
    function _()
      emitter = new BGE.DrawableParticles(m.entity, "rectangle")
      emitter.burst(20)
      m.assertEqual(1, emitter.getSceneObjects().count())
    end function

    @describe("participatesInOverlapDetection")
    @it("opts out of overlap-cluster candidacy")
    function _()
      emitter = new BGE.DrawableParticles(m.entity, "rectangle")
      sceneObj = emitter.addToScene(m.renderer)
      m.assertFalse((sceneObj as BGE.SceneObjectParticle).participatesInOverlapDetection())
    end function
  end class
end namespace
```

- [ ] **Step 2: Build the tests and confirm they fail**

Run: `npm run build-tests`
Expected: FAIL — the stub `SceneObjectParticle` draws nothing, so the "one draw call per particle" assertions fail (actual `0`, expected `5`/`3`).

- [ ] **Step 3: Implement the real `SceneObjectParticle`**

Replace the stub in `src/source/engine/renderer/sceneObjects/SceneObjectParticle.bs`:

```brighterscript
namespace BGE
  ' Draws an entire DrawableParticles emitter's live particles with a single SceneObject
  ' - not one SceneObject per particle. See
  ' specs/2026-08-18-particle-system-design.md ("Why one SceneObjectParticle per
  ' emitter, not per particle") for why: per-particle SceneObjects would call
  ' Renderer.addSceneObject/removeSceneObject every frame during continuous emission,
  ' permanently defeating the depth-sort skip-optimization for the whole renderer.
  class SceneObjectParticle extends SceneObject
    drawable as DrawableParticles

    sub new(name as string, drawableObj as DrawableParticles)
      super(name, drawableObj, BGE.SceneObjectType.Particle)
    end sub

    ' A multi-particle emitter can't pass the narrow-phase hull-validity check as a
    ' single object, and clustering doesn't add anything here since particles already
    ' draw as one batched unit - skip broad-phase candidacy entirely.
    override function participatesInOverlapDetection() as boolean
      return false
    end function

    protected override function performDraw(rendererObj as BGE.Renderer, drawMode as SceneObjectDrawMode) as boolean
      didDrawAny = false

      for each particle in m.drawable.particles
        canvasPos = rendererObj.worldPointToCanvasPoint(particle.position)
        if canvasPos = invalid
          continue for
        end if

        t = particle.age / particle.lifetime
        color = BGE.lerpColorRGB(particle.startColor, particle.endColor, t)
        alpha = BGE.Math.lerp(particle.startAlpha, particle.endAlpha, t) / 255.0
        rgba = BGE.RGBAtoRGBA((color >> 16) and &hFF, (color >> 8) and &hFF, color and &hFF, alpha)
        size = BGE.Math.lerp(particle.startSize, particle.endSize, t)

        if m.drawable.shape = "line"
          didDrawAny = m.drawLineParticle(rendererObj, particle, canvasPos, size, rgba) or didDrawAny
        else if m.drawable.shape = "rectangle"
          half = size / 2.0
          didDrawAny = rendererObj.drawRectangle(canvasPos.x - half, canvasPos.y - half, size, size, rgba) or didDrawAny
        else if m.drawable.shape = "image" and m.drawable.image <> invalid
          didDrawAny = rendererObj.drawRegion(m.drawable.image, canvasPos.x, canvasPos.y, size, size, particle.rotation, rgba) or didDrawAny
        end if
      end for

      return didDrawAny
    end function

    private function drawLineParticle(rendererObj as BGE.Renderer, particle as object, canvasPos as BGE.Math.Vector, length as float, rgba as integer) as boolean
      direction = BGE.Math.VectorOps.create(1, 0)
      if not BGE.Math.VectorOps.isZero(particle.velocity)
        direction = BGE.Math.VectorOps.getNormalizedCopy(particle.velocity)
      end if
      endWorldPos = BGE.Math.VectorOps.add(particle.position, BGE.Math.VectorOps.scale(direction, length))
      endCanvasPos = rendererObj.worldPointToCanvasPoint(endWorldPos)
      if endCanvasPos = invalid
        return false
      end if
      return rendererObj.drawLine(canvasPos.x, canvasPos.y, endCanvasPos.x, endCanvasPos.y, rgba)
    end function
  end class
end namespace
```

- [ ] **Step 4: Run the tests and confirm they pass**

Run: `npm run build-tests && npm run test:ci`
Expected: PASS for every `@it` block above.

- [ ] **Step 5: Validate and commit**

Run: `npm run validate`
Expected: no type errors.

```bash
git add src/source/engine/renderer/sceneObjects/SceneObjectParticle.bs src/source/engine/renderer/sceneObjects/SceneObjectParticle.spec.bs
git commit -m "Implement SceneObjectParticle's per-emitter draw loop (#86)

Replaces the Task 2 stub. One direct draw call per live particle, shape
determined by the owning DrawableParticles - no per-particle SceneObject
registration.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 4: `GameEntity.addParticles()` convenience method

**Files:**
- Modify: `src/source/engine/GameEntity.bs`
- Modify: `src/source/engine/GameEntity.spec.bs` (already exists — confirmed via `src/source/engine/GameEntity.spec.bs:13`, `m.entity = new BGE.GameEntity(m.game, {name: "TestEntity"})` in its `beforeEach`)

**Interfaces:**
- Consumes: `DrawableParticles.new(owner as GameEntity, shape as string, args as roAssociativeArray)` (Task 2), `GameEntity.addDrawable(imageName as string, drawableObject as Drawable, insertPosition as integer) as Drawable` (existing).
- Produces: `GameEntity.addParticles(particlesName as string, shape as string, args = {} as roAssociativeArray, insertPosition = -1 as integer) as DrawableParticles`, used by Task 5's example.

- [ ] **Step 1: Read the existing `GameEntity.spec.bs` to match its style**

Run: `cat src/source/engine/GameEntity.spec.bs`

Confirm the `@suite`/`beforeEach` pattern (a real `m.game`/`m.entity`, per this repo's convention) so the new `@it` block below fits alongside its existing ones as a sibling, not a divergent style.

- [ ] **Step 2: Write the failing test**

Add this `@it` block to the existing `@suite` class in `src/source/engine/GameEntity.spec.bs`:

```brighterscript
@describe("addParticles")
@it("adds a DrawableParticles configured with the given shape")
function _()
  emitter = m.entity.addParticles("sparks", "line", {spawnRate: 10.0})
  m.assertEqual("line", emitter.shape)
  m.assertEqual(10.0, emitter.spawnRate)
end function
```

- [ ] **Step 3: Build the tests and confirm they fail**

Run: `npm run build-tests`
Expected: FAIL — `addParticles` is undefined on `GameEntity`.

- [ ] **Step 4: Implement `addParticles`**

In `src/source/engine/GameEntity.bs`, add near `addCircle`/`addRectangle` (matching their exact JSDoc/body style):

```brighterscript
    ' Adds a particle emitter to be drawn for this entity. See DrawableParticles for the
    ' full set of configurable behavior (spawnRate, lifetime, velocity/spread,
    ' acceleration, color/alpha/size-over-lifetime, maxParticles) and its start()/stop()/
    ' burst() control API.
    '
    ' @param {string} particlesName - Name of the particle emitter drawable
    ' @param {string} shape - "line", "rectangle", or "image" - see DrawableParticles.shape
    ' @param [args={}] - any extra properties to set (e.g. spawnRate, lifetime, velocity, acceleration, startColor, endColor, startAlpha, endAlpha, startSize, endSize, maxParticles)
    ' @param {integer} [insertPosition=-1] - the position/order in the drawables array where the emitter should be added (defaults to being added at the end)
    ' @return {DrawableParticles} - The particle emitter that was added, or `invalid` if there was an error
    function addParticles(particlesName as string, shape as string, args = {} as roAssociativeArray, insertPosition = -1 as integer) as DrawableParticles
      particlesObject = new DrawableParticles(m, shape, args)
      return m.addDrawable(particlesName, particlesObject, insertPosition) as DrawableParticles
    end function
```

- [ ] **Step 5: Run the tests and confirm they pass**

Run: `npm run build-tests && npm run test:ci`
Expected: PASS.

- [ ] **Step 6: Validate and commit**

Run: `npm run validate`
Expected: no type errors.

```bash
git add src/source/engine/GameEntity.bs src/source/engine/GameEntity.spec.bs
git commit -m "Add GameEntity.addParticles() convenience method (#86)

Mirrors addCircle/addRectangle/addSphere's existing pattern.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 5: `examples/particles` demo + on-device verification

**Files:**
- Create: `examples/particles/` (via `npm run create-example`)
- Create: `examples/particles/src/source/Rooms/LineParticlesRoom.bs`, `RectangleParticlesRoom.bs`, `ImageParticlesRoom.bs`, `BurstRoom.bs`, `StressRoom.bs` (via `npm run create-room`)
- Modify: `examples/particles/src/source/main.bs` (room registration, `getRoomNames()`-style room switching if the scaffold includes one — check `MainRoom.bs`'s scaffolded `onInput` first)

**Interfaces:**
- Consumes: `GameEntity.addParticles(...)` (Task 4).

This task has no Rooibos spec of its own — per CLAUDE.md, automated tests don't exercise example app code at all, and this repo's standing rule is that on-device/simulator verification via the `rokubot-examples` skill is mandatory before considering runtime behavior of a new/changed example verified, not optional polish.

- [ ] **Step 1: Scaffold the example project**

```bash
npm run create-example -- particles "Particles"
```

Expected: creates `examples/particles/` (manifest, bsconfig, `.vscode/*`, `src/source/main.bs`, `src/source/Rooms/MainRoom.bs`, generated icon/splash images) and registers it in the root `.vscode/tasks.json`.

- [ ] **Step 2: Install the example's own dependencies**

```bash
cd examples/particles && npm install && cd ../..
```

Expected: `examples/particles/node_modules/` populated, including the engine via ropm.

- [ ] **Step 3: Scaffold the demo rooms**

```bash
npm run create-room -- particles LineParticlesRoom
npm run create-room -- particles RectangleParticlesRoom
npm run create-room -- particles ImageParticlesRoom
npm run create-room -- particles BurstRoom
npm run create-room -- particles StressRoom
```

Expected: five new files under `examples/particles/src/source/Rooms/`, each a `BGE.Room` subclass stub with `onCreate`/`onInput`.

- [ ] **Step 4: Read the scaffolded `MainRoom.bs` and `main.bs` to match the existing room-switching convention**

Run: `cat examples/particles/src/source/Rooms/MainRoom.bs examples/particles/src/source/main.bs`

Other multi-room examples (e.g. `examples/3d`, `examples/depthsort`) use a `"back"`-to-return-to-menu / next-button-to-cycle convention with an array of room names — follow whatever pattern the scaffold already sets up rather than inventing a new one. Every room's `onInput` back-check must be `input.press and input.isButton("back")` (Global Constraints, above) — copy that guard exactly.

- [ ] **Step 5: Implement `LineParticlesRoom`**

Follow the `MainRoom.bs` convention confirmed in `examples/asteroids` (`m.game.addEntity(new PauseHandler(m.game))`) — construct the entity, then register it with `m.game.addEntity(...)`:

```brighterscript
namespace examples.particles
  class LineParticlesRoom extends BGE.Room
    sparks as BGE.GameEntity

    override sub onCreate()
      m.sparks = new BGE.GameEntity(m.game, {name: "Sparks", position: BGE.Math.VectorOps.create(m.game.canvas.getWidth() / 2, m.game.canvas.getHeight() / 2)})
      m.game.addEntity(m.sparks)
      emitter = m.sparks.addParticles("sparks", "line", {
        spawnRate: 60
        lifetime: 0.6
        lifetimeSpread: 0.2
        velocitySpreadMagnitude: 220
        startColor: BGE.ColorsRGB.Yellow
        endColor: BGE.ColorsRGB.Red
        startAlpha: 255
        endAlpha: 0
        startSize: 14
        endSize: 4
        maxParticles: 200
      })
      emitter.start()
    end sub

    override sub onInput(input as BGE.GameInput)
      if input.press and input.isButton("back")
        m.game.End()
      end if
    end sub
  end class
end namespace
```

`BGE.ColorsRGB.Yellow`/`BGE.ColorsRGB.Red` are confirmed members (`src/source/utils/colors.bs`'s `ColorsRGB` enum) — no substitution needed.

- [ ] **Step 6: Implement `RectangleParticlesRoom`**

Same structure as Step 5, but:

```brighterscript
emitter = m.debris.addParticles("debris", "rectangle", {
  spawnRate: 20
  lifetime: 2.0
  velocitySpreadAngleDegrees: 30
  velocitySpreadMagnitude: 150
  acceleration: BGE.Math.VectorOps.create(0, -300) ' gravity - +y is world-up, see GameInput's convention
  startColor: BGE.ColorsRGB.Silver
  endColor: BGE.ColorsRGB.Gray
  startSize: 12
  endSize: 3
  maxParticles: 150
})
emitter.start()
```

- [ ] **Step 7: Implement `ImageParticlesRoom`**

`Game.loadBitmap(bitmapName as string, path as dynamic) as boolean` (`src/source/engine/Game.bs:1499`) populates `m.game.Bitmaps[bitmapName]` — the same call every other example uses (e.g. `examples/asteroids/src/source/main.bs:5`, `game.loadBitmap("rocket", "pkg:/sprites/rocket_off.png")`). Add a small sprite to `examples/particles/src/images/` (reuse an existing example's sprite file, e.g. copy `examples/asteroids/src/images/rock_a.png` in as `spark.png`), load it in `main.bs`'s `Main()` before `game.changeRoom(...)` — `game.loadBitmap("spark", "pkg:/images/spark.png")` — then:

```brighterscript
emitter = m.confetti.addParticles("confetti", "image", {
  spawnRate: 15
  lifetime: 1.5
  velocitySpreadAngleDegrees: 45
  velocitySpreadMagnitude: 100
  rotationSpeed: 180
  startSize: 1.0
  endSize: 0.4
  startAlpha: 255
  endAlpha: 0
  maxParticles: 100
})
emitter.image = m.game.getBitmap("spark")
emitter.start()
```

- [ ] **Step 8: Implement `BurstRoom`**

Demonstrates `burst(count)` as a discrete, one-shot event (e.g. on an input press) rather than continuous emission — guard with `input.press and input.isButton(...)` per Global Constraints, calling `emitter.burst(50)` each press.

- [ ] **Step 9: Implement `StressRoom`**

Spawns an emitter (or several) configured near `maxParticles` (e.g. `maxParticles: 500`, high `spawnRate`) specifically to read real fps/draw-call numbers on-device — this is the room the design spec's "measure via examples/particles" testing plan is actually asking for. Enable the FPS debug overlay in `onCreate()` via `m.game.enableStandardDebugUi({log: false})` (per this repo's existing convention) so the number is visible on-screen without needing `rokubot`'s own instrumentation.

- [ ] **Step 10: Wire room registration in `main.bs`**

Follow the exact pattern already present in the scaffolded `main.bs` (`game.defineRoom(...)` / `game.changeRoom(...)`) — add all five new rooms and whatever menu/cycling entity the scaffold's `MainRoom` convention expects.

- [ ] **Step 11: Validate the example**

```bash
npm run build && cd examples/particles && npm run build && cd ../..
```

Expected: both build cleanly with no `bsc` errors.

- [ ] **Step 12: On-device/simulator verification (mandatory, not optional)**

Load the `rokubot-examples` skill and use it to sideload, launch, and step through each room of `examples/particles` on a real Roku or simulator, screenshotting each. Specifically confirm:
- Each shape (line/rectangle/image) actually renders and visually matches its config (color fades, gravity pulls rectangles down, images rotate).
- `BurstRoom` spawns exactly on press, not on both press and release (the `GameInput` double-fire gotcha from CLAUDE.md).
- `StressRoom`'s FPS overlay stays legible and reports a real number — note the actual fps at `maxParticles` particles live, since that number is what informs whether this feature's default `maxParticles` needs tuning (per the design spec).
- No crash navigating between rooms or pressing "back".

Per CLAUDE.md and `feedback_no_realtime_game_play` — do not attempt to judge continuous animation smoothness by rapid act→screenshot polling; take a handful of screenshots per room and report the FPS overlay's number plus what's visually on screen, and ask the user to spot-check live smoothness themselves if that matters.

- [ ] **Step 13: Commit**

```bash
git add examples/particles .vscode/tasks.json
git commit -m "Add examples/particles demo for DrawableParticles (#86)

One room per shape, a burst-vs-continuous-emission contrast, and a
stress room for on-device fps/draw-call numbers near maxParticles.
Verified on-device via rokubot-examples.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 6: Animated sprite-sheet particles (engine support)

**Added mid-execution, per direct user request** (not in the original design spec) — see `specs/2026-08-18-particle-system-design.md`'s addendum, or the SDD ledger, for the reference asset (opengameart.org "Fireball Particle Sheet", CC-BY 3.0, a 4x4/16-frame grid whose frames already fade from bright to transparent). The `"image"` shape currently draws one static bitmap for a particle's whole life; this task adds an opt-in sprite-sheet mode, driven directly by `age/lifetime` rather than an independent frame-rate timer, since that's what makes a fade-style sheet like this one reproduce its own fade for free.

This mirrors `Sprite.bs`'s existing `cellWidth`/`cellHeight` grid-slicing convention (`Sprite.bs:88-95`, row-major `CreateObject("roRegion", bitmap, col * cellWidth, row * cellHeight, cellWidth, cellHeight)`) rather than inventing new naming — deliberate consistency with how every other spritesheet-based drawable in this engine already names this concept.

**Files:**
- Modify: `src/source/engine/drawables/DrawableParticles.bs`
- Modify: `src/source/engine/drawables/DrawableParticles.spec.bs`
- Modify: `src/source/engine/renderer/sceneObjects/SceneObjectParticle.bs`
- Modify: `src/source/engine/renderer/sceneObjects/SceneObjectParticle.spec.bs`

**Interfaces:**
- Consumes: `roRegion` construction (`CreateObject("roRegion", bitmap, x, y, w, h)`), same as `Sprite.setCellRegions()`.
- Produces (for Task 7's example room): `DrawableParticles.cellWidth as integer = 0`, `DrawableParticles.cellHeight as integer = 0` (config fields — both `>0` opts a `shape: "image"` emitter into sprite-sheet mode), and `DrawableParticles.getFrameRegions() as roRegion[]` (lazily slices `image` into a row-major grid on first call, caches it; returns `invalid` if `image` isn't set yet or `cellWidth`/`cellHeight` aren't both `>0` — i.e. "not a sprite sheet, caller should fall back to the whole bitmap").
- Produces: `SceneObjectParticle.performDraw`'s image branch picks a per-particle frame region via `getFrameRegions()[frameIndex]` when sprite-sheet mode is active, where `frameIndex` is `Int((particle.age / particle.lifetime) * frameCount)` manually bounds-checked into `[0, frameCount - 1]` (not `BGE.Math.Clamp`, which returns a `float` — an integer array index needs the manual bounds check shown in Step 5) — falls back to drawing `m.drawable.image` whole, unchanged from before this task, when `getFrameRegions()` returns `invalid`. Fully backward compatible: existing Task 3 tests (single static image, `cellWidth`/`cellHeight` left at their `0` default) must keep passing unmodified.

- [ ] **Step 1: Write the failing tests**

Add to `src/source/engine/drawables/DrawableParticles.spec.bs` (existing `@suite` class):

```brighterscript
@describe("getFrameRegions")
@it("returns invalid when cellWidth/cellHeight are not set (not a sprite sheet)")
function _()
  emitter = new BGE.DrawableParticles(m.entity, "image")
  m.assertEqual(invalid, emitter.getFrameRegions())
end function

@it("returns invalid when image is not set, even with cellWidth/cellHeight set")
function _()
  emitter = new BGE.DrawableParticles(m.entity, "image", {cellWidth: 16, cellHeight: 16})
  m.assertEqual(invalid, emitter.getFrameRegions())
end function

@it("slices a sprite sheet into a row-major grid of regions")
function _()
  sheet = CreateObject("roBitmap", {width: 64, height: 32, alphaEnable: true})
  emitter = new BGE.DrawableParticles(m.entity, "image", {cellWidth: 16, cellHeight: 16})
  emitter.image = sheet
  regions = emitter.getFrameRegions()
  m.assertEqual(8, regions.count()) ' 64/16=4 cols x 32/16=2 rows
end function

@it("caches the sliced regions across repeated calls")
function _()
  sheet = CreateObject("roBitmap", {width: 32, height: 16, alphaEnable: true})
  emitter = new BGE.DrawableParticles(m.entity, "image", {cellWidth: 16, cellHeight: 16})
  emitter.image = sheet
  first = emitter.getFrameRegions()
  second = emitter.getFrameRegions()
  m.assertEqual(first.count(), second.count())
end function
```

Add to `src/source/engine/renderer/sceneObjects/SceneObjectParticle.spec.bs` (existing `@suite` class):

```brighterscript
@describe("animated sprite-sheet image particles")
@it("still draws one call per particle when the image emitter is configured as a sprite sheet")
function _()
  sheet = CreateObject("roBitmap", {width: 32, height: 16, alphaEnable: true})
  emitter = new BGE.DrawableParticles(m.entity, "image", {cellWidth: 16, cellHeight: 16})
  emitter.image = sheet
  emitter.burst(4)
  m.assertEqual(4, m.drawOnce(emitter))
end function
```

- [ ] **Step 2: Build the tests and confirm they fail**

Run: `npm run build-tests`
Expected: FAIL — `getFrameRegions` is undefined.

- [ ] **Step 3: Implement `DrawableParticles.getFrameRegions()`**

Add to `src/source/engine/drawables/DrawableParticles.bs`, near the `image` field:

```brighterscript
    ' Width/height (pixels) of one animation cell if `image` is a sprite sheet, "image"
    ' shape only. When both are >0, `image` is sliced into a row-major grid of frames and
    ' each particle's current frame is driven by its own age/lifetime - a fade-style sheet
    ' (bright to transparent) reproduces its own fade this way, with no extra frame-rate
    ' config needed. 0 (the default) means `image` is drawn as a single static bitmap,
    ' unchanged from previous behavior.
    cellWidth as integer = 0
    cellHeight as integer = 0

    protected regions as roRegion[] = invalid
```

And this method, near `spawnParticle`:

```brighterscript
    ' Lazily slices `image` into a row-major grid of `cellWidth` x `cellHeight` regions
    ' (built once, cached) - mirrors Sprite.setCellRegions()'s exact slicing convention.
    '
    ' @return {roRegion[]} the per-frame regions, or `invalid` if this emitter isn't
    '   configured as a sprite sheet (cellWidth/cellHeight are 0) or `image` isn't set yet
    function getFrameRegions() as roRegion[]
      if m.image = invalid or m.cellWidth <= 0 or m.cellHeight <= 0
        return invalid
      end if
      if m.regions = invalid
        cols = cint(m.image.getWidth() / m.cellWidth)
        rows = cint(m.image.getHeight() / m.cellHeight)
        m.regions = []
        for row = 0 to rows - 1
          for col = 0 to cols - 1
            m.regions.push(CreateObject("roRegion", m.image, col * m.cellWidth, row * m.cellHeight, m.cellWidth, m.cellHeight))
          end for
        end for
      end if
      return m.regions
    end function
```

- [ ] **Step 4: Run the tests and confirm the new `DrawableParticles` tests pass**

Run: `npm run build-tests && npm run test:ci`
Expected: PASS for the four new `getFrameRegions` tests. The `SceneObjectParticle` test still fails at this point (frame-region drawing isn't wired up yet) — that's expected.

- [ ] **Step 5: Implement the frame-region draw path in `SceneObjectParticle`**

In `src/source/engine/renderer/sceneObjects/SceneObjectParticle.bs`, replace the existing image branch in `performDraw`:

```brighterscript
        else if m.drawable.shape = "image" and m.drawable.image <> invalid
          regionToDraw = m.drawable.image
          frameRegions = m.drawable.getFrameRegions()
          if frameRegions <> invalid and frameRegions.count() > 0
            frameIndex = Int(t * frameRegions.count())
            if frameIndex >= frameRegions.count()
              frameIndex = frameRegions.count() - 1
            end if
            if frameIndex < 0
              frameIndex = 0
            end if
            regionToDraw = frameRegions[frameIndex]
          end if
          didDrawAny = rendererObj.drawRegion(regionToDraw, canvasPos.x, canvasPos.y, size, size, particle.rotation, rgba) or didDrawAny
        end if
```

- [ ] **Step 6: Run the full suite and confirm everything passes, including Task 3's original static-image test**

Run: `npm run build-tests && npm run test:ci`
Expected: PASS for all tests, including the pre-existing "issues one draw call per live line/rectangle particle" tests from Task 3 (unaffected — they don't use `shape: "image"`) and the pre-existing image-shape behavior (no `cellWidth`/`cellHeight` set → `getFrameRegions()` returns `invalid` → falls back to `m.drawable.image` exactly as before this task).

- [ ] **Step 7: Validate and commit**

Run: `npm run validate`
Expected: no type errors.

```bash
git add src/source/engine/drawables/DrawableParticles.bs src/source/engine/drawables/DrawableParticles.spec.bs src/source/engine/renderer/sceneObjects/SceneObjectParticle.bs src/source/engine/renderer/sceneObjects/SceneObjectParticle.spec.bs
git commit -m "Support animated sprite-sheet image particles (#86)

Opt-in via cellWidth/cellHeight (mirrors Sprite's own grid-slicing
convention). Frame index is driven directly by age/lifetime rather than
an independent frame-rate timer, so a fade-style sheet reproduces its own
fade for free. Falls back to the existing single-bitmap behavior
unchanged when not configured as a sheet.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 7: `AnimatedImageParticlesRoom` example + asset credit

**Files:**
- Add (asset — see note below): `examples/particles/src/sprites/fireball.png`
- Create: `examples/particles/src/sprites/CREDITS.md`
- Create: `examples/particles/src/source/Rooms/AnimatedImageParticlesRoom.bs` (via `npm run create-room`)
- Modify: `examples/particles/src/source/main.bs` (load the bitmap, register the room, add it to the room-cycle array)

**Interfaces:**
- Consumes: `GameEntity.addParticles(...)` (Task 4), `DrawableParticles.cellWidth`/`cellHeight` (Task 6).

**Asset:** `examples/particles/src/sprites/fireball.png` (the opengameart.org "Fireball Particle Sheet", CC-BY 3.0, credited to Davididev/davididev.com per the license page) is already in place, confirmed 512x512 pixels, a 4x4 grid of 16 frames — so **`cellWidth: 128, cellHeight: 128`** exactly (512/4 = 128 each dimension). Confirm the file is still there before starting (`ls -la examples/particles/src/sprites/fireball.png`), but the dimensions below are already verified, not a placeholder to fill in.

- [ ] **Step 1: Confirm the asset is present**

Run: `ls -la examples/particles/src/sprites/fireball.png`
Expected: file exists (512x512 PNG). If missing, stop and report NEEDS_CONTEXT — do not substitute a placeholder.

- [ ] **Step 2: Add the credits file**

Create `examples/particles/src/sprites/CREDITS.md`, following the exact convention already established in `examples/parallax/src/sprites/CREDITS.md`:

```markdown
# Art Credits

The fireball sprite sheet (`fireball.png`) is the
["Fireball Particle Sheet"](https://opengameart.org/content/fireball-particle-sheet) by
[Davididev](https://davididev.com), licensed
[CC-BY 3.0](https://creativecommons.org/licenses/by/3.0/) - attribution required.
```

- [ ] **Step 3: Scaffold the room**

```bash
npm run create-room -- particles AnimatedImageParticlesRoom
```

- [ ] **Step 4: Implement the room**

Read `examples/particles/src/source/Rooms/ImageParticlesRoom.bs` first (Task 5) to match its exact structure/conventions (constructor vs. `onCreate`, back-navigation, room-cycling calls via `util.bs`'s `goToNextRoom`) — this room is the same shape with sprite-sheet config added:

```brighterscript
namespace examples.particles
  class AnimatedImageParticlesRoom extends BGE.Room
    fireballs as BGE.GameEntity

    override sub onCreate()
      m.fireballs = new BGE.GameEntity(m.game, {name: "Fireballs", position: BGE.Math.VectorOps.create(m.game.canvas.getWidth() / 2, m.game.canvas.getHeight() / 2)})
      m.game.addEntity(m.fireballs)
      emitter = m.fireballs.addParticles("fireballs", "image", {
        spawnRate: 8
        lifetime: 1.2
        velocitySpreadAngleDegrees: 360
        velocitySpreadMagnitude: 60
        startSize: 0.5
        endSize: 0.5
        cellWidth: 128
        cellHeight: 128
        maxParticles: 40
      })
      emitter.image = m.game.getBitmap("fireball")
      emitter.start()
    end sub

    override sub onInput(input as BGE.GameInput)
      if input.press and input.isButton("back")
        m.game.End()
      else if input.press and input.isButton("fastforward")
        examples.particles.goToNextRoom(m, 1)
      else if input.press and input.isButton("rewind")
        examples.particles.goToNextRoom(m, -1)
      end if
    end sub
  end class
end namespace
```

`cellWidth`/`cellHeight` are already confirmed above (128/128, from the sheet's verified 512x512/4x4 dimensions) — not a placeholder. Match the `onInput`/room-cycling calls to whatever `util.bs` actually exports (Task 5's report says a `goToNextRoom(currentRoom, direction)` helper in `examples.particles`'s `util.bs` — read it to get the exact call signature right, the snippet above is illustrative). `startSize`/`endSize` of `0.5` scale the 128px frame down to a 64px on-canvas particle — adjust only if it looks visually wrong on-device in Step 7, not before.

- [ ] **Step 5: Wire it into `main.bs`**

Add `game.loadBitmap("fireball", "pkg:/sprites/fireball.png")` alongside the existing `game.loadBitmap("spark", ...)` call, add `AnimatedImageParticlesRoom` to the local `getRoomNames()` array (Task 5's fix for definition-order cycling) in whatever position makes sense in the cycle (e.g. right after `ImageParticlesRoom`), and register it via `game.defineRoom(...)` alongside the other five rooms.

- [ ] **Step 6: Validate the build**

```bash
npm run build && cd examples/particles && npm run build && cd ../..
```
Expected: both build cleanly.

- [ ] **Step 7: On-device verification for this one new room**

Load the `rokubot-examples` skill and verify specifically: the fireball sheet's frames actually cycle/animate per-particle over each particle's lifetime (not a single static frame), the fade-to-transparent progression is visible, and cycling to/from this room via `fastforward`/`rewind` works cleanly alongside the other five rooms. You do not need to re-verify the other five rooms (Task 5 already did) — this is a scoped, single-room check.

- [ ] **Step 8: Commit**

```bash
git add examples/particles
git commit -m "Add AnimatedImageParticlesRoom demo (#86)

Fireball sprite sheet by Davididev (opengameart.org), CC-BY 3.0 - see
examples/particles/src/sprites/CREDITS.md.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 8: Documentation

**Files:**
- Modify: `docs/drawables-and-scene-objects.md`
- Modify: `CLAUDE.md`

**Interfaces:** none — this task only edits prose.

- [ ] **Step 1: Read the existing guide's structure**

Run: `cat docs/drawables-and-scene-objects.md`

Follow its existing per-drawable/scene-object-pair walkthrough structure and heading level exactly — per `feedback_docs_fundamentals_over_gotchas`, lead with how-to/what-it-does, fold the "why one SceneObjectParticle per emitter, not per particle" performance rationale in as a subordinate aside rather than a standalone section.

- [ ] **Step 2: Add the `DrawableParticles`/`SceneObjectParticle` section**

Write a new subsection (matching the file's existing heading depth) covering: what it's for, the config surface (spawn rate, lifetime, velocity/spread, acceleration, color/alpha/size-over-lifetime, `maxParticles`), the `start()`/`stop()`/`burst()` API, the opt-in `cellWidth`/`cellHeight` sprite-sheet animation mode for `"image"` particles (Task 6/7 — frame driven by `age/lifetime`, mirroring `Sprite`'s own grid-slicing convention), and — as an aside, not a lead — the one-SceneObject-per-emitter batching rationale with a link to `specs/2026-08-18-particle-system-design.md` for the full reasoning.

- [ ] **Step 3: Update `CLAUDE.md`'s drawable/scene-object subclass lists**

In the "Entities, Rooms, Drawables" section, add `DrawableParticles` to the existing parenthetical list (`Image, Sprite, AnimatedImage, DrawableRectangle, DrawableLine, DrawablePolygon, DrawableText, DrawableCircle, DrawableSphere, Model3d, DrawablePlane` → append `, DrawableParticles`).

In the "Renderer / SceneObjects" section, add `SceneObjectParticle` to the existing list (`SceneObjectImage, SceneObjectBillboard, SceneObjectLine, SceneObjectPolygon, SceneObjectRectangle, SceneObjectText, SceneObjectCircle, SceneObjectModel, SceneObjectPlane` → append `, SceneObjectParticle`), and add one sentence noting it's the one documented exception to "one SceneObject per Drawable" in this codebase, with a pointer to the design spec.

- [ ] **Step 4: Regenerate the docs site locally to confirm it builds**

Run: `npm run docs`
Expected: no errors; `docs-site/` regenerates (gitignored, not committed).

- [ ] **Step 5: Commit**

```bash
git add docs/drawables-and-scene-objects.md CLAUDE.md
git commit -m "Document DrawableParticles/SceneObjectParticle (#86)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Final check before considering this done

- [ ] `npm run check` passes (lint, validate, headless tests).
- [ ] `npm run validate-examples` passes, including the new `examples/particles`.
- [ ] Task 5 Step 12's on-device verification actually happened and its findings (fps at max particles, any visual issues) are reported to the user, per `feedback_static_analysis_insufficient_for_examples` — do not claim this feature works on a real/simulated Roku without having run it.
- [ ] Task 7 Step 7's on-device verification of `AnimatedImageParticlesRoom` actually happened (sheet frames genuinely cycle per-particle, not a static frame).
- [ ] `examples/particles/src/sprites/CREDITS.md` correctly attributes the fireball sheet (CC-BY 3.0, Davididev).
- [ ] `package.json`/`package-lock.json`'s local `brighterscript` `file:` link was never staged/committed in any of the above commits (per this branch's own housekeeping constraint).
