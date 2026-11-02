---
title: Third-Person Cameras
group: Guides
order: 11
---

# Third-Person Cameras

A third-person game usually wants three things from its camera: it follows the player from
behind and above, the right stick swings it round the player, and it doesn't end up inside a
wall. The engine has a piece for each:

- `BGE.OrbitCamera` moves a `Camera3d` round a target entity.
- `BGE.CameraBoom` pulls the camera in front of anything between it and the target.
- `BGE.Math.cameraRelativeMove()` turns the move stick into a direction on the ground, relative
  to the camera, so pushing up always runs away from the camera.

`examples/thirdPerson` uses all three.

## Setting up an orbit camera

Create it once the player exists, and update it in the scene's `onPostUpdate()`, after
everything has moved. Otherwise the camera is a frame behind the player and jitters.

```brighterscript
override sub onCreate(args as roAssociativeArray)
  m.player = new Player(m.game)
  m.game.addEntity(m.player)

  camera = m.game.canvas.renderer.camera as BGE.Camera3d
  m.orbit = new BGE.OrbitCamera(camera, m.player, {
    distance: 128,  ' behind the player, on the ground
    height: 56,     ' camera height above the player's feet
    lookHeight: 40  ' it looks at this point above the player's feet
  })
end sub

override sub onUpdate(dt as float)
  if m.game.controls.isActionPressed("recenter")
    m.orbit.recenter()
  end if
end sub

override sub onPostUpdate(dt as float)
  m.orbit.update(dt, m.game.controls.getRawAxis("look"))
end sub
```

The camera starts behind the target, which is whichever way its `rotation.y` faces (heading 0
faces -z). `update()` takes a look vector, each axis -1 to 1: x orbits the camera round the
target and y tilts it up or down. It doesn't have to come from a stick, so a game on a Roku
remote can build one from buttons.

The camera swings round the look-at point on a sphere, so the target stays framed as it tilts.
`minTilt`/`maxTilt` limit the tilt (radians either side of the resting angle; positive looks
down), and the camera never goes lower than `minHeight` above the target's feet.

The camera does not drift back behind a moving target on its own. With camera-relative
movement, a drifting camera would turn every run into a curve. `recenter()` swings it back
behind the target and levels the tilt instead. Any look input cancels a recenter.

Every option is also a public field, so you can change them while the game runs, e.g. pull the
camera in for a cutscene. The defaults (all in world units) suit a world of about 32 units per
metre: 4 m back, 1.75 m up, looking at 1.25 m.

| Field | Default | |
| --- | --- | --- |
| `distance` | 128 | Distance behind the target, on the ground, at rest |
| `height` | 56 | Camera height above the target's position at rest |
| `lookHeight` | 40 | Height of the look-at point above the target's position |
| `minHeight` | 10 | The camera never goes lower than this above the target |
| `orbitSpeed` / `tiltSpeed` | 2.6 / 1.6 | Radians per second at full look |
| `recenterSpeed` | 8 | Radians per second while recentering |
| `minTilt` / `maxTilt` | -0.4 / 0.4 | Tilt limits, radians |
| `heading` | target's `rotation.y` | The heading the camera looks along |
| `boom` | `invalid` | A `BGE.CameraBoom` (see below) |

## Keeping the camera out of walls

Give the orbit camera a `BGE.CameraBoom`. Each frame, the boom casts rays from the look-at
point to where the camera wants to be and moves it in front of the first thing they hit. It
pulls in at once and eases back out once the way is clear.

```brighterscript
const CAMERA_BLOCKER = 2

m.orbit = new BGE.OrbitCamera(camera, m.player, {
  boom: new BGE.CameraBoom(m.game, {
    probeRadius: 10,   ' how thick the camera is
    minDistance: 25,   ' never closer to the look-at point than this
    collidableFlags: CAMERA_BLOCKER
  })
})
```

Only 3D colliders (`BoxCollider3d`, `SphereCollider3d`) block the camera. Put walls and
buildings on their own `memberFlags` bit and set the boom's `collidableFlags` to it, so the
characters' own colliders don't pull the camera in:

```brighterscript
wall.isStatic = true
collider = wall.addBoxCollider3d("body", 200, 300, 40)
collider.memberFlags = CAMERA_BLOCKER
```

You can also use a boom without an orbit camera: `camera.position = boom.update(lookAt,
wantedPosition, dt)`. Call `boom.reset()` after a cut so the camera snaps instead of easing out.
`boom.isClose()` is true within `closeDistance` of the look-at point, e.g. to fade out a player
the camera is pushed right up against.

## Camera-relative movement

With an orbit camera, pushing the stick up should run away from the camera, whichever way it
faces. `BGE.Math.cameraRelativeMove()` turns the stick into that direction on the ground:

```brighterscript
override sub onUpdate(dt as float)
  move = BGE.Math.cameraRelativeMove(m.game.controls.getAxis("move"), m.orbit.heading)
  if BGE.Math.VectorOps.length(move) > 0.1
    m.rotation.y = BGE.Math.turnToward(m.rotation.y, BGE.Math.headingOf(move), m.turnSpeed * dt)
    m.position = BGE.Math.VectorOps.add(m.position, BGE.Math.VectorOps.scale(move, m.runSpeed * dt))
  end if
end sub
```

The result has y = 0. Its length follows the stick, up to 1, so a stick pushed halfway gives a
half-speed walk, and a diagonal isn't faster than straight ahead.
