# 3D Collision Detection Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add true 3D entity-vs-entity collision detection (sphere-sphere and box-box) to the engine, using a two-plane `roCompositor` broad-phase gate plus a precise Vector-math narrow-phase confirm/resolve step, and ship a `examples/collisions3d` bouncing-spheres demo that exercises it on real hardware.

**Architecture:** `Collider` gets two new overridable hooks (`checkCollisions`/`confirmCollision`), extracted from existing logic in `Game.processEntityOnCollision` with zero behavior change for `CircleCollider`/`RectangleCollider`. Two new collider types, `SphereCollider3d`/`BoxCollider3d`, each internally own a pair of ordinary 2D colliders (one on the entity's XY plane, one on a synthetic YZ plane sharing the same `roCompositor`) for cheap native broad-phase, then confirm/reject via a pure-function 3D overlap check (`colliders/Collision3d.bs`) before `onCollision` fires.

**Tech Stack:** BrighterScript, Rooibos (`rooibos-roku`) for tests, existing `BGE.Math.Vector`/`VectorOps` primitives, `roCompositor`/`roSprite` native collision detection.

**Spec:** `specs/2026-09-18-3d-collision-detection-design.md`

## Global Constraints

- `SphereCollider3d`/`BoxCollider3d` support same-shape overlap only (sphere-vs-sphere, box-vs-box) — no cross-shape check in this plan.
- Static/world-geometry 3D collision is out of scope — entity-vs-entity dynamic collision only.
- `CircleCollider`/`RectangleCollider` behavior must be unchanged after the `Collider` refactor — their existing specs must continue to pass unmodified.
- Every new public engine method gets a JSDoc-style `'` doc comment (`@param`/`@return`), per this repo's convention (see `CLAUDE.md`).
- A file that references another file's class/interface/enum/const/function/namespace must `import` it explicitly (source-scope ambient visibility is not enough — see `CLAUDE.md`).
- Run `npm run validate` after any engine source change, `npm run test:ci` after any test change, `npm run lint` before considering a task done.

---

## File Structure

**Modify:**
- `src/source/engine/colliders/Collider.bs` — add `checkCollisions()`, `confirmCollision()`, `disableCollisionChecking()`.
- `src/source/engine/Game.bs` — refactor `processEntityOnCollision()` to use the new hooks.
- `src/source/engine/GameEntity.bs` — add `addSphereCollider3d()`/`addBoxCollider3d()`, plus imports.
- `CLAUDE.md` — document the new colliders and the `Collider` hook refactor under "Collision".

**Create:**
- `src/source/engine/colliders/Collision3d.bs` — `sphereOverlap()`/`aabbOverlap()` pure functions, `Sphere3dCollisionResult`/`Box3dCollisionResult`, `COLLIDER_3D_YZ_PLANE_FLAG` const.
- `src/source/engine/colliders/Collision3d.spec.bs`
- `src/source/engine/colliders/SphereCollider3d.bs`
- `src/source/engine/colliders/SphereCollider3d.spec.bs`
- `src/source/engine/colliders/BoxCollider3d.bs`
- `src/source/engine/colliders/BoxCollider3d.spec.bs`
- `examples/collisions3d/` — new example (scaffolded via `npm run create-example`), `src/source/Entities/Sphere.bs`, `src/source/Rooms/MainRoom.bs`.

---

## Task 1: Extract `checkCollisions`/`confirmCollision`/`disableCollisionChecking` hooks on `Collider`

**Files:**
- Modify: `src/source/engine/colliders/Collider.bs`
- Modify: `src/source/engine/Game.bs:974-1024` (`processEntityOnCollision`)
- Test: `src/source/engine/colliders/CircleCollider.spec.bs`, `src/source/engine/colliders/RectangleCollider.spec.bs` (existing — must still pass unmodified), `src/source/engine/GameEntity.spec.bs` (existing — must still pass unmodified)

**Interfaces:**
- Produces (used by Tasks 3, 4): `Collider.checkCollisions(entityPosition as BGE.Math.Vector) as object[]` — returns an array of collision-candidate records `{entityId: string, objectName: string, colliderName: string}` (base implementation: one record per `CheckMultipleCollisions()` hit, taken from that hit sprite's `GetData()`).
- Produces: `Collider.confirmCollision(myEntity as GameEntity, otherCollider as Collider, otherEntity as GameEntity) as boolean` — base implementation always returns `true`.
- Produces: `Collider.disableCollisionChecking() as void` — base implementation zeroes `compositorObject`'s member/collidable flags.

This is a pure refactor: no new test file, because the deliverable's correctness is "every existing collider/entity/game spec still passes." There's no behavior to newly assert on `Collider` itself yet — `SphereCollider3d`'s spec (Task 3) is what proves the hooks actually work for a real subclass.

- [ ] **Step 1: Run the existing collision-related specs to capture the current baseline**

```bash
npm run build-tests && npm run test:ci 2>&1 | tail -20
```

Expected: `[Rooibos Result]: PASS`, note the total passed count (you'll compare it again in Step 5 — it must be unchanged).

- [ ] **Step 2: Add the three hooks to `Collider`**

In `src/source/engine/colliders/Collider.bs`, add these three methods to the `Collider` class (after `adjustCompositorObject`, before `debugDraw`):

```brighterscript
    ' Runs this collider's broad-phase overlap check against every other collider
    ' currently registered in the compositor, moving this collider to entityPosition
    ' first. Called once per frame, per enabled collider, from Game.processEntityOnCollision().
    ' Overridden by SphereCollider3d/BoxCollider3d to combine two internal 2D colliders'
    ' own checkCollisions() results into one true-3D-aware candidate list.
    '
    ' @param {BGE.Math.Vector} entityPosition - the owning entity's current position
    ' @return {object[]} one {entityId, objectName, colliderName} record per broad-phase
    '   candidate (identifying the OTHER entity/collider each candidate collided with)
    function checkCollisions(entityPosition as BGE.Math.Vector) as object[]
      m.compositorObject.SetMemberFlags(m.memberFlags)
      m.compositorObject.SetCollidableFlags(m.collidableFlags)
      m.refreshColliderRegion()
      m.compositorObject.MoveTo(entityPosition.x, entityPosition.y)
      hits = m.compositorObject.CheckMultipleCollisions() as roSprite[]
      candidates = []
      if hits <> invalid
        for each hitSprite in hits
          data = hitSprite.GetData()
          if data <> invalid
            candidates.push(data)
          end if
        end for
      end if
      return candidates
    end function


    ' Called once per checkCollisions() candidate, before onCollision() fires, as a final
    ' gate. The base implementation always confirms (the broad-phase result already is the
    ' final answer for a plain 2D collider) - overridden by SphereCollider3d/BoxCollider3d
    ' to run a precise 3D math check, since their own broad-phase can produce false
    ' positives (see SphereCollider3d's own doc comment).
    '
    ' @param {GameEntity} myEntity - the entity this collider is attached to
    ' @param {Collider} otherCollider - the other entity's collider that broad-phase matched
    ' @param {GameEntity} otherEntity
    ' @return {boolean} true if this candidate is a genuine collision
    function confirmCollision(myEntity as object, otherCollider as Collider, otherEntity as object) as boolean
      return true
    end function


    ' Zeroes this collider's member/collidable flags so it stops participating in
    ' collision checks, without removing it from the compositor. Called every frame by
    ' Game.processEntityOnCollision() for a disabled collider. Overridden by
    ' SphereCollider3d/BoxCollider3d to disable both of their internal 2D colliders.
    sub disableCollisionChecking()
      m.compositorObject.SetMemberFlags(0)
      m.compositorObject.SetCollidableFlags(0)
    end sub
```

Note: `myEntity`/`otherEntity` are typed `as object` here (not `as GameEntity`) specifically to avoid a circular import — `Collider.bs` is imported by `GameEntity.bs`, so `Collider.bs` importing `GameEntity.bs` back would cycle. `SphereCollider3d.bs`/`BoxCollider3d.bs` (Tasks 3/4), which are NOT imported by `GameEntity.bs` itself, can import `GameEntity.bs` and use the real `GameEntity` type in their own `override` signatures.

- [ ] **Step 3: Refactor `Game.processEntityOnCollision` to use the new hooks**

Replace the body of `processEntityOnCollision` in `src/source/engine/Game.bs` (currently lines 974-1024) with:

```brighterscript
    ' Checks all colliders in an entity with all other colliders and if
    ' there is a collision, will call the entity's onCollsion() function
    '
    ' @param {GameEntity} entity
    ' @return {boolean} true if this entity is still valid
    private function processEntityOnCollision(entity as GameEntity) as boolean
      if not m.isValidEntity(entity)
        return false
      end if
      for each colliderKey in entity.colliders
        myCollider = entity.colliders[colliderKey] as Collider
        if myCollider <> invalid
          if myCollider.enabled
            candidates = myCollider.checkCollisions(entity.position)
            for each otherColliderData in candidates
              if invalid <> otherColliderData and invalid <> otherColliderData.entityId
                if otherColliderData.entityId <> entity.id
                  otherEntity as GameEntity = invalid
                  if invalid <> m.Entities[otherColliderData.objectName][otherColliderData.entityId]
                    otherEntity = m.Entities[otherColliderData.objectName][otherColliderData.entityId] as GameEntity
                  else if invalid <> m.currentRoom and otherColliderData.objectName = m.currentRoom.name
                    ' Or is it the current room?
                    otherEntity = m.currentRoom as GameEntity
                  end if
                  if invalid <> otherEntity and otherEntity.id <> entity.id
                    otherColliderObj = otherEntity.colliders[otherColliderData.colliderName]
                    if myCollider.confirmCollision(entity, otherColliderObj, otherEntity)
                      entity.onCollision(myCollider, otherColliderObj, otherEntity)
                      if not m.isValidEntity(entity)
                        return false
                      end if
                    end if
                  end if
                end if
              end if
            end for
            if not m.isValidEntity(entity)
              return false
            end if
          else
            myCollider.disableCollisionChecking()
          end if
        else
          if invalid <> entity.colliders[colliderKey]
            entity.colliders.Delete(colliderKey)
          end if
        end if
      end for
      return true
    end function
```

- [ ] **Step 4: Validate and lint**

```bash
npm run validate && npm run lint
```

Expected: both exit 0, no new errors/warnings.

- [ ] **Step 5: Re-run the full test suite and confirm the same pass count as Step 1**

```bash
npm run build-tests && npm run test:ci 2>&1 | tail -20
```

Expected: `[Rooibos Result]: PASS`, same total passed count as Step 1 (this refactor changes no behavior).

- [ ] **Step 6: Commit**

```bash
git add src/source/engine/colliders/Collider.bs src/source/engine/Game.bs
git commit -m "Extract checkCollisions/confirmCollision/disableCollisionChecking hooks on Collider

Pure refactor ahead of #131 - moves the roCompositor-specific broad-phase
logic out of Game.processEntityOnCollision and onto Collider itself as
overridable hooks, with zero behavior change for CircleCollider/
RectangleCollider. A 3D collider (next task) needs to combine two internal
2D colliders' own broad-phase results and reject broad-phase false
positives with a precise math check - neither is expressible against the
old inline-in-Game.bs shape."
```

---

## Task 2: `Collision3d.bs` — pure-function sphere/AABB overlap resolvers

**Files:**
- Create: `src/source/engine/colliders/Collision3d.bs`
- Test: `src/source/engine/colliders/Collision3d.spec.bs`

**Interfaces:**
- Consumes: `BGE.Math.VectorOps.subtract/length/scale/create/add` (`src/source/math/vector.bs`), `BGE.Math.Min/Max` (`src/source/math/math.bs`).
- Produces (used by Tasks 3, 4): `BGE.sphereOverlap(centerA as Vector, radiusA as float, centerB as Vector, radiusB as float) as Sphere3dCollisionResult`, `BGE.aabbOverlap(minA as Vector, maxA as Vector, minB as Vector, maxB as Vector) as Box3dCollisionResult`, `BGE.Sphere3dCollisionResult{overlapping, normal, penetrationDepth}`, `BGE.Box3dCollisionResult{overlapping, normal, penetrationDepth}`, `BGE.COLLIDER_3D_YZ_PLANE_FLAG` (const).

- [ ] **Step 1: Write the failing spec**

Create `src/source/engine/colliders/Collision3d.spec.bs`:

```brighterscript
namespace tests

  @suite("BGE.sphereOverlap")
  class SphereOverlapTests extends rooibos.BaseTestSuite

    @describe("sphereOverlap")

    @it("reports no overlap when spheres are far apart")
    function _()
      result = BGE.sphereOverlap(BGE.Math.VectorOps.create(0, 0, 0), 5.0, BGE.Math.VectorOps.create(100, 0, 0), 5.0)
      m.assertFalse(result.overlapping)
    end function

    @it("reports overlap when spheres genuinely intersect in 3D")
    function _()
      result = BGE.sphereOverlap(BGE.Math.VectorOps.create(0, 0, 0), 5.0, BGE.Math.VectorOps.create(3, 0, 3), 5.0)
      m.assertTrue(result.overlapping)
    end function

    @it("rejects the diagonal near-miss that a two-plane-only check would false-positive on")
    function _()
      ' distance = sqrt(8^2 + 0^2 + 8^2) ~= 11.31, > radius sum (10) - see
      ' specs/2026-09-18-3d-collision-detection-design.md's spike findings.
      result = BGE.sphereOverlap(BGE.Math.VectorOps.create(0, 0, 0), 5.0, BGE.Math.VectorOps.create(8, 0, 8), 5.0)
      m.assertFalse(result.overlapping)
    end function

    @it("returns a normal pointing from centerB toward centerA, and a positive penetration depth")
    function _()
      result = BGE.sphereOverlap(BGE.Math.VectorOps.create(4, 0, 0), 5.0, BGE.Math.VectorOps.create(0, 0, 0), 5.0)
      m.assertTrue(result.overlapping)
      m.assertEqual(1.0, result.normal.x)
      m.assertEqual(0.0, result.normal.y)
      m.assertEqual(0.0, result.normal.z)
      m.assertEqual(6.0, result.penetrationDepth) ' radius sum (10) - distance (4)
    end function

  end class

  @suite("BGE.aabbOverlap")
  class AabbOverlapTests extends rooibos.BaseTestSuite

    @describe("aabbOverlap")

    @it("reports no overlap when boxes are separated on any single axis")
    function _()
      result = BGE.aabbOverlap(
      BGE.Math.VectorOps.create(0, 0, 0), BGE.Math.VectorOps.create(10, 10, 10),
      BGE.Math.VectorOps.create(20, 0, 0), BGE.Math.VectorOps.create(30, 10, 10))
      m.assertFalse(result.overlapping)
    end function

    @it("reports overlap when boxes genuinely intersect on all three axes")
    function _()
      result = BGE.aabbOverlap(
      BGE.Math.VectorOps.create(0, 0, 0), BGE.Math.VectorOps.create(10, 10, 10),
      BGE.Math.VectorOps.create(5, 5, 5), BGE.Math.VectorOps.create(15, 15, 15))
      m.assertTrue(result.overlapping)
    end function

    @it("picks the least-overlapping axis as the normal direction")
    function _()
      ' Overlaps by 5 on x, 10 on y, 10 on z - x is the shallowest penetration
      result = BGE.aabbOverlap(
      BGE.Math.VectorOps.create(0, 0, 0), BGE.Math.VectorOps.create(10, 10, 10),
      BGE.Math.VectorOps.create(5, 0, 0), BGE.Math.VectorOps.create(15, 10, 10))
      m.assertTrue(result.overlapping)
      m.assertEqual(5.0, result.penetrationDepth)
      m.assertEqual(-1.0, result.normal.x) ' A's center (5) is left of B's center (10)
      m.assertEqual(0.0, result.normal.y)
      m.assertEqual(0.0, result.normal.z)
    end function

  end class

end namespace
```

- [ ] **Step 2: Run it to verify it fails**

```bash
npm run build-tests && npm run test:ci 2>&1 | grep -A3 "sphereOverlap\|aabbOverlap"
```

Expected: build/compile failure (`BGE.sphereOverlap`/`BGE.aabbOverlap` don't exist yet).

- [ ] **Step 3: Implement `Collision3d.bs`**

Create `src/source/engine/colliders/Collision3d.bs`:

```brighterscript
import "../../math/vector.bs"

namespace BGE

  ' Reserved member/collidable flag bit for SphereCollider3d/BoxCollider3d's internal "YZ
  ' plane" broad-phase colliders. Both the XY-plane and YZ-plane internal colliders
  ' register against the SAME shared roCompositor (Game.compositor) - without a dedicated
  ' flag, a YZ-plane collider (whose MoveTo position is (entity.y, entity.z), not a real
  ' screen position) could spuriously "collide" with an ordinary 2D collider whose real
  ' (x, y) position happens to numerically coincide. Every YZ-plane collider's member AND
  ' collidable flags are set to this bit, so it can only ever match another YZ-plane
  ' collider. See specs/2026-09-18-3d-collision-detection-design.md.
  const COLLIDER_3D_YZ_PLANE_FLAG = &h40000000

  ' The result of sphereOverlap(): whether two spheres truly overlap in 3D, and if so, the
  ' contact normal (points away from centerB, toward centerA) and how far they're
  ' currently penetrating along that normal.
  class Sphere3dCollisionResult
    overlapping as boolean
    normal as BGE.Math.Vector
    penetrationDepth as float

    sub new(overlapping as boolean, normal as BGE.Math.Vector, penetrationDepth as float)
      m.overlapping = overlapping
      m.normal = normal
      m.penetrationDepth = penetrationDepth
    end sub
  end class

  ' The result of aabbOverlap(): whether two axis-aligned boxes truly overlap, and if so,
  ' the contact normal (along whichever axis has the least overlap, away from box B and
  ' toward box A) and the penetration depth along that axis.
  class Box3dCollisionResult
    overlapping as boolean
    normal as BGE.Math.Vector
    penetrationDepth as float

    sub new(overlapping as boolean, normal as BGE.Math.Vector, penetrationDepth as float)
      m.overlapping = overlapping
      m.normal = normal
      m.penetrationDepth = penetrationDepth
    end sub
  end class


  ' True 3D sphere-sphere overlap test - the narrow-phase check SphereCollider3d.
  ' confirmCollision() runs after its two-plane broad-phase gate finds a candidate pair,
  ' since two spheres can pass both plane checks while never actually touching in 3D (a
  ' diagonal near-miss - see the design doc's spike findings). No precondition - safe to
  ' call with any two centers/radii.
  '
  ' @param {BGE.Math.Vector} centerA
  ' @param {float} radiusA
  ' @param {BGE.Math.Vector} centerB
  ' @param {float} radiusB
  ' @return {BGE.Sphere3dCollisionResult}
  function sphereOverlap(centerA as BGE.Math.Vector, radiusA as float, centerB as BGE.Math.Vector, radiusB as float) as BGE.Sphere3dCollisionResult
    diff = BGE.Math.VectorOps.subtract(centerA, centerB)
    dist = BGE.Math.VectorOps.length(diff)
    radiusSum = radiusA + radiusB

    if dist >= radiusSum
      return new BGE.Sphere3dCollisionResult(false, BGE.Math.VectorOps.create(0, 1, 0), 0.0)
    end if

    if dist > 0.0
      normal = BGE.Math.VectorOps.scale(diff, 1.0 / dist)
    else
      ' Centers exactly coincide - no meaningful direction, pick an arbitrary axis.
      normal = BGE.Math.VectorOps.create(0, 1, 0)
    end if

    return new BGE.Sphere3dCollisionResult(true, normal, radiusSum - dist)
  end function


  ' True 3D AABB-vs-AABB overlap test. Unlike sphereOverlap(), a two-plane broad-phase
  ' gate for boxes has no false-positive case - AABB overlap decomposes exactly per axis
  ' (see the design doc). BoxCollider3d.confirmCollision() still calls this, but only to
  ' compute the penetration/normal result, since the broad-phase result is already
  ' correct. No precondition - safe to call with any two boxes.
  '
  ' @param {BGE.Math.Vector} minA
  ' @param {BGE.Math.Vector} maxA
  ' @param {BGE.Math.Vector} minB
  ' @param {BGE.Math.Vector} maxB
  ' @return {BGE.Box3dCollisionResult}
  function aabbOverlap(minA as BGE.Math.Vector, maxA as BGE.Math.Vector, minB as BGE.Math.Vector, maxB as BGE.Math.Vector) as BGE.Box3dCollisionResult
    overlapX = BGE.Math.Min(maxA.x, maxB.x) - BGE.Math.Max(minA.x, minB.x)
    overlapY = BGE.Math.Min(maxA.y, maxB.y) - BGE.Math.Max(minA.y, minB.y)
    overlapZ = BGE.Math.Min(maxA.z, maxB.z) - BGE.Math.Max(minA.z, minB.z)

    if overlapX <= 0.0 or overlapY <= 0.0 or overlapZ <= 0.0
      return new BGE.Box3dCollisionResult(false, BGE.Math.VectorOps.create(0, 1, 0), 0.0)
    end if

    centerA = BGE.Math.VectorOps.scale(BGE.Math.VectorOps.add(minA, maxA), 0.5)
    centerB = BGE.Math.VectorOps.scale(BGE.Math.VectorOps.add(minB, maxB), 0.5)

    if overlapX <= overlapY and overlapX <= overlapZ
      sign = 1.0
      if centerA.x < centerB.x
        sign = -1.0
      end if
      return new BGE.Box3dCollisionResult(true, BGE.Math.VectorOps.create(sign, 0, 0), overlapX)
    else if overlapY <= overlapZ
      sign = 1.0
      if centerA.y < centerB.y
        sign = -1.0
      end if
      return new BGE.Box3dCollisionResult(true, BGE.Math.VectorOps.create(0, sign, 0), overlapY)
    else
      sign = 1.0
      if centerA.z < centerB.z
        sign = -1.0
      end if
      return new BGE.Box3dCollisionResult(true, BGE.Math.VectorOps.create(0, 0, sign), overlapZ)
    end if
  end function

end namespace
```

- [ ] **Step 4: Run the spec and verify it passes**

```bash
npm run build-tests && npm run test:ci 2>&1 | grep -B1 -A1 "sphereOverlap\|aabbOverlap"
```

Expected: all `SphereOverlapTests`/`AabbOverlapTests` cases pass (✔).

- [ ] **Step 5: Validate and lint**

```bash
npm run validate && npm run lint
```

Expected: both exit 0.

- [ ] **Step 6: Commit**

```bash
git add src/source/engine/colliders/Collision3d.bs src/source/engine/colliders/Collision3d.spec.bs
git commit -m "Add pure-function 3D sphere/AABB overlap resolvers (#131)

sphereOverlap()/aabbOverlap() live alongside TileCollision.bs's existing
pure-function-resolver pattern. sphereOverlap() is what fixes the
two-plane compositor trick's diagonal-near-miss false positive found by
the design spike."
```

---

## Task 3: `SphereCollider3d`

**Files:**
- Create: `src/source/engine/colliders/SphereCollider3d.bs`
- Test: `src/source/engine/colliders/SphereCollider3d.spec.bs`

**Interfaces:**
- Consumes: `Collider.checkCollisions/confirmCollision/disableCollisionChecking/setupCompositor` (Task 1), `CircleCollider` (existing), `BGE.sphereOverlap`/`Sphere3dCollisionResult`/`COLLIDER_3D_YZ_PLANE_FLAG` (Task 2).
- Produces (used by Task 5): `SphereCollider3d extends Collider`, constructed via `new BGE.SphereCollider3d(name, {radius: ..., offset: ...})`, field `radius as float`, field `lastCollisionResult as Sphere3dCollisionResult` (readable from `onCollision()`), `colliderType = "sphere3d"`.

- [ ] **Step 1: Write the failing spec**

Create `src/source/engine/colliders/SphereCollider3d.spec.bs`:

```brighterscript
namespace tests

  ' Constructs real BGE.Game/GameEntity/roCompositor, same pattern as
  ' CircleCollider.spec.bs - proven to work headlessly under brs-cli.
  @suite("BGE.SphereCollider3d")
  class SphereCollider3dTests extends rooibos.BaseTestSuite

    game as BGE.Game

    protected override function beforeEach()
      m.game = new BGE.Game(320, 240)
    end function

    @describe("new")

    @it("sets colliderType to 'sphere3d' and stores the given radius")
    function _()
      entity = new BGE.GameEntity(m.game, {name: "A"})
      collider = entity.addSphereCollider3d("body", 15.0)
      m.assertEqual("sphere3d", collider.colliderType)
      m.assertEqual(15.0, collider.radius)
    end function

    @describe("checkCollisions / confirmCollision - broad-phase + narrow-phase together")

    @it("finds no broad-phase candidate when spheres are far apart on every axis")
    function _()
      entityA = new BGE.GameEntity(m.game, {name: "A"})
      entityA.position = BGE.Math.VectorOps.create(0, 0, 0)
      colliderA = entityA.addSphereCollider3d("body", 5.0)

      entityB = new BGE.GameEntity(m.game, {name: "B"})
      entityB.position = BGE.Math.VectorOps.create(500, 500, 500)
      entityB.addSphereCollider3d("body", 5.0)

      candidates = colliderA.checkCollisions(entityA.position)
      m.assertEqual(0, candidates.count())
    end function

    @it("finds a broad-phase candidate AND confirms it for a genuine 3D overlap")
    function _()
      entityA = new BGE.GameEntity(m.game, {name: "A"})
      entityA.position = BGE.Math.VectorOps.create(0, 0, 0)
      colliderA = entityA.addSphereCollider3d("body", 5.0)

      entityB = new BGE.GameEntity(m.game, {name: "B"})
      entityB.position = BGE.Math.VectorOps.create(3, 0, 3)
      colliderB = entityB.addSphereCollider3d("body", 5.0)

      candidates = colliderA.checkCollisions(entityA.position)
      m.assertEqual(1, candidates.count())
      m.assertEqual("body", candidates[0].colliderName)

      m.assertTrue(colliderA.confirmCollision(entityA, colliderB, entityB))
      m.assertTrue(colliderA.lastCollisionResult.overlapping)
    end function

    @it("finds a broad-phase candidate but REJECTS it on the diagonal near-miss (the false positive the two-plane trick alone would produce)")
    function _()
      entityA = new BGE.GameEntity(m.game, {name: "A"})
      entityA.position = BGE.Math.VectorOps.create(0, 0, 0)
      colliderA = entityA.addSphereCollider3d("body", 5.0)

      entityB = new BGE.GameEntity(m.game, {name: "B"})
      entityB.position = BGE.Math.VectorOps.create(8, 0, 8)
      colliderB = entityB.addSphereCollider3d("body", 5.0)

      ' Both planes overlap (broad-phase finds a candidate)...
      candidates = colliderA.checkCollisions(entityA.position)
      m.assertEqual(1, candidates.count())

      ' ...but the true 3D distance (~11.31) exceeds the radius sum (10), so
      ' confirmCollision() must reject it.
      m.assertFalse(colliderA.confirmCollision(entityA, colliderB, entityB))
      m.assertFalse(colliderA.lastCollisionResult.overlapping)
    end function

    @it("does not treat an ordinary CircleCollider at the same numeric position as a YZ-plane match")
    function _()
      entityA = new BGE.GameEntity(m.game, {name: "A"})
      entityA.position = BGE.Math.VectorOps.create(0, 0, 5)
      colliderA = entityA.addSphereCollider3d("body", 5.0)

      ' An ordinary 2D CircleCollider on another entity, positioned at (5, 0) - the same
      ' (x, y) SphereCollider3d's synthetic YZ-plane collider would compute from
      ' entityA's own (y=0, z=5). Without COLLIDER_3D_YZ_PLANE_FLAG segregation, this
      ' could spuriously satisfy the YZ half of the two-plane gate.
      entityC = new BGE.GameEntity(m.game, {name: "C"})
      entityC.position = BGE.Math.VectorOps.create(5, 0, 0)
      entityC.addCircleCollider("body", 5.0)

      candidates = colliderA.checkCollisions(entityA.position)
      m.assertEqual(0, candidates.count())
    end function

  end class

end namespace
```

- [ ] **Step 2: Run it to verify it fails**

```bash
npm run build-tests && npm run test:ci 2>&1 | grep -A3 "SphereCollider3d"
```

Expected: build/compile failure (`addSphereCollider3d` doesn't exist yet).

- [ ] **Step 3: Implement `SphereCollider3d.bs`**

Create `src/source/engine/colliders/SphereCollider3d.bs`:

```brighterscript
import "../../math/vector.bs"
import "../Game.bs"
import "../GameEntity.bs"
import "CircleCollider.bs"
import "Collider.bs"
import "Collision3d.bs"

namespace BGE

  ' A collider with the shape of a sphere centered at (offset.x, offset.y, offset.z) with
  ' given radius, that detects a true 3D overlap - not just an XY-space projection.
  '
  ' Internally, this owns two ordinary CircleColliders for broad-phase: one tracking the
  ' entity's real (x, y) - the same XY plane every other 2D Collider uses - and one
  ' tracking a synthetic (y, z) "YZ plane", flagged with COLLIDER_3D_YZ_PLANE_FLAG so it
  ' can only ever match another YZ-plane collider (both register against the same
  ' roCompositor as ordinary 2D colliders, so without this flag a YZ-plane collider could
  ' spuriously match an unrelated 2D collider at the same numeric (x, y) position). A pair
  ' only becomes a broad-phase candidate when it overlaps on BOTH planes - and even then,
  ' confirmCollision() runs a true sphere-sphere distance check before accepting it,
  ' because two spheres can pass both plane checks while never actually touching in 3D (a
  ' diagonal near-miss). See specs/2026-09-18-3d-collision-detection-design.md.
  class SphereCollider3d extends Collider

    ' Radius of the sphere
    radius = 0.0

    ' The most recent confirmCollision() result, readable from onCollision() to compute a
    ' bounce response - result.normal points away from the other entity, toward this
    ' collider's own entity. Set every time confirmCollision() runs, whether or not it
    ' confirmed (check result.overlapping).
    lastCollisionResult as Sphere3dCollisionResult = invalid

    private xyCollider as CircleCollider
    private yzCollider as CircleCollider

    ' Create a new SphereCollider3d
    '
    ' @param {string} colliderName - name of this collider
    ' @param [args={}] - additional properties (e.g {radius: 10})
    sub new (colliderName as string, args = {} as roAssociativeArray)
      super(colliderName, args)
      m.colliderType = "sphere3d"
      ' bs:disable-next-line: 1140
      m.append(args)
    end sub


    override sub setupCompositor(gameEngine as Game, entityName as string, entityId as string, entityPosition as BGE.Math.Vector)
      m.xyCollider = new CircleCollider(m.name + "__xyPlane", {
        radius: m.radius,
        offset: BGE.Math.VectorOps.create(m.offset.x, m.offset.y)
      })
      m.xyCollider.setupCompositor(gameEngine, entityName, entityId, entityPosition)

      m.yzCollider = new CircleCollider(m.name + "__yzPlane", {
        radius: m.radius,
        offset: BGE.Math.VectorOps.create(m.offset.y, m.offset.z ?? 0),
        memberFlags: COLLIDER_3D_YZ_PLANE_FLAG,
        collidableFlags: COLLIDER_3D_YZ_PLANE_FLAG
      })
      m.yzCollider.setupCompositor(gameEngine, entityName, entityId, m.toYZPosition(entityPosition))
    end sub


    override function checkCollisions(entityPosition as BGE.Math.Vector) as object[]
      xyCandidates = m.xyCollider.checkCollisions(entityPosition)
      yzCandidates = m.yzCollider.checkCollisions(m.toYZPosition(entityPosition))

      yzKeys = {}
      for each candidate in yzCandidates
        yzKeys[candidate.entityId + ":" + m.stripPlaneSuffix(candidate.colliderName)] = true
      end for

      result = []
      for each candidate in xyCandidates
        baseName = m.stripPlaneSuffix(candidate.colliderName)
        key = candidate.entityId + ":" + baseName
        if yzKeys[key] = true
          result.push({entityId: candidate.entityId, objectName: candidate.objectName, colliderName: baseName})
        end if
      end for
      return result
    end function


    override function confirmCollision(myEntity as object, otherCollider as Collider, otherEntity as object) as boolean
      if otherCollider = invalid or otherCollider.colliderType <> "sphere3d"
        m.lastCollisionResult = new Sphere3dCollisionResult(false, BGE.Math.VectorOps.create(0, 1, 0), 0.0)
        return false
      end if
      otherSphere = otherCollider as SphereCollider3d
      myGameEntity = myEntity as GameEntity
      otherGameEntity = otherEntity as GameEntity
      myCenter = BGE.Math.VectorOps.add(myGameEntity.position, m.offset)
      otherCenter = BGE.Math.VectorOps.add(otherGameEntity.position, otherSphere.offset)
      m.lastCollisionResult = sphereOverlap(myCenter, m.radius, otherCenter, otherSphere.radius)
      return m.lastCollisionResult.overlapping
    end function


    override sub disableCollisionChecking()
      m.xyCollider.disableCollisionChecking()
      m.yzCollider.disableCollisionChecking()
    end sub


    ' Game.adjustEntityCompositorObjectPostCollision() calls this directly on every
    ' collider, every frame, right after processEntityOnCollision() - the base Collider
    ' implementation touches m.compositorObject directly, which this class never sets on
    ' itself (only m.xyCollider/m.yzCollider have real compositorObjects), so this MUST be
    ' overridden or every frame crashes for any entity holding a SphereCollider3d.
    override sub adjustCompositorObject(entityPosition as BGE.Math.Vector)
      m.xyCollider.adjustCompositorObject(entityPosition)
      m.yzCollider.adjustCompositorObject(m.toYZPosition(entityPosition))
    end sub


    private function toYZPosition(entityPosition as BGE.Math.Vector) as BGE.Math.Vector
      return BGE.Math.VectorOps.create(entityPosition.y, entityPosition.z ?? 0)
    end function


    private function stripPlaneSuffix(colliderName as string) as string
      if Right(colliderName, 9) = "__xyPlane" or Right(colliderName, 9) = "__yzPlane"
        return Left(colliderName, Len(colliderName) - 9)
      end if
      return colliderName
    end function

  end class
end namespace
```

- [ ] **Step 4: Add `GameEntity.addSphereCollider3d()`**

In `src/source/engine/GameEntity.bs`, add this import near the existing collider imports (after `import "colliders/RectangleCollider.bs"`):

```brighterscript
import "colliders/SphereCollider3d.bs"
```

Then add this method right after `addRectangleCollider` (before `addCollider`):

```brighterscript
    ' Adds a sphere collider to this entity, for true 3D overlap detection (not just an
    ' XY-space projection) - see BGE.SphereCollider3d.
    '
    ' @param {string} colliderName - Name of the collider (only one collider with the same name can be added)
    ' @param {float} radius - radius of the sphere
    ' @param {float} [offset_x=0] - horizontal offset from entity position of centre of the sphere
    ' @param {float} [offset_y=0] - vertical offset from entity position of centre of the sphere
    ' @param {float} [offset_z=0] - depth offset from entity position of centre of the sphere
    ' @param {boolean} [enabled=true] - is this collider enabled?
    ' @return {object}  - the collider that was added, or `invalid` if it could not be added
    function addSphereCollider3d(colliderName as string, radius as float, offset_x = 0 as float, offset_y = 0 as float, offset_z = 0 as float, enabled = true as boolean) as SphereCollider3d
      sphereCollider = new SphereCollider3d(colliderName, {
        enabled: enabled,
        radius: radius,
        offset: BGE.Math.VectorOps.create(offset_x, offset_y, offset_z)
      })
      return m.addCollider(sphereCollider) as SphereCollider3d
    end function
```

- [ ] **Step 5: Run the spec and verify it passes**

```bash
npm run build-tests && npm run test:ci 2>&1 | grep -B1 -A6 "BGE.SphereCollider3d"
```

Expected: all 5 `SphereCollider3dTests` cases pass (✔), including the diagonal-near-miss rejection and the YZ-flag-segregation test.

- [ ] **Step 6: Validate and lint**

```bash
npm run validate && npm run lint
```

Expected: both exit 0.

- [ ] **Step 7: Commit**

```bash
git add src/source/engine/colliders/SphereCollider3d.bs src/source/engine/colliders/SphereCollider3d.spec.bs src/source/engine/GameEntity.bs
git commit -m "Add SphereCollider3d + GameEntity.addSphereCollider3d() (#131)

Two-plane roCompositor broad-phase (segregated from ordinary 2D colliders
via COLLIDER_3D_YZ_PLANE_FLAG) + sphereOverlap() narrow-phase confirm.
Spec proves the diagonal-near-miss false positive the design spike found
in the two-plane-only approach is now correctly rejected end to end."
```

---

## Task 4: `BoxCollider3d`

**Files:**
- Create: `src/source/engine/colliders/BoxCollider3d.bs`
- Test: `src/source/engine/colliders/BoxCollider3d.spec.bs`
- Modify: `src/source/engine/GameEntity.bs`

**Interfaces:**
- Consumes: `Collider.checkCollisions/confirmCollision/disableCollisionChecking/setupCompositor` (Task 1), `RectangleCollider` (existing), `BGE.aabbOverlap`/`Box3dCollisionResult`/`COLLIDER_3D_YZ_PLANE_FLAG` (Task 2).
- Produces: `BoxCollider3d extends Collider`, constructed via `new BGE.BoxCollider3d(name, {width, height, depth, offset})`, fields `width`/`height`/`depth as float`, field `lastCollisionResult as Box3dCollisionResult`, `colliderType = "box3d"`. `offset` is the box's CENTER (not a corner - a deliberate simplification vs. `RectangleCollider`'s own corner-based convention, see the class doc comment below).

- [ ] **Step 1: Write the failing spec**

Create `src/source/engine/colliders/BoxCollider3d.spec.bs`:

```brighterscript
namespace tests

  @suite("BGE.BoxCollider3d")
  class BoxCollider3dTests extends rooibos.BaseTestSuite

    game as BGE.Game

    protected override function beforeEach()
      m.game = new BGE.Game(320, 240)
    end function

    @describe("new")

    @it("sets colliderType to 'box3d' and stores the given dimensions")
    function _()
      entity = new BGE.GameEntity(m.game, {name: "A"})
      collider = entity.addBoxCollider3d("body", 20.0, 30.0, 40.0)
      m.assertEqual("box3d", collider.colliderType)
      m.assertEqual(20.0, collider.width)
      m.assertEqual(30.0, collider.height)
      m.assertEqual(40.0, collider.depth)
    end function

    @describe("checkCollisions / confirmCollision - broad-phase + narrow-phase together")

    @it("finds no broad-phase candidate when boxes are far apart on every axis")
    function _()
      entityA = new BGE.GameEntity(m.game, {name: "A"})
      entityA.position = BGE.Math.VectorOps.create(0, 0, 0)
      colliderA = entityA.addBoxCollider3d("body", 10.0, 10.0, 10.0)

      entityB = new BGE.GameEntity(m.game, {name: "B"})
      entityB.position = BGE.Math.VectorOps.create(500, 500, 500)
      entityB.addBoxCollider3d("body", 10.0, 10.0, 10.0)

      candidates = colliderA.checkCollisions(entityA.position)
      m.assertEqual(0, candidates.count())
    end function

    @it("finds a broad-phase candidate AND confirms it for two overlapping boxes centered on the same point")
    function _()
      entityA = new BGE.GameEntity(m.game, {name: "A"})
      entityA.position = BGE.Math.VectorOps.create(0, 0, 0)
      colliderA = entityA.addBoxCollider3d("body", 10.0, 10.0, 10.0)

      entityB = new BGE.GameEntity(m.game, {name: "B"})
      entityB.position = BGE.Math.VectorOps.create(0, 0, 0)
      colliderB = entityB.addBoxCollider3d("body", 10.0, 10.0, 10.0)

      candidates = colliderA.checkCollisions(entityA.position)
      m.assertEqual(1, candidates.count())

      m.assertTrue(colliderA.confirmCollision(entityA, colliderB, entityB))
      m.assertTrue(colliderA.lastCollisionResult.overlapping)
      m.assertEqual(10.0, colliderA.lastCollisionResult.penetrationDepth)
    end function

    @it("does not confirm when boxes are offset enough on one axis to not truly overlap")
    function _()
      entityA = new BGE.GameEntity(m.game, {name: "A"})
      entityA.position = BGE.Math.VectorOps.create(0, 0, 0)
      colliderA = entityA.addBoxCollider3d("body", 10.0, 10.0, 10.0)

      entityB = new BGE.GameEntity(m.game, {name: "B"})
      entityB.position = BGE.Math.VectorOps.create(0, 0, 20)
      colliderB = entityB.addBoxCollider3d("body", 10.0, 10.0, 10.0)

      m.assertFalse(colliderA.confirmCollision(entityA, colliderB, entityB))
      m.assertFalse(colliderA.lastCollisionResult.overlapping)
    end function

  end class

end namespace
```

- [ ] **Step 2: Run it to verify it fails**

```bash
npm run build-tests && npm run test:ci 2>&1 | grep -A3 "BoxCollider3d"
```

Expected: build/compile failure (`addBoxCollider3d` doesn't exist yet).

- [ ] **Step 3: Implement `BoxCollider3d.bs`**

Create `src/source/engine/colliders/BoxCollider3d.bs`:

```brighterscript
import "../../math/vector.bs"
import "../Game.bs"
import "../GameEntity.bs"
import "Collider.bs"
import "Collision3d.bs"
import "RectangleCollider.bs"

namespace BGE

  ' A collider with the shape of an axis-aligned box CENTERED at (offset.x, offset.y,
  ' offset.z), with given width (x), height (y), depth (z). Note this offset convention
  ' is center-based, not RectangleCollider's own corner-based convention (see
  ' RectangleCollider's class doc) - deliberately simpler, since BoxCollider3d's own 3D
  ' math (aabbOverlap()) has no reason to inherit RectangleCollider's screen-space corner
  ' convention.
  '
  ' Internally, this owns two ordinary RectangleColliders for broad-phase - one tracking
  ' the entity's real (x, y) plane, one tracking a synthetic (y, z) "YZ plane", flagged
  ' with COLLIDER_3D_YZ_PLANE_FLAG the same way SphereCollider3d's internal colliders are
  ' (see that class's doc comment for why). Unlike SphereCollider3d, this two-plane broad
  ' phase has NO false-positive case for boxes - AABB overlap decomposes exactly per axis,
  ' so a pair that passes both plane checks is always a genuine 3D overlap. confirmCollision()
  ' still runs aabbOverlap(), but only to compute the penetration/normal result for physics
  ' response, not to reject anything. See specs/2026-09-18-3d-collision-detection-design.md.
  class BoxCollider3d extends Collider

    width = 0.0
    height = 0.0
    depth = 0.0

    ' The most recent confirmCollision() result, readable from onCollision() to compute a
    ' bounce response - result.normal points away from the other entity, toward this
    ' collider's own entity.
    lastCollisionResult as Box3dCollisionResult = invalid

    private xyCollider as RectangleCollider
    private yzCollider as RectangleCollider

    ' Create a new BoxCollider3d
    '
    ' @param {string} colliderName - name of this collider
    ' @param [args={}] - additional properties (e.g {width: 10, height: 20, depth: 10})
    sub new (colliderName as string, args = {} as roAssociativeArray)
      super(colliderName, args)
      m.colliderType = "box3d"
      ' bs:disable-next-line: 1140
      m.append(args)
    end sub


    override sub setupCompositor(gameEngine as Game, entityName as string, entityId as string, entityPosition as BGE.Math.Vector)
      ' RectangleCollider's offset is its TOP edge (offset.y) with the bottom at
      ' offset.y - height (see TileCollision.bs's own doc comment on this same
      ' RectangleCollider convention) - convert from this collider's own center-based
      ' offset accordingly.
      m.xyCollider = new RectangleCollider(m.name + "__xyPlane", {
        width: m.width,
        height: m.height,
        offset: BGE.Math.VectorOps.create(m.offset.x - m.width / 2.0, m.offset.y + m.height / 2.0)
      })
      m.xyCollider.setupCompositor(gameEngine, entityName, entityId, entityPosition)

      m.yzCollider = new RectangleCollider(m.name + "__yzPlane", {
        width: m.height,
        height: m.depth,
        offset: BGE.Math.VectorOps.create(m.offset.y - m.height / 2.0, (m.offset.z ?? 0) + m.depth / 2.0),
        memberFlags: COLLIDER_3D_YZ_PLANE_FLAG,
        collidableFlags: COLLIDER_3D_YZ_PLANE_FLAG
      })
      m.yzCollider.setupCompositor(gameEngine, entityName, entityId, m.toYZPosition(entityPosition))
    end sub


    override function checkCollisions(entityPosition as BGE.Math.Vector) as object[]
      xyCandidates = m.xyCollider.checkCollisions(entityPosition)
      yzCandidates = m.yzCollider.checkCollisions(m.toYZPosition(entityPosition))

      yzKeys = {}
      for each candidate in yzCandidates
        yzKeys[candidate.entityId + ":" + m.stripPlaneSuffix(candidate.colliderName)] = true
      end for

      result = []
      for each candidate in xyCandidates
        baseName = m.stripPlaneSuffix(candidate.colliderName)
        key = candidate.entityId + ":" + baseName
        if yzKeys[key] = true
          result.push({entityId: candidate.entityId, objectName: candidate.objectName, colliderName: baseName})
        end if
      end for
      return result
    end function


    override function confirmCollision(myEntity as object, otherCollider as Collider, otherEntity as object) as boolean
      if otherCollider = invalid or otherCollider.colliderType <> "box3d"
        m.lastCollisionResult = new Box3dCollisionResult(false, BGE.Math.VectorOps.create(0, 1, 0), 0.0)
        return false
      end if
      otherBox = otherCollider as BoxCollider3d
      myGameEntity = myEntity as GameEntity
      otherGameEntity = otherEntity as GameEntity

      myCenter = BGE.Math.VectorOps.add(myGameEntity.position, m.offset)
      myHalf = BGE.Math.VectorOps.create(m.width / 2.0, m.height / 2.0, m.depth / 2.0)
      myMin = BGE.Math.VectorOps.subtract(myCenter, myHalf)
      myMax = BGE.Math.VectorOps.add(myCenter, myHalf)

      otherCenter = BGE.Math.VectorOps.add(otherGameEntity.position, otherBox.offset)
      otherHalf = BGE.Math.VectorOps.create(otherBox.width / 2.0, otherBox.height / 2.0, otherBox.depth / 2.0)
      otherMin = BGE.Math.VectorOps.subtract(otherCenter, otherHalf)
      otherMax = BGE.Math.VectorOps.add(otherCenter, otherHalf)

      m.lastCollisionResult = aabbOverlap(myMin, myMax, otherMin, otherMax)
      return m.lastCollisionResult.overlapping
    end function


    override sub disableCollisionChecking()
      m.xyCollider.disableCollisionChecking()
      m.yzCollider.disableCollisionChecking()
    end sub


    ' Game.adjustEntityCompositorObjectPostCollision() calls this directly on every
    ' collider, every frame - see SphereCollider3d's identical override for why this is
    ' required, not optional (the base Collider implementation touches m.compositorObject
    ' directly, which this class never sets on itself).
    override sub adjustCompositorObject(entityPosition as BGE.Math.Vector)
      m.xyCollider.adjustCompositorObject(entityPosition)
      m.yzCollider.adjustCompositorObject(m.toYZPosition(entityPosition))
    end sub


    private function toYZPosition(entityPosition as BGE.Math.Vector) as BGE.Math.Vector
      return BGE.Math.VectorOps.create(entityPosition.y, entityPosition.z ?? 0)
    end function


    private function stripPlaneSuffix(colliderName as string) as string
      if Right(colliderName, 9) = "__xyPlane" or Right(colliderName, 9) = "__yzPlane"
        return Left(colliderName, Len(colliderName) - 9)
      end if
      return colliderName
    end function

  end class
end namespace
```

- [ ] **Step 4: Add `GameEntity.addBoxCollider3d()`**

In `src/source/engine/GameEntity.bs`, add this import near the existing collider imports:

```brighterscript
import "colliders/BoxCollider3d.bs"
```

Then add this method right after `addSphereCollider3d` (added in Task 3):

```brighterscript
    ' Adds a box collider to this entity, for true 3D overlap detection - see
    ' BGE.BoxCollider3d. Note offset is the box's CENTER, unlike addRectangleCollider()'s
    ' corner-based offset.
    '
    ' @param {string} colliderName - Name of the collider (only one collider with the same name can be added)
    ' @param {float} width - width of the box (x axis)
    ' @param {float} height - height of the box (y axis)
    ' @param {float} depth - depth of the box (z axis)
    ' @param {float} [offset_x=0] - horizontal offset from entity position of the box's center
    ' @param {float} [offset_y=0] - vertical offset from entity position of the box's center
    ' @param {float} [offset_z=0] - depth offset from entity position of the box's center
    ' @param {boolean} [enabled=true] - is this collider enabled?
    ' @return {object}  - the collider that was added, or `invalid` if it could not be added
    function addBoxCollider3d(colliderName as string, width as float, height as float, depth as float, offset_x = 0 as float, offset_y = 0 as float, offset_z = 0 as float, enabled = true as boolean) as BoxCollider3d
      boxCollider = new BoxCollider3d(colliderName, {
        enabled: enabled,
        width: width,
        height: height,
        depth: depth,
        offset: BGE.Math.VectorOps.create(offset_x, offset_y, offset_z)
      })
      return m.addCollider(boxCollider) as BoxCollider3d
    end function
```

- [ ] **Step 5: Run the spec and verify it passes**

```bash
npm run build-tests && npm run test:ci 2>&1 | grep -B1 -A6 "BGE.BoxCollider3d"
```

Expected: all 4 `BoxCollider3dTests` cases pass (✔).

If the overlap/no-overlap assertions fail while the `new`/dimension-storage test passes, the most likely cause is the `offset.y - height`/`offset.y + height` sign convention this task assumed for `RectangleCollider` (see the comment in Step 3) being backwards for this codebase's actual `SetCollisionRectangle` behavior - swap the `+`/`-` in the `xyCollider`/`yzCollider` offset calculations in `setupCompositor()` and re-run.

- [ ] **Step 6: Validate and lint**

```bash
npm run validate && npm run lint
```

Expected: both exit 0.

- [ ] **Step 7: Commit**

```bash
git add src/source/engine/colliders/BoxCollider3d.bs src/source/engine/colliders/BoxCollider3d.spec.bs src/source/engine/GameEntity.bs
git commit -m "Add BoxCollider3d + GameEntity.addBoxCollider3d() (#131)

Two-plane roCompositor broad-phase is exact for AABB-vs-AABB (no false
positive case, unlike spheres) - confirmCollision() still runs
aabbOverlap() to compute the penetration/normal result for physics
response."
```

---

## Task 5: `examples/collisions3d` — bouncing spheres demo

**Files:**
- Create: `examples/collisions3d/` (scaffolded)
- Create: `examples/collisions3d/src/source/Entities/Sphere.bs`
- Create: `examples/collisions3d/src/source/Rooms/MainRoom.bs`
- Modify: `examples/collisions3d/src/source/main.bs`

**Interfaces:**
- Consumes: `BGE.GameEntity.addSphere/addSphereCollider3d` (Task 3), `BGE.SphereCollider3d.lastCollisionResult` (Task 3), `BGE.Camera3d`, `BGE.Math.VectorOps`.

- [ ] **Step 1: Scaffold the example**

```bash
npm run create-example -- collisions3d "3D Collisions"
```

Expected: creates `examples/collisions3d/` with manifest, `bsconfig.json`, generated icon/splash, a minimal `MainRoom`, and registers it in the root `.vscode/tasks.json` example picker.

- [ ] **Step 2: Point the new example at the local engine build**

```bash
cd examples/collisions3d && npm install
```

Expected: installs successfully, pulling in the just-built engine via ROPM (the repo's `prepare-examples` flow - see `CLAUDE.md`). Run `npm run build-engine` from the repo root first if this fails to find the engine package (`cd .. && npm run build`).

- [ ] **Step 3: Set the camera in `main.bs`**

Edit `examples/collisions3d/src/source/main.bs` (generated content is the template shown in `CLAUDE.md`'s `create-example` description - a `Main()` sub that constructs `BGE.Game`, `fitCanvasToScreen()`, defines/changes to `MainRoom`, calls `enableStandardDebugUi()` and `play()`). Add `game.setCamera(new BGE.Camera3d())` right after `game.fitCanvasToScreen()`:

```brighterscript
sub Main()
  game = new BGE.Game(1280, 720) ' This initializes the game engine
  game.fitCanvasToScreen()
  game.setCamera(new BGE.Camera3d())

  firstRoom = new MainRoom(game)
  game.defineRoom(firstRoom)
  game.changeRoom(firstRoom.name)

  game.enableStandardDebugUi({memory: false, garbageCollector: false, log: false})

  game.play()
end sub
```

- [ ] **Step 4: Write the `Sphere` entity**

Create `examples/collisions3d/src/source/Entities/Sphere.bs`:

```brighterscript
' A bouncing sphere: bounds off the walls of a fixed cube and reflects its velocity off
' the contact normal of any other Sphere it collides with in true 3D (see
' BGE.SphereCollider3d) - the worked example specs/2026-09-18-3d-collision-detection-design.md
' asks for.
class Sphere extends BGE.GameEntity

  radius = 20.0
  bound = 200.0

  sub new(game as BGE.Game)
    super(game)
    m.name = "Sphere"
  end sub

  override sub onCreate(args as roAssociativeArray)
    m.radius = args.radius
    m.position = args.position
    m.velocity = args.velocity
    m.bound = args.bound - m.radius
    m.addSphere("visual", m.radius, {color: args.color})
    m.addSphereCollider3d("body", m.radius)
  end sub

  override sub onUpdate(deltaTime as float)
    m.bounceOffWalls()
  end sub

  private sub bounceOffWalls()
    if (m.position.x > m.bound and m.velocity.x > 0) or (m.position.x < -m.bound and m.velocity.x < 0)
      m.velocity.x = -m.velocity.x
    end if
    if (m.position.y > m.bound and m.velocity.y > 0) or (m.position.y < -m.bound and m.velocity.y < 0)
      m.velocity.y = -m.velocity.y
    end if
    if (m.position.z > m.bound and m.velocity.z > 0) or (m.position.z < -m.bound and m.velocity.z < 0)
      m.velocity.z = -m.velocity.z
    end if
  end sub

  override sub onCollision(myCollider as BGE.Collider, otherCollider as BGE.Collider, otherEntity as BGE.GameEntity)
    if myCollider.colliderType = "sphere3d"
      sphereCollider = myCollider as BGE.SphereCollider3d
      result = sphereCollider.lastCollisionResult
      if result <> invalid and result.overlapping
        ' Reflect velocity off the contact normal, but only if still moving toward the
        ' other sphere - otherwise a pair resting in contact across several frames would
        ' flip velocity every single frame instead of separating.
        approaching = BGE.Math.VectorOps.dotProduct(m.velocity, result.normal)
        if approaching < 0.0
          m.velocity = BGE.Math.VectorOps.subtract(m.velocity, BGE.Math.VectorOps.scale(result.normal, 2.0 * approaching))
        end if
      end if
    end if
  end sub

end class
```

- [ ] **Step 5: Write `MainRoom`**

Replace `examples/collisions3d/src/source/Rooms/MainRoom.bs` with:

```brighterscript
class MainRoom extends BGE.Room

  bound = 200.0

  sub new(game as BGE.Game)
    super(game)
    m.name = "MainRoom"
  end sub

  override sub onCreate(args as roAssociativeArray)
    m.game.canvas.renderer.camera.position = BGE.Math.VectorOps.create(0, 250, -600)
    m.game.canvas.renderer.camera.setTarget(BGE.Math.VectorOps.create(0, 0, 0))

    colors = [BGE.Colors.Red, BGE.Colors.Green, BGE.Colors.Blue, BGE.Colors.Yellow, BGE.Colors.Cyan]
    positions = [
      BGE.Math.VectorOps.create(-100, 0, 0),
      BGE.Math.VectorOps.create(100, 50, -50),
      BGE.Math.VectorOps.create(0, -50, 100),
      BGE.Math.VectorOps.create(80, -30, -80),
      BGE.Math.VectorOps.create(-80, 60, 60)
    ]
    velocities = [
      BGE.Math.VectorOps.create(60, 40, 50),
      BGE.Math.VectorOps.create(-50, 55, -45),
      BGE.Math.VectorOps.create(45, -60, 55),
      BGE.Math.VectorOps.create(-55, -45, -50),
      BGE.Math.VectorOps.create(50, 50, -60)
    ]

    for i = 0 to 4
      m.game.addEntity(new Sphere(m.game), {
        radius: 25.0,
        position: positions[i],
        velocity: velocities[i],
        color: colors[i],
        bound: m.bound
      })
    end for
  end sub

  override sub onInput(input as BGE.GameInput)
    if input.press and input.isButton("back")
      m.game.End()
    end if
  end sub

end class
```

- [ ] **Step 6: Wire up the imports (`main.bs` needs to reference `Sphere`)**

Confirm `examples/collisions3d/bsconfig.json`'s default `rootDir`/glob (from the template) already picks up every `.bs` file under `src/source/` automatically - this is the case for every other example in this repo, so no explicit import list should be needed. Skip this step's edits if `npm run build` (next step) succeeds without a `cannot-find-name` diagnostic for `Sphere`.

- [ ] **Step 7: Build the example**

```bash
cd examples/collisions3d && npm run build
```

Expected: builds with no errors. If `Sphere`/`MainRoom` aren't found, check `bslint.json`/`bsconfig.json` for the source glob pattern used by other examples (e.g. `examples/pong/bsconfig.json`) and match it.

- [ ] **Step 8: Package and sideload to a real device**

```bash
cd examples/collisions3d && npm run package
cd ../.. && node node_modules/rokubot/dist/cli.js sideload ./examples/collisions3d/out/bge-collisions3d.zip --deleteDevChannel
node node_modules/rokubot/dist/cli.js launch dev
```

- [ ] **Step 9: Screenshot and visually verify on real hardware**

```bash
node node_modules/rokubot/dist/cli.js screenshot --scale 0.5
```

Read the resulting image. Expected: five colored spheres visible, moving and bouncing off each other and the (invisible) bounding cube walls - not passing through each other, not getting stuck together, not flying off to infinity. Per this repo's own rule (`CLAUDE.md`: "Automated Rooibos tests do not exercise example apps' own entity/room code at all"), this on-device check is mandatory, not optional polish - take a second screenshot a few seconds later (`node node_modules/rokubot/dist/cli.js screenshot --scale 0.5`) and confirm the spheres have visibly moved/bounced, not frozen.

If spheres visibly pass through each other: check `debugger-state` for a crash first; if the app is running fine but collisions aren't firing, the most likely culprit is `Sphere.onCreate`'s `addSphereCollider3d` radius not matching `addSphere`'s visual radius, or the `bound` value being too large for a collision to ever occur before Step 9's screenshot window.

- [ ] **Step 10: Commit**

```bash
git add examples/collisions3d .vscode/tasks.json
git commit -m "Add examples/collisions3d - bouncing spheres in true 3D (#131)

The 3D take on the Roku 'ux components/control/Collisions' sample the
issue asks for, and the on-device manual test bed for validating
SphereCollider3d - confirmed live on real hardware: spheres visibly
bounce off each other and the bounding walls without passing through or
sticking together."
```

---

## Task 6: Update `CLAUDE.md`'s Collision section

**Files:**
- Modify: `CLAUDE.md` (the "Collision (`engine/colliders/`)" section)

Per this repo's standing convention of updating `CLAUDE.md`/docs alongside significant engine changes, not as an afterthought.

- [ ] **Step 1: Add the new classes to the Collision section**

In `CLAUDE.md`, find the `### Collision (\`engine/colliders/\`)` section (currently just describes `Collider`/`CircleCollider`/`RectangleCollider` and `resolveAabbTileCollision`). Add a new paragraph after the existing content:

```markdown
- `SphereCollider3d`/`BoxCollider3d` (`addSphereCollider3d()`/`addBoxCollider3d()` on `GameEntity`) detect a true 3D overlap, not just an XY-space projection - each internally owns two ordinary 2D colliders (one on the entity's real XY plane, one on a synthetic YZ plane sharing the same `roCompositor`, segregated via a reserved `COLLIDER_3D_YZ_PLANE_FLAG` member/collidable flag bit) for a cheap native broad-phase, then confirms with a precise Vector-math check (`colliders/Collision3d.bs`'s `sphereOverlap()`/`aabbOverlap()`) before `onCollision()` fires - a plain two-plane compositor check alone produces false positives for spheres (a diagonal near-miss can pass both plane checks while never truly touching in 3D), though not for boxes (AABB-vs-AABB overlap decomposes exactly per axis, so the two-plane check alone is already exact there). `Collider` itself exposes this as three overridable hooks - `checkCollisions()`, `confirmCollision()`, `disableCollisionChecking()` - which `CircleCollider`/`RectangleCollider` don't need to override (their base implementations are exactly today's compositor-only behavior). See `specs/2026-09-18-3d-collision-detection-design.md` and `examples/collisions3d` for a runnable demo (bouncing spheres, reflecting velocity off each collision's contact normal).
```

- [ ] **Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "Document SphereCollider3d/BoxCollider3d in CLAUDE.md (#131)"
```

---

## Self-Review Notes

**Spec coverage:**
- Two-plane broad-phase + math narrow-phase confirm/resolve — Tasks 1, 3, 4. ✓
- `Collider` refactor (`checkCollisions`/`confirmCollision`, zero behavior change) — Task 1. ✓
- `Collision3d.bs` pure functions + `COLLIDER_3D_YZ_PLANE_FLAG` — Task 2. ✓
- `SphereCollider3d`/`BoxCollider3d`, `addSphereCollider3d`/`addBoxCollider3d` — Tasks 3, 4. ✓
- Example + on-device verification — Task 5. ✓
- Doc update — Task 6. ✓
- Out-of-scope items (static geometry, cross-shape checks, spatial partitioning beyond `roCompositor`) — deliberately have no task, matching the design doc.

**Type consistency:** `Sphere3dCollisionResult`/`Box3dCollisionResult` (Task 2) are used identically in Task 3/4's `confirmCollision()` and Task 5's `Sphere.onCollision()`. `checkCollisions()`'s `object[]` record shape (`{entityId, objectName, colliderName}`) is produced identically by the base `Collider` (Task 1) and both 3D colliders (Tasks 3, 4), and consumed identically by `Game.processEntityOnCollision` (Task 1).

**Known risk flagged in-task:** `BoxCollider3d`'s `RectangleCollider` offset-conversion sign (Task 4, Step 3) is based on `TileCollision.bs`'s documented real-world usage of `RectangleCollider`, not a directly-tested guarantee — Task 4 Step 5 includes an explicit fallback instruction if the overlap tests fail on the first attempt.
