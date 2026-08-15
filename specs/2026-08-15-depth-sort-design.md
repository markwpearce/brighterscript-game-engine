# Smarter depth/visibility for the renderer

Design for [#59](https://github.com/markwpearce/brighterscript-game-engine/issues/59).

## Problem

`Renderer.drawScene()` sorts the whole `sceneObjects` array by one scalar per object
(`negDistanceFromCamera`, from a single world point - `SceneObject.getPositionForCameraDistance()`)
and draws back-to-front. This is a **painter's algorithm at object granularity**, and it fails
whenever two objects' primitives need to interleave rather than one drawing wholly before the
other: interpenetrating quads/models, model faces from two different models, an entity straddling
`SceneObjectPlane`'s hardcoded first-pass hack. See the issue for the full symptom list.

The fix has to work within this engine's real constraint: no hardware z-buffer, and CPU-side pixel
access (`GetPng`/byte-array round-trips) is far too slow for a per-frame budget - see the
`roku-draw2d-performance` numbers linked from the issue. So this is about a smarter *visibility
algorithm*, not a literal z-buffer.

## Approach: sort primitives only where objects actually contest the same space

A full "flatten every primitive in the scene into one global list and sort it" (the issue's
candidate #1) fixes the ordering problem, but at a real cost most objects don't need to pay: it
throws away `SceneObjectBillboard`'s whole-object temp-bitmap caching (and the cheap
transform-reuse `attemptTransformTempBitmap` already does when an object hasn't moved much) for
*everything*, including the large majority of objects that don't overlap anything else on screen
at all this frame.

The key realization: **primitive-level interleaving is only necessary between objects whose
extents actually overlap in both screen space and depth.** Two objects that don't overlap on
screen produce an identical result whichever whole-object order they're drawn in. So the design
is a broad/narrow-phase overlap test - the same shape collision detection in a physics engine
takes - that isolates the (typically small) set of objects that genuinely contest space, and only
pays the expensive primitive-sort/no-cache cost for those:

- **Solo objects** (the common case): unchanged from today - whole-object depth key, whole-object
  temp-bitmap caching, drawn via the existing per-object painter's sort.
  Zero regression from today's behavior or cost.
- **Objects in a multi-member overlap cluster**: temp-bitmap caching suspended for as long as they
  stay clustered; their primitives are flattened and depth-sorted *within that cluster only*, then
  drawn interleaved.

This does not implement BSP-style polygon splitting - it cannot correctly order two primitives
that actually intersect/interpenetrate in 3D space (no single scalar orders that; you'd see a
wrong seam right at the intersection line). That's a separate, much bigger effort, useful mainly
for **static** geometry where the one-time tree-build cost is a non-issue - filed separately as
[#107](https://github.com/markwpearce/brighterscript-game-engine/issues/107). This design
correctly handles the practically-common case instead: separate objects whose *bounds* overlap
without their actual geometry crossing (two models standing near each other, an entity at the edge
of a plane, a quad passing in front of - not through - a model).

## Prerequisite: two cheap, always-on fixes

These land regardless of the clustering work, since clustering needs them anyway (a bigger,
per-cluster primitive list is pointless to re-sort every frame if nothing moved) and they're safe,
independently-valuable wins on their own:

1. **Skip the sort when nothing that affects order changed.** `SceneObject.update()` already
   dirty-checks whether it needs to recompute `negDistanceFromCamera`
   (`cameraObj.movedLastFrame() or objMovedLastFrame or drawModeChanged`) - but `drawScene()`
   calls `sortBy` unconditionally regardless. `SceneObject.update()` will expose whether it
   recomputed depth this frame; `Renderer.updateSceneObjects()` ORs these together (plus a flag
   set by `addSceneObject`/`removeSceneObject`, since the list itself changing also requires a
   resort) into a single `needsDepthSort` flag `drawScene()` checks before sorting.
2. **Stable tie-breaking for near-equal depths.** A genuine depth crossover (two objects' true
   order swaps as the camera passes) is an inherent limitation of any single-scalar-key painter's
   sort - no tie-break avoids that hard swap, and it's not what this fixes. What it does fix:
   floating-point jitter causing two objects at *genuinely equal or near-equal* depth (e.g. a row
   of coplanar entities) to swap order from frame to frame with no real motion behind it. Depths
   within a small epsilon of each other keep their previous relative order instead of whatever
   `roArray.SortBy` happens to produce for near-ties.

## Overlap clustering

### Broad phase: AABB + depth range, reusing existing bounding data

Every `SceneObject` already computes `getPositionsForFrustumCheck(drawMode)` - a small set of
world-space points bounding the object (4 corners for a billboard, an 8-point bounding cube for a
model/polygon via `BGE.Math.getBoundingCubePoints`, 2 endpoints for a line). The broad phase reuses
these exact points rather than computing new geometry:

- Project each point through `worldPointToCanvasPoint()` (already used for drawing) to get a
  screen-space AABB (min/max x/y across the projected points).
- Compute a depth range from the same points via `cameraObj.distanceFromCameraFront()` (min/max
  across the points) - reusing the same per-point distance function `negDistanceFromCamera`
  already calls once per object today, just called across the whole point set instead of one.

Two objects are broad-phase candidates only if both their screen AABBs *and* their depth ranges
overlap. This is deliberately loose and fast - it exists to cheaply reject the large majority of
non-candidate pairs, not to be precise. `O(n²)` pair comparisons across visible objects is expected
to be cheap in practice (an AABB+range overlap check is a handful of comparisons, nowhere near the
cost of a draw call), but this is exactly the kind of claim the project's own rule says to
*measure*, not assume - see Testing, below. A spatial grid/hash to cut this down is a candidate
future optimization if a real scene proves it necessary, not part of this pass.

### Narrow phase: exact test, only for broad-phase candidates

The broad phase is intentionally loose - a long diagonal wall's AABB has to cover its full
diagonal extent, creating a lot of "empty" bounding area a nearby-but-not-actually-overlapping
object could fall inside. The narrow phase exists precisely to reject those false positives before
committing to the expensive clustered path:

- For a billboard/wall, its real shape is its 4 actual corners (already computed).
- For a model, its real shape is its own bounding hull/cube (the same 8 points `getBoundingCubePoints`
  already produces) - **not** a per-face test. A model that's confirmed to overlap something
  explodes entirely (all its faces go into the cluster's primitive list), not just the specific
  faces that actually conflict. Finer-grained per-face clustering is a possible future refinement,
  not part of this pass.
- Test via the separating-axis theorem (SAT) between the two objects' convex screen-space shapes,
  plus confirming the depth ranges genuinely overlap. `src/source/utils/quickhull.bs` already
  implements convex hull computation (used for 3D model face computation) - SAT needs the two
  hulls' edges as candidate separating axes, which quickhull's output already provides directly.

Only pairs that pass **both** phases join an overlap cluster (union-find/connected-components over
the pairs that survive the narrow phase - most objects end up alone in a cluster of one).

### Drawing a cluster

- A solo cluster (the common case) draws exactly as today: `SceneObject.draw()` unchanged, full
  temp-bitmap caching, sorted against other clusters by the cluster's own single depth key (the
  minimum depth among its member(s) - reusing the same "nearest point" idea from the depth-key
  cheap-win, now expressed at the cluster level instead of always needing a per-`SceneObject`
  override).
- A multi-member cluster suspends temp-bitmap caching for its members and instead has each member
  emit its own primitives (a billboard's one quad, a model's `modelCanvasFaces` - already a
  per-face list with each face's own depth priority computed via the same logic
  `SceneObjectModel`'s existing intra-model sort already uses) into a list scoped to *that cluster
  only*. The cluster's combined primitive list is depth-sorted once and drawn in interleaved order.
  This is `SceneObjectModel`'s existing intra-model face sort, generalized to span every member of
  the cluster instead of just one model's own faces - `SceneObjectModel`'s own per-model sort logic
  is subsumed into this, not duplicated alongside it.

### Cluster membership changes frame to frame

An object's cluster can change size as objects move (a monster walks up next to a wall, then walks
away). Entering a multi-member cluster invalidates that object's temp-bitmap cache (its
`m.tempBitmap` field, or the moral equivalent per-subclass); leaving one back down to a solo
cluster lets it resume the normal caching path on its next draw, no different from any other
first-frame-after-a-change case the caching logic already handles today (`isRedrawToCanvasRequired`).

## `SceneObject` draw contract change

`performDraw()`/`drawToCanvas()`/`drawToTempBitmap()` currently assume "this object draws itself."
Membership in a multi-member cluster needs a different entry point: "give me your primitives with
their depths, don't draw yet." The exact new method signature(s) - most likely something like
`getPrimitivesForClusterDraw() as BGE.RendererHelpers.DepthPrimitive[]` that `SceneObjectBillboard`
implements as "my one quad" and `SceneObjectModel` implements as "my `modelCanvasFaces`, one entry
per face" - is an implementation-plan-level decision once the exact primitive shape (screen points
+ color/region + depth) is nailed down against real code, not a design-level one.

## `examples/depthsort`

A new, dedicated example (matching the existing one-example-per-mechanism precedent:
`examples/terrain`, `examples/canvas`, `examples/tweens`, `examples/parallax`) - not folded into
`examples/3d`, since this is about multi-object interaction rather than showing off one drawable.
Reusable as the regression bed for this issue's follow-ups (#105, #107) too, not just this pass.

- **A `Camera2d` room**: a row of coplanar/near-coplanar entities to demonstrate the tie-breaking
  fix (jitter-free ordering) versus a toggle showing the old unstable behavior for comparison.
- **A `Camera3d` room** (camera controls via `BaseRoom`, same pattern `CirclesRoom`/`RectanglesRoom`
  already use): two interpenetrating quads, two overlapping `Model3d` instances, and an entity
  straddling `SceneObjectPlane` - each demonstrating a clustering fix directly, with an on-screen
  toggle to disable clustering and show the old broken behavior for comparison. Also includes the
  wall-plus-nearby-model scenario (a tall diagonal `DrawableRectangle` wall with a `Model3d` next
  to it, not touching) specifically to demonstrate the narrow phase correctly keeping them in
  separate, cached, solo clusters - a visible regression check for the false-positive concern this
  design exists to avoid.

## Testing

- Rooibos specs for the broad/narrow-phase overlap test as pure functions (given known bounding
  points for two objects, do they cluster or not) - testable without a real `Game`/`Renderer`.
- Rooibos specs for the skip-sort and tie-break logic against a real `Renderer`/`SceneObject`
  pair, following the existing `SceneObjectRectangle.spec.bs`-style real-`Renderer`-over-a-real-
  `bitmap` pattern.
- Manual/visual verification via `examples/depthsort`, sideloaded to a device/simulator - per the
  project's "measure, don't guess" rule, this includes actually timing the broad-phase
  `O(n²)` cost at a representative entity count (a `rendererTest`-style before/after draw-call and
  frame-time comparison, or an on-screen counter in the new example) rather than assuming it's
  cheap enough.

## Out of scope

- **True polygon intersection/BSP** for genuinely-interpenetrating primitives - filed as
  [#107](https://github.com/markwpearce/brighterscript-game-engine/issues/107), aimed at static
  level geometry where a one-time tree build is affordable.
- **Occlusion culling** (the original code's own `TODO` wording) - orthogonal to ordering, cuts
  primitive count rather than fixing draw order.
- **Per-tile/per-region depth resolution** (the issue's candidate #6) - a plausible middle ground
  in principle, but Roku's `ifDraw2D` has no native clip-rect support, so per-tile clipping would
  need extra scratch-bitmap/region work per tile per object; likely a worse engineering fit for
  this platform than clustering. Not pursued here.
- **A finer-grained, per-face (rather than per-model) narrow phase** - noted above as a possible
  future refinement once the coarser per-model version is measured.
