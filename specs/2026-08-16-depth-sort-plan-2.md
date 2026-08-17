# Depth Sort Plan 2: Sort-and-Sweep Broad Phase + Clustered Draw Order Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current all-pairs `O(n^2)` overlap-cluster broad phase with sort-and-sweep
(fixing a measured ~70% FPS regression at ~176 objects), then build the actual clustered
primitive-interleaving draw behavior Plan 1 deferred, on top of that now-cheap foundation.

**Architecture:** Part A rewrites `BGE.DepthSort.groupIntoClusters()`'s internals to sort
candidates by screen-space `minX` (incrementally, reusing last frame's order) and sweep for
X-overlapping pairs instead of testing every pair. Part B adds a `getPrimitiveCount()`/
`getPrimitiveDepth()`/`drawPrimitive()` contract to `SceneObject`, defaulting to "1 primitive, my
whole self" (correct as-is for every billboard type with zero code changes), overridden by
`SceneObjectModel` to expose its per-face list. `Renderer.drawScene()` defers a multi-member
cluster's members to a combined per-frame primitive list, sorted once and drawn interleaved: a
solo cluster (unchanged, still the common case) draws exactly as it does today. Part C fixes the
pre-existing `QuickHull([])` bug this plan's own broad-phase code touches again.

**Tech Stack:** BrighterScript, Rooibos tests, `rokubot` for on-device verification.

**Spec:** [specs/2026-08-16-depth-sort-plan-2-design.md](2026-08-16-depth-sort-plan-2-design.md)
(and the original [specs/2026-08-15-depth-sort-design.md](2026-08-15-depth-sort-design.md)
this continues from).

## Global Constraints

- One `@suite` class per `*.spec.bs` file - Rooibos v6 corrupts test data with two or more in the
  same file. `DepthSortHelpers.spec.bs` already has one (`DepthSortBroadPhaseTests`) - add new
  tests as new `@it` blocks inside it, never a second `@suite` class.
- `private function`/`private sub` is only valid as a class member in this codebase's BrighterScript
  version - never at bare namespace scope (confirmed via whole-codebase grep during Plan 1).
  `DepthSortHelpers.bs`'s existing namespace-scope helper functions are plain (no `private`
  keyword) for this reason - follow the same pattern for any new namespace-scope function.
- `assertEqual` is type-strict (Integer vs Float fail against each other) - match the literal
  type a value actually carries, not just its declared field type. When unsure, run the test once
  and read the actual/expected types from the failure diff.
- JSDoc-style `'` comments (`@param`, `@return`) directly above every new public engine method -
  pulled into generated docs via `brighterscript-jsdocs-plugin`.
- `Renderer.computeOverlapClusters` stays `false` by default through this entire plan - nothing
  here changes who opts in, only what opting in costs and what it now visibly does.
- On-device verification via `rokubot` (see `.claude/skills/rokubot-examples/SKILL.md`) is
  **mandatory** before either Part A or Part B's own validation task is considered done - Plan 1
  shipped code that a full `npm run check` pass and two independent code reviews approved, and
  that still crashed/misbehaved the moment it actually ran on hardware. Static analysis passing is
  necessary, not sufficient, anywhere in this plan.

---

### Task 1: Fix `QuickHull([])` returning `[invalid, invalid]` instead of `[]` (#109)

**Files:**
- Modify: `src/source/utils/quickhull.bs`
- Test: `src/source/utils/quickhull.spec.bs` (create if it doesn't exist yet - check first)

**Interfaces:** none - this is a self-contained bugfix, independent of every other task in this plan.

- [ ] **Step 1: Check whether a spec file already exists**

Run: `ls src/source/utils/quickhull.spec.bs` (or `find src/source/utils -iname "quickhull.spec.bs"`).

- [ ] **Step 2: Write the failing test(s)**

If `quickhull.spec.bs` already exists, add these as new `@it` blocks inside its existing `@suite`
class (do NOT create a second `@suite` class). If it doesn't exist, create it with exactly this
`@suite` class:

```brightscript
namespace tests

  @suite("BGE.QuickHull")
  class QuickHullTests extends rooibos.BaseTestSuite

    @describe("QuickHull")

    @it("returns an empty array for empty input, not [invalid, invalid]")
    function _()
      result = BGE.QuickHull.QuickHull([])
      m.assertEqual(0, result.count())
    end function

    @it("returns the input unchanged for 1 point")
    function _()
      points = [BGE.Math.VectorOps.create(1, 2)]
      result = BGE.QuickHull.QuickHull(points)
      m.assertEqual(1, result.count())
      m.assertEqual(1.0, result[0].x)
      m.assertEqual(2.0, result[0].y)
    end function

    @it("returns the input unchanged for 2 points")
    function _()
      points = [BGE.Math.VectorOps.create(1, 2), BGE.Math.VectorOps.create(3, 4)]
      result = BGE.QuickHull.QuickHull(points)
      m.assertEqual(2, result.count())
    end function

    @it("still returns the input unchanged for exactly 3 points (pre-existing behavior)")
    function _()
      points = [BGE.Math.VectorOps.create(0, 0), BGE.Math.VectorOps.create(10, 0), BGE.Math.VectorOps.create(0, 10)]
      result = BGE.QuickHull.QuickHull(points)
      m.assertEqual(3, result.count())
    end function

  end class

end namespace
```

- [ ] **Step 3: Run the tests to verify the first two fail**

Run: `npm run build-tests && npm run test:ci`
Expected: the "empty array" and "1 point" tests FAIL (current behavior returns `[invalid, invalid]`
for empty input, and likely mishandles 1 point too - the 2-point and 3-point tests should already
pass unchanged).

- [ ] **Step 4: Fix `QuickHull()`**

In `src/source/utils/quickhull.bs`, find the `QuickHull` function (the one with the existing
`if pointsArray.count() = 3` early-return). Add a new guard immediately above it:

```brightscript
    ' Fewer than three points can't enclose an area, so the input is already its own
    ' hull - matches the existing count()=3 early return below. Without this,
    ' getMinMaxPoints() read pointsArray[0] unconditionally (even on an empty array,
    ' giving `invalid`) and returned a hull of [invalid, invalid] for empty input -
    ' any caller reading .x/.y off that result crashed with a Type Mismatch. Confirmed
    ' via #59's depth-sort work, which added a defensive guard at the consumer layer
    ' (DepthSortHelpers.bs's MIN_VALID_HULL_POINTS/isValidHull) rather than fix it here -
    ' this fixes it at the source, benefiting every caller (including
    ' getTrianglesFromPoints()/3D model face computation, not just DepthSort).
    if pointsArray.count() < 3
      return pointsArray
    end if
```

Place it as the very first statement inside the function, before the existing `hull as
BGE.Math.Vector[] = []` line (check the exact current line - it's right after the function
signature and JSDoc comment).

- [ ] **Step 5: Run the tests again to verify they all pass**

Run: `npm run build-tests && npm run test:ci`
Expected: all 4 new tests PASS, and the existing suite is still fully green (532+ tests, no
regressions - `DepthSortHelpers.spec.bs`'s own degenerate-hull tests should be unaffected since
they test `DepthSortHelpers.bs`'s own defensive layer, not `QuickHull` directly).

- [ ] **Step 6: Commit**

```bash
git add src/source/utils/quickhull.bs src/source/utils/quickhull.spec.bs
git commit -m "Fix QuickHull([]) returning [invalid, invalid] instead of [] (#109, #59)"
```

---

### Task 2: Add sort-and-sweep helper functions to `DepthSortHelpers.bs`

**Files:**
- Modify: `src/source/engine/renderer/DepthSortHelpers.bs`
- Test: `src/source/engine/renderer/DepthSortHelpers.spec.bs` (add `@it` blocks to the existing
  `DepthSortBroadPhaseTests` `@suite` class - do NOT create a new `@suite` class)

**Interfaces:**
- Produces: `sortByMinXIncremental(objects as BGE.SceneObject[], previousOrderIds as string[],
  screenBoundsById as object) as BGE.SceneObject[]` and
  `sweepForCandidatePairIndexes(sortedObjects as BGE.SceneObject[], screenBoundsById as object) as
  object` (an array of 2-element integer arrays `[i, j]`) - both consumed by Task 3's rewritten
  `groupIntoClusters()`.
- Consumes: nothing new - reuses the existing `ScreenBounds` interface and `getScreenBounds()`.

- [ ] **Step 1: Write the failing tests**

Add these `@it` blocks inside `DepthSortBroadPhaseTests` in `DepthSortHelpers.spec.bs` (put them
under a new `@describe("sortByMinXIncremental")` and `@describe("sweepForCandidatePairIndexes")`,
after the existing `@describe("groupIntoClusters")` block):

```brightscript
    @describe("sortByMinXIncremental")

    @it("sorts objects ascending by minX when given no previous order")
    function _()
      game = new BGE.Game(320, 240)
      entityA = new BGE.GameEntity(game, {name: "A"})
      entityA.position = BGE.Math.VectorOps.create(100, 0, 0)
      entityB = new BGE.GameEntity(game, {name: "B"})
      entityB.position = BGE.Math.VectorOps.create(-100, 0, 0)
      rectA = new BGE.DrawableRectangle(entityA, 20, 20)
      rectB = new BGE.DrawableRectangle(entityB, 20, 20)
      sceneObjA = rectA.addToScene(m.renderer)
      sceneObjB = rectB.addToScene(m.renderer)
      entityA.updateTransformationMatrix()
      entityB.updateTransformationMatrix()
      m.renderer.setupCameraForFrame()
      sceneObjA.update(m.renderer.camera)
      sceneObjB.update(m.renderer.camera)

      screenBoundsById = {}
      screenBoundsById[sceneObjA.id] = BGE.DepthSort.getScreenBounds(sceneObjA.getBoundingPoints(m.renderer.camera), m.renderer)
      screenBoundsById[sceneObjB.id] = BGE.DepthSort.getScreenBounds(sceneObjB.getBoundingPoints(m.renderer.camera), m.renderer)

      sorted = BGE.DepthSort.sortByMinXIncremental([sceneObjA, sceneObjB], [], screenBoundsById)
      m.assertEqual(sceneObjB.id, sorted[0].id)
      m.assertEqual(sceneObjA.id, sorted[1].id)
    end function

    @it("preserves a previous order that is already correctly sorted (the cheap common case)")
    function _()
      game = new BGE.Game(320, 240)
      entityA = new BGE.GameEntity(game, {name: "A"})
      entityA.position = BGE.Math.VectorOps.create(-100, 0, 0)
      entityB = new BGE.GameEntity(game, {name: "B"})
      entityB.position = BGE.Math.VectorOps.create(100, 0, 0)
      rectA = new BGE.DrawableRectangle(entityA, 20, 20)
      rectB = new BGE.DrawableRectangle(entityB, 20, 20)
      sceneObjA = rectA.addToScene(m.renderer)
      sceneObjB = rectB.addToScene(m.renderer)
      entityA.updateTransformationMatrix()
      entityB.updateTransformationMatrix()
      m.renderer.setupCameraForFrame()
      sceneObjA.update(m.renderer.camera)
      sceneObjB.update(m.renderer.camera)

      screenBoundsById = {}
      screenBoundsById[sceneObjA.id] = BGE.DepthSort.getScreenBounds(sceneObjA.getBoundingPoints(m.renderer.camera), m.renderer)
      screenBoundsById[sceneObjB.id] = BGE.DepthSort.getScreenBounds(sceneObjB.getBoundingPoints(m.renderer.camera), m.renderer)

      sorted = BGE.DepthSort.sortByMinXIncremental([sceneObjA, sceneObjB], [sceneObjA.id, sceneObjB.id], screenBoundsById)
      m.assertEqual(sceneObjA.id, sorted[0].id)
      m.assertEqual(sceneObjB.id, sorted[1].id)
    end function

    @it("appends an object with no entry in the previous order, then still sorts correctly")
    function _()
      game = new BGE.Game(320, 240)
      entityA = new BGE.GameEntity(game, {name: "A"})
      entityA.position = BGE.Math.VectorOps.create(100, 0, 0)
      entityB = new BGE.GameEntity(game, {name: "B"})
      entityB.position = BGE.Math.VectorOps.create(-100, 0, 0)
      rectA = new BGE.DrawableRectangle(entityA, 20, 20)
      rectB = new BGE.DrawableRectangle(entityB, 20, 20)
      sceneObjA = rectA.addToScene(m.renderer)
      sceneObjB = rectB.addToScene(m.renderer)
      entityA.updateTransformationMatrix()
      entityB.updateTransformationMatrix()
      m.renderer.setupCameraForFrame()
      sceneObjA.update(m.renderer.camera)
      sceneObjB.update(m.renderer.camera)

      screenBoundsById = {}
      screenBoundsById[sceneObjA.id] = BGE.DepthSort.getScreenBounds(sceneObjA.getBoundingPoints(m.renderer.camera), m.renderer)
      screenBoundsById[sceneObjB.id] = BGE.DepthSort.getScreenBounds(sceneObjB.getBoundingPoints(m.renderer.camera), m.renderer)

      ' previousOrderIds only knows about A - B is "new this frame".
      sorted = BGE.DepthSort.sortByMinXIncremental([sceneObjA, sceneObjB], [sceneObjA.id], screenBoundsById)
      m.assertEqual(2, sorted.count())
      m.assertEqual(sceneObjB.id, sorted[0].id)
      m.assertEqual(sceneObjA.id, sorted[1].id)
    end function

    @it("ignores an id in the previous order with no matching object this frame (removed/disabled)")
    function _()
      game = new BGE.Game(320, 240)
      entityA = new BGE.GameEntity(game, {name: "A"})
      rectA = new BGE.DrawableRectangle(entityA, 20, 20)
      sceneObjA = rectA.addToScene(m.renderer)
      entityA.updateTransformationMatrix()
      m.renderer.setupCameraForFrame()
      sceneObjA.update(m.renderer.camera)

      screenBoundsById = {}
      screenBoundsById[sceneObjA.id] = BGE.DepthSort.getScreenBounds(sceneObjA.getBoundingPoints(m.renderer.camera), m.renderer)

      sorted = BGE.DepthSort.sortByMinXIncremental([sceneObjA], ["some-stale-id-not-in-objects", sceneObjA.id], screenBoundsById)
      m.assertEqual(1, sorted.count())
      m.assertEqual(sceneObjA.id, sorted[0].id)
    end function

    @describe("sweepForCandidatePairIndexes")

    @it("returns no pairs for two objects whose X ranges do not overlap")
    function _()
      game = new BGE.Game(320, 240)
      entityA = new BGE.GameEntity(game, {name: "A"})
      entityA.position = BGE.Math.VectorOps.create(-100, 0, 0)
      entityB = new BGE.GameEntity(game, {name: "B"})
      entityB.position = BGE.Math.VectorOps.create(100, 0, 0)
      rectA = new BGE.DrawableRectangle(entityA, 20, 20)
      rectB = new BGE.DrawableRectangle(entityB, 20, 20)
      sceneObjA = rectA.addToScene(m.renderer)
      sceneObjB = rectB.addToScene(m.renderer)
      entityA.updateTransformationMatrix()
      entityB.updateTransformationMatrix()
      m.renderer.setupCameraForFrame()
      sceneObjA.update(m.renderer.camera)
      sceneObjB.update(m.renderer.camera)

      screenBoundsById = {}
      screenBoundsById[sceneObjA.id] = BGE.DepthSort.getScreenBounds(sceneObjA.getBoundingPoints(m.renderer.camera), m.renderer)
      screenBoundsById[sceneObjB.id] = BGE.DepthSort.getScreenBounds(sceneObjB.getBoundingPoints(m.renderer.camera), m.renderer)

      sorted = BGE.DepthSort.sortByMinXIncremental([sceneObjA, sceneObjB], [], screenBoundsById)
      pairs = BGE.DepthSort.sweepForCandidatePairIndexes(sorted, screenBoundsById)
      m.assertEqual(0, pairs.count())
    end function

    @it("returns exactly one pair for two objects whose X ranges overlap")
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

      screenBoundsById = {}
      screenBoundsById[sceneObjA.id] = BGE.DepthSort.getScreenBounds(sceneObjA.getBoundingPoints(m.renderer.camera), m.renderer)
      screenBoundsById[sceneObjB.id] = BGE.DepthSort.getScreenBounds(sceneObjB.getBoundingPoints(m.renderer.camera), m.renderer)

      sorted = BGE.DepthSort.sortByMinXIncremental([sceneObjA, sceneObjB], [], screenBoundsById)
      pairs = BGE.DepthSort.sweepForCandidatePairIndexes(sorted, screenBoundsById)
      m.assertEqual(1, pairs.count())
    end function

    @it("matches a brute-force O(n^2) reference scan across a scattered layout (correctness check)")
    function _()
      game = new BGE.Game(320, 240)
      entities = []
      sceneObjs = []
      ' A scattered layout: some overlapping, some not, including one wide object
      ' (standing in for the diagonal-wall pathology) among several narrow ones.
      positions = [-500, -480, -460, 0, 5, 400, 900, 905]
      widths = [800, 20, 20, 20, 20, 20, 20, 20]
      for i = 0 to positions.count() - 1
        entity = new BGE.GameEntity(game, {name: `E${i}`})
        entity.position = BGE.Math.VectorOps.create(positions[i], 0, 0)
        rect = new BGE.DrawableRectangle(entity, widths[i], 20)
        sceneObj = rect.addToScene(m.renderer)
        entity.updateTransformationMatrix()
        entities.push(entity)
        sceneObjs.push(sceneObj)
      end for

      m.renderer.setupCameraForFrame()
      screenBoundsById = {}
      for each sceneObj in sceneObjs
        sceneObj.update(m.renderer.camera)
        screenBoundsById[sceneObj.id] = BGE.DepthSort.getScreenBounds(sceneObj.getBoundingPoints(m.renderer.camera), m.renderer)
      end for

      sorted = BGE.DepthSort.sortByMinXIncremental(sceneObjs, [], screenBoundsById)
      sweepPairIds = {}
      for each pair in BGE.DepthSort.sweepForCandidatePairIndexes(sorted, screenBoundsById)
        key = sorted[pair[0]].id + "-" + sorted[pair[1]].id
        reverseKey = sorted[pair[1]].id + "-" + sorted[pair[0]].id
        if invalid = sweepPairIds[key] and invalid = sweepPairIds[reverseKey]
          sweepPairIds[key] = true
        end if
      end for

      ' Brute-force reference: every pair whose X ranges actually overlap.
      bruteForceCount = 0
      for i = 0 to sceneObjs.count() - 1
        for j = i + 1 to sceneObjs.count() - 1
          boundsA = screenBoundsById[sceneObjs[i].id]
          boundsB = screenBoundsById[sceneObjs[j].id]
          if boundsA.minX <= boundsB.maxX and boundsB.minX <= boundsA.maxX
            bruteForceCount++
          end if
        end for
      end for

      m.assertEqual(bruteForceCount, sweepPairIds.count())
    end function
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `npm run build-tests && npm run test:ci`
Expected: compile errors (functions don't exist yet) or FAIL, since `sortByMinXIncremental`/
`sweepForCandidatePairIndexes` don't exist yet.

- [ ] **Step 3: Add the two functions to `DepthSortHelpers.bs`**

Add these as new namespace-scope functions (no `private` keyword - see Global Constraints),
placed after `boundsOverlap()` and before `hullsOverlap()`:

```brightscript
  ' Reorders `objects` by ascending screen-space minX, using `previousOrderIds` (last
  ' frame's sorted order, by SceneObject.id) as the starting arrangement before sorting -
  ' most objects don't move far frame-to-frame, so this starting point is usually already
  ' nearly sorted, and an insertion sort on a nearly-sorted list is close to O(n) rather
  ' than the O(n log n) a fresh sort would cost every single frame. An id in
  ' previousOrderIds with no matching object this frame is silently skipped (the object
  ' was removed, disabled, or culled out of the candidate set); an object with no
  ' matching id in previousOrderIds (new this frame, or the very first frame) is
  ' appended at the end before sorting, so it still ends up in the right place, just at
  ' typical fresh-object cost.
  '
  ' @param {BGE.SceneObject[]} objects
  ' @param {string[]} previousOrderIds
  ' @param {object} screenBoundsById - associative array keyed by SceneObject.id
  ' @return {BGE.SceneObject[]}
  function sortByMinXIncremental(objects as BGE.SceneObject[], previousOrderIds as string[], screenBoundsById as object) as BGE.SceneObject[]
    objectById = {}
    for each obj in objects
      objectById[obj.id] = obj
    end for

    seeded = [] as BGE.SceneObject[]
    seenIds = {}
    for each id in previousOrderIds
      obj = objectById[id]
      if invalid <> obj
        seeded.push(obj)
        seenIds[id] = true
      end if
    end for
    for each obj in objects
      if invalid = seenIds[obj.id]
        seeded.push(obj)
      end if
    end for

    ' Insertion sort by minX - close to O(n) when `seeded` is already close to sorted
    ' (the common case), correct regardless of how scrambled it is.
    for i = 1 to seeded.count() - 1
      current = seeded[i]
      currentMinX = screenBoundsById[current.id].minX
      j = i - 1
      while j >= 0 and screenBoundsById[seeded[j].id].minX > currentMinX
        seeded[j + 1] = seeded[j]
        j--
      end while
      seeded[j + 1] = current
    end for

    return seeded
  end function

  ' Sweeps `sortedObjects` (already sorted ascending by minX) left to right, returning
  ' only the index pairs whose screen-space X ranges actually overlap - this is the
  ' broad phase's real cost-saving step. An object is dropped from the "active" set
  ' once its maxX has been passed by the sweep, so a later object is only ever compared
  ' against objects it could plausibly overlap, not the whole list - this is what turns
  ' the broad phase from O(n^2) into roughly O(n + k) for k actual overlapping pairs in
  ' a typical scene, and specifically fixes the diagonal-wall pathology (a wide object's
  ' cost is proportional to how many other objects its X range actually overlaps, not
  ' the whole scene).
  '
  ' @param {BGE.SceneObject[]} sortedObjects - sorted ascending by ScreenBounds.minX (see sortByMinXIncremental)
  ' @param {object} screenBoundsById - associative array keyed by SceneObject.id
  ' @return {object} array of 2-element integer arrays [i, j], indexes into sortedObjects
  function sweepForCandidatePairIndexes(sortedObjects as BGE.SceneObject[], screenBoundsById as object) as object
    pairs = []
    activeIndexes = [] as integer[]
    for i = 0 to sortedObjects.count() - 1
      currentBounds = screenBoundsById[sortedObjects[i].id]

      stillActive = [] as integer[]
      for each activeIndex in activeIndexes
        if screenBoundsById[sortedObjects[activeIndex].id].maxX >= currentBounds.minX
          stillActive.push(activeIndex)
          pairs.push([activeIndex, i])
        end if
      end for
      activeIndexes = stillActive
      activeIndexes.push(i)
    end for
    return pairs
  end function
```

- [ ] **Step 4: Run the tests again to verify they pass**

Run: `npm run build-tests && npm run test:ci`
Expected: all new tests PASS, full suite still green.

- [ ] **Step 5: Commit**

```bash
git add src/source/engine/renderer/DepthSortHelpers.bs src/source/engine/renderer/DepthSortHelpers.spec.bs
git commit -m "Add sort-and-sweep broad-phase helper functions (#59, depth-sort Plan 2)"
```

---

### Task 3: Rewrite `groupIntoClusters()` to use sort-and-sweep instead of all-pairs scan

**Files:**
- Modify: `src/source/engine/renderer/DepthSortHelpers.bs`
- Modify: `src/source/engine/renderer/DepthSortHelpers.spec.bs`

**Interfaces:**
- Consumes: `sortByMinXIncremental()`/`sweepForCandidatePairIndexes()` from Task 2.
- Produces: a new `ClusterResult` interface (`clusters as BGE.SceneObject[][]`, `sortedIds as
  string[]`) and a changed `groupIntoClusters()` signature:
  `function groupIntoClusters(objects as BGE.SceneObject[], rendererObj as BGE.Renderer,
  previousOrderIds as string[]) as ClusterResult` - Task 4 updates `Renderer.bs`'s call site to
  match this new signature and to store/pass `sortedIds` across frames.

- [ ] **Step 1: Write the failing tests**

The existing `@describe("groupIntoClusters")` tests in `DepthSortHelpers.spec.bs` call
`BGE.DepthSort.groupIntoClusters([sceneObjA, sceneObjB], m.renderer)` (2 args) and check
`clusters.count()`/`clusters[0].count()` directly on the return value. Update every existing call
site in that `@describe` block (there are at least 2 - "puts two non-overlapping objects..." and
"puts two overlapping objects...") to pass a third argument and unwrap `.clusters`:

```brightscript
      clusterResult = BGE.DepthSort.groupIntoClusters([sceneObjA, sceneObjB], m.renderer, [])
      m.assertEqual(2, clusterResult.clusters.count())
```

(and similarly for the "overlapping" test, unwrapping `.clusters` before the existing assertions).
Also check `DepthSortHelpers.spec.bs`'s other `@it` blocks under
`@describe("getBoundingPoints (SceneObjectPolygon/SceneObjectModel regression)")` and the
degenerate-hull tests further down (search for every call site of `groupIntoClusters` in the
file - there should be a handful, including ones added for Plan 1's crash-guard regression tests)
and update each one the same way: add `, []` as the third argument, and change
`clusters = BGE.DepthSort.groupIntoClusters(...)` to `clusterResult = BGE.DepthSort.groupIntoClusters(...)`
followed by `clusters = clusterResult.clusters` right after, so the rest of each test body's
assertions on `clusters` need no further changes.

Add one new test confirming the incremental order is actually returned and usable:

```brightscript
    @it("groupIntoClusters returns the sorted order for feeding back in as previousOrderIds next frame")
    function _()
      game = new BGE.Game(320, 240)
      entityA = new BGE.GameEntity(game, {name: "A"})
      entityA.position = BGE.Math.VectorOps.create(100, 0, 0)
      entityB = new BGE.GameEntity(game, {name: "B"})
      entityB.position = BGE.Math.VectorOps.create(-100, 0, 0)
      rectA = new BGE.DrawableRectangle(entityA, 20, 20)
      rectB = new BGE.DrawableRectangle(entityB, 20, 20)
      sceneObjA = rectA.addToScene(m.renderer)
      sceneObjB = rectB.addToScene(m.renderer)
      entityA.updateTransformationMatrix()
      entityB.updateTransformationMatrix()
      m.renderer.setupCameraForFrame()
      sceneObjA.update(m.renderer.camera)
      sceneObjB.update(m.renderer.camera)

      clusterResult = BGE.DepthSort.groupIntoClusters([sceneObjA, sceneObjB], m.renderer, [])
      m.assertEqual(2, clusterResult.sortedIds.count())
      m.assertEqual(sceneObjB.id, clusterResult.sortedIds[0]) ' B is at x=-100, sorts first
      m.assertEqual(sceneObjA.id, clusterResult.sortedIds[1])
    end function
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `npm run build-tests && npm run test:ci`
Expected: compile errors (signature mismatch - `groupIntoClusters` still takes 2 args and returns
`BGE.SceneObject[][]` directly, not a `ClusterResult`).

- [ ] **Step 3: Rewrite `groupIntoClusters()`**

Replace the entire existing `groupIntoClusters()` function in `DepthSortHelpers.bs` with:

```brightscript
  ' The result of groupIntoClusters(): the computed clusters, plus the sorted-by-minX
  ' ordering it used this frame - feed sortedIds back in as previousOrderIds next frame
  ' to keep the incremental sort cheap (see sortByMinXIncremental).
  interface ClusterResult
    clusters as BGE.SceneObject[][]
    sortedIds as string[]
  end interface

  ' Groups objects into overlap clusters: connected components over the "these two
  ' objects' bounds overlap" relation (broad phase via sort-and-sweep, then narrow
  ' phase to reject false positives). Most objects end up alone in a cluster of one -
  ' only objects that mutually, genuinely overlap end up grouped together.
  '
  ' @param {BGE.SceneObject[]} objects
  ' @param {BGE.Renderer} rendererObj
  ' @param {string[]} previousOrderIds - last frame's sorted order (see ClusterResult.sortedIds); pass [] on the first call
  ' @return {ClusterResult}
  function groupIntoClusters(objects as BGE.SceneObject[], rendererObj as BGE.Renderer, previousOrderIds as string[]) as ClusterResult
    screenBoundsById = {}
    hullById = {}
    for each obj in objects
      boundingPoints = obj.getBoundingPoints(rendererObj.camera)
      screenBoundsById[obj.id] = getScreenBounds(boundingPoints, rendererObj)
      projectedPoints = projectPointsToScreen(boundingPoints, rendererObj)
      if projectedPoints.count() < MIN_VALID_HULL_POINTS
        ' Fewer than MIN_VALID_HULL_POINTS points survived projection (e.g. some/all of
        ' this object's bounding points are behind the camera, or it only ever had 1-2
        ' bounding points to begin with, like SceneObjectPlane/SceneObjectParallaxLayer's
        ' single-point default). Treat this object as having no valid hull this frame -
        ' hullsOverlap()'s own isValidHull guard then keeps it out of every cluster.
        hull = []
      else
        hull = BGE.QuickHull.QuickHull(projectedPoints)
      end if
      hullById[obj.id] = hull
    end for

    sortedObjects = sortByMinXIncremental(objects, previousOrderIds, screenBoundsById)

    ' Union-find over indexes into sortedObjects.
    parent = [] as integer[]
    for i = 0 to sortedObjects.count() - 1
      parent.push(i)
    end for

    for each pairIndexes in sweepForCandidatePairIndexes(sortedObjects, screenBoundsById)
      i = pairIndexes[0]
      j = pairIndexes[1]
      idA = sortedObjects[i].id
      idB = sortedObjects[j].id
      if boundsOverlap(screenBoundsById[idA], screenBoundsById[idB])
        if hullsOverlap(hullById[idA], hullById[idB])
          union(parent, i, j)
        end if
      end if
    end for

    clustersByRoot = {}
    for i = 0 to sortedObjects.count() - 1
      root = find(parent, i).toStr()
      if invalid = clustersByRoot[root]
        clustersByRoot[root] = [] as BGE.SceneObject[]
      end if
      clustersByRoot[root].push(sortedObjects[i])
    end for

    clusters = [] as BGE.SceneObject[][]
    for each item in clustersByRoot.items()
      clusters.push(item.value)
    end for

    sortedIds = [] as string[]
    for each obj in sortedObjects
      sortedIds.push(obj.id)
    end for

    return {clusters: clusters, sortedIds: sortedIds}
  end function
```

This removes the old `for i / for j = i+1` all-pairs double loop entirely - `boundsOverlap()` is
now only called for pairs `sweepForCandidatePairIndexes()` actually returns, not every pair.

- [ ] **Step 4: Run the tests again to verify they pass**

Run: `npm run build-tests && npm run test:ci`
Expected: all tests PASS, full suite green.

- [ ] **Step 5: Commit**

```bash
git add src/source/engine/renderer/DepthSortHelpers.bs src/source/engine/renderer/DepthSortHelpers.spec.bs
git commit -m "Replace all-pairs broad-phase scan with sort-and-sweep in groupIntoClusters (#59, depth-sort Plan 2)"
```

---

### Task 4: Wire the incremental sort order into `Renderer.bs`

**Files:**
- Modify: `src/source/engine/renderer/Renderer.bs`
- Modify: `src/source/engine/renderer/Renderer.spec.bs`

**Interfaces:**
- Consumes: `BGE.DepthSort.groupIntoClusters(objects, rendererObj, previousOrderIds) as
  BGE.DepthSort.ClusterResult` (Task 3).
- Produces: nothing new for later tasks - this closes out Part A.

- [ ] **Step 1: Write the failing test**

The existing `Renderer.spec.bs` test `@it("returns the cluster containing both overlapping
objects")` (or similarly named, under the `getOverlapClusters`/clustering `@describe` block -
search for `computeOverlapClusters = true` to find it) calls `m.renderer.drawScene()` and then
`m.renderer.getOverlapClusters()`. Add one new test confirming the sorted order actually persists
and is reused frame-to-frame (a smoke test that the wiring compiles and runs, not a deep test of
the sort itself - that's already covered by Task 2/3's tests):

```brightscript
    @it("computes overlap clusters correctly across two consecutive frames (incremental sort wiring)")
    function _()
      entityA = new BGE.GameEntity(new BGE.Game(320, 240), {name: "A"})
      entityA.position = BGE.Math.VectorOps.create(-5, 0, 0)
      entityB = new BGE.GameEntity(new BGE.Game(320, 240), {name: "B"})
      entityB.position = BGE.Math.VectorOps.create(5, 0, 0)
      rectA = new BGE.DrawableRectangle(entityA, 20, 20)
      rectB = new BGE.DrawableRectangle(entityB, 20, 20)
      rectA.addToScene(m.renderer)
      rectB.addToScene(m.renderer)
      entityA.updateTransformationMatrix()
      entityB.updateTransformationMatrix()
      m.renderer.computeOverlapClusters = true

      m.renderer.setupCameraForFrame()
      m.renderer.drawScene()
      m.assertEqual(1, m.renderer.getOverlapClusters().count())

      ' Second frame, nothing moved - the incremental sort must still produce the
      ' correct clustering, not silently drop it.
      m.renderer.setupCameraForFrame()
      m.renderer.drawScene()
      m.assertEqual(1, m.renderer.getOverlapClusters().count())
      m.assertEqual(2, m.renderer.getOverlapClusters()[0].count())
    end function
```

- [ ] **Step 2: Run the test to verify it fails (or already passes by coincidence)**

Run: `npm run build-tests && npm run test:ci`
Expected: compile error - `Renderer.bs`'s current call site still calls the old 2-arg
`groupIntoClusters()` signature, which Task 3 already changed to 3 args returning a
`ClusterResult` - so this will fail to compile until this task's Step 3 is done.

- [ ] **Step 3: Update `Renderer.bs`**

Add a new private field near the existing `private overlapClusters as BGE.SceneObject[][] = []`
(around line 39):

```brightscript
    private overlapClusters as BGE.SceneObject[][] = []
    ' Last frame's overlap-cluster sort order (by SceneObject.id) - fed back into
    ' groupIntoClusters() as previousOrderIds so its sort-and-sweep broad phase can do
    ' an incremental (nearly-sorted) insertion sort instead of a fresh one every frame.
    private lastClusterSortOrder as string[] = []
```

Then update the `drawScene()` body (currently around line 316-318):

```brightscript
      if m.computeOverlapClusters
        m.overlapClusters = BGE.DepthSort.groupIntoClusters(m.getClusterCandidates(), m)
      end if
```

replace with:

```brightscript
      if m.computeOverlapClusters
        clusterResult = BGE.DepthSort.groupIntoClusters(m.getClusterCandidates(), m, m.lastClusterSortOrder)
        m.overlapClusters = clusterResult.clusters
        m.lastClusterSortOrder = clusterResult.sortedIds
      end if
```

- [ ] **Step 4: Run the tests again to verify they pass**

Run: `npm run build-tests && npm run test:ci`
Expected: all tests PASS, full suite green (should be 540+ tests from Plan 1, plus this plan's new
ones so far).

- [ ] **Step 5: Run the full quality gate**

Run: `npm run check`
Expected: lint clean, validate clean, all tests passing.

- [ ] **Step 6: Commit**

```bash
git add src/source/engine/renderer/Renderer.bs src/source/engine/renderer/Renderer.spec.bs
git commit -m "Wire incremental sweep order into Renderer.drawScene() (#59, depth-sort Plan 2)"
```

---

### Task 5: Fix `getScreenBounds`'s leftover fake-origin-AABB early return (residual from Plan 1's final review)

**Files:**
- Modify: `src/source/engine/renderer/DepthSortHelpers.bs`
- Modify: `src/source/engine/renderer/DepthSortHelpers.spec.bs`

**Interfaces:** none - internal consistency fix only, touches code this plan's Part A already
modified.

Plan 1's final review flagged that `getScreenBounds()`'s early-return for empty/invalid
`worldPoints` (near the top of the function) still returns the old literal
`{minX: 0.0, maxX: 0.0, minY: 0.0, maxY: 0.0, minDepth: 0.0, maxDepth: 0.0}` shape, while the rest
of the function was fixed to return `getEmptyScreenBounds()` (a sentinel that can never overlap
anything) for every other degenerate case. This is currently unreachable in practice (nothing
calls `getScreenBounds` with `invalid`/empty `worldPoints` today), but it's an inconsistency in
code this plan is already touching - fix it while here.

- [ ] **Step 1: Write the failing test**

Add to `DepthSortHelpers.spec.bs`'s existing `@describe("getScreenBounds")` block:

```brightscript
    @it("returns the same never-overlaps-anything sentinel as every other degenerate case, for invalid input")
    function _()
      bounds = BGE.DepthSort.getScreenBounds(invalid, m.renderer)
      otherBounds = {minX: -1000000.0, maxX: 1000000.0, minY: -1000000.0, maxY: 1000000.0, minDepth: -1000000.0, maxDepth: 1000000.0, hasScreenBounds: true}
      m.assertFalse(BGE.DepthSort.boundsOverlap(bounds, otherBounds))
    end function
```

(Check the exact field name/shape `ScreenBounds` currently uses in this codebase - Plan 1's final
review added a `hasScreenBounds` boolean field to the interface; confirm by reading the current
`ScreenBounds` interface definition in `DepthSortHelpers.bs` before writing this test, and match
whatever `getEmptyScreenBounds()` actually returns today.)

- [ ] **Step 2: Run the test to verify it fails (or passes already)**

Run: `npm run build-tests && npm run test:ci`
This may already pass if `bounds` happens to be `{0,0,0,0,...}` and `otherBounds` doesn't cover
the origin - check the actual result. If it passes without the fix, adjust `otherBounds` in the
test to genuinely cover canvas origin `(0,0)` at an overlapping depth, so the test actually
exercises the bug (this mirrors the exact regression test Plan 1's final review added for the
other degenerate branches in this same function).

- [ ] **Step 3: Fix the early return**

Find the line near the top of `getScreenBounds()`:

```brightscript
    if invalid = worldPoints or worldPoints.count() < 1
      return {minX: 0.0, maxX: 0.0, minY: 0.0, maxY: 0.0, minDepth: 0.0, maxDepth: 0.0}
    end if
```

Replace with:

```brightscript
    if invalid = worldPoints or worldPoints.count() < 1
      return getEmptyScreenBounds()
    end if
```

- [ ] **Step 4: Run the tests again to verify they pass**

Run: `npm run build-tests && npm run test:ci`

- [ ] **Step 5: Commit**

```bash
git add src/source/engine/renderer/DepthSortHelpers.bs src/source/engine/renderer/DepthSortHelpers.spec.bs
git commit -m "Fix leftover fake-origin-AABB early return in getScreenBounds (#59, depth-sort Plan 2)"
```

---

### Task 6: On-device measurement checkpoint - confirm the broad-phase fix actually works

**Files:** none modified - this is a verification-only task, gating Part B.

**Interfaces:** none.

This re-runs the exact `examples/3d` `TreesRoom` measurement from the
[#59 GitHub issue comment](https://github.com/markwpearce/brighterscript-game-engine/issues/59)
against this plan's Part A fix, to prove it actually solves the measured regression before Part B
builds on top of it.

- [ ] **Step 1: Build the engine and the example**

```bash
npm run build
cd examples/3d && npm run package
```

- [ ] **Step 2: Temporarily enable `computeOverlapClusters` for this measurement**

In `examples/3d/src/source/main.bs`, add (near `game.enableStandardDebugUi()`):

```brightscript
  ' TEMP MEASUREMENT SCRATCH - not part of any plan, discarded before commit.
  game.canvas.renderer.computeOverlapClusters = true
```

Rebuild: `cd examples/3d && npm run package`

- [ ] **Step 3: Sideload and measure**

Follow the `rokubot-examples` skill workflow:

```bash
node node_modules/rokubot/dist/cli.js sideload ./examples/3d/out/bge-3d.zip --deleteDevChannel
node node_modules/rokubot/dist/cli.js launch dev
```

Navigate to `TreesRoom` (per `getRoomNames()` in `examples/3d/src/source/main.bs`, it's index 7 -
press `fwd` 7 times from the default `ImagesRoom`, screenshotting after each press to confirm
which room is showing, since navigation order can be surprising). Take several screenshots ~1-2
seconds apart once settled, reading the `FPS:` debug overlay value each time.

- [ ] **Step 4: Compare against the recorded baseline**

The recorded baseline (from the GitHub issue) is **~31-36 FPS with clustering off, 9 FPS with the
old all-pairs scan on**. Record the new FPS reading with this plan's sort-and-sweep fix in place.
If the new reading is not close to the ~31-36 FPS baseline (i.e. clustering is no longer a
measurable regression), STOP - do not proceed to Part B (Tasks 7-10) until the broad-phase fix is
actually confirmed working. If it is close, proceed.

- [ ] **Step 5: Revert the temporary measurement change**

```bash
git checkout -- examples/3d/src/source/main.bs
```

Confirm: `git status --short` shows no diff in `examples/3d`.

- [ ] **Step 6: Report the before/after numbers**

Record the exact before/after FPS readings in this task's completion note (ledger, if using
subagent-driven-development) - this is the evidence the rest of this plan (and the eventual PR
description) leans on.

---

### Task 7: Add the `getPrimitiveCount()`/`getPrimitiveDepth()`/`drawPrimitive()` contract to `SceneObject`, and the cluster draw loop to `Renderer`

**Files:**
- Modify: `src/source/engine/renderer/sceneObjects/SceneObject.bs`
- Modify: `src/source/engine/renderer/Renderer.bs`
- Modify: `src/source/engine/renderer/sceneObjects/SceneObjectTestDoubles.spec.bs` (only if a test
  double there needs the new default methods - check first, likely no change needed since these
  are new methods with base-class defaults, not new abstract requirements)
- Test: `src/source/engine/renderer/Renderer.spec.bs`, `src/source/engine/renderer/sceneObjects/SceneObjectRectangle.spec.bs`

**Interfaces:**
- Produces: `SceneObject.getPrimitiveCount() as integer` (default `1`), `SceneObject.getPrimitiveDepth(index
  as integer) as float` (default `m.negDistanceFromCamera`), `SceneObject.drawPrimitive(rendererObj as
  Renderer, index as integer) as boolean` (default: delegates to `m.performDraw(rendererObj,
  m.lastDrawMode)`), `SceneObject.clusterMemberCount as integer = 1` (public field, set once per
  frame by `Renderer`). `Renderer.addPendingClusterDraw(sceneObj as SceneObject)`.
- Consumes: nothing new from earlier tasks in this plan - this is the start of Part B, built on
  top of Part A's now-cheap `getOverlapClusters()`.

**Design note on why billboard caching is NOT suspended here:** Plan 1's original design spec said
clustering should "suspend temp-bitmap caching" for every clustered member. Verified against the
actual `SceneObjectBillboard.performDraw()` code: a billboard is always exactly one primitive
regardless of clustering, so calling its existing `performDraw()` (with its existing caching
decision-making intact) at the correct point in the interleaved draw order produces identical,
correct pixels - caching suspension is only actually necessary for `SceneObjectModel` (Task 8),
whose *whole-object* temp bitmap aggregates multiple faces in an order that doesn't respect
cross-object interleaving. Do not add cache-suspension logic to `SceneObjectBillboard.bs` in this
task - it would add complexity/cache churn with no correctness benefit for the single-primitive
case.

- [ ] **Step 1: Write the failing tests**

Add to `SceneObjectRectangle.spec.bs` (a billboard subclass - representative of the base-class
default behavior every other non-Model `SceneObject` inherits unchanged):

```brightscript
    @describe("getPrimitiveCount / getPrimitiveDepth / drawPrimitive (cluster draw contract)")

    @it("getPrimitiveCount defaults to 1 for a billboard")
    function _()
      rect = new BGE.DrawableRectangle(m.entity, 20, 20)
      sceneObj = rect.addToScene(m.renderer)
      m.assertEqual(1, sceneObj.getPrimitiveCount())
    end function

    @it("getPrimitiveDepth(0) matches negDistanceFromCamera")
    function _()
      rect = new BGE.DrawableRectangle(m.entity, 20, 20)
      sceneObj = rect.addToScene(m.renderer)
      m.entity.updateTransformationMatrix()
      m.renderer.setupCameraForFrame()
      sceneObj.update(m.renderer.camera)
      m.assertEqual(sceneObj.negDistanceFromCamera, sceneObj.getPrimitiveDepth(0))
    end function

    @it("drawPrimitive(0) draws the same as a normal draw() call")
    function _()
      rect = new BGE.DrawableRectangle(m.entity, 20, 20)
      sceneObj = rect.addToScene(m.renderer)
      m.entity.updateTransformationMatrix()
      m.renderer.setupCameraForFrame()
      sceneObj.update(m.renderer.camera)
      m.renderer.resetDrawCallCounter()
      result = sceneObj.drawPrimitive(m.renderer, 0)
      m.assertTrue(result)
      m.assertTrue(m.renderer.getDrawCallsLastFrame() > 0)
    end function
```

(Check `SceneObjectRectangle.spec.bs`'s existing `beforeEach` for the exact names of `m.entity`/
`m.renderer` - match whatever fixture fields it already sets up, following the same pattern as its
other tests in that file.)

Add to `Renderer.spec.bs`:

```brightscript
    @describe("cluster draw loop")

    @it("a solo cluster (or clustering disabled) draws exactly as before - draw call count unchanged")
    function _()
      entityA = new BGE.GameEntity(new BGE.Game(320, 240), {name: "A"})
      rectA = new BGE.DrawableRectangle(entityA, 20, 20)
      rectA.addToScene(m.renderer)
      entityA.updateTransformationMatrix()
      m.renderer.setupCameraForFrame()
      m.renderer.resetDrawCallCounter()
      m.renderer.drawScene()
      soloDrawCalls = m.renderer.getDrawCallsLastFrame()
      m.assertTrue(soloDrawCalls > 0)
    end function

    @it("two clustered objects both actually draw (via the deferred primitive path)")
    function _()
      entityA = new BGE.GameEntity(new BGE.Game(320, 240), {name: "A"})
      entityA.position = BGE.Math.VectorOps.create(-5, 0, 0)
      entityB = new BGE.GameEntity(new BGE.Game(320, 240), {name: "B"})
      entityB.position = BGE.Math.VectorOps.create(5, 0, 0)
      rectA = new BGE.DrawableRectangle(entityA, 20, 20)
      rectB = new BGE.DrawableRectangle(entityB, 20, 20)
      rectA.addToScene(m.renderer)
      rectB.addToScene(m.renderer)
      entityA.updateTransformationMatrix()
      entityB.updateTransformationMatrix()
      m.renderer.computeOverlapClusters = true

      m.renderer.setupCameraForFrame()
      m.renderer.resetDrawCallCounter()
      m.renderer.drawScene()
      m.assertTrue(m.renderer.getDrawCallsLastFrame() > 0)
      m.assertEqual(1, m.renderer.getOverlapClusters().count())
      m.assertEqual(2, m.renderer.getOverlapClusters()[0].count())
    end function
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `npm run build-tests && npm run test:ci`
Expected: compile errors (the new methods/field don't exist yet).

- [ ] **Step 3: Add the default methods and field to `SceneObject.bs`**

Add near the other public fields (e.g. near `id as string = ""` around line 129):

```brightscript
    ' How many members are in this object's overlap cluster this frame (see
    ' Renderer.getOverlapClusters()) - 1 means solo (the common case, and the only
    ' value possible when Renderer.computeOverlapClusters is false). Set once per frame
    ' by Renderer, right after it computes clusters - not meant to be set directly by
    ' game code.
    clusterMemberCount as integer = 1
```

Add these three new methods near `performDraw()` (around line 398), after it:

```brightscript
    ' How many separately-orderable draw primitives this object currently has. The
    ' base-class default (1) is correct for every billboard-family SceneObject - a
    ' quad/circle/text/etc. is always drawn as one piece regardless of draw mode.
    ' SceneObjectModel overrides this to return its actual per-face count, which does
    ' vary with draw mode (backface-culled modes only count front-facing faces; the
    ' *DrawBackFace variants count both).
    '
    ' @return {integer}
    function getPrimitiveCount() as integer
      return 1
    end function

    ' The depth to sort primitive `index` by, within a multi-member cluster's combined
    ' primitive list. The base-class default (this object's own overall depth) is
    ' correct for the single-primitive case.
    '
    ' @param {integer} index
    ' @return {float}
    function getPrimitiveDepth(index as integer) as float
      return m.negDistanceFromCamera
    end function

    ' Draws primitive `index` now. The base-class default delegates to this object's
    ' normal whole-object draw path (performDraw, with its normal caching behavior
    ' intact) - correct for the single-primitive case, where "draw primitive 0" and
    ' "draw the whole object" are the same operation. SceneObjectModel overrides this
    ' to draw one face directly (bypassing its whole-model temp-bitmap cache, which
    ' can't represent cross-object interleaving).
    '
    ' @param {Renderer} rendererObj
    ' @param {integer} index
    ' @return {boolean} whether this primitive actually drew something
    function drawPrimitive(rendererObj as Renderer, index as integer) as boolean
      return m.performDraw(rendererObj, m.lastDrawMode)
    end function
```

Modify the existing `draw()` method (around line 293-322) - find this block:

```brightscript
        if m.hasValidCanvasPosition
          didDraw = m.performDraw(rendererObj, drawModeToUse)
          if didDraw
            m.afterDraw()
          else
            deterministicFailure = m.isDeterministicDrawFailure(rendererObj, drawModeToUse)
          end if
        end if
```

Replace with:

```brightscript
        if m.hasValidCanvasPosition
          if m.clusterMemberCount > 1
            ' Defer to the interleaved cluster draw pass at the end of drawScene() -
            ' this object's primitives get sorted together with the rest of its
            ' cluster's members and drawn in one combined depth order, instead of
            ' drawing this whole object atomically right now.
            rendererObj.addPendingClusterDraw(m)
            didDraw = true
          else
            didDraw = m.performDraw(rendererObj, drawModeToUse)
            if didDraw
              m.afterDraw()
            else
              deterministicFailure = m.isDeterministicDrawFailure(rendererObj, drawModeToUse)
            end if
          end if
        end if
```

- [ ] **Step 4: Add the cluster draw loop to `Renderer.bs`**

Add a new private field near `overlapClusters`/`lastClusterSortOrder`:

```brightscript
    private pendingClusterDraws as object[] = []
```

Add a new public method (near `addSceneObject`/`removeSceneObject`):

```brightscript
    ' Registers a SceneObject as deferred to the end-of-frame interleaved cluster draw
    ' pass - called by SceneObject.draw() when clusterMemberCount > 1. Not meant to be
    ' called directly by game code.
    '
    ' @param {SceneObject} sceneObj
    sub addPendingClusterDraw(sceneObj as SceneObject)
      m.pendingClusterDraws.push(sceneObj)
    end sub
```

Add a new private method (near `updateSceneObjects`):

```brightscript
    ' Draws every deferred multi-member-cluster object's primitives in one combined
    ' depth order, then calls afterDraw() once per object (matching the normal
    ' single-object draw path's bookkeeping). Called once per frame, at the end of
    ' drawScene(), after every SceneObject.draw() call has either drawn directly or
    ' deferred here.
    private sub drawPendingClusterPrimitives()
      primitiveEntries = []
      for each sceneObj in m.pendingClusterDraws
        for i = 0 to sceneObj.getPrimitiveCount() - 1
          primitiveEntries.push({sceneObj: sceneObj, index: i, depth: sceneObj.getPrimitiveDepth(i)})
        end for
      end for
      primitiveEntries.SortBy("depth")
      for each entry in primitiveEntries
        entry.sceneObj.drawPrimitive(m, entry.index)
      end for
      for each sceneObj in m.pendingClusterDraws
        sceneObj.afterDraw()
      end for
      m.pendingClusterDraws = []
    end sub
```

Update `drawScene()` (around line 349-366) to clear `pendingClusterDraws` at the start of the
per-object draw section and flush it at the end - find:

```brightscript
      for each sceneObj in m.sceneObjects
        if sceneObj.isEnabled() and sceneObj.type = SceneObjectType.Plane
          if sceneObj.negDistanceFromCamera < 0 'and sceneObj.normnegDistanceFromCamera < 10000
            sceneObj.draw(m)
          end if
        end if
      end for


      ' draw sceneObjects in sorted order
      ' ignore any that are too far away (TBD) or behind camera
      for each sceneObj in m.sceneObjects
        if sceneObj.isEnabled()and sceneObj.type <> SceneObjectType.Plane
          if sceneObj.negDistanceFromCamera < 0 'and sceneObj.normnegDistanceFromCamera < 10000
            sceneObj.draw(m)
          end if
        end if
      end for
    end sub
```

Replace with:

```brightscript
      m.pendingClusterDraws = []

      for each sceneObj in m.sceneObjects
        if sceneObj.isEnabled() and sceneObj.type = SceneObjectType.Plane
          if sceneObj.negDistanceFromCamera < 0 'and sceneObj.normnegDistanceFromCamera < 10000
            sceneObj.draw(m)
          end if
        end if
      end for


      ' draw sceneObjects in sorted order
      ' ignore any that are too far away (TBD) or behind camera
      for each sceneObj in m.sceneObjects
        if sceneObj.isEnabled()and sceneObj.type <> SceneObjectType.Plane
          if sceneObj.negDistanceFromCamera < 0 'and sceneObj.normnegDistanceFromCamera < 10000
            sceneObj.draw(m)
          end if
        end if
      end for

      m.drawPendingClusterPrimitives()
    end sub
```

Finally, set `clusterMemberCount` on every scene object once per frame, right after
`m.overlapClusters` is computed (in the `if m.computeOverlapClusters ... end if` block added in
Task 4) - find:

```brightscript
      if m.computeOverlapClusters
        clusterResult = BGE.DepthSort.groupIntoClusters(m.getClusterCandidates(), m, m.lastClusterSortOrder)
        m.overlapClusters = clusterResult.clusters
        m.lastClusterSortOrder = clusterResult.sortedIds
      end if
```

Replace with:

```brightscript
      if m.computeOverlapClusters
        clusterResult = BGE.DepthSort.groupIntoClusters(m.getClusterCandidates(), m, m.lastClusterSortOrder)
        m.overlapClusters = clusterResult.clusters
        m.lastClusterSortOrder = clusterResult.sortedIds
        for each cluster in m.overlapClusters
          for each sceneObj in cluster
            sceneObj.clusterMemberCount = cluster.count()
          end for
        end for
      else
        for each sceneObj in m.sceneObjects
          sceneObj.clusterMemberCount = 1
        end for
      end if
```

- [ ] **Step 5: Run the tests again to verify they pass**

Run: `npm run build-tests && npm run test:ci`
Expected: all tests PASS, full suite green.

- [ ] **Step 6: Run the full quality gate**

Run: `npm run check`

- [ ] **Step 7: Commit**

```bash
git add src/source/engine/renderer/sceneObjects/SceneObject.bs src/source/engine/renderer/Renderer.bs src/source/engine/renderer/Renderer.spec.bs src/source/engine/renderer/sceneObjects/SceneObjectRectangle.spec.bs
git commit -m "Add cluster draw contract (getPrimitiveCount/getPrimitiveDepth/drawPrimitive) and interleaved draw loop (#59, depth-sort Plan 2)"
```

---

### Task 8: `SceneObjectModel` overrides - per-face primitives, bypassing whole-model caching

**Files:**
- Modify: `src/source/engine/renderer/sceneObjects/SceneObjectModel.bs`
- Test: `src/source/engine/renderer/sceneObjects/SceneObjectModel.spec.bs` (check if it exists
  first; if not, this task's tests may need a new spec file - follow the one-`@suite`-class rule)

**Interfaces:**
- Consumes: the `getPrimitiveCount()`/`getPrimitiveDepth()`/`drawPrimitive()` contract from Task 7.
- Produces: nothing later tasks depend on.

- [ ] **Step 1: Check for an existing spec file**

Run: `ls src/source/engine/renderer/sceneObjects/SceneObjectModel.spec.bs`

- [ ] **Step 2: Write the failing tests**

If the file exists, add these as new `@it` blocks inside its existing `@suite` class. If it
doesn't exist, create it (matching the `@suite`/fixture pattern used by
`SceneObjectRectangle.spec.bs` - read that file first for the exact `beforeEach`/imports style to
follow):

Every test below uses `orientedDrawBackFace`/`solidDrawBackFace` deliberately, not
`oriented`/`solid` - those `*DrawBackFace` modes short-circuit the backface-cull check to
always-true (confirmed in this plan's design doc), so every face counts regardless of vertex
winding order, giving a deterministic assertion instead of one that depends on getting winding
order right by hand:

```brightscript
    @describe("getPrimitiveCount / getPrimitiveDepth / drawPrimitive (cluster draw contract)")

    @it("getPrimitiveCount reflects the actual number of faces, not the base class's default of 1")
    function _()
      face1 = BGE.Model3dFaceOps.create([BGE.Math.VectorOps.create(-10, -10, 0), BGE.Math.VectorOps.create(10, -10, 0), BGE.Math.VectorOps.create(0, 10, 0)])
      face2 = BGE.Model3dFaceOps.create([BGE.Math.VectorOps.create(-10, -10, 5), BGE.Math.VectorOps.create(10, -10, 5), BGE.Math.VectorOps.create(0, 10, 5)])
      model = new BGE.Model3d([face1, face2])
      drawableModel = new BGE.DrawableModel(m.entity, model)
      drawableModel.drawMode = BGE.SceneObjectDrawMode.orientedDrawBackFace
      sceneObj = drawableModel.addToScene(m.renderer)
      m.entity.updateTransformationMatrix()
      m.renderer.setupCameraForFrame()
      sceneObj.update(m.renderer.camera)
      m.assertEqual(2, sceneObj.getPrimitiveCount())
    end function

    @it("drawPrimitive draws a face directly, without going through the whole-model temp bitmap cache")
    function _()
      face1 = BGE.Model3dFaceOps.create([BGE.Math.VectorOps.create(-10, -10, 0), BGE.Math.VectorOps.create(10, -10, 0), BGE.Math.VectorOps.create(0, 10, 0)])
      model = new BGE.Model3d([face1])
      drawableModel = new BGE.DrawableModel(m.entity, model)
      drawableModel.drawMode = BGE.SceneObjectDrawMode.solidDrawBackFace
      sceneObj = drawableModel.addToScene(m.renderer)
      m.entity.updateTransformationMatrix()
      m.renderer.setupCameraForFrame()
      sceneObj.update(m.renderer.camera)
      m.assertEqual(1, sceneObj.getPrimitiveCount())
      m.renderer.resetDrawCallCounter()
      result = sceneObj.drawPrimitive(m.renderer, 0)
      m.assertTrue(result)
      m.assertTrue(m.renderer.getDrawCallsLastFrame() > 0)
    end function

    @it("getPrimitiveDepth returns the same value as the face's own priority")
    function _()
      face1 = BGE.Model3dFaceOps.create([BGE.Math.VectorOps.create(-10, -10, 0), BGE.Math.VectorOps.create(10, -10, 0), BGE.Math.VectorOps.create(0, 10, 0)])
      model = new BGE.Model3d([face1])
      drawableModel = new BGE.DrawableModel(m.entity, model)
      drawableModel.drawMode = BGE.SceneObjectDrawMode.solidDrawBackFace
      sceneObj = drawableModel.addToScene(m.renderer)
      m.entity.updateTransformationMatrix()
      m.renderer.setupCameraForFrame()
      sceneObj.update(m.renderer.camera)
      m.assertEqual(1, sceneObj.getPrimitiveCount())
      m.assertTrue(sceneObj.getPrimitiveDepth(0) <> invalid)
    end function
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `npm run build-tests && npm run test:ci`
Expected: without the override, `getPrimitiveCount()` returns the inherited base-class default
(`1`) regardless of actual face count - the 2-face test in Step 2 above should fail (expects `2`,
gets `1`) since it's the one that forces a real, deterministic failure before the fix.

- [ ] **Step 4: Add the overrides to `SceneObjectModel.bs`**

Refactor the existing `drawToCanvas` to extract a per-face helper (this becomes the one shared
place per-face draw dispatch lives, used by both the normal solo draw path and the new
`drawPrimitive` override) - replace:

```brightscript
    protected override function drawToCanvas(rendererObj as BGE.Renderer, drawMode as SceneObjectDrawMode) as boolean
      someWorked = false
      for each face in m.modelCanvasFaces
        shadedColor = BGE.colorBrightness(face.color, face.brightness)
        if drawMode = BGE.SceneObjectDrawMode.oriented or drawMode = BGE.SceneObjectDrawMode.orientedDrawBackFace or drawMode = BGE.SceneObjectDrawMode.solid or drawMode = BGE.SceneObjectDrawMode.solidDrawBackFace
          someWorked = rendererObj.drawTriangle(face.vertices, 0, 0, shadedColor) or someWorked
        else if drawMode = BGE.SceneObjectDrawMode.wireFrame or drawMode = BGE.SceneObjectDrawMode.wireFrameDrawBackFace
          someWorked = rendererObj.drawTriangleOutline(face.vertices, shadedColor) or someWorked
        end if
      end for
      return someWorked
    end function
```

with:

```brightscript
    protected override function drawToCanvas(rendererObj as BGE.Renderer, drawMode as SceneObjectDrawMode) as boolean
      someWorked = false
      for each face in m.modelCanvasFaces
        someWorked = m.drawFaceToCanvas(rendererObj, face, drawMode) or someWorked
      end for
      return someWorked
    end function

    ' Draws one face directly to the live canvas - the single place per-face draw
    ' dispatch lives, shared by the normal solo draw path (drawToCanvas, above) and the
    ' cluster draw path (drawPrimitive, below). Deliberately does not touch
    ' m.modelCanvasFaces/m.tempBitmap - this always draws live, never builds or relies
    ' on the whole-model temp-bitmap cache, since that cache aggregates every face in
    ' this model's own internal order and can't represent this face being interleaved
    ' with a different object's primitives.
    '
    ' @param {Renderer} rendererObj
    ' @param {Model3dFace} face
    ' @param {SceneObjectDrawMode} drawMode
    ' @return {boolean}
    private function drawFaceToCanvas(rendererObj as BGE.Renderer, face as BGE.Model3dFace, drawMode as SceneObjectDrawMode) as boolean
      shadedColor = BGE.colorBrightness(face.color, face.brightness)
      if drawMode = BGE.SceneObjectDrawMode.oriented or drawMode = BGE.SceneObjectDrawMode.orientedDrawBackFace or drawMode = BGE.SceneObjectDrawMode.solid or drawMode = BGE.SceneObjectDrawMode.solidDrawBackFace
        return rendererObj.drawTriangle(face.vertices, 0, 0, shadedColor)
      else if drawMode = BGE.SceneObjectDrawMode.wireFrame or drawMode = BGE.SceneObjectDrawMode.wireFrameDrawBackFace
        return rendererObj.drawTriangleOutline(face.vertices, shadedColor)
      end if
      return false
    end function
```

Add the three overrides after `getTempBitmapThreshold` (the last method in the class, before
`end class`):

```brightscript
    ' Overrides the base class's "always 1" default: a model's real primitive count is
    ' its actual current face list, which m.modelCanvasFaces (rebuilt every frame by
    ' updateCanvasPosition, above) already reflects correctly for whatever draw mode is
    ' active - front-facing-only for oriented/solid/wireFrame, front+back for the
    ' *DrawBackFace variants, and empty for matchCamera/directToCamera/directScaled
    ' (which this class doesn't render at all via any path). No new draw-mode-awareness
    ' is needed here - it's inherited for free from updateCanvasPosition's existing,
    ' already-correct backface-cull logic.
    '
    ' @return {integer}
    override function getPrimitiveCount() as integer
      return m.modelCanvasFaces.count()
    end function

    ' @param {integer} index
    ' @return {float}
    override function getPrimitiveDepth(index as integer) as float
      return m.modelCanvasFaces[index].priority
    end function

    ' @param {Renderer} rendererObj
    ' @param {integer} index
    ' @return {boolean}
    override function drawPrimitive(rendererObj as Renderer, index as integer) as boolean
      return m.drawFaceToCanvas(rendererObj, m.modelCanvasFaces[index], m.lastDrawMode)
    end function
```

- [ ] **Step 5: Run the tests again to verify they pass**

Run: `npm run build-tests && npm run test:ci`

- [ ] **Step 6: Run the full quality gate**

Run: `npm run check`

- [ ] **Step 7: Commit**

```bash
git add src/source/engine/renderer/sceneObjects/SceneObjectModel.bs src/source/engine/renderer/sceneObjects/SceneObjectModel.spec.bs
git commit -m "Add per-face cluster draw contract to SceneObjectModel (#59, depth-sort Plan 2)"
```

---

### Task 9: Extend `examples/depthsort` to visually demonstrate interleaved draw order, and fix the residual `computeOverlapClusters` reset-on-room-exit issue

**Files:**
- Modify: `examples/depthsort/src/source/Rooms/ClusterVisualizerRoom.bs`

**Interfaces:** none - this is a leaf demo update, consuming Task 7/8's new behavior.

Plan 1's final review noted `ClusterVisualizerRoom.onCreate` sets `computeOverlapClusters = true`
on the shared renderer and never resets it on room exit, so navigating away to `TieBreakRoom`
leaves clustering enabled there too (harmless before this plan, since nothing consumed clusters -
now that Task 7 makes clustering actually change draw order, this needs fixing so `TieBreakRoom`
genuinely only demonstrates the tie-break fix, not clustering).

- [ ] **Step 1: Add an `onChangeRoom` reset**

In `ClusterVisualizerRoom.bs`, find the existing empty override:

```brightscript
  override sub onChangeRoom(newRoom as BGE.Room)
  end sub
```

Replace with:

```brightscript
  override sub onChangeRoom(newRoom as BGE.Room)
    ' Only this room demonstrates clustering (see onCreate) - reset it when leaving so
    ' TieBreakRoom genuinely only exercises the tie-break fix, not clustering too.
    m.game.canvas.renderer.computeOverlapClusters = false
  end sub
```

- [ ] **Step 2: Add a genuinely-interpenetrating scenario that now visibly resolves correctly**

Add one new pair of entities to `onCreate` whose panels visibly overlap enough that the OLD
whole-object painter's-sort behavior would have drawn one entirely in front of the other, but
which - now that Task 7/8 actually interleaves cluster primitives by depth - should be
demonstrable as correctly ordered. Since `ClusterProbeEntity` is a flat `DrawableRectangle` (a
single-primitive billboard, per this plan's design note in Task 7), two overlapping
`ClusterProbeEntity` panels already draw via the new interleaved path once clustered (Task 7 alone
already covers this case correctly) - the genuinely new, Model-specific behavior (Task 8) needs at
least one `Model3d`-based demonstration to be visually meaningful.

First, copy the model asset this needs: `examples/3d/src/models/low_poly_bird.stl` into
`examples/depthsort/src/models/low_poly_bird.stl` (check `examples/3d/bsconfig.json` for whether
its `files` array needs an explicit `src/models/**/*` entry, and add the same entry to
`examples/depthsort/bsconfig.json` if it's missing there).

In `examples/depthsort/src/source/main.bs`, load the model once at startup (matching
`examples/3d/src/source/main.bs`'s own `game.load3dModel("bird", "pkg:/models/low_poly_bird.stl")`
call - add the identical line to `examples/depthsort/src/source/main.bs`'s `main()` function,
before `game.changeRoom(...)`).

Then in `ClusterVisualizerRoom.onCreate`, add two overlapping model entities, positioned so their
bounding volumes genuinely intersect (close enough together that a whole-object painter's sort
would visibly get their relative front/back order wrong from at least one camera angle, matching
this plan's testing requirement for a real, checkable regression) - this exact pattern (`new
BGE.GameEntity(game, args)`, `new BGE.DrawableModel(entity, model, args)`,
`entity.addDrawable(name, drawableObj)`) is confirmed against `GameEntity.new()`
(`src/source/engine/GameEntity.bs:61`, `function new(gameEngine as Game, args = {} as
roAssociativeArray)`, which calls `m.append(args)` - so `{name: "..."}` in the constructor args
does set the entity's name) and `examples/3d/src/source/Entities/Model3d.bs`'s own
`new BGE.DrawableModel(m, m.game.get3dModel("bird"))` + `m.addDrawable("model", m.modelDraw)`
usage:

```brightscript
    model = m.game.get3dModel("bird")

    modelEntity1 = new BGE.GameEntity(m.game, {name: "ModelA"})
    modelEntity1.position = BGE.Math.VectorOps.create(700, 0, 300)
    drawableModel1 = new BGE.DrawableModel(modelEntity1, model, {drawMode: BGE.SceneObjectDrawMode.solidDrawBackFace, scale: BGE.Math.createScaleVector(5)})
    modelEntity1.addDrawable("model", drawableModel1)
    m.game.addEntity(modelEntity1)

    modelEntity2 = new BGE.GameEntity(m.game, {name: "ModelB"})
    modelEntity2.position = BGE.Math.VectorOps.create(720, 0, 320)
    drawableModel2 = new BGE.DrawableModel(modelEntity2, model, {drawMode: BGE.SceneObjectDrawMode.solidDrawBackFace, scale: BGE.Math.createScaleVector(5)})
    modelEntity2.addDrawable("model", drawableModel2)
    m.game.addEntity(modelEntity2)
```

(`Game.addEntity(entity, args)` (`src/source/engine/Game.bs:1249`) is called last, after the
drawable is attached, matching the order every other entity in this file already uses via
`m.game.addEntity(new ClusterProbeEntity(m.game), {...})` - the entity object itself, not the
`addEntity` call, is what needs the drawable attached first here since this task builds the entity
directly rather than through a custom subclass's own `onCreate`.)

- [ ] **Step 3: Build and validate**

Run: `cd examples/depthsort && npm run build`
Expected: no errors.

- [ ] **Step 4: On-device visual verification**

Sideload and screenshot per the `rokubot-examples` skill workflow. Confirm:
- The two overlapping models are both visible with their faces correctly interleaved (not one
  model's whole silhouette entirely occluding the other where their volumes overlap) - compare
  against toggling `computeOverlapClusters` off temporarily (a quick local edit, reverted after)
  to see the old, incorrect whole-object-occlusion behavior for contrast.
- Navigating from `ClusterVisualizerRoom` to `TieBreakRoom` no longer leaves `computeOverlapClusters`
  stuck on (this is harder to observe directly on-screen - confirm via a temporary `game.log()`
  print of `m.game.canvas.renderer.computeOverlapClusters` in `TieBreakRoom.onCreate`, reverted
  after confirming, or by reading the LogDisplay debug panel).

- [ ] **Step 5: Commit**

```bash
git add examples/depthsort/
git commit -m "Add interleaved-model-draw-order demo to ClusterVisualizerRoom, fix computeOverlapClusters reset on room exit (#59, depth-sort Plan 2)"
```

---

### Task 10: Final validation - full quality gate, all examples, and on-device re-measurement

**Files:** none modified - validation only.

- [ ] **Step 1: Run the full quality gate**

Run: `npm run check`
Expected: lint clean, validate clean, all tests passing.

- [ ] **Step 2: Validate every example**

Run: `npm run validate-examples`
Expected: no errors, including `examples/depthsort` and `examples/3d`.

- [ ] **Step 3: Rebuild every example**

Run: `npm run build-examples`

- [ ] **Step 4: Re-run the on-device `TreesRoom` measurement one more time against the final code**

Repeat Task 6's measurement (temporarily set `computeOverlapClusters = true` in
`examples/3d/src/source/main.bs`, sideload, measure `TreesRoom`'s FPS, revert) - this confirms
Task 7/8's draw-loop changes didn't reintroduce a regression on top of Task 6's already-confirmed
broad-phase fix. Record the final before/after numbers.

- [ ] **Step 5: On-device sanity check of `examples/depthsort`'s existing rooms**

Sideload `examples/depthsort` and confirm, per the lesson from Plan 1: `ClusterVisualizerRoom`'s
existing false-positive/red-outline behavior still works correctly (it exercises detection only,
Task 7/8 doesn't change `getOverlapClusters()`'s contents, only what happens to a multi-member
cluster's members visually), and `TieBreakRoom`'s tie-break demonstration still shows no popping.

- [ ] **Step 6: Update `CLAUDE.md`**

In the "Renderer / SceneObjects" section, extend the existing Plan-1-era `BGE.DepthSort` bullet (or
add a new one directly after it) to document: the sort-and-sweep broad phase replacing the old
all-pairs scan (with the measured before/after numbers), and the
`getPrimitiveCount()`/`getPrimitiveDepth()`/`drawPrimitive()` contract with the design rationale
for why billboard caching isn't suspended but model caching is bypassed for per-face drawing.
Cross-reference `specs/2026-08-16-depth-sort-plan-2-design.md`.

- [ ] **Step 7: Commit**

```bash
git add CLAUDE.md
git commit -m "Document sort-and-sweep broad phase and cluster draw contract in CLAUDE.md (#59, depth-sort Plan 2)"
```

- [ ] **Step 8: Open the PR**

Push the branch and open a PR against `main` referencing #59, summarizing the broad-phase fix (with
before/after FPS numbers), the new cluster draw behavior, and the `QuickHull`/residual-Minor fixes
folded in along the way.
