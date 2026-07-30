# Making a culled SceneObject recoverable — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make a `SceneObject` that failed to draw recover on the next frame, while keeping the optimisation that a genuinely frustum-culled static object costs nothing.

**Architecture:** Two independent changes. First, `SceneObject` stops latching on "didn't draw" (`framesSinceDrawn`) and latches only on "the frustum culled me" (`lastFrameWasCulled`), which makes the two already-existing inner retry paths reachable. Second, `Camera` gains a `projectionVersion` that bumps when frame size or field of view changes — recomputing the camera's own derived frustum state at the same time — and `SceneObject` treats a bump like a geometry change.

**Tech Stack:** BrighterScript compiled with `bsc`; Rooibos v6 (`rooibos-roku`) specs colocated as `*.spec.bs`; `brs-cli` for headless test runs.

**Spec:** `specs/2026-07-29-scene-object-cull-latch-design.md`
**Issue:** [#48](https://github.com/markwpearce/brighterscript-game-engine/issues/48)
**Branch:** `fix_cull_latch_recovery` (already created, spec doc already committed)

## Global Constraints

- All engine source lives under `src/source/` inside the `BGE` namespace. Specs live in `namespace tests`.
- `bslint.json` sets `inline-if-style: never` — never write a single-line `if`. Always use a multi-line `if` / `end if`.
- **A `*.spec.bs` file may contain only one `@suite` class.** Two or more silently corrupt Rooibos metadata and crash the run.
- **`assertEqual` is type-strict**: `1` (Integer) and `1.0` (Float) fail against each other. When a comparison fails unexpectedly, read the actual/expected *types* out of the Rooibos failure diff rather than guessing.
- A spec must call `Renderer.setupCameraForFrame()` before `Renderer.drawScene()`, or a `Camera3d`'s frustum normals are uninitialised and `isInView` fails for reasons unrelated to the test.
- Never compare whole engine objects with `assertEqual` — they embed circular references and native components. Compare a distinguishing scalar.
- Public engine methods get JSDoc-style `'` comments with `@param`/`@return`. Protected/internal ones get a plain explanatory comment.
- Do not commit anything under `docs-site/` (gitignored, generated).
- Per-task verification is `npm run test:ci`. The full gate before the PR is `npm run validate && npm run lint && npm run test:ci`.

## A correction to the spec, folded into this plan

The spec says the camera half is "bump a version number". Reading the camera code more closely, that alone would not work, and Task 2 is written to handle it:

On a projection change the camera's **own derived state is stale**, so `isInView` would keep answering from the old projection and the un-latched object would simply be culled again:

- `Camera3d.frustumNormals` is recomputed inside `onCameraMovement()` and only when the *orientation* changed (`Camera3d.bs:127`). A field-of-view change alone recomputes nothing.
- `Camera3d.frustumRays` and `frustrumConvergence` are likewise only recomputed on movement, and both depend on `fieldOfViewDegrees` and `frameSize`.
- `getVerticalFOV()` (`Camera3d.bs:400`) derives from `frameSize`, so a frame-size change also changes the vertical FOV feeding the normals.
- `Camera2d.isInView` reads `top`/`bottom`/`left`/`right`, which are computed inside `computeWorldToCameraMatrix()` (`Camera2d.bs:40-53`) — and `Renderer.setupCameraForFrame()` only calls that when the camera *moved* (`Renderer.bs:157`).

So a projection change must also **recompute that derived state**, not merely signal that it changed. Task 2 does both.

## File Structure

**Modified:**

- `src/source/engine/renderer/sceneObjects/SceneObject.bs` — Tasks 1 and 3. The latch, and consuming the camera's projection version.
- `src/source/engine/renderer/cameras/Camera.bs` — Task 2. Base projection-version detection plus the `onProjectionChange()` hook.
- `src/source/engine/renderer/cameras/Camera3d.bs` — Task 2. Adds the field-of-view term to the detection, and recomputes the frustum on change.
- `src/source/engine/renderer/cameras/Camera.spec.bs` — Task 2.
- `src/source/engine/renderer/cameras/Camera3d.spec.bs` — Task 2.
- `src/source/engine/renderer/sceneObjects/SceneObjectImage.spec.bs` — Tasks 1 and 3.
- `docs/drawables-and-scene-objects.md` — Task 4. Lines 193-195 describe the old gate.

**Created:**

- `src/source/engine/renderer/sceneObjects/SceneObjectTestDoubles.spec.bs` — Task 1. Holds the one test-only subclass, and **no `@suite`**, so it never trips the one-suite-per-file rule and is excluded from production builds for free by `bsconfig.build.json`'s `*.spec.bs` glob.

The design doc proposed trying a helper class inside `SceneObjectImage.spec.bs` first. This plan skips that experiment and goes straight to the separate file: it costs nothing, and the documented Rooibos failure mode is a *silent* metadata corruption whose crash surfaces in an unrelated suite, which is a miserable thing to debug for no benefit.

---

### Task 1: Latch on cull, not on "didn't draw"

**Files:**
- Create: `src/source/engine/renderer/sceneObjects/SceneObjectTestDoubles.spec.bs`
- Modify: `src/source/engine/renderer/sceneObjects/SceneObject.bs` (fields ~143-147, `draw()` 242-268, `isPotentiallyOnScreen()` 357-373, `resetFrameSinceDrawn()` 343-346)
- Test: `src/source/engine/renderer/sceneObjects/SceneObjectImage.spec.bs`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `SceneObject.lastFrameWasCulled` (protected boolean). Removes `SceneObject.framesSinceDrawn` and `SceneObject.resetFrameSinceDrawn()` — no other file references either (verified by grep).

- [ ] **Step 1: Create the test double**

Create `src/source/engine/renderer/sceneObjects/SceneObjectTestDoubles.spec.bs`:

```brightscript
namespace tests

  ' Test-only SceneObject subclasses. This file deliberately contains no @suite - Rooibos
  ' allows only one @suite per file, and these are shared across suites.
  '
  ' A transient draw failure (a scratch bitmap that couldn't be allocated, a corner that
  ' failed to project) can't be induced through the public API, so this fakes one: it is
  ' the only way to cover the recovery path in SceneObject.draw().
  class FailingSceneObjectImage extends BGE.SceneObjectImage

    ' While true, every draw attempt fails as though the real draw call had failed.
    public shouldFail = true

    protected override function performDraw(rendererObj as BGE.Renderer, drawMode as BGE.SceneObjectDrawMode) as boolean
      if m.shouldFail
        return false
      end if
      return super.performDraw(rendererObj, drawMode)
    end function

  end class

end namespace
```

- [ ] **Step 2: Write the failing test**

Append to `SceneObjectImage.spec.bs`, immediately before the closing `end class` (after the `"changing draw mode on a stationary object"` block, which already provides the `drawFrames(count)` helper this uses):

```brightscript
    @describe("recovering from a failed draw")

    ' A draw that fails must not latch the object off. The frustum-cull shortcut in
    ' isPotentiallyOnScreen() declines to re-examine a culled object until something moves,
    ' and nothing here moves - so if a failure is treated as a cull, the object never draws
    ' again. See issue #48.
    @it("draws again on the very next frame after a transient draw failure clears")
    function _()
      imageDrawable = m.newImage()
      failing = new tests.FailingSceneObjectImage("failing", imageDrawable)
      m.renderer.addSceneObject(failing)
      m.entity.updateTransformationMatrix()

      ' three frames is enough for the object to settle: MotionChecker reports moved until
      ' the first computeTransformationMatrix, and the first frame is always a mode change
      m.assertEqual(0, m.drawFrames(3))

      failing.shouldFail = false
      m.assertTrue(m.drawFrames(1) > 0)
    end function
```

- [ ] **Step 3: Run the test and verify it fails**

Run: `npm run test:ci`

Expected: FAIL on `"draws again on the very next frame after a transient draw failure clears"`, with the final assertion getting `0` draw calls. Every other test passes. If it *passes*, stop — the reproduction is wrong and the rest of the task is unfounded.

- [ ] **Step 4: Replace the field**

In `SceneObject.bs`, replace line 143:

```brightscript
    protected framesSinceDrawn = 0
```

with:

```brightscript
    ' Whether the last frame's draw was skipped because the frustum rejected this object.
    ' Only a genuine cull latches: nothing moved, so re-running the check would give the
    ' same answer, and skipping it is what makes a static off-screen object free. A draw
    ' that was attempted and *failed* must not latch - findCanvasPosition() and
    ' performDraw() both already retry on the following frame, and treating their failure
    ' as a cull is what made one bad frame permanent. See issue #48.
    protected lastFrameWasCulled = false
```

- [ ] **Step 5: Rewrite the gate in `draw()`**

In `SceneObject.bs`, replace lines 242-268 (the whole `sub draw`) with:

```brightscript
    sub draw(rendererObj as Renderer)
      drawModeToUse = m.getActualDrawMode(rendererObj.camera)
      modeChanged = m.drawModeChanged(drawModeToUse)
      ' A mode change bypasses the on-screen shortcut as well as the geometry cache: that
      ' shortcut declines to re-examine a culled object until something moves, so a
      ' stationary object in a new draw mode would never be reconsidered.
      enteredDrawPath = modeChanged or m.isPotentiallyOnScreen(rendererObj.camera)
      if enteredDrawPath
        if m.objMovedInRelationToCamera(rendererObj.camera) or not m.hasValidCanvasPosition or m.isFirstFrameSinceEnabled or m.geometryChanged() or modeChanged
          m.hasValidCanvasPosition = m.findCanvasPosition(rendererObj, drawModeToUse)
        end if
        if m.hasValidCanvasPosition
          if m.performDraw(rendererObj, drawModeToUse)
            m.afterDraw()
          end if
        end if
      end if
      m.lastFrameWasCulled = not enteredDrawPath
      m.isFirstFrameSinceEnabled = false
      m.lastGeometryVersion = m.drawable.geometryVersion
      m.lastDrawMode = drawModeToUse
    end sub
```

The `didDraw` local is gone: its only remaining job was choosing between `resetFrameSinceDrawn()` and `framesSinceDrawn++`, and it now gates nothing but `afterDraw()`.

- [ ] **Step 6: Delete `resetFrameSinceDrawn()`**

In `SceneObject.bs`, delete lines 343-346 in full:

```brightscript
    ' Reset the frame count since the object was drawn
    protected sub resetFrameSinceDrawn()
      m.framesSinceDrawn = 0
    end sub
```

- [ ] **Step 7: Update the short-circuit in `isPotentiallyOnScreen()`**

In `SceneObject.bs`, replace:

```brightscript
      if m.framesSinceDrawn = 0 or m.isFirstFrameSinceEnabled
        return true
      end if
```

with:

```brightscript
      if not m.lastFrameWasCulled or m.isFirstFrameSinceEnabled
        return true
      end if
```

Behaviour on the first frame is unchanged: `framesSinceDrawn = 0` and `lastFrameWasCulled = false` both mean "reconsider me".

- [ ] **Step 8: Confirm nothing else referenced the removed members**

Run: `grep -rn "framesSinceDrawn\|resetFrameSinceDrawn" src examples`

Expected: no output. If anything matches, it must be updated before continuing.

- [ ] **Step 9: Run the full check**

Run: `npm run validate && npm run lint && npm run test:ci`

Expected: all pass, including the new recovery test.

- [ ] **Step 10: Commit**

```bash
git add src/source/engine/renderer/sceneObjects/SceneObject.bs \
        src/source/engine/renderer/sceneObjects/SceneObjectTestDoubles.spec.bs \
        src/source/engine/renderer/sceneObjects/SceneObjectImage.spec.bs
git commit -m "Latch a SceneObject on a genuine cull, not on any failed draw

isPotentiallyOnScreen() short-circuited on framesSinceDrawn, which
cannot tell a frustum cull from a draw that was attempted and failed.
Only the cull justifies latching. findCanvasPosition() and performDraw()
already retry on the next frame; they were simply unreachable.

Refs #48"
```

---

### Task 2: A camera projection change bumps a version and rebuilds derived state

**Files:**
- Modify: `src/source/engine/renderer/cameras/Camera.bs` (fields ~12-18, `checkMovement()` 51-62)
- Modify: `src/source/engine/renderer/cameras/Camera3d.bs` (fields ~100-110, `onCameraMovement()` 123-140)
- Test: `src/source/engine/renderer/cameras/Camera.spec.bs`, `src/source/engine/renderer/cameras/Camera3d.spec.bs`

**Interfaces:**
- Consumes: nothing from Task 1.
- Produces, on `BGE.Camera`:
  - `projectionVersion as integer` — public, starts at `0`, increments on every detected projection change.
  - `sub bumpProjectionVersion()` — public.
  - `protected function projectionChangedThisFrame() as boolean` — detection; subclasses override to add their own terms.
  - `protected sub onProjectionChange()` — rebuild hook; subclasses override to add their own derived state.
  - `sub checkProjectionChange()` — public, orchestrates the two; called from `checkMovement()`.
- Produces, on `BGE.Camera3d`: `protected sub recomputeFrustum(recomputeNormals as boolean)`.

- [ ] **Step 1: Write the failing tests**

Append to `Camera.spec.bs`, before the closing `end class`:

```brightscript
    @describe("projectionVersion")

    ' isInView and the projection matrix are derived from frame size, but Camera's
    ' MotionChecker only watches position and orientation - so a frame-size change is
    ' invisible to every "did anything change?" check in the renderer. See issue #48.
    @it("starts at zero")
    function _()
      m.assertEqual(0, m.camera.projectionVersion)
    end function

    @it("bumps when the frame size changes")
    function _()
      m.camera.setFrameSize(100, 100)
      m.camera.checkMovement()
      before = m.camera.projectionVersion

      m.camera.setFrameSize(200, 100)
      m.camera.checkMovement()
      m.assertTrue(m.camera.projectionVersion > before)
    end function

    @it("holds steady when nothing about the projection changed")
    function _()
      m.camera.setFrameSize(100, 100)
      m.camera.checkMovement()
      before = m.camera.projectionVersion

      m.camera.checkMovement()
      m.assertEqual(before, m.camera.projectionVersion)
    end function

    @it("bumps on demand via bumpProjectionVersion")
    function _()
      before = m.camera.projectionVersion
      m.camera.bumpProjectionVersion()
      m.assertTrue(m.camera.projectionVersion > before)
    end function
```

- [ ] **Step 2: Write the failing Camera3d test**

Open `src/source/engine/renderer/cameras/Camera3d.spec.bs` and read its `beforeEach` to learn the field name it stores the camera under. The block below assumes `m.camera`; **rename to match the existing file if it differs.** Append before the closing `end class`:

```brightscript
    @describe("projectionVersion and the frustum")

    ' fieldOfViewDegrees is a plain public field, so no setter can intercept a write to it -
    ' it has to be dirty-checked. And the frustum normals it feeds are otherwise only
    ' recomputed when the *orientation* changes, so a FOV change alone would leave isInView
    ' answering from the old frustum. See issue #48.
    @it("bumps projectionVersion when the field of view changes")
    function _()
      m.camera.setFrameSize(200, 200)
      m.camera.checkMovement()
      before = m.camera.projectionVersion

      m.camera.fieldOfViewDegrees = 45
      m.camera.checkMovement()
      m.assertTrue(m.camera.projectionVersion > before)
    end function

    @it("holds projectionVersion steady when the field of view is unchanged")
    function _()
      m.camera.setFrameSize(200, 200)
      m.camera.checkMovement()
      before = m.camera.projectionVersion

      m.camera.checkMovement()
      m.assertEqual(before, m.camera.projectionVersion)
    end function

    @it("widens what isInView accepts when the field of view widens")
    function _()
      m.camera.setFrameSize(200, 200)
      m.camera.position = BGE.Math.VectorOps.create(0, 0, 1000)
      m.camera.fieldOfViewDegrees = 20
      m.camera.checkMovement()

      offToTheSide = BGE.Math.VectorOps.create(900, 0, 0)
      m.assertFalse(m.camera.isInView(offToTheSide))

      m.camera.fieldOfViewDegrees = 120
      m.camera.checkMovement()
      m.assertTrue(m.camera.isInView(offToTheSide))
    end function
```

- [ ] **Step 3: Run the tests and verify they fail**

Run: `npm run test:ci`

Expected: the new `Camera` and `Camera3d` cases fail. The first ones fail to compile or error on the unknown `projectionVersion` member; that is a legitimate red. Everything pre-existing still passes.

- [ ] **Step 4: Add the version and detection to `Camera`**

In `Camera.bs`, after the `frameSize` field (line 12), add:

```brightscript
    ' Bumped whenever something about the camera's projection - as opposed to its
    ' position or orientation - changes. MotionChecker watches only position and
    ' orientation, so without this a frame-size or field-of-view change is invisible to
    ' every dirty check in the renderer, and a stationary culled object stays culled
    ' through a projection change that should have brought it back into view.
    projectionVersion as integer = 0

    ' Last frame size seen by checkProjectionChange(). Stored as two scalars rather than a
    ' Vector so it can't alias the live frameSize object and compare equal to itself.
    private lastProjectionFrameWidth as float = -1
    private lastProjectionFrameHeight as float = -1
```

- [ ] **Step 5: Add the three methods to `Camera`**

In `Camera.bs`, immediately after `setFrameSize()` (which ends at line 26), add:

```brightscript
    ' Force a projection change to be reported this frame. Public so a future setter can
    ' declare a change explicitly rather than relying on the dirty check to spot it.
    sub bumpProjectionVersion()
      m.projectionVersion++
    end sub

    ' Detect and act on a projection change. Called once per frame from checkMovement().
    sub checkProjectionChange()
      if m.projectionChangedThisFrame()
        m.bumpProjectionVersion()
        m.onProjectionChange()
      end if
    end sub

    ' Whether anything feeding the projection changed since the last frame, recording the
    ' new values as it goes. Override in a subclass to add its own terms - and call
    ' super.projectionChangedThisFrame() unconditionally, never inside a boolean
    ' expression, so its recording side effect always runs.
    '
    ' @return {boolean} true if the projection changed
    protected function projectionChangedThisFrame() as boolean
      if m.lastProjectionFrameWidth = m.frameSize.x and m.lastProjectionFrameHeight = m.frameSize.y
        return false
      end if
      m.lastProjectionFrameWidth = m.frameSize.x
      m.lastProjectionFrameHeight = m.frameSize.y
      return true
    end function

    ' Rebuild whatever the camera derives from its projection. Renderer only rebuilds the
    ' world-to-camera matrix when the camera moved, and Camera2d's isInView bounds
    ' (top/bottom/left/right) are computed inside that matrix build - so a frame-size
    ' change with a stationary camera would otherwise leave them stale.
    protected sub onProjectionChange()
      m.computeWorldToCameraMatrix()
    end sub
```

- [ ] **Step 6: Call it from `checkMovement()`**

In `Camera.bs`, make `checkProjectionChange()` the first statement of `checkMovement()` — before the early `return`, so it runs on every frame:

```brightscript
    sub checkMovement()
      m.checkProjectionChange()

      currentlyMoved = m.motionChecker.check(m.position, m.orientation)
      if m.movedLastFrame() and not currentlyMoved
        m.motionChecker.resetMovedFlag()
        return
      end if

      if currentlyMoved
        m.onCameraMovement()
        m.motionChecker.setTransform(m.position, m.orientation)
      end if
    end sub
```

`Renderer.setupCameraForFrame()` (`Renderer.bs:153-160`) already calls `setFrameSize()` and *then* `checkMovement()` every frame, so the dirty check sees the current frame size and needs no new plumbing.

- [ ] **Step 7: Extract the frustum rebuild in `Camera3d`**

In `Camera3d.bs`, replace `onCameraMovement()` (lines 123-140) with:

```brightscript
    override sub onCameraMovement()
      ' The normals depend only on orientation and FOV, so movement alone doesn't dirty them
      rotated = BGE.Math.VectorOps.norm(m.motionChecker.getRotationDifference(m.orientation)) > 0
      m.recomputeFrustum(rotated)
    end sub

    ' Rebuild the frustum from the camera's current position, orientation and field of view.
    '
    ' @param {boolean} recomputeNormals whether the frustum plane normals need rebuilding too
    protected sub recomputeFrustum(recomputeNormals as boolean)
      vertFov = m.getVerticalFOV()

      if recomputeNormals
        m.frustumNormals.setNormals(m.orientation, m.fieldOfViewDegrees, vertFov)
      end if

      m.frustumRays.setRays(m.position, m.orientation, m.fieldOfViewDegrees, vertFov, m.getUpVector(), m.getRightVector())

      ' make the frustrum converge BEHIND the camera, instead of at the camera's position, so
      ' items on edge of frame don't get cut off
      ' This simply puts the convergence such that the whole frame will be in the frustrum
      ' There are probably better ways of doing this
      fovRad = BGE.Math.DegreesToRadians(m.fieldOfViewDegrees)
      halfFrameSize = BGE.Math.max(m.frameSize.x, m.frameSize.y) / 2
      m.frustrumConvergence = BGE.Math.VectorOps.subtract(m.position, BGE.Math.VectorOps.scale(m.orientation, halfFrameSize * cos(fovRad / 2)))
    end sub
```

This is a pure extraction — the movement path behaves exactly as before.

- [ ] **Step 8: Add the FOV term and the frustum rebuild to `Camera3d`**

In `Camera3d.bs`, after the `fieldOfViewDegrees` field (line 100), add:

```brightscript
    ' Last field of view seen by projectionChangedThisFrame(). fieldOfViewDegrees is a
    ' plain public field that consumers write directly, so it has to be dirty-checked -
    ' a setter would be silently bypassed.
    private lastProjectionFieldOfView as float = -1
```

and, next to the other overrides, add:

```brightscript
    protected override function projectionChangedThisFrame() as boolean
      ' called unconditionally rather than inside an `or`, so it always records the new
      ' frame size even when the FOV changed too
      changed = super.projectionChangedThisFrame()

      if m.lastProjectionFieldOfView <> m.fieldOfViewDegrees
        m.lastProjectionFieldOfView = m.fieldOfViewDegrees
        changed = true
      end if

      return changed
    end function

    protected override sub onProjectionChange()
      super.onProjectionChange()
      ' the normals are otherwise only rebuilt on a rotation, and both they and the rays
      ' depend on the field of view and (via getVerticalFOV) the frame size
      m.recomputeFrustum(true)
    end sub
```

- [ ] **Step 9: Run the tests and verify they pass**

Run: `npm run validate && npm run lint && npm run test:ci`

Expected: all pass, including the seven new camera cases. If `"widens what isInView accepts"` still fails, the frustum rebuild isn't being reached — check that `onProjectionChange()` is spelled identically in both classes so the override actually binds.

- [ ] **Step 10: Commit**

```bash
git add src/source/engine/renderer/cameras/Camera.bs \
        src/source/engine/renderer/cameras/Camera3d.bs \
        src/source/engine/renderer/cameras/Camera.spec.bs \
        src/source/engine/renderer/cameras/Camera3d.spec.bs
git commit -m "Detect camera projection changes and rebuild the frustum from them

Camera's MotionChecker watches only position and orientation, so a
change to frameSize or fieldOfViewDegrees was invisible: the frustum
normals, rays and convergence all kept their old values, as did
Camera2d's isInView bounds. Dirty-check both, since fieldOfViewDegrees
is a public field no setter could intercept.

Refs #48"
```

---

### Task 3: `SceneObject` treats a projection change as an invalidation

**Files:**
- Modify: `src/source/engine/renderer/sceneObjects/SceneObject.bs` (fields ~152-155, `draw()` as rewritten in Task 1)
- Test: `src/source/engine/renderer/sceneObjects/SceneObjectImage.spec.bs`

**Interfaces:**
- Consumes: `BGE.Camera.projectionVersion as integer` from Task 2; `SceneObject.lastFrameWasCulled` and the `enteredDrawPath` shape of `draw()` from Task 1.
- Produces: `SceneObject.lastProjectionVersion as integer`, `protected function projectionChanged(cameraObj as Camera) as boolean`.

- [ ] **Step 1: Write the failing test**

Append to `SceneObjectImage.spec.bs`, before the closing `end class`:

```brightscript
    @describe("recovering from a camera projection change")

    ' A culled object is deliberately not reconsidered until it or the camera moves - but
    ' the camera's MotionChecker doesn't count a field-of-view change as movement, so
    ' without an explicit signal the object stays culled through a change that should have
    ' brought it back into view. Nothing here moves. See issue #48.
    @it("draws again after the field of view widens to include it")
    function _()
      ' well outside a 20-degree field of view at this distance, comfortably inside 120
      m.entity.position = BGE.Math.VectorOps.create(900, 0, 0)
      m.renderer.camera.fieldOfViewDegrees = 20

      imageDrawable = m.newImage()
      imageDrawable.addToScene(m.renderer)
      m.entity.updateTransformationMatrix()
      m.assertEqual(0, m.drawFrames(3))

      m.renderer.camera.fieldOfViewDegrees = 120
      m.assertTrue(m.drawFrames(1) > 0)
    end function
```

- [ ] **Step 2: Run the test and verify it fails**

Run: `npm run test:ci`

Expected: FAIL on `"draws again after the field of view widens to include it"`, with `0` draw calls after the widening. The camera's frustum is now correct (Task 2), but the scene object is still latched.

Sanity-check the *first* assertion held: if `m.assertEqual(0, m.drawFrames(3))` is what failed, the object was never culled to begin with and the test proves nothing — widen the offset or narrow the FOV until it is.

- [ ] **Step 3: Add the tracking field**

In `SceneObject.bs`, after `lastDrawMode` (line 155), add:

```brightscript
    ' The camera's `projectionVersion` as of the last draw - see projectionChanged()
    protected lastProjectionVersion as integer = -1
```

- [ ] **Step 4: Add the comparison**

In `SceneObject.bs`, immediately after `geometryChanged()` (which ends at line 298), add:

```brightscript
    ' Whether the camera's projection - its frame size or field of view - changed since
    ' this object last drew. Neither counts as camera movement, so the motion dirty-check
    ' can't see them, and both change where a world point lands on the canvas and what the
    ' frustum accepts. Tracked as a version number rather than a flag for the same reason
    ' geometryVersion is: one camera serves every SceneObject in its renderer, so no single
    ' object may clear it.
    '
    ' @param {Camera} cameraObj
    ' @return {boolean} true if the camera's projection changed since the last draw
    protected function projectionChanged(cameraObj as Camera) as boolean
      return m.lastProjectionVersion <> cameraObj.projectionVersion
    end function
```

- [ ] **Step 5: Wire it into `draw()`**

In `SceneObject.bs`, in the `draw()` written in Task 1, add the projection check to the two conditions and record the version at the end. The method becomes:

```brightscript
    sub draw(rendererObj as Renderer)
      drawModeToUse = m.getActualDrawMode(rendererObj.camera)
      modeChanged = m.drawModeChanged(drawModeToUse)
      projectionChanged = m.projectionChanged(rendererObj.camera)
      ' A mode change or a camera projection change bypasses the on-screen shortcut as well
      ' as the geometry cache: that shortcut declines to re-examine a culled object until
      ' something moves, and neither of these counts as movement.
      enteredDrawPath = modeChanged or projectionChanged or m.isPotentiallyOnScreen(rendererObj.camera)
      if enteredDrawPath
        if m.objMovedInRelationToCamera(rendererObj.camera) or not m.hasValidCanvasPosition or m.isFirstFrameSinceEnabled or m.geometryChanged() or modeChanged or projectionChanged
          m.hasValidCanvasPosition = m.findCanvasPosition(rendererObj, drawModeToUse)
        end if
        if m.hasValidCanvasPosition
          if m.performDraw(rendererObj, drawModeToUse)
            m.afterDraw()
          end if
        end if
      end if
      m.lastFrameWasCulled = not enteredDrawPath
      m.isFirstFrameSinceEnabled = false
      m.lastGeometryVersion = m.drawable.geometryVersion
      m.lastDrawMode = drawModeToUse
      m.lastProjectionVersion = rendererObj.camera.projectionVersion
    end sub
```

Deliberately **not** added to `update()`'s `forceRecompute`: frame size and field of view change where a point lands on the canvas and what the frustum accepts, not where the object sits in the world.

- [ ] **Step 6: Run the tests and verify they pass**

Run: `npm run validate && npm run lint && npm run test:ci`

Expected: all pass, including both new `SceneObjectImage` recovery tests.

- [ ] **Step 7: Commit**

```bash
git add src/source/engine/renderer/sceneObjects/SceneObject.bs \
        src/source/engine/renderer/sceneObjects/SceneObjectImage.spec.bs
git commit -m "Reconsider a culled SceneObject when the camera projection changes

A frame-size or field-of-view change is not camera movement, so a
culled stationary object was never re-examined after one. Mirrors the
existing geometryVersion/lastGeometryVersion pair.

Refs #48"
```

---

### Task 4: Documentation and pull request

**Files:**
- Modify: `docs/drawables-and-scene-objects.md:193-195`
- Modify: `specs/2026-07-29-scene-object-cull-latch-design.md`

**Interfaces:**
- Consumes: the finished behaviour from Tasks 1-3.
- Produces: nothing consumed by later tasks.

- [ ] **Step 1: Update the per-frame work guide**

In `docs/drawables-and-scene-objects.md`, replace the bullet at lines 193-195:

```markdown
- **`isPotentiallyOnScreen(cameraObj)`** - a cheap frustum check gate in `draw()`. If the object
  hasn't moved relative to the camera and was on-screen last frame, it skips straight to drawing;
  otherwise it checks the camera's frustum before doing any real work.
```

with:

```markdown
- **`isPotentiallyOnScreen(cameraObj)`** - a cheap frustum check gate in `draw()`. If the object
  drew last frame it skips straight to drawing; if the frustum *culled* it last frame and nothing
  has moved since, it stays culled without re-checking, which is what makes a static off-screen
  object free. Only a genuine cull latches this way: a draw that was attempted and failed is
  retried on the very next frame, because `findCanvasPosition()` and `performDraw()` are both
  transient-failure-prone and both already recover. A camera *projection* change - its frame size
  or field of view, neither of which counts as camera movement - lifts the latch too, via
  `Camera.projectionVersion`.
```

- [ ] **Step 2: Reconcile the design doc with what was built**

In `specs/2026-07-29-scene-object-cull-latch-design.md`, the section "2. A camera projection change invalidates the latch" describes only the version bump. Append this paragraph to the end of that section:

```markdown
**Amended during planning.** A version bump alone is not sufficient: on a projection change the
camera's own derived state is stale too, so `isInView` would answer from the old projection and
the un-latched object would simply be culled again. `Camera3d.frustumNormals` is rebuilt only when
the *orientation* changes (`Camera3d.bs:127`); `frustumRays` and `frustrumConvergence` only on
movement; and `Camera2d`'s `top`/`bottom`/`left`/`right` inside `computeWorldToCameraMatrix()`,
which the renderer calls only when the camera moved. So `checkProjectionChange()` also invokes an
`onProjectionChange()` hook - rebuilding the projection matrix on the base class, and the full
frustum on `Camera3d` via an extracted `recomputeFrustum(recomputeNormals)`.
```

Also update the "One mechanical question for the plan to resolve" subsection to record the decision — replace its body with:

```markdown
Resolved: the helper subclass lives in its own `SceneObjectTestDoubles.spec.bs` containing no
`@suite`. The same-file experiment was skipped deliberately - it costs nothing to avoid, and the
documented Rooibos failure mode is a silent metadata corruption that surfaces as a crash in an
unrelated suite.
```

- [ ] **Step 3: Run the full gate one last time**

Run: `npm run validate && npm run lint && npm run test:ci`

Expected: all pass.

- [ ] **Step 4: Check the docs site still builds**

Run: `npm run docs`

Expected: completes without error. Confirm with `git status --short` that nothing under `docs-site/` is staged for commit — it is gitignored and must stay that way.

- [ ] **Step 5: Commit**

```bash
git add docs/drawables-and-scene-objects.md specs/2026-07-29-scene-object-cull-latch-design.md
git commit -m "Document the cull latch and the camera projection version

Refs #48"
```

- [ ] **Step 6: Open the pull request**

```bash
git push -u origin fix_cull_latch_recovery
gh pr create --base main --title "Make a culled SceneObject recoverable" --body "$(cat <<'EOF'
Closes #48.

`SceneObject.isPotentiallyOnScreen()` short-circuited on `framesSinceDrawn`, which cannot tell a frustum cull from a draw that was attempted and failed. Only the cull justifies latching — nothing moved, so re-running the check gives the same answer. A failure does not: `findCanvasPosition()` and `performDraw()` both already retry on the following frame, and were simply unreachable behind the gate. One bad frame was therefore permanent for a stationary object in front of a stationary camera.

Replaces `framesSinceDrawn` with `lastFrameWasCulled`, set only on the genuine-cull path. The optimisation is unchanged: a culled static object still costs one boolean test per frame until something moves.

Also closes a second instance of the same trap. `Camera.movedLastFrame()` dirty-checks only position and orientation, so a change to `frameSize` or `fieldOfViewDegrees` left a culled object culled. `Camera` now carries a `projectionVersion` that `SceneObject` compares against, mirroring the existing `geometryVersion` pair. That needed more than a version bump: the camera's own frustum normals, rays and convergence — and `Camera2d`'s `isInView` bounds — were all stale after such a change, so `onProjectionChange()` rebuilds them.

## Testing

Three new specs, each confirmed to fail before its fix:

- a transient `performDraw` failure clears and the object draws on the very next frame
- widening `fieldOfViewDegrees` brings a culled stationary object back
- `Camera3d.isInView` accepts a wider angle once the field of view widens

Plus unit coverage for `projectionVersion` bumping and holding steady.

`npm run validate && npm run lint && npm run test:ci` all pass.

## Not included

- No periodic retry backstop, and no `drew`/`culled`/`failed` enum — see the design doc's "Out of scope".
- `update()` omits `cameraObj.movedLastFrame()` from `forceRecompute`, which may matter for `directScaled`'s camera-facing quad. Noticed while working here, unrelated to this fix, worth its own issue.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 7: File the follow-up issue**

```bash
gh issue create --title "update() omits camera movement from forceRecompute, which may stale directScaled's quad" --label bug --body "$(cat <<'EOF'
Noticed while fixing #48.

`SceneObject.update(cameraObj)` builds `forceRecompute` from the object's own movement, world-position validity, first-frame-since-enabled, geometry version and draw-mode change — but **not** `cameraObj.movedLastFrame()`.

For most draw modes that is correct: world position doesn't depend on the camera. But `updateWorldPosition()` in the `directScaled` branch builds a quad *facing the camera*, which does. A stationary object in `directScaled` in front of a moving camera may therefore keep a quad oriented for where the camera used to be.

Unverified — it may be masked by `findCanvasPosition()` re-running on camera movement in `draw()`. Worth reproducing in `examples/3d` (Play cycles the modes) before deciding whether it's real.
EOF
)"
```

---

## Self-Review

**Spec coverage.** Every section of the design doc maps to a task: "Latch on cull, not on didn't-draw" → Task 1; "A camera projection change invalidates the latch" → Tasks 2 and 3; all three Testing bullets → Task 1 Step 2, Task 3 Step 1, Task 2 Steps 1-2; "One mechanical question" → resolved in File Structure and recorded in Task 4 Step 2; "Out of scope" → restated in the PR body; "Verification" → the full gate runs in Tasks 1, 2, 3 and 4.

One spec statement is contradicted on purpose and flagged in its own section above: the camera half needs a derived-state rebuild, not just a version bump. Task 4 Step 2 amends the design doc to match.

**Placeholders.** None. Every code step carries the literal text to write; every run step names the command and the expected result.

**Type consistency.** `projectionVersion as integer` on `Camera` matches `lastProjectionVersion as integer` on `SceneObject`, both compared with `<>`. `projectionChangedThisFrame() as boolean` and `onProjectionChange()` keep identical signatures between `Camera` and the `Camera3d` overrides. `recomputeFrustum(recomputeNormals as boolean)` is declared in Task 2 Step 7 and called in Steps 7 and 8. `performDraw(rendererObj as BGE.Renderer, drawMode as BGE.SceneObjectDrawMode) as boolean` in the test double matches `SceneObjectBillboard.bs:45`. `lastFrameWasCulled` is introduced in Task 1 and reused verbatim in Task 3's rewrite of `draw()`.

**Ordering.** Task 1 does not reference `projectionChanged`, so it is independently committable and testable; Task 3 adds it to both conditions. Task 3's test depends on Task 2's frustum rebuild — run out of order it would fail for the wrong reason.
