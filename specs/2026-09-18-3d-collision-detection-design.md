# 3D collision detection — design

Issue: [#131](https://github.com/markwpearce/brighterscript-game-engine/issues/131)

## Problem

The existing collision system (`engine/colliders/`: `Collider`/`CircleCollider`/`RectangleCollider`) wraps a Roku `roCompositor`/`roSprite` region per entity and checks overlap via `CheckMultipleCollisions()` in XY/screen space only — `Collider.adjustCompositorObject()` and `Game.processEntityOnCollision()` both call `MoveTo(entityPosition.x, entityPosition.y)`, ignoring `z` entirely. There is no way to detect a true 3D collision between objects that are separated in depth but overlap in screen-projected XY, which is common in the engine's pseudo-3D renderer (billboards, models, `SceneObjectPlane` — see `examples/3d`, `examples/terrain`).

## Spike findings

Before committing to an approach, two throwaway spikes (deleted after use, not part of this design's diff) settled the issue's own open questions:

**Correctness — the two-plane compositor trick has real false positives.** The issue proposed maintaining a second `Collider` in the YZ plane per entity, registering a 3D collision only when both the XY-plane and YZ-plane compositor checks report overlap for the same pair. Constructed via a headless Rooibos spec (real `Game`/`Collider`/`roCompositor`, confirmed working per this repo's own test conventions): two spheres of radius 5 at `(0,0,0)` and `(8,0,8)`. XY-plane distance is 8 (< radius sum 10 → overlap). YZ-plane distance is also 8 (< 10 → overlap). Both planes say "collision" — but the true 3D distance is `√(8² + 0² + 8²) ≈ 11.31 > 10`. They never actually touch. The two-plane trick alone cannot distinguish this from a real hit, because neither plane's compositor check ever sees a depth/penetration value — it's boolean-only.

**Performance — native `roCompositor` checks are dramatically cheaper than any interpreted per-pair math loop**, confirmed both under `brs-cli` (headless) and on a real device via a `rendererTest`-style benchmark demo (`rokubot`-driven, per this repo's established perf-measurement convention — see `examples/rendererTest`'s `quad-fill-benchmark`/`circle-fast-draw-benchmark`). For 40 entities × 100 frames of O(n²) pairwise checking:

| Approach | brs-cli (headless) | Real device |
|---|---|---|
| `roCompositor` (native, O(n) calls) | 70ms | 15ms |
| Pure math via `BGE.Math.VectorOps` (allocates a `Vector` AA per op) | 12,291ms (~175x) | 1590ms (~106x) |
| Raw scalar math, no Vector allocation, squared-distance | 1046ms (~15x) | 312ms (~20.8x) |

Two effects compound here: BrighterScript's interpreted loop/function-call/AA-allocation overhead (consistent with this codebase's existing draw2d perf lore), and `CheckMultipleCollisions()` doing its own broad-phase internally in native code — O(n) calls rather than the O(n²) pairwise loop a hand-rolled check has to do itself. Even the leanest possible math loop can't compete with that structural advantage.

**Conclusion:** don't replace `roCompositor` anywhere, and don't rely on the two-plane trick alone either. Use it as a cheap broad-phase gate, and run a precise 3D math check only on the (rare) candidate pairs that pass both planes — this both fixes the false-positive problem and keeps the native broad-phase's performance advantage.

## Design

### `Collider` base class — two new overridable hooks

Both are extracted from existing logic in `Game.processEntityOnCollision` and default to today's exact behavior, so `CircleCollider`/`RectangleCollider` are unaffected:

- `checkCollisions(entityPosition as BGE.Math.Vector) as roSprite[]` — the `SetMemberFlags`/`SetCollidableFlags`/`refreshColliderRegion`/`MoveTo`/`CheckMultipleCollisions` block currently inline in `Game.processEntityOnCollision`, moved onto `Collider` unchanged.
- `confirmCollision(myEntity as GameEntity, otherCollider as Collider, otherEntity as GameEntity) as boolean` — called once per broad-phase candidate, before `onCollision` fires. Base implementation returns `true` unconditionally (today's behavior: the broad-phase result *is* the final answer).

`Game.processEntityOnCollision` changes from calling `myCollider.compositorObject` directly to calling `myCollider.checkCollisions(entity.position)`, then gating each resolved candidate through `myCollider.confirmCollision(entity, otherCollider, otherEntity)` before invoking `entity.onCollision(...)`. This is a mechanical extraction of the existing method, not a rewrite of the per-frame collision pass.

### New collider types

`colliders/SphereCollider3d.bs`:
- Constructed via `radius` and a 3-component `offset` (reusing `Collider.offset`, which is already a full `BGE.Math.Vector`).
- Internally owns two `CircleCollider`s: one tracking the entity's `x,y` (XY plane), one tracking `y,z` (YZ plane). `setupCompositor()` is overridden to construct and set up both internal colliders (the YZ one gets a synthesized position `Vector(entityPosition.y, entityPosition.z)`, since `Collider.setupCompositor`/`adjustCompositorObject` only ever read `.x`/`.y` off whatever `Vector` they're given — no change needed there). `checkCollisions()` is overridden to drive both internal colliders' own `checkCollisions()` and intersect their candidate sets by `entityId` (a pair only survives broad-phase if it appears in *both* planes' results).
- `confirmCollision()` override: runs a true sphere-sphere distance check (see below) using the real 3D positions/radii of both entities, and returns `true` only on a genuine 3D overlap. This is what rejects the diagonal-near-miss false positive the spike found.

`colliders/BoxCollider3d.bs`:
- Constructed via `width`/`height`/`depth` and a 3-component `offset`.
- Internally owns two `RectangleCollider`s the same way (XY, YZ planes), with the same `setupCompositor()`/`checkCollisions()` override shape.
- **Worth noting: AABB-vs-AABB overlap decomposes exactly per axis.** The XY-plane rectangle check already tests X-overlap AND Y-overlap; the YZ-plane check tests Y-overlap AND Z-overlap (Y redundantly, harmlessly). Together they're exactly equivalent to true 3D AABB overlap — unlike spheres, there is no false-positive case for boxes, so `confirmCollision()` here doesn't need to *reject* anything. It still overrides the hook, but only to compute the penetration/normal result for physics response.

### Pure-function 3D resolvers

`colliders/Collision3d.bs`, alongside the existing `colliders/TileCollision.bs` (same structural pattern: pure functions, no `roCompositor`/engine coupling, explicit-precondition doc comments, called only after broad-phase overlap is already suspected):

```
function sphereOverlap(centerA as Vector, radiusA as float, centerB as Vector, radiusB as float) as Sphere3dCollisionResult
function aabbOverlap(minA as Vector, maxA as Vector, minB as Vector, maxB as Vector) as Box3dCollisionResult
```

Both return a small result value object — `{overlapping as boolean, normal as Vector, penetrationDepth as float}` — mirroring `TileCollisionResult`'s shape. `SphereCollider3d`/`BoxCollider3d` stash the last result (e.g. as a field) for the entity's `onCollision` handler to read when computing a bounce response.

### API surface (`GameEntity.bs`)

Follows the existing `addCircleCollider`/`addRectangleCollider` pattern exactly:

```
function addSphereCollider3d(colliderName as string, radius as float, offset_x = 0 as float, offset_y = 0 as float, offset_z = 0 as float, enabled = true as boolean) as SphereCollider3d
function addBoxCollider3d(colliderName as string, width as float, height as float, depth as float, offset_x = 0 as float, offset_y = 0 as float, offset_z = 0 as float, enabled = true as boolean) as BoxCollider3d
```

Both are stored in the same `entity.colliders` map and dispatch through the existing `onCollision(myCollider, otherCollider, otherEntity)` hook — no new hook name needed, since `Collider` stays the common base type regardless of `colliderType` (`"sphere3d"`/`"box3d"`).

### Example: `examples/collisions3d`

New example (not a room inside `examples/3d`, to avoid disturbing that example's existing per-demo-room structure): the 3D take on the Roku `ux components/control/Collisions` sample the issue asks for — `DrawableSphere` entities bouncing around in 3D space, using `addSphereCollider3d` and reflecting velocity off the confirmed collision's `normal`. Doubles as the on-device manual test bed for validating the whole approach, per this repo's rule that example runtime behavior needs on-device/rokubot verification, not just static analysis.

### Testing

Rooibos specs mirroring `CircleCollider.spec.bs`/`TileCollision.spec.bs`:
- Unit tests for the pure `Collision3d.bs` functions (`sphereOverlap`/`aabbOverlap`) covering overlap, no-overlap, and edge-touching cases.
- A spec proving the diagonal-near-miss case from the spike is now correctly rejected end-to-end through a real `SphereCollider3d` (the false positive the two-plane trick alone would produce).
- `checkCollisions`/`confirmCollision` extraction on `Collider` verified not to change `CircleCollider`/`RectangleCollider` behavior (existing specs should continue to pass unmodified).

## Out of scope

- Static/world-geometry 3D collision (this design covers entity-vs-entity dynamic collision only, matching `TileCollision.bs`'s own scoping note that it's a separate concern from `Collider`).
- Broad-phase spatial partitioning beyond what `roCompositor` already provides internally.
- A `Sphere3dCollider`-vs-`BoxCollider3d` cross-shape check (both new types support same-shape overlap only for the initial version; sphere-vs-box can be a follow-up if a concrete need arises).
