# Parallax / Scrolling Background Layers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `DrawableParallaxLayer`/`SceneObjectParallaxLayer` — a bitmap-based drawable that scrolls at a configurable per-axis fraction of the camera's movement and optionally tiles to cover the viewport — plus a dedicated `examples/parallax` demonstrating it with real camera-follow.

**Architecture:** `DrawableParallaxLayer` extends `Drawable` (owns `region`/`parallaxFactor`/`repeatX`/`repeatY`, same shape as `Image`). `SceneObjectParallaxLayer` extends `SceneObject` directly (not `SceneObjectBillboard` — always flat 2D, may draw several tiled copies per frame). All the parallax math and tile enumeration live in one overridden `findCanvasPosition()`, which the base `SceneObject.draw()` already re-invokes correctly whenever the camera moves (`objMovedInRelationToCamera()`'s default already ORs in `cameraObj.movedLastFrame()`) — no changes to the shared `SceneObject`/`Drawable` base classes at all.

**Tech Stack:** BrighterScript, Rooibos (`rooibos-roku`) for unit tests, `brs-cli` headless test runner, `rokubot` for on-device verification of the new example.

## Global Constraints

- One `@suite` class per `.spec.bs` file (Rooibos v6 requirement — a second `@suite` in the same file silently corrupts test metadata).
- `assertEqual` is type-strict (Integer vs Float) — match the actual runtime type, not just the declared field type; when unsure, run the test once and read the failure diff.
- Construct a real `BGE.Game`/`GameEntity`/`Renderer` in tests rather than mocking — native Roku components (`roBitmap`, `roScreen`) can't be stubbed by Rooibos, and this repo's precedent (`SceneObjectRectangle.spec.bs`, `TweenManager.spec.bs`) always uses real construction.
- No comments in example source code explaining engine conventions the player wouldn't see (e.g. no "this keeps things title-safe" notes) — keep example comments about gameplay only. Positions/starting layout must still stay within a 10%-margin title-safe area on all sides.
- Run `npm run build-tests` after every source change in this plan, and `node scripts/run-tests-ci.js` after every task, before committing.
- Run `npm run check` (lint + validate + tests) before opening the PR at the end.
- Follow this repo's git workflow: branch `feature/parallax-layers-v2` (already created and pushed for the design spec, PR #87 open) is where this plan's commits land — do not create a new branch. Push with an explicit refspec (`git push origin feature/parallax-layers-v2:feature/parallax-layers-v2`), never a bare `git push -u origin <branch>`, since this repo's `push.default=upstream` config can silently retarget a push to `main` if the local branch's upstream ever gets set to `origin/main`.

---

## File Structure

- Create: `src/source/engine/drawables/DrawableParallaxLayer.bs` — the public `Drawable` subclass.
- Create: `src/source/engine/drawables/DrawableParallaxLayer.spec.bs` — its Rooibos suite.
- Create: `src/source/engine/renderer/sceneObjects/SceneObjectParallaxLayer.bs` — the `SceneObject` subclass doing the actual per-frame math and drawing.
- Create: `src/source/engine/renderer/sceneObjects/SceneObjectParallaxLayer.spec.bs` — its Rooibos suite (the bulk of the real test coverage: parallax math, tiling, sub-pixel accumulation).
- Modify: `src/source/engine/renderer/sceneObjects/SceneObject.bs` — add one new `SceneObjectType` enum value (`ParallaxLayer`). No other change to this file.
- Modify: `docs/drawables-and-scene-objects.md` — add the new pair to the reference table plus a short new section.
- Create: `examples/parallax/` — scaffolded via `npm run create-example`, then hand-written `Entities/Player.bs`, `Rooms/MainRoom.bs`, a small helper to paint the three procedural background bitmaps.

---

### Task 1: `SceneObjectType.ParallaxLayer` + `DrawableParallaxLayer` skeleton

**Files:**
- Modify: `src/source/engine/renderer/sceneObjects/SceneObject.bs` (the `SceneObjectType` enum, currently lines 6-14)
- Create: `src/source/engine/drawables/DrawableParallaxLayer.bs`
- Test: `src/source/engine/drawables/DrawableParallaxLayer.spec.bs`

**Interfaces:**
- Produces: `BGE.DrawableParallaxLayer` with public fields `region as roRegion`, `parallaxFactor as BGE.Math.Vector` (default `{1,1,0}`), `repeatX as boolean = true`, `repeatY as boolean = false`; constructor `sub new(owner as BGE.GameEntity, region as roRegion, args = {} as roAssociativeArray)`; `override function addToScene(rendererObj as Renderer) as BGE.SceneObject`.
- Produces: `BGE.SceneObjectType.ParallaxLayer` enum value, for later tasks to reference.

- [ ] **Step 1: Write the failing test for the enum value and construction defaults**

```brightscript
' src/source/engine/drawables/DrawableParallaxLayer.spec.bs
namespace tests

  @suite("BGE.DrawableParallaxLayer")
  class DrawableParallaxLayerTests extends rooibos.BaseTestSuite

    game as BGE.Game
    entity as BGE.GameEntity
    sourceBitmap as roBitmap

    protected override function beforeEach()
      m.game = new BGE.Game(320, 240)
      m.entity = new BGE.GameEntity(m.game, {name: "TestEntity"})
      m.sourceBitmap = CreateObject("roBitmap", {width: 32, height: 24, alphaEnable: true})
    end function

    private function newRegion(width = 32 as integer, height = 24 as integer) as roRegion
      return CreateObject("roRegion", m.sourceBitmap, 0, 0, width, height)
    end function

    @describe("construction")

    @it("takes its width/height from the region, like Image does")
    function _()
      layer = new BGE.DrawableParallaxLayer(m.entity, m.newRegion(32, 24))
      size = layer.getSize()
      m.assertEqual(32.0, size.width)
      m.assertEqual(24.0, size.height)
    end function

    @it("defaults parallaxFactor to {1,1} - ordinary 1:1 scrolling")
    function _()
      layer = new BGE.DrawableParallaxLayer(m.entity, m.newRegion())
      m.assertEqual(1.0, layer.parallaxFactor.x)
      m.assertEqual(1.0, layer.parallaxFactor.y)
    end function

    @it("defaults repeatX to true and repeatY to false")
    function _()
      layer = new BGE.DrawableParallaxLayer(m.entity, m.newRegion())
      m.assertTrue(layer.repeatX)
      m.assertFalse(layer.repeatY)
    end function

    @it("accepts overrides via the args associative array, like every other Drawable")
    function _()
      layer = new BGE.DrawableParallaxLayer(m.entity, m.newRegion(), {
        parallaxFactor: BGE.Math.VectorOps.create(0.3, 0.1),
        repeatX: false,
        repeatY: true
      })
      m.assertEqual(0.3, layer.parallaxFactor.x)
      m.assertEqual(0.1, layer.parallaxFactor.y)
      m.assertFalse(layer.repeatX)
      m.assertTrue(layer.repeatY)
    end function

    @describe("addToScene")

    @it("registers a SceneObjectParallaxLayer of type ParallaxLayer")
    function _()
      bitmap = CreateObject("roBitmap", {width: 100, height: 100, alphaEnable: true})
      renderer = new BGE.Renderer(bitmap)
      layer = new BGE.DrawableParallaxLayer(m.entity, m.newRegion())
      sceneObj = layer.addToScene(renderer)
      m.assertEqual(BGE.SceneObjectType.ParallaxLayer, sceneObj.type)
    end function

  end class

end namespace
```

- [ ] **Step 2: Run it to confirm it fails**

Run: `npm run build-tests` (expect compile errors — `DrawableParallaxLayer`/`SceneObjectType.ParallaxLayer`/`SceneObjectParallaxLayer` don't exist yet).

- [ ] **Step 3: Add the enum value**

In `src/source/engine/renderer/sceneObjects/SceneObject.bs`, add one line to the existing `SceneObjectType` enum:

```brightscript
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
  end enum
```

- [ ] **Step 4: Write `DrawableParallaxLayer`**

```brightscript
' src/source/engine/drawables/DrawableParallaxLayer.bs
namespace BGE

  ' Scrolls a tiled/non-tiled bitmap layer at a configurable per-axis fraction of the
  ' camera's movement (parallax). {1,1} is the default and behaves exactly like an
  ' ordinary drawable; {0,0} pins the layer to the camera; 0 < factor < 1 is a background
  ' layer that drifts slower than the world; factor > 1 is a foreground layer that
  ' scrolls faster. See SceneObjectParallaxLayer for the actual per-frame math.
  '
  ' Combines with the owning entity's position/offset exactly like every other Drawable -
  ' there is no special "independent of owner" positioning mode. Attach this to a
  ' dedicated static entity if you want a fixed background anchor.
  class DrawableParallaxLayer extends Drawable

    ' The bitmap tile to scroll/repeat.
    region as roRegion

    ' Per-axis fraction of camera movement this layer scrolls at. See the class doc for
    ' what different values mean.
    parallaxFactor as BGE.Math.Vector = BGE.Math.VectorOps.create(1, 1)

    ' Whether this layer tiles to cover the canvas along each axis. repeatX defaults true
    ' (the common side-scroller case); repeatY defaults false.
    repeatX as boolean = true
    repeatY as boolean = false

    sub new(owner as BGE.GameEntity, region as roRegion, args = {} as roAssociativeArray)
      super(owner, args)
      m.region = region
      if invalid <> m.region
        m.width = m.region.getWidth()
        m.height = m.region.getHeight()
      end if
      ' bs:disable-next-line: 1140
      m.append(args)
    end sub

    override function addToScene(rendererObj as Renderer) as BGE.SceneObject
      return m.addSceneObjectToRenderer(new BGE.SceneObjectParallaxLayer(m.getSceneObjectName("parallaxLayer"), m), rendererObj)
    end function

  end class

end namespace
```

- [ ] **Step 5: Write the minimal `SceneObjectParallaxLayer` to make the tests compile and pass**

```brightscript
' src/source/engine/renderer/sceneObjects/SceneObjectParallaxLayer.bs
namespace BGE

  class SceneObjectParallaxLayer extends SceneObject

    drawable as DrawableParallaxLayer

    sub new(name as string, drawableObj as DrawableParallaxLayer)
      super(name, drawableObj, BGE.SceneObjectType.ParallaxLayer)
    end sub

  end class

end namespace
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `npm run build-tests && node scripts/run-tests-ci.js`
Expected: all `DrawableParallaxLayer` tests PASS.

- [ ] **Step 7: Commit**

```bash
git add src/source/engine/renderer/sceneObjects/SceneObject.bs src/source/engine/drawables/DrawableParallaxLayer.bs src/source/engine/drawables/DrawableParallaxLayer.spec.bs src/source/engine/renderer/sceneObjects/SceneObjectParallaxLayer.bs
git commit -m "Add DrawableParallaxLayer skeleton and SceneObjectType.ParallaxLayer"
```

---

### Task 2: `findCanvasPosition` — non-repeating, factor `{1,1}` baseline behavior

**Files:**
- Modify: `src/source/engine/renderer/sceneObjects/SceneObjectParallaxLayer.bs`
- Test: `src/source/engine/renderer/sceneObjects/SceneObjectParallaxLayer.spec.bs` (new file)

**Interfaces:**
- Consumes: `BGE.DrawableParallaxLayer` (Task 1) — `region`, `parallaxFactor`, `repeatX`, `repeatY`.
- Consumes: `BGE.Math.VectorOps.subtract/add/multiply/create` (`src/source/math/Vector.bs`), `Renderer.worldPointToCanvasPoint`, `Renderer.camera.position`, `Renderer.camera.frameSize`.
- Produces: `SceneObjectParallaxLayer`'s private `tileCanvasPositions as BGE.Math.Vector[]` (the computed draw positions for this frame — later tasks and tests read it via bracket-indexing, e.g. `sceneObj["tileCanvasPositions"]`, the same pattern already established for `TweenManager`'s private `tweens` dict) and private `referencePosition as BGE.Math.Vector`.

- [ ] **Step 1: Write the failing test**

```brightscript
' src/source/engine/renderer/sceneObjects/SceneObjectParallaxLayer.spec.bs
namespace tests

  ' SceneObjectParallaxLayer does the actual drawing for a DrawableParallaxLayer. Tests
  ' drive the same two per-frame passes Renderer.drawScene() runs (update, then draw)
  ' against a real Renderer over a real bitmap - same harness SceneObjectRectangle.spec.bs
  ' uses. The default Camera2d centers on its canvas (useDefaultCameraTarget()), so for a
  ' 200x100 bitmap the camera starts at world (100, 50).
  @suite("BGE.SceneObjectParallaxLayer")
  class SceneObjectParallaxLayerTests extends rooibos.BaseTestSuite

    game as BGE.Game
    entity as BGE.GameEntity
    sourceBitmap as roBitmap
    canvasBitmap as roBitmap
    renderer as BGE.Renderer

    protected override function beforeEach()
      m.game = new BGE.Game(320, 240)
      m.entity = new BGE.GameEntity(m.game, {name: "TestEntity"})
      m.sourceBitmap = CreateObject("roBitmap", {width: 32, height: 24, alphaEnable: true})
      m.canvasBitmap = CreateObject("roBitmap", {width: 200, height: 100, alphaEnable: true})
      m.renderer = new BGE.Renderer(m.canvasBitmap)
    end function

    private function newRegion(width = 32 as integer, height = 24 as integer) as roRegion
      return CreateObject("roRegion", m.sourceBitmap, 0, 0, width, height)
    end function

    private function newLayer(args = {} as roAssociativeArray) as BGE.DrawableParallaxLayer
      return new BGE.DrawableParallaxLayer(m.entity, m.newRegion(), args)
    end function

    ' Runs one simulated frame: camera setup (so frameSize/movement tracking are current),
    ' then the same update+draw pass Renderer.drawScene() runs per scene object.
    private sub runFrame(sceneObj as BGE.SceneObject)
      m.renderer.setupCameraForFrame()
      m.entity.updateTransformationMatrix()
      sceneObj.update(m.renderer.camera)
      sceneObj.draw(m.renderer)
    end sub

    @describe("factor {1,1} - baseline (behaves like an ordinary drawable)")

    @it("draws at the entity's own canvas position regardless of camera position")
    function _()
      m.entity.position = BGE.Math.VectorOps.create(100, 50, 0)
      layer = m.newLayer({repeatX: false, repeatY: false})
      sceneObj = layer.addToScene(m.renderer)
      m.runFrame(sceneObj)

      positions = sceneObj["tileCanvasPositions"]
      m.assertEqual(1, positions.count())
      ' World (100,50) is the camera's own default target - canvas center, (100,50) on a
      ' 200x100 bitmap.
      m.assertEqual(100, positions[0].x)
      m.assertEqual(50, positions[0].y)
    end function

    @it("moves 1:1 with camera movement, same as an ordinary drawable")
    function _()
      m.entity.position = BGE.Math.VectorOps.create(100, 50, 0)
      layer = m.newLayer({repeatX: false, repeatY: false})
      sceneObj = layer.addToScene(m.renderer)
      m.runFrame(sceneObj)
      firstX = sceneObj["tileCanvasPositions"][0].x

      m.renderer.camera.position.x += 20
      m.runFrame(sceneObj)
      secondX = sceneObj["tileCanvasPositions"][0].x

      ' The world didn't move but the camera did - an ordinary (non-parallax) object
      ' shifts on canvas by the exact opposite of the camera's own movement.
      m.assertEqual(firstX - 20, secondX)
    end function

  end class

end namespace
```

- [ ] **Step 2: Run to verify it fails**

Run: `npm run build-tests && node scripts/run-tests-ci.js`
Expected: FAIL — `tileCanvasPositions` doesn't exist yet, `findCanvasPosition`/`performDraw` aren't overridden yet (no draw call happens, `hasValidCanvasPosition` never becomes true).

- [ ] **Step 3: Implement `findCanvasPosition`/`performDraw` for the non-repeating case**

```brightscript
' src/source/engine/renderer/sceneObjects/SceneObjectParallaxLayer.bs
namespace BGE

  class SceneObjectParallaxLayer extends SceneObject

    drawable as DrawableParallaxLayer

    ' The layer's own base world position at rest, captured once (first findCanvasPosition
    ' call) - the fixed baseline the camera-relative shift is measured against. Not to be
    ' confused with Drawable.anchor, the unrelated normalized 0-1 pivot-point concept.
    private optional referencePosition as BGE.Math.Vector

    ' This frame's draw positions, one per visible tile (or a single entry when neither
    ' repeatX nor repeatY is set). Recomputed in findCanvasPosition(), consumed in
    ' performDraw().
    private tileCanvasPositions as BGE.Math.Vector[] = []

    sub new(name as string, drawableObj as DrawableParallaxLayer)
      super(name, drawableObj, BGE.SceneObjectType.ParallaxLayer)
    end sub

    ' Computes this frame's canvas draw position(s). Called from the base SceneObject.draw()
    ' (never overridden directly - see class doc), already re-invoked correctly whenever the
    ' camera moves: objMovedInRelationToCamera()'s default implementation already ORs in
    ' cameraObj.movedLastFrame(), so no change to the shared SceneObject/update() machinery
    ' is needed for this to stay live under camera movement.
    protected override function findCanvasPosition(rendererObj as Renderer, drawMode as SceneObjectDrawMode) as boolean
      if invalid = m.referencePosition
        m.referencePosition = BGE.Math.VectorOps.copy(m.worldPosition)
      end if

      cameraPos = rendererObj.camera.position
      factor = m.drawable.parallaxFactor
      inverseFactor = BGE.Math.VectorOps.subtract(BGE.Math.VectorOps.create(1, 1), factor)
      delta = BGE.Math.VectorOps.subtract(cameraPos, m.referencePosition)
      shift = BGE.Math.VectorOps.multiply(inverseFactor, delta)
      effective = BGE.Math.VectorOps.add(m.worldPosition, shift)

      baseCanvasPos = rendererObj.worldPointToCanvasPoint(effective)
      if invalid = baseCanvasPos
        m.tileCanvasPositions = []
        return false
      end if

      m.tileCanvasPositions = m.computeTilePositions(baseCanvasPos, rendererObj.camera.frameSize)
      return true
    end function

    ' Non-repeating case for now - a single draw position. Tiling is added in Task 4.
    private function computeTilePositions(basePos as BGE.Math.Vector, frameSize as BGE.Math.Vector) as BGE.Math.Vector[]
      return [basePos]
    end function

    protected override function performDraw(rendererObj as Renderer, drawMode as SceneObjectDrawMode) as boolean
      if invalid = m.drawable.region
        return false
      end if
      drewAny = false
      scaleX = m.drawable.scale.x
      scaleY = m.drawable.scale.y
      for each pos in m.tileCanvasPositions
        if scaleX = 1.0 and scaleY = 1.0
          drewAny = rendererObj.drawObject(cint(pos.x), cint(pos.y), m.drawable.region) or drewAny
        else
          drewAny = rendererObj.drawScaledObject(cint(pos.x), cint(pos.y), scaleX, scaleY, m.drawable.region) or drewAny
        end if
      end for
      return drewAny
    end function

  end class

end namespace
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `npm run build-tests && node scripts/run-tests-ci.js`
Expected: all `SceneObjectParallaxLayer` tests PASS, and `DrawableParallaxLayer`'s existing tests still pass.

- [ ] **Step 5: Commit**

```bash
git add src/source/engine/renderer/sceneObjects/SceneObjectParallaxLayer.bs src/source/engine/renderer/sceneObjects/SceneObjectParallaxLayer.spec.bs
git commit -m "Implement SceneObjectParallaxLayer's baseline (factor {1,1}) draw path"
```

---

### Task 3: Parallax shift math (factor `0`, `0.5`, `>1`)

**Files:**
- Modify: `src/source/engine/renderer/sceneObjects/SceneObjectParallaxLayer.spec.bs`

No production code changes expected — Task 2's `findCanvasPosition` already implements the general formula for any factor. This task is about proving it, since factor `{1,1}` alone can't distinguish a correct implementation from one that ignores `parallaxFactor` entirely.

**Interfaces:**
- Consumes: everything from Task 2, unchanged.

- [ ] **Step 1: Write the failing tests**

```brightscript
    @describe("parallax factor shifts the effective position relative to the camera")

    @it("factor {0,0} pins the layer to the camera - it never moves on canvas")
    function _()
      m.entity.position = BGE.Math.VectorOps.create(100, 50, 0)
      layer = m.newLayer({repeatX: false, repeatY: false, parallaxFactor: BGE.Math.VectorOps.create(0, 0)})
      sceneObj = layer.addToScene(m.renderer)
      m.runFrame(sceneObj)
      firstX = sceneObj["tileCanvasPositions"][0].x

      m.renderer.camera.position.x += 20
      m.runFrame(sceneObj)
      secondX = sceneObj["tileCanvasPositions"][0].x

      m.assertEqual(firstX, secondX)
    end function

    @it("factor {0.5,0.5} moves at half the camera's own movement")
    function _()
      m.entity.position = BGE.Math.VectorOps.create(100, 50, 0)
      layer = m.newLayer({repeatX: false, repeatY: false, parallaxFactor: BGE.Math.VectorOps.create(0.5, 0.5)})
      sceneObj = layer.addToScene(m.renderer)
      m.runFrame(sceneObj)
      firstX = sceneObj["tileCanvasPositions"][0].x

      m.renderer.camera.position.x += 20
      m.runFrame(sceneObj)
      secondX = sceneObj["tileCanvasPositions"][0].x

      m.assertEqual(firstX - 10.0, secondX)
    end function

    @it("factor > 1 (a foreground layer) moves faster than the camera's own movement")
    function _()
      m.entity.position = BGE.Math.VectorOps.create(100, 50, 0)
      layer = m.newLayer({repeatX: false, repeatY: false, parallaxFactor: BGE.Math.VectorOps.create(1.5, 1.5)})
      sceneObj = layer.addToScene(m.renderer)
      m.runFrame(sceneObj)
      firstX = sceneObj["tileCanvasPositions"][0].x

      m.renderer.camera.position.x += 20
      m.runFrame(sceneObj)
      secondX = sceneObj["tileCanvasPositions"][0].x

      m.assertEqual(firstX - 30.0, secondX)
    end function

    @it("x and y factors are independent")
    function _()
      m.entity.position = BGE.Math.VectorOps.create(100, 50, 0)
      layer = m.newLayer({repeatX: false, repeatY: false, parallaxFactor: BGE.Math.VectorOps.create(0, 1)})
      sceneObj = layer.addToScene(m.renderer)
      m.runFrame(sceneObj)
      first = sceneObj["tileCanvasPositions"][0]

      m.renderer.camera.position.x += 20
      m.renderer.camera.position.y += 20
      m.runFrame(sceneObj)
      second = sceneObj["tileCanvasPositions"][0]

      m.assertEqual(first.x, second.x) ' factor 0 on x - pinned
      ' Camera2d's y axis is inverted relative to world space (canvas y increases
      ' downward, world y increases upward), so ordinary (factor 1) scrolling moves
      ' canvas y in the SAME direction as the camera's own world-y movement - the
      ' opposite sign relationship from x. This is pre-existing Camera2d behavior
      ' (see worldPointToCanvasPoint), not something specific to parallax.
      m.assertEqual(first.y + 20, second.y) ' factor 1 on y - ordinary scrolling
    end function
```

- [ ] **Step 2: Run to verify they fail or pass**

Run: `npm run build-tests && node scripts/run-tests-ci.js`
Expected: PASS already, if Task 2's formula is implemented correctly (it should be — this task exists to prove it, not to add code). If any of these fail, the bug is in Task 2's `findCanvasPosition` math (check the `inverseFactor`/`shift`/`effective` computation against the design spec's formula before changing anything else).

- [ ] **Step 3: Commit**

```bash
git add src/source/engine/renderer/sceneObjects/SceneObjectParallaxLayer.spec.bs
git commit -m "Add parallax-factor coverage for SceneObjectParallaxLayer"
```

---

### Task 4: Tiling (`repeatX`/`repeatY`)

**Files:**
- Modify: `src/source/engine/renderer/sceneObjects/SceneObjectParallaxLayer.bs` (replace `computeTilePositions`)
- Modify: `src/source/engine/renderer/sceneObjects/SceneObjectParallaxLayer.spec.bs`

**Interfaces:**
- Produces: `computeTilePositions(basePos as BGE.Math.Vector, frameSize as BGE.Math.Vector) as BGE.Math.Vector[]` now honors `m.drawable.repeatX`/`repeatY` and `m.drawable.region`'s size (scaled by `m.drawable.scale`).

- [ ] **Step 1: Write the failing tests**

```brightscript
    @describe("tiling (repeatX/repeatY)")

    @it("draws a single tile when neither repeatX nor repeatY is set")
    function _()
      layer = m.newLayer({repeatX: false, repeatY: false})
      sceneObj = layer.addToScene(m.renderer)
      m.runFrame(sceneObj)
      m.assertEqual(1, sceneObj["tileCanvasPositions"].count())
    end function

    @it("repeatX covers the full viewport width with enough tiles, including the safety tile")
    function _()
      ' region is 32px wide, canvas (frameSize) is 200px wide: ceil(200/32) + 1 = 8 tiles.
      layer = m.newLayer({repeatX: true, repeatY: false})
      sceneObj = layer.addToScene(m.renderer)
      m.runFrame(sceneObj)
      m.assertEqual(8, sceneObj["tileCanvasPositions"].count())
    end function

    @it("repeatX tile positions are tileWidth apart and the leftmost one is <= 0")
    function _()
      layer = m.newLayer({repeatX: true, repeatY: false})
      sceneObj = layer.addToScene(m.renderer)
      m.runFrame(sceneObj)
      positions = sceneObj["tileCanvasPositions"]
      m.assertTrue(positions[0].x <= 0)
      m.assertEqual(positions[0].x + 32.0, positions[1].x)
    end function

    @it("repeatX and repeatY together tile in a full grid")
    function _()
      ' 200/32 -> 8 tiles wide, 100/24 -> ceil(100/24)+1 = 6 tiles tall. 8 * 6 = 48.
      layer = m.newLayer({repeatX: true, repeatY: true})
      sceneObj = layer.addToScene(m.renderer)
      m.runFrame(sceneObj)
      m.assertEqual(48, sceneObj["tileCanvasPositions"].count())
    end function

    @it("draws one renderer draw call per tile")
    function _()
      ' The +1 safety-margin tile in computeAxisTilePositions is only ever fully needed
      ' at one specific phase (wrapped close to -tileSize) - at most other phases,
      ' including wrapped = 0 (the default entity position used elsewhere in this file),
      ' the last computed tile lands entirely off-canvas and doesn't produce a draw
      ' call, which would make this assertion phase-dependent rather than a real test
      ' of "every computed tile draws". Position.x = 4 puts wrapped at -28 (worked out
      ' by hand: wrapped = basePos.x - tileWidth * Fix(basePos.x / tileWidth), then
      ' subtract tileWidth since it's > 0 -> 4 - 32 = -28), the phase where all 8
      ' computed tiles genuinely overlap the 200px canvas.
      m.entity.position = BGE.Math.VectorOps.create(4, 0, 0)
      layer = m.newLayer({repeatX: true, repeatY: false})
      sceneObj = layer.addToScene(m.renderer)
      m.renderer.setupCameraForFrame()
      m.entity.updateTransformationMatrix()
      sceneObj.update(m.renderer.camera)
      m.renderer.resetDrawCallCounter()
      sceneObj.draw(m.renderer)
      m.assertEqual(8, m.renderer.getDrawCallsLastFrame())
    end function
```

- [ ] **Step 2: Run to verify they fail**

Run: `npm run build-tests && node scripts/run-tests-ci.js`
Expected: FAIL (still only ever returns `[basePos]`, a single tile).

- [ ] **Step 3: Implement full tiling in `computeTilePositions`**

```brightscript
    private function computeTilePositions(basePos as BGE.Math.Vector, frameSize as BGE.Math.Vector) as BGE.Math.Vector[]
      tileWidth = m.drawable.getSize().width * m.drawable.scale.x
      tileHeight = m.drawable.getSize().height * m.drawable.scale.y

      xPositions = m.computeAxisTilePositions(basePos.x, frameSize.x, tileWidth, m.drawable.repeatX)
      yPositions = m.computeAxisTilePositions(basePos.y, frameSize.y, tileHeight, m.drawable.repeatY)

      positions = []
      for each y in yPositions
        for each x in xPositions
          positions.push(BGE.Math.VectorOps.create(x, y))
        end for
      end for
      return positions
    end function

    ' The tile start positions along one axis. Not repeating on this axis is the
    ' zero-tiling-cost special case: a single position, exactly basePos.
    '
    ' @param {float} basePos - this axis's un-tiled canvas position
    ' @param {float} viewportSize - the canvas size along this axis
    ' @param {float} tileSize - the tile's on-screen size along this axis
    ' @param {boolean} repeat
    ' @return {float[]} tile start positions, left-to-right / top-to-bottom
    private function computeAxisTilePositions(basePos as float, viewportSize as float, tileSize as float, repeat as boolean) as float[]
      if not repeat or tileSize <= 0
        return [basePos]
      end if

      ' Float-safe remainder (BrightScript's MOD truncates to integers, which would throw
      ' away sub-pixel precision) - wrapped lands in (-tileSize, 0] so the leftmost/topmost
      ' visible tile is always at or before the viewport edge.
      wrapped = basePos - tileSize * Fix(basePos / tileSize)
      if wrapped > 0
        wrapped = wrapped - tileSize
      end if

      ' Fix() truncates toward zero, not floor - -Fix(-x) only equals ceil(x) for
      ' negative x, not positive. Int() is a true floor (rounds toward negative
      ' infinity), so -Int(-x) correctly gives ceil(x) here since viewportSize/tileSize
      ' is always positive.
      tileCount = -Int(-viewportSize / tileSize) + 1 ' ceil(viewportSize / tileSize) + 1
      positions = []
      for i = 0 to tileCount - 1
        positions.push(wrapped + i * tileSize)
      end for
      return positions
    end function
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `npm run build-tests && node scripts/run-tests-ci.js`
Expected: all `SceneObjectParallaxLayer` tests PASS.

- [ ] **Step 5: Commit**

```bash
git add src/source/engine/renderer/sceneObjects/SceneObjectParallaxLayer.bs src/source/engine/renderer/sceneObjects/SceneObjectParallaxLayer.spec.bs
git commit -m "Implement repeatX/repeatY tiling for SceneObjectParallaxLayer"
```

---

### Task 5: Sub-pixel accumulation regression test

**Files:**
- Modify: `src/source/engine/renderer/sceneObjects/SceneObjectParallaxLayer.spec.bs`

No production code changes expected (per the design spec, this already falls out of keeping `effective` in float world-space and letting `Camera2d.worldPointToCanvasPoint()`'s own `fix()` be the only rounding step) — this task exists purely to prove it, since a regression here (e.g. someone later adding a `cint()` inside `findCanvasPosition` "to be safe") would be an easy, silent visual bug (slow layers stuttering) that no other test catches.

**Interfaces:**
- Consumes: everything from Tasks 2-4, unchanged.

- [ ] **Step 1: Write the failing test**

```brightscript
    @describe("sub-pixel accumulation - no premature rounding")

    @it("several small camera moves land at the same canvas position as one equivalent big move")
    function _()
      m.entity.position = BGE.Math.VectorOps.create(100, 50, 0)
      ' A small factor so a whole-pixel camera move is still a fractional shift here -
      ' 0.9 factor means a 10px camera move is only a 1px shift, easy to lose to
      ' premature rounding if it happened before the final canvas conversion.
      layerA = m.newLayer({repeatX: false, repeatY: false, parallaxFactor: BGE.Math.VectorOps.create(0.9, 0.9)})
      sceneObjA = layerA.addToScene(m.renderer)
      m.runFrame(sceneObjA)

      for i = 1 to 10
        m.renderer.camera.position.x += 1
        m.runFrame(sceneObjA)
      end for
      accumulatedX = sceneObjA["tileCanvasPositions"][0].x

      ' A second, independent layer/entity pair that takes the same total 10px camera
      ' move in one step instead of ten 1px steps.
      entityB = new BGE.GameEntity(m.game, {name: "TestEntityB"})
      entityB.position = BGE.Math.VectorOps.create(100, 50, 0)
      layerB = new BGE.DrawableParallaxLayer(entityB, m.newRegion(), {repeatX: false, repeatY: false, parallaxFactor: BGE.Math.VectorOps.create(0.9, 0.9)})
      sceneObjB = layerB.addToScene(m.renderer)
      m.renderer.camera.position.x -= 10 ' reset camera back to its starting position
      m.runFrame(sceneObjB)
      m.renderer.camera.position.x += 10
      entityB.updateTransformationMatrix()
      sceneObjB.update(m.renderer.camera)
      sceneObjB.draw(m.renderer)
      oneStepX = sceneObjB["tileCanvasPositions"][0].x

      m.assertEqual(oneStepX, accumulatedX)
    end function
```

- [ ] **Step 2: Run to verify it passes**

Run: `npm run build-tests && node scripts/run-tests-ci.js`
Expected: PASS. If it fails, look for any `cint()`/`fix()`/`Int()` call inside `findCanvasPosition()` or `computeTilePositions()` before the final `rendererObj.worldPointToCanvasPoint()` call — that's the bug this test exists to catch.

- [ ] **Step 3: Commit**

```bash
git add src/source/engine/renderer/sceneObjects/SceneObjectParallaxLayer.spec.bs
git commit -m "Add sub-pixel accumulation regression test for SceneObjectParallaxLayer"
```

---

### Task 6: Docs update

**Files:**
- Modify: `docs/drawables-and-scene-objects.md`

**Interfaces:** none (documentation only).

- [ ] **Step 1: Add a row to the "Every Drawable / SceneObject pair" table**

In `docs/drawables-and-scene-objects.md`, add a row after the `DrawablePlane` row (around line 33):

```markdown
| `DrawableParallaxLayer` | `SceneObjectParallaxLayer` | A scrolling/tiling background (or foreground) layer that moves at a configurable fraction of the camera's movement. |
```

- [ ] **Step 2: Add a short new section**

After the `## Deep dive: SceneObjectPlane` section (end of file), add:

```markdown
## Parallax layers (`DrawableParallaxLayer`)

`DrawableParallaxLayer` scrolls a bitmap at a configurable per-axis fraction of the
camera's movement (`parallaxFactor`, a `BGE.Math.Vector`): `{1,1}` (the default) behaves
like an ordinary drawable, `{0,0}` pins it to the camera, `0 < factor < 1` gives a
background layer that drifts slower than the world, and `factor > 1` gives a foreground
layer that scrolls faster. `repeatX`/`repeatY` (defaulting to `true`/`false`) tile the
bitmap to cover the viewport along either axis.

Unlike every other billboard drawable, `SceneObjectParallaxLayer` extends `SceneObject`
directly rather than `SceneObjectBillboard` - a parallax layer is always flat 2D and may
draw several tiled copies in a single frame, so it skips the 3D/orientation/temp-bitmap
machinery entirely and just issues one `Renderer.drawObject()`/`drawScaledObject()` call
per visible tile.

All of the parallax math and tile enumeration live in one overridden
`findCanvasPosition()` - the base `SceneObject.draw()`'s existing
`objMovedInRelationToCamera()` check already re-triggers it whenever the camera moves
(its default implementation already ORs in `cameraObj.movedLastFrame()`), so no change to
the shared `SceneObject`/`Drawable` update machinery was needed to make a parallax layer
stay live as the camera pans.

Draw order relies entirely on the ordinary distance-from-camera sort - give a background
layer's owning entity a suitably negative Z (or positive, for a foreground layer) so it
falls out of `Renderer.drawScene()`'s existing sort with no renderer changes.
```

- [ ] **Step 3: Commit**

```bash
git add docs/drawables-and-scene-objects.md
git commit -m "Document DrawableParallaxLayer/SceneObjectParallaxLayer"
```

---

### Task 7: `examples/parallax`

**Files:**
- Create (scaffolded): `examples/parallax/` via `npm run create-example -- parallax "Parallax Example"`
- Modify: `examples/parallax/src/source/main.bs`
- Create: `examples/parallax/src/source/Entities/Player.bs`
- Modify: `examples/parallax/src/source/Rooms/MainRoom.bs`
- Create: `examples/parallax/src/source/BackgroundArt.bs` (procedural bitmap painters)

**Interfaces:**
- Consumes: `BGE.DrawableParallaxLayer` (Tasks 1-4), `BGE.Game`, `BGE.Room`, `BGE.GameEntity`, `BGE.Camera2d.setTarget`, `BGE.Renderer` (used one-off inside `onCreate` purely to paint the procedural art bitmaps - see below).

- [ ] **Step 1: Scaffold the example**

Run: `npm run create-example -- parallax "Parallax Example"`
Expected: `examples/parallax/` created with manifest/bsconfig/icons and a minimal `MainRoom`, registered in the root `.vscode/tasks.json` example picker.

- [ ] **Step 2: Write the procedural background-art helper**

```brightscript
' examples/parallax/src/source/BackgroundArt.bs

' Paints a small tileable "mountains" bitmap using the engine's own Renderer (a scratch
' Renderer over a fresh roBitmap, used here only to paint an asset - not part of the
' example's actual game-time rendering). No external image assets needed. Renderer.drawRectangle/
' drawPolygon and the BGE.Colors enum (both in src/source/engine/renderer/Renderer.bs and
' src/source/utils/colors.bs respectively) only have a fixed small palette - Black, White,
' Red, Lime, Blue, Yellow, Cyan, Aqua, Magenta, Pink, Fuchsia, Silver, Gray, Grey, Maroon,
' Olive, Green, Purple, Teal, Navy - so this uses only those, not invented names.
function paintMountainsTile(width as integer, height as integer) as roBitmap
  bmp = CreateObject("roBitmap", {width: width, height: height, alphaEnable: true})
  renderer = new BGE.Renderer(bmp)
  renderer.drawRectangle(0, 0, width, height, BGE.Colors.Blue)
  renderer.drawPolygon([
    BGE.Math.VectorOps.create(0, height * 0.4),
    BGE.Math.VectorOps.create(width * 0.3, height * 0.85),
    BGE.Math.VectorOps.create(width * 0.6, height * 0.5),
    BGE.Math.VectorOps.create(width, height * 0.9),
    BGE.Math.VectorOps.create(width, height),
    BGE.Math.VectorOps.create(0, height)
  ], 0, 0, BGE.Colors.Gray)
  return bmp
end function

' A closer, lower "hills" tile - a rounder, flatter polygon silhouette than the mountains
' tile, same technique.
function paintHillsTile(width as integer, height as integer) as roBitmap
  bmp = CreateObject("roBitmap", {width: width, height: height, alphaEnable: true})
  renderer = new BGE.Renderer(bmp)
  renderer.drawPolygon([
    BGE.Math.VectorOps.create(0, height * 0.75),
    BGE.Math.VectorOps.create(width * 0.25, height * 0.55),
    BGE.Math.VectorOps.create(width * 0.5, height * 0.7),
    BGE.Math.VectorOps.create(width * 0.75, height * 0.5),
    BGE.Math.VectorOps.create(width, height * 0.65),
    BGE.Math.VectorOps.create(width, height),
    BGE.Math.VectorOps.create(0, height)
  ], 0, 0, BGE.Colors.Green)
  return bmp
end function

' A single foreground silhouette tile - drawn dark so it reads as a foreground element in
' front of the player, per the DrawableParallaxLayer demo of factor > 1.
function paintForegroundTile(width as integer, height as integer) as roBitmap
  bmp = CreateObject("roBitmap", {width: width, height: height, alphaEnable: true})
  renderer = new BGE.Renderer(bmp)
  renderer.drawRectangle(0, height * 0.75, width * 0.15, height * 0.25, BGE.Colors.Black)
  renderer.drawRectangle(width * 0.6, height * 0.7, width * 0.15, height * 0.3, BGE.Colors.Black)
  return bmp
end function
```

`Renderer.drawRectangle(x, y, width, height, rgba)` and `Renderer.drawPolygon(points, x, y, rgba, allowQuickDraw = false)` already exist in `src/source/engine/renderer/Renderer.bs` (signatures confirmed while writing this plan) - `x`/`y` in `drawPolygon` are an additional offset added to every point, `0, 0` here since the polygon points above are already in tile-local coordinates.

- [ ] **Step 3: Write `Player.bs`**

Following this repo's own `onInput`/world-space convention (`input.y: 1` is up, matching
every existing example that does `velocity.y = input.y * speed`):

```brightscript
' examples/parallax/src/source/Entities/Player.bs
class Player extends BGE.GameEntity

  speed as float = 150.0

  sub new(game as BGE.Game)
    super(game, {name: "Player"})
    ' DrawableRectangle.color is packed RGB (BGE.ColorsRGB), not the RGBA BGE.Colors used
    ' by the raw Renderer.draw* calls in BackgroundArt.bs above - easy to mix up, see
    ' CLAUDE.md's note on the two color formats.
    m.addDrawable("body", new BGE.DrawableRectangle(m, 20, 20, {color: BGE.ColorsRGB.White}))
  end sub

  override sub onInput(input as BGE.GameInput)
    m.velocity.x = input.x * m.speed
    m.velocity.y = input.y * m.speed
  end sub

end class
```

- [ ] **Step 4: Write `MainRoom.bs`**

```brightscript
' examples/parallax/src/source/Rooms/MainRoom.bs
class MainRoom extends BGE.Room

  player as Player

  sub new(game as BGE.Game)
    super(game)
    m.name = "MainRoom"
  end sub

  override sub onCreate(args as roAssociativeArray)
    m.player = new Player(m.game)
    m.player.position = BGE.Math.VectorOps.create(m.game.canvas.getWidth() * 0.5, m.game.canvas.getHeight() * 0.5, 0)
    m.game.addEntity(m.player)

    background = new BGE.GameEntity(m.game, {name: "Background"})
    background.position = BGE.Math.VectorOps.create(m.player.position.x, m.player.position.y, -500)
    m.game.addEntity(background)

    tileWidth = m.game.canvas.getWidth()
    tileHeight = m.game.canvas.getHeight()

    mountainsRegion = CreateObject("roRegion", paintMountainsTile(tileWidth, tileHeight), 0, 0, tileWidth, tileHeight)
    mountains = new BGE.DrawableParallaxLayer(background, mountainsRegion, {
      parallaxFactor: BGE.Math.VectorOps.create(0.2, 0.05),
      repeatX: true,
      repeatY: false
    })
    background.addDrawable("mountains", mountains)

    hillsRegion = CreateObject("roRegion", paintHillsTile(tileWidth, tileHeight), 0, 0, tileWidth, tileHeight)
    hills = new BGE.DrawableParallaxLayer(background, hillsRegion, {
      offset: BGE.Math.VectorOps.create(0, 0, 100),
      parallaxFactor: BGE.Math.VectorOps.create(0.5, 0.1),
      repeatX: true,
      repeatY: false
    })
    background.addDrawable("hills", hills)

    foregroundEntity = new BGE.GameEntity(m.game, {name: "Foreground"})
    foregroundEntity.position = BGE.Math.VectorOps.create(m.player.position.x, m.player.position.y, 500)
    m.game.addEntity(foregroundEntity)
    foregroundRegion = CreateObject("roRegion", paintForegroundTile(tileWidth, tileHeight), 0, 0, tileWidth, tileHeight)
    foreground = new BGE.DrawableParallaxLayer(foregroundEntity, foregroundRegion, {
      parallaxFactor: BGE.Math.VectorOps.create(1.3, 1.3),
      repeatX: true,
      repeatY: false
    })
    foregroundEntity.addDrawable("foreground", foreground)
  end sub

  override sub onUpdate(dt as float)
    m.game.canvas.renderer.camera.setTarget(m.player.position)
  end sub

  override sub onInput(input as BGE.GameInput)
    if input.isButton("back")
      m.game.End()
    end if
  end sub

end class
```

- [ ] **Step 5: Wire up `main.bs`**

Confirm `examples/parallax/src/source/main.bs` (scaffolded by `create-example`) matches the standard template (construct `BGE.Game`, `game.fitCanvasToScreen()`, define/change to `MainRoom`, `game.play()`) - no changes needed if `create-example` already produced this.

- [ ] **Step 6: Build and validate**

Run: `cd examples/parallax && npm install && npm run build`
Expected: builds clean. Fix any compile errors (likely candidates: exact `BGE.Colors`/named-color mismatches from Step 2 - grep `src/source/utils/colors.bs` for the real names and substitute).

- [ ] **Step 7: Verify on-device via `rokubot`**

Per this repo's `rokubot-examples` skill: `npm run package` in `examples/parallax`, sideload the zip, launch, and screenshot. Press each direction to confirm:
- The player entity moves and the camera follows it (`setTarget`).
- The three layers scroll at visibly different rates (mountains slowest, hills faster, foreground fastest and in front of the player).
- `repeatX` tiling has no visible seam/gap as the player moves far in either direction.

- [ ] **Step 8: Commit**

```bash
git add examples/parallax .vscode/tasks.json
git commit -m "Add examples/parallax demonstrating DrawableParallaxLayer with camera follow"
```

---

### Task 8: Final quality gate and PR

**Files:** none (verification only).

- [ ] **Step 1: Run the full quality gate**

Run: `npm run check` (lint + validate + headless tests)
Expected: clean.

- [ ] **Step 2: Run `npm run check:all`**

Run: `npm run check:all` (adds validating every example, including the new `examples/parallax`)
Expected: clean.

- [ ] **Step 3: Push and open the PR**

```bash
git push origin feature/parallax-layers-v2:feature/parallax-layers-v2
```

Then `gh pr create` (or update the existing PR #87, which currently holds just the design
spec commit - this plan's commits land on the same branch/PR) referencing issue #67.
