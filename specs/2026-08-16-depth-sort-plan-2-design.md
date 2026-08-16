# Depth sort, Plan 2: real broad-phase acceleration + clustered draw order

Design for [#59](https://github.com/markwpearce/brighterscript-game-engine/issues/59), continuing from
[Plan 1](2026-08-15-depth-sort-design.md) (PR [#111](https://github.com/markwpearce/brighterscript-game-engine/pull/111),
merged) which landed the always-on skip-sort/tie-break fixes plus overlap *detection* (broad-phase
AABB+depth-range test, narrow-phase SAT test, union-find clustering) - all gated behind
`Renderer.computeOverlapClusters`, defaulting to `false`, with nothing in the actual draw path
consuming a cluster yet.

## Why this plan exists now, not later

Plan 1's own PR description flagged an explicit known gap: the broad phase's real-world cost was
never measured on-device before merging (no reachable device that session). It has been measured
since, on real hardware ([#59 comment](https://github.com/markwpearce/brighterscript-game-engine/issues/59)):

- `examples/3d`'s `TreesRoom` (~176 real scene objects, no debug-visualization inflation):
  **~31-36 FPS baseline -> 9 FPS with `computeOverlapClusters = true`** - roughly a 70% drop, and
  stable at that floor, not a transient GC blip.
- `examples/asteroids` (~5-10 objects at once): no measurable difference either way - the object
  count there is simply too low to expose the cost.

This confirms the design's own guess ("`O(n^2)` pair comparisons... is expected to be cheap in
practice... but this is exactly the kind of claim the project's own rule says to *measure*, not
assume") was wrong at even a modest, plausible object count. The current broad phase is an
all-pairs scan over every candidate object - literally `O(n^2)` comparisons, each involving a
`getScreenBounds()` call. Building real draw-order behavior on top of that would mean the feature
could never be safely turned on for anything but a toy scene, so this plan fixes the broad phase
*before/alongside* the actual clustered-draw work Plan 1 deferred, not after.

## Part A: Sort-and-sweep broad phase

Replaces the current all-pairs scan inside `BGE.DepthSort.groupIntoClusters()` (called from
`Renderer.drawScene()`, still gated behind `Renderer.computeOverlapClusters`). The narrow phase
(SAT test, `hullsOverlap()`) is unchanged - this only changes *which pairs* reach it.

### Why sort-and-sweep over a spatial grid

A uniform spatial grid was the design's original follow-up idea ("a spatial grid/hash to cut this
down is a candidate future optimization"). Sort-and-sweep (aka sweep and prune - the standard
broad-phase technique physics engines like Box2D/Bullet use for exactly this "arbitrary AABBs,
need broad-phase before narrow-phase" problem) was chosen instead because:

- **No tuning parameter.** A grid needs a cell size, and the right size is scene-dependent (a
  sprite-heavy game and a few-huge-walls game want different sizes) - get it wrong and either too
  many objects share a cell (defeating the purpose) or a large object spans too many cells.
- **Handles the diagonal-wall pathology natively.** A long, thin AABB (the original motivating
  concern for the narrow phase) doesn't need special multi-cell insertion logic - it just costs
  sweep time proportional to how many *other* objects' X-ranges it actually overlaps, which is the
  real quantity that matters.

### Algorithm

Per frame, inside `groupIntoClusters()`:

1. Build each candidate object's `ScreenBounds` up front (already exists via `getScreenBounds()` -
   no change here).
2. Sort the candidate list by `minX` - **incrementally (insertion sort), not a fresh sort every
   frame.** Most objects don't jump far frame-to-frame, so the list is already nearly sorted from
   last frame; insertion sort on a nearly-sorted list is close to `O(n)` in practice, and unlike
   `roArray.SortBy` (which re-sorts from scratch) it preserves temporal coherence a moving-object
   game already has for free. The sorted order (and the objects it was computed from) needs to
   persist frame-to-frame on the `Renderer` - a new field, not a locally-scoped list rebuilt fresh
   every call.
3. Sweep left to right maintaining an "active" set - objects whose `maxX` hasn't been passed yet
   by the current sweep position. Each new object entering the sweep is tested only against the
   current active set (not the whole candidate list): this is where the quadratic blowup
   disappears - two objects whose X-ranges never overlap are never even considered as a pair.
4. Only pairs whose X-ranges overlap proceed to the existing depth-range check
   (`boundsOverlap()`'s Y/depth portions - or just re-run the full `boundsOverlap()`, simplest to
   reuse it directly since X-overlap is necessary but not sufficient) and then the existing
   narrow-phase SAT test (`hullsOverlap()`). Nothing about the narrow phase changes.

### Correctness under the incremental sort

An insertion sort assumes the input is *nearly* sorted - it is still fully correct (just not
`O(n)`-fast) if an object moves far enough to require many swaps in one frame, or if the candidate
set itself changes (an object added/removed, or enters/exits `getClusterCandidates()`'s
enabled/non-culled filter). No special-casing is needed for these cases; insertion sort handles an
arbitrarily-scrambled input correctly, just not necessarily cheaply on that one frame. Object
identity across frames (so "this object's previous sorted position" means something) is via
`SceneObject.id`, the same identity mechanism `Renderer.getSceneObjectIndexById()` already uses.

### Testing

- A pure-function Rooibos suite comparing the sweep's candidate pairs against a brute-force
  reference `O(n^2)` scan across a range of synthetic layouts (scattered, all-overlapping,
  all-disjoint, one huge diagonal AABB among many small disjoint ones) - correctness first.
- A dedicated regression test reproducing the diagonal-wall-among-disjoint-objects scenario and
  asserting the sweep visits a bounded number of candidate pairs (not literally timing it in a
  unit test, but counting comparisons/active-set size as a proxy) to guard against silently
  regressing back to all-pairs behavior.
- **On-device re-measurement is mandatory, not optional**: re-run the exact `examples/3d`
  `TreesRoom` A/B comparison from the GitHub issue against this fix, and report the actual
  before/after FPS numbers in the PR - the whole reason this plan exists is a measured regression,
  so it needs a measured fix, not an assumed one.

## Part B: Drawing a cluster (the `SceneObject` draw contract change Plan 1 deferred)

### New capability

Two new methods on `SceneObject` (defaults on the base class, overridden per subclass):

- `getPrimitiveCount() as integer` - how many separately-orderable pieces this object currently
  has. Base class default: `1` (a billboard is always one quad, regardless of draw mode - matches
  `SceneObjectBillboard`/`SceneObjectImage`/`SceneObjectRectangle`/`SceneObjectCircle`/`SceneObjectText`,
  none of whose draw modes produce a variable piece count).
- `drawPrimitive(rendererObj as Renderer, index as integer) as boolean` - draw piece `index`
  now, returning whether it actually drew something (mirroring the existing `draw()`/
  `drawToCanvas()` return convention). Base class default for index `0`: delegate to the object's
  existing whole-object draw path (so a solo billboard's cluster-path draw and its normal draw
  path are the same call, not a second implementation to keep in sync).

`SceneObjectModel` overrides both:

- `getPrimitiveCount()` returns `m.modelCanvasFaces.count()` - the face list `updateCanvasPosition()`
  already rebuilds every frame, already correctly reflecting the resolved draw mode's backface-cull
  behavior (verified against the actual code: `oriented`/`solid`/`wireFrame` only include
  front-facing faces via the `isNormalFacingCamera()` check *before* a face is pushed into
  `modelCanvasFaces`; the `*DrawBackFace` variants short-circuit that check to always-true, so
  every face is included; `matchCamera`/`directToCamera`/`directScaled` draw nothing today via
  either draw path, so `modelCanvasFaces` being non-empty for those modes is harmless - `drawPrimitive`
  for those modes returns `false` the same way the existing whole-object draw already silently
  no-ops for them). **No new draw-mode-awareness needs to be added at this layer** - it inherits
  correctness for free from code that already exists and is already correct.
- `drawPrimitive(rendererObj, index)` draws `m.modelCanvasFaces[index]` via whichever of
  `drawTriangle`/`drawTriangleOutline` the resolved draw mode already selects in the existing
  per-face loop - this becomes the one and only place that per-face draw dispatch lives; the
  existing `drawToCanvas`/`drawToTempBitmap` loops become thin wrappers that call
  `drawPrimitive()` for every index in sequence, rather than a second, parallel implementation.

### Cluster draw loop

In `Renderer.drawScene()`, after `groupIntoClusters()` (still gated behind
`computeOverlapClusters` - this plan does not change that default):

- A solo cluster (a cluster of exactly one member - the overwhelming common case, more so now that
  sort-and-sweep makes "not overlapping anything" cheap to detect) draws exactly as it does today:
  unchanged whole-object temp-bitmap caching, no primitive enumeration, `draw()` called once. This
  is the zero-regression path the whole design has insisted on from the start.
- A multi-member cluster: for each member, call `getPrimitiveCount()` and build one entry per
  primitive (member + index + a depth key - reusing each face/quad's existing per-primitive depth
  computation, e.g. `SceneObjectModel`'s existing `priority` field per face, or the object's own
  `negDistanceFromCamera` for a billboard's single primitive) into a list scoped to *that cluster
  only*. Sort that list once by depth, then call `drawPrimitive()` in that order. This generalizes
  `SceneObjectModel`'s existing intra-model face sort to span every member of the cluster, rather
  than duplicating similar sort logic at two levels - a model that's part of a multi-member cluster
  has its faces interleaved with the *other* members' primitives in one combined sort, not sorted
  against its own faces first and then placed as a block.

### Cache invalidation on cluster membership change

No new mechanism needed. Entering a multi-member cluster suspends that object's temp-bitmap
caching for the frames it stays clustered (checked once per frame: "is my cluster's member count
> 1 this frame" gates whether the whole-object cached path or the primitive path runs) - this
reuses the same `isRedrawToCanvasRequired()`-style dirty-checking the caching logic already has for
every other invalidation reason (moved, rotated, drawMode changed, etc.), just adding "am I
currently solo or clustered" as one more input to that existing check. Leaving a multi-member
cluster (back down to solo) resumes the cached path on the very next draw, identical to any other
first-frame-after-a-change case the caching logic already handles.

### Testing

- Rooibos specs for `getPrimitiveCount()`/`drawPrimitive()` on `SceneObjectBillboard` (always 1,
  across every draw mode) and `SceneObjectModel` (varies with draw mode/backface variant - using
  constructed models with known face orientations, directly exercising the four cases confirmed
  above: front-only, front+back, wireframe-same-as-solid, and the three unsupported modes drawing
  nothing).
- Rooibos specs confirming a solo cluster's draw call count/temp-bitmap reuse is unchanged from
  today (regression guard against the zero-regression claim).
- Rooibos specs for the cluster-membership-change cache invalidation (entering/leaving a
  multi-member cluster correctly suspends/resumes caching), following the existing
  `isRedrawToCanvasRequired()` test patterns.
- **On-device visual verification is mandatory, not optional** (per the hard lesson from Plan 1):
  extend `examples/depthsort`'s `ClusterVisualizerRoom` (or add a new room) to actually show
  interleaved draw order now taking visible effect - e.g. two overlapping, genuinely interpenetrating
  quads that previously popped/z-fought now draw in stable per-primitive order - sideloaded and
  screenshotted, not just asserted by unit test.

## Part C: Fix `QuickHull([])` while touching this code (#109)

`BGE.QuickHull.QuickHull()` (`src/source/utils/quickhull.bs`) does not handle fewer-than-3-point
input correctly - `QuickHull([])` returns `[invalid, invalid]` instead of `[]` (`getMinMaxPoints()`
reads `pointsArray[0]` unconditionally). `DepthSortHelpers.bs` already guards against this at the
consumer layer (`isValidHull()`/`MIN_VALID_HULL_POINTS`, landed in Plan 1's final-review fix
round) - this plan fixes it at the source too, since this plan's own broad-phase work touches
`DepthSortHelpers.bs`/`quickhull.bs`-adjacent code again and the existing consumer-side guard was
always meant as a stopgap, not the real fix. Per the filed issue's suggested fix: an early
`if pointsArray.count() < 3 return pointsArray` at the top of `QuickHull()`, matching the existing
`count() = 3` early-return immediately below it. `getTrianglesFromPoints()`/3D model face
computation (the other real caller) benefits from the same fix, not just `DepthSort`.

## Out of scope (unchanged from Plan 1, still deliberate follow-ups)

- **BSP/static geometry** - [#107](https://github.com/markwpearce/brighterscript-game-engine/issues/107).
- **Occlusion culling** - [#108](https://github.com/markwpearce/brighterscript-game-engine/issues/108).
- **Corner-pin blit seam** - [#110](https://github.com/markwpearce/brighterscript-game-engine/issues/110) -
  unrelated code path, not touched by this plan.
- **A finer per-face (rather than per-model) narrow phase** - noted in Plan 1's design as a
  possible future refinement once the coarser per-model version is measured; still not measured as
  a bottleneck, still deferred.
- **A second sweep axis (Y)** - only worth adding if the X-only sweep proves insufficient once
  actually measured on-device; not assumed necessary up front.
- **Making `computeOverlapClusters` default to `true`** - even with the broad-phase fix, this
  stays an explicit opt-in until real-world measurement across a broader range of scenes justifies
  flipping the default; this plan's job is making the opt-in path *actually cheap enough to use*,
  not changing who uses it by default.
