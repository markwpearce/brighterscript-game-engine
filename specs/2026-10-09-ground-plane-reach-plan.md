# Ground Plane Reach Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Objects that belong on the ground are never drawn above it: the ground's far edge is the objects' far-clip depth, and the ground reaches the highest quality level's distance.

**Architecture:** `SceneObjectPlane` builds its far corners on the forward-depth plane at F instead of a circle. `Camera3d.getPlaneDrawDistance()` becomes the largest distance any quality level could use (pushed from `RenderQualityManager` through `Renderer`), never less than the object distance; the eased object distance is clamped to it. The plane's top-down bitmap gets a pixel budget so memory/cost stay at today's default.

**Tech Stack:** BrighterScript, Rooibos v6 headless tests (`npm run check`), rokubot for device checks.

**Spec:** `specs/2026-10-09-ground-plane-reach-design.md`

## Global Constraints

- Branch `feature/issue-307-floating-beyond-ground` (from `main`). Never commit to `main`.
- Pixel budget: `PLANE_PRE_PERSPECTIVE_MAX_PIXELS = 2000000` (today's default 2000 x 1000).
- Headless runs report as the simulator: device cap 900, so tests use `maxDrawDistance = 500` (Ultra 1.5x = 750 stays under the cap).
- One `@suite` per spec file; `assertEqual` is type-strict (compare floats with a tolerance); never `=` two objects.
- Every file referencing another file's symbols `import`s it.
- After each task `npm run check` must pass; commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **A camera pitched down past half its vertical FOV** (top rays hit the ground far away): expect the ground to stop at depth F, not run to the ray hit. Pinned in Task 2.
2. **A game that sets `drawDistanceScale`/`drawDistanceOverride` on the camera directly** (no `RenderQualityManager`): expect the ground to still reach at least the object distance. Pinned in Task 3.
3. **`overridePreset()` raising a level's scale above the presets**: expect the ground to grow to match. Pinned in Task 3.
4. **A game shrinking `maxDrawDistance` mid-transition**: expect objects clipped inside the (immediately shrunk) ground. Pinned in Task 3.
5. **A `Renderer` used without a `Game`** (`examples/rendererTest`): expect today's behavior at its own level. Pinned in Task 3.

---

### Task 1: Pixel budget for the pre-perspective bitmap

**Files:**
- Create: `src/source/engine/renderer/sceneObjects/PlaneBitmapSizing.bs`
- Create: `src/source/engine/renderer/sceneObjects/PlaneBitmapSizing.spec.bs`
- Modify: `src/source/engine/renderer/sceneObjects/SceneObjectPlane.bs` (`getPrePerspectiveBmp()`, add import)

**Interfaces:**
- Produces: `BGE.getPlanePrePerspectiveBmpSize(farDistance as float, fovDegrees as float, maxPixels as float) as SizeWH` and `const PLANE_PRE_PERSPECTIVE_MAX_PIXELS = 2000000` (namespace `BGE`).

- [ ] **Step 1: failing test** - `PlaneBitmapSizing.spec.bs`:

```brighterscript
namespace tests

  @suite("BGE.getPlanePrePerspectiveBmpSize")
  class PlaneBitmapSizingTests extends rooibos.BaseTestSuite

    @describe("getPlanePrePerspectiveBmpSize")

    @it("is 1 pixel per world unit within the budget")
    function _()
      size = BGE.getPlanePrePerspectiveBmpSize(1000, 90, BGE.PLANE_PRE_PERSPECTIVE_MAX_PIXELS)
      m.assertTrue(abs(size.width - 2000) < 1, `width ${size.width}`)
      m.assertTrue(abs(size.height - 1000) < 1, `height ${size.height}`)
    end function

    @it("scales both sides down to stay within the budget, keeping the aspect ratio")
    function _()
      size = BGE.getPlanePrePerspectiveBmpSize(1500, 90, BGE.PLANE_PRE_PERSPECTIVE_MAX_PIXELS)
      m.assertTrue(size.width * size.height <= BGE.PLANE_PRE_PERSPECTIVE_MAX_PIXELS + 1)
      m.assertTrue(abs(size.width / size.height - 2.0) < 0.01)
    end function

  end class

end namespace
```

- [ ] **Step 2:** `npm run validate` → FAIL (cannot find function).
- [ ] **Step 3: implement** - `PlaneBitmapSizing.bs`:

```brighterscript
import "../../interfaces.bs"
import "../../../math/math.bs"

namespace BGE

  ' A ground plane's top-down bitmap never exceeds this many pixels (the size of the
  ' default 1000-unit draw distance at 90 degrees), so reaching farther costs texture
  ' sharpness rather than memory or draw time.
  const PLANE_PRE_PERSPECTIVE_MAX_PIXELS = 2000000

  ' Size of a ground plane's top-down bitmap: a wedge `farDistance` deep and
  ' 2 * farDistance * tan(fov / 2) wide at 1 pixel per world unit, scaled down
  ' uniformly if that would exceed `maxPixels`.
  '
  ' @param {float} farDistance how far the plane draws, in world units
  ' @param {float} fovDegrees the camera's horizontal field of view
  ' @param {float} maxPixels pixel budget
  ' @return {SizeWH}
  function getPlanePrePerspectiveBmpSize(farDistance as float, fovDegrees as float, maxPixels as float) as SizeWH
    height = farDistance
    width = farDistance * tan(BGE.Math.DegreesToRadians(fovDegrees) / 2) * 2
    if width * height > maxPixels
      scale = Sqr(maxPixels / (width * height))
      width = width * scale
      height = height * scale
    end if
    return {width: width, height: height}
  end function

end namespace
```

In `SceneObjectPlane.bs` add `import "PlaneBitmapSizing.bs"` and replace the body of `getPrePerspectiveBmp()` after `farDistance = camera.getPlaneDrawDistance()`:

```brighterscript
      ' everything downstream works in this bitmap's own pixels, so a scaled-down
      ' bitmap needs no other change (SCENE_OBJECT_PLANE_NEAR_DISTANCE is 0)
      size = BGE.getPlanePrePerspectiveBmpSize(farDistance - nearDistance, camera.fieldOfViewDegrees, BGE.PLANE_PRE_PERSPECTIVE_MAX_PIXELS)
      return CreateObject("roBitmap", {width: size.width, height: size.height, AlphaEnable: true})
```

(delete the old `finalHeight`/`finalWidth` lines).
- [ ] **Step 4:** `npm run check` → PASS.
- [ ] **Step 5:** commit `Cap the ground plane's top-down bitmap at today's default size (#307)`.

---

### Task 2: Far edge on the forward-depth plane

**Files:**
- Modify: `src/source/engine/renderer/sceneObjects/SceneObjectPlane.bs` (`getPerspectivePointsByCamera()`, the block from `projectedRay = ...` through the four `if invalid = output.*` fallbacks)
- Modify: `src/source/engine/renderer/sceneObjects/SceneObjectPlane.spec.bs` (new describe block)

**Interfaces:**
- Produces: `private function getFarEdgeCorner(camera as Camera3d, plane as BGE.Math.Plane, cameraPointOnPlane as BGE.Math.Vector, projectedForward as BGE.Math.Vector, farDistance as float, horizFov as float, side as float) as BGE.Math.Vector` (side -1 left, +1 right).

- [ ] **Step 1: failing tests** - add to `SceneObjectPlane.spec.bs` before `@describe("getRollCanvasSize")`'s first `@it`... (insert as a new describe block at the end of the class):

```brighterscript
    @describe("far edge matches the object far-clip (issue #307)")

    ' Adds a color-fill ground plane, points the camera, renders a few settled frames
    ' and returns the plane's scene object.
    private function renderGround(cameraTarget as BGE.Math.Vector) as object
      colorDrawable = new BGE.DrawablePlane(m.testScene, invalid, {normal: {x: 0, y: 1, z: 0}, point: {x: 0, y: 0, z: 0}}, {fillMode: BGE.PlaneFillMode.color, color: BGE.ColorsRGB.Green})
      m.testScene.addDrawable("Ground", colorDrawable)
      renderer = m.game.canvas.renderer
      camera = renderer.camera as BGE.Camera3d
      camera.position = BGE.Math.VectorOps.create(0, 50, 0)
      camera.setTarget(cameraTarget)
      for i = 1 to 4
        m.testScene.updateTransformationMatrix()
        renderer.setupCameraForFrame()
        renderer.render()
      end for
      return colorDrawable.getSceneObjects()[0] as object
    end function

    @it("reaches the forward depth objects are clipped at, so an object near the limit stands on the ground")
    function _()
      camera = m.game.canvas.renderer.camera as BGE.Camera3d
      camera.maxDrawDistance = 500
      plane = m.renderGround(BGE.Math.VectorOps.create(0, 50, -100))
      objectBase = BGE.Math.VectorOps.create(0, 0, -450)
      m.assertTrue(camera.isInView(objectBase))
      edgeY = camera.worldPointToCanvasPoint(plane.perspectivePoints.actual.topLeft).y
      baseY = camera.worldPointToCanvasPoint(objectBase).y
      m.assertTrue(edgeY <= baseY, `ground edge at y=${edgeY} is below the object's base at y=${baseY}`)
    end function

    @it("stops at the far-clip depth when the camera is pitched down far enough for the top rays to hit the ground")
    function _()
      camera = m.game.canvas.renderer.camera as BGE.Camera3d
      camera.maxDrawDistance = 500
      ' 47 degrees down: the top rays hit the ground ~1400 units out
      plane = m.renderGround(BGE.Math.VectorOps.create(0, 50 - 107.2, -100))
      farCorner = plane.perspectivePoints.actual.topLeft
      depth = BGE.Math.VectorOps.dotProduct(BGE.Math.VectorOps.subtract(farCorner, camera.position), camera.orientation)
      m.assertTrue(depth <= camera.getPlaneDrawDistance() + 1, `far edge at depth ${depth}`)
    end function
```

- [ ] **Step 2:** `npm run test:ci` → both FAIL (edge below base; depth ~1000+).
- [ ] **Step 3: implement.** In `getPerspectivePointsByCamera()`, after `projectedRay` is computed, replace `scaledOrientationFromCameraPointOnPlane` and the two TOP fallbacks (`topRight`, `topLeft`) with depth-plane corners, and add the past-F check. Keep the two bottom fallbacks as they are (they still need `scaledOrientationFromCameraPointOnPlane`, so keep computing it):

```brighterscript
      projectedForward = BGE.Math.VectorOps.getNormalizedCopy(projectedRay.direction)
      if invalid = output.topRight or m.isPastForwardDepth(camera, output.topRight, farDistance)
        output.topRight = m.getFarEdgeCorner(camera, plane, cameraPointOnPlane, projectedForward, farDistance, horizFov, 1)
      end if
      if invalid = output.topLeft or m.isPastForwardDepth(camera, output.topLeft, farDistance)
        output.topLeft = m.getFarEdgeCorner(camera, plane, cameraPointOnPlane, projectedForward, farDistance, horizFov, -1)
      end if
```

and add:

```brighterscript
    private function isPastForwardDepth(camera as Camera3d, point as BGE.Math.Vector, farDistance as float) as boolean
      return BGE.Math.VectorOps.dotProduct(BGE.Math.VectorOps.subtract(point, camera.position), camera.orientation) > farDistance
    end function

    ' A far corner on the plane at forward depth `farDistance` - the same flat depth
    ' Camera3d.isInView() clips objects at - on the left (side -1) or right (+1)
    ' edge of the view. Not a fixed radius around the camera, which would stop the
    ' ground short of the object far-clip straight ahead (issue #307).
    private function getFarEdgeCorner(camera as Camera3d, plane as BGE.Math.Plane, cameraPointOnPlane as BGE.Math.Vector, projectedForward as BGE.Math.Vector, farDistance as float, horizFov as float, side as float) as BGE.Math.Vector
      cameraOffsetDepth = BGE.Math.VectorOps.dotProduct(BGE.Math.VectorOps.subtract(cameraPointOnPlane, camera.position), camera.orientation)
      forwardRate = BGE.Math.VectorOps.dotProduct(projectedForward, camera.orientation)
      if forwardRate <= 0.0001
        forwardRate = 0.0001
      end if
      along = (farDistance - cameraOffsetDepth) / forwardRate
      farCenter = BGE.Math.VectorOps.add(cameraPointOnPlane, BGE.Math.VectorOps.scale(projectedForward, along))
      right = BGE.Math.VectorOps.getNormalizedCopy(BGE.Math.VectorOps.cross(projectedForward, plane.normal))
      halfWidth = farDistance * tan(BGE.Math.DegreesToRadians(horizFov) / 2)
      return BGE.Math.VectorOps.add(farCenter, BGE.Math.VectorOps.scale(right, halfWidth * side))
    end function
```

Before relying on `cross(projectedForward, plane.normal)` being the camera's right, check `BGE.Math.VectorOps.cross` exists (`grep -n "function cross" src/source/math/vector.bs`) and its handedness: for forward (0,0,-1) and normal (0,1,0) the result must be (+1,0,0). If it comes out (-1,0,0), swap the operands. If `cross` doesn't exist, use `BGE.Math.VectorOps.getNormalizedCopy(camera.getLevelRightVector())` projected onto the plane (subtract its normal component) instead.
- [ ] **Step 4:** `npm run check` → PASS. Existing plane tests must still pass (they exercise the static/tiled paths through the same corners).
- [ ] **Step 5:** commit `Put the ground's far edge at the object far-clip depth (#307)`.

---

### Task 3: Ground reach = highest level's distance

**Files:**
- Modify: `src/source/engine/renderer/cameras/Camera.bs` (two fields next to `drawDistanceOverride`)
- Modify: `src/source/engine/renderer/cameras/Camera3d.bs` (`getPlaneDrawDistance()`, `advanceDrawDistance()`)
- Modify: `src/source/engine/renderer/Renderer.bs` (fields, `setPlaneDrawDistanceRange()`, `setupCameraForFrame()`)
- Modify: `src/source/engine/quality/RenderQualityManager.bs` (`new()`, `overridePreset()`, new private `pushPlaneDrawDistanceRange()`)
- Tests: `Camera3d.spec.bs`, `RendererQuality.spec.bs`, `RenderQualityManager.spec.bs`, `SceneObjectPlane.spec.bs`

**Interfaces:**
- Produces: `Camera.planeDrawDistanceScale as float = 1.0`, `Camera.planeDrawDistanceOverride as float = 0.0`; `Renderer.setPlaneDrawDistanceRange(scale as float, override as float)`.

- [ ] **Step 1: failing tests.**

`Camera3d.spec.bs` (append before `end class`):

```brighterscript
    @describe("ground plane reach (issue #307)")

    @it("reaches the plane draw-distance scale")
    function _()
      m.camera.maxDrawDistance = 500
      m.camera.planeDrawDistanceScale = 1.5
      m.assertNear(750.0, m.camera.getPlaneDrawDistance())
    end function

    @it("is never shorter than the object draw distance, even when the camera's scale is set directly")
    function _()
      m.camera.maxDrawDistance = 300
      m.camera.drawDistanceScale = 2.0
      m.assertTrue(m.camera.getPlaneDrawDistance() >= m.camera.getEffectiveMaxDrawDistance())
      m.camera.drawDistanceScale = 1.0
      m.camera.drawDistanceOverride = 800
      m.assertTrue(m.camera.getPlaneDrawDistance() >= 800)
    end function

    @it("never lets the object distance outlast a shrunk ground")
    function _()
      m.camera.maxDrawDistance = 500
      m.camera.drawDistanceTransitionSeconds = 1.0
      m.camera.advanceDrawDistance(0)
      m.camera.maxDrawDistance = 300
      m.camera.advanceDrawDistance(0.1)
      m.assertTrue(m.camera.getCurrentDrawDistance() <= m.camera.getPlaneDrawDistance())
    end function
```

`RendererQuality.spec.bs` (append):

```brighterscript
    @it("pushes its own draw-distance scale as the plane's reach when nothing else set one")
    function _()
      cam = new BGE.Camera3d()
      m.renderer.camera = cam
      m.renderer.setQualitySettings(BGE.getRenderQualityPreset(BGE.RenderQualityLevel.low))
      m.renderer.setupCameraForFrame()
      m.assertEqual(m.renderer.qualitySettings.drawDistanceScale, cam.planeDrawDistanceScale)
    end function

    @it("pushes a plane reach range set on it")
    function _()
      cam = new BGE.Camera3d()
      m.renderer.camera = cam
      m.renderer.setPlaneDrawDistanceRange(1.5, 40)
      m.renderer.setupCameraForFrame()
      m.assertEqual(1.5, cam.planeDrawDistanceScale)
      m.assertEqual(40.0, cam.planeDrawDistanceOverride)
    end function
```

`RenderQualityManager.spec.bs` (append):

```brighterscript
    @it("gives the ground the same reach at every level: the highest level's")
    function _()
      cam = new BGE.Camera3d()
      cam.maxDrawDistance = 500
      m.renderer.camera = cam
      manager = new BGE.RenderQualityManager(m.renderer, BGE.RenderQualityLevel.basic)
      m.renderer.setupCameraForFrame()
      basicReach = cam.getPlaneDrawDistance()
      manager.setLevel(BGE.RenderQualityLevel.ultra)
      m.renderer.setupCameraForFrame()
      m.assertEqual(basicReach, cam.getPlaneDrawDistance())
      m.assertTrue(basicReach >= cam.getEffectiveMaxDrawDistance())
    end function

    @it("grows the ground's reach when a level's scale is overridden higher")
    function _()
      cam = new BGE.Camera3d()
      cam.maxDrawDistance = 400
      m.renderer.camera = cam
      manager = new BGE.RenderQualityManager(m.renderer, BGE.RenderQualityLevel.medium)
      manager.overridePreset(BGE.RenderQualityLevel.high, {drawDistanceScale: 2.0})
      m.renderer.setupCameraForFrame()
      m.assertTrue(abs(cam.getPlaneDrawDistance() - 800) < 0.01, `reach ${cam.getPlaneDrawDistance()}`)
    end function
```

`SceneObjectPlane.spec.bs`, in the Task 2 describe block:

```brighterscript
    @it("reaches far enough at Ultra that an object near the Ultra limit stands on the ground")
    function _()
      camera = m.game.canvas.renderer.camera as BGE.Camera3d
      camera.maxDrawDistance = 500
      m.game.setQualityLevel(BGE.RenderQualityLevel.ultra)
      plane = m.renderGround(BGE.Math.VectorOps.create(0, 50, -100))
      objectBase = BGE.Math.VectorOps.create(0, 0, -700)
      m.assertTrue(camera.isInView(objectBase))
      edgeY = camera.worldPointToCanvasPoint(plane.perspectivePoints.actual.topLeft).y
      baseY = camera.worldPointToCanvasPoint(objectBase).y
      m.assertTrue(edgeY <= baseY, `ground edge at y=${edgeY} is below the object's base at y=${baseY}`)
    end function
```

(`m.assertNear` exists in `Camera3d.spec.bs` from #125; check the RenderQualityManager suite's `m.renderer` name in its `beforeEach`.)

- [ ] **Step 2:** `npm run validate` → FAIL (unknown `planeDrawDistanceScale`, `setPlaneDrawDistanceRange`).
- [ ] **Step 3: implement.**

`Camera.bs`, after `drawDistanceOverride`:

```brighterscript
    ' How far a 3D camera's ground plane reaches, as a multiple of maxDrawDistance - the
    ' largest draw-distance scale any quality level uses, so the ground always reaches
    ' past every object. Set by the renderer every frame. Ignored by Camera2d.
    planeDrawDistanceScale as float = 1.0

    ' The largest absolute draw distance any quality level uses (0 = none). Set by the
    ' renderer every frame. Ignored by Camera2d.
    planeDrawDistanceOverride as float = 0.0
```

`Camera3d.getPlaneDrawDistance()` (rewrite, update its doc comment to: "How far a `DrawablePlane` (ground/terrain) draws: the farthest any quality level would draw objects, so objects always fade out on the ground - never past its edge. Doesn't change with the level, so the horizon stays put."):

```brighterscript
    function getPlaneDrawDistance() as float
      distance = m.maxDrawDistance * m.planeDrawDistanceScale
      if m.planeDrawDistanceOverride > distance
        distance = m.planeDrawDistanceOverride * 1.0
      end if
      ' never shorter than objects reach, whatever set the camera's own scale
      effective = m.getEffectiveMaxDrawDistance()
      if effective > distance
        distance = effective
      end if
      deviceCap = m.getMaxDrawDistanceDeviceCap()
      if distance > deviceCap
        distance = deviceCap * 1.0
      end if
      return distance
    end function
```

`Camera3d.advanceDrawDistance()`: right after the `if m.currentDrawDistance < 0 ... end if` easing block (before `fractionChanged = ...`):

```brighterscript
      ' objects never reach past the ground, e.g. right after maxDrawDistance shrinks
      planeDistance = m.getPlaneDrawDistance()
      if m.currentDrawDistance > planeDistance
        m.currentDrawDistance = planeDistance
      end if
```

`Renderer.bs` fields (near `qualitySettings`):

```brighterscript
    ' Ground plane reach pushed to the camera each frame; invalid = use qualitySettings.
    private planeDrawDistanceScale as dynamic = invalid
    private planeDrawDistanceOverride as float = 0.0
```

method (near `setQualitySettings`):

```brighterscript
    ' Sets how far a ground plane reaches: the largest draw-distance scale and override
    ' any quality level uses. `RenderQualityManager` calls this; without it the ground
    ' reaches this renderer's own level's distance.
    '
    ' @param {float} scale
    ' @param {float} override 0 for none
    sub setPlaneDrawDistanceRange(scale as float, override as float)
      m.planeDrawDistanceScale = scale
      m.planeDrawDistanceOverride = override
    end sub
```

`setupCameraForFrame()`, after the two existing quality pushes:

```brighterscript
      if invalid = m.planeDrawDistanceScale
        m.camera.planeDrawDistanceScale = m.qualitySettings.drawDistanceScale
        m.camera.planeDrawDistanceOverride = m.qualitySettings.drawDistanceOverride
      else
        m.camera.planeDrawDistanceScale = m.planeDrawDistanceScale
        m.camera.planeDrawDistanceOverride = m.planeDrawDistanceOverride
      end if
```

`RenderQualityManager.bs`: call `m.pushPlaneDrawDistanceRange()` at the end of `new()` and of `overridePreset()`, and add:

```brighterscript
    ' The ground reaches the farthest any level draws objects, so changing level never
    ' moves the horizon and objects always fade out on the ground.
    private sub pushPlaneDrawDistanceRange()
      maxScale = 0.0
      maxOverride = 0.0
      for level = RenderQualityLevel.basic to RenderQualityLevel.ultra
        settings = m.getSettings(level as BGE.RenderQualityLevel)
        if settings.drawDistanceScale > maxScale
          maxScale = settings.drawDistanceScale
        end if
        if settings.drawDistanceOverride > maxOverride
          maxOverride = settings.drawDistanceOverride
        end if
      end for
      m.renderer.setPlaneDrawDistanceRange(maxScale, maxOverride)
    end sub
```

- [ ] **Step 4:** `npm run check` → PASS. If an existing plane spec breaks because the plane now reaches 1.5x under a `Game` (bigger bitmaps/different corners), read the failure: a spec asserting a specific `maxDrawDistance`-derived bitmap size or corner is now expected to see the max-level reach - update its expectation to `camera.getPlaneDrawDistance()` rather than `maxDrawDistance`, with a one-line comment.
- [ ] **Step 5:** commit `Ground reaches the highest quality level's draw distance (#307)`.

---

### Task 4: Docs

- [ ] CLAUDE.md:
  - `Camera3d.maxDrawDistance` bullet: replace "`SceneObjectPlane` derives both its own far-render-distance and ... its tiled-supertexture size from this same effective value" with: the plane uses `getPlaneDrawDistance()` = the largest distance any quality level uses (`planeDrawDistanceScale`/`Override`, pushed by `Renderer` from `RenderQualityManager`, never below the effective distance), and `advanceDrawDistance()` clamps the eased object distance to it (#307).
  - Render quality bullet: replace "`SceneObjectPlane` ignores the level's draw-distance scale/override entirely and always uses `Camera3d.getPlaneDrawDistance()` (the authored `maxDrawDistance`, device-capped)" with the new reach, and note the 2M-pixel pre-perspective budget (`PLANE_PRE_PERSPECTIVE_MAX_PIXELS`) is what keeps a 1.5x reach from growing memory.
  - `SceneObjectPlane` bullet: the far edge is built on the object far-clip depth plane (`getFarEdgeCorner()`), not a circle.
- [ ] `docs/drawables-and-scene-objects.md`: in the plane section, how far the ground reaches; in "Draw-distance fade", that objects always fade out on the ground.
- [ ] `npm run docs` succeeds; commit `Document the ground plane's reach (#307)`.

---

### Task 5: Device verification and PR

- [ ] `npm run check:all` → PASS.
- [ ] Build engine + `examples/terrain`, sideload with `--deleteDevChannel`. For pinned levels, temporarily add a `quality=` launch param to `examples/terrain/src/source/main.bs` (do not commit; revert before the PR), as in #125.
- [ ] Medium and Ultra pinned: hold Down ~7s from the start, pause in the debugger, screenshot. Expect nothing standing above the ground edge. Compare against the `main` screenshots in #307.
- [ ] Parked FPS at Ultra (first paused sample after a fresh launch) vs. `main`'s ~47-48.
- [ ] Adaptive on: watch a level change; the horizon must not move.
- [ ] Revert the temp terrain change; push with an explicit refspec; open the PR (`pr-voice`), `Fixes #307`, with the FPS numbers.
