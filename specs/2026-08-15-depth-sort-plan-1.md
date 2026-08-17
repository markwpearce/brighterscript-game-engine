# Depth-Sort Plan 1: Prerequisites + Overlap Detection Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land the two cheap, always-on depth-sort fixes (skip the sort when nothing changed; stable tie-breaking) plus a standalone, tested broad/narrow-phase overlap-detection capability, and a new `examples/depthsort` example that visualizes both - without yet changing how overlapping objects are actually drawn (that's Plan 2).

**Architecture:** `Renderer.drawScene()` gains a dirty flag so `sortBy` only runs when depth actually changed, and a stable combined sort key so near-equal depths keep their previous relative order. A new `BGE.DepthSort` namespace implements broad-phase (AABB + depth range, reusing `getPositionsForFrustumCheck`'s existing bounding points) and narrow-phase (SAT via the existing `quickhull` utility) overlap tests as pure functions, plus per-frame cluster grouping exposed read-only from `Renderer` for the new example to visualize. `examples/depthsort` gets a `Camera2d` room proving the tie-break fix and a `Camera3d` room highlighting detected overlap clusters (including the wall-vs-nearby-model false-positive check) with no draw-order change yet.

**Tech Stack:** BrighterScript (engine), Rooibos for specs, the existing `examples/3d`-style `BaseRoom` camera-control pattern.

**Spec:** `specs/2026-08-15-depth-sort-design.md`

## Global Constraints

- One `@suite` class per `*.spec.bs` file (Rooibos v6 corrupts multi-suite files).
- `assertEqual` is type-strict - match Integer vs Float exactly; when unsure, run the test once and read the actual/expected types off the failure diff.
- Public API methods get JSDoc-style `'` comments (`@param`, `@return`) directly above them.
- Run `npm run validate` after any engine source change; run `npm run test:ci` after any spec change. Both must pass before moving to the next task.
- Never edit on `main` directly - all work happens on `feature/depth-sort` (already checked out).
- Per the spec: this plan does **not** change draw order or disable temp-bitmap caching for any object - it only detects and reports overlap, so it must be provably zero-risk to land on its own.

---

### Task 1: Skip the depth sort when nothing changed

**Files:**
- Modify: `src/source/engine/renderer/sceneObjects/SceneObject.bs:218-233` (the `update()` method)
- Modify: `src/source/engine/renderer/Renderer.bs:195-199` (`addSceneObject`), `:201-210` (`removeSceneObject`), `:216-222` (`updateSceneObjects`), `:233-236` (`drawScene`)
- Test: `src/source/engine/renderer/Renderer.spec.bs`

**Interfaces:**
- Produces: `SceneObject.depthChangedThisFrame as boolean` (public field, true for exactly the frame `update()` recomputed `negDistanceFromCamera`) - `Renderer.updateSceneObjects()` reads this. `Renderer.needsDepthSort as boolean` (private field, but the test observes its effect via `getDrawCallsLastFrame()`-style indirect assertion - see below).

- [ ] **Step 1: Write the failing test**

Add to `src/source/engine/renderer/Renderer.spec.bs` (after the existing `@describe("resources.circle")` block, following its existing `beforeEach`/`bitmap`/`renderer` fixture):

```brightscript
    @describe("depth sort skipping")

    @it("does not re-sort when nothing has moved")
    function _()
      entityA = new BGE.GameEntity(new BGE.Game(320, 240), {name: "A"})
      rectA = new BGE.DrawableRectangle(entityA, 20, 20)
      sceneObjA = rectA.addToScene(m.renderer)
      entityA.updateTransformationMatrix()
      m.renderer.setupCameraForFrame()
      m.renderer.drawScene()

      ' Nothing moved between these two calls - the array should be the exact
      ' same objects in the exact same order both times, and (per the fix)
      ' sortBy should not even run the second time.
      m.renderer.setupCameraForFrame()
      countBefore = m.renderer.getSceneObjectCount()
      m.renderer.drawScene()
      m.assertEqual(countBefore, m.renderer.getSceneObjectCount())
      m.assertFalse(m.renderer.didSortLastFrame())
    end function

    @it("does re-sort when the camera moved")
    function _()
      entityA = new BGE.GameEntity(new BGE.Game(320, 240), {name: "A"})
      rectA = new BGE.DrawableRectangle(entityA, 20, 20)
      rectA.addToScene(m.renderer)
      entityA.updateTransformationMatrix()
      m.renderer.setupCameraForFrame()
      m.renderer.drawScene()

      m.renderer.camera.position.z += 10
      m.renderer.setupCameraForFrame()
      m.renderer.drawScene()
      m.assertTrue(m.renderer.didSortLastFrame())
    end function
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `npm run test:ci`
Expected: FAIL - `getSceneObjectCount`/`didSortLastFrame` are not members of `BGE.Renderer`.

- [ ] **Step 3: Add `depthChangedThisFrame` to `SceneObject.update()`**

In `src/source/engine/renderer/sceneObjects/SceneObject.bs`, find the `update()` method (currently):

```brightscript
    sub update(cameraObj as Camera)
      objMovedLastFrame = m.drawable.movedLastFrame(true)
      m.isFirstFrameSinceEnabled = (m.isEnabled() and not m.wasEnabledLastFrame)
      sceneObjDrawMode = m.getActualDrawMode(cameraObj)
      drawModeChanged = m.drawModeChanged(sceneObjDrawMode)
      forceRecompute = objMovedLastFrame or not m.hasValidWorldPosition or m.isFirstFrameSinceEnabled or m.geometryChanged() or drawModeChanged
      if forceRecompute
        m.drawable.computeTransformationMatrix()
        BGE.math.Matrix44.setFrom(m.transformationMatrix, BGE.math.Matrix44.multiply(m.drawable.transformationMatrix, m.drawable.owner.transformationMatrix))
        m.hasValidWorldPosition = m.updateWorldPosition(sceneObjDrawMode)
      end if
      if cameraObj.movedLastFrame() or objMovedLastFrame or drawModeChanged
        m.negDistanceFromCamera = -cameraObj.distanceFromCameraFront(m.getPositionForCameraDistance(sceneObjDrawMode))
      end if
      m.wasEnabledLastFrame = m.isEnabled()
    end sub
```

Replace with (adds the `depthChangedThisFrame` field set alongside the existing recompute condition, no other logic changed):

```brightscript
    ' True for exactly the frame this object's negDistanceFromCamera was recomputed -
    ' Renderer.updateSceneObjects() ORs these together to decide whether the whole
    ' scene needs a re-sort this frame, instead of always resorting even when nothing
    ' that could change draw order actually happened.
    depthChangedThisFrame as boolean = true

    sub update(cameraObj as Camera)
      objMovedLastFrame = m.drawable.movedLastFrame(true)
      m.isFirstFrameSinceEnabled = (m.isEnabled() and not m.wasEnabledLastFrame)
      sceneObjDrawMode = m.getActualDrawMode(cameraObj)
      drawModeChanged = m.drawModeChanged(sceneObjDrawMode)
      forceRecompute = objMovedLastFrame or not m.hasValidWorldPosition or m.isFirstFrameSinceEnabled or m.geometryChanged() or drawModeChanged
      if forceRecompute
        m.drawable.computeTransformationMatrix()
        BGE.math.Matrix44.setFrom(m.transformationMatrix, BGE.math.Matrix44.multiply(m.drawable.transformationMatrix, m.drawable.owner.transformationMatrix))
        m.hasValidWorldPosition = m.updateWorldPosition(sceneObjDrawMode)
      end if
      m.depthChangedThisFrame = cameraObj.movedLastFrame() or objMovedLastFrame or drawModeChanged
      if m.depthChangedThisFrame
        m.negDistanceFromCamera = -cameraObj.distanceFromCameraFront(m.getPositionForCameraDistance(sceneObjDrawMode))
      end if
      m.wasEnabledLastFrame = m.isEnabled()
    end sub
```

Note: `depthChangedThisFrame` defaults to `true` so a scene object's very first frame always contributes to a sort, matching today's always-sort-on-first-frame behavior.

- [ ] **Step 4: Add the dirty flag and accessors to `Renderer`**

In `src/source/engine/renderer/Renderer.bs`, add a private field near the other renderer-private fields (next to `private sceneObjects as SceneObject[] = []`):

```brightscript
    private needsDepthSort as boolean = true
```

Update `addSceneObject`/`removeSceneObject` (both already exist) to mark the list dirty:

```brightscript
    sub addSceneObject(sceneObj as SceneObject)
      sceneObj.setId(m.nextSceneObjectId.toStr().trim())
      m.nextSceneObjectId++
      m.sceneObjects.push(sceneObj)
      m.needsDepthSort = true
    end sub

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
      end if
      sceneObjToRemove.id = ""
    end sub
```

Update `updateSceneObjects()` to aggregate the per-object flag:

```brightscript
    private sub updateSceneObjects()
      for each sceneObj in m.sceneObjects
        if sceneObj.isEnabled()
          sceneObj.update(m.camera)
          if sceneObj.depthChangedThisFrame
            m.needsDepthSort = true
          end if
        end if
      end for
    end sub
```

Update `drawScene()` to only sort when needed, and track whether it sorted:

```brightscript
    sub drawScene()
      m.updateSceneObjects()

      m.lastFrameDidSort = m.needsDepthSort
      if m.needsDepthSort
        m.sceneObjects.sortBy("negDistanceFromCamera")
        m.needsDepthSort = false
      end if

      'TODO - Do proper occlusion culling
      ' draw planes first
```

(leave the rest of `drawScene()` - the two draw-pass for loops - unchanged.)

Add the private tracking field next to `needsDepthSort`, and the two public accessors near `getDrawCallsLastFrame()`:

```brightscript
    private lastFrameDidSort as boolean = false
```

```brightscript
    ' Whether drawScene() actually re-sorted the scene objects last frame, or skipped
    ' the sort because nothing that could change draw order happened. Exposed for
    ' testing/diagnostics, not meant to drive game logic.
    '
    ' @return {boolean}
    function didSortLastFrame() as boolean
      return m.lastFrameDidSort
    end function

    ' How many SceneObjects are currently registered with this renderer.
    '
    ' @return {integer}
    function getSceneObjectCount() as integer
      return m.sceneObjects.count()
    end function
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `npm run test:ci`
Expected: PASS.

- [ ] **Step 6: Run validate**

Run: `npm run validate`
Expected: no errors.

- [ ] **Step 7: Commit**

```bash
git add src/source/engine/renderer/sceneObjects/SceneObject.bs src/source/engine/renderer/Renderer.bs src/source/engine/renderer/Renderer.spec.bs
git commit -m "Skip the depth sort when nothing that affects draw order changed (#59)"
```

---

### Task 2: Stable tie-breaking for near-equal depths

**Files:**
- Modify: `src/source/engine/renderer/sceneObjects/SceneObject.bs` (add a stable sort key field)
- Modify: `src/source/engine/renderer/Renderer.bs` (`drawScene()`, compute the key before sorting)
- Test: `src/source/engine/renderer/Renderer.spec.bs`

**Interfaces:**
- Consumes: `SceneObject.negDistanceFromCamera`, `SceneObject.depthChangedThisFrame` (Task 1).
- Produces: `SceneObject.stableSortKey as float` (public field) - what `Renderer.drawScene()` sorts by from now on, instead of `negDistanceFromCamera` directly. `Renderer.DEPTH_TIE_EPSILON as float` (a `const` other code/tests can reference).

- [ ] **Step 1: Write the failing test**

Add to `src/source/engine/renderer/Renderer.spec.bs`, in the same `@describe("depth sort skipping")` block:

```brightscript
    @it("keeps the previous relative order for two objects at the same depth, even after other objects change")
    function _()
      gameA = new BGE.Game(320, 240)
      entityFar = new BGE.GameEntity(gameA, {name: "Far"})
      entityFar.position = BGE.Math.VectorOps.create(0, 0, 100)
      entityTie1 = new BGE.GameEntity(gameA, {name: "Tie1"})
      entityTie1.position = BGE.Math.VectorOps.create(-10, 0, 0)
      entityTie2 = new BGE.GameEntity(gameA, {name: "Tie2"})
      entityTie2.position = BGE.Math.VectorOps.create(10, 0, 0)

      rectFar = new BGE.DrawableRectangle(entityFar, 20, 20)
      rectTie1 = new BGE.DrawableRectangle(entityTie1, 20, 20)
      rectTie2 = new BGE.DrawableRectangle(entityTie2, 20, 20)
      rectFar.addToScene(m.renderer)
      sceneObjTie1 = rectTie1.addToScene(m.renderer)
      sceneObjTie2 = rectTie2.addToScene(m.renderer)

      for each entity in [entityFar, entityTie1, entityTie2]
        entity.updateTransformationMatrix()
      end for
      m.renderer.setupCameraForFrame()
      m.renderer.drawScene()
      orderBefore = [sceneObjTie1.id, sceneObjTie2.id]

      ' Move only the far object - the two tied objects never move, so their
      ' relative order must not change even though a sort runs again.
      entityFar.position.z += 50
      entityFar.updateTransformationMatrix()
      m.renderer.setupCameraForFrame()
      m.renderer.drawScene()

      tie1Index = m.renderer.getSceneObjectIndexById(sceneObjTie1.id)
      tie2Index = m.renderer.getSceneObjectIndexById(sceneObjTie2.id)
      if orderBefore[0] = sceneObjTie1.id
        m.assertTrue(tie1Index < tie2Index)
      else
        m.assertTrue(tie2Index < tie1Index)
      end if
    end function
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm run test:ci`
Expected: FAIL - `getSceneObjectIndexById` is not a member of `BGE.Renderer` (this test can also fail non-deterministically today even without that error, since nothing currently guarantees stable tie order - the missing method is the immediate blocker to fix first).

- [ ] **Step 3: Add the stable sort key**

In `src/source/engine/renderer/sceneObjects/SceneObject.bs`, add a field next to `negDistanceFromCamera`:

```brightscript
    ' What Renderer actually sorts by - negDistanceFromCamera quantized to
    ' DEPTH_TIE_EPSILON, combined with this object's sort position from the previous
    ' frame, so two objects at the same (or nearly the same) depth keep their previous
    ' relative order instead of swapping from floating-point jitter alone. A genuine
    ' depth crossover still swaps order correctly, since the quantized depth term
    ' dominates the combined key.
    stableSortKey as float = 0
    private lastSortIndex as integer = 0
```

- [ ] **Step 4: Compute the combined key in `Renderer.drawScene()` before sorting**

In `src/source/engine/renderer/Renderer.bs`, add the epsilon constant near the top of the class alongside the other `const`s (`RendererResourceSize`, etc.):

```brightscript
    const DEPTH_TIE_EPSILON = 0.5
```

Update `drawScene()` (from Task 1) to compute `stableSortKey` for every object before sorting, and record each object's new index after:

```brightscript
    sub drawScene()
      m.updateSceneObjects()

      m.lastFrameDidSort = m.needsDepthSort
      if m.needsDepthSort
        ' A combined key: the quantized depth dominates, with the previous frame's
        ' sort position as the tie-breaker for anything that quantizes to the same
        ' bucket. The multiplier is scaled to the actual object count (rather than a
        ' fixed large constant) so lastSortIndex - which never reaches the object
        ' count - can never spill into the next depth bucket, while keeping the
        ' combined key's magnitude small enough that Float32 precision doesn't silently
        ' round the tie-break term away at larger depth values.
        sortKeyMultiplier = m.sceneObjects.count() + 1
        for each sceneObj in m.sceneObjects
          quantizedDepth = Int(sceneObj.negDistanceFromCamera / DEPTH_TIE_EPSILON)
          sceneObj.stableSortKey = (quantizedDepth * sortKeyMultiplier) + sceneObj.lastSortIndex
        end for
        m.sceneObjects.sortBy("stableSortKey")
        for i = 0 to m.sceneObjects.count() - 1
          m.sceneObjects[i].lastSortIndex = i
        end for
        m.needsDepthSort = false
      end if
```

`lastSortIndex` is `private` on `SceneObject`, so `Renderer` (a different class) can't assign it directly from outside - add a small setter to `SceneObject.bs` right after the `stableSortKey`/`lastSortIndex` field declarations:

```brightscript
    sub setLastSortIndex(index as integer)
      m.lastSortIndex = index
    end sub
```

and use `sceneObj.setLastSortIndex(i)` instead of `sceneObj.lastSortIndex = i` in the loop above.

Add the accessor test needs:

```brightscript
    ' The current array index of the SceneObject with the given id, or -1 if none
    ' matches. Exposed for testing stable sort order - not meant for game logic.
    '
    ' @param {string} id
    ' @return {integer}
    function getSceneObjectIndexById(id as string) as integer
      for i = 0 to m.sceneObjects.count() - 1
        if m.sceneObjects[i].id = id
          return i
        end if
      end for
      return -1
    end function
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `npm run test:ci`
Expected: PASS.

- [ ] **Step 6: Run validate**

Run: `npm run validate`
Expected: no errors.

- [ ] **Step 7: Commit**

```bash
git add src/source/engine/renderer/sceneObjects/SceneObject.bs src/source/engine/renderer/Renderer.bs src/source/engine/renderer/Renderer.spec.bs
git commit -m "Stable tie-breaking for near-equal depths in the scene sort (#59)"
```

---

### Task 3: Broad-phase overlap test (AABB + depth range)

**Files:**
- Create: `src/source/engine/renderer/DepthSortHelpers.bs`
- Test: `src/source/engine/renderer/DepthSortHelpers.spec.bs`

**Interfaces:**
- Consumes: `BGE.Math.getBounds(points as BGE.Math.Vector[]) as BGE.Math.Vector[]` (existing, returns `[minPoint, maxPoint]`), `Camera.distanceFromCameraFront(point as BGE.Math.Vector) as float` (existing).
- Produces: `BGE.DepthSort.ScreenBounds` interface (`{minX, maxX, minY, maxY, minDepth, maxDepth}`), `BGE.DepthSort.getScreenBounds(worldPoints as BGE.Math.Vector[], rendererObj as BGE.Renderer) as ScreenBounds`, `BGE.DepthSort.boundsOverlap(a as ScreenBounds, b as ScreenBounds) as boolean`. Task 4 (narrow phase) and Task 5 (cluster grouping) both consume these.

- [ ] **Step 1: Write the failing tests**

Create `src/source/engine/renderer/DepthSortHelpers.spec.bs`:

```brightscript
namespace tests

  ' DepthSortHelpers.getScreenBounds/boundsOverlap are pure functions over already-
  ' computed bounding points (the same points getPositionsForFrustumCheck() returns),
  ' so they're tested directly against a real Renderer/Camera without needing a full
  ' SceneObject.
  @suite("BGE.DepthSort broad phase")
  class DepthSortBroadPhaseTests extends rooibos.BaseTestSuite

    bitmap as roBitmap
    renderer as BGE.Renderer

    protected override function beforeEach()
      m.bitmap = CreateObject("roBitmap", {width: 400, height: 400, alphaEnable: true})
      m.renderer = new BGE.Renderer(m.bitmap)
    end function

    @describe("getScreenBounds")

    @it("projects world points to a screen-space AABB and a camera-relative depth range")
    function _()
      ' A 2D camera centered on its canvas: world (0,0,z) projects near canvas center,
      ' and distanceFromCameraFront is just camera.position.z - point.z.
      points = [
        BGE.Math.VectorOps.create(-50, -50, 0),
        BGE.Math.VectorOps.create(50, 50, 20)
      ]
      bounds = BGE.DepthSort.getScreenBounds(points, m.renderer)
      m.assertTrue(bounds.minX < bounds.maxX)
      m.assertTrue(bounds.minY < bounds.maxY)
      m.assertTrue(bounds.minDepth < bounds.maxDepth)
    end function

    @describe("boundsOverlap")

    @it("returns true for two identical bounds")
    function _()
      bounds = {minX: 0.0, maxX: 10.0, minY: 0.0, maxY: 10.0, minDepth: 0.0, maxDepth: 10.0}
      m.assertTrue(BGE.DepthSort.boundsOverlap(bounds, bounds))
    end function

    @it("returns false when screen X ranges don't overlap, even if depth ranges do")
    function _()
      a = {minX: 0.0, maxX: 10.0, minY: 0.0, maxY: 10.0, minDepth: 0.0, maxDepth: 10.0}
      b = {minX: 20.0, maxX: 30.0, minY: 0.0, maxY: 10.0, minDepth: 0.0, maxDepth: 10.0}
      m.assertFalse(BGE.DepthSort.boundsOverlap(a, b))
    end function

    @it("returns false when depth ranges don't overlap, even if screen bounds do")
    function _()
      a = {minX: 0.0, maxX: 10.0, minY: 0.0, maxY: 10.0, minDepth: 0.0, maxDepth: 10.0}
      b = {minX: 0.0, maxX: 10.0, minY: 0.0, maxY: 10.0, minDepth: 100.0, maxDepth: 110.0}
      m.assertFalse(BGE.DepthSort.boundsOverlap(a, b))
    end function

    @it("returns true when both screen bounds and depth ranges overlap")
    function _()
      a = {minX: 0.0, maxX: 10.0, minY: 0.0, maxY: 10.0, minDepth: 0.0, maxDepth: 10.0}
      b = {minX: 5.0, maxX: 15.0, minY: 5.0, maxY: 15.0, minDepth: 5.0, maxDepth: 15.0}
      m.assertTrue(BGE.DepthSort.boundsOverlap(a, b))
    end function

  end class

end namespace
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `npm run test:ci`
Expected: FAIL - `BGE.DepthSort` namespace/functions don't exist.

- [ ] **Step 3: Write `DepthSortHelpers.bs`**

Create `src/source/engine/renderer/DepthSortHelpers.bs`:

```brightscript
namespace BGE.DepthSort

  ' A screen-space AABB plus a camera-relative depth range, both derived from the same
  ' set of world-space bounding points a SceneObject already computes for its frustum
  ' check (getPositionsForFrustumCheck) - the broad phase of overlap detection reuses
  ' that geometry rather than computing anything new.
  interface ScreenBounds
    minX as float
    maxX as float
    minY as float
    maxY as float
    minDepth as float
    maxDepth as float
  end interface

  ' Projects a set of world-space points into a ScreenBounds: a screen-space AABB (via
  ' the renderer's own camera projection) and a depth range (via the camera's
  ' distanceFromCameraFront, the same function SceneObject.update() already calls once
  ' per object - here called once per bounding point instead).
  '
  ' @param {BGE.Math.Vector[]} worldPoints
  ' @param {BGE.Renderer} rendererObj
  ' @return {ScreenBounds}
  function getScreenBounds(worldPoints as BGE.Math.Vector[], rendererObj as BGE.Renderer) as ScreenBounds
    canvasPoints = []
    depths = []
    for each worldPoint in worldPoints
      canvasPoint = rendererObj.worldPointToCanvasPoint(worldPoint)
      if invalid <> canvasPoint
        canvasPoints.push(canvasPoint)
      end if
      depths.push(rendererObj.camera.distanceFromCameraFront(worldPoint))
    end for

    screenBoundPoints = BGE.Math.getBounds(canvasPoints)
    minDepth = depths[0]
    maxDepth = depths[0]
    for each depth in depths
      minDepth = BGE.Math.Min(minDepth, depth)
      maxDepth = BGE.Math.Max(maxDepth, depth)
    end for

    if screenBoundPoints.count() < 2
      return {minX: 0.0, maxX: 0.0, minY: 0.0, maxY: 0.0, minDepth: minDepth, maxDepth: maxDepth}
    end if

    return {
      minX: screenBoundPoints[0].x,
      maxX: screenBoundPoints[1].x,
      minY: screenBoundPoints[0].y,
      maxY: screenBoundPoints[1].y,
      minDepth: minDepth,
      maxDepth: maxDepth
    }
  end function

  ' Whether two ScreenBounds overlap in both screen space and depth - the broad-phase
  ' overlap test. Deliberately loose (an AABB overexpands for a rotated/diagonal
  ' shape) - true here only means "worth the narrow-phase check", not "these objects
  ' actually need to interleave".
  '
  ' @param {ScreenBounds} a
  ' @param {ScreenBounds} b
  ' @return {boolean}
  function boundsOverlap(a as ScreenBounds, b as ScreenBounds) as boolean
    xOverlap = a.minX <= b.maxX and b.minX <= a.maxX
    yOverlap = a.minY <= b.maxY and b.minY <= a.maxY
    depthOverlap = a.minDepth <= b.maxDepth and b.minDepth <= a.maxDepth
    return xOverlap and yOverlap and depthOverlap
  end function

end namespace
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `npm run test:ci`
Expected: PASS.

- [ ] **Step 5: Run validate**

Run: `npm run validate`
Expected: no errors.

- [ ] **Step 6: Commit**

```bash
git add src/source/engine/renderer/DepthSortHelpers.bs src/source/engine/renderer/DepthSortHelpers.spec.bs
git commit -m "Add broad-phase (AABB + depth range) overlap test (#59)"
```

---

### Task 4: Narrow-phase overlap test (SAT via quickhull)

**Files:**
- Modify: `src/source/engine/renderer/DepthSortHelpers.bs`
- Test: `src/source/engine/renderer/DepthSortHelpers.spec.bs`

**Interfaces:**
- Consumes: `BGE.QuickHull(pointsArray as BGE.Math.Vector[]) as BGE.Math.Vector[]` (existing, `src/source/utils/quickhull.bs` - returns the convex hull of a set of 2D points, in order).
- Produces: `BGE.DepthSort.hullsOverlap(hullA as BGE.Math.Vector[], hullB as BGE.Math.Vector[]) as boolean`. Task 5 (cluster grouping) consumes this as the narrow-phase check.

- [ ] **Step 1: Write the failing tests**

Add to `src/source/engine/renderer/DepthSortHelpers.spec.bs`, a new `@describe` block:

```brightscript
    @describe("hullsOverlap (narrow phase - separating axis theorem)")

    @it("returns true for two overlapping squares")
    function _()
      squareA = [
        BGE.Math.VectorOps.create(0, 0),
        BGE.Math.VectorOps.create(10, 0),
        BGE.Math.VectorOps.create(10, 10),
        BGE.Math.VectorOps.create(0, 10)
      ]
      squareB = [
        BGE.Math.VectorOps.create(5, 5),
        BGE.Math.VectorOps.create(15, 5),
        BGE.Math.VectorOps.create(15, 15),
        BGE.Math.VectorOps.create(5, 15)
      ]
      m.assertTrue(BGE.DepthSort.hullsOverlap(squareA, squareB))
    end function

    @it("returns false for two separated squares, even when their AABBs would overlap")
    function _()
      ' A thin diagonal "wall" from (0,0) to (100,100) has an AABB covering the whole
      ' 100x100 area - a small square sitting in the empty corner of that AABB (e.g.
      ' near (90, 10)) must not be reported as overlapping the wall itself.
      diagonalWall = [
        BGE.Math.VectorOps.create(-2, 2),
        BGE.Math.VectorOps.create(2, -2),
        BGE.Math.VectorOps.create(102, 98),
        BGE.Math.VectorOps.create(98, 102)
      ]
      nearbySquare = [
        BGE.Math.VectorOps.create(85, 5),
        BGE.Math.VectorOps.create(95, 5),
        BGE.Math.VectorOps.create(95, 15),
        BGE.Math.VectorOps.create(85, 15)
      ]
      m.assertFalse(BGE.DepthSort.hullsOverlap(diagonalWall, nearbySquare))
    end function

    @it("returns false for two squares that share only a touching edge's exterior, no interior overlap")
    function _()
      squareA = [
        BGE.Math.VectorOps.create(0, 0),
        BGE.Math.VectorOps.create(10, 0),
        BGE.Math.VectorOps.create(10, 10),
        BGE.Math.VectorOps.create(0, 10)
      ]
      squareB = [
        BGE.Math.VectorOps.create(20, 0),
        BGE.Math.VectorOps.create(30, 0),
        BGE.Math.VectorOps.create(30, 10),
        BGE.Math.VectorOps.create(20, 10)
      ]
      m.assertFalse(BGE.DepthSort.hullsOverlap(squareA, squareB))
    end function
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `npm run test:ci`
Expected: FAIL - `hullsOverlap` is not a member of `BGE.DepthSort`.

- [ ] **Step 3: Write `hullsOverlap`**

Add to `src/source/engine/renderer/DepthSortHelpers.bs`, inside the `namespace BGE.DepthSort` block:

```brightscript
  ' Separating-axis theorem (SAT) test between two convex 2D polygons (already-computed
  ' hulls - a billboard's 4 corners, or a model's bounding-cube projection reduced to
  ' its convex hull via BGE.QuickHull). Two convex shapes overlap unless there exists
  ' an axis (perpendicular to one of either shape's edges) that separates them - so
  ' this checks every candidate axis from both shapes and returns false the moment one
  ' actually separates them.
  '
  ' @param {BGE.Math.Vector[]} hullA points in perimeter order
  ' @param {BGE.Math.Vector[]} hullB points in perimeter order
  ' @return {boolean} true if the two convex shapes overlap
  function hullsOverlap(hullA as BGE.Math.Vector[], hullB as BGE.Math.Vector[]) as boolean
    if hullA.count() < 2 or hullB.count() < 2
      return true ' degenerate shape - can't prove separation, so don't false-negative
    end if
    for each axis in getEdgeNormals(hullA)
      if isSeparatingAxis(axis, hullA, hullB)
        return false
      end if
    end for
    for each axis in getEdgeNormals(hullB)
      if isSeparatingAxis(axis, hullA, hullB)
        return false
      end if
    end for
    return true
  end function

  private function getEdgeNormals(hull as BGE.Math.Vector[]) as BGE.Math.Vector[]
    normals = []
    for i = 0 to hull.count() - 1
      p1 = hull[i]
      p2 = hull[(i + 1) mod hull.count()]
      edge = BGE.Math.VectorOps.subtract(p2, p1)
      ' perpendicular to the edge, in 2D: (x, y) -> (-y, x)
      normals.push(BGE.Math.VectorOps.create(-edge.y, edge.x))
    end for
    return normals
  end function

  private function isSeparatingAxis(axis as BGE.Math.Vector, hullA as BGE.Math.Vector[], hullB as BGE.Math.Vector[]) as boolean
    projA = projectHull(axis, hullA)
    projB = projectHull(axis, hullB)
    return projA.max < projB.min or projB.max < projA.min
  end function

  private function projectHull(axis as BGE.Math.Vector, hull as BGE.Math.Vector[]) as {min as float, max as float}
    minProj = (axis.x * hull[0].x) + (axis.y * hull[0].y)
    maxProj = minProj
    for each point in hull
      proj = (axis.x * point.x) + (axis.y * point.y)
      minProj = BGE.Math.Min(minProj, proj)
      maxProj = BGE.Math.Max(maxProj, proj)
    end for
    return {min: minProj, max: maxProj}
  end function
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `npm run test:ci`
Expected: PASS.

- [ ] **Step 5: Run validate**

Run: `npm run validate`
Expected: no errors.

- [ ] **Step 6: Commit**

```bash
git add src/source/engine/renderer/DepthSortHelpers.bs src/source/engine/renderer/DepthSortHelpers.spec.bs
git commit -m "Add narrow-phase (SAT) overlap test (#59)"
```

---

### Task 5: Per-frame cluster grouping, exposed read-only from Renderer

**Files:**
- Modify: `src/source/engine/renderer/DepthSortHelpers.bs`
- Modify: `src/source/engine/renderer/Renderer.bs`
- Modify: `src/source/engine/renderer/sceneObjects/SceneObject.bs` (expose the hull points a `SceneObject` already computes)
- Test: `src/source/engine/renderer/DepthSortHelpers.spec.bs`, `src/source/engine/renderer/Renderer.spec.bs`

**Interfaces:**
- Consumes: `BGE.DepthSort.getScreenBounds`/`boundsOverlap` (Task 3), `BGE.DepthSort.hullsOverlap` (Task 4), `SceneObject.getPositionsForFrustumCheck(drawMode) as BGE.Math.Vector[]` (existing, protected - needs a public wrapper for cross-object narrow-phase use, see Step 3).
- Produces: `BGE.DepthSort.groupIntoClusters(objects as BGE.SceneObject[], rendererObj as BGE.Renderer) as BGE.SceneObject[][]` (returns each cluster as an array of the SceneObjects in it - clusters of size 1 are the common case). `Renderer.getOverlapClusters() as BGE.SceneObject[][]` - computed once per frame in `drawScene()`, cached, and exposed for the example in Task 8 to visualize. **This task does not change what gets drawn or how** - `drawScene()`'s actual draw passes are untouched; clusters are computed purely for reporting.

- [ ] **Step 1: Write the failing tests**

Add to `src/source/engine/renderer/DepthSortHelpers.spec.bs`, a new `@describe` block (needs a real `Game`/`GameEntity` to build real `SceneObject`s, so add `game`/`entity`-style setup to this suite's existing `beforeEach` - extend it rather than adding a second one, per the one-suite-per-file rule):

```brightscript
    @describe("groupIntoClusters")

    @it("puts two non-overlapping objects in their own single-member clusters")
    function _()
      game = new BGE.Game(320, 240)
      entityA = new BGE.GameEntity(game, {name: "A"})
      entityA.position = BGE.Math.VectorOps.create(-200, 0, 0)
      entityB = new BGE.GameEntity(game, {name: "B"})
      entityB.position = BGE.Math.VectorOps.create(200, 0, 0)
      rectA = new BGE.DrawableRectangle(entityA, 20, 20)
      rectB = new BGE.DrawableRectangle(entityB, 20, 20)
      sceneObjA = rectA.addToScene(m.renderer)
      sceneObjB = rectB.addToScene(m.renderer)
      entityA.updateTransformationMatrix()
      entityB.updateTransformationMatrix()
      m.renderer.setupCameraForFrame()
      sceneObjA.update(m.renderer.camera)
      sceneObjB.update(m.renderer.camera)

      clusters = BGE.DepthSort.groupIntoClusters([sceneObjA, sceneObjB], m.renderer)
      m.assertEqual(2, clusters.count())
    end function

    @it("puts two overlapping objects in the same cluster")
    function _()
      game = new BGE.Game(320, 240)
      entityA = new BGE.GameEntity(game, {name: "A"})
      entityA.position = BGE.Math.VectorOps.create(-5, 0, 0)
      entityB = new BGE.GameEntity(game, {name: "B"})
      entityB.position = BGE.Math.VectorOps.create(5, 0, 0)
      rectA = new BGE.DrawableRectangle(entityA, 20, 20)
      rectB = new BGE.DrawableRectangle(entityB, 20, 20)
      sceneObjA = rectA.addToScene(m.renderer)
      sceneObjB = rectB.addToScene(m.renderer)
      entityA.updateTransformationMatrix()
      entityB.updateTransformationMatrix()
      m.renderer.setupCameraForFrame()
      sceneObjA.update(m.renderer.camera)
      sceneObjB.update(m.renderer.camera)

      clusters = BGE.DepthSort.groupIntoClusters([sceneObjA, sceneObjB], m.renderer)
      m.assertEqual(1, clusters.count())
      m.assertEqual(2, clusters[0].count())
    end function
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `npm run test:ci`
Expected: FAIL - `groupIntoClusters` is not a member of `BGE.DepthSort`.

- [ ] **Step 3: Expose a public hull accessor on `SceneObject`**

`getPositionsForFrustumCheck` is `protected`, so `DepthSort.groupIntoClusters` (a plain namespace function, not a `SceneObject` method) can't call it directly across objects. In `src/source/engine/renderer/sceneObjects/SceneObject.bs`, add a public wrapper right after the existing `getPositionsForFrustumCheck` declaration:

```brightscript
    ' Public wrapper around getPositionsForFrustumCheck(), for cross-object callers
    ' (e.g. BGE.DepthSort's overlap detection) that need this object's own bounding
    ' points but aren't a SceneObject subclass themselves.
    '
    ' @param {Camera} cameraObj
    ' @return {BGE.Math.Vector[]}
    function getBoundingPoints(cameraObj as Camera) as BGE.Math.Vector[]
      return m.getPositionsForFrustumCheck(m.getActualDrawMode(cameraObj))
    end function
```

- [ ] **Step 4: Write `groupIntoClusters`**

Add to `src/source/engine/renderer/DepthSortHelpers.bs`:

```brightscript
  ' Groups objects into overlap clusters: connected components over the "these two
  ' objects' bounds overlap" relation (broad phase, then narrow phase to reject false
  ' positives). Most objects end up alone in a cluster of one - only objects that
  ' mutually, genuinely overlap end up grouped together.
  '
  ' @param {BGE.SceneObject[]} objects
  ' @param {BGE.Renderer} rendererObj
  ' @return {BGE.SceneObject[][]} each cluster as an array of its member SceneObjects
  function groupIntoClusters(objects as BGE.SceneObject[], rendererObj as BGE.Renderer) as object
    screenBoundsByIndex = []
    hullByIndex = []
    for each obj in objects
      boundingPoints = obj.getBoundingPoints(rendererObj.camera)
      screenBoundsByIndex.push(getScreenBounds(boundingPoints, rendererObj))
      hull = BGE.QuickHull(projectPointsToScreen(boundingPoints, rendererObj))
      hullByIndex.push(hull)
    end for

    ' Union-find over object indices.
    parent = []
    for i = 0 to objects.count() - 1
      parent.push(i)
    end for

    for i = 0 to objects.count() - 1
      for j = i + 1 to objects.count() - 1
        if boundsOverlap(screenBoundsByIndex[i], screenBoundsByIndex[j])
          if hullsOverlap(hullByIndex[i], hullByIndex[j])
            union(parent, i, j)
          end if
        end if
      end for
    end for

    clustersByRoot = {}
    for i = 0 to objects.count() - 1
      root = find(parent, i).toStr()
      if invalid = clustersByRoot[root]
        clustersByRoot[root] = []
      end if
      clustersByRoot[root].push(objects[i])
    end for

    clusters = []
    for each item in clustersByRoot.items()
      clusters.push(item.value)
    end for
    return clusters
  end function

  private function projectPointsToScreen(worldPoints as BGE.Math.Vector[], rendererObj as BGE.Renderer) as BGE.Math.Vector[]
    canvasPoints = []
    for each worldPoint in worldPoints
      canvasPoint = rendererObj.worldPointToCanvasPoint(worldPoint)
      if invalid <> canvasPoint
        canvasPoints.push(canvasPoint)
      end if
    end for
    return canvasPoints
  end function

  private function find(parent as object, i as integer) as integer
    if parent[i] <> i
      parent[i] = find(parent, parent[i])
    end if
    return parent[i]
  end function

  private sub union(parent as object, i as integer, j as integer)
    rootI = find(parent, i)
    rootJ = find(parent, j)
    if rootI <> rootJ
      parent[rootI] = rootJ
    end if
  end sub
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `npm run test:ci`
Expected: PASS.

- [ ] **Step 6: Wire cluster computation into `Renderer`, exposed read-only**

In `src/source/engine/renderer/Renderer.bs`, add a private field and public accessor:

```brightscript
    private overlapClusters as object = []
```

In `drawScene()`, after `m.updateSceneObjects()` (before the sort), add:

```brightscript
      m.overlapClusters = BGE.DepthSort.groupIntoClusters(m.sceneObjects, m)
```

Add the public accessor near `getSceneObjectCount()`:

```brightscript
    ' This frame's overlap clusters - most objects are alone in a cluster of one.
    ' Computed every frame for now (Plan 2 will use this to decide caching/draw
    ' behavior; for now it's purely diagnostic/visualized by examples/depthsort).
    '
    ' @return {BGE.SceneObject[][]} each cluster as an array of its member SceneObjects
    function getOverlapClusters() as object
      return m.overlapClusters
    end function
```

Add a test to `Renderer.spec.bs` confirming the wiring (not re-testing the clustering logic itself, which Task 5's own tests already cover):

```brightscript
    @describe("getOverlapClusters")

    @it("reports every scene object in its own cluster when nothing overlaps")
    function _()
      entityA = new BGE.GameEntity(new BGE.Game(320, 240), {name: "A"})
      entityA.position = BGE.Math.VectorOps.create(-200, 0, 0)
      rectA = new BGE.DrawableRectangle(entityA, 20, 20)
      rectA.addToScene(m.renderer)
      entityA.updateTransformationMatrix()
      m.renderer.setupCameraForFrame()
      m.renderer.drawScene()

      m.assertEqual(1, m.renderer.getOverlapClusters().count())
    end function
```

- [ ] **Step 7: Run tests to verify they pass**

Run: `npm run test:ci`
Expected: PASS.

- [ ] **Step 8: Run validate**

Run: `npm run validate`
Expected: no errors.

- [ ] **Step 9: Commit**

```bash
git add src/source/engine/renderer/DepthSortHelpers.bs src/source/engine/renderer/DepthSortHelpers.spec.bs src/source/engine/renderer/Renderer.bs src/source/engine/renderer/Renderer.spec.bs src/source/engine/renderer/sceneObjects/SceneObject.bs
git commit -m "Compute per-frame overlap clusters, exposed read-only from Renderer (#59)"
```

---

### Task 6: Scaffold `examples/depthsort`

**Files:**
- Create: `examples/depthsort/` (via `npm run create-example`)

**Interfaces:** none - this task only produces the scaffold Tasks 7-8 build on.

- [ ] **Step 1: Scaffold the example**

Run: `npm run create-example -- depthsort "Depth Sort"`

Expected: creates `examples/depthsort/` with a manifest, `bsconfig.json`, generated icon/splash images, a minimal `MainRoom`, and registers it in the root `.vscode/tasks.json` example picker.

- [ ] **Step 2: Install its dependencies and confirm it builds as scaffolded**

Run: `cd examples/depthsort && npm install && npm run build`
Expected: no errors.

- [ ] **Step 3: Commit**

```bash
cd /path/to/repo/root
git add examples/depthsort .vscode/tasks.json
git commit -m "Scaffold examples/depthsort (#59)"
```

---

### Task 7: `Camera2d` room demonstrating the tie-break fix

**Files:**
- Modify: `examples/depthsort/src/source/main.bs`
- Create: `examples/depthsort/src/source/Rooms/TieBreakRoom.bs`
- Create: `examples/depthsort/src/source/Entities/RowEntity.bs`

**Interfaces:**
- Consumes: `BGE.Renderer.didSortLastFrame() as boolean` (Task 1), `BGE.DrawableRectangle` (existing).
- Produces: nothing later tasks depend on - this is a leaf demo room.

- [ ] **Step 1: Write `RowEntity`**

Create `examples/depthsort/src/source/Entities/RowEntity.bs`:

```brightscript
' One rectangle in a row of coplanar (or near-coplanar) entities - used to show off
' stable tie-breaking. Each one jitters its own z position by a tiny sub-epsilon amount
' every frame, simulating the floating-point noise that used to cause visible
' order-swapping between equal-depth objects.
class RowEntity extends BGE.GameEntity

  baseZ = 0.0
  jitterPhase = 0.0

  sub new(game as BGE.Game)
    super(game)
    m.name = "RowEntity"
  end sub

  override sub onCreate(args as roAssociativeArray)
    m.position.x = args.x
    m.position.y = args.y
    m.baseZ = args.z
    m.jitterPhase = Rnd(0) * 6.28
    m.addRectangle("body", 60, 60, {color: args.color})
  end sub

  override sub onUpdate(deltaTime as float)
    ' Sub-epsilon jitter - smaller than Renderer.DEPTH_TIE_EPSILON, so this must never
    ' visibly reorder the row once the tie-break fix is in place.
    m.position.z = m.baseZ + (sin(m.jitterPhase + (m.game.getTotalTime() * 3)) * 0.1)
  end sub

end class
```

- [ ] **Step 2: Write `TieBreakRoom`**

Create `examples/depthsort/src/source/Rooms/TieBreakRoom.bs`:

```brightscript
' Demonstrates stable tie-breaking: a row of same-depth entities that each jitter their
' own z position by a tiny sub-epsilon amount every frame. Before the fix, this jitter
' alone was enough to cause visible left-right swapping between neighbors, purely from
' floating-point noise crossing zero - nothing here is actually changing depth order.
class TieBreakRoom extends BGE.Room

  rowEntities = []

  sub new(game as BGE.Game)
    super(game)
    m.name = "TieBreakRoom"
  end sub

  override sub onCreate(args as roAssociativeArray)
    colors = [BGE.ColorsRGB.Red, BGE.ColorsRGB.Orange, BGE.ColorsRGB.Yellow, BGE.ColorsRGB.Lime, BGE.ColorsRGB.Cyan, BGE.ColorsRGB.Blue]
    centerX = m.game.canvas.getWidth() / 2
    centerY = m.game.canvas.getHeight() / 2
    spacing = 90
    startX = centerX - (spacing * (colors.count() - 1) / 2)
    for i = 0 to colors.count() - 1
      entity = new RowEntity(m.game)
      m.game.addEntity(entity, {x: startX + (i * spacing), y: centerY, z: 0, color: colors[i]})
      m.rowEntities.push(entity)
    end for
  end sub

  override sub onInput(input as BGE.GameInput)
    if input.press and input.isButton("back")
      m.game.end()
    end if
  end sub

  override sub onGameEvent(event as string, data as object)
  end sub

  override sub onChangeRoom(newRoom as BGE.Room)
  end sub

end class
```

- [ ] **Step 3: Wire it into `main.bs`**

Modify `examples/depthsort/src/source/main.bs` to define and start `TieBreakRoom`:

```brightscript
sub main()
  game = new BGE.Game(1280, 720)
  game.fitCanvasToScreen()

  tieBreakRoom = new TieBreakRoom(game)
  game.defineRoom(tieBreakRoom)

  game.changeRoom("TieBreakRoom")
  game.enableStandardDebugUi()
  game.debugShowUi(true)
  game.Play()
end sub
```

- [ ] **Step 4: Build and validate**

Run: `cd examples/depthsort && npm run build`
Expected: no errors.

- [ ] **Step 5: Commit**

```bash
cd /path/to/repo/root
git add examples/depthsort/src/source/Entities/RowEntity.bs examples/depthsort/src/source/Rooms/TieBreakRoom.bs examples/depthsort/src/source/main.bs
git commit -m "Add TieBreakRoom to examples/depthsort (#59)"
```

---

### Task 8: `Camera3d` room visualizing overlap clusters

**Files:**
- Modify: `examples/depthsort/src/source/main.bs`
- Create: `examples/depthsort/src/source/Rooms/ClusterVisualizerRoom.bs`
- Create: `examples/depthsort/src/source/Entities/ClusterProbeEntity.bs`

**Interfaces:**
- Consumes: `BGE.Renderer.getOverlapClusters() as object` (Task 5), `BGE.Camera3d` (existing), `BGE.DrawableRectangle`/`BGE.Model3d` (existing).

- [ ] **Step 1: Write `ClusterProbeEntity`**

Create `examples/depthsort/src/source/Entities/ClusterProbeEntity.bs` - a labeled panel whose outline color reflects whether it's currently in a multi-member cluster:

```brightscript
' A DrawableRectangle panel whose outline turns red when it's part of a multi-member
' overlap cluster this frame (per Renderer.getOverlapClusters()), and stays its default
' color when it's alone. Used to visualize cluster detection directly - see
' ClusterVisualizerRoom.
class ClusterProbeEntity extends BGE.GameEntity

  panel as BGE.DrawableRectangle

  sub new(game as BGE.Game)
    super(game)
    m.name = "ClusterProbeEntity"
  end sub

  override sub onCreate(args as roAssociativeArray)
    m.panel = m.addRectangle("panel", args.size, args.size, {
      color: args.color,
      offset: BGE.Math.VectorOps.create(-args.size / 2, args.size / 2, 0),
      outlineRGBA: BGE.ColorsRGB.White,
      outlineWidth: 2
    })
  end sub

  override sub onUpdate(deltaTime as float)
    isClustered = false
    for each cluster in m.game.canvas.renderer.getOverlapClusters()
      if cluster.count() > 1
        for each sceneObj in cluster
          if sceneObj.drawable = m.panel
            isClustered = true
          end if
        end for
      end if
    end for
    if isClustered
      m.panel.outlineRGBA = BGE.ColorsRGB.Red
    else
      m.panel.outlineRGBA = BGE.ColorsRGB.White
    end if
  end sub

end class
```

- [ ] **Step 2: Write `ClusterVisualizerRoom`**

Create `examples/depthsort/src/source/Rooms/ClusterVisualizerRoom.bs` - includes the specific wall-vs-nearby-model false-positive scenario the design spec calls out:

```brightscript
' Visualizes overlap-cluster detection directly: each ClusterProbeEntity's outline
' turns red when Renderer.getOverlapClusters() reports it's grouped with something
' this frame. Two deliberately overlapping panels should both turn red; a third,
' separated panel should stay white. A tall diagonal panel (standing in for a wall)
' with a small panel positioned near it but not touching demonstrates the narrow phase
' correctly keeping them un-clustered despite their AABBs overlapping - the false-
' positive case the design's broad+narrow phase split exists to avoid.
'
' This room only visualizes clustering - it does not yet change draw order (that's
' Plan 2). Arrow keys move the camera; Play toggles debug info.
class ClusterVisualizerRoom extends BGE.Room

  cameraSpeed = 300
  cameraVelocity = 0
  cameraRotation = 0

  sub new(game as BGE.Game)
    super(game)
    m.name = "ClusterVisualizerRoom"
  end sub

  override sub onCreate(args as roAssociativeArray)
    ' Two overlapping panels - both should show a red outline.
    m.game.addEntity(new ClusterProbeEntity(m.game), {size: 150, color: BGE.ColorsRGB.Red}).position = BGE.Math.VectorOps.create(-50, 0, 300)
    m.game.addEntity(new ClusterProbeEntity(m.game), {size: 150, color: BGE.ColorsRGB.Cyan}).position = BGE.Math.VectorOps.create(50, 0, 300)

    ' A separated panel - should stay white.
    m.game.addEntity(new ClusterProbeEntity(m.game), {size: 100, color: BGE.ColorsRGB.Lime}).position = BGE.Math.VectorOps.create(500, 0, 300)

    ' The wall-vs-nearby-model false-positive check: a tall diagonal panel and a small
    ' panel near it but not touching - both should stay white despite overlapping AABBs.
    wall = m.game.addEntity(new ClusterProbeEntity(m.game), {size: 400, color: BGE.ColorsRGB.Gray})
    wall.position = BGE.Math.VectorOps.create(-500, 0, 300)
    wall.rotation.z = 0.785 ' 45 degrees - a diagonal wall, wide AABB
    m.game.addEntity(new ClusterProbeEntity(m.game), {size: 60, color: BGE.ColorsRGB.Yellow}).position = BGE.Math.VectorOps.create(-350, 150, 300)
  end sub

  override sub onUpdate(dt as float)
    if m.cameraRotation <> 0
      m.game.canvas.renderer.camera.rotate(BGE.Math.VectorOps.create(0, m.cameraRotation * dt, 0))
    end if
    if m.cameraVelocity <> 0
      BGE.Math.VectorOps.plusEquals(m.game.canvas.renderer.camera.position,
      BGE.Math.VectorOps.scale(m.game.canvas.renderer.camera.orientation, m.cameraSpeed * dt * m.cameraVelocity))
    end if
  end sub

  override sub onInput(input as BGE.GameInput)
    if input.x <> 0 or input.y <> 0
      m.cameraVelocity = input.y
      m.cameraRotation = input.x
    else
      m.cameraVelocity = 0
      m.cameraRotation = 0
    end if
    if input.press and input.isButton("back")
      m.game.end()
    end if
  end sub

  override sub onGameEvent(event as string, data as object)
  end sub

  override sub onChangeRoom(newRoom as BGE.Room)
  end sub

end class
```

- [ ] **Step 3: Wire both rooms into `main.bs` with room switching**

Replace `examples/depthsort/src/source/main.bs` with:

```brightscript
sub main()
  game = new BGE.Game(1280, 720)
  game.fitCanvasToScreen()
  game.setCamera(new BGE.Camera3d())

  tieBreakRoom = new TieBreakRoom(game)
  game.defineRoom(tieBreakRoom)

  clusterVisualizerRoom = new ClusterVisualizerRoom(game)
  game.defineRoom(clusterVisualizerRoom)

  game.changeRoom(getRoomNames()[0])
  game.enableStandardDebugUi()
  game.debugShowUi(true)
  game.Play()
end sub

function getRoomNames() as string[]
  return ["TieBreakRoom", "ClusterVisualizerRoom"]
end function

sub goToNextRoom(currentRoom as BGE.Room, direction as integer)
  currentIndex = 0
  i = 0
  roomNames = getRoomNames()
  for each name in roomNames
    if currentRoom.name = name
      currentIndex = i
      exit for
    end if
    i++
  end for

  nextIndex = currentIndex + direction
  if nextIndex >= roomNames.count()
    nextIndex = 0
  else if nextIndex < 0
    nextIndex = roomNames.count() - 1
  end if

  currentRoom.game.changeRoom(roomNames[nextIndex])
end sub
```

Add `fastforward`/`rewind` handling (via `goToNextRoom`) to both `TieBreakRoom.onInput` and `ClusterVisualizerRoom.onInput` from Tasks 7-8, following the exact pattern every other multi-room example (`examples/pixels`, `examples/3d`) already uses:

```brightscript
    else if input.isButton("fastforward")
      goToNextRoom(m, 1)
    else if input.isButton("rewind")
      goToNextRoom(m, -1)
```

- [ ] **Step 4: Build and validate**

Run: `cd examples/depthsort && npm run build`
Expected: no errors.

- [ ] **Step 5: Commit**

```bash
cd /path/to/repo/root
git add examples/depthsort/
git commit -m "Add ClusterVisualizerRoom to examples/depthsort, including the wall/model false-positive check (#59)"
```

---

### Task 9: Final validation, on-device measurement, and docs

**Files:**
- Modify: `CLAUDE.md`

**Interfaces:** none - this task only validates and documents what Tasks 1-8 already built.

- [ ] **Step 1: Run the full quality gate**

Run: `npm run check`
Expected: lint, validate, and headless tests all pass.

- [ ] **Step 2: Validate every example still builds**

Run: `npm run validate-examples`
Expected: no errors, including `examples/depthsort`.

- [ ] **Step 3: Sideload and measure on-device, per the spec's testing section**

Follow the `rokubot-examples` skill workflow. Sideload `examples/depthsort`, and for `ClusterVisualizerRoom` specifically with a representative entity count (e.g. temporarily bump the room to add 30-50 `ClusterProbeEntity` instances scattered around), compare `Renderer.getDrawCallsLastFrame()`/on-screen FPS against the same scene with clustering disabled (a quick local `#if false`-style toggle is fine for this one measurement, not a permanent feature) to confirm the broad-phase `O(n²)` cost is actually cheap at that count, not just assumed to be. Record the result in the PR description - if the cost turns out non-trivial at realistic entity counts, that's a real finding to flag before Plan 2 builds on top of it, not something to silently absorb.

- [ ] **Step 4: Update `CLAUDE.md`**

In the "Renderer / SceneObjects" section, add a bullet documenting the new `BGE.DepthSort` namespace, the skip-sort/tie-break fixes, and cross-reference `specs/2026-08-15-depth-sort-design.md` and `examples/depthsort`.

- [ ] **Step 5: Commit**

```bash
git add CLAUDE.md
git commit -m "Document depth-sort prerequisites and overlap detection in CLAUDE.md (#59)"
```

- [ ] **Step 6: Open the PR**

Push the branch and open a PR against `main` referencing #59, summarizing the skip-sort/tie-break fixes and the overlap-detection capability, linking the design spec, and noting that Plan 2 (the actual clustered-draw behavior change) is a deliberate follow-up, not part of this PR.
