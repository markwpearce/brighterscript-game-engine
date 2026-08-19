# Camera Roll and Plane Horizon Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give `Camera3d` a real roll axis (rotation about its own forward/view axis) that correctly banks every 3D-projected object (billboards, models) and renders the ground plane's horizon at the matching angle, plus live pitch/roll controls in `examples/terrain` to exercise and verify it.

**Architecture:** `Camera3d.rollDegrees` drives roll-aware `getUpVector()`/`getRightVector()`, which feed a now roll-aware view matrix (`Matrix44.lookAt` gains an up-vector parameter) — this alone makes ordinary per-point-projected 3D objects bank correctly. `SceneObjectPlane` can't use per-point projection (it rasterizes via horizontal trapezoid slices), so it instead computes all of its geometry against an *unrolled* ("level") camera - using new `getLevelUpVector()`/`getLevelRightVector()` helpers - into a canvas enlarged to the frame's diagonal, then rotates that composite by `-rollDegrees` and center-crops it onto the real frame. This is mathematically exact for a pure roll (perspective division commutes with an in-plane rotation about the optical axis), and reduces to today's unchanged behavior whenever `rollDegrees = 0`.

**Tech Stack:** BrighterScript (compiles to BrightScript/.brs for Roku), Rooibos v6 for unit tests, `brs-cli` for headless CI test runs, `rokubot` for on-device/simulator verification.

**Spec:** `specs/2026-08-19-camera-roll-and-plane-horizon-design.md`

## Global Constraints

- Positive `rollDegrees` = aviation convention, right side down.
- `rollDegrees = 0` must reproduce today's rendering exactly, byte-for-byte in the math (no incidental behavior change for existing non-rolled camera users) - verified by the existing Rooibos suites staying green throughout.
- `Camera2d`/base `Camera` are unaffected by every change in this plan - `Matrix44.lookAt`'s new parameter defaults to preserve their current behavior, and roll only exists on `Camera3d`.
- Follow existing JSDoc-comment conventions (`'` doc comments with `@param`/`@return`) on every new public method, per `CLAUDE.md`.
- Run `npm run validate` after any engine (`src/source/**`) change; run `npm run check` before any commit that finishes a task.
- On-device verification via the `rokubot-examples` skill is mandatory before this plan is considered done - not optional polish. See Task 10.

---

## File Structure

- `src/source/math/Matrix44.bs` - `lookAt()` gains an optional `up` parameter.
- `src/source/math/Matrix44.spec.bs` - new tests for `lookAt()`'s up-vector behavior.
- `src/source/engine/renderer/cameras/Camera3d.bs` - `rollDegrees` field; `getLevelUpVector()`/`getLevelRightVector()` (today's pre-roll math, kept under a new name); roll-aware `getUpVector()`/`getRightVector()`; `computeWorldToCameraMatrix()` passes the real up vector; roll dirty-checking; `getFocalLength()`/`getFovDegreesForCanvasSize()`; `getHorizonLine()` refactored onto a shared `horizonLineForMatrix()` helper plus a new `getLevelHorizonLine()`.
- `src/source/engine/renderer/cameras/Camera3d.spec.bs` - new tests for all of the above.
- `src/source/engine/renderer/Renderer.bs` - new `drawRotatedImageWithCenter()` convenience wrapper (default-canvas variant of the existing `drawRotatedImageWithCenterTo()`, matching every other `draw*`/`draw*To` pair already in this file).
- `src/source/engine/renderer/sceneObjects/SceneObjectPlane.bs` - geometry computed against an enlarged level view when `rollDegrees <> 0`; composite gets rotated/cropped before the final blit.
- `src/source/engine/renderer/sceneObjects/SceneObjectPlane.spec.bs` - new file; tests for the roll-canvas-sizing and enlarged-FOV math.
- `examples/terrain/src/source/Rooms/MainRoom.bs` - live pitch/roll controls, reset, debug-toggle moved to a held Back.
- `examples/terrain/src/source/Entities/RollMarker.bs` - new file; an oriented billboard planted along the track for independent visual confirmation of banking.
- `CLAUDE.md` - one-paragraph update noting `Camera3d` roll support, once implemented (Task 9).

---

### Task 1: `Matrix44.lookAt()` gains an up-vector parameter

**Files:**
- Modify: `src/source/math/Matrix44.bs:280` (the `lookAt` function)
- Test: `src/source/math/Matrix44.spec.bs`

**Interfaces:**
- Produces: `BGE.Math.lookAt(from as Vector, lookTo as Vector, up = {x: 0, y: 1, z: 0} as Vector) as float[][]` - same return shape as today (a camera-to-world basis matrix), with the third row (`camToWorld[1][...]`) now derived from the given `up` instead of always from world-up.

- [ ] **Step 1: Write the failing tests**

Add to `src/source/math/Matrix44.spec.bs` (after the existing `@describe` blocks, same file/class - do not create a second `@suite` class, per this repo's Rooibos gotcha):

```brighterscript
    @describe("lookAt")

    @it("defaults to world-up when no up vector is given")
    function _()
      withDefault = BGE.Math.lookAt(BGE.Math.VectorOps.create(0, 0, 0), BGE.Math.VectorOps.create(0, 0, -1))
      withExplicitWorldUp = BGE.Math.lookAt(BGE.Math.VectorOps.create(0, 0, 0), BGE.Math.VectorOps.create(0, 0, -1), BGE.Math.VectorOps.create(0, 1, 0))

      m.assertTrue(BGE.Math.Matrix44.equals(withDefault, withExplicitWorldUp))
    end function

    @it("rotates the resulting right/up basis when a non-default up vector is given")
    function _()
      ' Looking down -z with "up" pointing along +x (a 90 degree roll) should put
      ' the right axis (row 0) where the up axis normally sits, and the up axis
      ' (row 1) where the right axis normally sits, pointing down.
      level = BGE.Math.lookAt(BGE.Math.VectorOps.create(0, 0, 0), BGE.Math.VectorOps.create(0, 0, -1))
      rolled = BGE.Math.lookAt(BGE.Math.VectorOps.create(0, 0, 0), BGE.Math.VectorOps.create(0, 0, -1), BGE.Math.VectorOps.create(1, 0, 0))

      m.assertEqual(level[1][0], rolled[0][0])
      m.assertEqual(level[1][1], rolled[0][1])
      m.assertEqual(level[1][2], rolled[0][2])
    end function
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `npm run build-tests && npm run test:ci`
Expected: the second `lookAt` test FAILs (today's `lookAt` ignores any third argument and always uses world-up, so `rolled` equals `level` instead of being rotated).

- [ ] **Step 3: Implement**

In `src/source/math/Matrix44.bs`, change:

```brighterscript
  function lookAt(from as Vector, lookTo as Vector) as float[][]
    tmp = {x: 0, y: 1, z: 0}
```

to:

```brighterscript
  ' Builds a camera-to-world basis matrix looking from `from` toward `lookTo`, using
  ' `up` to resolve the remaining roll ambiguity around the view axis - defaults to
  ' world-up, matching every call site that doesn't care about roll (Camera2d, and
  ' Camera3d before roll support existed).
  '
  ' @param {Vector} from
  ' @param {Vector} lookTo
  ' @param {Vector} [up={x:0,y:1,z:0}]
  ' @return {float[][]}
  function lookAt(from as Vector, lookTo as Vector, up = {x: 0, y: 1, z: 0} as Vector) as float[][]
    tmp = up
```

(Everything below `tmp = {x: 0, y: 1, z: 0}` already reads from the local `tmp` variable - no other line in the function body needs to change.)

- [ ] **Step 4: Run the tests to verify they pass**

Run: `npm run build-tests && npm run test:ci`
Expected: PASS. Also run `npm run validate` to confirm every existing call site of `lookAt(from, lookTo)` (currently only `Camera3d.computeWorldToCameraMatrix()`) still type-checks with the new optional parameter.

- [ ] **Step 5: Commit**

```bash
git add src/source/math/Matrix44.bs src/source/math/Matrix44.spec.bs
git commit -m "Add optional up-vector parameter to Matrix44.lookAt"
```

---

### Task 2: `Camera3d.rollDegrees` and roll-aware up/right vectors

**Files:**
- Modify: `src/source/engine/renderer/cameras/Camera3d.bs`
- Test: `src/source/engine/renderer/cameras/Camera3d.spec.bs`

**Interfaces:**
- Consumes: nothing new from Task 1 yet (this task is pure vector math).
- Produces:
  - `Camera3d.rollDegrees as float = 0` (public field)
  - `Camera3d.getLevelUpVector() as BGE.Math.Vector` - today's pre-roll `getUpVector()` body, unchanged, under a new name.
  - `Camera3d.getLevelRightVector() as BGE.Math.Vector` - today's pre-roll `getRightVector()` body, unchanged, under a new name.
  - `Camera3d.getUpVector()`/`getRightVector()` (existing overrides) now roll-aware: identical to the level vectors when `rollDegrees = 0`, otherwise rotated around `m.orientation` by `rollDegrees` (in radians) via `BGE.Math.RotateVectorAroundPoint3d`.

- [ ] **Step 1: Write the failing tests**

Add to `src/source/engine/renderer/cameras/Camera3d.spec.bs`:

```brighterscript
    @describe("rollDegrees")

    @it("matches the level up/right vectors when rollDegrees is 0")
    function _()
      m.camera.setTarget(BGE.Math.VectorOps.create(0, 0, -100))

      m.assertTrue(BGE.Math.VectorOps.equals(m.camera.getLevelUpVector(), m.camera.getUpVector()))
      m.assertTrue(BGE.Math.VectorOps.equals(m.camera.getLevelRightVector(), m.camera.getRightVector()))
    end function

    @it("rotates up toward the level right vector on a 90 degree right bank")
    function _()
      ' Default camera looks down -z with level up (0,1,0) and level right (1,0,0).
      ' A 90 degree right-bank puts "up" where "right" used to point - the pilot's
      ' view out the canopy now faces what used to be the horizontal right.
      m.camera.rollDegrees = 90

      up = m.camera.getUpVector()
      m.assertEqual(1.0, up.x)
      m.assertEqual(0.0, up.y)
      m.assertEqual(0.0, up.z)
    end function

    @it("rotates right toward straight down on a 90 degree right bank")
    function _()
      m.camera.rollDegrees = 90

      right = m.camera.getRightVector()
      m.assertEqual(0.0, right.x)
      m.assertEqual(-1.0, right.y)
      m.assertEqual(0.0, right.z)
    end function
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `npm run build-tests && npm run test:ci`
Expected: FAIL with "getLevelUpVector is not a function" (or similar) - it doesn't exist yet.

- [ ] **Step 3: Implement**

In `src/source/engine/renderer/cameras/Camera3d.bs`, add the `rollDegrees` field near `fieldOfViewDegrees`:

```brighterscript
    fieldOfViewDegrees as float = 90

    ' Rotation about the camera's own forward/view axis, in degrees. Positive = right
    ' side down (aviation convention). getUpVector()/getRightVector() apply this on
    ' top of the "level" vectors - see getLevelUpVector()/getLevelRightVector().
    rollDegrees as float = 0
```

Rename the existing overrides' bodies to new level-only methods, then rewrite the overrides to use them:

```brighterscript
    ' The "level" (rollDegrees = 0) up vector - see getUpVector() for the roll-aware
    ' version most callers want. SceneObjectPlane uses this one directly, since its
    ' ground rendering computes its own geometry against an unrolled view and applies
    ' roll as a final image rotation instead (see SceneObjectPlane).
    '
    ' @return {BGE.Math.Vector}
    function getLevelUpVector() as BGE.Math.Vector
      forward = BGE.Math.VectorOps.copy(m.orientation)
      BGE.Math.VectorOps.normalize(forward)

      worldUp = BGE.Math.VectorOps.create(0, 1, 0)
      right = BGE.Math.VectorOps.crossProduct(worldUp, forward)
      epsilon = 0.00001

      if BGE.Math.VectorOps.norm(right) <= epsilon
        worldUp = BGE.Math.VectorOps.create(0, 0, 1)
        right = BGE.Math.VectorOps.crossProduct(worldUp, forward)
      end if

      if BGE.Math.VectorOps.norm(right) <= epsilon
        return BGE.Math.VectorOps.create(0, 1, 0)
      end if

      BGE.Math.VectorOps.normalize(right)
      up = BGE.Math.VectorOps.crossProduct(forward, right)
      BGE.Math.VectorOps.normalize(up)
      return up
    end function

    ' The "level" (rollDegrees = 0) right vector - see getLevelUpVector().
    '
    ' @return {BGE.Math.Vector}
    function getLevelRightVector() as BGE.Math.Vector
      return BGE.Math.VectorOps.crossProduct(m.orientation, m.getLevelUpVector())
    end function

    ' Returns a normalized up vector that is perpendicular to the camera orientation,
    ' rotated around the forward axis by rollDegrees. This assumes a world-up
    ' preference (+Y) before roll is applied, with fallback when forward is parallel
    ' to +Y - see getLevelUpVector().
    override function getUpVector() as BGE.Math.Vector
      level = m.getLevelUpVector()
      if m.rollDegrees = 0
        return level
      end if
      return BGE.Math.RotateVectorAroundPoint3d(level, BGE.Math.VectorOps.create(), m.orientation, BGE.Math.DegreesToRadians(m.rollDegrees))
    end function


    override function getRightVector() as BGE.Math.Vector
      level = m.getLevelRightVector()
      if m.rollDegrees = 0
        return level
      end if
      return BGE.Math.RotateVectorAroundPoint3d(level, BGE.Math.VectorOps.create(), m.orientation, BGE.Math.DegreesToRadians(m.rollDegrees))
    end function
```

Remove the old (now-duplicate) `getUpVector`/`getRightVector` bodies you're replacing - there should be exactly one `getUpVector` and one `getRightVector` override left in the file, plus the two new `getLevel*` methods.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `npm run build-tests && npm run test:ci`
Expected: PASS. Also run the full suite to confirm nothing that depends on `getUpVector`/`getRightVector` at `rollDegrees = 0` (frustum normals/rays, `isInView`) regressed - all existing `Camera3dTests` assertions should still pass unchanged.

- [ ] **Step 5: Commit**

```bash
git add src/source/engine/renderer/cameras/Camera3d.bs src/source/engine/renderer/cameras/Camera3d.spec.bs
git commit -m "Add Camera3d.rollDegrees with roll-aware up/right vectors"
```

---

### Task 3: Wire the real view matrix to carry roll

**Files:**
- Modify: `src/source/engine/renderer/cameras/Camera3d.bs` (`computeWorldToCameraMatrix`)
- Test: `src/source/engine/renderer/cameras/Camera3d.spec.bs`

**Interfaces:**
- Consumes: `BGE.Math.lookAt(from, lookTo, up)` (Task 1), `Camera3d.getUpVector()` (Task 2).
- Produces: `Camera3d.computeWorldToCameraMatrix()` now roll-aware - no signature change, same override.

- [ ] **Step 1: Write the failing test**

Add to `src/source/engine/renderer/cameras/Camera3d.spec.bs`:

```brighterscript
    @describe("worldPointToCanvasPoint with roll")

    @it("projects a world point to a rotated raster position when the camera is rolled")
    function _()
      m.camera.position = BGE.Math.VectorOps.create(0, 0, 0)
      m.camera.setTarget(BGE.Math.VectorOps.create(0, 0, -100))
      m.camera.setFrameSize(200, 200)
      m.camera.checkMovement()

      ' A point straight above the camera's forward axis, level.
      levelResult = m.camera.worldPointToCanvasPoint(BGE.Math.VectorOps.create(0, 10, -100))

      m.camera.rollDegrees = 90
      m.camera.checkMovement()
      rolledResult = m.camera.worldPointToCanvasPoint(BGE.Math.VectorOps.create(0, 10, -100))

      ' A 90 degree roll should move a point that was directly above center to
      ' directly beside center instead - x and y raster offsets from the canvas
      ' center should have swapped (up to which side, given rounding).
      centerX = 100
      centerY = 100
      m.assertEqual(0, levelResult.x - centerX)
      m.assertNotEqual(0, rolledResult.x - centerX)
    end function
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `npm run build-tests && npm run test:ci`
Expected: FAIL - `rolledResult.x - centerX` is still `0` today, since `computeWorldToCameraMatrix()` ignores roll entirely.

- [ ] **Step 3: Implement**

In `src/source/engine/renderer/cameras/Camera3d.bs`, change:

```brighterscript
    override sub computeWorldToCameraMatrix()
      lookTarget = BGE.Math.VectorOps.add(m.position, m.orientation)
      m.worldToCamera = BGE.Math.Matrix44.inverse(BGE.Math.lookAt(m.position, lookTarget))
    end sub
```

to:

```brighterscript
    override sub computeWorldToCameraMatrix()
      lookTarget = BGE.Math.VectorOps.add(m.position, m.orientation)
      m.worldToCamera = BGE.Math.Matrix44.inverse(BGE.Math.lookAt(m.position, lookTarget, m.getUpVector()))
    end sub
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `npm run build-tests && npm run test:ci`
Expected: PASS. Run the full suite too - every other `Camera3dTests` test uses `rollDegrees = 0` (the default), so `getUpVector()` returns the same level vector as before and none of them should change behavior.

- [ ] **Step 5: Commit**

```bash
git add src/source/engine/renderer/cameras/Camera3d.bs src/source/engine/renderer/cameras/Camera3d.spec.bs
git commit -m "Make Camera3d's view matrix reflect roll"
```

---

### Task 4: Roll dirty-checking

**Files:**
- Modify: `src/source/engine/renderer/cameras/Camera3d.bs`
- Test: `src/source/engine/renderer/cameras/Camera3d.spec.bs`

**Interfaces:**
- Consumes: `Camera.checkMovement()` (base class, unmodified), `Camera3d.recomputeFrustum(recomputeNormals as boolean)` (existing).
- Produces: `Camera3d.checkMovement()` override. After this task, a roll-only change (position and orientation both unchanged) results in: `frustumRays`/`frustumNormals` rebuilt, `m.worldToCamera` invalidated so it's rebuilt lazily on next use, and `camera.movedLastFrame()` reporting `true` for that frame.

- [ ] **Step 1: Write the failing tests**

Add to `src/source/engine/renderer/cameras/Camera3d.spec.bs`:

```brighterscript
    @describe("checkMovement with roll")

    @it("rebuilds the frustum rays when only rollDegrees changes")
    function _()
      m.camera.setFrameSize(200, 200)
      m.camera.checkMovement()
      before = m.camera.frustumRays.topLeft.direction.y

      m.camera.rollDegrees = 45
      m.camera.checkMovement()

      m.assertNotEqual(before, m.camera.frustumRays.topLeft.direction.y)
    end function

    @it("reports movedLastFrame true on a roll-only change")
    function _()
      m.camera.setFrameSize(200, 200)
      m.camera.checkMovement()
      m.camera.movedLastFrame() ' drain the initial true-on-construction state

      m.camera.rollDegrees = 45
      m.camera.checkMovement()

      m.assertTrue(m.camera.movedLastFrame())
    end function

    @it("invalidates the cached world-to-camera matrix on a roll-only change")
    function _()
      m.camera.setFrameSize(200, 200)
      m.camera.checkMovement()
      m.camera.computeWorldToCameraMatrix() ' force it to exist
      before = BGE.Math.Matrix44.copy(m.camera.worldToCamera)

      m.camera.rollDegrees = 45
      m.camera.checkMovement()

      m.assertInvalid(m.camera.worldToCamera)
    end function
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `npm run build-tests && npm run test:ci`
Expected: all three FAIL - nothing in `Camera3d` currently reacts to a `rollDegrees`-only change.

- [ ] **Step 3: Implement**

In `src/source/engine/renderer/cameras/Camera3d.bs`, add a tracking field near `lastProjectionFieldOfView`:

```brighterscript
    ' Last rollDegrees seen by checkMovement(). rollDegrees is a plain public field a
    ' consumer writes directly, and MotionChecker's position/orientation check has no
    ' way to represent "rotated about the forward axis" - a roll-only frame needs its
    ' own dirty check or the frustum/view-matrix/plane caches would all go stale. See
    ' issue #53's roll design.
    private lastRollDegrees as float = 0
```

Then override `checkMovement()` (add this method to the class, near `onCameraMovement`):

```brighterscript
    override sub checkMovement()
      rollChanged = m.rollDegrees <> m.lastRollDegrees
      m.lastRollDegrees = m.rollDegrees

      super.checkMovement()

      if rollChanged
        m.recomputeFrustum(true)
        m.worldToCamera = invalid
        m.motionChecker.movedLastFrame = true
      end if
    end sub
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `npm run build-tests && npm run test:ci`
Expected: PASS. Run the full suite - the existing `"holds projectionVersion steady when the field of view is unchanged"` test and friends should be unaffected, since `rollChanged` is `false` in all of them (`rollDegrees` defaults to `0` and none of those tests touch it).

- [ ] **Step 5: Commit**

```bash
git add src/source/engine/renderer/cameras/Camera3d.bs src/source/engine/renderer/cameras/Camera3d.spec.bs
git commit -m "Dirty-check Camera3d.rollDegrees so frustum/view-matrix/plane caches don't go stale"
```

---

### Task 5: Refactor `getHorizonLine` onto a shared, parameterized helper

**Files:**
- Modify: `src/source/engine/renderer/cameras/Camera3d.bs`
- Test: `src/source/engine/renderer/cameras/Camera3d.spec.bs`

**Interfaces:**
- Produces:
  - `Camera3d.getFocalLength() as float` - the camera's intrinsic focal length in pixels, derived from `fieldOfViewDegrees`/`frameSize.x`.
  - `Camera3d.getFovDegreesForCanvasSize(canvasSize as float) as float` - the field of view (both axes - meant for a square canvas) a `canvasSize x canvasSize` canvas would need to cover the same angular extent as this camera's real field of view, at the same focal length.
  - `Camera3d.horizonLineForMatrix(plane as BGE.Math.Plane, worldToCameraMatrix as float[][], canvasWidth as float, focalLength as float) as BGE.Math.Vector[]` (private) - the core of today's `getHorizonLine`, parameterized.
  - `Camera3d.getHorizonLine(plane)` - unchanged public signature and behavior, now implemented via the helper above.
  - `Camera3d.getLevelHorizonLine(plane as BGE.Math.Plane, canvasSize as float) as BGE.Math.Vector[]` - the horizon as seen by an unrolled camera against a `canvasSize x canvasSize` canvas. Used by `SceneObjectPlane` (Task 7).

- [ ] **Step 1: Write the failing tests**

Add to `src/source/engine/renderer/cameras/Camera3d.spec.bs`:

```brighterscript
    @describe("getFocalLength / getFovDegreesForCanvasSize")

    @it("returns a larger field of view for a larger canvas at the same focal length")
    function _()
      m.camera.setFrameSize(200, 200)
      m.camera.fieldOfViewDegrees = 90

      m.assertEqual(90.0, m.camera.getFovDegreesForCanvasSize(200))
      m.assertTrue(m.camera.getFovDegreesForCanvasSize(400) > 90)
    end function

    @describe("getLevelHorizonLine")

    @it("matches getHorizonLine when the camera isn't rolled and the canvas matches the frame")
    function _()
      m.camera.position = BGE.Math.VectorOps.create(0, 10, 0)
      m.camera.setFrameSize(200, 200)
      m.camera.setTarget(BGE.Math.VectorOps.create(0, 10, -100))
      m.camera.checkMovement()

      real = m.camera.getHorizonLine(m.groundPlane)
      level = m.camera.getLevelHorizonLine(m.groundPlane, 200)

      m.assertEqual(real[0].x, level[0].x)
      m.assertEqual(real[0].y, level[0].y)
    end function

    @it("stays the same for the level horizon regardless of rollDegrees")
    function _()
      m.camera.position = BGE.Math.VectorOps.create(0, 10, 0)
      m.camera.setFrameSize(200, 200)
      m.camera.setTarget(BGE.Math.VectorOps.create(0, 10, -100))
      m.camera.checkMovement()

      unrolled = m.camera.getLevelHorizonLine(m.groundPlane, 200)

      m.camera.rollDegrees = 45
      m.camera.checkMovement()
      rolled = m.camera.getLevelHorizonLine(m.groundPlane, 200)

      m.assertEqual(unrolled[0].y, rolled[0].y)
    end function
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `npm run build-tests && npm run test:ci`
Expected: FAIL - none of `getFocalLength`, `getFovDegreesForCanvasSize`, `getLevelHorizonLine` exist yet.

- [ ] **Step 3: Implement**

In `src/source/engine/renderer/cameras/Camera3d.bs`, replace the existing `getHorizonLine` function body with:

```brighterscript
    ' The camera's intrinsic focal length in pixels, derived from its real field of
    ' view and frame width. This is independent of any particular canvas size - see
    ' getFovDegreesForCanvasSize(), which uses it to answer "what FOV would a
    ' differently-sized canvas need to cover the same angular extent this camera
    ' actually sees."
    '
    ' @return {float}
    function getFocalLength() as float
      return (m.frameSize.x * 0.5) / tan(BGE.Math.DegreesToRadians(m.fieldOfViewDegrees) * 0.5)
    end function

    ' The (horizontal = vertical, meant for a square canvas) field of view a
    ' canvasSize x canvasSize canvas would need to cover the same angular extent as
    ' this camera's real field of view does for its own frame width, at the same
    ' focal length. Used by SceneObjectPlane to render its ground geometry into an
    ' enlarged canvas before rotating it for roll - see SceneObjectPlane.
    '
    ' @param {float} canvasSize
    ' @return {float} degrees
    function getFovDegreesForCanvasSize(canvasSize as float) as float
      return BGE.Math.RadiansToDegrees(2 * BGE.Math.Atan2(canvasSize / 2, m.getFocalLength()))
    end function

    ' Returns two screen-space points that define the visible horizon line of a plane.
    ' If the horizon does not intersect the camera frame, invalid is returned.
    '
    ' @param {BGE.Math.Plane} plane
    ' @return {BGE.Math.Vector[]} Two points in screen space that define the horizon line of the plane, or invalid if the plane is not visible.
    function getHorizonLine(plane as BGE.Math.Plane) as BGE.Math.Vector[]
      if invalid = m.worldToCamera
        m.computeWorldToCameraMatrix()
      end if
      return m.horizonLineForMatrix(plane, m.worldToCamera, m.frameSize.x, m.getFocalLength())
    end function

    ' The horizon line as seen by an unrolled (rollDegrees = 0) camera at this
    ' camera's real position/orientation, against a canvasSize x canvasSize square
    ' canvas rather than the real frame. SceneObjectPlane computes all of its ground
    ' geometry this way and applies the actual roll as a final image rotation instead
    ' of deriving a tilted horizon directly - see SceneObjectPlane.
    '
    ' @param {BGE.Math.Plane} plane
    ' @param {float} canvasSize
    ' @return {BGE.Math.Vector[]}
    function getLevelHorizonLine(plane as BGE.Math.Plane, canvasSize as float) as BGE.Math.Vector[]
      lookTarget = BGE.Math.VectorOps.add(m.position, m.orientation)
      levelWorldToCamera = BGE.Math.Matrix44.inverse(BGE.Math.lookAt(m.position, lookTarget, m.getLevelUpVector()))
      return m.horizonLineForMatrix(plane, levelWorldToCamera, canvasSize, m.getFocalLength())
    end function

    ' Shared core of getHorizonLine()/getLevelHorizonLine() - see those for context.
    '
    ' @param {BGE.Math.Plane} plane
    ' @param {float[][]} worldToCameraMatrix
    ' @param {float} canvasWidth
    ' @param {float} focalLength
    ' @return {BGE.Math.Vector[]}
    private function horizonLineForMatrix(plane as BGE.Math.Plane, worldToCameraMatrix as float[][], canvasWidth as float, focalLength as float) as BGE.Math.Vector[]
      if invalid = plane or invalid = plane.normal or invalid = plane.point
        return invalid
      end if

      ' Transform the plane's normal into view space (ignore translation).
      nv = BGE.Math.Matrix44.multDirMatrix(plane.normal, worldToCameraMatrix)

      ' If nv.y is near 0, the camera is tilted so the horizon is vertical, or
      ' looking straight up/down - no meaningful horizontal horizon to draw.
      if abs(nv.y) < 0.001
        return invalid
      end if

      leftPt = m.findHorizonPoint(-canvasWidth * 0.5, focalLength, nv)
      rightPt = m.findHorizonPoint(canvasWidth * 0.5, focalLength, nv)
      return [leftPt, rightPt]
    end function
```

Remove the old inline `getHorizonLine` body you're replacing (the `nv = ...` / `fovRad = ...` / `width = ...` / `focalLength = ...` lines that are now inside `horizonLineForMatrix`/`getFocalLength`), so there's exactly one `getHorizonLine`, `getLevelHorizonLine`, and `horizonLineForMatrix` in the file.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `npm run build-tests && npm run test:ci`
Expected: PASS, including every pre-existing `getHorizonLine` test (`"returns a left/right point pair..."`, `"returns invalid for a 'wall' plane..."`) - this is a behavior-preserving refactor for the public method.

- [ ] **Step 5: Commit**

```bash
git add src/source/engine/renderer/cameras/Camera3d.bs src/source/engine/renderer/cameras/Camera3d.spec.bs
git commit -m "Refactor Camera3d.getHorizonLine onto a parameterized helper, add getLevelHorizonLine"
```

---

### Task 6: `SceneObjectPlane` computes an enlarged, level view when rolled

**Files:**
- Modify: `src/source/engine/renderer/sceneObjects/SceneObjectPlane.bs`
- Test (new file): `src/source/engine/renderer/sceneObjects/SceneObjectPlane.spec.bs`

**Interfaces:**
- Consumes: `Camera3d.rollDegrees`, `getLevelUpVector()`/`getLevelRightVector()` (Task 2), `getFovDegreesForCanvasSize()` (Task 5), `getLevelHorizonLine()` (Task 5), `CameraFrustumRays.setRays(...)` (existing).
- Produces: `SceneObjectPlane.getPerspectivePointsByCamera()` returns geometry computed against an enlarged square canvas whenever `camera.rollDegrees <> 0`, and exactly as before when `rollDegrees = 0`. New private helper `SceneObjectPlane.getRollCanvasSize(frameSize as BGE.Math.Vector) as float`, exposed at the class's default (non-private) visibility specifically so the new spec file can call it directly.

- [ ] **Step 1: Write the failing tests**

Create `src/source/engine/renderer/sceneObjects/SceneObjectPlane.spec.bs`:

```brighterscript
namespace tests

  @suite("BGE.SceneObjectPlane")
  class SceneObjectPlaneTests extends rooibos.BaseTestSuite

    game as BGE.Game
    plane as BGE.SceneObjectPlane

    protected override function beforeEach()
      m.game = new BGE.Game(200, 200)
      m.game.setCamera(new BGE.Camera3d())
      m.game.canvas.renderer.camera.setFrameSize(200, 100)

      room = new BGE.Room(m.game, {name: "TestRoom"})
      m.game.defineRoom(room)
      m.game.changeRoom("TestRoom")

      bmp = CreateObject("roBitmap", {width: 8, height: 8, AlphaEnable: true})
      region = CreateObject("roRegion", bmp, 0, 0, 8, 8)
      drawablePlane = new BGE.DrawablePlane(room, region, {normal: {x: 0, y: 1, z: 0}, point: {x: 0, y: 0, z: 0}})
      m.plane = new BGE.SceneObjectPlane("plane", drawablePlane)
    end function

    @describe("getRollCanvasSize")

    @it("returns a size at least as large as the frame's diagonal")
    function _()
      size = m.plane.getRollCanvasSize(BGE.Math.VectorOps.create(200, 100))
      diagonal = Sqr(200.0 * 200.0 + 100.0 * 100.0)

      m.assertTrue(size >= diagonal)
    end function

  end class

end namespace
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `npm run build-tests && npm run test:ci`
Expected: FAIL - `getRollCanvasSize` doesn't exist yet.

- [ ] **Step 3: Implement**

In `src/source/engine/renderer/sceneObjects/SceneObjectPlane.bs`, add a canvas-sizing helper (near the top of the class, after the existing private fields):

```brighterscript
    ' Sized to at least the camera frame's diagonal, so a composite rendered into a
    ' canvasSize x canvasSize square can be rotated by any angle without exposing an
    ' empty corner once it's cropped back down to the real frame - see performDraw().
    ' The +2 is slack for the sqrt/int rounding, not a precision requirement.
    '
    ' @param {BGE.Math.Vector} frameSize
    ' @return {float}
    function getRollCanvasSize(frameSize as BGE.Math.Vector) as float
      return Int(Sqr(frameSize.x * frameSize.x + frameSize.y * frameSize.y)) + 2
    end function
```

Then change `getPerspectivePointsByCamera` to branch on `camera.rollDegrees`. Replace:

```brighterscript
      rays = camera.frustumRays


      output = new BGE.Math.CornerPoints()

      output.topRight = BGE.Math.intersectRayWithPlane(plane, rays.topRight)
      output.topLeft = BGE.Math.intersectRayWithPlane(plane, rays.topLeft)
      output.bottomRight = BGE.Math.intersectRayWithPlane(plane, rays.bottomRight)
      output.bottomLeft = BGE.Math.intersectRayWithPlane(plane, rays.bottomLeft)

      horizonOrig = camera.getHorizonLine(plane)
      horizon = []
      for each pt in horizonOrig
        converted = camera.cameraPointToScreenPoint(pt)
        'print "horizon point: "; pt; converted
        horizon.Push(converted)
      end for

      horizFov = camera.fieldOfViewDegrees
```

with:

```brighterscript
      isRolled = camera.rollDegrees <> 0
      canvasWidth = camera.frameSize.x
      canvasHeight = camera.frameSize.y

      if not isRolled
        rays = camera.frustumRays
        horizFov = camera.fieldOfViewDegrees
        horizonOrig = camera.getHorizonLine(plane)
      else
        ' Roll can't be represented by this trapezoid-slice rasterizer directly (see
        ' the design doc) - instead, compute every bit of geometry against an
        ' unrolled ("level") view enlarged to cover the frame's diagonal, and apply
        ' the actual roll as a final image rotation in performDraw()/
        ' drawPerspectiveBmpSlicesToByCamera(). A pure roll's projection is exactly
        ' the level projection rotated about the image center, so this is exact, not
        ' an approximation - modulo the finite canvas needing to be big enough to
        ' cover every angle, which getRollCanvasSize() guarantees.
        canvasWidth = m.getRollCanvasSize(camera.frameSize)
        canvasHeight = canvasWidth
        horizFov = camera.getFovDegreesForCanvasSize(canvasWidth)

        rays = new CameraFrustumRays()
        rays.setRays(camera.position, camera.orientation, horizFov, horizFov, camera.getLevelUpVector(), camera.getLevelRightVector())

        horizonOrig = camera.getLevelHorizonLine(plane, canvasWidth)
      end if

      output = new BGE.Math.CornerPoints()

      output.topRight = BGE.Math.intersectRayWithPlane(plane, rays.topRight)
      output.topLeft = BGE.Math.intersectRayWithPlane(plane, rays.topLeft)
      output.bottomRight = BGE.Math.intersectRayWithPlane(plane, rays.bottomRight)
      output.bottomLeft = BGE.Math.intersectRayWithPlane(plane, rays.bottomLeft)

      horizon = []
      for each pt in horizonOrig
        ' cameraPointToScreenPoint() reads the real camera's frameSize, which is only
        ' correct for the non-rolled path above - do the same {x + width/2, height/2
        ' - y} conversion directly here so it works for both canvasWidth values.
        horizon.Push({x: pt.x + canvasWidth * 0.5, y: canvasHeight * 0.5 - pt.y})
      end for
```

The rest of `getPerspectivePointsByCamera` (from `cameraPointOnPlane = ...` onward) is unchanged - it already only reads `horizFov`, `output`, `plane`, `camera.position`, and `camera.orientation`, all of which are now correctly set for both branches.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `npm run build-tests && npm run test:ci`
Expected: PASS. Also run `npm run validate` - `SceneObjectPlane.bs` now constructs a bare `CameraFrustumRays` directly; confirm it type-checks (it's in the same `BGE` namespace, so no import needed).

- [ ] **Step 5: Commit**

```bash
git add src/source/engine/renderer/sceneObjects/SceneObjectPlane.bs src/source/engine/renderer/sceneObjects/SceneObjectPlane.spec.bs
git commit -m "Compute SceneObjectPlane geometry against an enlarged level view when the camera is rolled"
```

---

### Task 7: Rotate the composite and blit it for rolled cameras

**Files:**
- Modify: `src/source/engine/renderer/Renderer.bs`
- Modify: `src/source/engine/renderer/sceneObjects/SceneObjectPlane.bs`

**Interfaces:**
- Consumes: `Renderer.drawRotatedImageWithCenterTo(draw2d, srcRegion, srcRotationPoint, theta, translation, drawScale)` (existing), `camera.rollDegrees` (Task 2).
- Produces: `Renderer.drawRotatedImageWithCenter(srcRegion, srcRotationPoint, theta, translation, drawScale) as boolean` (new) - the same no-`To`-suffix convenience wrapper pattern every other `Renderer.draw*To` method already has (e.g. `drawObject`/`drawObjectTo`, `drawRotatedObject`/`drawRotatedObjectTo`), defaulting the target to the renderer's own canvas. `SceneObjectPlane.performDraw()`/`drawPerspectiveBmpSlicesToByCamera()` blit a roll-rotated, center-cropped result to the screen when `rollDegrees <> 0`; unchanged direct blit when `rollDegrees = 0`.

This task is deliberately not TDD'd with a Rooibos test - the result is a rendered raster image, which the existing test suite has no way to assert on (see `CLAUDE.md`'s note that automated tests can't exercise this class of code). Correctness is verified on-device in Task 10.

- [ ] **Step 0: Add a default-canvas convenience wrapper for `drawRotatedImageWithCenterTo`**

`drawRotatedImageWithCenterTo` is the only `...To`-suffixed draw method in `Renderer.bs` without a matching no-`To` convenience wrapper defaulting to the renderer's own (private) `m.draw2d` - every existing caller so far has targeted a scratch bitmap explicitly. `SceneObjectPlane` needs to draw straight to the renderer's real canvas, which it can't reach directly (`draw2d` is `private`). In `src/source/engine/renderer/Renderer.bs`, immediately above `drawRotatedImageWithCenterTo`, add:

```brighterscript
    function drawRotatedImageWithCenter(srcRegion as ifDraw2d, srcRotationPoint as BGE.Math.Vector, theta as float, translation = BGE.Math.VectorOps.create() as BGE.Math.Vector, drawScale = BGE.Math.createScaleVector(1) as BGE.Math.Vector) as boolean
      return m.drawRotatedImageWithCenterTo(m.draw2d, srcRegion, srcRotationPoint, theta, translation, drawScale)
    end function


```

Run `npm run validate` to confirm it type-checks alongside the existing `drawRotatedImageWithCenterTo`.

- [ ] **Step 1: Update `drawPerspectiveBmpSlicesToByCamera`'s composite size**

In `src/source/engine/renderer/sceneObjects/SceneObjectPlane.bs`, `drawPerspectiveBmpSlicesToByCamera` currently sizes its output bitmap to `camera.frameSize`:

```brighterscript
      destWidth = camera.frameSize.x
      destTop = rendererObj.camera.frameSize.y
```

Change this to size against whatever canvas the (now roll-aware, per Task 6) `cp`/`horizon` were actually computed against - which for a rolled camera is the enlarged square, not the frame. Replace with:

```brighterscript
      isRolled = camera.rollDegrees <> 0
      compositeSize = m.getRollCanvasSize(camera.frameSize)
      destWidth = camera.frameSize.x
      destTop = camera.frameSize.y
      if isRolled
        destWidth = compositeSize
        destTop = compositeSize
      end if
```

(`destTop` is reused below as the mutable "current top of the next slice" accumulator - keep that usage exactly as-is; only its *initial* value is changing here.)

- [ ] **Step 2: Rotate and crop before the final blit**

Still in `drawPerspectiveBmpSlicesToByCamera`, find the final line:

```brighterscript
      worked = worked and rendererObj.drawObject(0, 0, m.tempBitmap)
      return worked
```

Replace with:

```brighterscript
      if not isRolled
        worked = worked and rendererObj.drawObject(0, 0, m.tempBitmap)
        return worked
      end if

      ' m.tempBitmap is the enlarged, level (unrolled) composite here - rotating it
      ' by -rollDegrees about its own center and reading off the real frame-sized
      ' region centered on that same point gives exactly the rolled camera's view
      ' (see the design doc: perspective division commutes with an in-plane rotation
      ' about the optical axis for a pure roll).
      center = BGE.Math.VectorOps.create(compositeSize / 2, compositeSize / 2)
      rollRad = BGE.Math.DegreesToRadians(-camera.rollDegrees)
      cropOffset = BGE.Math.VectorOps.create((compositeSize - camera.frameSize.x) / 2, (compositeSize - camera.frameSize.y) / 2)
      worked = worked and rendererObj.drawRotatedImageWithCenter(m.tempBitmap, center, rollRad, BGE.Math.VectorOps.negative(cropOffset))
      return worked
```

- [ ] **Step 3: Confirm `getPrePerspectiveBmp`'s cache-sizing still matches**

`performDraw()` already guards `m.tempBitmap`'s (re)creation on a width/height mismatch:

```brighterscript
      if invalid = m.tempBitmap or m.tempBitmap.GetWidth() <> destWidth or m.tempBitmap.GetHeight() <> destTop
        m.tempBitmap = CreateObject("roBitmap", {width: destWidth, height: destTop, AlphaEnable: true})
      end if
```

No change needed here - `destWidth`/`destTop` from Step 1 already reflect the enlarged size when rolled, so this creates a bigger `m.tempBitmap` automatically, and correctly shrinks back to frame-size the first time `rollDegrees` returns to `0` (e.g. after the terrain example's Play/Pause reset in Task 8).

- [ ] **Step 4: Type-check**

Run: `npm run validate`
Expected: no errors. There's no automated test to run for this task - proceed to the next task and rely on Task 10's on-device verification to catch any mistake here (corner artifacts, wrong rotation direction, seam issues).

- [ ] **Step 5: Commit**

```bash
git add src/source/engine/renderer/Renderer.bs src/source/engine/renderer/sceneObjects/SceneObjectPlane.bs
git commit -m "Rotate SceneObjectPlane's composite by roll before blitting to screen"
```

---

### Task 8: Live pitch/roll controls in `examples/terrain`

**Files:**
- Modify: `examples/terrain/src/source/Rooms/MainRoom.bs`
- Create: `examples/terrain/src/source/Entities/RollMarker.bs`

**Interfaces:**
- Consumes: `Camera3d.rollDegrees` (Task 2), `GameEntity.addRectangle(name, width, height, args)` (existing, see `src/source/engine/GameEntity.bs:377`).
- Produces: no new engine-facing interfaces - this is example-app behavior only.

This task is not unit-tested (per `CLAUDE.md`: automated tests don't cover `examples/*` runtime behavior at all) - it's verified on-device in Task 10.

- [ ] **Step 1: Add held-continuous pitch/roll state to `MainRoom`**

In `examples/terrain/src/source/Rooms/MainRoom.bs`, replace the fixed tilt constant and add roll/pitch tracking fields:

```brighterscript
class MainRoom extends BGE.Room

  drawablePlane as BGE.DrawablePlane
  showingCheckerboard = false
  debugEnabled = false

  turnSpeed = 2.0 ' radians/sec
  driveSpeed = 80 ' units/sec
  rollSpeed = 60 ' degrees/sec
  pitchSpeed = 0.3 ' radians/sec, matching downwardTilt's small scale
  cameraHeight = 50
  defaultDownwardTilt = 0.12 ' small negative y-component on the (unit) look direction, for a slight downward tilt

  heading = 0.0 ' radians, 0 = facing -z (the default camera forward)
  downwardTilt = 0.12
  rollDirection = 0 ' -1 = rolling left, 1 = rolling right, 0 = not rolling
  pitchDirection = 0 ' -1 = pitching down, 1 = pitching up, 0 = not pitching
  backHeldMs = 0
  debugToggledForThisHold = false
  lastInput as BGE.GameInput
```

- [ ] **Step 2: Update `onCreate` to plant the roll marker**

```brighterscript
  override sub onCreate(args as roAssociativeArray)
    m.setGroundTexture(false)

    camera = m.game.canvas.renderer.camera as BGE.Camera3d
    camera.position = BGE.Math.VectorOps.create(0, m.cameraHeight, 0)
    m.updateCameraOrientation()

    marker = new RollMarker(m.game)
    marker.position = BGE.Math.VectorOps.create(150, 0, -400)
    m.game.addEntity(marker)
  end sub
```

- [ ] **Step 3: Handle press/held/release for the new buttons in `onInput`**

```brighterscript
  override sub onInput(input as BGE.GameInput)
    m.lastInput = input
    if input.isButton("replay") and not input.release
      m.rollDirection = -1
    else if input.isButton("options") and not input.release
      m.rollDirection = 1
    else if input.isButton("replay") and input.release
      m.rollDirection = 0
    else if input.isButton("options") and input.release
      m.rollDirection = 0
    else if input.isButton("rewind") and not input.release
      m.pitchDirection = -1
    else if input.isButton("fastforward") and not input.release
      m.pitchDirection = 1
    else if input.isButton("rewind") and input.release
      m.pitchDirection = 0
    else if input.isButton("fastforward") and input.release
      m.pitchDirection = 0
    end if

    if input.press
      if input.isButton("OK")
        m.setGroundTexture(not m.showingCheckerboard)
      else if input.isButton("play")
        camera = m.game.canvas.renderer.camera as BGE.Camera3d
        camera.rollDegrees = 0
        m.downwardTilt = m.defaultDownwardTilt
      end if
    end if

    ' Back needs tap-vs-hold disambiguation: quitting can't fire on press (the
    ' normal, simplest way to handle a button), or holding Back to toggle debug
    ' info would never get the chance to run - the app would already be quitting
    ' before 2 seconds of held time could accumulate. So a press just resets the
    ' hold tracking, and a release only quits if the hold never reached 2 seconds
    ' (i.e. debug info wasn't already toggled by onUpdate's held-time check below).
    if input.isButton("back")
      if input.press
        m.backHeldMs = 0
        m.debugToggledForThisHold = false
      else if input.release
        if not m.debugToggledForThisHold
          m.game.end()
        end if
      end if
    end if
  end sub
```

- [ ] **Step 4: Apply roll/pitch/back-held every frame in `onUpdate`**

```brighterscript
  override sub onUpdate(dt as float)
    input = m.lastInput
    if input <> invalid
      m.heading += input.x * dt * m.turnSpeed
      if input.y <> 0
        camera = m.game.canvas.renderer.camera as BGE.Camera3d
        camera.position = BGE.Math.VectorOps.add(camera.position, BGE.Math.VectorOps.scale(m.headingForward(), input.y * dt * m.driveSpeed))
      end if
      if input.isButton("back") and input.held
        m.backHeldMs = input.heldTimeMs
        if m.backHeldMs >= 2000 and not m.debugToggledForThisHold
          m.debugEnabled = not m.debugEnabled
          m.game.debugDrawEntityDetails(m.debugEnabled)
          m.debugToggledForThisHold = true
        end if
      end if
    end if

    if m.rollDirection <> 0
      camera = m.game.canvas.renderer.camera as BGE.Camera3d
      camera.rollDegrees = camera.rollDegrees + m.rollDirection * m.rollSpeed * dt
    end if
    if m.pitchDirection <> 0
      m.downwardTilt += m.pitchDirection * m.pitchSpeed * dt
    end if

    m.updateCameraOrientation()
  end sub
```

- [ ] **Step 5: Use the live `downwardTilt` field in `updateCameraOrientation`**

```brighterscript
  private sub updateCameraOrientation()
    camera = m.game.canvas.renderer.camera as BGE.Camera3d
    forward = m.headingForward()
    tiltedForward = BGE.Math.VectorOps.create(forward.x, -m.downwardTilt, forward.z)
    BGE.Math.VectorOps.normalize(tiltedForward)
    camera.orientation = tiltedForward
  end sub
```

(This body is unchanged from today except that `m.downwardTilt` replaces the old fixed constant of the same name - it's now a mutable field instead.)

- [ ] **Step 6: Update the on-screen instructions in `onDrawEnd`**

```brighterscript
  override sub onDrawEnd(renderObj as BGE.Renderer, uiRenderObj as BGE.Renderer)
    font = m.game.getFont("default")
    frameCenter = uiRenderObj.getCanvasCenter()
    text = "Turn: Left/Right   Move: Up/Down" + Chr(10) + "Roll: Instant Replay/Options   Pitch: Rewind/FF" + Chr(10) + "OK: toggle track / checkerboard   Play: reset pitch/roll" + Chr(10) + "Hold Back 2s: toggle debug info"
    uiRenderObj.DrawText(text, frameCenter.x, 140, BGE.Colors.White, font, "center")
  end sub
```

- [ ] **Step 7: Create the roll marker entity**

Create `examples/terrain/src/source/Entities/RollMarker.bs`:

```brighterscript
' A fixed, oriented billboard planted beside the track. Unlike the ground plane
' (which fakes roll by rotating its own rendered composite - see SceneObjectPlane),
' this marker renders through the ordinary per-point projection path
' (Camera3d.worldPointToCanvasPoint), so it banks with the camera independently -
' an easy visual check that both mechanisms agree on which way is "up" as the
' camera rolls and pitches.
class RollMarker extends BGE.GameEntity

  sub new(game as BGE.Game)
    super(game)
    m.name = "RollMarker"
  end sub

  override sub onCreate(args as roAssociativeArray)
    marker = m.addRectangle("marker", 20, 80, {
      color: BGE.ColorsRGB.Red,
      offset: BGE.Math.VectorOps.create(-10, 80, 0)
    })
    marker.drawMode = BGE.SceneObjectDrawMode.oriented
  end sub

end class
```

- [ ] **Step 8: Build and validate**

Run: `cd examples/terrain && npm install && npm run validate`
Expected: no errors.

- [ ] **Step 9: Commit**

```bash
git add examples/terrain/src/source/Rooms/MainRoom.bs examples/terrain/src/source/Entities/RollMarker.bs
git commit -m "Add live pitch/roll controls and a banking marker to the terrain example"
```

---

### Task 9: Update `CLAUDE.md`

**Files:**
- Modify: `CLAUDE.md`

Per project convention, review docs on significant engine changes. This one is small: one clause added to the existing `SceneObjectPlane`/`Camera3d` paragraph.

- [ ] **Step 1: Add a sentence to the `SceneObjectPlane`/`DrawablePlane` paragraph**

Find the bullet in `CLAUDE.md` starting `` `SceneObjectPlane`/`DrawablePlane` render a textured ground/floor plane `` and add, after its existing sentences:

```markdown
`Camera3d.rollDegrees` (rotation about the camera's own forward axis) is supported throughout - ordinary 3D objects (billboards, models) bank correctly because they're projected per-point through the camera's view matrix, but `SceneObjectPlane` can't do that (it rasterizes via horizontal trapezoid slices, which can't represent a tilted horizon directly) - instead it computes its geometry against an *unrolled* view enlarged to the frame's diagonal, then rotates the composited result by the roll angle before cropping it to the frame. See `specs/2026-08-19-camera-roll-and-plane-horizon-design.md`.
```

- [ ] **Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "Document Camera3d roll support in CLAUDE.md"
```

---

### Task 10: On-device verification (mandatory)

**Files:** none - this task uses the `rokubot-examples` skill against the already-built `examples/terrain` example.

This is not optional polish - per `CLAUDE.md`, automated tests do not exercise `examples/*` runtime behavior at all, and this is exactly the class of bug (visual seams, corner artifacts, wrong rotation direction/sign) that has previously escaped both `npm run check` and code review.

- [ ] **Step 1: Sideload and launch**

Use the `rokubot-examples` skill to build, sideload, and launch `examples/terrain`.

- [ ] **Step 2: Screenshot at level roll/pitch**

Take a screenshot at the default state (roll = 0, pitch = default). Confirm: the horizon is a straight, level line; the ground renders exactly as it did before this plan (no visible change is expected at `rollDegrees = 0`); the roll marker is visible and upright.

- [ ] **Step 3: Screenshot at a shallow roll (~15 degrees)**

Hold Options briefly (or use rokubot's key-press to tap it a few times, since held-key timing isn't reliable for scripted control - see project memory on this) to bank to roughly 15 degrees. Screenshot. Confirm: the horizon is a straight line tilted at roughly the expected angle; the ground still fills the frame below it with no gaps; the roll marker visibly tilts to match.

- [ ] **Step 4: Screenshot at a steep roll (~45-60 degrees)**

Continue tapping/holding to reach a steeper bank. Screenshot. Confirm: no wedge-shaped transparent gaps or stale-pixel artifacts at the frame corners (the `ScratchBitmapPool`-not-cleared gotcha already documented in this codebase); the track texture isn't stretched or duplicated oddly.

- [ ] **Step 5: Screenshot near a 90-degree roll**

Screenshot at the steepest reachable bank. Confirm the same checks as Step 4 still hold at the extreme.

- [ ] **Step 6: Screenshot with pitch changed**

Tap Rewind/FastForward to change pitch away from the default, both together with and without roll applied. Confirm the horizon's vertical position on screen shifts sensibly with pitch, and (when combined with roll) the tilted horizon line also shifts up/down as expected rather than snapping back to center.

- [ ] **Step 7: Confirm reset works**

Press Play/Pause. Confirm roll and pitch both return to their defaults immediately.

- [ ] **Step 8: Confirm the debug-info hold-to-toggle**

Hold Back for roughly 2 seconds (not a quick tap) and confirm debug info toggles on; a quick tap of Back should still quit the app without toggling debug info first.

- [ ] **Step 9: Report and, if any check fails, fix and re-verify**

If any check in Steps 2-8 fails, identify which task's math is responsible (a wrong rotation direction points at Task 7's `rollRad` sign or Task 2's `RotateVectorAroundPoint3d` axis choice; corner gaps point at `getRollCanvasSize` in Task 6; a horizon that doesn't move with pitch points at Task 5/6's `getLevelHorizonLine` wiring), fix it, re-run `npm run check`, and repeat the relevant screenshot step before moving on.

No commit for this task unless Step 9 required a fix - in that case, commit the fix with a message describing what was wrong and how the on-device check caught it.
