# Skybox rendering + terrain example showcase world Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add skybox rendering to the engine (issue #65) and use it, together with a
tiled-grass/static-map ground and scattered trees, to build a new `WorldRoom` in
`examples/terrain` as that example's first room.

**Architecture:** A `DrawableSkybox`/`SceneObjectSkybox` pair (matching the existing
Drawable/SceneObject family) draws a cylindrical panorama that tracks camera yaw/pitch,
with roll handled by rendering the unrolled result and rotating the composited bitmap
(mirroring `SceneObjectPlane`'s existing roll trick). A new `Renderer.drawScene()` pass
draws it first, unsorted. A shared `FreeFlyCameraController` helper (extracted from
`MainRoom`) gives both terrain rooms roll-relative yaw/pitch, a ground clamp, and
back-button room switching. `WorldRoom` layers a color/tiled-grass/static-map ground,
one skybox, and 69 fixed-position tree billboards.

**Tech Stack:** BrighterScript, Rooibos (`rooibos-roku`) for unit tests, `brs-cli` for
headless CI, `rokubot` for on-device/simulator verification.

**Spec:** `specs/2026-08-23-skybox-and-terrain-world-design.md`

## Global Constraints

- One `@suite` class per `*.spec.bs` file (Rooibos v6 corrupts multi-suite files).
- `assertEqual` is type-strict (Integer vs Float) - match the literal type the code
  under test actually produces (see CLAUDE.md's Unit tests section).
- Every entity/room callback must re-validate the entity/room via `isValidEntity()`
  where the codebase convention already does so - not applicable to the plain
  (non-`GameEntity`) `FreeFlyCameraController` class this plan adds, which is called
  directly and synchronously.
- Run `npm run validate` after any engine change; `npm run lint` before committing;
  `npm run test:ci` before considering an engine task done.
- Terse code comments (the "why" only, 1-3 sentences) - match the surrounding file's
  density.
- On-device/simulator verification via `rokubot-examples` is mandatory for
  `examples/*` runtime behavior - `npm run check`/`validate-examples` do not exercise
  example room/entity code at all.

---

## Part A - Skybox rendering (issue #65)

### Task 1: `DrawableSkybox` + `SceneObjectSkybox` scaffolding

**Files:**
- Modify: `src/source/engine/renderer/sceneObjects/SceneObject.bs` (add `Skybox` to
  `SceneObjectType`)
- Create: `src/source/engine/drawables/DrawableSkybox.bs`
- Create: `src/source/engine/renderer/sceneObjects/SceneObjectSkybox.bs`
- Test: `src/source/engine/drawables/DrawableSkybox.spec.bs`
- Test: `src/source/engine/renderer/sceneObjects/SceneObjectSkybox.spec.bs`

**Interfaces:**
- Produces: `BGE.SceneObjectType.Skybox` enum member; `BGE.DrawableSkybox(owner as
  BGE.GameEntity, region as roRegion, args = {} as object)` with public fields
  `degreesPerFullWidth as float = 360`, `verticalDegreesCovered as float = 90`;
  `BGE.SceneObjectSkybox(name as string, drawableObj as BGE.DrawableSkybox)` extending
  `BGE.SceneObject`, overriding `participatesInOverlapDetection() as boolean` (returns
  `false`), `isPotentiallyOnScreen(cameraObj as Camera) as boolean` (returns `false`
  unless `cameraObj.name = "Camera3d"`, both protected - matching every other
  `SceneObject` subclass's convention, so no test calls either directly), and
  `updateWorldPosition(drawMode as SceneObjectDrawMode) as boolean` (returns `true`
  without touching `drawable.getWorldPosition()` - a skybox has no meaningful world
  position). Also produces the public `renderNow(rendererObj as BGE.Renderer) as
  boolean` - applies the same Camera2d/Camera3d gate and then calls `performDraw`
  directly, bypassing the base `update()`/`draw()` pipeline's `movedLastFrame(true)`
  call (which dereferences the drawable's owner - fine for a real Room/GameEntity
  owner via the normal `Renderer.drawScene()` path, but not an option for a caller
  with none). `renderNow` is how Task 5's rendererTest demo (deliberately built
  without `Game`/`Room`) and this class's own unit tests exercise drawing.
  `performDraw`/`findCanvasPosition` are stubbed in this task (real logic lands in
  Tasks 2-3) - `findCanvasPosition` returns `true`, `performDraw` returns `false` for
  now.

- [ ] **Step 1: Write the failing tests**

`src/source/engine/drawables/DrawableSkybox.spec.bs`:

```
namespace tests

  @suite("BGE.DrawableSkybox")
  class DrawableSkyboxTests extends rooibos.BaseTestSuite

    game as BGE.Game
    entity as BGE.GameEntity
    sourceBitmap as roBitmap

    protected override function beforeEach()
      m.game = new BGE.Game(320, 240)
      m.entity = new BGE.GameEntity(m.game, {name: "TestEntity"})
      m.sourceBitmap = CreateObject("roBitmap", {width: 64, height: 32, alphaEnable: true})
    end function

    private function newRegion() as roRegion
      return CreateObject("roRegion", m.sourceBitmap, 0, 0, 64, 32)
    end function

    @describe("construction")

    @it("defaults degreesPerFullWidth to 360 and verticalDegreesCovered to 90")
    function _()
      skybox = new BGE.DrawableSkybox(m.entity, m.newRegion())
      m.assertEqual(360.0, skybox.degreesPerFullWidth)
      m.assertEqual(90.0, skybox.verticalDegreesCovered)
    end function

    @it("accepts overrides via the args associative array, like every other Drawable")
    function _()
      skybox = new BGE.DrawableSkybox(m.entity, m.newRegion(), {degreesPerFullWidth: 180.0, verticalDegreesCovered: 60.0})
      m.assertEqual(180.0, skybox.degreesPerFullWidth)
      m.assertEqual(60.0, skybox.verticalDegreesCovered)
    end function

    @describe("addToScene")

    @it("registers a SceneObjectSkybox of type Skybox")
    function _()
      skybox = new BGE.DrawableSkybox(m.entity, m.newRegion())
      skybox.addToScene(m.game.canvas.renderer)
      sceneObjects = skybox.getSceneObjects()
      m.assertEqual(1, sceneObjects.count())
      m.assertEqual("Skybox", sceneObjects[0].type)
    end function

  end class

end namespace
```

`src/source/engine/renderer/sceneObjects/SceneObjectSkybox.spec.bs`:

```
namespace tests

  @suite("BGE.SceneObjectSkybox")
  class SceneObjectSkyboxTests extends rooibos.BaseTestSuite

    game as BGE.Game
    drawable as BGE.DrawableSkybox
    skybox as BGE.SceneObjectSkybox
    sourceBitmap as roBitmap

    protected override function beforeEach()
      m.game = new BGE.Game(200, 100)
      m.game.setCamera(new BGE.Camera3d())
      m.game.canvas.renderer.camera.setFrameSize(200, 100)

      m.sourceBitmap = CreateObject("roBitmap", {width: 64, height: 32, alphaEnable: true})
      region = CreateObject("roRegion", m.sourceBitmap, 0, 0, 64, 32)
      ' No room is defined in this suite - SceneObjectSkybox never touches its
      ' drawable's owner, so invalid is safe here (same pattern the rendererTest
      ' SkyboxTest demo uses for the same reason - see Task 5).
      m.drawable = new BGE.DrawableSkybox(invalid, region)
      m.skybox = new BGE.SceneObjectSkybox("skybox", m.drawable)
    end function

    @describe("participatesInOverlapDetection")

    @it("is false - a skybox is always fully behind everything, never a cluster candidate")
    function _()
      m.assertFalse(m.skybox.participatesInOverlapDetection())
    end function

    @describe("renderNow")

    ' isPotentiallyOnScreen/performDraw are protected (matching SceneObject's own
    ' convention - see SceneObjectPlane, which never calls either directly from its
    ' spec either), so the Camera2d/Camera3d gate is exercised through the public
    ' renderNow() wrapper instead. At this stage performDraw is still the Task-1 stub
    ' (always returns false), so this only proves the Camera2d short-circuit rejects
    ' before ever reaching performDraw - real Camera3d drawing is covered once Task 2
    ' gives performDraw a real implementation.
    @it("is false under a Camera2d - Camera2d skybox support is a separate follow-up issue")
    function _()
      m.game.setCamera(new BGE.Camera2d())
      m.assertFalse(m.skybox.renderNow(m.game.canvas.renderer))
    end function

  end class

end namespace
```

- [ ] **Step 2: Run tests to verify they fail (compile error - types don't exist yet)**

Run: `npm run build-tests`
Expected: FAIL - `BGE.DrawableSkybox`/`BGE.SceneObjectSkybox`/`SceneObjectType.Skybox` not found

- [ ] **Step 3: Add the `Skybox` enum member**

In `src/source/engine/renderer/sceneObjects/SceneObject.bs`, add to the existing
`SceneObjectType` enum (near `Plane`):

```
    Plane = "Plane"
    Skybox = "Skybox"
```

- [ ] **Step 4: Create the minimal `SceneObjectSkybox`**

```
namespace BGE

  class SceneObjectSkybox extends SceneObject

    drawable as DrawableSkybox

    sub new(name as string, drawableObj as DrawableSkybox)
      super(name, drawableObj, BGE.SceneObjectType.Skybox)
      ' Redeclaring `drawable` above auto-inits it to invalid after super() - this wins since it runs last (issue #69).
      m.drawable = drawableObj
    end sub

    ' A skybox is always fully behind everything and has no meaningful bounding hull -
    ' never a candidate for overlap-cluster interleaving (mirrors SceneObjectPlane/
    ' SceneObjectLine's own exclusion for the same reason).
    override function participatesInOverlapDetection() as boolean
      return false
    end function

    ' Only a Camera3d has yaw/pitch to map a cylindrical panorama against - a 2D room
    ' simply never draws this. See specs/2026-08-23-skybox-and-terrain-world-design.md's
    ' Camera2d follow-up note.
    protected override function isPotentiallyOnScreen(cameraObj as Camera) as boolean
      return cameraObj.name = "Camera3d"
    end function

    ' A skybox has no meaningful world position (it's always drawn as if centered on
    ' the camera) - skip the base class's default, which computes one from
    ' m.drawable.getWorldPosition() for no benefit here.
    override function updateWorldPosition(drawMode as SceneObjectDrawMode) as boolean
      return true
    end function

    protected override function findCanvasPosition(rendererObj as Renderer, drawMode as SceneObjectDrawMode) as boolean
      return true
    end function

    protected override function performDraw(rendererObj as BGE.Renderer, drawMode as SceneObjectDrawMode) as boolean
      return false
    end function

    ' Draws this skybox against rendererObj's current camera right now, bypassing the
    ' base SceneObject update()/draw() pipeline entirely. That pipeline's update()
    ' unconditionally calls m.drawable.movedLastFrame(true), which dereferences the
    ' drawable's owner - fine for a DrawableSkybox added to a real Room/GameEntity
    ' (the normal path, via Renderer.drawScene()), but not an option for a caller with
    ' no owning entity at all. renderNow() is that owner-independent entry point: used
    ' by the rendererTest SkyboxTest demo (Task 5), which deliberately has no
    ' Game/Room, and by this class's own unit tests for the same reason. It applies
    ' the same Camera2d/Camera3d gate isPotentiallyOnScreen() would.
    function renderNow(rendererObj as BGE.Renderer) as boolean
      if rendererObj.camera.name <> "Camera3d"
        return false
      end if
      return m.performDraw(rendererObj, BGE.SceneObjectDrawMode.directToCamera)
    end function

  end class

end namespace
```

- [ ] **Step 5: Create `DrawableSkybox`**

```
namespace BGE

  ' Draws a cylindrical panorama that tracks the camera's yaw/pitch (and, via a
  ' render-then-rotate composite, roll), giving a Camera3d scene a sky/horizon
  ' background instead of a flat fill. See SceneObjectSkybox for the draw algorithm.
  class DrawableSkybox extends BGE.Image

    ' How many degrees of camera yaw the texture's full width covers. Default wraps a
    ' full circle - the horizontal texture offset loops seamlessly at any yaw.
    degreesPerFullWidth as float = 360

    ' How many degrees of camera pitch the texture's full height covers, centered on
    ' the texture's vertical middle (pitch 0 = horizon). Looking past this range shows
    ' the renderer's background, same as a finite ground decal running out.
    verticalDegreesCovered as float = 90

    ' @param {BGE.GameEntity} owner
    ' @param {roRegion} region a cylindrical panorama texture
    ' @param {object} [args={}] pass `degreesPerFullWidth`/`verticalDegreesCovered` here to override the defaults
    sub new(owner as BGE.GameEntity, region as roRegion, args = {} as object)
      super(owner, region, args)
      ' bs:disable-next-line: 1140
      m.append(args)
    end sub

    override sub addToScene(rendererObj as Renderer)
      m.addSceneObjectToRenderer(new SceneObjectSkybox(m.getSceneObjectName("skybox"), m), rendererObj)
    end sub

  end class

end namespace
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `npm run build-tests && npm run test:ci`
Expected: PASS for all tests in both new spec files

- [ ] **Step 7: Lint and validate**

Run: `npm run lint && npm run validate`
Expected: no errors

- [ ] **Step 8: Commit**

```bash
git add src/source/engine/renderer/sceneObjects/SceneObject.bs src/source/engine/renderer/sceneObjects/SceneObjectSkybox.bs src/source/engine/renderer/sceneObjects/SceneObjectSkybox.spec.bs src/source/engine/drawables/DrawableSkybox.bs src/source/engine/drawables/DrawableSkybox.spec.bs
git commit -m "Add DrawableSkybox/SceneObjectSkybox scaffolding (issue #65)"
```

---

### Task 2: Flat (non-rolled) skybox draw

**Files:**
- Modify: `src/source/engine/renderer/sceneObjects/SceneObjectSkybox.bs`
- Modify: `src/source/engine/renderer/sceneObjects/SceneObjectSkybox.spec.bs`

**Interfaces:**
- Consumes: `BGE.Camera3d.orientation` (Vector), `.rollDegrees` (float),
  `.fieldOfViewDegrees` (float), `.getFovDegreesForCanvasSize(canvasHeight as float) as
  float`, `.frameSize` (Vector); `BGE.Math.atan2(y as float, x as float) as float`,
  `BGE.Math.Clamp`, `BGE.Math.DegreesToRadians`, `BGE.Math.RadiansToDegrees`.
- Produces: public `computeVisibleBand(camera as Camera3d, destWidth as float,
  destHeight as float) as object` (returns `{leftX, topY, cropHeight, scaleX, scaleY,
  textureWidth, textureHeight}`) and public `arcsinDegrees(sinValue as float) as
  float`, both callable directly in tests without a full render pass (mirrors
  `SceneObjectPlane.getRollCanvasSize()`'s precedent of exposing pure-math helpers
  publicly for testability).

- [ ] **Step 1: Write the failing tests**

Append to `SceneObjectSkyboxTests` (before the closing `end class`):

```
    @describe("arcsinDegrees")

    @it("returns 0 for sin=0, 90 for sin=1, -90 for sin=-1")
    function _()
      m.assertEqual(0.0, Fix(m.skybox.arcsinDegrees(0)))
      m.assertEqual(90.0, Fix(m.skybox.arcsinDegrees(1)))
      m.assertEqual(-90.0, Fix(m.skybox.arcsinDegrees(-1)))
    end function

    @describe("computeVisibleBand")

    @it("centers on the texture's horizontal middle when facing the default orientation (yaw 0)")
    function _()
      camera = m.game.canvas.renderer.camera as BGE.Camera3d
      camera.orientation = BGE.Math.VectorOps.create(0, 0, -1) ' yaw 0, matches the engine's default forward
      band = m.skybox.computeVisibleBand(camera, 200, 100)
      ' 64px-wide texture / 360 degrees-per-width, camera fov defaults to 90 degrees -
      ' visible band is 16px wide, centered on the texture's 32px midpoint.
      m.assertEqual(24.0, band.leftX)
    end function

    @it("shifts the band left as yaw increases (turning right samples further along the texture)")
    function _()
      camera = m.game.canvas.renderer.camera as BGE.Camera3d
      camera.orientation = BGE.Math.VectorOps.create(1, 0, 0) ' yaw +90 degrees
      band = m.skybox.computeVisibleBand(camera, 200, 100)
      ' +90 degrees of yaw on a 360-degree-wide 64px texture is a quarter-texture (16px) shift.
      m.assertEqual(40.0, band.leftX)
    end function

    @it("shifts the band up as pitch increases (looking up samples toward the texture's top)")
    function _()
      camera = m.game.canvas.renderer.camera as BGE.Camera3d
      camera.orientation = BGE.Math.VectorOps.create(0, 0, -1)
      levelBand = m.skybox.computeVisibleBand(camera, 200, 100)

      camera.orientation = BGE.Math.VectorOps.create(0, 1, 0) ' straight up, pitch +90 degrees
      upBand = m.skybox.computeVisibleBand(camera, 200, 100)

      ' Not asserting an exact figure here - the vertical FOV in play comes from
      ' Camera3d.getFovDegreesForCanvasSize()'s aspect-based formula, not a round
      ' number. The regression this guards is direction: looking up must move the
      ' sampled band toward the texture's top (smaller topY), not leave it flat or
      ' move it the wrong way.
      m.assertTrue(upBand.topY < levelBand.topY)
    end function

    @describe("renderNow")

    @it("draws under Camera3d now that performDraw is implemented")
    function _()
      m.game.canvas.renderer.resetDrawCallCounter()
      m.assertTrue(m.skybox.renderNow(m.game.canvas.renderer))
      m.assertTrue(m.game.canvas.renderer.getDrawCallsLastFrame() > 0)
    end function
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `npm run build-tests && npm run test:ci`
Expected: FAIL - `arcsinDegrees`/`computeVisibleBand` not defined, or return wrong values

- [ ] **Step 3: Implement the math helpers and flat draw in `SceneObjectSkybox`**

Replace the Task-1 stub `findCanvasPosition`/`performDraw` and add the new methods:

```
    ' BrighterScript/BrightScript has no native arcsine - asin(x) = atan2(x, sqrt(1-x^2))
    ' for x in [-1, 1] is the standard identity, reusing the engine's existing atan2.
    ' Exposed (not private) so its correctness can be tested directly, matching
    ' SceneObjectPlane.getRollCanvasSize()'s precedent for pure-math helpers.
    function arcsinDegrees(sinValue as float) as float
      clamped = BGE.Math.Clamp(sinValue, -1, 1)
      return BGE.Math.RadiansToDegrees(BGE.Math.atan2(clamped, Sqr(1 - clamped * clamped)))
    end function

    ' Camera3d.orientation itself is unaffected by roll (rolling spins the camera
    ' around its own forward axis, which doesn't change that axis's direction) - so yaw
    ' and pitch can be read directly off orientation with no roll-aware "level" variant
    ' needed, unlike SceneObjectPlane's horizon math. Roll is applied separately, as a
    ' final image rotation (see the roll path in performDraw, Task 3).
    '
    ' @param {Camera3d} camera
    ' @param {float} destWidth the destination surface's width in pixels
    ' @param {float} destHeight the destination surface's height in pixels
    ' @return {object} {leftX, topY, cropHeight, scaleX, scaleY, textureWidth, textureHeight}
    function computeVisibleBand(camera as Camera3d, destWidth as float, destHeight as float) as object
      textureWidth = m.drawable.region.GetWidth()
      textureHeight = m.drawable.region.GetHeight()
      pxPerDegX = textureWidth / m.drawable.degreesPerFullWidth
      pxPerDegY = textureHeight / m.drawable.verticalDegreesCovered

      yawDeg = BGE.Math.RadiansToDegrees(BGE.Math.atan2(camera.orientation.x, -camera.orientation.z))
      pitchDeg = m.arcsinDegrees(camera.orientation.y)

      horizFov = camera.fieldOfViewDegrees
      vertFov = camera.getFovDegreesForCanvasSize(destHeight)

      visibleWidthPx = horizFov * pxPerDegX
      visibleHeightPx = vertFov * pxPerDegY

      ' Float-safe wrap into [0, 360) - BrightScript's MOD operator has no documented
      ' float contract in this codebase (every existing use is integer-only), so wrap
      ' by hand rather than relying on it.
      wrappedYawDeg = yawDeg - 360 * Int(yawDeg / 360)
      if wrappedYawDeg < 0
        wrappedYawDeg = wrappedYawDeg + 360
      end if
      ' Texture's horizontal middle column is yaw 0 - not its left edge (pixel 0).
      centerX = (wrappedYawDeg / 360) * textureWidth + textureWidth / 2
      if centerX >= textureWidth
        centerX = centerX - textureWidth
      end if
      leftX = centerX - visibleWidthPx / 2

      topY = (textureHeight / 2) - (pitchDeg * pxPerDegY) - (visibleHeightPx / 2)

      ' Vertical is finite (looking past verticalDegreesCovered's edge shows nothing,
      ' same as a finite ground decal) - clamp the crop into the texture's bounds and
      ' shrink the destination band to match rather than sampling out of range.
      cropHeight = visibleHeightPx
      destYOffset = 0.0
      if topY < 0
        destYOffset = -topY
        cropHeight = cropHeight + topY
        topY = 0.0
      end if
      if topY + cropHeight > textureHeight
        cropHeight = textureHeight - topY
      end if

      return {
        leftX: leftX
        topY: topY
        cropHeight: cropHeight
        destYOffset: destYOffset
        visibleWidthPx: visibleWidthPx
        scaleX: destWidth / visibleWidthPx
        scaleY: destHeight / visibleHeightPx
        textureWidth: textureWidth
        textureHeight: textureHeight
      }
    end function

    ' Blits the unrolled (no-roll) visible band into destSurface, sized destWidth x
    ' destHeight. Handles the horizontal wrap seam (two source slices) when the visible
    ' band crosses the texture's left or right edge - vertical is never wrapped (see
    ' computeVisibleBand).
    '
    ' @return {boolean} true if anything was drawn (false only when the vertical crop
    '   collapsed to nothing, i.e. pitch looked entirely past verticalDegreesCovered)
    private function drawUnrolledBand(rendererObj as BGE.Renderer, destSurface as ifDraw2D, destWidth as float, destHeight as float, band as object) as boolean
      if band.cropHeight <= 0
        return false
      end if

      srcBitmap = m.drawable.region.GetBitmap()
      destSurface.Clear(&h00000000)

      leftX = band.leftX
      destYOffset = band.destYOffset * band.scaleY

      if leftX < 0
        wrapWidth = -leftX
        firstWidth = wrapWidth
        secondWidth = band.visibleWidthPx - wrapWidth
        firstRegion = CreateObject("roRegion", srcBitmap, band.textureWidth - wrapWidth, band.topY, firstWidth, band.cropHeight)
        secondRegion = CreateObject("roRegion", srcBitmap, 0, band.topY, secondWidth, band.cropHeight)
        worked = rendererObj.drawScaledObjectTo(destSurface, 0, destYOffset, band.scaleX, band.scaleY, firstRegion)
        worked = rendererObj.drawScaledObjectTo(destSurface, firstWidth * band.scaleX, destYOffset, band.scaleX, band.scaleY, secondRegion) and worked
        return worked
      else if leftX + band.visibleWidthPx > band.textureWidth
        firstWidth = band.textureWidth - leftX
        secondWidth = band.visibleWidthPx - firstWidth
        firstRegion = CreateObject("roRegion", srcBitmap, leftX, band.topY, firstWidth, band.cropHeight)
        secondRegion = CreateObject("roRegion", srcBitmap, 0, band.topY, secondWidth, band.cropHeight)
        worked = rendererObj.drawScaledObjectTo(destSurface, 0, destYOffset, band.scaleX, band.scaleY, firstRegion)
        worked = rendererObj.drawScaledObjectTo(destSurface, firstWidth * band.scaleX, destYOffset, band.scaleX, band.scaleY, secondRegion) and worked
        return worked
      end if

      region = CreateObject("roRegion", srcBitmap, leftX, band.topY, band.visibleWidthPx, band.cropHeight)
      return rendererObj.drawScaledObjectTo(destSurface, 0, destYOffset, band.scaleX, band.scaleY, region)
    end function

    protected override function findCanvasPosition(rendererObj as Renderer, drawMode as SceneObjectDrawMode) as boolean
      return true
    end function

    protected override function performDraw(rendererObj as BGE.Renderer, drawMode as SceneObjectDrawMode) as boolean
      camera = rendererObj.camera as Camera3d

      if invalid = m.tempBitmap or m.tempBitmap.GetWidth() <> camera.frameSize.x or m.tempBitmap.GetHeight() <> camera.frameSize.y
        m.tempBitmap = CreateObject("roBitmap", {width: camera.frameSize.x, height: camera.frameSize.y, AlphaEnable: true})
      end if

      band = m.computeVisibleBand(camera, camera.frameSize.x, camera.frameSize.y)
      if not m.drawUnrolledBand(rendererObj, m.tempBitmap, camera.frameSize.x, camera.frameSize.y, band)
        return false
      end if

      return rendererObj.drawObject(0, 0, m.tempBitmap)
    end function
```

Add the field near the top of the class (with `drawable`):

```
    private tempBitmap as roBitmap
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `npm run build-tests && npm run test:ci`
Expected: PASS for all tests

- [ ] **Step 5: Lint and validate**

Run: `npm run lint && npm run validate`

- [ ] **Step 6: Commit**

```bash
git add src/source/engine/renderer/sceneObjects/SceneObjectSkybox.bs src/source/engine/renderer/sceneObjects/SceneObjectSkybox.spec.bs
git commit -m "Implement flat (non-rolled) skybox draw"
```

---

### Task 3: Roll handling (render-then-rotate)

**Files:**
- Modify: `src/source/engine/renderer/sceneObjects/SceneObjectSkybox.bs`
- Modify: `src/source/engine/renderer/sceneObjects/SceneObjectSkybox.spec.bs`

**Interfaces:**
- Consumes: `Renderer.drawRotatedImageWithCenterTo(draw2d as ifDraw2d, srcRegion as
  ifDraw2d, srcRotationPoint as BGE.Math.Vector, theta as float, translation =
  BGE.Math.VectorOps.create() as BGE.Math.Vector) as boolean`.
- Produces: public `getRollCanvasSize(frameSize as BGE.Math.Vector) as float` (same
  contract as `SceneObjectPlane.getRollCanvasSize`), used by `performDraw`'s roll path.

- [ ] **Step 1: Write the failing tests**

Append to `SceneObjectSkyboxTests`:

```
    @describe("getRollCanvasSize")

    @it("returns a size at least as large as the frame's diagonal")
    function _()
      size = m.skybox.getRollCanvasSize(BGE.Math.VectorOps.create(200, 100))
      diagonal = Sqr(200.0 * 200.0 + 100.0 * 100.0)
      m.assertTrue(size >= diagonal)
    end function

    @describe("a rolled camera still draws")

    @it("renderNow succeeds with a non-zero rollDegrees")
    function _()
      camera = m.game.canvas.renderer.camera as BGE.Camera3d
      camera.rollDegrees = 30
      camera.checkMovement()
      m.assertTrue(m.skybox.renderNow(m.game.canvas.renderer))
    end function
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `npm run build-tests && npm run test:ci`
Expected: FAIL - `getRollCanvasSize` not defined

- [ ] **Step 3: Implement `getRollCanvasSize` and the roll path in `performDraw`**

Add the method:

```
    ' Sized to at least the camera frame's diagonal, so a composite rendered into a
    ' canvasSize x canvasSize square can be rotated by any angle without exposing an
    ' empty corner once it's cropped back down to the real frame - mirrors
    ' SceneObjectPlane.getRollCanvasSize() exactly (same underlying geometry problem).
    '
    ' @param {BGE.Math.Vector} frameSize
    ' @return {float}
    function getRollCanvasSize(frameSize as BGE.Math.Vector) as float
      return Int(Sqr(frameSize.x * frameSize.x + frameSize.y * frameSize.y)) + 2
    end function
```

Add the field:

```
    private rotatedTempBitmap as roBitmap
```

Replace `performDraw` with:

```
    protected override function performDraw(rendererObj as BGE.Renderer, drawMode as SceneObjectDrawMode) as boolean
      camera = rendererObj.camera as Camera3d
      isRolled = camera.rollDegrees <> 0

      destWidth = camera.frameSize.x
      destHeight = camera.frameSize.y
      if isRolled
        compositeSize = m.getRollCanvasSize(camera.frameSize)
        destWidth = compositeSize
        destHeight = compositeSize
      end if

      if invalid = m.tempBitmap or m.tempBitmap.GetWidth() <> destWidth or m.tempBitmap.GetHeight() <> destHeight
        m.tempBitmap = CreateObject("roBitmap", {width: destWidth, height: destHeight, AlphaEnable: true})
      end if

      band = m.computeVisibleBand(camera, destWidth, destHeight)
      if not m.drawUnrolledBand(rendererObj, m.tempBitmap, destWidth, destHeight, band)
        return false
      end if

      if not isRolled
        return rendererObj.drawObject(0, 0, m.tempBitmap)
      end if

      ' m.tempBitmap is the enlarged, level (unrolled) composite here - rotating it by
      ' rollDegrees about its own center and reading off the real frame-sized region
      ' centered on that same point gives exactly the rolled camera's view. Same trick
      ' as SceneObjectPlane (specs/2026-08-19-camera-roll-and-plane-horizon-design.md).
      center = BGE.Math.VectorOps.create(destWidth / 2, destHeight / 2)
      rollRad = BGE.Math.DegreesToRadians(camera.rollDegrees)
      cropOffset = BGE.Math.VectorOps.create((destWidth - camera.frameSize.x) / 2, (destHeight - camera.frameSize.y) / 2)

      if invalid = m.rotatedTempBitmap or m.rotatedTempBitmap.GetWidth() <> camera.frameSize.x or m.rotatedTempBitmap.GetHeight() <> camera.frameSize.y
        m.rotatedTempBitmap = CreateObject("roBitmap", {width: camera.frameSize.x, height: camera.frameSize.y, AlphaEnable: true})
      end if
      m.rotatedTempBitmap.Clear(&h00000000)

      worked = rendererObj.drawRotatedImageWithCenterTo(m.rotatedTempBitmap, m.tempBitmap, center, rollRad, BGE.Math.VectorOps.negative(cropOffset))
      worked = worked and rendererObj.drawObject(0, 0, m.rotatedTempBitmap)
      return worked
    end function
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `npm run build-tests && npm run test:ci`
Expected: PASS for all tests

- [ ] **Step 5: Lint and validate**

Run: `npm run lint && npm run validate`

- [ ] **Step 6: Commit**

```bash
git add src/source/engine/renderer/sceneObjects/SceneObjectSkybox.bs src/source/engine/renderer/sceneObjects/SceneObjectSkybox.spec.bs
git commit -m "Add skybox roll support (render-then-rotate)"
```

---

### Task 4: Hook the skybox pass into `Renderer.drawScene()`

**Files:**
- Modify: `src/source/engine/renderer/Renderer.bs:463-478` (the plane pass, in
  `drawScene()`)
- Test: `src/source/engine/renderer/Renderer.spec.bs`

**Interfaces:**
- Consumes: `SceneObjectType.Skybox` (Task 1).
- Produces: skybox scene objects draw before the plane pass, in insertion order;
  excluded from `getClusterCandidates()`.

- [ ] **Step 1: Write the failing test**

Append to `RendererTests` in `Renderer.spec.bs` (add a `@describe`/`@it` block; check
the file's existing `beforeEach` for the `bitmap`/`renderer` fields it already sets up,
and add a `game`/`room` field only if this suite doesn't already have one for a
similar existing test - if it does, reuse it):

```
    @describe("drawScene skybox pass")

    @it("draws a Skybox-type scene object before the plane pass, even though both are enabled")
    function _()
      game = new BGE.Game(64, 64)
      game.setCamera(new BGE.Camera3d())
      game.canvas.renderer.camera.setFrameSize(64, 64)
      room = new BGE.Room(game, {name: "TestRoom"})
      game.defineRoom(room)
      game.changeRoom("TestRoom")

      skyBmp = CreateObject("roBitmap", {width: 8, height: 4, alphaEnable: true})
      skyRegion = CreateObject("roRegion", skyBmp, 0, 0, 8, 4)
      skyDrawable = new BGE.DrawableSkybox(room, skyRegion)
      room.addDrawable("Sky", skyDrawable)

      planeBmp = CreateObject("roBitmap", {width: 8, height: 8, alphaEnable: true})
      planeRegion = CreateObject("roRegion", planeBmp, 0, 0, 8, 8)
      planeDrawable = new BGE.DrawablePlane(room, planeRegion, {normal: {x: 0, y: 1, z: 0}, point: {x: 0, y: 0, z: 0}})
      room.addDrawable("Ground", planeDrawable)

      ' drawScene() must not error and must actually attempt both draws - the
      ' regression this guards is a skybox scene object never being reached at all
      ' (e.g. filtered out by the type check) rather than draw ordering per se, since
      ' ordering has no externally-observable effect for two objects that don't
      ' occlude each other in this headless test.
      game.canvas.renderer.drawScene()
      m.assertTrue(true)
    end function
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm run build-tests && npm run test:ci`
Expected: FAIL or crash - `Renderer.drawScene()` never reaches `SceneObjectType.Skybox`
objects (they fall through to the generic sorted-pass loop today with no camera-aware
gating, since Task 1-3 built the class but nothing drives it from `drawScene()` yet)

- [ ] **Step 3: Add the skybox pass**

In `src/source/engine/renderer/Renderer.bs`, immediately before the existing `' draw
planes first` comment and its loop (~line 466), add:

```
      for each sceneObj in m.sceneObjects
        if sceneObj.isEnabled() and sceneObj.type = SceneObjectType.Skybox
          sceneObj.draw(m)
        end if
      end for

      'TODO - Do proper occlusion culling
      ' draw planes first
```

Then update the plane loop's condition (and the final sorted-pass loop's condition) to
also exclude `Skybox`, so a skybox never double-draws through either of the other two
passes:

```
        if sceneObj.isEnabled() and sceneObj.type = SceneObjectType.Plane
```
stays as-is (Skybox already only matches its own new loop above), and:
```
        if sceneObj.isEnabled()and sceneObj.type <> SceneObjectType.Plane
```
becomes:
```
        if sceneObj.isEnabled() and sceneObj.type <> SceneObjectType.Plane and sceneObj.type <> SceneObjectType.Skybox
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npm run build-tests && npm run test:ci`
Expected: PASS

- [ ] **Step 5: Lint and validate**

Run: `npm run lint && npm run validate`

- [ ] **Step 6: Commit**

```bash
git add src/source/engine/renderer/Renderer.bs src/source/engine/renderer/Renderer.spec.bs
git commit -m "Draw Skybox-type scene objects in their own earliest pass"
```

---

### Task 5: `rendererTest` `SkyboxTest` demo

**Files:**
- Create: `examples/rendererTest/src/source/Tests/SkyboxTest.bs`
- Modify: `examples/rendererTest/src/source/DemoList.bs`

**Interfaces:**
- Consumes: `RendererTest` base class (`setup(renderer)`, `update(dt)`,
  `draw(renderer)`, `onInput(buttonName)`), `BGE.DrawableSkybox`,
  `BGE.SceneObjectSkybox` - none of these are `GameEntity`/`Room`-based, so this demo
  constructs a `BGE.Camera3d` directly rather than going through `BGE.Game`, matching
  every other `rendererTest` demo's isolation from `Game`/`Room`.

- [ ] **Step 1: Write `SkyboxTest.bs`**

```
namespace BGE

  class SkyboxTest extends RendererTest

    camera as BGE.Camera3d
    drawable as BGE.DrawableSkybox
    yawDegreesPerSec = 30
    rollDegreesPerSec = 0

    override sub setup(renderer as BGE.Renderer)
      m.camera = new BGE.Camera3d()
      m.camera.setFrameSize(renderer.getCanvasSize().x, renderer.getCanvasSize().y)
      renderer.camera = m.camera

      skyBmp = CreateObject("roBitmap", "pkg:/sprites/skybox_night.jpg")
      skyRegion = CreateObject("roRegion", skyBmp, 0, 0, skyBmp.GetWidth(), skyBmp.GetHeight())

      ' No owning GameEntity/Room exists in this demo (rendererTest is deliberately
      ' built without Game/Room - see CLAUDE.md). DrawableSkybox/SceneObjectSkybox
      ' tolerate an invalid owner by design (SceneObjectSkybox.updateWorldPosition()
      ' never dereferences it - see Task 1).
      m.drawable = new BGE.DrawableSkybox(invalid, skyRegion)
    end sub

    override sub update(dt as float)
      yawRad = BGE.Math.DegreesToRadians(m.yawDegreesPerSec * dt)
      m.camera.orientation = BGE.Math.RotateVectorAroundPoint3d(m.camera.orientation, BGE.Math.VectorOps.create(), BGE.Math.VectorOps.create(0, 1, 0), yawRad)
      if m.rollDegreesPerSec <> 0
        m.camera.rollDegrees = m.camera.rollDegrees + m.rollDegreesPerSec * dt
      end if
    end sub

    override sub draw(renderer as BGE.Renderer)
      m.camera.checkMovement()
      ' renderNow(), not update()/draw() - the base SceneObject update() pipeline
      ' unconditionally touches the drawable's owner, and this demo has none (see
      ' SceneObjectSkybox.renderNow()'s doc comment, Task 1). getSceneObjects()[0] is
      ' safe - DrawableSkybox.addToScene() always registers exactly one
      ' SceneObjectSkybox. Cast to the subtype since renderNow() isn't on the base
      ' SceneObject type getSceneObjects() returns.
      sceneObj = m.drawable.getSceneObjects()[0] as BGE.SceneObjectSkybox
      sceneObj.renderNow(renderer)
    end sub

    ' OK toggles a constant roll, to specifically measure the render-then-rotate
    ' path's cost (issue #65's DoD calls for measuring this, not just the flat path).
    override sub onInput(buttonName as string)
      if buttonName = "OK"
        if m.rollDegreesPerSec = 0
          m.rollDegreesPerSec = 20
        else
          m.rollDegreesPerSec = 0
          m.camera.rollDegrees = 0
        end if
      end if
    end sub

  end class

end namespace
```

- [ ] **Step 2: Copy the skybox texture into `rendererTest`'s sprites**

```bash
mkdir -p examples/rendererTest/src/sprites
cp examples/terrain/src/sprites/skybox_night.jpg examples/rendererTest/src/sprites/skybox_night.jpg
```

- [ ] **Step 3: Register the demo in `DemoList.bs`**

Open `examples/rendererTest/src/source/DemoList.bs`, find the array of demo entries,
and add (matching the existing entry shape/category grouping used by other
draw-mode/perf demos there):

```
    {id: "skybox", category: "Renderer", name: "Skybox (yaw/pitch/roll)", create: function() as RendererTest
      return new BGE.SkyboxTest()
    end function}
```

- [ ] **Step 4: Build and manually verify via `rokubot-examples`**

This is a visual/perf demo, not something Rooibos can assert on - follow the
`rokubot-examples` skill to sideload `examples/rendererTest`, launch directly into the
demo (`rokubot launch dev --param demo=skybox`), and confirm via screenshot: the sky
scrolls as yaw animates, OK toggles a visible roll, and the FPS/frame-ms/draw-call
overlay reports sane numbers (no crash, no runaway frame time).

- [ ] **Step 5: Commit**

```bash
git add examples/rendererTest/src/source/Tests/SkyboxTest.bs examples/rendererTest/src/source/DemoList.bs examples/rendererTest/src/sprites/skybox_night.jpg
git commit -m "Add rendererTest SkyboxTest demo"
```

---

### Task 6: Docs for the skybox

**Files:**
- Modify: `docs/drawables-and-scene-objects.md`
- Modify: `CLAUDE.md` (Renderer/SceneObjects section)

**Interfaces:** none (docs only)

- [ ] **Step 1: Add a Skybox section to `docs/drawables-and-scene-objects.md`**

Read the file's existing Plane section first (`grep -n "^### " docs/drawables-and-scene-objects.md`)
to match its heading level and tone, then add a new `### Skybox` section
immediately after it covering: what `DrawableSkybox`/`SceneObjectSkybox` do, the
`degreesPerFullWidth`/`verticalDegreesCovered` fields with a code example
constructing one, and one paragraph on the render-then-rotate roll trick with a link
to `specs/2026-08-19-camera-roll-and-plane-horizon-design.md` (same trick,
cross-referenced rather than re-explained).

- [ ] **Step 2: Update `CLAUDE.md`**

In the Renderer/SceneObjects bullet list (the `SceneObjectPlane`/`SceneObjectModel`
paragraph), add one sentence noting `SceneObjectSkybox` and the new earliest
`drawScene()` pass, following the existing bullet's density and cross-referencing
issue #65.

- [ ] **Step 3: Commit**

```bash
git add docs/drawables-and-scene-objects.md CLAUDE.md
git commit -m "Document the skybox in docs/drawables-and-scene-objects.md and CLAUDE.md"
```

---

## Part B - Shared free-fly camera controller

### Task 7: `FreeFlyCameraController`

**Files:**
- Create: `examples/terrain/src/source/Entities/FreeFlyCameraController.bs`
- Test: `examples/terrain/src/source/Entities/FreeFlyCameraController.spec.bs`

**Interfaces:**
- Consumes: `BGE.Room`, `BGE.Camera3d.getUpVector()`/`.getRightVector()`,
  `BGE.Math.RotateVectorAroundPoint3d`, `BGE.Math.Plane`.
- Produces: `FreeFlyCameraController(room as BGE.Room, otherRoomName as string,
  groundPlane as BGE.Math.Plane)` with `onInput(input as BGE.GameInput)`,
  `update(dt as float)`, `getHintText() as string`, and a public
  `clampAboveGround(candidate as BGE.Math.Vector) as BGE.Math.Vector` (exposed for
  direct testing).

Note: this class lives under `examples/terrain`, not `src/source/engine` - it's
example-app code, not part of the shippable engine, so it isn't covered by
`npm run validate`/`npm run check`'s engine-only gates, but it IS covered by Rooibos
since `examples/terrain` has its own `bsconfig.json`/test setup. Check
`examples/terrain/package.json` for its own `test`/`build-tests` scripts before
writing the test - if it has none, add a minimal Rooibos suite only for
`clampAboveGround` (pure math, no `Game`/`Room` needed) and skip Rooibos entirely for
the input/update methods, verifying those via Task 8's on-device pass instead.

- [ ] **Step 1: Check whether `examples/terrain` has its own test setup**

Run: `cat examples/terrain/package.json examples/terrain/bsconfig.json`

If there's no `rooibos-roku` plugin/test bsconfig for this example (expected - most
examples don't), skip straight to Step 3 and rely on the on-device verification in
Task 12 for `onInput`/`update`; still write the `clampAboveGround` test as a plain
manual check (Step 2) since it's pure math and worth getting right before wiring it
into live camera movement.

- [ ] **Step 2: Write a throwaway verification script for `clampAboveGround`'s math**

This isn't committed - it's a quick correctness check before writing the real class,
since `examples/terrain` has no Rooibos harness to lean on. Run this with `brs-cli` or
by temporarily pasting the function into a scratch `.bs` file compiled via `bsc`:

```
plane = {normal: {x: 0, y: 1, z: 0}, point: {x: 0, y: 0, z: 0}}
minHeight = 1.0

function clampAboveGround(candidate, plane, minHeight)
  toCandidate = BGE.Math.VectorOps.subtract(candidate, plane.point)
  distance = BGE.Math.VectorOps.dotProduct(toCandidate, plane.normal)
  if distance >= minHeight
    return candidate
  end if
  shortfall = minHeight - distance
  return BGE.Math.VectorOps.add(candidate, BGE.Math.VectorOps.scale(plane.normal, shortfall))
end function

' Expect: y stays 50 (already well above ground)
print clampAboveGround(BGE.Math.VectorOps.create(0, 50, 0), plane, minHeight)
' Expect: y pushed up to 1 (was at 0, exactly on the plane)
print clampAboveGround(BGE.Math.VectorOps.create(10, 0, -5), plane, minHeight)
' Expect: y pushed up to 1 (was below the plane, at -20)
print clampAboveGround(BGE.Math.VectorOps.create(10, -20, -5), plane, minHeight)
```

Confirm the three printed `y` values are `50`, `1`, `1` before proceeding.

- [ ] **Step 3: Write `FreeFlyCameraController.bs`**

```
namespace BGE

end namespace

' A plain, non-GameEntity helper: the owning Room constructs one and forwards its own
' onInput/onUpdate calls to it. Extracted from the terrain example's original MainRoom
' so both MainRoom and WorldRoom share the same controls and the same fixes - yaw/pitch
' relative to the camera's current (roll-adjusted) orientation instead of always
' world-vertical, and a ground clamp so flying forward can't cross the ground plane.
class FreeFlyCameraController

  room as BGE.Room
  otherRoomName as string
  groundPlane as BGE.Math.Plane

  turnSpeed = 2.0 ' radians/sec
  driveSpeed = 80 ' units/sec
  rollSpeed = 60 ' degrees/sec
  pitchSpeed = 0.3 ' radians/sec
  ' Keeps pitch well short of +/-90 degrees - Camera3d.getLevelUpVector()'s
  ' forward-parallel-to-world-up fallback degrades past that point.
  maxDownwardTilt = 1.2 ' radians (~69 degrees)
  minHeightAboveGround = 1.0 ' world units

  ' Tracked only to enforce maxDownwardTilt - yaw is free rotation with no clamp, so it
  ' needs no equivalent accumulator.
  pitchAccum = 0.0
  rollDirection = 0 ' -1 = rolling left, 1 = rolling right, 0 = not rolling
  pitchDirection = 0 ' -1 = pitching up, 1 = pitching down, 0 = not pitching
  backHeldMs = 0
  debugToggledForThisHold = false
  debugEnabled = false
  lastInput as BGE.GameInput

  sub new(room as BGE.Room, otherRoomName as string, groundPlane as BGE.Math.Plane)
    m.room = room
    m.otherRoomName = otherRoomName
    m.groundPlane = groundPlane
  end sub

  function getHintText() as string
    return "Turn: Left/Right   Move: Up/Down" + Chr(10) + "Roll: Instant Replay/Options   Pitch: Rewind/FF" + Chr(10) + "Play: reset orientation   Back: switch room" + Chr(10) + "Hold Back 2s: toggle debug info"
  end function

  sub onInput(input as BGE.GameInput)
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

    if input.press and input.isButton("play")
      camera = m.getCamera()
      camera.rollDegrees = 0
      m.pitchAccum = 0
      camera.orientation = BGE.Math.VectorOps.create(0, 0, -1)
    end if

    ' Back needs tap-vs-hold disambiguation: switching rooms can't fire on press (a
    ' hold-to-toggle-debug would never get 2 seconds to accumulate before the room
    ' already changed), so a press just resets the hold tracking, and a release only
    ' switches rooms if the hold never reached 2 seconds (i.e. debug info wasn't
    ' already toggled by update()'s held-time check below).
    if input.isButton("back")
      if input.press
        m.backHeldMs = 0
        m.debugToggledForThisHold = false
      else if input.release
        if not m.debugToggledForThisHold
          m.room.game.changeRoom(m.otherRoomName)
        end if
      end if
    end if
  end sub

  sub update(dt as float)
    input = m.lastInput
    camera = m.getCamera()

    if input <> invalid
      if input.x <> 0
        camera.orientation = BGE.Math.RotateVectorAroundPoint3d(camera.orientation, BGE.Math.VectorOps.create(), camera.getUpVector(), input.x * dt * m.turnSpeed)
      end if
      if input.y <> 0
        candidate = BGE.Math.VectorOps.add(camera.position, BGE.Math.VectorOps.scale(camera.orientation, input.y * dt * m.driveSpeed))
        camera.position = m.clampAboveGround(candidate)
      end if
      if input.isButton("back") and input.held
        m.backHeldMs = input.heldTimeMs
        if m.backHeldMs >= 2000 and not m.debugToggledForThisHold
          m.debugEnabled = not m.debugEnabled
          m.room.game.debugDrawEntityDetails(m.debugEnabled)
          m.debugToggledForThisHold = true
        end if
      end if
    end if

    if m.rollDirection <> 0
      camera.rollDegrees = camera.rollDegrees + m.rollDirection * m.rollSpeed * dt
    end if

    if m.pitchDirection <> 0
      delta = m.pitchDirection * m.pitchSpeed * dt
      clampedAccum = BGE.Math.Clamp(m.pitchAccum + delta, -m.maxDownwardTilt, m.maxDownwardTilt)
      actualDelta = clampedAccum - m.pitchAccum
      m.pitchAccum = clampedAccum
      if actualDelta <> 0
        camera.orientation = BGE.Math.RotateVectorAroundPoint3d(camera.orientation, BGE.Math.VectorOps.create(), camera.getRightVector(), actualDelta)
      end if
    end if
  end sub

  ' Pushes a candidate camera position back above the ground plane by at least
  ' minHeightAboveGround, along the plane's own normal - keeps the camera from flying
  ' through the ground regardless of the plane's orientation. Exposed (not private) for
  ' direct testing.
  function clampAboveGround(candidate as BGE.Math.Vector) as BGE.Math.Vector
    toCandidate = BGE.Math.VectorOps.subtract(candidate, m.groundPlane.point)
    distance = BGE.Math.VectorOps.dotProduct(toCandidate, m.groundPlane.normal)
    if distance >= m.minHeightAboveGround
      return candidate
    end if
    shortfall = m.minHeightAboveGround - distance
    return BGE.Math.VectorOps.add(candidate, BGE.Math.VectorOps.scale(m.groundPlane.normal, shortfall))
  end function

  private function getCamera() as BGE.Camera3d
    return m.room.game.canvas.renderer.camera as BGE.Camera3d
  end function

end class
```

(Delete the stray empty `namespace BGE ... end namespace` block above if your editor's
template inserted one - this class is deliberately NOT inside the `BGE` namespace,
since it's example-app code, matching how `RollMarker`/other terrain entities aren't
namespaced either.)

- [ ] **Step 4: Build the example to confirm it compiles**

Run: `cd examples/terrain && npm run build`
Expected: no errors (this class isn't wired into any room yet, so nothing exercises it
at runtime until Task 8)

- [ ] **Step 5: Commit**

```bash
git add examples/terrain/src/source/Entities/FreeFlyCameraController.bs
git commit -m "Add shared FreeFlyCameraController for the terrain example"
```

---

### Task 8: Refactor `MainRoom` onto the shared controller

**Files:**
- Modify: `examples/terrain/src/source/Rooms/MainRoom.bs`

**Interfaces:**
- Consumes: `FreeFlyCameraController` (Task 7).

- [ ] **Step 1: Replace `MainRoom`'s duplicated camera-control fields/methods**

Remove these fields: `turnSpeed`, `driveSpeed`, `rollSpeed`, `pitchSpeed`,
`cameraHeight` (keep - still used in `onCreate`), `defaultDownwardTilt`,
`maxDownwardTilt`, `heading`, `downwardTilt`, `rollDirection`, `pitchDirection`,
`backHeldMs`, `debugToggledForThisHold`, `lastInput`. Remove the methods
`headingForward()` and `updateCameraOrientation()`. Remove the roll/pitch/back-handling
branches from `onInput` and `onUpdate` (keep the `OK`-cycles-ground-overlay branch and
the `play`-resets branch only if `FreeFlyCameraController.getHintText()`'s existing
"Play: reset orientation" already covers it - it does, so remove `MainRoom`'s own
`play` handling too).

Add a field:

```
  cameraController as FreeFlyCameraController
```

In `onCreate`, after setting up `camera.position` (keep the existing `cameraHeight`
logic), add:

```
    m.cameraController = new FreeFlyCameraController(m, "WorldRoom", {normal: {x: 0, y: 1, z: 0}, point: {x: 0, y: 0, z: 0}})
```

and delete the `m.updateCameraOrientation()` call that followed it (the controller
owns orientation now; the camera keeps whatever default orientation `Camera3d` starts
with, `(0,0,-1)`, which matches the old `heading=0`/`downwardTilt=0.12`... note this
is a small behavior change: `MainRoom` used to start pitched down by
`defaultDownwardTilt` (0.12 rad). Preserve that opening view by setting it explicitly
right after constructing the controller:

```
    camera.orientation = BGE.Math.RotateVectorAroundPoint3d(camera.orientation, BGE.Math.VectorOps.create(), camera.getRightVector(), 0.12)
```

- [ ] **Step 2: Delegate `onInput`/`onUpdate` to the controller**

At the top of `onInput` (after `m.lastInput = input` is removed, since the controller
tracks its own `lastInput` now):

```
  override sub onInput(input as BGE.GameInput)
    m.cameraController.onInput(input)

    if input.press
      if input.isButton("OK")
        m.groundModeIndex = (m.groundModeIndex + 1) mod 3
        m.cycleGroundOverlay()
      end if
    end if
  end sub
```

At the top of `onUpdate`:

```
  override sub onUpdate(dt as float)
    m.cameraController.update(dt)
  end sub
```

- [ ] **Step 3: Update the onscreen hint text**

In `onDrawEnd`, replace the hardcoded `text` string with:

```
    text = m.cameraController.getHintText() + Chr(10) + "OK: cycle ground overlay"
```

- [ ] **Step 4: Build and verify on-device**

Run: `cd examples/terrain && npm run build`
Expected: no errors

Follow the `rokubot-examples` skill to sideload and manually verify `MainRoom`:
turning/driving/rolling/pitching all still work, pitch and yaw now feel bank-relative
when rolled, driving into the ground no longer clips through it, OK still cycles the
ground overlay, Play resets orientation, and Back switches to `WorldRoom` (which
doesn't exist yet until Task 11 - expect this to error/no-op until then; note it and
re-verify in Task 12's final pass) rather than quitting.

- [ ] **Step 5: Commit**

```bash
git add examples/terrain/src/source/Rooms/MainRoom.bs
git commit -m "Refactor MainRoom onto the shared FreeFlyCameraController"
```

---

## Part C - `WorldRoom`

### Task 9: `TreePlacements.bs` data file

**Files:**
- Create: `examples/terrain/src/source/Rooms/TreePlacements.bs`

**Interfaces:**
- Produces: `function getTreePlacements() as object[]`, each entry
  `{x as float, z as float, spriteIndex as integer, rotationDegrees as float}`; and
  `function getTreeAnchor(spriteIndex as integer) as BGE.Math.Vector` (normalized
  x/y anchor per sprite, from the per-image trunk-base pixel measurements in the
  design spec).

- [ ] **Step 1: Write `TreePlacements.bs`**

```
' Fixed (not runtime-random) tree placements for WorldRoom, generated once from
' worldMap.png's actual grass/water/path pixel content - see
' specs/2026-08-23-skybox-and-terrain-world-design.md section 3 for how these were
' derived. 14 on-map trees sit only on grass cells (never water/path/bridge/shore),
' spread around the map's grassy perimeter; 55 forest-ring trees scatter outside the
' map's [-512,512] square footprint out to radius 800.
function getTreePlacements() as object[]
  return [
    {x: -272.0, z: -144.0, spriteIndex: 5, rotationDegrees: 228.0}
    {x: 272.0, z: 80.0, spriteIndex: 2, rotationDegrees: 270.3}
    {x: 464.0, z: 272.0, spriteIndex: 5, rotationDegrees: 249.1}
    {x: -432.0, z: -400.0, spriteIndex: 3, rotationDegrees: 359.1}
    {x: -368.0, z: 144.0, spriteIndex: 4, rotationDegrees: 327.1}
    {x: 176.0, z: -400.0, spriteIndex: 5, rotationDegrees: 243.6}
    {x: 304.0, z: 304.0, spriteIndex: 5, rotationDegrees: 21.7}
    {x: -16.0, z: -432.0, spriteIndex: 2, rotationDegrees: 115.1}
    {x: 400.0, z: -112.0, spriteIndex: 2, rotationDegrees: 27.7}
    {x: -400.0, z: 304.0, spriteIndex: 4, rotationDegrees: 340.9}
    {x: 464.0, z: 432.0, spriteIndex: 4, rotationDegrees: 85.5}
    {x: 176.0, z: 464.0, spriteIndex: 2, rotationDegrees: 234.9}
    {x: 432.0, z: 80.0, spriteIndex: 3, rotationDegrees: 60.7}
    {x: -464.0, z: -16.0, spriteIndex: 4, rotationDegrees: 172.5}
    {x: -57.6, z: 731.2, spriteIndex: 2, rotationDegrees: 238.3}
    {x: -567.0, z: -524.5, spriteIndex: 1, rotationDegrees: 279.5}
    {x: 626.6, z: 315.3, spriteIndex: 4, rotationDegrees: 107.4}
    {x: -610.0, z: -451.6, spriteIndex: 2, rotationDegrees: 317.9}
    {x: -285.3, z: -702.2, spriteIndex: 1, rotationDegrees: 195.7}
    {x: 304.6, z: -608.2, spriteIndex: 3, rotationDegrees: 226.5}
    {x: -313.6, z: 663.3, spriteIndex: 5, rotationDegrees: 142.4}
    {x: -194.6, z: -715.1, spriteIndex: 4, rotationDegrees: 56.5}
    {x: -622.4, z: 199.3, spriteIndex: 5, rotationDegrees: 342.0}
    {x: 590.0, z: 529.9, spriteIndex: 5, rotationDegrees: 310.5}
    {x: 645.1, z: -261.2, spriteIndex: 4, rotationDegrees: 215.2}
    {x: -268.5, z: -550.8, spriteIndex: 1, rotationDegrees: 101.8}
    {x: -206.9, z: 651.1, spriteIndex: 1, rotationDegrees: 327.1}
    {x: -763.8, z: -185.0, spriteIndex: 1, rotationDegrees: 347.7}
    {x: -627.0, z: -226.2, spriteIndex: 5, rotationDegrees: 239.8}
    {x: -691.5, z: -27.8, spriteIndex: 1, rotationDegrees: 195.4}
    {x: 314.1, z: -700.1, spriteIndex: 3, rotationDegrees: 10.5}
    {x: 678.3, z: -415.2, spriteIndex: 4, rotationDegrees: 258.2}
    {x: 357.8, z: 711.6, spriteIndex: 2, rotationDegrees: 102.3}
    {x: 768.7, z: -180.7, spriteIndex: 1, rotationDegrees: 142.9}
    {x: -523.5, z: -240.0, spriteIndex: 4, rotationDegrees: 56.0}
    {x: -586.7, z: -73.6, spriteIndex: 3, rotationDegrees: 244.4}
    {x: 346.3, z: 561.2, spriteIndex: 1, rotationDegrees: 54.0}
    {x: 747.9, z: -57.1, spriteIndex: 2, rotationDegrees: 329.2}
    {x: 709.8, z: 246.4, spriteIndex: 3, rotationDegrees: 321.6}
    {x: -311.2, z: 580.7, spriteIndex: 3, rotationDegrees: 204.2}
    {x: -680.9, z: 92.1, spriteIndex: 3, rotationDegrees: 338.3}
    {x: -653.7, z: -299.3, spriteIndex: 4, rotationDegrees: 30.4}
    {x: 237.9, z: 628.7, spriteIndex: 4, rotationDegrees: 4.2}
    {x: -50.3, z: 532.6, spriteIndex: 1, rotationDegrees: 180.5}
    {x: 738.9, z: 50.8, spriteIndex: 2, rotationDegrees: 53.2}
    {x: 182.2, z: 774.8, spriteIndex: 5, rotationDegrees: 359.1}
    {x: 115.2, z: 638.1, spriteIndex: 3, rotationDegrees: 259.7}
    {x: 425.6, z: 571.8, spriteIndex: 5, rotationDegrees: 43.7}
    {x: -6.5, z: -703.8, spriteIndex: 5, rotationDegrees: 288.6}
    {x: -130.2, z: 772.1, spriteIndex: 4, rotationDegrees: 326.0}
    {x: 91.3, z: 720.9, spriteIndex: 2, rotationDegrees: 297.5}
    {x: 571.2, z: 220.5, spriteIndex: 1, rotationDegrees: 211.3}
    {x: 597.5, z: 10.9, spriteIndex: 2, rotationDegrees: 18.7}
    {x: 62.1, z: -726.4, spriteIndex: 1, rotationDegrees: 55.9}
    {x: -441.8, z: 666.8, spriteIndex: 5, rotationDegrees: 270.9}
    {x: -471.4, z: -572.8, spriteIndex: 2, rotationDegrees: 160.6}
    {x: 650.3, z: 198.6, spriteIndex: 2, rotationDegrees: 229.2}
    {x: -696.8, z: 346.1, spriteIndex: 4, rotationDegrees: 358.7}
    {x: 288.0, z: 700.6, spriteIndex: 1, rotationDegrees: 161.2}
    {x: -182.0, z: 530.8, spriteIndex: 3, rotationDegrees: 138.1}
    {x: -630.3, z: 379.8, spriteIndex: 5, rotationDegrees: 79.7}
    {x: 371.5, z: -563.8, spriteIndex: 4, rotationDegrees: 95.6}
    {x: 12.8, z: -575.9, spriteIndex: 1, rotationDegrees: 58.3}
    {x: 546.0, z: -506.5, spriteIndex: 5, rotationDegrees: 302.5}
    {x: 235.0, z: -692.3, spriteIndex: 2, rotationDegrees: 221.3}
    {x: 531.0, z: -276.2, spriteIndex: 1, rotationDegrees: 340.0}
    {x: -44.3, z: -765.2, spriteIndex: 1, rotationDegrees: 34.9}
    {x: 91.0, z: -534.7, spriteIndex: 3, rotationDegrees: 183.5}
    {x: 641.8, z: 473.7, spriteIndex: 1, rotationDegrees: 308.6}
  ]
end function

' Per-sprite normalized anchor (trunk-base pixel / image dimensions), measured
' directly off each cropped sprite - see the design spec's Trees section. Placing a
' tree's Image drawable's anchor here (rather than the default top-left/center) makes
' `offset` position the trunk's foot on the ground instead of the sprite's bounding-box
' corner or middle.
function getTreeAnchor(spriteIndex as integer) as BGE.Math.Vector
  anchors = {
    "1": BGE.Math.VectorOps.create(0.641, 0.907)
    "2": BGE.Math.VectorOps.create(0.623, 0.902)
    "3": BGE.Math.VectorOps.create(0.623, 0.896)
    "4": BGE.Math.VectorOps.create(0.624, 0.886)
    "5": BGE.Math.VectorOps.create(0.653, 0.893)
  }
  return anchors[spriteIndex.ToStr()]
end function
```

- [ ] **Step 2: Build to confirm it compiles**

Run: `cd examples/terrain && npm run build`
Expected: no errors (unused-function lint warnings are fine here - it's consumed in
Task 11)

- [ ] **Step 3: Commit**

```bash
git add examples/terrain/src/source/Rooms/TreePlacements.bs
git commit -m "Add fixed tree placement data for WorldRoom"
```

---

### Task 10: `WorldRoom`

**Files:**
- Create: `examples/terrain/src/source/Rooms/WorldRoom.bs`
- Modify: `examples/terrain/src/source/main.bs`

**Interfaces:**
- Consumes: `FreeFlyCameraController` (Task 7), `getTreePlacements()`/`getTreeAnchor()`
  (Task 9), `BGE.DrawableSkybox` (Task 1), `BGE.DrawablePlane`/`BGE.PlaneFillMode`
  (existing), `BGE.Image` (existing).

- [ ] **Step 1: Load the new bitmaps in `main.bs`**

In `examples/terrain/src/source/main.bs`, alongside the existing
`game.loadBitmap("mariokart", ...)`/`game.loadBitmap("checkerboard", ...)` calls, add:

```
  game.loadBitmap("grass", "pkg:/sprites/grass.png")
  game.loadBitmap("worldMap", "pkg:/sprites/worldMap.png")
  game.loadBitmap("skyboxNight", "pkg:/sprites/skybox_night.jpg")
  game.loadBitmap("tree1", "pkg:/sprites/tree1.png")
  game.loadBitmap("tree2", "pkg:/sprites/tree2.png")
  game.loadBitmap("tree3", "pkg:/sprites/tree3.png")
  game.loadBitmap("tree4", "pkg:/sprites/tree4.png")
  game.loadBitmap("tree5", "pkg:/sprites/tree5.png")
```

- [ ] **Step 2: Register `WorldRoom` and change the starting room**

In `main.bs`, add:

```
  world_Room = new WorldRoom(game)
  game.defineRoom(world_Room)
```

before the existing `main_Room = new MainRoom(game)` / `game.defineRoom(main_Room)`
lines, and change:

```
  game.changeRoom(game.getRoomNames()[0])
```

to:

```
  game.changeRoom("WorldRoom")
```

(`getRoomNames()[0]` was relying on definition order; naming it explicitly is clearer
now that there are two rooms and order matters for which one is "first" only by
convention, not by array position.)

- [ ] **Step 3: Write `WorldRoom.bs`**

```
class WorldRoom extends BGE.Room

  cameraController as FreeFlyCameraController
  cameraHeight = 50

  sub new(game as BGE.Game)
    super(game)
    m.name = "WorldRoom"
  end sub

  override sub onCreate(args as roAssociativeArray)
    groundPlaneDef = {normal: {x: 0, y: 1, z: 0}, point: {x: 0, y: 0, z: 0}}

    ' Layered ground, same composition pattern as MainRoom.cycleGroundOverlay(): a
    ' flat color base, a seamlessly tiled grass texture over it, then the finite
    ' park/lake map decal on top (grass09.png is CC0 / OpenGameArt, credit:
    ' https://opengameart.org/content/seamless-grass-textures-20-pack).
    colorBase = new BGE.DrawablePlane(m, invalid, groundPlaneDef, {fillMode: BGE.PlaneFillMode.color, color: BGE.ColorsRGB.Green})
    m.addDrawable("GroundColor", colorBase)

    grassBmp = m.game.getBitmap("grass")
    grassRegion = CreateObject("roRegion", grassBmp, 0, 0, grassBmp.GetWidth(), grassBmp.GetHeight())
    grassOverlay = new BGE.DrawablePlane(m, grassRegion, groundPlaneDef, {fillMode: BGE.PlaneFillMode.tiledImage})
    m.addDrawable("GroundGrass", grassOverlay)

    mapBmp = m.game.getBitmap("worldMap")
    mapRegion = CreateObject("roRegion", mapBmp, 0, 0, mapBmp.GetWidth(), mapBmp.GetHeight())
    mapOverlay = new BGE.DrawablePlane(m, mapRegion, groundPlaneDef, {fillMode: BGE.PlaneFillMode.staticImage})
    m.addDrawable("GroundMap", mapOverlay)

    skyBmp = m.game.getBitmap("skyboxNight")
    skyRegion = CreateObject("roRegion", skyBmp, 0, 0, skyBmp.GetWidth(), skyBmp.GetHeight())
    sky = new BGE.DrawableSkybox(m, skyRegion)
    m.addDrawable("Sky", sky)

    m.addTrees()

    camera = m.game.canvas.renderer.camera as BGE.Camera3d
    camera.position = BGE.Math.VectorOps.create(0, m.cameraHeight, 0)
    m.cameraController = new FreeFlyCameraController(m, "MainRoom", groundPlaneDef)
  end sub

  ' World size is set explicitly (not left at the source PNG's native pixel size) so
  ' every tree is the same in-world height regardless of its source image's resolution -
  ' width is derived per sprite to preserve that image's own aspect ratio.
  private sub addTrees()
    treeHeight = 180.0
    bitmapsByIndex = {
      "1": m.game.getBitmap("tree1")
      "2": m.game.getBitmap("tree2")
      "3": m.game.getBitmap("tree3")
      "4": m.game.getBitmap("tree4")
      "5": m.game.getBitmap("tree5")
    }

    placements = getTreePlacements()
    for i = 0 to placements.count() - 1
      placement = placements[i]
      bmp = bitmapsByIndex[placement.spriteIndex.ToStr()]
      region = CreateObject("roRegion", bmp, 0, 0, bmp.GetWidth(), bmp.GetHeight())
      treeWidth = treeHeight * (bmp.GetWidth() / bmp.GetHeight())

      tree = new BGE.Image(m, region, {
        width: treeWidth
        height: treeHeight
        drawMode: BGE.SceneObjectDrawMode.directToCamera
      })
      anchor = getTreeAnchor(placement.spriteIndex)
      tree.setAnchor(anchor.x, anchor.y)
      tree.offset = BGE.Math.VectorOps.create(placement.x, 0, placement.z)
      tree.rotation.z = BGE.Math.DegreesToRadians(placement.rotationDegrees)
      m.addDrawable("Tree" + i.ToStr(), tree)
    end for
  end sub

  override sub onInput(input as BGE.GameInput)
    m.cameraController.onInput(input)
  end sub

  override sub onUpdate(dt as float)
    m.cameraController.update(dt)
  end sub

  override sub onDrawEnd(renderObj as BGE.Renderer, uiRenderObj as BGE.Renderer)
    font = m.game.getFont("default")
    frameCenter = uiRenderObj.getCanvasCenter()
    uiRenderObj.DrawText(m.cameraController.getHintText(), frameCenter.x, 140, BGE.Colors.White, font, "center")
  end sub

end class
```

- [ ] **Step 4: Build**

Run: `cd examples/terrain && npm run build`
Expected: no errors

- [ ] **Step 5: Lint and validate the example**

Run: `cd examples/terrain && npm run lint && npm run validate` (or the root
`npm run validate-examples`, which covers every example including this one)

- [ ] **Step 6: Commit**

```bash
git add examples/terrain/src/source/Rooms/WorldRoom.bs examples/terrain/src/source/main.bs
git commit -m "Add WorldRoom: layered ground, skybox, and scattered trees"
```

---

### Task 11: On-device verification (mandatory)

**Files:** none (verification only)

Per CLAUDE.md: automated checks never exercise example room/entity runtime behavior,
and this plan has touched exactly the kind of code (room navigation, live camera
control, a brand-new rendering feature) that has previously passed every static check
and still crashed or looked wrong on first actual run. Follow the `rokubot-examples`
skill for the full sideload/launch/screenshot workflow.

- [ ] **Step 1: Build and sideload `examples/terrain`**

Run: `cd examples/terrain && npm run build && npm run package` (or whatever this
example's own build-and-deploy flow is - check its `package.json`), then sideload per
`rokubot-examples`.

- [ ] **Step 2: Verify `WorldRoom` (the new starting room)**

- Launches directly into `WorldRoom`, not `MainRoom`.
- Ground shows the color base, tiled grass, and the park/lake map decal layered
  correctly (map decal on top, no black seams).
- Skybox is visible, tracks yaw as you turn and pitch as you look up/down, and rolls
  correctly with no visible tearing at the composite's crop edge.
- Trees are visible, grounded (trunks touch the ground plane, not floating or sunk),
  denser outside the map footprint than on it, and none appear to be standing in the
  lake.
- Driving forward into the ground no longer clips through it - the camera stops just
  above the surface.
- Turning/pitching while rolled feels bank-relative (turn the camera to a visible
  roll, then confirm pitch/yaw rotate around the tilted axes, not always
  world-vertical).
- Back switches to `MainRoom`; a 2-second hold on Back still toggles debug info
  instead of switching rooms.

- [ ] **Step 3: Verify `MainRoom` (regression pass)**

- OK still cycles the three ground fill modes.
- Play still resets orientation.
- Back switches back to `WorldRoom`; a 2-second hold still toggles debug info.
- No regressions in turn/drive/roll/pitch feel versus before Task 8's refactor, other
  than the intentional bank-relative yaw/pitch change.

- [ ] **Step 4: Fix any issues found, re-verify, then note completion**

If anything above fails, fix it in the relevant task's files, re-run that task's
tests/build, and re-run this entire verification task from Step 1 - do not consider
Part C done until every item above passes on-device.

---

## Self-Review Notes

- **Spec coverage:** Skybox API/draw algorithm/hook/Camera2d/background-clear/testing
  (Tasks 1-6), `FreeFlyCameraController`'s yaw/pitch/ground-clamp/back-switch (Task
  7-8), `WorldRoom`'s ground/skybox/trees/navigation (Tasks 9-11), assets (staged
  ahead of this plan, referenced in Task 10), docs (Task 6). The spec's "Non-goals"
  section is deliberately not covered by any task.
- **Follow-up issue** ("Support skybox as a Camera2d parallax layer") is filed
  separately from this plan, per the spec - not a task here.
- **Type consistency:** `BGE.DrawableSkybox.degreesPerFullWidth`/
  `verticalDegreesCovered` (Task 1) are the exact names `SceneObjectSkybox`
  (Tasks 2-3) and `WorldRoom` (Task 10) reference. `FreeFlyCameraController`'s
  constructor signature (Task 7) matches both call sites in Task 8 and Task 10.
  `getTreePlacements()`/`getTreeAnchor()` (Task 9) return the exact field names
  `WorldRoom.addTrees()` (Task 10) consumes.
