---
title: 3D Colliders and Raycasts
group: Guides
order: 19
---

# 3D Colliders and Raycasts

`BGE.SphereCollider3d` and `BGE.BoxCollider3d` detect real 3D overlap. Two spheres
only count as touching when they touch in 3D, not when their shadows on the screen
plane overlap. `game.raycast()` and `game.raycastAll()` use the same shapes, so a line
of sight check, a hitscan shot or a camera pull sees what gameplay collides with.

`examples/collisions3d` is the runnable reference. Five spheres bounce inside a box
built from six `BoxCollider3d` walls. Press OK to add a sphere, and Options to draw the
colliders.

This guide assumes you know the basics of 2D colliders and `onCollision()`. See
[Building a Game with BGE](/game-engine-overview#colliders-and-collisions) first.

## Adding colliders

Add 3D colliders in `onCreate()`, as you would a 2D one:

```brighterscript
class Sphere extends BGE.GameEntity

  radius = 20.0

  sub new(game as BGE.Game)
    super(game)
    m.name = "Sphere"
  end sub

  override sub onCreate(args as roAssociativeArray)
    m.radius = args.radius
    m.position = args.position
    m.velocity = args.velocity
    m.addSphere("visual", m.radius, {color: args.color})
    m.addSphereCollider3d("body", m.radius)
  end sub

end class
```

The two helpers take the same kind of arguments as their 2D versions:

- `addSphereCollider3d(colliderName, radius, [offset_x], [offset_y], [offset_z], [enabled])`
  The offset is the centre of the sphere, relative to the entity's position.
- `addBoxCollider3d(colliderName, width, height, depth, [offset_x], [offset_y], [offset_z], [enabled])`
  `width` runs along x, `height` along y and `depth` along z. These are full sizes,
  not half-sizes. The offset is the centre of the box. This differs from
  `addRectangleCollider()`, whose offset is the top-left corner.

A box is axis-aligned unless you turn it. Set `collider.yaw` (radians) to turn it about
the y axis through its centre. Entity `rotation` doesn't turn colliders. A sphere has no
yaw to set.

Walls and other things that don't move should be `isStatic`. A static entity never
checks for collisions itself. Anything that moves into it finds it from its own side.
This keeps a level full of walls from testing them against each other every frame.
The moving entity gets the `onCollision()` call. The static entity's own callbacks
never fire.

```brighterscript
class Wall extends BGE.GameEntity

  sub new(game as BGE.Game)
    super(game)
    m.name = "Wall"
  end sub

  override sub onCreate(args as roAssociativeArray)
    m.isStatic = true
    m.position = args.center
    m.addBoxCollider3d("body", args.width, args.height, args.depth)
  end sub

end class
```

If you change a static entity's collider after it's in the scene, for example by
resizing it or moving it, call `collider.markChanged()`. A moving entity picks up
changes to `radius`, `width`, `height`, `depth`, `offset` and `enabled` every frame.

## How collisions are found

Each 3D collider is two 2D colliders on the engine's shared `roCompositor`:

- an XY collider on the entity's real (x, y) position, the same plane every 2D collider
  uses
- a YZ collider on a made-up (y, z) position

The YZ collider carries the reserved `BGE.COLLIDER_3D_YZ_PLANE_FLAG` bit (`&h40000000`)
as both its member and collidable flag. So a YZ collider only matches other YZ
colliders. Without that bit, the numbers could line up by accident, and a YZ collider
would match an ordinary 2D collider at the same (x, y).

Each frame, the engine asks the compositor for hits. A pair is a candidate only when it
overlaps on both planes. That first pass is the broad phase. It's cheap, but it isn't
exact. Two spheres can pass both plane checks and still miss each other in 3D, when they
pass each other diagonally.

So the candidate then goes through `confirmCollision()`, which runs an exact test:

- sphere against sphere
- sphere against box (axis-aligned or turned)
- box against box

Only a confirmed overlap calls `onCollision()`. `onCollisionEnter()` and
`onCollisionExit()` work for 3D colliders too.

The two planes are internal. Their names (`<name>__xyPlane` and `<name>__yzPlane`)
never reach `onCollision()`. Your code only sees the collider you added.

A 3D collider only reports overlaps with other 3D colliders. A 2D collider never
reports one with a 3D collider.

## Reading the hit

In `onCollision()`, `lastCollisionResult` holds the most recent exact test for that
collider. Read it there, because the next frame overwrites it. Its `normal` points away
from the other entity, toward this one. `penetrationDepth` is how far the two shapes
overlap along that normal.

The bounce in `examples/collisions3d` uses it like this:

```brighterscript
override sub onCollision(myCollider as BGE.Collider, otherCollider as BGE.Collider, otherEntity as BGE.GameEntity)
  if myCollider.colliderType = "sphere3d"
    sphereCollider = myCollider as BGE.SphereCollider3d
    result = sphereCollider.lastCollisionResult
    if result <> invalid and result.overlapping
      ' Only reflect while still approaching, or a resting pair would flip every frame.
      approaching = BGE.Math.VectorOps.dotProduct(m.velocity, result.normal)
      if approaching < 0.0
        m.velocity = BGE.Math.VectorOps.subtract(m.velocity, BGE.Math.VectorOps.scale(result.normal, 2.0 * approaching))
      end if
    end if
  end if
end sub
```

A box collider has the same field, typed as `Box3dCollisionResult`. Check
`myCollider.colliderType = "box3d"` first, as this snippet does for spheres.

## Flags

`memberFlags` and `collidableFlags` work as they do for 2D colliders, with one
difference between collisions and raycasts.

For collisions, a 3D collider's own flags don't decide what it collides with. Its two
internal planes keep their own flags: the XY plane uses the default, and the YZ plane
uses the reserved bit. So any two overlapping 3D colliders collide. Setting
`memberFlags` on a 3D collider changes what raycasts and the camera see, not what the
collider touches. If you need flags to filter collisions, use a 2D collider.

Raycasts do use each collider's own `memberFlags`. Choose bits for your groups as you
would for 2D colliders. Don't use `BGE.COLLIDER_3D_YZ_PLANE_FLAG` for your own groups.

```brighterscript
const WALL_FLAG = 2
const ENEMY_FLAG = 4

wall.isStatic = true
collider = wall.addBoxCollider3d("body", 200, 300, 40)
collider.memberFlags = WALL_FLAG
```

## Raycasts

`game.raycast()` returns the nearest hit, or `invalid` if the ray hits nothing:

```brighterscript
' origin and direction are BGE.Math.Vector. The direction doesn't need to be normalised.
hit = m.game.raycast(origin, direction, 500.0, ENEMY_FLAG)
if invalid <> hit
  print "hit "; hit.entity.name; " at distance "; hit.distance
  print "point "; hit.point.x; ","; hit.point.y; ","; hit.point.z
end if
```

- `maxDistance` (default `10000.0`) is how far the ray is tested.
- `collidableFlags` (default `&hFFFFFFFF`) keeps only colliders whose `memberFlags`
  overlap the mask. The default tests every collider.

A `BGE.RaycastHit` has `entity`, `collider`, `point`, `distance` and `normal`. The
distance is in world units from the origin. If the origin is already inside a
collider, the hit is at distance 0.

`game.raycastAll()` takes the same arguments. It returns every hit, nearest first, or
an empty array.

A line of sight check is a ray with a distance and a wall mask:

```brighterscript
' True if nothing on WALL_FLAG stands between "from" and "target"
function canSee(game as BGE.Game, from as BGE.Math.Vector, target as BGE.Math.Vector) as boolean
  toTarget = BGE.Math.VectorOps.subtract(target, from)
  hit = game.raycast(from, toTarget, BGE.Math.VectorOps.length(toTarget), WALL_FLAG)
  if invalid = hit
    return true
  end if
  return false
end function
```

Raycasts read each entity's current position and the collider's current geometry. They
don't go through the compositor, so they never lag a frame behind, and they don't need
`markChanged()`. Disabled entities and colliders are skipped.

Each `raycast()` walks every entity. To cast many rays in one frame, get the colliders
once with `game.getColliders(flags)`, or `game.getCollidersInBox(area, flags)` for a
region. Then test each ray with `Collider.raycastCheck()`. That method takes a unit
direction and returns the hit without its `entity` or `collider` filled in, so you
set those yourself if you need them.

The camera uses raycasts too. A `BGE.CameraBoom` casts rays from the look-at point to
the camera, and pulls in at the first hit. See
[Third-Person Cameras](/third-person-cameras#keeping-the-camera-out-of-walls).

## Limits

- Only `BoxCollider3d` turns, and only about the y axis.
- A 3D collider is two compositor sprites rather than one.
- `game.debugDrawColliders(true)` draws every collider, 3D ones included, so you can check
  where they sit. See
  [Building a Game with BGE](/game-engine-overview#colliders-and-collisions).
- For the design behind the two-plane broad phase, see
  `specs/2026-09-18-3d-collision-detection-design.md` and
  `specs/2026-09-21-raycasting-design.md` in the repository. The raycasting spec predates
  `BoxCollider3d.yaw`.
- For the wider picture of how colliders reach the compositor, see
  [Engine Internals](/engine-internals#colliders-never-go-through-the-camera).
