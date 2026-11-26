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

### Locking on

`lockOn(entity)` turns the camera to look past the target at another entity, e.g. the enemy
the player has locked onto, and keeps it there as either moves. Look input is ignored while
locked, so the look stick is free for switching targets, and the tilt eases to `lockTilt`;
a positive one looks down on the ground between them, which makes the distance easier to judge. `releaseLock()` lets go, leaving the
camera where it is; it also lets go by itself when the entity is invalidated.

```brighterscript
if m.game.controls.isActionPressed("lockOn")
  if m.orbit.isLocked()
    m.orbit.releaseLock()
  else
    ' m.livingEnemies() is the game's own filter
    target = BGE.Targeting.pickInView(m.livingEnemies(), m.player.position, m.orbit.heading, 480, BGE.Math.PI * 0.4)
    if invalid <> target
      m.orbit.lockOn(target)
    else
      m.orbit.recenter()
    end if
  end if
end if
```

`BGE.Targeting` (see [Picking targets](/game-engine-overview)) chooses what's roughly where the
camera looks, and `nextByBearing()` the next one left or right for a stick flick. Dropping the
target when it dies or gets away is up to the game.

By default the camera turns to keep the locked entity right behind the target, so every step
either takes turns the whole view, and a turning camera redraws the whole frame. Give it a
`lockDeadZone` to let the entity wander round the middle of the screen instead: with
`lockDeadZone: 0.2` the camera holds still while the entity is in the middle 20% of the screen's
width (the player keeps facing it themselves), and only turns once it drifts out, until it's back
within half of that. A locked entity that gets round between the camera and the player turns it
too, wherever it shows. `lockEase` makes the turn an exponential ease (each frame it turns
`1 - e^(-lockEase * dt)` of the angle left), quick when the entity is far off and slowing as it
nears the middle, still capped at `lockTurnSpeed`. The zone is worked out across the ground from
the camera, so with the camera tilted well down it's only roughly the on-screen fraction:

```brighterscript
m.orbit = new BGE.OrbitCamera(camera, m.player, {
  lockDeadZone: 0.2, ' the middle 20% of the screen
  lockEase: 4        ' quick at first, slowing near the middle
})
```

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
| `lockTurnSpeed` | 6 | Radians per second while turning toward a `lockOn()` entity |
| `lockTilt` | 0 | Tilt while locked on, radians (within `minTilt`/`maxTilt`) |
| `lockDeadZone` | 0 | Middle fraction of the screen width a locked-on entity can move in without the camera turning |
| `lockEase` | 0 | Locked on, ease the turn: each frame turns `1 - e^(-lockEase * dt)` of the angle left (up to `lockTurnSpeed`); 0 turns at `lockTurnSpeed` |
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

Only 3D colliders (`BoxCollider3d`, `SphereCollider3d`) block the camera. See [3D Colliders and Raycasts](/colliders-3d#flags) for how their flags apply to raycasts. Put walls and
buildings on their own `memberFlags` bit and set the boom's `collidableFlags` to it, so the
characters' own colliders don't pull the camera in:

```brighterscript
wall.isStatic = true
collider = wall.addBoxCollider3d("body", 200, 300, 40)
collider.memberFlags = CAMERA_BLOCKER
```

A box collider is axis-aligned unless you turn it: `collider.yaw` (radians) turns it about the
y axis through its centre, the same way `rotation.y` turns a model, so a building at any angle
gets a blocker that fits. Set it before the first frame, or call `collider.markChanged()` after
changing it on a static entity.

You can also use a boom without an orbit camera: `camera.position = boom.update(lookAt,
wantedPosition, dt)`. Call `boom.reset()` after a cut so the camera snaps instead of easing out.
`boom.isClose()` is true within `closeDistance` of the look-at point, e.g. to fade out a player
the camera is pushed right up against.

### Walls on a grid

For walls built from a `BGE.GridWallsMap`, use a `BGE.GridWallsCameraBoom`.
Instead of casting rays at colliders, it walks the line to the camera in
`stepLength` steps and stops a step short of the first one where the camera's
probe square touches a solid cell. The walls need no colliders, so they cost
nothing to check each frame.

```brighterscript
map = new BGE.GridWallsMap(rows, {cellSize: 192, wallHeight: 128, origin: corner, solid: {"#": "stone"}})
m.orbit = new BGE.OrbitCamera(camera, m.player, {
  boom: new BGE.GridWallsCameraBoom(m.game, map, {
    probeRadius: 10,
    minDistance: 25,
    stepLength: 6      ' keep it well under the cell size
  })
})
```

It takes the same fields as `BGE.CameraBoom`. Override `isBlockedAt(x, z)` to
block on something besides the map's solid cells.

## Chase cameras for vehicles

`BGE.OrbitCamera` stays level and waits for the player to swing it. A plane, spaceship or boat
wants the opposite: a camera that trails behind along its heading and pitch and rolls with its
bank. `BGE.ChaseCamera` does that, eased so turns swing the view round instead of snapping it.
It has no look input; you pass the target's attitude to `update()` each frame.

```brighterscript
override sub onCreate(args as roAssociativeArray)
  m.plane = new Plane(m.game)
  m.game.addEntity(m.plane)
  camera = m.game.canvas.renderer.camera as BGE.Camera3d
  m.chase = new BGE.ChaseCamera(camera, m.plane, {
    heading: m.plane.heading, ' where it starts; defaults to the plane's rotation.y
    distance: 85,
    height: 18,
    terrain: m.terrain ' optional: keeps the camera above a DrawableVoxelTerrain
  })
end sub

override sub onPostUpdate(dt as float)
  m.chase.update(dt, m.plane.heading, m.plane.pitch, m.plane.bank)
end sub
```

The heading uses the engine's convention (0 faces -z, increasing turns clockwise seen from
above); negate it if your vehicle turns the other way. Bank becomes the camera's `rollDegrees`.
Like `OrbitCamera`, it places the camera as soon as it's created. Call `snapBehind(heading)`
after a respawn or a cut to place it again without easing.

`distance` and `height` don't mean quite what they do on an `OrbitCamera`: `distance` is
measured along the camera's pitch, so the camera climbs and dives with the target, and
`height` is added straight up on top of that.
`examples/flightSim` uses one.

| Field | Default | |
| --- | --- | --- |
| `distance` | 85 | Distance behind the target, along its eased heading and pitch |
| `height` | 18 | Raised this far above that point |
| `lookDown` | 0.12 | Radians the camera looks below its own pitch, so the target sits low on screen |
| `followRate` | 4 | How quickly heading and pitch catch up, 1/seconds |
| `rollRate` | 5 | How quickly roll catches up, 1/seconds |
| `pitchFollow` | 0.8 | Fraction of the target's pitch the camera takes up |
| `maxPitch` | 0.436 (25°) | Camera pitch limit, radians |
| `rollFollow` | 0.8 | Fraction of the bank the camera rolls by; under 1 keeps the target looking banked |
| `terrain` | `invalid` | A `BGE.DrawableVoxelTerrain` to stay above |
| `groundClearance` | 8 | Height kept above `terrain` |
| `heading` | target's `rotation.y` | The heading the camera starts behind |

## Switching cameras

`OrbitCamera` and `ChaseCamera` are both a `BGE.FollowCamera`, so a scene can keep its camera
in a field of that type and swap one rig for the other, e.g. when the player climbs into a
plane, without touching the rest of its code:

- `follow(dt, input)` moves the camera for the frame. `input` is a `BGE.FollowCameraInput`, and
  each rig reads only the fields it uses: `look` for an orbit camera, `heading`, `pitch` and
  `bank` for a chase camera. Fill in all of them and either rig works.
- `snapBehind(heading)` puts the camera straight behind the target, no easing.
- `getLookAt()` is the point on the target the camera is framed round.
- `camera`, `target` and `heading` are public fields on both.

```brighterscript
m.rig = new BGE.OrbitCamera(camera, m.player) as BGE.FollowCamera

' later, e.g. on boarding the plane: start the new rig where the old one was looking
m.rig = new BGE.ChaseCamera(camera, m.plane, {heading: m.rig.heading}) as BGE.FollowCamera

override sub onPostUpdate(dt as float)
  m.rig.follow(dt, {
    look: m.game.controls.getRawAxis("look"),
    heading: m.plane.heading,
    pitch: m.plane.pitch,
    bank: m.plane.bank
  })
end sub
```

The rig-specific methods (`OrbitCamera.recenter()`/`lockOn()`, the typed `update()` calls)
still need the concrete class: cast back, or keep a second field typed as it. Any other class
with the same fields and methods counts as a `FollowCamera` too.

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

## Zooming

`camera.zoom` (or `camera.zoomTo(target, seconds)`, see
[Building a Game with BGE](/game-engine-overview#zooming)) works on a `Camera3d` like a zoom
lens: it multiplies the focal length, so zoom 2 shows the middle of the view twice as big, with
real perspective. `fieldOfViewDegrees` stays the field of view at zoom 1;
`getEffectiveFieldOfViewDegrees()` is the narrower one in use, `2 * atan(tan(fov / 2) / zoom)`.
The frustum, culling, `getFocalLength()`, `pixelsPerWorldUnitAt()`, the skybox, the ground,
models, impostors, fog and particles sized in world units all follow it.

Some things deliberately don't change:

- The draw distance. A zoomed-in camera stops drawing at the same distance, so zooming at
  something past the fog won't show it. Raise `maxDrawDistance` for a scene that needs it.
- `directToCamera` billboards and particles that aren't `sizeInWorldUnits` stay their size in
  pixels.
- Models are cut at `getNearDepth()` (focal length / 64), which moves out as you zoom in, so the
  zoomed view loses things very close to the camera first.

An `OrbitCamera`'s lock-on dead zone is a fraction of the screen, so it tightens in world terms
as you zoom in. `examples/collisions3d` zooms on Replay, and `examples/thirdPerson` takes a
`zoom=<n>` deep link.
