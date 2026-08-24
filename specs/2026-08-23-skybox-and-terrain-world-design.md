---
title: Skybox rendering + terrain example showcase world
---

# Skybox rendering + terrain example showcase world

Implements issue #65 (skybox rendering) and issue #65's example-app follow-through: a new
`WorldRoom` in `examples/terrain` combining a tiled grass ground, a static park/lake map
decal, a skybox, and scattered trees, as the example's first room.

## 1. Skybox (issue #65)

### API

`DrawableSkybox` (`src/source/engine/drawables/DrawableSkybox.bs`) + `SceneObjectSkybox`
(`src/source/engine/renderer/sceneObjects/SceneObjectSkybox.bs`), following the existing
Drawable/SceneObject pairing (`DrawablePlane`/`SceneObjectPlane` is the closest analogue).
New `SceneObjectType.Skybox` enum member.

```
DrawableSkybox(owner as GameEntity, region as roRegion, args = {} as object)
```

- `region`: a cylindrical panorama texture (the night-sky image, 1024x512).
- `degreesPerFullWidth as float = 360`: how many degrees of yaw the texture's full width
  covers. Default wraps a full circle.
- `verticalDegreesCovered as float = 90`: how many degrees of pitch the texture's full
  height covers, centered on the horizon (texture's vertical center = pitch 0).

Only one `DrawableSkybox` is expected per room in practice, but nothing enforces that -
multiple draw in insertion order like any other `SceneObject` tie.

### Draw algorithm

`SceneObjectSkybox.performDraw()`:

1. Compute camera yaw (`atan2` of the level-forward vector's x/z) and pitch (angle of
   `orientation` above/below the level plane) from the camera's current orientation -
   both roll-independent (`Camera3d.getLevelUpVector()`/level-forward math, the same
   roll-invariant vectors `SceneObjectPlane` already uses for horizon math).
2. Map yaw to a horizontal texture offset (`yawFraction * textureWidth`, wrapping) and
   pitch to a vertical offset, then blit the visible texture slice(s) unrolled - one
   `DrawObject`/`DrawScaledObject`-class call, two only when the visible window straddles
   the texture's horizontal wrap seam.
3. **Roll**: mirrors `SceneObjectPlane`'s "render level, then rotate" trick
   (`specs/2026-08-19-camera-roll-and-plane-horizon-design.md` §D). Step 2's unrolled
   result is drawn into a scratch bitmap enlarged to the frame's diagonal (cleared first -
   `ScratchBitmapPool` hands out pooled, uncleared memory), the composited bitmap is
   rotated by `-rollDegrees` via the existing rotated-blit path, then cropped to the frame
   size before the final blit to canvas. This is one rotated-quad-class draw
   (~500/sec measured), not per-face like a cubemap, so it's affordable per frame.
4. Result is cached (like `SceneObjectPlane`'s `tempBitmap`) and only redrawn when yaw,
   pitch, or roll actually changed (reuses the camera's existing movement/roll
   dirty-checking).

`getPrimitiveCount()`/`participatesInOverlapDetection()`: opts out of overlap-cluster
candidacy entirely (always fully behind everything; no possible overlap-driven behavior
change).

### Hook into `Renderer.drawScene()`

A third earliest pass, before the existing plane pass:

```
for each sceneObj in m.sceneObjects
  if sceneObj.isEnabled() and sceneObj.type = SceneObjectType.Skybox
    sceneObj.draw(m)
  end if
end for
' existing plane pass, then existing sorted pass, unchanged
```

Skybox objects never enter the depth-sort array and are excluded from
`getClusterCandidates()`.

### Camera2d

No-op: `SceneObjectSkybox.isPotentiallyOnScreen()`/`findCanvasPosition()` return `false`
outright when `rendererObj.camera` isn't a `Camera3d`, so a `DrawableSkybox` added under a
2D room simply never draws. Filing a follow-up issue ("Support skybox as a Camera2d
parallax layer") rather than building it now - `DrawableParallaxLayer` is a different,
position-shift-based mechanism and isn't reusable for yaw/pitch cylindrical mapping.

### Background clear

`Game.bs`'s existing per-frame flat-color clear is left unconditional - it's a cheap
`DrawRect`-class op, and stays a correctness safety net for any frame where the skybox
doesn't fully cover the canvas (limited `verticalDegreesCovered`, or no skybox on that
entity at all).

### Testing

- Rooibos specs for `DrawableSkybox`/`SceneObjectSkybox`: yaw/pitch-to-UV mapping at known
  camera angles (including the wrap-seam case), roll rotate/crop math against known
  `rollDegrees` values, and dirty-check behavior (cached result reused when the camera
  hasn't moved).
- `examples/rendererTest` gets a `SkyboxTest` demo (`Tests/SkyboxTest.bs` +
  `DemoList.bs` entry) per issue #65's definition of done, to get the standard
  fps/frame-ms/draw-ms/draw-call reporting automatically and specifically measure the
  roll-enabled render-then-rotate cost.
- Documented in `docs/drawables-and-scene-objects.md`, in its own section next to the
  plane walkthrough (same family of trick).

## 2. Shared `FreeFlyCameraController`

New `examples/terrain/src/source/Entities/FreeFlyCameraController.bs` - a plain
BrighterScript class (not a `GameEntity`; a room constructs one and forwards its own
`onInput`/`onUpdate` calls to it), extracted from `MainRoom`'s existing turn/drive/roll/
pitch logic so `WorldRoom` doesn't duplicate ~80 lines of camera math, and both rooms get
the same fixes in one place.

```
FreeFlyCameraController(room as BGE.Room, otherRoomName as string, groundPlane as BGE.Math.Plane)
```

### Yaw/pitch relative to current orientation

Replaces the old world-frame `heading` (accumulated angle, always rotated around world
Y) + `downwardTilt` (orientation recomputed from scratch every frame) scheme with direct
incremental rotation of `camera.orientation`:

- Pitch: rotate `orientation` around `camera.getRightVector()` (already roll-aware) by
  `pitchDirection * pitchSpeed * dt`. A scalar `pitchAccum` is still tracked purely to
  preserve the existing `maxDownwardTilt` clamp (needed to avoid
  `Camera3d.getLevelUpVector()`'s forward-parallel-to-world-up degenerate case) - if
  applying the delta would push `pitchAccum` past the clamp, the delta is scaled back
  before being applied.
- Yaw: rotate `orientation` around `camera.getUpVector()` (also roll-aware; was
  world-up) by `input.x * dt * turnSpeed`. No accumulator or clamp needed - free
  rotation.
- Roll continues exactly as today (`camera.rollDegrees` incremented directly by
  `replay`/`options`).

This makes turning and pitching bank-relative (flight-sim-style) instead of always
world-vertical, matching how a rolled camera intuitively should respond.

### Ground clamp

After applying a drive-forward position update, clamp the camera above the ground plane:
if `dot(camera.position - groundPlane.point, groundPlane.normal)` drops below a small
minimum (`1.0` world unit), push `camera.position` back out along `groundPlane.normal` by
the shortfall. Takes the room's ground plane definition in its constructor so it isn't
hardcoded to world-up.

### Room switching replaces quit

`back` semantics change:

- press: resets hold-tracking (unchanged).
- release: **switches to `otherRoomName`** via `room.game.changeRoom(...)` (was quit).
- 2s+ hold: still toggles debug info (unchanged).
- Explicit quit is dropped - Roku's system back/home already exits the channel from the
  top level.

### Room wiring

- `WorldRoom`'s controller: `new FreeFlyCameraController(m, "MainRoom", groundPlaneDef)`.
- `MainRoom`'s controller: `new FreeFlyCameraController(m, "WorldRoom", groundPlaneDef)`.
- `MainRoom` is refactored onto this controller, dropping its own duplicated
  heading/downwardTilt/roll/pitch/back fields and methods; its `OK`-cycles-ground-overlay
  behavior stays room-local (unrelated to the controller).
- `main.bs` changes its initial `changeRoom` call to `"WorldRoom"`.

## 3. New `WorldRoom`

`examples/terrain/src/source/Rooms/WorldRoom.bs`, the first room shown
(`game.changeRoom("WorldRoom")` in `main.bs`, ahead of `MainRoom`).

### Ground (layered via `addDrawable()` order, same pattern as `MainRoom.cycleGroundOverlay()`)

1. `colorBasePlane`: flat green `PlaneFillMode.color` fallback (matches `MainRoom`'s base
   layer).
2. `grassOverlay`: `PlaneFillMode.tiledImage` using `sprites/grass.png` (from
   `grass-set-00/grass09.png`, CC0/no attribution required per OpenGameArt - a short
   courtesy credit comment is added where it's loaded anyway).
3. `mapOverlay`: `PlaneFillMode.staticImage` using `sprites/worldMap.png` (from the
   supplied `Map.png`, 1024x1024) - a top-down park/lake/bridge decal, replacing the
   Mario Kart crop `MainRoom` uses for its own demo (unaffected).

The ground plane's `point` stays `{0,0,0}`, so the map decal's 1024x1024 footprint maps
1:1 to world units `x,z` in `[-512, 512]` (confirmed via
`BGE.Math.worldPointToTexturePixel`'s 1-world-unit-per-pixel, center-anchored mapping).

### Skybox

One `DrawableSkybox` using `sprites/skybox_night.jpg` (1024x512 night-sky panorama,
supplied), added via `addDrawable()`.

### Trees

Five cropped sprites (`sprites/tree1.png` .. `tree5.png`, from the supplied
`Sprite_01.png`..`Sprite_05.png`) - each is the same tree render at a different angle,
originally on a transparent background with a baked-in soft directional drop-shadow
blob. The shadow is stripped in preprocessing (see Assets below); each cropped sprite's
per-image anchor (the trunk-base pixel, so `offset` places the trunk's foot rather than
the sprite's center) is:

| sprite | anchor (x, y, normalized) |
|---|---|
| tree1 | (0.641, 0.907) |
| tree2 | (0.623, 0.902) |
| tree3 | (0.623, 0.896) |
| tree4 | (0.624, 0.886) |
| tree5 | (0.653, 0.893) |

Each tree is a plain `BGE.Image` drawable added directly to `WorldRoom` (not a separate
`GameEntity` - they're static, no per-tree update/collision needed, matching how the
ground planes are just drawables on the room itself). World size is set explicitly via
constructor args (`width`/`height`) rather than native pixel size - height fixed at `180`
world units, width scaled to preserve each source image's aspect ratio - and
`drawMode: directToCamera` so they billboard to always face the camera. `offset` is set
to `(x, 0, z)` per placement (ground-level y, since the anchor already accounts for the
trunk-to-sprite-top height).

**Placement** (per your direction: sparse on the map, dense in the surrounding forest,
fixed/deterministic, not runtime-random) - generated once from `worldMap.png`'s actual
pixel content (sampled on a 32x32-world-unit grid, classified grass vs.
water/path/shore, keeping only cells whose full 3x3 neighborhood is grass) and a
deterministic scatter outside the map's footprint:

- **14 on-map trees**, hand-selected from the classified grass cells (never on water,
  shore, path, or bridge), spread around the map's grassy perimeter (the lake occupies
  most of the map's interior) with a minimum 150-unit spacing:
  `(-272,-144) (272,80) (464,272) (-432,-400) (-368,144) (176,-400) (304,304) (-16,-432)
  (400,-112) (-400,304) (464,432) (176,464) (432,80) (-464,-16)`
- **55 forest-ring trees**, scattered outside the map's `[-512,512]` square footprint out
  to radius 800 (comfortably under `Camera3d.maxDrawDistance`'s device-capped range),
  minimum 70-unit spacing, deterministically generated (fixed-seed scatter, not
  `rnd()` at runtime) - full coordinate list lives in the implementation
  (`TreePlacements.bs`), not reproduced here.
- Each placement also gets a deterministic sprite index (1-5) and yaw rotation, varied
  per point (not identical trees repeated), from the same generation pass.

Both lists (and the generation approach) live in a small data file,
`examples/terrain/src/source/Rooms/TreePlacements.bs`, returning an array of
`{x, z, spriteIndex, rotationDegrees}` - `WorldRoom.onCreate()` iterates it once,
constructing one `Image` drawable per entry.

### Navigation

`FreeFlyCameraController` wired as described in section 2 - `back` switches between
`WorldRoom` and `MainRoom`. Onscreen hint text (matching `MainRoom.onDrawEnd`'s existing
convention) documents the controls in both rooms, including "Back: switch room" and
"Hold Back 2s: toggle debug info".

## 4. Assets

| file | source | notes |
|---|---|---|
| `examples/terrain/src/sprites/grass.png` | `~/Downloads/grass-set-00/grass09.png` | CC0 (OpenGameArt, author `athile`), no attribution required |
| `examples/terrain/src/sprites/worldMap.png` | `~/Downloads/Map.png` | supplied |
| `examples/terrain/src/sprites/skybox_night.jpg` | supplied (1024x512) | |
| `examples/terrain/src/sprites/tree1.png` .. `tree5.png` | `~/Downloads/_01/Sprite_01.png` .. `Sprite_05.png` | shadow-stripped (see below) |

**Shadow removal**: each source tree sprite has a soft, low-alpha, near-neutral-gray
drop shadow distinct from the tree's saturated bark/leaf colors even at its edges
(sampled: shadow core `rgba(8,8,8,0.31)` vs. trunk `rgba(123,121,90,1.0)` vs. leaf
`rgba(148,170,82,0.86)`). Stripped via an alpha-channel expression that zeroes alpha for
near-neutral, dark, already-partially-transparent pixels
(`abs(r-g)<0.06 && abs(g-b)<0.06 && abs(r-b)<0.06 && r<0.3`), leaving tree pixels
untouched. Verified visually and by direct pixel sampling on all 5 sprites.

## 5. Docs

- `docs/drawables-and-scene-objects.md`: new Skybox section next to the plane walkthrough.
- `CLAUDE.md`: Renderer/SceneObjects section gets the new pass and `SceneObjectType`
  mentioned, matching existing density; terrain example description updated to mention
  `WorldRoom` as the entry point.

## Non-goals

- Cubemap/skysphere skybox modes (issue #65 lists them; cylindrical panorama is
  sufficient here).
- Camera2d skybox support (follow-up issue).
- Runtime-random tree placement, or a general "scatter drawables by sampling a texture"
  engine utility - this is a one-off, hand-tuned placement for this room, not a new
  engine feature.
- An in-app quit control (dropped per section 2; Roku's system back already exits the
  channel).
