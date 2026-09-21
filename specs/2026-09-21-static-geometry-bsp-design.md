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

Real BSP tree, built once over static geometry, with dynamic objects inserted into the
traversal rather than split against it - the classic technique (Doom-style): only static
geometry needs a tree/splitting; a moving object is just classified against each node's
plane as the walk reaches it.

Considered and rejected: a heuristic depth-*range* key per static quad (no real tree, much
less code) that forces a dynamic object inside a static quad's near/far range to draw after
it. Rejected because it's only correct for simple axis-aligned rooms, not general level
geometry (angled walls, multiple overlapping static quads) - given performance is priority
#1 but correctness ranks above code simplicity, a heuristic that's "correct for box rooms"
isn't good enough for what #107 is actually for (foundation for real level geometry, #62/#63).

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

Classic BSP construction over static quads' world-space corner planes: pick a partition
quad from the remaining list, clip every other remaining quad front/back against its plane
(Sutherland-Hodgman-style), recurse on each side; coplanar quads stay together in the same
node. For the realistic case (a room's wall faces, which share edges but don't interpenetrate
each other) this rarely needs to actually split anything - the clipping code exists for
general level geometry (per #107's own scope questions) but only costs anything at build
time, which happens once per room (or once per static-geometry change, which should be rare
- level load, not per-frame).

## Per-frame traversal

Standard back-to-front BSP walk: at each node, compare the camera's position against the
node's plane to decide which child subtree is farther, visit it first, draw this node's
static quad(s), then visit the near subtree. Dynamic (non-static) scene objects are
classified against the current node's plane and drawn at the matching point in the walk
instead of being split. No `new`/class instantiation inside this path - plain arrays/AAs
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

- `SceneObjectPlane` participation in BSP.
- Full `SceneObjectModel` mesh splitting (only flat quads for v1).
- Compile-time/structural enforcement that a static entity never moves (warning + rebuild
  only).
- Updating `examples/3d`/`examples/terrain` to mark any of their own geometry `isStatic` -
  a separate follow-up pass once this lands, per the project's example-update priority.
