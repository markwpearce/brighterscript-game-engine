# Raycasting design

Issue: [#225](https://github.com/markwpearce/brighterscript-game-engine/issues/225)

## Goal

Add engine-level raycasting: cast a ray from an origin in a direction (with
an optional max distance) and determine whether/where it intersects any
collider — 2D (`CircleCollider`/`RectangleCollider`) and 3D
(`SphereCollider3d`/`BoxCollider3d`) alike. Motivating use cases: line-of-
sight checks, hitscan weapons, ground/wall detection, AI vision cones,
mouse/cursor picking.

## Non-goals

- Raycasting against static BSP drawable geometry (walls without a
  collider) — issue #225 asks for collider intersection specifically. A
  wall that should block a ray already needs a real collider for gameplay
  collision anyway (see `examples/collisions3d`'s walls, each a real
  `BoxCollider3d`). Ray-vs-static-drawable-geometry is a separate, larger
  concern (no collider tags an object as "solid," different geometry
  representation) and can be its own issue if a concrete need arises.
- Oriented/rotated rectangle or box colliders. Confirmed during design
  research: `RectangleCollider`/`BoxCollider3d` are always axis-aligned —
  entity `rotation` only affects drawable transforms, never collider
  geometry. Ray-vs-rectangle/box is therefore always a plain AABB slab
  test; introducing OBB support is out of scope here.
- Replacing or changing `CheckMultipleCollisions()`-based entity/entity
  collision. Raycasting is a new, separate query — it does not affect the
  per-frame collision pass in `Game.bs`.

## Existing stubs being replaced

`Game.bs` (~line 1709) currently has two empty placeholders:

```
function raycastVector(sourceX as float, sourceY as float, vectorX as float, vectorY as float) as object
  ' TODO Do Raycasts!
  return invalid
end function

function raycastAngle(sourceX as float, sourceY as float, angle as float) as object
  ' TODO Do Raycasts!
  return invalid
end function
```

Neither has any caller in the engine or examples. Both are removed and
replaced by `Game.raycast()`/`Game.raycastAll()` below (Vector-based
origin/direction, richer result, optional 3D support, optional filtering).

## Data model — `BGE.RaycastHit`

New file: `src/source/engine/colliders/RaycastResult.bs`.

```
class RaycastHit
  entity as object     ' as GameEntity
  collider as object   ' as Collider
  point as BGE.Math.Vector
  distance as float
  normal as BGE.Math.Vector
end class
```

This lives in its own file, separate from the free functions that
construct it, for the same reason `Sphere3dCollisionResult`/
`Box3dCollisionResult` live in `Collision3dResults.bs` rather than inside
`Collision3d.bs`: a namespace-level free function whose return type
self-references a class defined in the *same* file can corrupt bsc's
symbol resolution for unrelated code earlier in that file (documented in
CLAUDE.md, confirmed by bisection during the #107/#131 work). Keeping the
result class in its own file sidesteps this entirely.

## Pure intersection math — `colliders/Raycast.bs`

Mirrors `Collision3d.bs`'s existing style: free functions under the `BGE`
namespace, pure geometry math, no entity/game state. A ray's direction is
assumed pre-normalized by the caller (`Game.raycast`/`raycastAll` will
normalize defensively before calling into these, so callers passing an
un-normalized direction still get correct distances).

- `intersectRayCircle(origin, direction, maxDistance, center, radius) as BGE.RaycastHit`
  — classic ray-vs-circle quadratic: solve `|O + tD - C|² = r²` for the
  smallest non-negative `t` using `VectorOps.dotProduct`/`subtract`. If no
  real, non-negative root exists within `maxDistance`, return `invalid`.
  Normal = `normalize(hitPoint - center)`.
- `intersectRayAabb2d(origin, direction, maxDistance, min, max) as BGE.RaycastHit`
  — 2D slab method (test x-slab and y-slab intervals for `t`, intersect
  the two intervals). Normal = the axis of whichever slab produced
  `tEntry`, signed against the ray direction.
- `intersectRaySphere(origin, direction, maxDistance, center, radius) as BGE.RaycastHit`
  — same quadratic as the circle case, in 3D.
- `intersectRayAabb3d(origin, direction, maxDistance, min, max) as BGE.RaycastHit`
  — 3D slab method, same shape as the 2D case with a z-slab added.

Each function returns a fully-populated `BGE.RaycastHit` except `entity`/
`collider`, which are left `invalid` — `Collider.raycastCheck()` (below)
fills those in before handing the result back to `Game`.

Edge cases every function must handle (covered in the unit test plan
below): ray origin already inside the shape (returns a hit at `t=0`, not
`invalid`), ray parallel to a slab axis, ray pointing away from the shape,
and a hit exactly at `maxDistance` (inclusive) vs. just past it
(excluded).

## Collider hook

`Collider.raycastCheck(entityPosition, rayOrigin, rayDirection, maxDistance) as BGE.RaycastHit`
on the base class, default implementation returns `invalid`. This mirrors
the existing `confirmCollision()` extension point (`Collider` documents it
as overridable; `CircleCollider`/`RectangleCollider` don't need to
override it, `SphereCollider3d`/`BoxCollider3d` do).

- `CircleCollider.raycastCheck` computes `center = entityPosition + offset`
  and calls `intersectRayCircle(..., center, radius)`.
- `RectangleCollider.raycastCheck` computes `min`/`max` from
  `entityPosition + offset` and `width`/`height` (same corner convention
  `refreshColliderRegion()` already uses) and calls `intersectRayAabb2d`.
- `SphereCollider3d.raycastCheck` computes its true 3D center (already has
  this logic in `confirmCollision()`) and calls `intersectRaySphere`.
- `BoxCollider3d.raycastCheck` computes true min/max (already has this
  logic in `confirmCollision()`) and calls `intersectRayAabb3d`.

Each override sets `entity`/`collider` on the returned `BGE.RaycastHit`
before returning it (or leaves the result untouched when passing back
`invalid`). This keeps `Game.bs` free of any per-collider-type branching —
it only ever calls the polymorphic `raycastCheck()`.

`SphereCollider3d`/`BoxCollider3d` internally own two synthetic 2D
colliders (XY-plane + YZ-plane) for their compositor broad-phase — those
inner colliders are never registered in `entity.colliders` directly (only
the outer 3D collider is), so `Game.raycast`'s walk over
`entity.colliders` naturally never double-processes them.

## `Game` API

```
function raycast(origin as BGE.Math.Vector, direction as BGE.Math.Vector, maxDistance = 10000.0 as float, collidableFlags = &hFFFFFFFF as integer) as object ' as BGE.RaycastHit
function raycastAll(origin as BGE.Math.Vector, direction as BGE.Math.Vector, maxDistance = 10000.0 as float, collidableFlags = &hFFFFFFFF as integer) as object[] ' as BGE.RaycastHit[]
```

Both:
1. Normalize `direction` defensively (`VectorOps.normalize`), so a caller
   passing a non-unit vector still gets correct `distance`/`point` values.
2. Walk `sortedEntities` → each entity's `colliders` map.
3. Skip a collider if `not collider.enabled`, or if
   `(collider.memberFlags and collidableFlags) = 0` — the same bitmask
   convention colliders already use for broad-phase collision filtering
   (`memberFlags`/`collidableFlags`), so excluding e.g. the ray-caster's
   own colliders is just choosing distinct flag bits, not a new concept.
4. Call `collider.raycastCheck(entity.position, origin, direction, maxDistance)`;
   collect non-`invalid` results.
5. `raycast()` returns the single closest result (`invalid` if none);
   `raycastAll()` returns every result sorted by ascending `distance`
   (empty array if none).

`collidableFlags` defaults to matching every collider (`&hFFFFFFFF`), so a
simple `game.raycast(origin, direction)` call with no filtering "just
works" for the common case.

## Testing

- `src/source/engine/colliders/Raycast.spec.bs` (one `@suite` class, per
  the Rooibos one-suite-per-file rule) — pure math tests per shape:
  direct hit, miss, ray origin inside the shape, ray pointing away,
  tangent/grazing hit, and `maxDistance` clipping (hit just inside vs.
  just outside the limit). No `Game` needed — these are pure functions.
- A `Game`-level spec (new file, e.g.
  `src/source/engine/GameRaycast.spec.bs`) constructing a real `Game` with
  a few entities/colliders (matching the existing convention that a real
  `Game` is needed to exercise collider behavior — see `GameEntity.spec.bs`).
  Covers: `raycast()` returns the nearest of several overlapping
  colliders; `raycastAll()` returns all of them sorted by distance;
  `collidableFlags` correctly excludes a flagged-out collider; a disabled
  collider is skipped; no hit returns `invalid`/`[]`.

## Docs

- CLAUDE.md's Collision architecture section gets a new bullet describing
  `Game.raycast()`/`raycastAll()`, the `Collider.raycastCheck()` extension
  point, and the axis-aligned-only limitation — following the existing
  pattern for how `SphereCollider3d`/`BoxCollider3d` are documented there.
- `Game.raycast()`/`raycastAll()` get consumer-facing JSDoc-style doc
  comments (`@param`/`@return`), per this codebase's convention for public
  API methods.
