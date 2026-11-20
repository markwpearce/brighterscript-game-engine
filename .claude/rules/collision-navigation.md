---
paths:
  - "src/source/engine/colliders/**"
  - "src/source/engine/navigation/**"
  - "src/source/engine/gridMaps/**"
---

# Collision and pathfinding

- `CircleCollider`/`RectangleCollider` use `roCompositor.CheckMultipleCollisions()`; `onCollisionEnter`/`onCollisionExit` are diffed per frame.
- Edge-to-edge contact isn't overlap: snapping flush stops `onCollision` next frame, so "reset grounded every frame" flickers.
- `SphereCollider3d`/`BoxCollider3d`: true 3D overlap (two compositor planes + exact maths). `Game.raycast()`/`raycastAll()` → `BGE.RaycastHit`.
- Static geometry: `resolveAabbTileCollision()` (tile platformers), `BGE.SolidWorld.moveAndSlide()` (top-down), or `track(entity, radius)` + `resolveTracked()` to replay each body's frame move after everything moved it (opt-in auto-resolve: `GameScene.trackedSolidWorld`, run after `onPostUpdate()`). `BGE.separateCircles()` pushes characters apart by mass.
- Pathfinding (`docs/pathfinding.md`): `BGE.NavGrid` rasterises a `SolidWorld` (solids grown by `agentRadius`) into a byte-per-cell grid; `findPath()`/`startSearch()` run 8-way A* (no corner cutting, `step(budgetMs)` across frames) and smooth by grid line of sight. The hot loop is one inlined function over a border-padded grid with pooled per-cell state. Uses `SolidWorld` 2D coords (y = world z on a ground plane).
- Text-grid levels on the ground (`docs/tile-maps.md`): `BGE.CharGrid` (cells, `findRectGroups`/`findConnectedGroups`/`boundsOf`/`findRuns`, `wallSides`, `toSolidWorld()`) and `BGE.GridSides`. Character meaning stays with the game; thirdPerson's four maps extend it and pin its exact outputs (same group order, solid ids, float centres).
