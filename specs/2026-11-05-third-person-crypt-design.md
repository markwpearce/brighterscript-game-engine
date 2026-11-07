# thirdPerson: the crypt scene

## Intent

`examples/thirdPerson` is becoming a souls-like with a real map. The map is split into
separate scenes, so only one place's textures and models are in memory at a time:
walled town, forest, graveyard and crypt/dungeon. You move between them on foot through
a gate, a doorway or a gap in a fence, and the next scene loads with you just inside the
matching entrance. Invisible walls keep you inside each map. `FieldScene` stays as it is,
as the arena for testing monsters, combat and performance.

The crypt comes first because it is the riskiest technically: an enclosed maze of
oriented walls, seen from a chase camera, on a Roku. Mark will play it on a device and
give feedback before the other scenes are designed.

Reference mood: a Dark Souls catacomb. A flagstone floor, heavy stone walls, torches in
skull-lined alcoves throwing warm pools of light, darkness everywhere else, an arched
doorway at the end of a corridor with a pale glow beyond it.

## Goals

- A new `CryptScene` in `examples/thirdPerson`: a walkable stone maze, lit only by
  torches, that runs at a playable frame rate on a real device.
- Walls the knight can't walk through, and the chase camera can't see through.
- Enough props that it reads as a crypt, not a grey grid.
- A way out (a doorway) that changes scene.

## Non-goals (for now)

- Monsters and NPCs in the crypt. They come later; nothing spawns here.
- The other three scenes, and the graveyard entrance to the crypt.
- Carrying health/stamina across scenes, a save system, checkpoints.
- A ceiling. The darkness above the walls is the ceiling.
- Engine changes, unless measurement shows the scene can't hit its frame rate without one.
  If it can't, stop and report rather than silently widening scope.

## Anti-goals

- A maze that's cramped for the chase camera: if the camera boom is pulled in most of the
  time, the corridors are too narrow.
- Walls that flicker, pop or sort wrongly against the knight.
- Lights that blink or relight every frame (no flicker, no moving lights; see `Torch`).
- Bright or flat lighting: it should be dark between torches.

## Constraints

- Everything in `CLAUDE.md`, especially the renderer gotchas (draw queue limits, HD texture
  memory, scratch bitmaps) and the render-quality rules.
- World scale is `World.UNITS_PER_METRE` (32). Chase camera is 4 m behind, 1.8 m up.
- All art is made by us (procedural scripts under `examples/thirdPerson/tools/`, like
  `night-sky.py`), so nothing new goes in `CREDITS.md`. PNGs only.
- Keep texture memory modest: HD devices have 64 MB in all, and the four character
  atlases already use about 27 MB. Only the knight's atlas is needed in the crypt.
- Example code isn't covered by `npm run check`; it must be run on a device or the
  simulator (the `rokubot-examples` skill) before it counts as done.

## Decided

**Getting there.** `main.bs` reads a deep link `scene=crypt` and starts in `CryptScene`;
without it the game starts in `FieldScene` as now. Existing deep links (`quality`, `perf`,
…) keep working, and are passed to whichever scene starts.

**Layout.** The maze is a small text grid in the source, one character per cell, about
8 x 8 cells at 6 m per cell (so about 50 m across). Walls run along cell edges or fill
cells, builder's choice, but corridors must be 5-6 m wide. The same grid produces the
walls, their colliders, the torches and the props, so editing the layout is editing text.
It should feel like a maze: a few dead ends and loops, the exit not visible from the start.

**Floor.** A flagstone texture we draw, on a `DrawablePlane` with `fillMode: tiledImage`
across the whole maze, shaded (`isShaded`) so torches pool on it.

**Walls.** Oriented images of a stone texture we draw (about 4 m tall). Builder's call
(planning): solid grid cells, each showing only the faces that border a floor cell, drawn
one-sided (`oriented`, facing the floor), since the back of a solid cell is never seen.
They are `isStatic` (so they go in the renderer's static BSP) and
`isOccluder` (so walls hide what's behind them). The texture is pre-tiled into a wide
bitmap so a run of wall needs few quads. Each wall has a
`BoxCollider3d` on `World.CAMERA_BLOCKER`, so the existing `CameraBoom` pulls the camera in
front of it.

**Walls and torchlight (Mark's decision).** A shaded oriented image gets one colour per
triangle, taken at its centre (`SceneObjectBillboard.applyShading()`), so a single long
quad can't show a pool of light fading along it. Cut walls into short segments (about 2 m)
so torchlight falls off along them. If that measures too slow, fall back to long quads with
even shading.

**Wall type (Mark's decision).** Image walls re-warp every frame the camera moves, while a
`DrawableModel` reuses its impostor (that's why `Pillar` defaults to models). Build both
wall types behind a deep link (e.g. `walls=image|model`), compare them on the device, and
use the faster one by default. Model walls still occlude but don't go in the static BSP,
so check they sort right against the knight. This is example code, not an engine change.

**Update 2026-11-06: grid walls.** The two wall decisions above are superseded. Main gained
`BGE.DrawableGridWalls` (#445) for this maze, and the warp path was replaced by column drawing
(#449-#454), so both were measured again on the Ultra (orbiting camera, `perf=1`, average fps):

| Walls | Basic | Low | Medium | High | Ultra | Adaptive |
|---|---|---|---|---|---|---|
| image runs, up to 9 cells per quad | 23.3 | | 18.9 (min 14) | | 12.7 | |
| model runs | | | 20.4 | | | |
| image, one quad per 6 m cell | | | 10.9 | | | |
| grid walls | 34.0 | 24.3 | 23.8 (min 23) | 16.9 (4 px) / 19.2 (6 px) | 14.7 | 19.6 (min 17) |

Grid walls replace `CryptWallRun` (and the `walls`, `run` and `occlusion` deep links). They
cost about the same as the long runs at Medium (~22 ms), but the cost doesn't depend on the
number of walls, nothing swims, the frame rate is steady, and torchlight is sampled along the walls
(`lightWrap` 0.5, since a torch lights its own wall edge-on). The presets jump from 8 px strips
(Medium) to 4 px (High), doubling the walls' cost, so adaptive quality bounced between them
(19.0 avg, min 13). High is now 6 px (#464), and adaptive settles at High.

Profiling the walls (#464) showed the draw calls aren't the cost: at Medium, casting took
5.3 ms, strip geometry 6.2, shading 6.6 and the draw calls 3.9. Rotated strips cost the same as
upright ones (`grid-walls-strip-benchmark`: 320 strips in 3.6-3.9 ms either way). With each
face's light cached, shading drops to 1.8 ms: Medium runs at 26.2 fps, High (6 px) at 23.3, and
adaptive settles at High at 22.8 fps (min 21.9).
Torch flames (`DrawableParticles`) are hidden by grid walls since #463.

**Walking into walls.** The knight can't pass through walls or out of the maze. Use
`BGE.SolidWorld.moveAndSlide()` (x/z mapped onto its 2D plane) built from the same grid,
so sliding along a wall feels right.

**Light.** No moon. A very dim, cold `AmbientLight` so unlit stone is just visible, and
warm `Torch`es (the existing entity) on walls at junctions and in alcoves. The camera's
draw distance is short and fades to black (`drawDistanceFadeFraction`); no skybox (black
background).

**Props.** Billboards: skeletons in alcoves, rubble and bone piles, an altar with a pale
`spirit` torch at the far end. Doorways where corridors meet rooms are simple
post-and-lintel models, not curved arches.

**Exit.** A doorway at the end of the maze; walking into it changes scene to `FieldScene`
(with `changeSceneWithFade()`) until the graveyard exists. The scene removes its lights
in `onDestroy()`, as `FieldScene` does.

**Shared code.** The knight, camera rig, HUD and debug toggle are set up the same way in
both scenes; factor what's shared out of `FieldScene` rather than copying it, without
changing how `FieldScene` behaves.

**Done** when Mark can launch `scene=crypt` on a device, walk the whole maze and out the
exit, and it holds the game's 20 fps target in the busiest corridor. The target device is
the Roku Ultra at 192.168.41.102 (Mark's decision), the one this example has been tuned on.
Measure with adaptive quality on and report the frame rate and the quality level it
settles at, plus pinned-quality numbers for both wall types (builder's call: no quality
floor was set, so a low settled level is reported, not treated as failure).

## Left to the builder

- The exact maze, prop placement and torch count (keep torches few; each point light
  costs relighting).
- Texture sizes, colours and how the wall/floor/prop art is drawn.
- Whether walls run along cell edges or fill cells, as long as the scene measures well.
- Keeping the knight's `CombatDirector` with no enemies, freeing the crypt's bitmaps on
  leaving, and limiting camera tilt so it can't look over the walls.
- Draw distance, fade fraction and ambient level, tuned by eye on a device.
- Whether the knight starts facing into the maze or just inside the entrance doorway.
- How to wire `SolidWorld` into the knight's movement without changing `FieldScene`
  (`FieldScene` has no walls).
