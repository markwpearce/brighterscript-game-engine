# Static geometry BSP for correct draw order against dynamic objects

Design for [#107](https://github.com/markwpearce/brighterscript-game-engine/issues/107).

## Problem

`Renderer.drawScene()` sorts `sceneObjects` by one scalar per object
(`negDistanceFromCamera`) and draws back-to-front - a whole-object painter's sort. #59's
clustering (see `2026-08-15-depth-sort-design.md`) fixed ordering between objects whose
*bounds* overlap but whose geometry doesn't truly interpenetrate. It doesn't fix the case
where a flat static quad (a wall) spans a depth range that a dynamic object (a ball) sits
partway through - a single scalar per wall can't represent "the ball is behind the near
wall but in front of the far wall." That's `examples/collisions3d`'s disabled wall images
([Wall.bs:13](../examples/collisions3d/src/source/Entities/Wall.bs#L13)) - the concrete,
currently-broken case this design fixes.

## Scope

v1 targets flat static quads only - `SceneObjectBillboard`-family objects (walls, props:
`SceneObjectImage`, `SceneObjectRectangle`, etc., not full `SceneObjectModel` meshes).
`SceneObjectPlane` (ground/terrain) is out of scope - it already draws in its own
always-first pass ([Renderer.bs:497-508](../src/source/engine/renderer/Renderer.bs#L497-L508))
via trapezoid-slice rasterization, not the normal painter's sort, and there's no evidence
that path is currently wrong. Folding it into BSP is a separate, larger change to defer.

## Approach

BSP tree, built once over static geometry, with dynamic objects inserted into the
traversal by classification rather than split against it - the classic technique
(Doom-style): a moving object is just classified against each node's plane (which side of
the wall's plane is the ball/cat on?) as the walk reaches it, no geometry cutting involved.

**v1 does not do true polygon splitting between two static quads.** The motivating cases
(a ball resting on a static table/floor quad, a cat passing behind one wall segment and in
front of another, `collisions3d`'s ball-inside-a-box) are all *dynamic-object-vs-static-plane*
classification - none of them require cutting one static quad against another, since real
level geometry (walls, floors) shares edges rather than crossing through each other's
interior. True splitting only matters for two *static* quads that genuinely interpenetrate,
which has no concrete case in this codebase today and would require partial-texture/UV-clipped
draws to render a cut fragment correctly - a materially larger feature for a hypothetical
case. Classification-only build is a simple binary partition: pick a quad as the node,
sort every other static quad to front/back by its center's sign relative to that plane,
recurse. Two static quads that do truly interpenetrate remain a known, documented v1
limitation (see Out of scope).

Considered and rejected: a heuristic depth-*range* key per static quad (no tree at all,
even less code) that forces a dynamic object inside a static quad's near/far range to draw
after it. Rejected in favor of the classification tree because the heuristic is only
correct for simple axis-aligned rooms, not general level geometry (angled walls, multiple
overlapping static quads) - given performance is priority #1 but correctness ranks above
code simplicity, a heuristic that's "correct for box rooms" isn't good enough for what
#107 is actually for (foundation for real level geometry, #62/#63), and the classification
tree isn't meaningfully more expensive to build or walk.

## Marking static geometry

`GameEntity.isStatic as boolean = false` - a new field. An entity marked `isStatic` must
never change `position`/`rotation`/`scale` after its drawables register with a renderer.
This is a documented usage contract, not compile-time enforced (see Misuse detection below).

## Components

- `BGE.BSP.StaticGeometryTree` (new, `renderer/bsp/`) - owns the tree: build, traversal,
  and the front/back plane classification helper used by both.
- `Renderer.staticTree as object = invalid` - lazily created on the first static
  `SceneObject` registration. Stays `invalid` for any renderer with no static geometry.
- `Drawable.addToScene()` → `Renderer.addSceneObject()`: reads the owning entity's
  `isStatic`. A static object still lives in `m.sceneObjects` (culling, `isOnScreen()`,
  etc. all still apply) but is flagged (`SceneObject.isStatic`) and excluded from the
  normal per-frame `sortBy`/draw loop. `participatesInOverlapDetection()` returns `false`
  for it - BSP supersedes clustering for these objects. Registration (or removal) marks
  the tree dirty.

## Build (once, on dirty)

Binary partition over static quads' world-space plane (a point + normal, from each quad's
`BGE.Math.CornerPoints.getCenter()`/`getNormal()`): pick one remaining quad as a node, then
classify every other remaining quad's center against that plane
(`BGE.Math.distanceFromPlane`) into a front list and a back list, recurse on
each. No clipping/splitting - a quad is always assigned whole to one node. Cost is paid
once per room (or once per static-geometry change, which should be rare - level load, not
per-frame).

## Per-frame traversal

Standard back-to-front BSP walk: at each node, compare the camera's position against the
node's plane (same `distanceFromPlane` helper) to decide which child subtree is farther,
visit it first, draw this node's static quad, then visit the near subtree. Dynamic
(non-static) scene objects are partitioned against the current node's plane the same way and
carried down into the matching child call, so they're drawn at the correct point in the walk;
a leaf with no more static geometry to disambiguate against sorts its remaining dynamic
objects by their existing `negDistanceFromCamera` scalar (today's painter's-algorithm key)
before appending them. No `new`/class instantiation inside this path - plain arrays/AAs
only, consistent with how clustering (`DepthSort.bs`) already avoids per-frame allocation
of anything beyond arrays.

**Zero-static fallback**: if `Renderer.staticTree` is `invalid`, `drawScene()` takes exactly
today's code path, unchanged. This guarantees existing 2D examples and any 3D example that
hasn't opted in (`examples/3d`, `examples/terrain`, until a later pass considers them) see
no behavior or performance change.

## Misuse detection: a static entity that moves anyway

Piggybacks on the transform dirty-check every `Drawable` already runs
(`computeTransformationMatrix`'s `MotionChecker` use) rather than adding a new per-frame
check - if that existing check reports real movement on a `SceneObject` flagged `isStatic`:

- Log once (not every frame - gated behind a `staticWarningLogged` flag on the object) via
  `m.game.log("GameEntity '<name>' is marked isStatic but its position/rotation/scale
  changed after registration - rebuilding the static geometry tree", BGE.Debug.LogLevel.warning)`.
  A warning, not a thrown error, matching every other misuse case in this codebase (missing
  collider, duplicate drawable name, etc.).
- Also marks the static tree dirty, so it rebuilds (same lazy-rebuild path registration
  uses) rather than silently staying stale. This is a real per-rebuild cost, but only paid
  on the misuse path - the common (correct-usage) case never pays it.

## Testing

- Rooibos specs for tree build + traversal ordering correctness (pure geometry, doesn't need
  a real `Game`).
- Re-enable `collisions3d`'s wall images - the concrete proof case: a ball visibly correct
  against both near and far walls of the box.
- A `rendererTest` benchmark demo, old path vs. new, per this repo's "measure, don't guess"
  convention for any rendering change.
- Confirm `examples/3d`/`examples/terrain` (no `isStatic` usage yet) are unaffected before
  any example is updated to use the new flag.

## Out of scope for this pass

- `SceneObjectPlane` participation in BSP. A flat surface that needs correct ordering
  against dynamic objects (a table, a room floor) should be built as a static
  `SceneObjectRectangle`/`SceneObjectImage` quad, not the Mode-7 ground-plane system, to
  get BSP's classification.
- True polygon splitting between two static quads that genuinely interpenetrate (see
  Approach) - a known, documented limitation, not silently wrong-but-unnoticed.
- Full `SceneObjectModel` mesh splitting (only flat quads for v1).
- Compile-time/structural enforcement that a static entity never moves (warning + rebuild
  only).
- Updating `examples/3d`/`examples/terrain` to mark any of their own geometry `isStatic` -
  a separate follow-up pass once this lands, per the project's example-update priority.
