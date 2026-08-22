# Composable Terrain Planes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give `Camera3d` a real, shared draw-distance far-clip (`maxDrawDistance`), and let `DrawablePlane` compose three fill modes (`color`, `tiledImage`, `staticImage`) so a game can layer a flat-color base, a repeating ground texture, and a one-off decal on top of each other.

**Architecture:** `Camera3d.maxDrawDistance` becomes the single source of truth `SceneObjectPlane` derives its far distance from (issue #124), replacing its private `SCENE_OBJECT_PLANE_FAR_DISTANCE` constant. `DrawablePlane` gains a `PlaneFillMode` enum; `SceneObjectPlane` branches its draw path per mode: `color` skips the texture pipeline entirely and fills a projected polygon, `tiledImage` builds a cached, lazily-constructed "supertexture" (the base tile repeated enough times to cover the `maxDrawDistance` footprint) and wraps its anchor point into that cache each frame, `staticImage` is today's unchanged finite-decal behavior. Planes stack via ordinary multiple `addDrawable` calls - no new z-ordering mechanism.

**Tech Stack:** BrighterScript, Rooibos (rooibos-roku) for unit tests, `rokubot` for on-device/simulator verification.

**Spec:** [specs/2026-08-20-composable-terrain-planes-design.md](2026-08-20-composable-terrain-planes-design.md)

## Global Constraints

- `Camera3d.maxDrawDistance` defaults to `1000` (world units), applied everywhere - including `SceneObjectPlane`, deliberately accepting the resulting behavior change in `examples/terrain`/`examples/3d` (verified on-device, not just via `npm run check`).
- `#125` (fade near the limit) and `#126` (adaptive FPS-based tuning) are NOT part of this work - `maxDrawDistance` must stay a plain, live, game-settable field so either can build on it later.
- `#65` (skybox), `#66` (fog), and `#119` (oriented-billboard striping) are out of scope.
- Every existing `DrawablePlane` call site (today: `examples/terrain`) keeps working unchanged unless explicitly updated in Task 8.
- Run `npm run validate` after every task that touches `src/source/`; run `npm run check` before the final commit.

---

### Task 1: `BGE.Math.wrapValue` helper

**Files:**
- Modify: `src/source/math/math.bs` (add function, alongside the existing `Clamp`/`Min`/`Max`)
- Test: `src/source/math/math.spec.bs`

**Interfaces:**
- Produces: `BGE.Math.wrapValue(value as float, range as float) as float` - wraps `value` into `[0, range)`, correct for negative `value` too (unlike a raw `MOD`, which can return negative results in BrightScript for a negative left operand).

- [ ] **Step 1: Write the failing tests**

Add to `src/source/math/math.spec.bs` (find the existing `@suite`/`@describe` structure and add a new `@describe` block in the same style):

```brightscript
@describe("wrapValue")

@it("returns the value unchanged when already inside the range")
function _()
  m.assertEqual(30.0, BGE.Math.wrapValue(30, 100))
end function

@it("wraps a value at or past the top of the range back to the bottom")
function _()
  m.assertEqual(10.0, BGE.Math.wrapValue(110, 100))
  m.assertEqual(0.0, BGE.Math.wrapValue(100, 100))
end function

@it("wraps a negative value into the top of the range")
function _()
  m.assertEqual(90.0, BGE.Math.wrapValue(-10, 100))
end function

@it("handles a value many ranges away in either direction")
function _()
  m.assertEqual(5.0, BGE.Math.wrapValue(305, 100))
  m.assertEqual(5.0, BGE.Math.wrapValue(-295, 100))
end function
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `npm run build-tests && npm run test:ci`
Expected: FAIL - `wrapValue` is not a function member of "math".

- [ ] **Step 3: Implement `wrapValue`**

Add to `src/source/math/math.bs`, near `Clamp`:

```brightscript
' Wraps `value` into the half-open range [0, range) - correct for a negative `value`
' too, unlike a raw MOD, which can return a negative result in BrightScript for a
' negative left-hand operand. Used to map an unbounded world-space anchor point back
' into a single repeating tile's own pixel bounds (see SceneObjectPlane's tiledImage
' fill mode).
'
' @param {float} value
' @param {float} range
' @return {float}
function wrapValue(value as float, range as float) as float
  wrapped = value - Int(value / range) * range
  if wrapped < 0
    wrapped = wrapped + range
  end if
  return wrapped
end function
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `npm run build-tests && npm run test:ci`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add src/source/math/math.bs src/source/math/math.spec.bs
git commit -m "Add BGE.Math.wrapValue helper

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 2: `Camera3d.maxDrawDistance` and a far-distance `isInView` check

**Files:**
- Modify: `src/source/engine/renderer/cameras/Camera3d.bs`
- Test: `src/source/engine/renderer/cameras/Camera3d.spec.bs`

**Interfaces:**
- Consumes: `BGE.Math.VectorOps.subtract(a, v)`, `BGE.Math.VectorOps.dotProduct(a, v)` (existing).
- Produces: `Camera3d.maxDrawDistance as float = 1000` (public, live field). `Camera3d.isInView(point)` now also rejects a point farther than `maxDrawDistance` in front of the camera. `Camera3d.projectionChangedThisFrame()` (protected, already exists) now also picks up a `maxDrawDistance` change, so `projectionVersion` bumps and `onProjectionChange()`/`recomputeFrustum` run the same way a `fieldOfViewDegrees` change already does. Later tasks read `camera.maxDrawDistance` directly.

- [ ] **Step 1: Write the failing tests**

Add to `src/source/engine/renderer/cameras/Camera3d.spec.bs`, in a new `@describe` block (place it near the existing `isInView` tests):

```brightscript
@describe("isInView with maxDrawDistance")

@it("is true for a point closer than maxDrawDistance")
function _()
  m.camera.position = BGE.Math.VectorOps.create(0, 0, 0)
  m.camera.setTarget(BGE.Math.VectorOps.create(0, 0, -100))
  m.camera.maxDrawDistance = 500
  m.camera.checkMovement()

  m.assertTrue(m.camera.isInView(BGE.Math.VectorOps.create(0, 0, -50)))
end function

@it("is false for a point farther than maxDrawDistance, even directly ahead")
function _()
  m.camera.position = BGE.Math.VectorOps.create(0, 0, 0)
  m.camera.setTarget(BGE.Math.VectorOps.create(0, 0, -100))
  m.camera.maxDrawDistance = 500
  m.camera.checkMovement()

  m.assertFalse(m.camera.isInView(BGE.Math.VectorOps.create(0, 0, -600)))
end function

@describe("maxDrawDistance and the projection version")

@it("bumps projectionVersion when maxDrawDistance changes")
function _()
  m.camera.setFrameSize(200, 200)
  m.camera.checkMovement()
  before = m.camera.projectionVersion

  m.camera.maxDrawDistance = 250
  m.camera.checkMovement()

  m.assertTrue(m.camera.projectionVersion > before)
end function

@it("holds projectionVersion steady when maxDrawDistance is unchanged")
function _()
  m.camera.setFrameSize(200, 200)
  m.camera.maxDrawDistance = 250
  m.camera.checkMovement()
  before = m.camera.projectionVersion

  m.camera.checkMovement()

  m.assertEqual(before, m.camera.projectionVersion)
end function
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `npm run build-tests && npm run test:ci`
Expected: FAIL - both `isInView` tests fail because there's no far-distance rejection yet (the far point is still angularly inside the frustum), and both `projectionVersion` tests fail because `maxDrawDistance` doesn't exist yet (build error).

- [ ] **Step 3: Add `maxDrawDistance` and wire it into `isInView`/`projectionChangedThisFrame`**

In `src/source/engine/renderer/cameras/Camera3d.bs`, add the field near `fieldOfViewDegrees`/`rollDegrees`:

```brightscript
    ' How far (world units) in front of the camera a point can be and still be
    ' considered visible - see issue #124. Applied everywhere isInView() is checked,
    ' including SceneObjectPlane, which derives its own far-render-distance and
    ' tiled-texture cache size from this same value instead of a private constant.
    maxDrawDistance as float = 1000

    ' Last maxDrawDistance seen by projectionChangedThisFrame() - a plain public field
    ' a consumer writes directly, so (like fieldOfViewDegrees) it needs its own dirty
    ' check rather than a setter.
    private lastMaxDrawDistance as float = 1000
```

Update `isInView()`:

```brightscript
    override function isInView(point as BGE.Math.Vector) as boolean
      frustumSides = ["near", "top", "left", "right", "bottom"]
      for each side in frustumSides
        distance = m.distanceFromFrustumSide(side, point)
        if distance < 0
          return false
        end if
      end for
      forwardDistance = BGE.Math.VectorOps.dotProduct(BGE.Math.VectorOps.subtract(point, m.position), m.orientation)
      return forwardDistance <= m.maxDrawDistance
    end function
```

Update `projectionChangedThisFrame()`:

```brightscript
    protected override function projectionChangedThisFrame() as boolean
      ' called unconditionally rather than inside an `or`, so it always records the new
      ' frame size even when the FOV changed too
      changed = super.projectionChangedThisFrame()

      if m.lastProjectionFieldOfView <> m.fieldOfViewDegrees
        m.lastProjectionFieldOfView = m.fieldOfViewDegrees
        changed = true
      end if

      if m.lastMaxDrawDistance <> m.maxDrawDistance
        m.lastMaxDrawDistance = m.maxDrawDistance
        changed = true
      end if

      return changed
    end function
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `npm run build-tests && npm run test:ci`
Expected: PASS

- [ ] **Step 5: Run full validation**

Run: `npm run validate`
Expected: no type errors.

- [ ] **Step 6: Commit**

```bash
git add src/source/engine/renderer/cameras/Camera3d.bs src/source/engine/renderer/cameras/Camera3d.spec.bs
git commit -m "Add Camera3d.maxDrawDistance far-clip (#124)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 3: `SceneObjectPlane` derives its far distance from `camera.maxDrawDistance`

**Files:**
- Modify: `src/source/engine/renderer/sceneObjects/SceneObjectPlane.bs`
- Test: `src/source/engine/renderer/sceneObjects/SceneObjectPlane.spec.bs`

**Interfaces:**
- Consumes: `Camera3d.maxDrawDistance` (Task 2).
- Produces: `SCENE_OBJECT_PLANE_FAR_DISTANCE` constant removed. Every call site that used it now reads `(rendererObj.camera as Camera3d).maxDrawDistance` at the point the camera is already known to be a `Camera3d` (both existing call sites already only run after that cast).

- [ ] **Step 1: Write the failing test**

Add to `src/source/engine/renderer/sceneObjects/SceneObjectPlane.spec.bs`:

```brightscript
@describe("far distance follows camera.maxDrawDistance")

@it("still finds a canvas position when maxDrawDistance is generous")
function _()
  m.game.canvas.renderer.camera.maxDrawDistance = 2000
  m.plane.update(m.game.canvas.renderer.camera)
  m.plane.draw(m.game.canvas.renderer)

  m.assertFalse(m.plane.isCulled())
end function

@it("fails to find the plane when maxDrawDistance is shrunk below the camera's height above it")
function _()
  camera = m.game.canvas.renderer.camera as BGE.Camera3d
  camera.position = BGE.Math.VectorOps.create(0, 5000, 0)
  camera.setTarget(BGE.Math.VectorOps.create(0, 0, 0))
  camera.maxDrawDistance = 10
  m.plane.update(m.game.canvas.renderer.camera)
  m.plane.draw(m.game.canvas.renderer)

  m.assertTrue(m.plane.isCulled())
end function
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `npm run build-tests && npm run test:ci`
Expected: The second test FAILS (the plane is still found, because `maxDrawDistance` isn't consulted yet - the ray-cast fallback still uses the hardcoded `512`, which is bigger than `10` but the point is the fallback distance isn't driven by the camera at all yet). Confirm by reading the actual failure before proceeding, per systematic-debugging practice - don't assume the failure mode, read it.

- [ ] **Step 3: Replace the constant**

In `src/source/engine/renderer/sceneObjects/SceneObjectPlane.bs`:

Remove this line near the top of the file:

```brightscript
  const SCENE_OBJECT_PLANE_FAR_DISTANCE = 512
```

Keep `SCENE_OBJECT_PLANE_NEAR_DISTANCE = 0` and `SCENE_OBJECT_PLANE_SLICE_COUNT = 50` as-is - both are still private engine-tuning constants unrelated to the camera's own draw distance.

Update `findCanvasPosition`:

```brightscript
    protected override function findCanvasPosition(rendererObj as Renderer, drawMode as SceneObjectDrawMode) as boolean
      camera = rendererObj.camera as Camera3d
      m.perspectivePoints = m.getPerspectivePointsByCamera(rendererObj, m.drawable.plane, m.worldPosition, camera.maxDrawDistance)
      if invalid = m.perspectivePoints
        return false
      end if
      ' The texture is a finite decal, not an infinitely tiling one - skip
      ' the (relatively expensive) perspective warp entirely once the view
      ' has moved so far that there's no possible overlap with the texture
      ' at all. Partial overlaps are handled correctly by performDraw
      ' clearing its scratch/dest bitmaps before drawing into them, so a
      ' partially-out-of-bounds view correctly shows real texture where
      ' valid and background where not, rather than needing an all-or-
      ' nothing gate here.
      return BGE.Math.boundsOverlapRect(m.perspectivePoints.mapped.toArray(), m.drawable.region.GetWidth(), m.drawable.region.GetHeight())
    end function
```

(This cast-then-use is safe: `getPerspectivePointsByCamera` already returns `invalid` immediately if `rendererObj.camera.name <> "Camera3d"`, and `findCanvasPosition` already only runs when a camera exists, so this mirrors the existing safety, just moving the cast one line earlier so `maxDrawDistance` is reachable before the call. If `rendererObj.camera` is somehow not a `Camera3d` here, the `as Camera3d` cast doesn't throw in BrighterScript at this call boundary - it's a compile-time type assertion, not a runtime check - so behavior for a non-`Camera3d` renderer is unchanged from today: `getPerspectivePointsByCamera` still returns `invalid` immediately via its own `rendererCamera.name <> "Camera3d"` check.)

Update `getPrePerspectiveBmp`:

```brightscript
    private function getPrePerspectiveBmp(rendererObj as BGE.Renderer) as roBitmap
      nearDistance = SCENE_OBJECT_PLANE_NEAR_DISTANCE
      camera = rendererObj.camera as Camera3d
      farDistance = camera.maxDrawDistance
      finalHeight = farDistance - nearDistance
      finalWidth = (finalHeight) * tan(BGE.Math.DegreesToRadians(camera.fieldOfViewDegrees) / 2) * 2
      return CreateObject("roBitmap", {width: finalWidth, height: finalHeight, AlphaEnable: true})
    end function
```

`performDraw` already reads `SCENE_OBJECT_PLANE_NEAR_DISTANCE` and `SCENE_OBJECT_PLANE_SLICE_COUNT` when calling `drawPerspectiveBmpSlicesToByCamera` - leave that line as-is, those two constants aren't changing.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `npm run build-tests && npm run test:ci`
Expected: PASS

- [ ] **Step 5: Run full validation**

Run: `npm run validate`
Expected: no type errors.

- [ ] **Step 6: Commit**

```bash
git add src/source/engine/renderer/sceneObjects/SceneObjectPlane.bs src/source/engine/renderer/sceneObjects/SceneObjectPlane.spec.bs
git commit -m "SceneObjectPlane: derive far distance from camera.maxDrawDistance (#124)

Removes the private SCENE_OBJECT_PLANE_FAR_DISTANCE=512 constant in favor of
the shared Camera3d.maxDrawDistance (default 1000) added in the previous
commit - unifying the plane's render distance with the rest of the engine's
visibility, per issue #124.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 4: `DrawablePlane` gains `PlaneFillMode` and `color` mode

**Files:**
- Modify: `src/source/engine/drawables/DrawablePlane.bs`
- Create: `src/source/engine/drawables/DrawablePlane.spec.bs`

**Interfaces:**
- Produces:
  - `enum PlaneFillMode` with members `color`, `tiledImage`, `staticImage` (string-valued, matching the existing `enum ... as string` convention used by `CameraFrustumSide`/`SceneObjectDrawMode`).
  - `DrawablePlane.fillMode as PlaneFillMode = PlaneFillMode.staticImage` (public field).
  - `DrawablePlane.new(owner as BGE.GameEntity, region as roRegion, plane as BGE.Math.Plane, args = {} as object)` - **unchanged signature and positional order**, but `region` may now be `invalid` (for `color` mode). `fillMode` is set via `args` (e.g. `{fillMode: BGE.PlaneFillMode.color}`), applied via the existing `m.append(args)` call, same as every other `Drawable` option today.
  - Reuses the existing `Drawable.color`/`Drawable.alpha` fields as the fill color for `color` mode - no new color field.
- Consumed by: Task 5 (`SceneObjectPlane` color-mode rendering reads `m.drawable.fillMode` and `m.drawable.getFillColorRGBA()`, the latter already defined on `Drawable`).

- [ ] **Step 1: Write the failing tests**

Create `src/source/engine/drawables/DrawablePlane.spec.bs`:

```brightscript
namespace tests

  @suite("BGE.DrawablePlane")
  class DrawablePlaneTests extends rooibos.BaseTestSuite

    game as BGE.Game
    room as BGE.Room
    plane as BGE.Math.Plane

    protected override function beforeEach()
      m.game = new BGE.Game(200, 200)
      m.room = new BGE.Room(m.game, {name: "TestRoom"})
      m.game.defineRoom(m.room)
      m.game.changeRoom("TestRoom")
      m.plane = {normal: {x: 0, y: 1, z: 0}, point: {x: 0, y: 0, z: 0}}
    end function

    @describe("fillMode default")

    @it("defaults to staticImage when a region is provided and no fillMode is given")
    function _()
      bmp = CreateObject("roBitmap", {width: 8, height: 8, AlphaEnable: true})
      region = CreateObject("roRegion", bmp, 0, 0, 8, 8)

      drawable = new BGE.DrawablePlane(m.room, region, m.plane)

      m.assertEqual(BGE.PlaneFillMode.staticImage, drawable.fillMode)
    end function

    @describe("color fill mode")

    @it("accepts an invalid region and a color fillMode")
    function _()
      drawable = new BGE.DrawablePlane(m.room, invalid, m.plane, {fillMode: BGE.PlaneFillMode.color, color: BGE.ColorsRGB.Green})

      m.assertEqual(BGE.PlaneFillMode.color, drawable.fillMode)
      m.assertEqual(BGE.ColorsRGB.Green, drawable.color)
    end function

    @describe("tiledImage fill mode")

    @it("accepts a region with a tiledImage fillMode")
    function _()
      bmp = CreateObject("roBitmap", {width: 8, height: 8, AlphaEnable: true})
      region = CreateObject("roRegion", bmp, 0, 0, 8, 8)

      drawable = new BGE.DrawablePlane(m.room, region, m.plane, {fillMode: BGE.PlaneFillMode.tiledImage})

      m.assertEqual(BGE.PlaneFillMode.tiledImage, drawable.fillMode)
    end function

  end class

end namespace
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `npm run build-tests && npm run test:ci`
Expected: FAIL - `BGE.PlaneFillMode` doesn't exist yet (build error).

- [ ] **Step 3: Implement `PlaneFillMode` and `fillMode`**

Replace the contents of `src/source/engine/drawables/DrawablePlane.bs`:

```brightscript
namespace BGE

  ' Which of the three composable ways a DrawablePlane fills its surface:
  ' - color: a flat fill using the drawable's own `color`/`alpha` fields, no texture at
  '   all. Never "runs out" - the natural base/backdrop layer under the other two.
  ' - tiledImage: `region` is treated as a single repeating tile, seamlessly covering
  '   the world-space footprint bounded by the camera's `maxDrawDistance`.
  ' - staticImage: `region` is a one-off finite decal anchored at the plane's own world
  '   position (today's only historical behavior) - correct for e.g. a map texture,
  '   wrong for anything meant to repeat.
  '
  ' Multiple DrawablePlanes (in any mix of modes) can be layered on the same entity or
  ' room via separate addDrawable() calls - draw order for planes at the same depth
  ' follows insertion order (SceneObject's existing depth-sort tie-break), so add the
  ' base layer (e.g. a color plane) first.
  enum PlaneFillMode
    color = "color"
    tiledImage = "tiledImage"
    staticImage = "staticImage"
  end enum

  ' Used to draw a "infinite" plane in 3d space
  ' Ideally used for a ground or floor
  class DrawablePlane extends BGE.Image

    plane as BGE.Math.Plane
    fillMode as PlaneFillMode = PlaneFillMode.staticImage

    ' @param {BGE.GameEntity} owner
    ' @param {roRegion} region the texture tile to use for `tiledImage`/`staticImage`
    '   fillMode - pass `invalid` for `color` fillMode, which ignores it entirely.
    ' @param {BGE.Math.Plane} plane
    ' @param {object} [args={}] pass `fillMode` here to select a mode other than the
    '   default `staticImage` - e.g. `{fillMode: BGE.PlaneFillMode.color}`.
    sub new(owner as BGE.GameEntity, region as roRegion, plane as BGE.Math.Plane, args = {} as object)
      super(owner, region, args)
      m.plane = plane
      ' bs:disable-next-line: 1140
      m.append(args)
    end sub

    override sub addToScene(rendererObj as Renderer)
      m.addSceneObjectToRenderer(new SceneObjectPlane(m.getSceneObjectName("plane"), m), rendererObj)
    end sub

  end class

end namespace
```

(`super.new(owner, region, args)` - i.e. `BGE.Image.new` - already tolerates `region = invalid` today: it only derives `m.width`/`m.height` from the region `if m.region <> invalid`. No change needed there.)

- [ ] **Step 4: Run the tests to verify they pass**

Run: `npm run build-tests && npm run test:ci`
Expected: PASS

- [ ] **Step 5: Run full validation**

Run: `npm run validate`
Expected: no type errors.

- [ ] **Step 6: Commit**

```bash
git add src/source/engine/drawables/DrawablePlane.bs src/source/engine/drawables/DrawablePlane.spec.bs
git commit -m "DrawablePlane: add PlaneFillMode (color/tiledImage/staticImage)

color fillMode accepts an invalid region and reuses the existing
Drawable.color/alpha fields - SceneObjectPlane's rendering for it lands in
the next commit. staticImage is today's unchanged default behavior.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 5: `SceneObjectPlane` color fill mode rendering

**Files:**
- Modify: `src/source/engine/renderer/sceneObjects/SceneObjectPlane.bs`
- Test: `src/source/engine/renderer/sceneObjects/SceneObjectPlane.spec.bs`

**Interfaces:**
- Consumes: `PlaneFillMode` (Task 4), `Drawable.getFillColorRGBA(ignoreColor = false) as integer` (existing, on the `Drawable` base class), `Renderer.drawPolygon(points as BGE.Math.Vector[], x as float, y as float, rgba as integer, allowQuickDraw = false as boolean) as boolean` (existing), `Camera3d.worldPointToCanvasPoint(pWorld) as BGE.Math.Vector` (existing, returns `invalid` for a point behind the camera).
- Produces: `SceneObjectPlane.getPerspectivePointsByCamera()` skips the texture-pixel `mapped` computation for `color` fillMode (returns `{actual: output, mapped: invalid}`). `findCanvasPosition()` skips the finite-texture bounds check for both `color` and `tiledImage` (a color fill and a tiled texture never "run out"; only `staticImage` can). `performDraw()` branches to a new private `performColorDraw()` for `color` fillMode before doing any of the existing texture-warp work.

- [ ] **Step 1: Write the failing tests**

Add to `src/source/engine/renderer/sceneObjects/SceneObjectPlane.spec.bs`. This requires a second `beforeEach`-style setup for a color-mode plane - add a helper method and new tests:

```brightscript
@describe("color fillMode")

@it("draws successfully near the plane's own anchor position")
function _()
  colorDrawable = new BGE.DrawablePlane(m.room, invalid, {normal: {x: 0, y: 1, z: 0}, point: {x: 0, y: 0, z: 0}}, {fillMode: BGE.PlaneFillMode.color, color: BGE.ColorsRGB.Green})
  colorPlane = new BGE.SceneObjectPlane("colorPlane", colorDrawable)

  ' The default camera (position z=1000, same height as the plane) is a degenerate
  ' setup for actually exercising rendering - see the far-distance tests above,
  ' where this was root-caused. Use the same height-1, level-gaze camera already
  ' proven safe there instead.
  camera = m.game.canvas.renderer.camera as BGE.Camera3d
  camera.position = BGE.Math.VectorOps.create(0, 1, 0)
  camera.setTarget(BGE.Math.VectorOps.create(0, 1, -100))
  camera.checkMovement()

  colorPlane.update(camera)
  m.game.canvas.renderer.resetDrawCallCounter()
  colorPlane.draw(m.game.canvas.renderer)

  m.assertTrue(m.game.canvas.renderer.getDrawCallsLastFrame() > 0)
end function

@it("still draws far from the plane's own anchor position, unlike a staticImage decal")
function _()
  colorDrawable = new BGE.DrawablePlane(m.room, invalid, {normal: {x: 0, y: 1, z: 0}, point: {x: 0, y: 0, z: 0}}, {fillMode: BGE.PlaneFillMode.color})
  colorPlane = new BGE.SceneObjectPlane("colorPlane", colorDrawable)

  ' Same proven-safe height-1, level-gaze geometry as above, just translated far
  ' from the plane's own anchor position (0,0,0) - a staticImage plane would run
  ' out of texture here (see the far-distance tests above); a color plane never
  ' does, since findCanvasPosition() skips the bounds check entirely for this
  ' fillMode.
  camera = m.game.canvas.renderer.camera as BGE.Camera3d
  camera.position = BGE.Math.VectorOps.create(5000, 1, 5000)
  camera.setTarget(BGE.Math.VectorOps.create(5000, 1, 4900))
  camera.checkMovement()

  colorPlane.update(camera)
  m.game.canvas.renderer.resetDrawCallCounter()
  colorPlane.draw(m.game.canvas.renderer)

  m.assertTrue(m.game.canvas.renderer.getDrawCallsLastFrame() > 0)
end function
```

`m.room` isn't currently stored on `SceneObjectPlaneTests` - add it. **Note:** the current file (after an earlier task's fix) already has a `drawable as BGE.DrawablePlane` field and uses `m.drawable` instead of a local `drawablePlane` var - leave that as-is. Update the existing `beforeEach` in `SceneObjectPlane.spec.bs`, changing only the local `room` variable to `m.room` (declare the new field, assign it, and use it everywhere `room` was used):

```brightscript
    game as BGE.Game
    drawable as BGE.DrawablePlane
    room as BGE.Room
    plane as BGE.SceneObjectPlane

    protected override function beforeEach()
      m.game = new BGE.Game(200, 200)
      m.game.setCamera(new BGE.Camera3d())
      m.game.canvas.renderer.camera.setFrameSize(200, 100)

      m.room = new BGE.Room(m.game, {name: "TestRoom"})
      m.game.defineRoom(m.room)
      m.game.changeRoom("TestRoom")

      bmp = CreateObject("roBitmap", {width: 8, height: 8, AlphaEnable: true})
      region = CreateObject("roRegion", bmp, 0, 0, 8, 8)
      m.drawable = new BGE.DrawablePlane(m.room, region, {normal: {x: 0, y: 1, z: 0}, point: {x: 0, y: 0, z: 0}})
      m.plane = new BGE.SceneObjectPlane("plane", m.drawable)
    end function
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `npm run build-tests && npm run test:ci`
Expected: FAIL - `color` fillMode currently falls into the same texture-warp path as `staticImage`, which needs a real `region` (`m.drawable.region.GetWidth()` on an `invalid` region is a runtime crash, or at best returns false/doesn't draw).

- [ ] **Step 3: Implement color-mode rendering**

In `src/source/engine/renderer/sceneObjects/SceneObjectPlane.bs`:

Update `getPerspectivePointsByCamera` - the `mapped`-building block at the end becomes conditional. Replace:

```brightscript
      ' Anchor the texture's center on the plane's own world position (mapOffset)
      ' rather than on world-space (0,0) - otherwise world points get used
      ' directly as source-bitmap pixel coordinates, pinning the visible
      ' texture to a fixed absolute-world-space footprint regardless of
      ' where the plane (or camera) actually are.
      textureWidth = m.drawable.region.GetWidth()
      textureHeight = m.drawable.region.GetHeight()

      mapped = new BGE.Math.CornerPoints()

      mapped.topRight = BGE.Math.worldPointToTexturePixel(output.topRight, mapOffset, textureWidth, textureHeight)
      mapped.topLeft = BGE.Math.worldPointToTexturePixel(output.topLeft, mapOffset, textureWidth, textureHeight)
      mapped.bottomRight = BGE.Math.worldPointToTexturePixel(output.bottomRight, mapOffset, textureWidth, textureHeight)
      mapped.bottomLeft = BGE.Math.worldPointToTexturePixel(output.bottomLeft, mapOffset, textureWidth, textureHeight)

      return {actual: output, mapped: mapped}
    end function
```

with:

```brightscript
      ' A color fill has no texture at all - only the world-space quad (`output`)
      ' matters, so skip the texture-pixel mapping entirely.
      if m.drawable.fillMode = PlaneFillMode.color
        return {actual: output, mapped: invalid}
      end if

      ' Anchor the texture's center on the plane's own world position (mapOffset)
      ' rather than on world-space (0,0) - otherwise world points get used
      ' directly as source-bitmap pixel coordinates, pinning the visible
      ' texture to a fixed absolute-world-space footprint regardless of
      ' where the plane (or camera) actually are.
      textureWidth = m.drawable.region.GetWidth()
      textureHeight = m.drawable.region.GetHeight()

      mapped = new BGE.Math.CornerPoints()

      mapped.topRight = BGE.Math.worldPointToTexturePixel(output.topRight, mapOffset, textureWidth, textureHeight)
      mapped.topLeft = BGE.Math.worldPointToTexturePixel(output.topLeft, mapOffset, textureWidth, textureHeight)
      mapped.bottomRight = BGE.Math.worldPointToTexturePixel(output.bottomRight, mapOffset, textureWidth, textureHeight)
      mapped.bottomLeft = BGE.Math.worldPointToTexturePixel(output.bottomLeft, mapOffset, textureWidth, textureHeight)

      return {actual: output, mapped: mapped}
    end function
```

Update `findCanvasPosition`:

```brightscript
    protected override function findCanvasPosition(rendererObj as Renderer, drawMode as SceneObjectDrawMode) as boolean
      camera = rendererObj.camera as Camera3d
      m.perspectivePoints = m.getPerspectivePointsByCamera(rendererObj, m.drawable.plane, m.worldPosition, camera.maxDrawDistance)
      if invalid = m.perspectivePoints
        return false
      end if
      if m.drawable.fillMode <> PlaneFillMode.staticImage
        ' A color fill and a tiled texture never "run out" the way a finite decal
        ' does - visible whenever the plane itself is (perspectivePoints exists).
        return true
      end if
      ' The texture is a finite decal, not an infinitely tiling one - skip
      ' the (relatively expensive) perspective warp entirely once the view
      ' has moved so far that there's no possible overlap with the texture
      ' at all. Partial overlaps are handled correctly by performDraw
      ' clearing its scratch/dest bitmaps before drawing into them, so a
      ' partially-out-of-bounds view correctly shows real texture where
      ' valid and background where not, rather than needing an all-or-
      ' nothing gate here.
      return BGE.Math.boundsOverlapRect(m.perspectivePoints.mapped.toArray(), m.drawable.region.GetWidth(), m.drawable.region.GetHeight())
    end function
```

Update `performDraw` to branch to a new color path before any of the existing bitmap-cache logic:

```brightscript
    protected override function performDraw(rendererObj as BGE.Renderer, drawMode as SceneObjectDrawMode) as boolean
      if invalid = m.perspectivePoints
        return false
      end if

      if m.drawable.fillMode = PlaneFillMode.color
        return m.performColorDraw(rendererObj)
      end if

      camera = rendererObj.camera
      isRolled = false
      if camera.name = "Camera3d"
        isRolled = (camera as Camera3d).rollDegrees <> 0
      end if
      if not m.objMovedInRelationToCamera(camera) and m.hasAccurateTempBitmap
        ' If nothing has moved (including no roll change - Camera3d.checkMovement's
        ' own roll dirty-check forces movedLastFrame true only on the frame roll
        ' actually changes), redraw whichever cached bitmap is correct for the
        ' current mode instead of recomputing: the already-rotated/cropped one
        ' while rolled, or the plain composite otherwise. A camera parked at a
        ' fixed bank angle hits this path exactly as cheaply as a level one - only
        ' an actual roll/position/orientation change forces a recompute.
        if isRolled and m.rotatedTempBitmap <> invalid
          return rendererObj.drawObject(0, 0, m.rotatedTempBitmap)
        else if not isRolled and m.tempBitmap <> invalid
          return rendererObj.drawObject(0, 0, m.tempBitmap)
        end if
      end if
      m.hasAccurateTempBitmap = false

      if invalid = m.prePerspectiveBmp
        m.prePerspectiveBmp = m.getPrePerspectiveBmp(rendererObj)
      end if

      gotPreBmp = m.populatePerspectiveBmp(rendererObj, m.perspectivePoints.mapped, m.drawable.region, m.prePerspectiveBmp)
      if not gotPreBmp
        return false
      end if
      m.hasAccurateTempBitmap = m.drawPerspectiveBmpSlicesToByCamera(rendererObj, m.prePerspectiveBmp, m.perspectivePoints.actual, SCENE_OBJECT_PLANE_NEAR_DISTANCE, SCENE_OBJECT_PLANE_SLICE_COUNT)

      return m.hasAccurateTempBitmap
    end function

    ' Fills the plane's visible world-space quad with a flat color - no texture warp,
    ' no slice rasterization, no bitmap caching. Cheapest of the three fill modes, and
    ' - having no texture bounds - correctly draws regardless of how far the camera has
    ' moved from the plane's own anchor position (findCanvasPosition() already skips
    ' the finite-decal bounds check for this fillMode).
    '
    ' @param {BGE.Renderer} rendererObj
    ' @return {boolean} True if the draw call was successful
    private function performColorDraw(rendererObj as BGE.Renderer) as boolean
      camera = rendererObj.camera
      corners = [m.perspectivePoints.actual.topLeft, m.perspectivePoints.actual.topRight, m.perspectivePoints.actual.bottomRight, m.perspectivePoints.actual.bottomLeft]
      canvasPoints = []
      for each corner in corners
        canvasPoint = camera.worldPointToCanvasPoint(corner)
        if invalid <> canvasPoint
          canvasPoints.push(canvasPoint)
        end if
      end for

      if canvasPoints.count() < 3
        ' Every corner projected behind the camera - nothing to draw this frame.
        ' Not a deterministic failure (isDeterministicDrawFailure() isn't overridden
        ' here, so the base class's "keep retrying" default applies) - the camera
        ' moving again next frame can easily bring a corner back in front of it.
        return false
      end if

      return rendererObj.drawPolygon(canvasPoints, 0, 0, m.drawable.getFillColorRGBA())
    end function
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `npm run build-tests && npm run test:ci`
Expected: PASS

- [ ] **Step 5: Run full validation**

Run: `npm run validate`
Expected: no type errors.

- [ ] **Step 6: Commit**

```bash
git add src/source/engine/renderer/sceneObjects/SceneObjectPlane.bs src/source/engine/renderer/sceneObjects/SceneObjectPlane.spec.bs
git commit -m "SceneObjectPlane: render color fillMode as a flat polygon fill

Skips the whole texture-warp/slice pipeline for a color-filled plane -
projects the already-computed world-space quad to canvas points and does
one Renderer.drawPolygon fill instead. Also skips the finite-decal bounds
check for both color and tiledImage fillModes, since neither can 'run out'
the way a staticImage decal can.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 6: `SceneObjectPlane` tiledImage cached supertexture

**Files:**
- Modify: `src/source/engine/renderer/sceneObjects/SceneObjectPlane.bs`
- Test: `src/source/engine/renderer/sceneObjects/SceneObjectPlane.spec.bs`

**Interfaces:**
- Consumes: `BGE.Math.wrapValue` (Task 1), `PlaneFillMode.tiledImage` (Task 4), `Renderer.drawObjectTo(draw2d, x, y, src, rgba = -1) as boolean` (existing), `Renderer.drawRotatedImageWithCenterTo(draw2d, srcRegion, srcRotationPoint, theta, translation, drawScale) as boolean` (existing).
- Produces: `SceneObjectPlane` builds and caches a "supertexture" (the tile repeated enough times per axis to cover `camera.maxDrawDistance`) lazily on first tiled draw, keyed to the `maxDrawDistance` value it was built for (rebuilt if that value changes). `populatePerspectiveBmp` gains an explicit `anchorPoint`/`scratchOverride` parameter pair so both `staticImage` (pool-backed scratch, `cp.topLeft` anchor, unchanged behavior) and `tiledImage` (dedicated persistent scratch bitmap sized to the supertexture, wrapped anchor) share the same warp/scale code.

**Why a dedicated scratch bitmap, not the pool:** `ScratchBitmapPool.getRegion()` clamps to the device's own scratch size (256/720/1080 px depending on `roDeviceInfo.GetUIResolution()`, per `ScratchBitmap.bs`) and returns `invalid` above that - and `populatePerspectiveBmp`'s existing rotate step sizes its scratch region to exactly match its source region's dimensions. A supertexture built to cover `maxDrawDistance = 1000` world units will often exceed even the 1080 FHD cap. `SceneObjectPlane` already keeps three persistent, non-pooled bitmaps for its own exclusive use (`prePerspectiveBmp`, `tempBitmap`, `rotatedTempBitmap`) - the tiled scratch bitmap is a fourth, sized once and reused for the object's lifetime, sidestepping the pool's per-device cap entirely.

- [ ] **Step 1: Write the failing tests**

Add to `src/source/engine/renderer/sceneObjects/SceneObjectPlane.spec.bs`:

```brightscript
@describe("tiledImage fillMode")

@it("draws successfully from a small tile, near the plane's own anchor position")
function _()
  bmp = CreateObject("roBitmap", {width: 8, height: 8, AlphaEnable: true})
  region = CreateObject("roRegion", bmp, 0, 0, 8, 8)
  tiledDrawable = new BGE.DrawablePlane(m.room, region, {normal: {x: 0, y: 1, z: 0}, point: {x: 0, y: 0, z: 0}}, {fillMode: BGE.PlaneFillMode.tiledImage})
  tiledPlane = new BGE.SceneObjectPlane("tiledPlane", tiledDrawable)

  ' The default camera (position z=1000, same height as the plane) is a degenerate
  ' setup for actually exercising rendering - see the far-distance tests above,
  ' where this was root-caused. Use the same height-1, level-gaze camera already
  ' proven safe there instead.
  camera = m.game.canvas.renderer.camera as BGE.Camera3d
  camera.position = BGE.Math.VectorOps.create(0, 1, 0)
  camera.setTarget(BGE.Math.VectorOps.create(0, 1, -100))
  camera.maxDrawDistance = 200
  camera.checkMovement()

  tiledPlane.update(camera)
  m.game.canvas.renderer.resetDrawCallCounter()
  tiledPlane.draw(m.game.canvas.renderer)

  m.assertTrue(m.game.canvas.renderer.getDrawCallsLastFrame() > 0)
end function

@it("still draws far from the plane's own anchor position, unlike a staticImage decal")
function _()
  bmp = CreateObject("roBitmap", {width: 8, height: 8, AlphaEnable: true})
  region = CreateObject("roRegion", bmp, 0, 0, 8, 8)
  tiledDrawable = new BGE.DrawablePlane(m.room, region, {normal: {x: 0, y: 1, z: 0}, point: {x: 0, y: 0, z: 0}}, {fillMode: BGE.PlaneFillMode.tiledImage})
  tiledPlane = new BGE.SceneObjectPlane("tiledPlane", tiledDrawable)

  ' Same proven-safe height-1, level-gaze geometry as above, just translated far
  ' from the plane's own anchor position (0,0,0) - a staticImage plane would run
  ' out of texture here (see the far-distance tests above); a tiled plane never
  ' does, since the tile repeats to cover the whole maxDrawDistance footprint.
  camera = m.game.canvas.renderer.camera as BGE.Camera3d
  camera.position = BGE.Math.VectorOps.create(5000, 1, 5000)
  camera.setTarget(BGE.Math.VectorOps.create(5000, 1, 4900))
  camera.maxDrawDistance = 200
  camera.checkMovement()

  tiledPlane.update(camera)
  m.game.canvas.renderer.resetDrawCallCounter()
  tiledPlane.draw(m.game.canvas.renderer)

  m.assertTrue(m.game.canvas.renderer.getDrawCallsLastFrame() > 0)
end function
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `npm run build-tests && npm run test:ci`
Expected: FAIL - `tiledImage` currently falls into the unchanged `staticImage` texture-warp path, so it's still bounds-checked as a finite decal and gets culled once the camera is this far from the plane's anchor.

- [ ] **Step 3: Implement the supertexture cache and wrapped-anchor warp**

In `src/source/engine/renderer/sceneObjects/SceneObjectPlane.bs`, add new private fields near the existing bitmap fields:

```brightscript
    private superTextureBmp as roBitmap
    private superTextureRegion as roRegion
    ' A second, identically-sized bitmap used only as the rotate step's scratch
    ' destination - kept distinct from superTextureBmp so that step's canvas is
    ' never the same bitmap superTextureRegion (its source) reads from.
    private tiledScratchBmp as roBitmap
    private superTextureBuiltForMaxDrawDistance as float = -1
    private tileWidth as float
    private tileHeight as float
    private tilesPerAxis as integer
```

Add two new private methods (place them near `getPrePerspectiveBmp`):

```brightscript
    ' Builds (or rebuilds, if maxDrawDistance changed since the last build) a bitmap
    ' that repeats the plane's tile enough times per axis to seamlessly cover the
    ' world-space footprint bounded by camera.maxDrawDistance, so a single wrapped
    ' anchor point (see wrapAnchorIntoSuperTexture()) is always far enough from every
    ' edge of this bitmap to cover the actual required rotated footprint. Lazy and
    ' cached - built once per maxDrawDistance value, not per frame. See the design
    ' note on ScratchBitmapPool's device-scratch-size cap for why this is its own
    ' persistent bitmap rather than a pooled scratch region.
    '
    ' @param {BGE.Renderer} rendererObj
    private sub buildSuperTextureIfNeeded(rendererObj as BGE.Renderer)
      camera = rendererObj.camera as Camera3d
      if invalid <> m.superTextureBmp and m.superTextureBuiltForMaxDrawDistance = camera.maxDrawDistance
        return
      end if

      m.tileWidth = m.drawable.region.GetWidth()
      m.tileHeight = m.drawable.region.GetHeight()
      smallestTileDimension = BGE.Math.Min(m.tileWidth, m.tileHeight)

      m.tilesPerAxis = Fix(2 * camera.maxDrawDistance / smallestTileDimension) + 1
      if (m.tilesPerAxis mod 2) = 0
        ' Keep it odd, so a tile sits exactly centered in the supertexture - the
        ' center tile is where wrapAnchorIntoSuperTexture() re-centers every anchor.
        m.tilesPerAxis = m.tilesPerAxis + 1
      end if

      bmpWidth = m.tilesPerAxis * m.tileWidth
      bmpHeight = m.tilesPerAxis * m.tileHeight
      m.superTextureBmp = CreateObject("roBitmap", {width: bmpWidth, height: bmpHeight, AlphaEnable: true})
      m.superTextureBmp.SetAlphaEnable(true)
      m.superTextureBmp.Clear(&h00000000)

      for row = 0 to m.tilesPerAxis - 1
        for col = 0 to m.tilesPerAxis - 1
          rendererObj.drawObjectTo(m.superTextureBmp, col * m.tileWidth, row * m.tileHeight, m.drawable.region)
        end for
      end for

      m.superTextureRegion = CreateObject("roRegion", m.superTextureBmp, 0, 0, bmpWidth, bmpHeight)
      m.superTextureBuiltForMaxDrawDistance = camera.maxDrawDistance
    end sub

    ' Wraps a texture-pixel anchor point (unbounded, since it's derived from an
    ' unbounded world-space camera position) into this instance's supertexture bounds -
    ' re-centered so it always lands on the equivalent phase within the supertexture's
    ' own center tile. Only the anchor needs wrapping, not every corner point: the
    ' warp's rotation angle and scale factors are already translation-invariant
    ' (computed from differences/perpendicular distances between corners in
    ' populatePerspectiveBmp), so wrapping just this one pivot point is correct.
    '
    ' @param {BGE.Math.Vector} point
    ' @return {BGE.Math.Vector}
    private function wrapAnchorIntoSuperTexture(point as BGE.Math.Vector) as BGE.Math.Vector
      centerTileIndex = Int(m.tilesPerAxis / 2)
      wrappedX = BGE.Math.wrapValue(point.x, m.tileWidth)
      wrappedY = BGE.Math.wrapValue(point.y, m.tileHeight)
      return BGE.Math.VectorOps.create(centerTileIndex * m.tileWidth + wrappedX, centerTileIndex * m.tileHeight + wrappedY, 0)
    end function
```

Update `populatePerspectiveBmp` to take the anchor point and an optional dedicated scratch bitmap explicitly, instead of always deriving `cp.topLeft` and always going through the pool:

```brightscript
    private function populatePerspectiveBmp(rendererObj as BGE.Renderer, cp as BGE.Math.CornerPoints, srcRegion as ifDraw2D, destRegion as ifDraw2D, anchorPoint as BGE.Math.Vector, ownScratchBmp = invalid as roBitmap) as boolean
      if invalid = cp
        return false
      end if

      rotation = BGE.Math.atan2(cp.topRight.y - cp.topLeft.y, cp.topRight.x - cp.topLeft.x)
      footInfo = BGE.Math.TriangleOps.getPerpendicularFootFromPoint(cp.topLeft, cp.topRight, cp.bottomRight)

      distanceFromTopToBottom = BGE.Math.TotalDistance(cp.topLeft, cp.topRight)
      if distanceFromTopToBottom = 0
        return false
      end if

      horizScale = destRegion.GetWidth() / distanceFromTopToBottom
      vertScale = destRegion.GetHeight() / footInfo.distanceToPoint

      usingOwnScratch = invalid <> ownScratchBmp
      scratchRegionForPool = invalid
      scratchDrawTo = invalid as ifDraw2D
      if usingOwnScratch
        scratchDrawTo = ownScratchBmp
      else
        scratchRegionForPool = rendererObj.bmpPool.getRegion(srcRegion.GetWidth(), srcRegion.GetHeight())
        if scratchRegionForPool = invalid
          print "failed to get scratch region from pool"
          return false
        end if
        scratchDrawTo = scratchRegionForPool.region
      end if

      ' Scratch regions/bitmaps are reused frame to frame and are NOT cleared
      ' automatically - if the rotated draw below lands mostly or entirely outside
      ' this canvas (e.g. the camera's view has moved beyond the texture's valid
      ' bounds), leftover pixel data from a previous, unrelated frame's use of this
      ' same bitmap would otherwise show through.
      scratchDrawTo.Clear(&h00000000)
      destRegion.Clear(&h00000000)

      worked = rendererObj.drawRotatedImageWithCenterTo(scratchDrawTo, srcRegion, anchorPoint, rotation, BGE.Math.VectorOps.negative(anchorPoint))
      worked = worked and rendererObj.drawScaledObjectTo(destRegion, 0, 0, horizScale, vertScale, scratchDrawTo)
      if not worked
        print "failed to draw perspective bmp"
      end if
      if not usingOwnScratch
        rendererObj.bmpPool.returnRegion(scratchRegionForPool)
      end if

      return worked
    end function
```

Update the two call sites in `performDraw` (the `staticImage` path stays byte-for-byte equivalent; a `tiledImage` branch is added):

```brightscript
      if invalid = m.prePerspectiveBmp
        m.prePerspectiveBmp = m.getPrePerspectiveBmp(rendererObj)
      end if

      gotPreBmp = false
      if m.drawable.fillMode = PlaneFillMode.tiledImage
        m.buildSuperTextureIfNeeded(rendererObj)
        wrappedAnchor = m.wrapAnchorIntoSuperTexture(m.perspectivePoints.mapped.topLeft)
        gotPreBmp = m.populatePerspectiveBmp(rendererObj, m.perspectivePoints.mapped, m.superTextureRegion, m.prePerspectiveBmp, wrappedAnchor, m.tiledScratchBmp)
      else
        gotPreBmp = m.populatePerspectiveBmp(rendererObj, m.perspectivePoints.mapped, m.drawable.region, m.prePerspectiveBmp, m.perspectivePoints.mapped.topLeft)
      end if
      if not gotPreBmp
        return false
      end if
```

`m.tiledScratchBmp` (already declared as a field above) is a **second** persistent bitmap, the same size as the supertexture but never holding supertexture content itself - kept separate from `m.superTextureBmp` so the rotate step's destination is never the same bitmap `srcRegion` reads from. Create it inside `buildSuperTextureIfNeeded`, right after `m.superTextureRegion = ...`:

```brightscript
      m.tiledScratchBmp = CreateObject("roBitmap", {width: bmpWidth, height: bmpHeight, AlphaEnable: true})
      m.tiledScratchBmp.SetAlphaEnable(true)
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `npm run build-tests && npm run test:ci`
Expected: PASS

- [ ] **Step 5: Run full validation**

Run: `npm run validate`
Expected: no type errors.

- [ ] **Step 6: Commit**

```bash
git add src/source/engine/renderer/sceneObjects/SceneObjectPlane.bs src/source/engine/renderer/sceneObjects/SceneObjectPlane.spec.bs
git commit -m "SceneObjectPlane: render tiledImage fillMode via a cached supertexture

Builds a bitmap once per maxDrawDistance value (lazily, on first tiled draw)
that repeats the plane's tile enough times per axis to cover the
maxDrawDistance footprint, then wraps the per-frame anchor point into that
cache instead of the raw tile - the existing single rotate+scale warp call
is otherwise unchanged. Uses a dedicated scratch bitmap rather than the
renderer's ScratchBitmapPool, since the pool clamps to the device's own
scratch size (as low as 256px) and a supertexture built to cover the default
1000-unit maxDrawDistance can easily exceed that.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 7: `examples/terrain` demonstrates all three fill modes and stacking

**Files:**
- Modify: `examples/terrain/src/source/Rooms/MainRoom.bs`

**Interfaces:**
- Consumes: `BGE.PlaneFillMode`, the updated `BGE.DrawablePlane` constructor (Tasks 4-6).

- [ ] **Step 1: Replace the checkerboard/map toggle with a mode cycle plus a stacked color base**

Read the current file first (`examples/terrain/src/source/Rooms/MainRoom.bs`) to confirm line numbers haven't shifted from earlier tasks (they haven't - this task only touches the example, not engine source). Replace `setGroundTexture`, its call site in `onCreate`, its call site in `onInput`, and the `showingCheckerboard` field:

```brightscript
class MainRoom extends BGE.Room

  drawablePlane as BGE.DrawablePlane
  colorBasePlane as BGE.DrawablePlane
  groundModeIndex = 0 ' cycles staticImage -> tiledImage -> color
```

Replace `setGroundTexture` with:

```brightscript
  ' Cycles the ground's overlay layer through the three fill modes, always drawn on
  ' top of a permanent color base plane added once in onCreate() - demonstrating that
  ' DrawablePlane layers compose via ordinary addDrawable() insertion order. Replaces
  ' the overlay drawable entirely (rather than reassigning its region) since
  ' BGE.SceneObjectPlane caches a rendered bitmap and only redraws it once the camera
  ' has moved - a plain region swap wouldn't be picked up until the next camera
  ' movement.
  private sub cycleGroundOverlay()
    if invalid <> m.drawablePlane
      m.removeDrawable("GroundOverlay")
    end if

    groundPlaneDef = {normal: {x: 0, y: 1, z: 0}, point: {x: 0, y: 0, z: 0}}

    if m.groundModeIndex = 0
      marioKartBmp = m.game.getBitmap("mariokart")
      bmpRegion = CreateObject("roRegion", marioKartBmp, 0, 76, 1024, 1024)
      m.drawablePlane = new BGE.DrawablePlane(m, bmpRegion, groundPlaneDef, {fillMode: BGE.PlaneFillMode.staticImage})
    else if m.groundModeIndex = 1
      checkerboardBmp = m.game.getBitmap("checkerboard")
      ' A small crop of the checkerboard sheet, used as a single repeating tile -
      ' the whole 1080x1080 sheet would make for a needlessly huge cached
      ' supertexture (see SceneObjectPlane.buildSuperTextureIfNeeded).
      tileRegion = CreateObject("roRegion", checkerboardBmp, 0, 0, 120, 120)
      m.drawablePlane = new BGE.DrawablePlane(m, tileRegion, groundPlaneDef, {fillMode: BGE.PlaneFillMode.tiledImage})
    else
      m.drawablePlane = invalid
    end if

    if invalid <> m.drawablePlane
      m.addDrawable("GroundOverlay", m.drawablePlane)
    end if
  end sub
```

Update `onCreate` (replace the `m.setGroundTexture(false)` call):

```brightscript
  override sub onCreate(args as roAssociativeArray)
    m.colorBasePlane = new BGE.DrawablePlane(m, invalid, {normal: {x: 0, y: 1, z: 0}, point: {x: 0, y: 0, z: 0}}, {fillMode: BGE.PlaneFillMode.color, color: BGE.ColorsRGB.Green})
    m.addDrawable("GroundBase", m.colorBasePlane)
    m.cycleGroundOverlay()

    camera = m.game.canvas.renderer.camera as BGE.Camera3d
    camera.position = BGE.Math.VectorOps.create(0, m.cameraHeight, 0)
    m.updateCameraOrientation()

    marker = new RollMarker(m.game)
    marker.position = BGE.Math.VectorOps.create(150, 0, -400)
    m.game.addEntity(marker)
  end sub
```

Update `onInput`'s "OK" handling:

```brightscript
      if input.isButton("OK")
        m.groundModeIndex = (m.groundModeIndex + 1) mod 3
        m.cycleGroundOverlay()
```

Update `onDrawEnd`'s help text to mention the new cycle (replace `"OK: toggle track / checkerboard   Play: reset pitch/roll"` with `"OK: cycle ground overlay   Play: reset pitch/roll"`).

- [ ] **Step 2: Build the example**

Run: `cd examples/terrain && npm run build`
Expected: builds with no errors. (`npm run prepare-examples` from the repo root first if `node_modules`/the ropm-linked engine build is stale.)

- [ ] **Step 3: Commit**

```bash
git add examples/terrain/src/source/Rooms/MainRoom.bs
git commit -m "examples/terrain: demonstrate composable ground planes

A permanent color base plane (green) now sits under a cycling overlay
(static map decal -> tiled checkerboard -> none, revealing the base) -
demonstrating that DrawablePlane layers of any fillMode compose via ordinary
addDrawable() calls.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 8: Docs update

**Files:**
- Modify: `CLAUDE.md`
- Modify: `docs/drawables-and-scene-objects.md`

Per the project's own standing rule (proactively review docs on significant engine changes), this task is not optional polish.

- [ ] **Step 1: Update `CLAUDE.md`**

In the `SceneObjectPlane`/`DrawablePlane` bullet under **Renderer / SceneObjects**, add a short paragraph (after the existing `SceneObjectPlane`/`DrawablePlane` bullet) covering:
- `Camera3d.maxDrawDistance` (default `1000`) as the shared far-clip every `SceneObject.isInView` check now honors, and that `SceneObjectPlane` derives its own far distance and tiled-supertexture size from this same field instead of a private constant (issue #124).
- `DrawablePlane.fillMode` (`color`/`tiledImage`/`staticImage`) and that multiple planes compose via ordinary `addDrawable()` calls, insertion order deciding layering at equal depth (issue #53).
- The tiled supertexture's memory cost scales with `(maxDrawDistance / tileSize)²` and is a one-time, lazily-built, per-instance cache - pick a tile size with this in mind.

Read the existing bullet's surrounding prose first (`CLAUDE.md`'s "Renderer / SceneObjects" section, the `SceneObjectPlane`/`DrawablePlane` bullet) and match its citation style (issue links, backtick-quoted identifiers).

- [ ] **Step 2: Update `docs/drawables-and-scene-objects.md`**

Find this guide's existing `DrawablePlane`/`SceneObjectPlane` section (search for "SceneObjectPlane" or "Mode-7" in the file) and add a subsection covering the three fill modes with a short code example per mode, e.g.:

```brightscript
' A flat green base layer
baseLayer = new BGE.DrawablePlane(room, invalid, groundPlane, {fillMode: BGE.PlaneFillMode.color, color: BGE.ColorsRGB.Green})
room.addDrawable("GroundBase", baseLayer)

' A repeating grass tile on top of it
grassTile = CreateObject("roRegion", grassBmp, 0, 0, 64, 64)
grassLayer = new BGE.DrawablePlane(room, grassTile, groundPlane, {fillMode: BGE.PlaneFillMode.tiledImage})
room.addDrawable("Grass", grassLayer)

' A one-off decal (e.g. a road) on top of both
roadDecal = new BGE.DrawablePlane(room, roadRegion, groundPlane, {fillMode: BGE.PlaneFillMode.staticImage})
room.addDrawable("Road", roadDecal)
```

Follow this with a short callout matching this guide's existing tone (see the fundamentals-first convention already used throughout this file) that layering order follows `addDrawable()` insertion order for planes at the same depth, and that `tiledImage`'s cache size depends on `Camera3d.maxDrawDistance` and the tile's own dimensions.

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md docs/drawables-and-scene-objects.md
git commit -m "Document Camera3d.maxDrawDistance and DrawablePlane fill modes

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 9: On-device verification (mandatory gate)

Per this repo's own established lesson (`CLAUDE.md`'s "Conventions specific to this codebase" - automated tests don't exercise example app code, and static analysis has twice missed runtime-only crashes here), this task is the actual completion gate, not optional polish.

- [ ] **Step 1: Run the full local quality gate**

Run: `npm run check`
Expected: lint, validate, and headless tests all pass.

- [ ] **Step 2: Validate every example**

Run: `npm run check:all`
Expected: passes, including `validate-examples`.

- [ ] **Step 3: Sideload and drive `examples/terrain` via `rokubot`**

Use the `rokubot-examples` skill's workflow to sideload `examples/terrain`, launch it, and:
- Confirm the default view (static map + green base underneath, base not visible since the map is opaque and full-coverage).
- Press OK once: confirm the tiled checkerboard overlay appears, seamlessly repeating (no visible tile-boundary seams or black gaps) both close to the origin and after driving far away from it (Up held for several seconds) - this is the actual test of issue #53's tiling goal and can only be judged visually.
- Press OK again: confirm the overlay disappears and the green color base plane is now visible on its own, still extending to the horizon in every direction.
- Check the on-screen FPS display (enable via held-Back debug toggle, already wired up in this room) at each of the three states - confirm no regression severe enough to be user-visible stutter, given the far-clip's default grew from 512 to 1000 (roughly 4x the plane's own bitmap/memory cost, per the design doc).
- Roll the camera (Instant Replay/Options) and pitch it (Rewind/FF) in the tiled-overlay state specifically - confirm the tiled ground still renders correctly (no seams, no wrong rotation) under roll, since the supertexture's wrapped-anchor math has to interact correctly with `SceneObjectPlane`'s existing roll handling.

If any of these show a visual defect, treat it as a real bug to fix before considering this plan complete - do not rationalize a visual artifact away as "probably fine."

- [ ] **Step 4: Report results**

Summarize what was actually observed (not assumed) for each bullet above, including the FPS numbers at each ground-overlay state, before treating this plan as done.
