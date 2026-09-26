# Raycasting Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `Game.raycast()`/`Game.raycastAll()` so a caller can cast a ray from a point and get back the collider(s) it hits (entity, collider, hit point, distance, normal) — 2D (`CircleCollider`/`RectangleCollider`) and 3D (`SphereCollider3d`/`BoxCollider3d`) alike.

**Architecture:** Pure ray-vs-shape intersection math lives in new free functions (`colliders/Raycast.bs`), mirroring the existing `Collision3d.bs` narrow-phase style. Each collider type gets a `raycastCheck()` override (mirroring the existing `confirmCollision()` extension point on `Collider`) that computes its own world-space geometry and delegates to the matching intersection function. `Game.raycast()`/`raycastAll()` walk `sortedEntities` → `entity.colliders` calling the polymorphic `raycastCheck()`, with no per-type branching in `Game.bs`.

**Tech Stack:** BrighterScript (`bsc`), Rooibos v6 unit tests run headlessly via `brs-cli` (`npm run test:ci`).

**Spec:** `specs/2026-09-21-raycasting-design.md`

## Global Constraints

- One `@suite` class per `*.spec.bs` file (Rooibos v6 corrupts test metadata otherwise — see CLAUDE.md's Unit Tests section). Never add a second `@suite` to an existing spec file; append `@describe`/`@it` blocks to the existing suite class instead, or create a new file.
- A file that references another file's class/namespace/function must `import` it explicitly, even inside `source` scope where ambient visibility would let it compile anyway (see CLAUDE.md's "Conventions" section) — SceneGraph component scopes aren't ambient and a missing import is invisible until then.
- Never give a namespace-level free function a return type, or an instance method a parameter type, that self-references a class defined in the *same* file — confirmed to corrupt bsc's symbol resolution for unrelated code earlier in that file (CLAUDE.md). `BGE.RaycastHit` therefore lives in its own file (`RaycastResult.bs`), separate from the functions in `Raycast.bs` that return it.
- Colliders are always axis-aligned (no rotation) — ray-vs-rectangle/box is a plain AABB slab test, never OBB.
- Run `npm run validate` after touching engine code (per CLAUDE.md).
- Float assertions in this test suite must use tolerance comparisons (`Abs(actual - expected) < 0.0001`), not `assertEqual`, whenever a value comes from `Sqr`/division rather than a literal — `assertEqual` is type/value-strict and this codebase's convention (see `SphereBoxOverlap.spec.bs`, `SphereCollider3d.spec.bs`) is to use `Abs(...) < 0.0001` for any computed float.

---

## Task 1: `BGE.RaycastHit` result type + ray-vs-sphere/circle math

**Files:**
- Create: `src/source/engine/colliders/RaycastResult.bs`
- Create: `src/source/engine/colliders/Raycast.bs`
- Test: `src/source/engine/colliders/RaySphereIntersection.spec.bs`
- Test: `src/source/engine/colliders/RayCircleIntersection.spec.bs`

**Interfaces:**
- Produces: `BGE.RaycastHit` interface (`entity as GameEntity`, `collider as Collider`, `point as BGE.Math.Vector`, `distance as float`, `normal as BGE.Math.Vector`) — pure data, so an `interface` rather than a `class` (no instantiation cost). `entity`/`collider` are typed as their real classes, not `as object`: BrighterScript's documented same-file self-reference bsc bug (see Global Constraints) does not apply to a plain cross-file import cycle — confirmed empirically (`npm run validate`/`test:ci` both clean with `RaycastResult.bs` ↔ `Collider.bs` ↔ `GameEntity.bs` importing each other). Since it's an interface, a caller builds one as an AA literal (`{entity: invalid, collider: invalid, point: point, distance: t, normal: normal}`) rather than `new BGE.RaycastHit(...)`; a later caller (`Game.raycastAll()`, Task 5) fills `entity`/`collider` in via plain field assignment (`hit.entity = entity`).
- Produces: `BGE.intersectRaySphere(origin as BGE.Math.Vector, direction as BGE.Math.Vector, maxDistance as float, center as BGE.Math.Vector, radius as float) as BGE.RaycastHit` — direction must already be a unit vector (callers normalize before calling in).
- Produces: `BGE.intersectRayCircle(origin as BGE.Math.Vector, direction as BGE.Math.Vector, maxDistance as float, center as BGE.Math.Vector, radius as float) as BGE.RaycastHit` — 2D case, delegates to `intersectRaySphere` with z flattened to 0.

- [ ] **Step 1: Write the failing tests**

Create `src/source/engine/colliders/RaySphereIntersection.spec.bs`:

```brightscript
namespace tests

  @suite("BGE.intersectRaySphere")
  class RaySphereIntersectionTests extends rooibos.BaseTestSuite

    @describe("intersectRaySphere")

    @it("hits a sphere dead ahead and reports the near intersection point/distance/normal")
    function _()
      origin = BGE.Math.VectorOps.create(0, 0, -20)
      direction = BGE.Math.VectorOps.create(0, 0, 1)
      center = BGE.Math.VectorOps.create(0, 0, 0)
      hit = BGE.intersectRaySphere(origin, direction, 1000.0, center, 5.0)
      m.assertNotInvalid(hit)
      m.assertTrue(Abs(hit.distance - 15.0) < 0.0001)
      m.assertTrue(Abs(hit.point.z - (-5.0)) < 0.0001)
      m.assertTrue(Abs(hit.normal.z - (-1.0)) < 0.0001)
    end function

    @it("returns invalid when the ray passes outside the sphere's radius")
    function _()
      origin = BGE.Math.VectorOps.create(0, 100, -20)
      direction = BGE.Math.VectorOps.create(0, 0, 1)
      center = BGE.Math.VectorOps.create(0, 0, 0)
      hit = BGE.intersectRaySphere(origin, direction, 1000.0, center, 5.0)
      m.assertInvalid(hit)
    end function

    @it("returns invalid when the sphere is behind the ray origin")
    function _()
      origin = BGE.Math.VectorOps.create(0, 0, 20)
      direction = BGE.Math.VectorOps.create(0, 0, 1)
      center = BGE.Math.VectorOps.create(0, 0, 0)
      hit = BGE.intersectRaySphere(origin, direction, 1000.0, center, 5.0)
      m.assertInvalid(hit)
    end function

    @it("reports the exit point (positive t) when the ray origin starts inside the sphere")
    function _()
      origin = BGE.Math.VectorOps.create(0, 0, 0)
      direction = BGE.Math.VectorOps.create(0, 0, 1)
      center = BGE.Math.VectorOps.create(0, 0, 0)
      hit = BGE.intersectRaySphere(origin, direction, 1000.0, center, 5.0)
      m.assertNotInvalid(hit)
      m.assertTrue(Abs(hit.distance - 5.0) < 0.0001)
    end function

    @it("clips a hit exactly at maxDistance as a valid hit")
    function _()
      origin = BGE.Math.VectorOps.create(0, 0, -20)
      direction = BGE.Math.VectorOps.create(0, 0, 1)
      center = BGE.Math.VectorOps.create(0, 0, 0)
      hit = BGE.intersectRaySphere(origin, direction, 15.0, center, 5.0)
      m.assertNotInvalid(hit)
    end function

    @it("rejects a hit just past maxDistance")
    function _()
      origin = BGE.Math.VectorOps.create(0, 0, -20)
      direction = BGE.Math.VectorOps.create(0, 0, 1)
      center = BGE.Math.VectorOps.create(0, 0, 0)
      hit = BGE.intersectRaySphere(origin, direction, 14.9, center, 5.0)
      m.assertInvalid(hit)
    end function

  end class

end namespace
```

Create `src/source/engine/colliders/RayCircleIntersection.spec.bs`:

```brightscript
namespace tests

  @suite("BGE.intersectRayCircle")
  class RayCircleIntersectionTests extends rooibos.BaseTestSuite

    @describe("intersectRayCircle")

    @it("hits a circle dead ahead in the XY plane")
    function _()
      origin = BGE.Math.VectorOps.create(-20, 0)
      direction = BGE.Math.VectorOps.create(1, 0)
      center = BGE.Math.VectorOps.create(0, 0)
      hit = BGE.intersectRayCircle(origin, direction, 1000.0, center, 5.0)
      m.assertNotInvalid(hit)
      m.assertTrue(Abs(hit.distance - 15.0) < 0.0001)
      m.assertTrue(Abs(hit.point.x - (-5.0)) < 0.0001)
    end function

    @it("returns invalid when the ray passes outside the circle's radius")
    function _()
      origin = BGE.Math.VectorOps.create(-20, 100)
      direction = BGE.Math.VectorOps.create(1, 0)
      center = BGE.Math.VectorOps.create(0, 0)
      hit = BGE.intersectRayCircle(origin, direction, 1000.0, center, 5.0)
      m.assertInvalid(hit)
    end function

    @it("ignores z entirely - a ray offset only in z still misses a circle at z=0")
    function _()
      origin = BGE.Math.VectorOps.create(-20, 0, 100)
      direction = BGE.Math.VectorOps.create(1, 0, 0)
      center = BGE.Math.VectorOps.create(0, 0, 0)
      hit = BGE.intersectRayCircle(origin, direction, 1000.0, center, 5.0)
      m.assertNotInvalid(hit)
    end function

  end class

end namespace
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `npm run test:ci`
Expected: build/compile failure — `BGE.intersectRaySphere`/`BGE.intersectRayCircle` don't exist yet.

- [ ] **Step 3: Implement `RaycastResult.bs` and the sphere/circle math in `Raycast.bs`**

Create `src/source/engine/colliders/RaycastResult.bs`:

```brightscript
import "../../math/vector.bs"
import "../GameEntity.bs"
import "Collider.bs"

namespace BGE

  ' The result of a raycast hitting a collider - see Game.raycast()/raycastAll(). Pure data,
  ' so it's an interface rather than a class (no instantiation cost).
  interface RaycastHit
    entity as GameEntity
    collider as Collider
    point as BGE.Math.Vector
    distance as float
    normal as BGE.Math.Vector
  end interface

end namespace
```

Create `src/source/engine/colliders/Raycast.bs`:

```brightscript
import "../../math/vector.bs"
import "RaycastResult.bs"

namespace BGE

  ' Below this magnitude, a ray's direction component along an axis is treated as exactly
  ' zero (parallel to that axis' slab) rather than risking a division by a near-zero value
  ' in intersectRayAabb3d()'s slab test.
  const RAY_EPSILON = 0.000001

  ' Ray-vs-sphere intersection (the true 3D case; intersectRayCircle() is the 2D
  ' specialization below). Returns the nearest intersection point along the ray within
  ' [0, maxDistance], or `invalid` if the ray misses, points away from the sphere, or the
  ' sphere is entirely beyond maxDistance. `direction` must already be a unit vector - the
  ' returned `distance` is only meaningful in the same units as `direction`'s magnitude.
  '
  ' @param {BGE.Math.Vector} origin
  ' @param {BGE.Math.Vector} direction - must be a unit vector
  ' @param {float} maxDistance
  ' @param {BGE.Math.Vector} center
  ' @param {float} radius
  ' @return {BGE.RaycastHit}
  function intersectRaySphere(origin as BGE.Math.Vector, direction as BGE.Math.Vector, maxDistance as float, center as BGE.Math.Vector, radius as float) as BGE.RaycastHit
    oc = BGE.Math.VectorOps.subtract(origin, center)
    b = BGE.Math.VectorOps.dotProduct(oc, direction)
    c = BGE.Math.VectorOps.dotProduct(oc, oc) - radius * radius
    discriminant = b * b - c
    if discriminant < 0.0
      return invalid
    end if

    sqrtDiscriminant = Sqr(discriminant)
    t = -b - sqrtDiscriminant
    if t < 0.0
      ' Origin is inside the sphere (or the near root is behind the ray) - the far root is
      ' the only forward-facing intersection.
      t = -b + sqrtDiscriminant
    end if
    if t < 0.0 or t > maxDistance
      return invalid
    end if

    point = BGE.Math.VectorOps.add(origin, BGE.Math.VectorOps.scale(direction, t))
    normal = BGE.Math.VectorOps.getNormalizedCopy(BGE.Math.VectorOps.subtract(point, center))
    return {entity: invalid, collider: invalid, point: point, distance: t, normal: normal}
  end function


  ' Ray-vs-circle intersection in the XY plane - z is ignored entirely on both the ray and
  ' the circle, by flattening both to z=0 and delegating to intersectRaySphere().
  '
  ' @param {BGE.Math.Vector} origin
  ' @param {BGE.Math.Vector} direction - must be a unit vector
  ' @param {float} maxDistance
  ' @param {BGE.Math.Vector} center
  ' @param {float} radius
  ' @return {BGE.RaycastHit}
  function intersectRayCircle(origin as BGE.Math.Vector, direction as BGE.Math.Vector, maxDistance as float, center as BGE.Math.Vector, radius as float) as BGE.RaycastHit
    flatOrigin = BGE.Math.VectorOps.create(origin.x, origin.y, 0.0)
    flatDirection = BGE.Math.VectorOps.create(direction.x, direction.y, 0.0)
    flatCenter = BGE.Math.VectorOps.create(center.x, center.y, 0.0)
    return intersectRaySphere(flatOrigin, flatDirection, maxDistance, flatCenter, radius)
  end function

end namespace
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `npm run test:ci`
Expected: `[Rooibos Result]: PASS` including `BGE.intersectRaySphere` and `BGE.intersectRayCircle` suites, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add src/source/engine/colliders/RaycastResult.bs src/source/engine/colliders/Raycast.bs src/source/engine/colliders/RaySphereIntersection.spec.bs src/source/engine/colliders/RayCircleIntersection.spec.bs
git commit -m "Add BGE.RaycastHit and ray-vs-sphere/circle intersection math (#225)"
```

---

## Task 2: Ray-vs-AABB (3D/2D) math

**Files:**
- Modify: `src/source/engine/colliders/Raycast.bs`
- Test: `src/source/engine/colliders/RayAabb3dIntersection.spec.bs`
- Test: `src/source/engine/colliders/RayAabb2dIntersection.spec.bs`

**Interfaces:**
- Consumes: `BGE.RaycastHit` (Task 1).
- Produces: `BGE.intersectRayAabb3d(origin as BGE.Math.Vector, direction as BGE.Math.Vector, maxDistance as float, minPoint as BGE.Math.Vector, maxPoint as BGE.Math.Vector) as BGE.RaycastHit`.
- Produces: `BGE.intersectRayAabb2d(origin as BGE.Math.Vector, direction as BGE.Math.Vector, maxDistance as float, minPoint as BGE.Math.Vector, maxPoint as BGE.Math.Vector) as BGE.RaycastHit` — 2D case, delegates to `intersectRayAabb3d` with z widened to never constrain.

- [ ] **Step 1: Write the failing tests**

Create `src/source/engine/colliders/RayAabb3dIntersection.spec.bs`:

```brightscript
namespace tests

  @suite("BGE.intersectRayAabb3d")
  class RayAabb3dIntersectionTests extends rooibos.BaseTestSuite

    @describe("intersectRayAabb3d")

    @it("hits a box dead ahead and reports the near face's point/distance/normal")
    function _()
      origin = BGE.Math.VectorOps.create(0, 0, -20)
      direction = BGE.Math.VectorOps.create(0, 0, 1)
      minPoint = BGE.Math.VectorOps.create(-5, -5, -5)
      maxPoint = BGE.Math.VectorOps.create(5, 5, 5)
      hit = BGE.intersectRayAabb3d(origin, direction, 1000.0, minPoint, maxPoint)
      m.assertNotInvalid(hit)
      m.assertTrue(Abs(hit.distance - 15.0) < 0.0001)
      m.assertTrue(Abs(hit.point.z - (-5.0)) < 0.0001)
      m.assertTrue(Abs(hit.normal.z - (-1.0)) < 0.0001)
      m.assertTrue(Abs(hit.normal.x) < 0.0001)
      m.assertTrue(Abs(hit.normal.y) < 0.0001)
    end function

    @it("returns invalid when the ray passes beside the box on one axis")
    function _()
      origin = BGE.Math.VectorOps.create(0, 100, -20)
      direction = BGE.Math.VectorOps.create(0, 0, 1)
      minPoint = BGE.Math.VectorOps.create(-5, -5, -5)
      maxPoint = BGE.Math.VectorOps.create(5, 5, 5)
      hit = BGE.intersectRayAabb3d(origin, direction, 1000.0, minPoint, maxPoint)
      m.assertInvalid(hit)
    end function

    @it("returns invalid when the box is behind the ray origin")
    function _()
      origin = BGE.Math.VectorOps.create(0, 0, 20)
      direction = BGE.Math.VectorOps.create(0, 0, 1)
      minPoint = BGE.Math.VectorOps.create(-5, -5, -5)
      maxPoint = BGE.Math.VectorOps.create(5, 5, 5)
      hit = BGE.intersectRayAabb3d(origin, direction, 1000.0, minPoint, maxPoint)
      m.assertInvalid(hit)
    end function

    @it("reports distance 0 and a hit when the ray origin starts inside the box")
    function _()
      origin = BGE.Math.VectorOps.create(0, 0, 0)
      direction = BGE.Math.VectorOps.create(0, 0, 1)
      minPoint = BGE.Math.VectorOps.create(-5, -5, -5)
      maxPoint = BGE.Math.VectorOps.create(5, 5, 5)
      hit = BGE.intersectRayAabb3d(origin, direction, 1000.0, minPoint, maxPoint)
      m.assertNotInvalid(hit)
      m.assertTrue(Abs(hit.distance) < 0.0001)
    end function

    @it("picks the entry face normal correctly when approaching from the negative axis direction")
    function _()
      origin = BGE.Math.VectorOps.create(0, 0, 20)
      direction = BGE.Math.VectorOps.create(0, 0, -1)
      minPoint = BGE.Math.VectorOps.create(-5, -5, -5)
      maxPoint = BGE.Math.VectorOps.create(5, 5, 5)
      hit = BGE.intersectRayAabb3d(origin, direction, 1000.0, minPoint, maxPoint)
      m.assertNotInvalid(hit)
      m.assertTrue(Abs(hit.distance - 15.0) < 0.0001)
      m.assertTrue(Abs(hit.normal.z - 1.0) < 0.0001)
    end function

    @it("rejects a hit just past maxDistance")
    function _()
      origin = BGE.Math.VectorOps.create(0, 0, -20)
      direction = BGE.Math.VectorOps.create(0, 0, 1)
      minPoint = BGE.Math.VectorOps.create(-5, -5, -5)
      maxPoint = BGE.Math.VectorOps.create(5, 5, 5)
      hit = BGE.intersectRayAabb3d(origin, direction, 14.9, minPoint, maxPoint)
      m.assertInvalid(hit)
    end function

  end class

end namespace
```

Create `src/source/engine/colliders/RayAabb2dIntersection.spec.bs`:

```brightscript
namespace tests

  @suite("BGE.intersectRayAabb2d")
  class RayAabb2dIntersectionTests extends rooibos.BaseTestSuite

    @describe("intersectRayAabb2d")

    @it("hits a rectangle dead ahead in the XY plane")
    function _()
      origin = BGE.Math.VectorOps.create(-20, 0)
      direction = BGE.Math.VectorOps.create(1, 0)
      minPoint = BGE.Math.VectorOps.create(-5, -5)
      maxPoint = BGE.Math.VectorOps.create(5, 5)
      hit = BGE.intersectRayAabb2d(origin, direction, 1000.0, minPoint, maxPoint)
      m.assertNotInvalid(hit)
      m.assertTrue(Abs(hit.distance - 15.0) < 0.0001)
      m.assertTrue(Abs(hit.point.x - (-5.0)) < 0.0001)
    end function

    @it("returns invalid when the ray passes beside the rectangle")
    function _()
      origin = BGE.Math.VectorOps.create(-20, 100)
      direction = BGE.Math.VectorOps.create(1, 0)
      minPoint = BGE.Math.VectorOps.create(-5, -5)
      maxPoint = BGE.Math.VectorOps.create(5, 5)
      hit = BGE.intersectRayAabb2d(origin, direction, 1000.0, minPoint, maxPoint)
      m.assertInvalid(hit)
    end function

    @it("ignores z entirely - a ray offset only in z still hits a rectangle at z=0")
    function _()
      origin = BGE.Math.VectorOps.create(-20, 0, 100)
      direction = BGE.Math.VectorOps.create(1, 0, 0)
      minPoint = BGE.Math.VectorOps.create(-5, -5)
      maxPoint = BGE.Math.VectorOps.create(5, 5)
      hit = BGE.intersectRayAabb2d(origin, direction, 1000.0, minPoint, maxPoint)
      m.assertNotInvalid(hit)
    end function

  end class

end namespace
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `npm run test:ci`
Expected: build/compile failure — `BGE.intersectRayAabb3d`/`BGE.intersectRayAabb2d` don't exist yet.

- [ ] **Step 3: Implement the AABB math**

Append to `src/source/engine/colliders/Raycast.bs`, inside the `namespace BGE` block (before `end namespace`):

```brightscript

  ' Ray-vs-axis-aligned-box intersection via the classic slab method (Kay/Kajiya): each axis
  ' narrows [tMin, tMax] to the interval where the ray is within that axis' [lo, hi] slab;
  ' if the interval ever becomes empty, the ray misses. The entry face's outward normal is
  ' tracked as whichever axis last raised tMin.
  '
  ' @param {BGE.Math.Vector} origin
  ' @param {BGE.Math.Vector} direction - must be a unit vector
  ' @param {float} maxDistance
  ' @param {BGE.Math.Vector} minPoint
  ' @param {BGE.Math.Vector} maxPoint
  ' @return {BGE.RaycastHit}
  function intersectRayAabb3d(origin as BGE.Math.Vector, direction as BGE.Math.Vector, maxDistance as float, minPoint as BGE.Math.Vector, maxPoint as BGE.Math.Vector) as BGE.RaycastHit
    tMin = 0.0
    tMax = maxDistance
    normal = BGE.Math.VectorOps.create(0, 0, 0)

    axisOrigins = [origin.x, origin.y, origin.z ?? 0.0]
    axisDirections = [direction.x, direction.y, direction.z ?? 0.0]
    axisMins = [minPoint.x, minPoint.y, minPoint.z ?? 0.0]
    axisMaxes = [maxPoint.x, maxPoint.y, maxPoint.z ?? 0.0]
    axisNormals = [
      BGE.Math.VectorOps.create(1, 0, 0),
      BGE.Math.VectorOps.create(0, 1, 0),
      BGE.Math.VectorOps.create(0, 0, 1)
    ]

    for axisIndex = 0 to 2
      axisOrigin = axisOrigins[axisIndex]
      axisDirection = axisDirections[axisIndex]
      lo = axisMins[axisIndex]
      hi = axisMaxes[axisIndex]

      if Abs(axisDirection) < RAY_EPSILON
        if axisOrigin < lo or axisOrigin > hi
          return invalid
        end if
      else
        invDirection = 1.0 / axisDirection
        t1 = (lo - axisOrigin) * invDirection
        t2 = (hi - axisOrigin) * invDirection
        entryNormal = BGE.Math.VectorOps.scale(axisNormals[axisIndex], -1.0)
        if t1 > t2
          swapT = t1
          t1 = t2
          t2 = swapT
          entryNormal = axisNormals[axisIndex]
        end if
        if t1 > tMin
          tMin = t1
          normal = entryNormal
        end if
        if t2 < tMax
          tMax = t2
        end if
        if tMin > tMax
          return invalid
        end if
      end if
    end for

    if BGE.Math.VectorOps.isZero(normal)
      ' Ray origin started inside the box - no entry face was actually crossed.
      normal = BGE.Math.VectorOps.create(0, 1, 0)
    end if

    point = BGE.Math.VectorOps.add(origin, BGE.Math.VectorOps.scale(direction, tMin))
    return {entity: invalid, collider: invalid, point: point, distance: tMin, normal: normal}
  end function


  ' Ray-vs-axis-aligned-rectangle intersection in the XY plane - z is ignored entirely, by
  ' flattening the ray to z=0 and widening the box's z-range so the z-axis slab test in
  ' intersectRayAabb3d() never constrains the result.
  '
  ' @param {BGE.Math.Vector} origin
  ' @param {BGE.Math.Vector} direction - must be a unit vector
  ' @param {float} maxDistance
  ' @param {BGE.Math.Vector} minPoint
  ' @param {BGE.Math.Vector} maxPoint
  ' @return {BGE.RaycastHit}
  function intersectRayAabb2d(origin as BGE.Math.Vector, direction as BGE.Math.Vector, maxDistance as float, minPoint as BGE.Math.Vector, maxPoint as BGE.Math.Vector) as BGE.RaycastHit
    flatOrigin = BGE.Math.VectorOps.create(origin.x, origin.y, 0.0)
    flatDirection = BGE.Math.VectorOps.create(direction.x, direction.y, 0.0)
    widenedMin = BGE.Math.VectorOps.create(minPoint.x, minPoint.y, -999999999.0)
    widenedMax = BGE.Math.VectorOps.create(maxPoint.x, maxPoint.y, 999999999.0)
    return intersectRayAabb3d(flatOrigin, flatDirection, maxDistance, widenedMin, widenedMax)
  end function
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `npm run test:ci`
Expected: `[Rooibos Result]: PASS` including `BGE.intersectRayAabb3d` and `BGE.intersectRayAabb2d` suites, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add src/source/engine/colliders/Raycast.bs src/source/engine/colliders/RayAabb3dIntersection.spec.bs src/source/engine/colliders/RayAabb2dIntersection.spec.bs
git commit -m "Add ray-vs-AABB intersection math (#225)"
```

---

## Task 3: `Collider.raycastCheck()` hook + 2D collider overrides

**Files:**
- Modify: `src/source/engine/colliders/Collider.bs`
- Modify: `src/source/engine/colliders/CircleCollider.bs`
- Modify: `src/source/engine/colliders/RectangleCollider.bs`
- Modify (append tests): `src/source/engine/colliders/CircleCollider.spec.bs`
- Modify (append tests): `src/source/engine/colliders/RectangleCollider.spec.bs`

**Interfaces:**
- Consumes: `BGE.RaycastHit`, `BGE.intersectRayCircle`, `BGE.intersectRayAabb2d` (Tasks 1-2).
- Produces: `Collider.raycastCheck(entityPosition as BGE.Math.Vector, rayOrigin as BGE.Math.Vector, rayDirection as BGE.Math.Vector, maxDistance as float) as BGE.RaycastHit` — base returns `invalid`, overridden by every concrete collider. `entity`/`collider` are left `invalid` on the returned hit; the caller (`Game.raycastAll()`, Task 5) fills them in.

- [ ] **Step 1: Write the failing tests**

Add to `src/source/engine/colliders/CircleCollider.spec.bs`, before the final `end class` (after the existing `@describe("refreshColliderRegion / debugDraw")` block):

```brightscript
    @describe("raycastCheck")

    @it("reports a hit, with entity/collider left invalid, for a ray that crosses the circle")
    function _()
      m.entity.position = BGE.Math.VectorOps.create(0, 0)
      collider = m.entity.addCircleCollider("body", 5)
      hit = collider.raycastCheck(m.entity.position, BGE.Math.VectorOps.create(-20, 0), BGE.Math.VectorOps.create(1, 0), 1000.0)
      m.assertNotInvalid(hit)
      m.assertInvalid(hit.entity)
      m.assertInvalid(hit.collider)
      m.assertTrue(Abs(hit.distance - 15.0) < 0.0001)
    end function

    @it("accounts for the entity's position and the collider's own offset")
    function _()
      m.entity.position = BGE.Math.VectorOps.create(100, 0)
      collider = m.entity.addCircleCollider("body", 5, 10, 0)
      hit = collider.raycastCheck(m.entity.position, BGE.Math.VectorOps.create(0, 0), BGE.Math.VectorOps.create(1, 0), 1000.0)
      m.assertNotInvalid(hit)
      m.assertTrue(Abs(hit.distance - 105.0) < 0.0001)
    end function

    @it("returns invalid for a ray that misses the circle")
    function _()
      m.entity.position = BGE.Math.VectorOps.create(0, 100)
      collider = m.entity.addCircleCollider("body", 5)
      hit = collider.raycastCheck(m.entity.position, BGE.Math.VectorOps.create(-20, 0), BGE.Math.VectorOps.create(1, 0), 1000.0)
      m.assertInvalid(hit)
    end function
```

Add to `src/source/engine/colliders/RectangleCollider.spec.bs`, before the final `end class`:

```brightscript
    @describe("raycastCheck")

    @it("reports a hit, with entity/collider left invalid, for a ray that crosses the rectangle")
    function _()
      m.entity.position = BGE.Math.VectorOps.create(0, 0)
      collider = m.entity.addRectangleCollider("body", 10, 10, -5, 5)
      hit = collider.raycastCheck(m.entity.position, BGE.Math.VectorOps.create(-20, 0), BGE.Math.VectorOps.create(1, 0), 1000.0)
      m.assertNotInvalid(hit)
      m.assertInvalid(hit.entity)
      m.assertInvalid(hit.collider)
      m.assertTrue(Abs(hit.distance - 15.0) < 0.0001)
    end function

    @it("returns invalid for a ray that misses the rectangle")
    function _()
      m.entity.position = BGE.Math.VectorOps.create(0, 100)
      collider = m.entity.addRectangleCollider("body", 10, 10, -5, 5)
      hit = collider.raycastCheck(m.entity.position, BGE.Math.VectorOps.create(-20, 0), BGE.Math.VectorOps.create(1, 0), 1000.0)
      m.assertInvalid(hit)
    end function
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `npm run test:ci`
Expected: build/compile failure — `Collider`/`CircleCollider`/`RectangleCollider` don't have a `raycastCheck` method yet.

- [ ] **Step 3: Implement the hook and overrides**

In `src/source/engine/colliders/Collider.bs`, add the import at the top (alphabetical, matching existing import ordering):

```brightscript
import "../../math/vector.bs"
import "../../utils/TagList.bs"
import "../Game.bs"
import "../renderer/Renderer.bs"
import "RaycastResult.bs"
```

Then add this method to the `Collider` class, after `confirmCollision()` and before `disableCollisionChecking()`:

```brightscript
    ' Tests this collider's shape against a ray. The base implementation always misses -
    ' overridden by CircleCollider/RectangleCollider/SphereCollider3d/BoxCollider3d, each
    ' computing its own world-space geometry from entityPosition + m.offset and delegating
    ' to the matching BGE.intersectRay*() function (see colliders/Raycast.bs). Called by
    ' Game.raycast()/Game.raycastAll() - the returned hit's entity/collider fields are left
    ' `invalid` here and filled in by the caller, which is the only place that has both the
    ' owning GameEntity and this Collider in hand at once.
    '
    ' @param {BGE.Math.Vector} entityPosition - the owning entity's current position
    ' @param {BGE.Math.Vector} rayOrigin
    ' @param {BGE.Math.Vector} rayDirection - must be a unit vector
    ' @param {float} maxDistance
    ' @return {BGE.RaycastHit} the intersection, or `invalid` if the ray misses
    function raycastCheck(entityPosition as BGE.Math.Vector, rayOrigin as BGE.Math.Vector, rayDirection as BGE.Math.Vector, maxDistance as float) as BGE.RaycastHit
      return invalid
    end function
```

In `src/source/engine/colliders/CircleCollider.bs`, add the import:

```brightscript
import "../../math/vector.bs"
import "../renderer/Renderer.bs"
import "Collider.bs"
import "Raycast.bs"
import "RaycastResult.bs"
```

Then add this method, after `refreshColliderRegion()` and before `debugDraw()`:

```brightscript
    ' See Collider.raycastCheck()'s doc comment.
    override function raycastCheck(entityPosition as BGE.Math.Vector, rayOrigin as BGE.Math.Vector, rayDirection as BGE.Math.Vector, maxDistance as float) as BGE.RaycastHit
      center = BGE.Math.VectorOps.add(entityPosition, m.offset)
      return intersectRayCircle(rayOrigin, rayDirection, maxDistance, center, m.radius)
    end function
```

In `src/source/engine/colliders/RectangleCollider.bs`, add the import:

```brightscript
import "../../math/vector.bs"
import "../renderer/Renderer.bs"
import "Collider.bs"
import "Raycast.bs"
import "RaycastResult.bs"
```

Then add this method, after `refreshColliderRegion()` and before `debugDraw()`:

```brightscript
    ' See Collider.raycastCheck()'s doc comment. offset.x/offset.y is this rectangle's
    ' bottom-left corner (see the class doc comment above) - top-left is at
    ' (offset.x, offset.y - height), matching refreshColliderRegion()'s own SetCollisionRectangle() call.
    override function raycastCheck(entityPosition as BGE.Math.Vector, rayOrigin as BGE.Math.Vector, rayDirection as BGE.Math.Vector, maxDistance as float) as BGE.RaycastHit
      corner = BGE.Math.VectorOps.add(entityPosition, m.offset)
      minPoint = BGE.Math.VectorOps.create(corner.x, corner.y - m.height)
      maxPoint = BGE.Math.VectorOps.create(corner.x + m.width, corner.y)
      return intersectRayAabb2d(rayOrigin, rayDirection, maxDistance, minPoint, maxPoint)
    end function
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `npm run test:ci`
Expected: `[Rooibos Result]: PASS`, including the new `raycastCheck` tests in `BGE.CircleCollider` and `BGE.RectangleCollider`, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add src/source/engine/colliders/Collider.bs src/source/engine/colliders/CircleCollider.bs src/source/engine/colliders/RectangleCollider.bs src/source/engine/colliders/CircleCollider.spec.bs src/source/engine/colliders/RectangleCollider.spec.bs
git commit -m "Add Collider.raycastCheck() hook and 2D collider overrides (#225)"
```

---

## Task 4: 3D collider overrides

**Files:**
- Modify: `src/source/engine/colliders/SphereCollider3d.bs`
- Modify: `src/source/engine/colliders/BoxCollider3d.bs`
- Modify (append tests): `src/source/engine/colliders/SphereCollider3d.spec.bs`
- Modify (append tests): `src/source/engine/colliders/BoxCollider3d.spec.bs`

**Interfaces:**
- Consumes: `BGE.RaycastHit`, `BGE.intersectRaySphere`, `BGE.intersectRayAabb3d` (Tasks 1-2), `Collider.raycastCheck()` (Task 3).
- Produces: `SphereCollider3d.raycastCheck(...)`/`BoxCollider3d.raycastCheck(...)` overrides with the same signature as `Collider.raycastCheck()`.

- [ ] **Step 1: Write the failing tests**

Add to `src/source/engine/colliders/SphereCollider3d.spec.bs`, before the final `end class` (after the `@describe("debugDraw")` block):

```brightscript
    @describe("raycastCheck")

    @it("reports a hit, with entity/collider left invalid, for a ray that crosses the sphere")
    function _()
      entity = new BGE.GameEntity(m.game, {name: "A"})
      entity.position = BGE.Math.VectorOps.create(0, 0, 0)
      collider = entity.addSphereCollider3d("body", 5.0)
      hit = collider.raycastCheck(entity.position, BGE.Math.VectorOps.create(0, 0, -20), BGE.Math.VectorOps.create(0, 0, 1), 1000.0)
      m.assertNotInvalid(hit)
      m.assertInvalid(hit.entity)
      m.assertInvalid(hit.collider)
      m.assertTrue(Abs(hit.distance - 15.0) < 0.0001)
    end function

    @it("returns invalid for a ray that misses the sphere")
    function _()
      entity = new BGE.GameEntity(m.game, {name: "A"})
      entity.position = BGE.Math.VectorOps.create(0, 100, 0)
      collider = entity.addSphereCollider3d("body", 5.0)
      hit = collider.raycastCheck(entity.position, BGE.Math.VectorOps.create(0, 0, -20), BGE.Math.VectorOps.create(0, 0, 1), 1000.0)
      m.assertInvalid(hit)
    end function
```

Add to `src/source/engine/colliders/BoxCollider3d.spec.bs`, before the final `end class`:

```brightscript
    @describe("raycastCheck")

    @it("reports a hit, with entity/collider left invalid, for a ray that crosses the box")
    function _()
      entity = new BGE.GameEntity(m.game, {name: "A"})
      entity.position = BGE.Math.VectorOps.create(0, 0, 0)
      collider = entity.addBoxCollider3d("body", 10.0, 10.0, 10.0)
      hit = collider.raycastCheck(entity.position, BGE.Math.VectorOps.create(0, 0, -20), BGE.Math.VectorOps.create(0, 0, 1), 1000.0)
      m.assertNotInvalid(hit)
      m.assertInvalid(hit.entity)
      m.assertInvalid(hit.collider)
      m.assertTrue(Abs(hit.distance - 15.0) < 0.0001)
    end function

    @it("returns invalid for a ray that misses the box")
    function _()
      entity = new BGE.GameEntity(m.game, {name: "A"})
      entity.position = BGE.Math.VectorOps.create(0, 100, 0)
      collider = entity.addBoxCollider3d("body", 10.0, 10.0, 10.0)
      hit = collider.raycastCheck(entity.position, BGE.Math.VectorOps.create(0, 0, -20), BGE.Math.VectorOps.create(0, 0, 1), 1000.0)
      m.assertInvalid(hit)
    end function
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `npm run test:ci`
Expected: build/compile failure — `SphereCollider3d`/`BoxCollider3d` don't have a `raycastCheck` method yet.

- [ ] **Step 3: Implement the overrides**

In `src/source/engine/colliders/SphereCollider3d.bs`, add the import:

```brightscript
import "../../math/vector.bs"
import "../Game.bs"
import "../GameEntity.bs"
import "../renderer/Renderer.bs"
import "CircleCollider.bs"
import "Collider.bs"
import "Collision3d.bs"
import "Collision3dResults.bs"
import "Raycast.bs"
import "RaycastResult.bs"
```

Then add this method, after `confirmCollision()` and before `disableCollisionChecking()`:

```brightscript
    ' See Collider.raycastCheck()'s doc comment. Computes this sphere's true 3D center
    ' directly from m.offset (the same computation confirmCollision() uses), rather than
    ' delegating to m.xyCollider - a plain 2D CircleCollider has no z-axis to test against.
    override function raycastCheck(entityPosition as BGE.Math.Vector, rayOrigin as BGE.Math.Vector, rayDirection as BGE.Math.Vector, maxDistance as float) as BGE.RaycastHit
      center = BGE.Math.VectorOps.add(entityPosition, m.offset)
      return intersectRaySphere(rayOrigin, rayDirection, maxDistance, center, m.radius)
    end function
```

In `src/source/engine/colliders/BoxCollider3d.bs`, add the import:

```brightscript
import "../../math/vector.bs"
import "../Game.bs"
import "../GameEntity.bs"
import "Collider.bs"
import "Collision3d.bs"
import "Collision3dResults.bs"
import "Raycast.bs"
import "RaycastResult.bs"
import "RectangleCollider.bs"
```

Then add this method, after `confirmCollision()` and before `disableCollisionChecking()`:

```brightscript
    ' See Collider.raycastCheck()'s doc comment. Computes this box's true 3D min/max
    ' directly from m.offset/width/height/depth (the same computation confirmCollision()
    ' uses), rather than delegating to m.xyCollider - a plain 2D RectangleCollider has no
    ' z-axis to test against.
    override function raycastCheck(entityPosition as BGE.Math.Vector, rayOrigin as BGE.Math.Vector, rayDirection as BGE.Math.Vector, maxDistance as float) as BGE.RaycastHit
      center = BGE.Math.VectorOps.add(entityPosition, m.offset)
      half = BGE.Math.VectorOps.create(m.width / 2.0, m.height / 2.0, m.depth / 2.0)
      minPoint = BGE.Math.VectorOps.subtract(center, half)
      maxPoint = BGE.Math.VectorOps.add(center, half)
      return intersectRayAabb3d(rayOrigin, rayDirection, maxDistance, minPoint, maxPoint)
    end function
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `npm run test:ci`
Expected: `[Rooibos Result]: PASS`, including the new `raycastCheck` tests in `BGE.SphereCollider3d` and `BGE.BoxCollider3d`, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add src/source/engine/colliders/SphereCollider3d.bs src/source/engine/colliders/BoxCollider3d.bs src/source/engine/colliders/SphereCollider3d.spec.bs src/source/engine/colliders/BoxCollider3d.spec.bs
git commit -m "Add SphereCollider3d/BoxCollider3d raycastCheck overrides (#225)"
```

---

## Task 5: `Game.raycast()` / `Game.raycastAll()`

**Files:**
- Modify: `src/source/engine/Game.bs`
- Create: `src/source/engine/GameRaycast.spec.bs`

**Interfaces:**
- Consumes: `BGE.RaycastHit` (Task 1), `Collider.raycastCheck()` and its overrides (Tasks 3-4), `Game.sortedEntities as GameEntity[]`, `GameEntity.colliders as roAssociativeArray`, `GameEntity.position as BGE.Math.Vector`, `Collider.enabled as boolean`, `Collider.memberFlags`, `BGE.isValidEntity(entity) as boolean` (from `utils/utils.bs`, already imported into `Game.bs`).
- Produces: `Game.raycast(origin as BGE.Math.Vector, direction as BGE.Math.Vector, maxDistance = 10000.0 as float, collidableFlags = &hFFFFFFFF as integer) as BGE.RaycastHit`.
- Produces: `Game.raycastAll(origin as BGE.Math.Vector, direction as BGE.Math.Vector, maxDistance = 10000.0 as float, collidableFlags = &hFFFFFFFF as integer) as BGE.RaycastHit[]` — sorted by ascending `distance`.
- Removes: `Game.raycastVector(...)`, `Game.raycastAngle(...)` (the unused stubs this task replaces).

- [ ] **Step 1: Write the failing test**

Create `src/source/engine/GameRaycast.spec.bs`:

```brightscript
namespace tests

  ' Constructs a real BGE.Game with real entities/colliders, the same pattern proven in
  ' GameEntity.spec.bs and the collider spec files, to exercise Game.raycast()/raycastAll()
  ' end-to-end against real Collider.raycastCheck() overrides.
  @suite("BGE.Game raycast")
  class GameRaycastTests extends rooibos.BaseTestSuite

    game as BGE.Game

    protected override function beforeEach()
      m.game = new BGE.Game(320, 240)
    end function

    @describe("raycast / raycastAll")

    @it("returns invalid/empty when nothing is in the scene")
    function _()
      hit = m.game.raycast(BGE.Math.VectorOps.create(-20, 0), BGE.Math.VectorOps.create(1, 0))
      m.assertInvalid(hit)
      hits = m.game.raycastAll(BGE.Math.VectorOps.create(-20, 0), BGE.Math.VectorOps.create(1, 0))
      m.assertEqual(0, hits.count())
    end function

    @it("raycast() returns the nearest of several overlapping colliders, with entity/collider filled in")
    function _()
      near = m.game.addEntity(new BGE.GameEntity(m.game, {name: "Near"}))
      near.position = BGE.Math.VectorOps.create(10, 0)
      near.addCircleCollider("body", 5)

      far = m.game.addEntity(new BGE.GameEntity(m.game, {name: "Far"}))
      far.position = BGE.Math.VectorOps.create(50, 0)
      far.addCircleCollider("body", 5)

      hit = m.game.raycast(BGE.Math.VectorOps.create(-20, 0), BGE.Math.VectorOps.create(1, 0))
      m.assertNotInvalid(hit)
      m.assertEqual("Near", (hit.entity as BGE.GameEntity).name)
      m.assertTrue(Abs(hit.distance - 25.0) < 0.0001)
    end function

    @it("raycastAll() returns every hit sorted by ascending distance")
    function _()
      near = m.game.addEntity(new BGE.GameEntity(m.game, {name: "Near"}))
      near.position = BGE.Math.VectorOps.create(10, 0)
      near.addCircleCollider("body", 5)

      far = m.game.addEntity(new BGE.GameEntity(m.game, {name: "Far"}))
      far.position = BGE.Math.VectorOps.create(50, 0)
      far.addCircleCollider("body", 5)

      hits = m.game.raycastAll(BGE.Math.VectorOps.create(-20, 0), BGE.Math.VectorOps.create(1, 0))
      m.assertEqual(2, hits.count())
      m.assertEqual("Near", (hits[0].entity as BGE.GameEntity).name)
      m.assertEqual("Far", (hits[1].entity as BGE.GameEntity).name)
      m.assertTrue(hits[0].distance < hits[1].distance)
    end function

    @it("skips a disabled collider")
    function _()
      entity = m.game.addEntity(new BGE.GameEntity(m.game, {name: "A"}))
      entity.position = BGE.Math.VectorOps.create(10, 0)
      collider = entity.addCircleCollider("body", 5)
      collider.enabled = false

      hit = m.game.raycast(BGE.Math.VectorOps.create(-20, 0), BGE.Math.VectorOps.create(1, 0))
      m.assertInvalid(hit)
    end function

    @it("collidableFlags excludes a collider whose memberFlags don't overlap the mask")
    function _()
      entity = m.game.addEntity(new BGE.GameEntity(m.game, {name: "A"}))
      entity.position = BGE.Math.VectorOps.create(10, 0)
      collider = entity.addCircleCollider("body", 5)
      collider.memberFlags = 2

      excluded = m.game.raycast(BGE.Math.VectorOps.create(-20, 0), BGE.Math.VectorOps.create(1, 0), 1000.0, 1)
      m.assertInvalid(excluded)

      included = m.game.raycast(BGE.Math.VectorOps.create(-20, 0), BGE.Math.VectorOps.create(1, 0), 1000.0, 2)
      m.assertNotInvalid(included)
    end function

  end class

end namespace
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm run test:ci`
Expected: build/compile failure — `Game.raycast`/`Game.raycastAll` don't exist yet (only the old `raycastVector`/`raycastAngle` stubs do).

- [ ] **Step 3: Implement `Game.raycast()`/`raycastAll()`**

In `src/source/engine/Game.bs`, add the import (alphabetical, alongside the existing `import "colliders/Collider.bs"`):

```brightscript
import "colliders/Collider.bs"
import "colliders/RaycastResult.bs"
```

Replace the existing raycast stub section:

```brightscript
    ' --------------------------------Begin Raycast Functions----------------------------------------


    ' Performs a raycast from a certain location along a vector to find any colliders on that line
    '
    ' @param {float} sourceX x position of ray start
    ' @param {float} sourceY y position of ray start
    ' @param {float} vectorX x value of vector
    ' @param {float} vectorY y value of vector
    ' @return {object} {collider: collider, entity: entity} of first collider along the vector, or invalid if no collisions
    function raycastVector(sourceX as float, sourceY as float, vectorX as float, vectorY as float) as object

      ' TODO Do Raycasts!
      return invalid
    end function

    ' Performs a raycast from a certain location along a n angle to find any colliders on that line
    '
    ' @param {float} sourceX x position of ray start
    ' @param {float} sourceY y position of ray start
    ' @param {float} angle angle of ray
    ' @return {object} {collider: collider, entity: entity} of first collider along the angle, or invalid if no collisions
    function raycastAngle(sourceX as float, sourceY as float, angle as float) as object
      ' TODO Do Raycasts!
      return invalid
    end function
```

with:

```brightscript
    ' --------------------------------Begin Raycast Functions----------------------------------------


    ' Casts a ray from origin in direction and returns the nearest collider it intersects -
    ' 2D (CircleCollider/RectangleCollider) and 3D (SphereCollider3d/BoxCollider3d) alike.
    ' Useful for line-of-sight checks, hitscan weapons, ground/wall detection, AI vision
    ' cones, and mouse/cursor picking.
    '
    ' @param {BGE.Math.Vector} origin - world-space point the ray starts from
    ' @param {BGE.Math.Vector} direction - world-space direction of the ray (does not need to be pre-normalized)
    ' @param {float} [maxDistance=10000.0] - the ray stops testing past this distance
    ' @param {integer} [collidableFlags=&hFFFFFFFF] - only colliders whose memberFlags overlap this mask are tested (see Collider.memberFlags)
    ' @return {BGE.RaycastHit} the nearest hit, or `invalid` if the ray hit nothing
    function raycast(origin as BGE.Math.Vector, direction as BGE.Math.Vector, maxDistance = 10000.0 as float, collidableFlags = &hFFFFFFFF as integer) as BGE.RaycastHit
      hits = m.raycastAll(origin, direction, maxDistance, collidableFlags)
      if hits.count() = 0
        return invalid
      end if
      return hits[0]
    end function


    ' Casts a ray from origin in direction and returns every collider it intersects, sorted
    ' by ascending distance from origin. See raycast() for the single-nearest-hit variant.
    '
    ' @param {BGE.Math.Vector} origin - world-space point the ray starts from
    ' @param {BGE.Math.Vector} direction - world-space direction of the ray (does not need to be pre-normalized)
    ' @param {float} [maxDistance=10000.0] - the ray stops testing past this distance
    ' @param {integer} [collidableFlags=&hFFFFFFFF] - only colliders whose memberFlags overlap this mask are tested (see Collider.memberFlags)
    ' @return {BGE.RaycastHit[]} every hit along the ray, nearest first (empty array if none)
    function raycastAll(origin as BGE.Math.Vector, direction as BGE.Math.Vector, maxDistance = 10000.0 as float, collidableFlags = &hFFFFFFFF as integer) as BGE.RaycastHit[]
      normalizedDirection = BGE.Math.VectorOps.getNormalizedCopy(direction)
      hits = []
      for each entity in m.sortedEntities
        if m.isValidEntity(entity)
          for each colliderKey in entity.colliders
            myCollider = entity.colliders[colliderKey] as Collider
            if invalid <> myCollider and myCollider.enabled and (myCollider.memberFlags and collidableFlags) <> 0
              hit = myCollider.raycastCheck(entity.position, origin, normalizedDirection, maxDistance)
              if invalid <> hit
                hit.entity = entity
                hit.collider = myCollider
                hits.Push(hit)
              end if
            end if
          end for
        end if
      end for

      ' Insertion sort by ascending distance. roArray.SortBy() is deliberately not used
      ' here - it has a confirmed descending-instead-of-ascending numeric sort bug in the
      ' pinned brs-node@2.6.0 binary this project's `npm run test:ci` runs against (see
      ' issue #230 and StaticGeometryBSP.spec.bs's own note on the same bug), which would
      ' make this method's own "nearest first" guarantee untestable under CI.
      for i = 1 to hits.count() - 1
        current = hits[i]
        j = i - 1
        while j >= 0 and hits[j].distance > current.distance
          hits[j + 1] = hits[j]
          j = j - 1
        end while
        hits[j + 1] = current
      end for

      return hits
    end function
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npm run test:ci`
Expected: `[Rooibos Result]: PASS`, including the new `BGE.Game raycast` suite, 0 failures.

- [ ] **Step 5: Run the full quality gate**

Run: `npm run check`
Expected: lint, validate, and headless tests all pass with no new warnings/errors.

- [ ] **Step 6: Commit**

```bash
git add src/source/engine/Game.bs src/source/engine/GameRaycast.spec.bs
git commit -m "Add Game.raycast()/raycastAll(), replacing the old raycast stubs (#225)"
```

---

## Task 6: Docs

**Files:**
- Modify: `CLAUDE.md`

**Interfaces:**
- Consumes: nothing new — this task only documents Tasks 1-5's finished API.

- [ ] **Step 1: Add a bullet to the Collision section**

In `CLAUDE.md`, in the `### Collision (`engine/colliders/`)` section, after the existing `SphereCollider3d`/`BoxCollider3d` bullet (the one ending "...each wall its own entity with a real `BoxCollider3d`).") and before the `### Math / Utils` heading, add:

```markdown
- `Game.raycast()`/`Game.raycastAll()` (issue #225) cast a ray from a `BGE.Math.Vector` origin/direction and return the nearest (or every, sorted by ascending distance) collider it intersects as a `BGE.RaycastHit` (`entity`, `collider`, `point`, `distance`, `normal`) - across `CircleCollider`/`RectangleCollider` and `SphereCollider3d`/`BoxCollider3d` alike. Each collider type implements this via a `Collider.raycastCheck()` override (mirroring the `confirmCollision()` extension point above), delegating to a pure ray-vs-shape function in `colliders/Raycast.bs` (`intersectRayCircle`/`intersectRayAabb2d`/`intersectRaySphere`/`intersectRayAabb3d`) - since colliders are always axis-aligned (see the note above), these are always sphere/AABB tests, never OBB. An optional `collidableFlags` mask (default: match everything) reuses the same bitflag convention `Collider.memberFlags` already uses for broad-phase collision filtering, so excluding e.g. the ray-caster's own colliders is just choosing distinct flag bits. See `specs/2026-09-21-raycasting-design.md`.
```

- [ ] **Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "Document Game.raycast()/raycastAll() in CLAUDE.md (#225)"
```
