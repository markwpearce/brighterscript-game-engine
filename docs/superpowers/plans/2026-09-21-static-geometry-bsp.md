# Static Geometry BSP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give static, never-moving flat-quad geometry (walls, props) correct draw order against dynamic objects that spatially sit between/behind/in-front of it, fixing the case a whole-object painter's sort can't represent (a ball between a room's near and far wall).

**Architecture:** A `GameEntity.isStatic` flag marks an entity's drawables as static. Eligible `SceneObject`s (currently `SceneObjectImage`/`SceneObjectRectangle` only - see `isEligibleForStaticBsp()`) build a classification-only BSP tree once (lazily, on registration/removal), keyed off each quad's world-space center/normal. Each frame, `Renderer` walks that tree back-to-front relative to the camera, classifying every dynamic (non-static) `SceneObject` against each node's plane and drawing it at the matching point in the walk instead of a single global sort. No polygon splitting - see the spec for why that's out of scope. A renderer with no static geometry takes exactly today's code path, unchanged.

**Tech Stack:** BrighterScript (`.bs`), Rooibos v6 unit tests (`*.spec.bs`), `brs-cli` headless test runner.

**Spec:** [specs/2026-09-21-static-geometry-bsp-design.md](../../../specs/2026-09-21-static-geometry-bsp-design.md)

## Global Constraints

- No `new`/class instantiation inside the per-frame traversal path - plain arrays/AAs only.
- v1 static-eligible types: `SceneObjectImage`, `SceneObjectRectangle` only (not `SceneObjectModel`/`SceneObjectCircle`/`SceneObjectPolygon`/`SceneObjectText`/`SceneObjectPlane`).
- No true polygon splitting between two static quads - classification only.
- A renderer that never registers static geometry must produce byte-identical draw order to today's code (zero-static fallback).
- `Drawable.owner` can legitimately be `invalid` (see `examples/rendererTest`'s `SkyboxTest.bs`) - every new code path touching `sceneObj.drawable.owner` must null-check it first.
- Run `npm run validate` after adding the new `BGE.BSP` namespace file, specifically to catch the bsc same-file-self-reference symbol corruption bug documented in `CLAUDE.md` (a free function/interface referencing a type from the same file has bitten this codebase twice already).

---

### Task 1: `GameEntity.isStatic` flag

**Files:**
- Modify: `src/source/engine/GameEntity.bs:49` (right after the `pauseable` field)
- Test: `src/source/engine/GameEntity.spec.bs`

**Interfaces:**
- Produces: `GameEntity.isStatic as boolean` (default `false`) - read by `Renderer.addSceneObject()` in Task 4.

- [ ] **Step 1: Write the failing test**

Add to `src/source/engine/GameEntity.spec.bs`, in a new `@describe` block (place after the existing `isValid / invalidate` block):

```brightscript
    @describe("isStatic")

    @it("defaults to false")
    function _()
      m.assertFalse(m.entity.isStatic)
    end function
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm run build-tests && npm run test:ci`
Expected: FAIL - `isStatic` is not a member of `GameEntity` (compile error from `build-tests`, since the field doesn't exist yet).

- [ ] **Step 3: Add the field**

In `src/source/engine/GameEntity.bs`, after line 49 (`pauseable as boolean = true`):

```brightscript
    ' Does this entity persist across room changes?
    persistent as boolean = false
    ' When the game is paused, does this entity pause too?
    pauseable as boolean = true
    ' Marks this entity's drawables as static geometry (walls, props) that never moves
    ' after its drawables are added to a renderer. Static-eligible drawables (see
    ' BGE.SceneObject.isEligibleForStaticBsp()) get correct draw order against dynamic
    ' objects that spatially sit between/behind/in-front of them - something a single
    ' painter's-sort scalar per object can't represent (a ball between a room's near and
    ' far wall). Set this before the entity's drawables are added (i.e. at the top of
    ' onCreate()) - changing position/rotation/scale afterward logs a warning and forces
    ' a tree rebuild rather than being silently wrong (see SceneObject.update()).
    isStatic as boolean = false
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npm run build-tests && npm run test:ci`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add src/source/engine/GameEntity.bs src/source/engine/GameEntity.spec.bs
git commit -m "Add GameEntity.isStatic flag for static geometry (#107)"
```

---

### Task 2: `SceneObject` static eligibility, world-plane access, and misuse detection

**Files:**
- Modify: `src/source/engine/renderer/sceneObjects/SceneObject.bs`
- Modify: `src/source/engine/renderer/sceneObjects/SceneObjectBillboard.bs`
- Modify: `src/source/engine/renderer/sceneObjects/SceneObjectImage.bs`
- Modify: `src/source/engine/renderer/sceneObjects/SceneObjectRectangle.bs`
- Test: `src/source/engine/renderer/sceneObjects/SceneObject.spec.bs` (create if it doesn't already exist - check first)

**Interfaces:**
- Consumes: `Drawable.movedLastFrame(includeOwner as boolean) as boolean` (existing, `Drawable.bs:186`), `Drawable.owner.game.log(message as string, level as BGE.Debug.LogLevel)` (existing, `Game.bs:1609`).
- Produces: `SceneObject.isStatic as boolean` (default `false`, set externally by `Renderer` in Task 4 - not by this task), `SceneObject.isEligibleForStaticBsp() as boolean` (default `false`), `SceneObject.getWorldPoints() as BGE.Math.CornerPoints` (default `invalid`, overridden on `SceneObjectBillboard` to return `m.worldPoints`), `SceneObject.staticGeometryMovedThisFrame as boolean` (set inside `update()`, read by `Renderer.updateSceneObjects()` in Task 4).

First, check whether a spec file already exists for `SceneObject`:

```bash
ls src/source/engine/renderer/sceneObjects/SceneObject.spec.bs 2>/dev/null || echo "none yet"
```

If it doesn't exist, create it using the pattern below (mirroring `GameEntity.spec.bs`'s real-`Game`-construction style, since `SceneObject.update()`'s misuse check needs a real `Drawable`/`GameEntity`/`Game` chain to log through). If it does exist, add the `@describe` blocks below into it instead of creating a new file.

- [ ] **Step 1: Write the failing tests**

```brightscript
namespace tests

  @suite("BGE.SceneObject - static geometry")
  class SceneObjectStaticTests extends rooibos.BaseTestSuite

    game as BGE.Game
    entity as BGE.GameEntity

    protected override function beforeEach()
      m.game = new BGE.Game(320, 240)
      m.entity = new BGE.GameEntity(m.game, {name: "TestEntity"})
    end function

    @describe("isEligibleForStaticBsp")

    @it("is false for the base SceneObject default")
    function _()
      drawable = m.entity.addRectangle("plainRect", 10, 10)
      sceneObj = drawable.getSceneObjects()[0]
      m.assertFalse(sceneObj.isEligibleForStaticBsp())
    end function

    @describe("getWorldPoints")

    @it("returns non-invalid CornerPoints for a SceneObjectRectangle (SceneObjectBillboard override)")
    function _()
      rectDrawable = m.entity.addRectangle("plainRect2", 10, 10)
      rectSceneObj = rectDrawable.getSceneObjects()[0]
      m.assertNotInvalid(rectSceneObj.getWorldPoints())
    end function

    @describe("static misuse detection")

    @it("logs nothing and does not flag movement on the first update")
    function _()
      drawable = m.entity.addRectangle("wall", 50, 50)
      sceneObj = drawable.getSceneObjects()[0]
      sceneObj.isStatic = true
      sceneObj.update(m.game.canvas.renderer.camera)
      m.assertFalse(sceneObj.staticGeometryMovedThisFrame)
    end function

    @it("flags movement and logs a warning once the entity moves after being marked static")
    function _()
      drawable = m.entity.addRectangle("wall", 50, 50)
      sceneObj = drawable.getSceneObjects()[0]
      sceneObj.isStatic = true
      camera = m.game.canvas.renderer.camera
      sceneObj.update(camera) ' first update - settles the motion checker, no flag
      m.entity.position = BGE.Math.VectorOps.create(500, 0, 0)
      sceneObj.update(camera)
      m.assertTrue(sceneObj.staticGeometryMovedThisFrame)
      logHistory = m.game.getLogHistory()
      lastEntry = logHistory[logHistory.count() - 1]
      m.assertEqual(BGE.Debug.LogLevel.warning, lastEntry.level)
    end function

    @it("only logs the warning once across repeated moves")
    function _()
      drawable = m.entity.addRectangle("wall", 50, 50)
      sceneObj = drawable.getSceneObjects()[0]
      sceneObj.isStatic = true
      camera = m.game.canvas.renderer.camera
      sceneObj.update(camera)
      m.entity.position = BGE.Math.VectorOps.create(500, 0, 0)
      sceneObj.update(camera)
      countAfterFirstMove = m.game.getLogHistory().count()
      m.entity.position = BGE.Math.VectorOps.create(600, 0, 0)
      sceneObj.update(camera)
      m.assertEqual(countAfterFirstMove, m.game.getLogHistory().count())
    end function

  end class

end namespace
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `npm run build-tests && npm run test:ci`
Expected: FAIL - `isEligibleForStaticBsp`, `getWorldPoints` (on the base type), `isStatic`, and `staticGeometryMovedThisFrame` are not members of `SceneObject` yet.

- [ ] **Step 3: Implement on `SceneObject`**

In `src/source/engine/renderer/sceneObjects/SceneObject.bs`, add fields near the other `protected`/public state (after `stableSortKey`/`lastSortIndex`, around line 210):

```brightscript
    ' Set by Renderer when this object's owning entity is marked GameEntity.isStatic and
    ' this object's concrete type supports static BSP (isEligibleForStaticBsp()). Not
    ' meant to be set directly by game code - see Renderer.markStatic().
    isStatic as boolean = false

    ' True for exactly the frame Renderer.updateSceneObjects() should mark the static
    ' geometry tree dirty because a static-flagged object's transform changed after
    ' registration - see update()'s misuse-detection block.
    staticGeometryMovedThisFrame as boolean = false

    ' Whether update() has completed at least one prior frame for this object - guards
    ' the misuse check below from firing on the object's very first update, where
    ' MotionChecker always reports "moved" simply because it has no previous transform
    ' to compare against yet (see MotionChecker.check()'s invalid-previousTransform case).
    protected staticCheckArmed as boolean = false

    ' Whether the one-time misuse warning has already been logged for this object -
    ' keeps a static entity that's actually moving every frame (fully broken usage) from
    ' spamming the log.
    protected staticWarningLogged as boolean = false
```

Add near `participatesInOverlapDetection()` (after it, around line 574):

```brightscript
    ' Whether this concrete SceneObject type's geometry can be represented as a single
    ' flat quad usable by the static geometry BSP tree (see BGE.BSP and
    ' Renderer.buildStaticGeometryTree()). False by default - override true only for a
    ' type whose getWorldPoints() exactly matches its drawn fill geometry (currently
    ' SceneObjectImage and SceneObjectRectangle; not SceneObjectModel/SceneObjectCircle/
    ' SceneObjectPolygon/SceneObjectText, whose world corners are a bounding proxy, not
    ' their actual silhouette).
    '
    ' @return {boolean}
    function isEligibleForStaticBsp() as boolean
      return false
    end function

    ' This object's world-space quad corners, if it has any - invalid for a type that
    ' isn't built from a single flat quad. Overridden on SceneObjectBillboard (the shared
    ' base for every quad-shaped SceneObject) to return its computed worldPoints.
    '
    ' @return {BGE.Math.CornerPoints}
    function getWorldPoints() as BGE.Math.CornerPoints
      return invalid
    end function
```

Modify `update()` (around line 253) to add the misuse check right after `objMovedLastFrame` is computed:

```brightscript
    sub update(cameraObj as Camera)
      objMovedLastFrame = m.drawable.movedLastFrame(true)
      m.staticGeometryMovedThisFrame = false
      if m.isStatic and objMovedLastFrame and m.staticCheckArmed
        m.staticGeometryMovedThisFrame = true
        if not m.staticWarningLogged and m.drawable.owner <> invalid
          m.drawable.owner.game.log("GameEntity '" + m.drawable.owner.name + "' is marked isStatic but its position/rotation/scale changed after its drawables were registered - the static geometry tree will be rebuilt, but isStatic entities should never move after registration", BGE.Debug.LogLevel.warning)
          m.staticWarningLogged = true
        end if
      end if
      m.staticCheckArmed = true
      m.isFirstFrameSinceEnabled = (m.isEnabled() and not m.wasEnabledLastFrame)
```

(Leave the rest of `update()` unchanged - only the new block above `m.isFirstFrameSinceEnabled` is added.)

- [ ] **Step 4: Add the `override` and the `SceneObjectImage`/`SceneObjectRectangle` eligibility overrides**

In `src/source/engine/renderer/sceneObjects/SceneObjectBillboard.bs`, find the existing `getWorldPoints()` method (around line 682) and add `override`:

```brightscript
    ' The world-space corner points this billboard's oriented draw modes last computed.
    '
    ' @return {BGE.Math.CornerPoints}
    override function getWorldPoints() as BGE.Math.CornerPoints
      return m.worldPoints
    end function
```

In `src/source/engine/renderer/sceneObjects/SceneObjectImage.bs`, add inside the class body:

```brightscript
    ' A plain image is a single flat textured quad whose worldPoints exactly match its
    ' drawn fill - eligible for the static geometry BSP tree (issue #107).
    '
    ' @return {boolean}
    override function isEligibleForStaticBsp() as boolean
      return true
    end function
```

In `src/source/engine/renderer/sceneObjects/SceneObjectRectangle.bs`, add inside the class body:

```brightscript
    ' A rectangle is a single flat quad whose worldPoints exactly match its drawn fill -
    ' eligible for the static geometry BSP tree (issue #107).
    '
    ' @return {boolean}
    override function isEligibleForStaticBsp() as boolean
      return true
    end function
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `npm run build-tests && npm run test:ci`
Expected: PASS

- [ ] **Step 6: Run the full validation gate**

Run: `npm run validate`
Expected: no new diagnostics. This is the specific check called out in Global Constraints for the same-file self-reference bsc bug - `SceneObject.bs` now has a free method returning `BGE.Math.CornerPoints` (a different file's type, not self-referencing, so this file specifically isn't expected to trigger it, but running validate here catches it early regardless).

- [ ] **Step 7: Commit**

```bash
git add src/source/engine/renderer/sceneObjects/SceneObject.bs src/source/engine/renderer/sceneObjects/SceneObjectBillboard.bs src/source/engine/renderer/sceneObjects/SceneObjectImage.bs src/source/engine/renderer/sceneObjects/SceneObjectRectangle.bs src/source/engine/renderer/sceneObjects/SceneObject.spec.bs
git commit -m "Add static-BSP eligibility, world-plane access, and misuse detection to SceneObject (#107)"
```

---

### Task 3: `BGE.BSP` module - pure geometry, no `Game`/`Renderer` dependency

**Files:**
- Create: `src/source/engine/renderer/bsp/StaticGeometryBSP.bs`
- Test: `src/source/engine/renderer/bsp/StaticGeometryBSP.spec.bs`

**Interfaces:**
- Produces:
  - `interface BGE.BSP.StaticItem { sceneObj as dynamic, planePoint as BGE.Math.Vector, planeNormal as BGE.Math.Vector }`
  - `interface BGE.BSP.DynamicItem { sceneObj as dynamic, position as BGE.Math.Vector, depthKey as float }`
  - `function BGE.BSP.buildTree(items as BGE.BSP.StaticItem[]) as object` - returns `invalid` for empty input, else `{item: StaticItem, front: object or invalid, back: object or invalid}`
  - `sub BGE.BSP.collectDrawOrder(node as object, cameraPosition as BGE.Math.Vector, dynamicItems as BGE.BSP.DynamicItem[], result as dynamic[])` - appends `item.sceneObj`/`dynItem.sceneObj` payloads to `result` in back-to-front draw order.
- Consumed by: `Renderer` in Task 4 (which builds `StaticItem`/`DynamicItem` wrappers around real `SceneObject`s and unwraps `result` back into real `SceneObject`s to call `.draw()` on).

This module deliberately never touches `BGE.SceneObject`, `Renderer`, or `Game` - `sceneObj` in both interfaces is an opaque `dynamic` payload the caller supplies and gets back unchanged, so this file's tests use plain strings as payloads instead of constructing real scene objects.

- [ ] **Step 1: Write the failing tests**

```brightscript
namespace tests

  @suite("BGE.BSP")
  class StaticGeometryBSPTests extends rooibos.BaseTestSuite

    ' A quad centered at the origin, facing +Z (normal (0,0,1)) - e.g. the "far" wall
    ' of a room at z=0, room extends toward +Z.
    function planeAt(z as float, normalZ as float) as object
      return {
        planePoint: BGE.Math.VectorOps.create(0, 0, z)
        planeNormal: BGE.Math.VectorOps.create(0, 0, normalZ)
      }
    end function

    @describe("buildTree")

    @it("returns invalid for an empty item list")
    function _()
      m.assertInvalid(BGE.BSP.buildTree([]))
    end function

    @it("builds a single leaf node for one item")
    function _()
      p = m.planeAt(0, 1)
      node = BGE.BSP.buildTree([{sceneObj: "wallA", planePoint: p.planePoint, planeNormal: p.planeNormal}])
      m.assertEqual("wallA", node.item.sceneObj)
      m.assertInvalid(node.front)
      m.assertInvalid(node.back)
    end function

    @it("partitions a second item to front or back based on which side of the first item's plane it's on")
    function _()
      pivotPlane = m.planeAt(0, 1) ' plane through origin, normal +Z
      frontItem = {sceneObj: "front", planePoint: BGE.Math.VectorOps.create(0, 0, 10), planeNormal: BGE.Math.VectorOps.create(0, 0, 1)}
      backItem = {sceneObj: "back", planePoint: BGE.Math.VectorOps.create(0, 0, -10), planeNormal: BGE.Math.VectorOps.create(0, 0, 1)}
      node = BGE.BSP.buildTree([
        {sceneObj: "pivot", planePoint: pivotPlane.planePoint, planeNormal: pivotPlane.planeNormal},
        frontItem,
        backItem
      ])
      m.assertEqual("pivot", node.item.sceneObj)
      m.assertEqual("front", node.front.item.sceneObj)
      m.assertEqual("back", node.back.item.sceneObj)
    end function

    @describe("collectDrawOrder")

    @it("draws the single static item on its own")
    function _()
      p = m.planeAt(0, 1)
      node = BGE.BSP.buildTree([{sceneObj: "wall", planePoint: p.planePoint, planeNormal: p.planeNormal}])
      result = []
      BGE.BSP.collectDrawOrder(node, BGE.Math.VectorOps.create(0, 0, -100), [], result)
      m.assertEqual(1, result.count())
      m.assertEqual("wall", result[0])
    end function

    @it("draws back-to-front: farther wall first, nearer wall last, relative to the camera")
    function _()
      ' Two walls, at z=100 (far) and z=-100 (near), camera at z=-200 looking toward +Z.
      farWall = {sceneObj: "farWall", planePoint: BGE.Math.VectorOps.create(0, 0, 100), planeNormal: BGE.Math.VectorOps.create(0, 0, 1)}
      nearWall = {sceneObj: "nearWall", planePoint: BGE.Math.VectorOps.create(0, 0, -100), planeNormal: BGE.Math.VectorOps.create(0, 0, 1)}
      node = BGE.BSP.buildTree([farWall, nearWall])
      result = []
      BGE.BSP.collectDrawOrder(node, BGE.Math.VectorOps.create(0, 0, -200), [], result)
      m.assertEqual(["nearWall", "farWall"], result)
    end function

    @it("draws a dynamic object between two static planes in correct interleaved order - the ball-inside-a-box case")
    function _()
      ' Near wall at z=-100, far wall at z=100, camera at z=-200, ball at z=0 (between
      ' both walls). Expected order (back-to-front from the camera): far wall, ball, near wall.
      farWall = {sceneObj: "farWall", planePoint: BGE.Math.VectorOps.create(0, 0, 100), planeNormal: BGE.Math.VectorOps.create(0, 0, 1)}
      nearWall = {sceneObj: "nearWall", planePoint: BGE.Math.VectorOps.create(0, 0, -100), planeNormal: BGE.Math.VectorOps.create(0, 0, 1)}
      node = BGE.BSP.buildTree([farWall, nearWall])
      ball = {sceneObj: "ball", position: BGE.Math.VectorOps.create(0, 0, 0), depthKey: 0.0}
      result = []
      BGE.BSP.collectDrawOrder(node, BGE.Math.VectorOps.create(0, 0, -200), [ball], result)
      m.assertEqual(["farWall", "ball", "nearWall"], result)
    end function

    @it("sorts multiple dynamic objects at the same leaf by depthKey ascending (farthest first)")
    function _()
      farBall = {sceneObj: "farBall", position: BGE.Math.VectorOps.create(0, 0, 50), depthKey: -50.0}
      nearBall = {sceneObj: "nearBall", position: BGE.Math.VectorOps.create(0, 0, -50), depthKey: -150.0}
      result = []
      BGE.BSP.collectDrawOrder(invalid, BGE.Math.VectorOps.create(0, 0, -200), [farBall, nearBall], result)
      m.assertEqual(["nearBall", "farBall"], result)
    end function

  end class

end namespace
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `npm run build-tests && npm run test:ci`
Expected: FAIL - `BGE.BSP` namespace/functions don't exist yet.

- [ ] **Step 3: Implement**

Create `src/source/engine/renderer/bsp/StaticGeometryBSP.bs`:

```brightscript
import "../../../math/vector.bs"

namespace BGE.BSP

  ' One static quad's plane, in world space - planePoint/planeNormal come from the
  ' quad's own BGE.Math.CornerPoints.getCenter()/getNormal(). sceneObj is an opaque
  ' payload this module never inspects - the caller gets it back unchanged in
  ' collectDrawOrder()'s result.
  interface StaticItem
    sceneObj as dynamic
    planePoint as BGE.Math.Vector
    planeNormal as BGE.Math.Vector
  end interface

  ' One dynamic (non-static) object being threaded into the BSP walk. depthKey mirrors
  ' BGE.SceneObject.negDistanceFromCamera's convention (ascending = farthest from the
  ' camera first) - used only to order objects that land in the same leaf, where no more
  ' static geometry disambiguates them further.
  interface DynamicItem
    sceneObj as dynamic
    position as BGE.Math.Vector
    depthKey as float
  end interface

  ' Builds a classification-only BSP tree over static quads - no polygon splitting (see
  ' the design spec for why). Picks the first item as each node's splitting plane and
  ' partitions every other remaining item to front/back by which side of that plane its
  ' center falls on.
  '
  ' @param {BGE.BSP.StaticItem[]} items
  ' @return {object} `invalid` for an empty list, else `{item, front, back}`
  function buildTree(items as BGE.BSP.StaticItem[]) as object
    if items.count() = 0
      return invalid
    end if
    pivot = items[0]
    front = []
    back = []
    for i = 1 to items.count() - 1
      item = items[i]
      side = BGE.Math.distanceFromPlane(pivot.planePoint, pivot.planeNormal, item.planePoint)
      if side >= 0
        front.push(item)
      else
        back.push(item)
      end if
    end for
    return {
      item: pivot
      front: buildTree(front)
      back: buildTree(back)
    }
  end function

  ' Walks the tree back-to-front relative to cameraPosition, appending each static
  ' item's sceneObj payload to result in the correct draw position, with dynamicItems
  ' classified against each node's plane and interleaved at the matching point instead
  ' of being split. A leaf (node = invalid) appends its remaining dynamicItems sorted by
  ' depthKey ascending.
  '
  ' @param {object} node result of buildTree(), or invalid
  ' @param {BGE.Math.Vector} cameraPosition
  ' @param {BGE.BSP.DynamicItem[]} dynamicItems
  ' @param {dynamic[]} result appended to in draw order - not returned, so a caller can
  '   reuse one array across a partial traversal if ever needed
  sub collectDrawOrder(node as object, cameraPosition as BGE.Math.Vector, dynamicItems as BGE.BSP.DynamicItem[], result as dynamic[])
    if node = invalid
      appendLeafDynamicItems(dynamicItems, result)
      return
    end if

    frontDynamic = []
    backDynamic = []
    for each dynItem in dynamicItems
      side = BGE.Math.distanceFromPlane(node.item.planePoint, node.item.planeNormal, dynItem.position)
      if side >= 0
        frontDynamic.push(dynItem)
      else
        backDynamic.push(dynItem)
      end if
    end for

    cameraSide = BGE.Math.distanceFromPlane(node.item.planePoint, node.item.planeNormal, cameraPosition)
    if cameraSide >= 0
      ' Camera is in front of this node's plane - the back subtree is farther away, so
      ' it draws first (back-to-front painter's order).
      collectDrawOrder(node.back, cameraPosition, backDynamic, result)
      result.push(node.item.sceneObj)
      collectDrawOrder(node.front, cameraPosition, frontDynamic, result)
    else
      collectDrawOrder(node.front, cameraPosition, frontDynamic, result)
      result.push(node.item.sceneObj)
      collectDrawOrder(node.back, cameraPosition, backDynamic, result)
    end if
  end sub

  private function appendLeafDynamicItems(dynamicItems as BGE.BSP.DynamicItem[], result as dynamic[]) as void
    dynamicItems.sortBy("depthKey")
    for each dynItem in dynamicItems
      result.push(dynItem.sceneObj)
    end for
  end function

end namespace
```

(`private function ... as void` mirrors this codebase's convention of marking file-local helpers `private` even at namespace level - if `bslint`/`bsc` reject `private` on a namespace-level function, drop the modifier; a namespace-level function is already only reachable via its full `BGE.BSP.` path from outside this file's own scope regardless.)

- [ ] **Step 4: Run tests to verify they pass**

Run: `npm run build-tests && npm run test:ci`
Expected: PASS

- [ ] **Step 5: Run the full validation gate**

Run: `npm run validate`
Expected: no new diagnostics - this is the critical check for the same-file self-reference bsc bug (`buildTree`'s return type is `object`, not `BGE.BSP.StaticItem`/a self-referencing class, so this is not expected to trigger it, but confirm here before building on top of it in Task 4).

- [ ] **Step 6: Commit**

```bash
git add src/source/engine/renderer/bsp/StaticGeometryBSP.bs src/source/engine/renderer/bsp/StaticGeometryBSP.spec.bs
git commit -m "Add BGE.BSP: classification-only static geometry tree (#107)"
```

---

### Task 4: Wire `BGE.BSP` into `Renderer`

**Files:**
- Modify: `src/source/engine/renderer/Renderer.bs`
- Test: `src/source/engine/renderer/Renderer.spec.bs` (check whether it exists first - CLAUDE.md references it; add to it if so, else create)

**Interfaces:**
- Consumes: `BGE.BSP.buildTree`/`collectDrawOrder` (Task 3), `SceneObject.isEligibleForStaticBsp()`/`getWorldPoints()`/`isStatic`/`staticGeometryMovedThisFrame` (Task 2), `GameEntity.isStatic` (Task 1).
- Produces: `Renderer.markStatic(sceneObj as SceneObject)` (public - also usable directly by owner-less scene objects, e.g. `examples/rendererTest`), `Renderer.hasStaticGeometryTree() as boolean` (test/diagnostic accessor).

- [ ] **Step 1: Write the failing tests**

Check for an existing spec first:

```bash
ls src/source/engine/renderer/Renderer.spec.bs 2>/dev/null || echo "none yet"
```

Add (to the existing file, or a new one following the `GameEntity.spec.bs` real-`Game` pattern):

```brightscript
namespace tests

  @suite("BGE.Renderer - static geometry BSP")
  class RendererStaticGeometryTests extends rooibos.BaseTestSuite

    game as BGE.Game
    renderer as BGE.Renderer

    protected override function beforeEach()
      m.game = new BGE.Game(320, 240)
      m.renderer = m.game.canvas.renderer
    end function

    @describe("registering static geometry")

    @it("does not mark an entity's rectangle static when isStatic is false")
    function _()
      entity = new BGE.GameEntity(m.game, {name: "wall"})
      drawable = entity.addRectangle("r", 10, 10)
      sceneObj = drawable.getSceneObjects()[0]
      m.assertFalse(sceneObj.isStatic)
      m.assertFalse(m.renderer.hasStaticGeometryTree())
    end function

    @it("marks an eligible SceneObject static when its owning entity is isStatic")
    function _()
      entity = new BGE.GameEntity(m.game, {name: "wall", isStatic: true})
      drawable = entity.addRectangle("r", 10, 10)
      sceneObj = drawable.getSceneObjects()[0]
      m.assertTrue(sceneObj.isStatic)
      m.assertTrue(m.renderer.hasStaticGeometryTree())
    end function

    @it("markStatic() works directly on a SceneObject with no owning GameEntity")
    function _()
      drawable = new BGE.DrawableRectangle(invalid, {width: 10, height: 10})
      sceneObj = drawable.addToScene(m.renderer)
      m.assertFalse(sceneObj.isStatic)
      m.renderer.markStatic(sceneObj)
      m.assertTrue(sceneObj.isStatic)
      m.assertTrue(m.renderer.hasStaticGeometryTree())
    end function

    @describe("drawScene with a mix of static and dynamic content")

    @it("draws without error and both static and dynamic objects remain enabled")
    function _()
      wallEntity = new BGE.GameEntity(m.game, {name: "wall", isStatic: true, position: BGE.Math.VectorOps.create(0, 0, 100)})
      wallEntity.addRectangle("wallRect", 200, 200, {drawMode: BGE.SceneObjectDrawMode.oriented})
      ballEntity = new BGE.GameEntity(m.game, {name: "ball", position: BGE.Math.VectorOps.create(0, 0, 0)})
      ballEntity.addRectangle("ballRect", 20, 20, {drawMode: BGE.SceneObjectDrawMode.oriented})
      m.renderer.camera.position = BGE.Math.VectorOps.create(0, 0, -200)
      m.renderer.drawScene()
      m.assertTrue(wallEntity.isValid())
      m.assertTrue(ballEntity.isValid())
    end function

  end class

end namespace
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `npm run build-tests && npm run test:ci`
Expected: FAIL - `markStatic`/`hasStaticGeometryTree` don't exist yet; static entities aren't actually marked yet.

- [ ] **Step 3: Add fields**

In `src/source/engine/renderer/Renderer.bs`, near the other `private sceneObjects`/`needsDepthSort` fields (around line 59-60):

```brightscript
    private sceneObjects as SceneObject[] = []
    private needsDepthSort as boolean = true

    ' The static geometry BSP tree (see BGE.BSP), or invalid if no static SceneObject has
    ' ever registered with this renderer. Staying invalid is what makes drawScene() take
    ' today's exact code path for a renderer with no static geometry - see hasStaticGeometry.
    private staticTree as object = invalid
    private needsStaticTreeRebuild as boolean = false

    ' Whether any SceneObject has ever been marked static on this renderer. Distinct from
    ' `staticTree <> invalid` so that removing every static object still routes through
    ' the (now-empty, harmless) BSP draw path rather than silently reverting to the plain
    ' sorted path mid-room - see buildStaticGeometryTree().
    private hasStaticGeometry as boolean = false
```

- [ ] **Step 4: Update `addSceneObject`/`removeSceneObject`, add `markStatic`**

In `src/source/engine/renderer/Renderer.bs`, modify `addSceneObject` (around line 312):

```brightscript
    sub addSceneObject(sceneObj as SceneObject)
      sceneObj.setId(m.nextSceneObjectId.toStr().trim())
      m.nextSceneObjectId++
      m.sceneObjects.push(sceneObj)
      ' Initialize lastSortIndex to the current insertion position so objects added
      ' at the same time are ordered by their addition order even before the first sort.
      sceneObj.setLastSortIndex(m.sceneObjects.count() - 1)
      m.needsDepthSort = true

      owner = sceneObj.drawable.owner
      if owner <> invalid and owner.isStatic
        if sceneObj.isEligibleForStaticBsp()
          m.markStatic(sceneObj)
        else
          owner.game.log("GameEntity '" + owner.name + "' is marked isStatic but its " + sceneObj.type.toStr() + " scene object type doesn't support static geometry yet (v1 supports SceneObjectImage/SceneObjectRectangle only) - it will draw using the normal sorted order instead", BGE.Debug.LogLevel.warning)
        end if
      end if
    end sub

    ' Marks a SceneObject as static geometry and schedules a tree rebuild. Called
    ' automatically by addSceneObject() when the object's owning GameEntity is isStatic
    ' and its type is eligible (isEligibleForStaticBsp()) - exposed publicly so a
    ' SceneObject with no owning GameEntity (e.g. examples/rendererTest, which builds
    ' scene objects directly - see SkyboxTest.bs) can still opt in.
    '
    ' @param {SceneObject} sceneObj
    sub markStatic(sceneObj as SceneObject)
      sceneObj.isStatic = true
      m.hasStaticGeometry = true
      m.needsStaticTreeRebuild = true
    end sub
```

Modify `removeSceneObject` (around line 331) to add one line after the existing `m.needsDepthSort = true`:

```brightscript
    sub removeSceneObject(sceneObjToRemove as SceneObject)
      indexToDelete = -1
      for i = 0 to m.sceneObjects.count()
        sceneObj = m.sceneObjects[i]
        if sceneObj.id = sceneObjToRemove.id
          indexToDelete = i
          exit for
        end if
      end for
      if indexToDelete >= 0
        m.sceneObjects.delete(indexToDelete)
        m.needsDepthSort = true
        if sceneObjToRemove.isStatic
          m.needsStaticTreeRebuild = true
        end if
      end if
      sceneObjToRemove.id = ""
    end sub
```

- [ ] **Step 5: Pick up the misuse-detection flag in `updateSceneObjects`**

Modify `updateSceneObjects` (around line 369):

```brightscript
    private sub updateSceneObjects()
      for each sceneObj in m.sceneObjects
        if sceneObj.isEnabled()
          sceneObj.update(m.camera)
          if sceneObj.depthChangedThisFrame
            m.needsDepthSort = true
          end if
          if sceneObj.staticGeometryMovedThisFrame
            m.needsStaticTreeRebuild = true
          end if
        end if
      end for
    end sub
```

- [ ] **Step 6: Add `buildStaticGeometryTree`, `drawStaticAndDynamicSceneObjects`, `hasStaticGeometryTree`**

Add these new private methods to `Renderer.bs` (near `drawPendingClusterPrimitives`, since it's the closest existing analog):

```brightscript
    ' Rebuilds the static geometry BSP tree from every currently-registered static
    ' SceneObject's world-space plane. Called lazily from drawScene() only when
    ' needsStaticTreeRebuild is set (registration, removal, or a static object that
    ' moved - see SceneObject.update()'s misuse detection) - not every frame.
    private sub buildStaticGeometryTree()
      items = []
      for each sceneObj in m.sceneObjects
        if sceneObj.isStatic and sceneObj.isEnabled()
          worldPoints = sceneObj.getWorldPoints()
          items.push({
            sceneObj: sceneObj
            planePoint: worldPoints.getCenter()
            planeNormal: worldPoints.getNormal()
          })
        end if
      end for
      m.staticTree = BGE.BSP.buildTree(items)
      m.needsStaticTreeRebuild = false
    end sub

    ' The static+dynamic draw path used once any SceneObject has ever been marked static
    ' on this renderer (see hasStaticGeometry) - replaces the plain per-object sorted
    ' loop for every non-plane, non-skybox object. Static objects draw via the BSP tree
    ' walk; every other enabled, in-front-of-camera object is threaded into that same
    ' walk as a dynamic item (see BGE.BSP.collectDrawOrder) instead of being drawn in a
    ' separate pass, so a dynamic object between two static quads' depths draws in the
    ' correct interleaved position.
    private sub drawStaticAndDynamicSceneObjects()
      if m.needsStaticTreeRebuild
        m.buildStaticGeometryTree()
      end if

      dynamicItems = []
      for each sceneObj in m.sceneObjects
        if sceneObj.isEnabled() and not sceneObj.isStatic and sceneObj.type <> SceneObjectType.Plane and sceneObj.type <> SceneObjectType.Skybox and sceneObj.negDistanceFromCamera < 0
          dynamicItems.push({
            sceneObj: sceneObj
            position: sceneObj.worldPosition
            depthKey: sceneObj.negDistanceFromCamera
          })
        end if
      end for

      drawOrder = []
      BGE.BSP.collectDrawOrder(m.staticTree, m.camera.position, dynamicItems, drawOrder)
      for each sceneObj in drawOrder
        sceneObj.draw(m)
      end for
    end sub

    ' Whether any static geometry has ever been registered on this renderer - true even
    ' if every static object has since been removed (see hasStaticGeometry's own doc
    ' comment). Exposed for tests/diagnostics, not meant for game logic.
    '
    ' @return {boolean}
    function hasStaticGeometryTree() as boolean
      return m.hasStaticGeometry
    end function

    ' A shallow copy of every currently-registered SceneObject - for diagnostics/tests
    ' (see Task 6's rendererTest benchmark) that need to enumerate them without a direct
    ' reference to the live internal array.
    '
    ' @return {BGE.SceneObject[]}
    function getSceneObjectsCopy() as BGE.SceneObject[]
      return m.sceneObjects.slice()
    end function
```

- [ ] **Step 7: Branch `drawScene()`'s draw loop**

In `src/source/engine/renderer/Renderer.bs`, replace the existing "draw sceneObjects in sorted order" loop (the block right after the plane-drawing loop, before `m.drawPendingClusterPrimitives()`):

```brightscript
      ' draw sceneObjects in sorted order
      ' ignore any that are too far away (TBD) or behind camera
      for each sceneObj in m.sceneObjects
        if sceneObj.isEnabled() and sceneObj.type <> SceneObjectType.Plane and sceneObj.type <> SceneObjectType.Skybox
          if sceneObj.negDistanceFromCamera < 0 'and sceneObj.normnegDistanceFromCamera < 10000
            sceneObj.draw(m)
          end if
        end if
      end for
```

with:

```brightscript
      ' draw sceneObjects in sorted order - the static-geometry BSP walk (see
      ' drawStaticAndDynamicSceneObjects) once anything has ever been marked static on
      ' this renderer, otherwise exactly the plain per-object painter's sort from before
      ' this feature existed. hasStaticGeometry starting (and staying, once true) false
      ' for any renderer that never registers static geometry is what guarantees the
      ' zero-static case sees byte-identical draw order to before.
      if m.hasStaticGeometry
        m.drawStaticAndDynamicSceneObjects()
      else
        ' ignore any that are too far away (TBD) or behind camera
        for each sceneObj in m.sceneObjects
          if sceneObj.isEnabled() and sceneObj.type <> SceneObjectType.Plane and sceneObj.type <> SceneObjectType.Skybox
            if sceneObj.negDistanceFromCamera < 0
              sceneObj.draw(m)
            end if
          end if
        end for
      end if
```

- [ ] **Step 8: Add the import**

At the top of `src/source/engine/renderer/Renderer.bs`, add (alphabetically among the existing imports):

```brightscript
import "bsp/StaticGeometryBSP.bs"
```

- [ ] **Step 9: Run tests to verify they pass**

Run: `npm run build-tests && npm run test:ci`
Expected: PASS

- [ ] **Step 10: Run the full local quality gate**

Run: `npm run check`
Expected: lint, validate, and headless tests all pass.

- [ ] **Step 11: Commit**

```bash
git add src/source/engine/renderer/Renderer.bs src/source/engine/renderer/Renderer.spec.bs
git commit -m "Wire BGE.BSP static geometry tree into Renderer.drawScene() (#107)"
```

---

### Task 5: Re-enable `examples/collisions3d`'s wall images

**Files:**
- Modify: `examples/collisions3d/src/source/Entities/Wall.bs`

**Interfaces:**
- Consumes: `GameEntity.isStatic` (Task 1), the full static-BSP draw path (Task 4).

- [ ] **Step 1: Re-enable the wall image and mark it static**

Replace the full contents of `examples/collisions3d/src/source/Entities/Wall.bs`:

```brightscript
' One face of the bouncing box: a real BGE.BoxCollider3d slab spheres actually collide
' against. Marked isStatic (issue #107) so its image draws in correct order against the
' balls bouncing inside the box - previously disabled because a wall spans a depth range
' the balls sit partway through, which a single-scalar painter's sort can't represent.
class Wall extends BGE.GameEntity

  sub new(game as BGE.Game)
    super(game)
    m.name = "Wall"
  end sub

  override sub onCreate(args as roAssociativeArray)
    m.isStatic = true
    m.position = args.center

    if args.hasImage <> false
      textureSize = 512.0
      m.scale = BGE.Math.createScaleVector(args.size / textureSize)

      bitmap = m.game.getBitmap("wall")
      region = CreateObject("roRegion", bitmap, 0, 0, bitmap.getWidth(), bitmap.getHeight())
      image = m.addImage("visual", region, {rotation: args.rotation, isShaded: true, drawMode: BGE.SceneObjectDrawMode.orientedDrawBackFace})
      image.setAnchor(0.5, 0.5)
    end if

    m.addBoxCollider3d("body", args.colliderWidth, args.colliderHeight, args.colliderDepth)
  end sub

end class
```

- [ ] **Step 2: Build and validate the example**

Run: `npm run build && cd examples/collisions3d && npm install && npm run build`
Expected: builds cleanly, no diagnostics.

- [ ] **Step 3: On-device verification (mandatory, not optional)**

Per this repo's own rule (`CLAUDE.md`: automated tests don't exercise example entity/room code at all), sideload and run `examples/collisions3d` on a real device or simulator via the `rokubot-examples` skill. Confirm:
- The walls are now visibly textured (not blank/invisible).
- A ball is visibly drawn correctly in front of the near wall and behind the far wall as it moves through the box - the actual bug this task fixes.
- No crash, no z-fighting/flicker between walls and balls.

- [ ] **Step 4: Commit**

```bash
git add examples/collisions3d/src/source/Entities/Wall.bs
git commit -m "Re-enable collisions3d wall images now that static geometry BSP orders them correctly (#107)"
```

---

### Task 6: `rendererTest` benchmark - static BSP path vs. plain sorted path

**Files:**
- Create: `examples/rendererTest/src/source/Tests/StaticGeometryBspBenchmark.bs`
- Modify: `examples/rendererTest/src/source/DemoList.bs`

**Interfaces:**
- Consumes: `Renderer.markStatic()` (Task 4), the `owner = invalid` construction pattern already used by `SkyboxTest.bs`.

- [ ] **Step 1: Write the benchmark demo**

Create `examples/rendererTest/src/source/Tests/StaticGeometryBspBenchmark.bs`:

```brightscript
' Times Renderer.drawScene()'s static-geometry BSP path (Renderer.markStatic(), issue
' #107) against the plain per-object sorted path it replaces, using a small "room" of
' static wall quads with dynamic "ball" quads moving between them each frame - the same
' shape as examples/collisions3d, without needing BGE.Game/GameEntity (see SkyboxTest.bs
' for the same owner-less construction pattern this demo follows).
class StaticGeometryBspBenchmark extends RendererTest

  private wallCount = 6
  private ballCount = 10
  private resultLines as string[] = []

  sub new()
    super("Static Geometry BSP Benchmark")
  end sub

  override sub setup(renderer as BGE.Renderer)
    center = renderer.getCanvasCenter()
    renderer.camera = new BGE.Camera3d()
    renderer.camera.position = BGE.Math.VectorOps.create(0, 0, -400)
    renderer.camera.setTarget(BGE.Math.VectorOps.create(0, 0, 0))

    m.buildWalls(renderer, true)
    m.buildBalls(renderer)
    staticMs = m.timeDrawScene(renderer, 60)

    m.resetScene(renderer)
    m.buildWalls(renderer, false)
    m.buildBalls(renderer)
    plainMs = m.timeDrawScene(renderer, 60)

    m.resultLines = [
      `Static BSP path:  ${staticMs} ms / 60 frames`
      `Plain sorted path: ${plainMs} ms / 60 frames`
    ]
  end sub

  private sub resetScene(renderer as BGE.Renderer)
    for each sceneObj in renderer.getSceneObjectsCopy()
      renderer.removeSceneObject(sceneObj)
    end for
  end sub

  private sub buildWalls(renderer as BGE.Renderer, markAsStatic as boolean)
    positions = [
      BGE.Math.VectorOps.create(0, 0, 150), BGE.Math.VectorOps.create(0, 0, -150),
      BGE.Math.VectorOps.create(150, 0, 0), BGE.Math.VectorOps.create(-150, 0, 0),
      BGE.Math.VectorOps.create(0, 150, 0), BGE.Math.VectorOps.create(0, -150, 0)
    ]
    for i = 0 to m.wallCount - 1
      drawable = new BGE.DrawableRectangle(invalid, {width: 300, height: 300, drawMode: BGE.SceneObjectDrawMode.oriented})
      drawable.offset = positions[i]
      sceneObj = drawable.addToScene(renderer)
      if markAsStatic
        renderer.markStatic(sceneObj)
      end if
    end for
  end sub

  private sub buildBalls(renderer as BGE.Renderer)
    for i = 0 to m.ballCount - 1
      drawable = new BGE.DrawableRectangle(invalid, {width: 20, height: 20, drawMode: BGE.SceneObjectDrawMode.oriented})
      angle = (2 * BGE.Math.PI) * (i / m.ballCount)
      drawable.offset = BGE.Math.VectorOps.create(cos(angle) * 80, sin(angle) * 80, sin(angle * 2) * 80)
      drawable.addToScene(renderer)
    end for
  end sub

  private function timeDrawScene(renderer as BGE.Renderer, frames as integer) as integer
    timer = CreateObject("roTimespan")
    for i = 0 to frames - 1
      renderer.drawScene()
    end for
    return timer.TotalMilliseconds()
  end function

  override sub draw(renderer as BGE.Renderer)
    y = 20
    for each line in m.resultLines
      renderer.drawText(line, 20, y, BGE.Colors.White)
      y += 20
    end for
  end sub

end class
```

`Renderer.getSceneObjectsCopy()` (used in `resetScene()` above) was added as part of Task 4 - no new `Renderer` surface needed here.

- [ ] **Step 2: Register the demo**

In `examples/rendererTest/src/source/DemoList.bs`, add an entry (matching the existing `"Drawing"` category entries' shape):

```brightscript
    {
      id: "static-geometry-bsp-benchmark",
      category: "Drawing",
      name: "Static Geometry BSP Benchmark",
      create: function() as RendererTest
        return new StaticGeometryBspBenchmark()
      end function
    },
```

- [ ] **Step 3: Build and run**

Run: `cd examples/rendererTest && npm install && npm run build`
Expected: builds cleanly.

Run via `rokubot` (see the `rokubot-examples` skill): `rokubot launch dev --param demo=static-geometry-bsp-benchmark`
Expected: both timings print on screen; the static BSP path should not be dramatically slower than the plain sorted path for this small object count (6 walls, 10 balls) - if it's several times slower, that's a real finding to report back, not something to silently accept, per this repo's "measure, don't guess" rule for rendering changes.

- [ ] **Step 4: Commit**

```bash
git add examples/rendererTest/src/source/Tests/StaticGeometryBspBenchmark.bs examples/rendererTest/src/source/DemoList.bs
git commit -m "Add rendererTest benchmark: static geometry BSP path vs. plain sorted path (#107)"
```

---

### Task 7: Regression check - zero behavior change for non-static content

**Files:** none modified - verification only.

- [ ] **Step 1: Full engine + example quality gate**

Run: `npm run check:all`
Expected: lint, validate, headless tests, and every example's own validate all pass.

- [ ] **Step 2: On-device spot check of an unrelated 3D example**

Per `CLAUDE.md`'s rule that automated checks don't exercise example runtime behavior, sideload `examples/3d` (or `examples/terrain`) via `rokubot-examples` and confirm it looks and performs exactly as before - neither example sets `isStatic` anywhere yet, so `Renderer.hasStaticGeometry` stays `false` for their renderers and `drawScene()` takes the unchanged plain-sorted path. This is the concrete proof of the zero-static fallback guarantee, not just a code-review claim.

- [ ] **Step 3: Report findings**

If the benchmark from Task 6 showed a meaningful regression, or the on-device check found any visual difference in `examples/3d`/`examples/terrain`, stop and report back before considering #107 done - either would mean the zero-static fallback isn't actually zero-cost, which is a Global Constraint, not a nice-to-have.
