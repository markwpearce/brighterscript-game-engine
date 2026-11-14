# Engine fog (issue #520)

## Why

Past the draw distance, models and level walls vanish, and the skybox shows where a building or a
town wall should be. Fogged scenes like thirdPerson's town want distant things to sink into mist
and keep the skyline's shape, so the world doesn't look like it just ends. If that holds, the draw
distance can come down, which is the cheapest frame-rate win there is.

Fog is example code today: thirdPerson's `FogBand`s are screen-wide gradient billboards. Besides
being per-game, they're expensive: they sort behind the town's level walls, so each one redraws
every nearer wall strip over itself (`Renderer.redrawWallsOver`). That costs ~20 ms a frame in the
town (24.7 fps with bands vs 35.2 with no fog, measured 2026-11-14).

## Goals

- Fog as an engine feature: one fog colour on `Camera3d`, sharing the existing draw-distance fade
  band (`drawDistanceFadeFraction`).
- A **backdrop**: the band of the screen between where the ground ends and the fog's top, filled
  in fog colour behind everything, so objects fading out fade into fog, not sky.
- **Silhouettes**: drawables that opt in keep blocking the sky past the draw distance, as a
  fog-coloured screen box, out to a multiple of the draw distance.
- **Level walls** (`DrawableWalls`, e.g. the town wall) that opt in do the same with their real
  outline: their strips carry on past the draw distance as flat fog-coloured strips.
- Two PRs: the engine (fog, silhouettes, walls, tests, rendererTest demo and benchmark, docs),
  then thirdPerson's town switching to it, after the look is signed off from device screenshots.
- No FPS loss beyond noise (~0.5 fps) against no fog at the same draw distance, ideally. A 2-5%
  drop is acceptable if it looks better. The draw distance may come down, as long as buildings and
  walls past it still block the skybox. In the town, engine fog at a shorter draw distance should
  beat no fog at today's 44 m.

## Non-goals

- Exact silhouettes (flat-filled model faces): a filled polygon costs ~1.9 ms on device.
- Fogging things in front of the camera (mist over near houses, as the bands do today).
- Colour-lerping each object's own pixels towards the fog colour (Roku tints only multiply).
- `Camera2d`.

## Anti-goals

- Fog that costs about as much as drawing the objects: then it's just a longer draw distance.
- Baking the fade or fog into cached rasters (renderer rule: fades apply at the final draw).

## Approaches considered

Measured with a throwaway spike (local branch `spike/engine-fog`) in the town's gate view
(`at=17,29,0`, `perf=phases`, camera still unless noted):

| Variant | fps |
| --- | --- |
| FogBands, 44 m (today) | 24.7 (orbiting 14.5) |
| no fog, 44 m | 35.2 (orbiting 16.3) |
| backdrop only, 44 m | 35.1 |
| backdrop + boxes from the fade band's start, 44 m | 32.5 (orbiting 15.8) |
| backdrop + boxes from the draw distance, 44 m | 34.6 |
| no fog, 30 m | 41.0 |
| backdrop + boxes, 30 m | 40.7 (orbiting 18.5) |
| backdrop + boxes, 22 m | 45.6 (orbiting 20.4) |

1. **Backdrop plus screen boxes, mostly past the draw distance** (chosen). The backdrop is one
   `DrawRect`. Box cost scales with the boxes' area, not their count, so big boxes behind buildings
   early in the fade band cost ~2.5 ms and look boxy at roofs. Starting them late in the band keeps
   them small and nearly free.
2. **Backdrop plus a per-column skyline** (~40 rects from the boxes' and wall tops' heights).
   Fixed cost and a stepped rather than boxy edge, but more code, and the wall part needs a second,
   coarser walk past the draw distance. Not chosen.
3. **Exact silhouettes**: too expensive (see non-goals).

## Design

### `BGE.Fog` (new, `renderer/Fog.bs`), on `Camera3d.fog`

```brighterscript
class Fog
  ' Off by default: nothing draws and nothing is computed
  enabled as boolean = false
  ' RGB (0xRRGGBB), like Drawable.color
  color as integer = &h808080
  ' How high the backdrop reaches at the draw distance, in world units (0: no backdrop)
  backdropHeight as float = 0
  ' Silhouettes reach this many times the draw distance (0: none)
  silhouetteReach as float = 2.0
  ' A caster's box starts once its fade alpha drops below this (0-1), and goes from clear
  ' to solid as the alpha goes from here to 0, so the box fades in as the object fades out
  silhouetteStartAlpha as float = 0.5
end class
```

`Camera3d.fog` defaults to `new BGE.Fog()` (disabled). Fields are read every frame, so they can be
changed live. World units are y-up with the ground at y = 0, like every other `Camera3d` input.

### `Drawable.castsFogSilhouette as boolean = false`

Opt-in like `isOccluder`. Meant for big things that make the skyline: buildings, towers, big
trees. Supported for any scene object type whose `getBoundingPoints()` bounds what it draws (models,
images, rectangles); the renderer skips the rest. It doesn't need an `isStatic` owner: a moving
caster's box just isn't cached (see Caching).

### Frame order (`Renderer.render()`)

1. skybox
2. **fog backdrop** (new stage `fogBackdrop`)
3. planes
4. **fog silhouettes** (new stage `fogSilhouettes`): after the ground, so a box's lower edge sits
   on the ground rather than under it; before walls and sorted objects, so anything nearer covers
   it.
5. walls, sorted objects, as now.

Both new stages are skipped outright, at the cost of one field read, when `fog.enabled` is false
or the camera isn't a `Camera3d`.

### Backdrop

Flatten the camera's forward vector to the ground (`f = orientation` with y dropped, normalised).
Skip if it's degenerate (looking straight up or down). Then:

- `top` = `worldPointToCanvasPoint(position + f * currentDrawDistance, y = backdropHeight)`
- `foot` = the same at `getPlaneDrawDistance()` and y = 0, i.e. where the ground ends
- one `DrawRect(0, top.y, frameWidth, foot.y + 4 - top.y)` in `color` at full alpha, clamped to the
  frame (top ≥ 0, bottom ≤ frame height; 4 px overlap so no sky seam shows under the ground's edge)

Filling down to the bottom of the frame instead cost 2.5 fps in the spike: only fill to the ground's
edge. Camera roll is ignored (the rect isn't rotated); a rolled camera still gets the unrolled band.

### Silhouettes

The renderer keeps a list of casters, rebuilt when a scene object is added or removed and when
`castsFogSilhouette` is set on an existing drawable (see Caching). For each enabled caster with a
fade alpha `a < silhouetteStartAlpha` whose depth point is in front of the camera and nearer than
`currentDrawDistance * silhouetteReach`:

- project `getBoundingPoints(camera)` with `Camera3d.projectPointsWithDepth(..., markBehind = true)`
  and take the screen box of the points in front of the camera; skip the caster if none are, or the
  box misses the frame
- the box alpha is `1 - a / silhouetteStartAlpha` (so 0 → 1 as the object finishes fading out)
- `DrawRect` the box in `color` at that alpha

The object's own `distanceFadeAlpha` is already kept up to date in `SceneObject.update()` whether
or not it's culled, so it's free to read here. With `drawDistanceFadeFraction` 0 it's pinned to 1,
so then a caster past the draw distance counts as alpha 0 (a solid box) and one inside as 1 (my
call). Casters are drawn far to near (the scene objects'
sort order), though as one colour the order only matters where box alphas differ.

### Level walls past the draw distance

`DrawableWalls.castsFogSilhouette` (the same `Drawable` flag) opts a walls drawable in. When fog
is enabled with `silhouetteReach > 0`, `SceneObjectWalls` walks its view out to
`currentDrawDistance * silhouetteReach` instead of the draw distance (`WallsView.update()` takes the
far limit it culls parts by, instead of reading the camera's). Its walk-reuse key includes that
far limit, so a still camera still reuses the walk.

Pieces are then shaded by depth:
- nearer than where the fade alpha reaches `silhouetteStartAlpha`: as now (texture, lit, faded)
- past that, inside the draw distance: the textured piece as now, with a **fog strip** drawn just
  before it at the same place, alpha `1 - a / silhouetteStartAlpha`, so the wall crossfades into
  fog the way a box fades in behind a model
- past the draw distance: the fog strip alone, solid

A fog strip is the piece drawn with a 1px-wide white column region (made once per walls object)
tinted with the fog colour: a tint multiplies, so white comes out exactly the fog colour. It goes
through the same `DrawTransformedObject` call, lean and LOD widening as a textured strip, so it
follows the wall's real outline at any pitch.

Fog strips never hide sorted objects (anything that far is culled anyway) and are never redrawn
over objects (`redrawStrips()` only redraws pieces nearer than the object). `isBehindWalls()`
counts them as walls, which is right: a point behind one is past the draw distance.

Costs to measure: the longer walk while the camera moves (`wallsWalk` stage), and the extra strips
(`wallsStrips`). The far pieces are narrow, and past `wallLodDistanceFraction` they're widened over
two rays, so the count should stay modest; if it doesn't, a coarser strip width past the draw
distance is the fallback.

### Caching

While nothing that shapes the boxes changed, the last frame's boxes (x, y, w, h, rgba) are
redrawn as-is without projecting anything. They're recomputed when the camera moved
(`motionChecker.movedLastFrame`), its far distance changed (`farDistanceChangedThisFrame()`), the
frame size or any `Fog` field changed, the caster list changed, or any caster's
`depthChangedThisFrame` is set (which covers it moving).

For the caster list, `Drawable.castsFogSilhouette` is a plain field. `Renderer.updateSceneObjects()`
already visits every object each frame and syncs `isOccluder` there; the caster flag is synced the
same way, marking the list dirty when it flips (my call).

## Testing

**Unit tests (Rooibos, headless):** render into a real bitmap and read pixels back
(`GetByteArray`).
- disabled fog draws nothing and adds no draw calls
- the backdrop: fog colour just above the ground's far edge, the skybox's colour above the
  backdrop's top
- a caster past the draw distance leaves fog colour at its projected centre; a non-caster there
  leaves the sky
- a caster behind the camera, or past `silhouetteReach`, draws nothing
- walls that cast silhouettes: a wall past the draw distance (inside the reach) leaves fog colour
  where it stands and the sky above its top; with the flag off it draws nothing there; a wall in
  the crossfade draws two pieces per ray (fog strip then texture)
- box alpha: a caster at fade alpha ≥ `silhouetteStartAlpha` draws no box; past the draw distance,
  a solid one
- caching: with the camera still, the second frame repeats the boxes (same draw count) without
  projecting (expose a counter or test through a subclass); moving the camera recomputes
- stage order: backdrop drawn after the skybox and before planes

**`examples/rendererTest`:**
- a `fog` demo: skybox, ground plane, a row of tall boxes (models or rectangles) marching from half
  to twice the draw distance, half of them casters, inside a ring of level walls. Buttons cycle fog off / backdrop /
  backdrop + silhouettes, and step the draw distance. The demo timing line shows the cost.
- a `fog-benchmark`: `FOG` console lines for each mode × draw distance × caster count (10/50/200),
  still and orbiting, in one run (`sweep=1`), like `walls-benchmark`.

**thirdPerson town, on device:** the town switches to engine fog. Keep the bands reachable with
`fog=bands` for A/B. Measure with `perf=phases` at the square (default spawn), the gate
(`at=17,29,0`) and orbiting (`orbit=0.4`), at 44, 30 and 22 m. Pick the town's draw distance from
those numbers: engine fog must at least match no fog at 44 m, at the gate the keep must keep its
outline in fog colour, and the user signs off on the look from screenshots.

## Left to the builder

- The town gets a `draw=<metres>` deep link for the 44/30/22 m measurements, and `fog=bands` keeps
  the old bands; what happens to the other band styles (`edge`, `thick`, ...) is the builder's call.
- `Fog` fields stay out of `RenderQualitySettings` unless a cost shows up on device.
- Prior art: the spike (local `spike/engine-fog`, 8b28ac24) and the closed PR #95
  (`Renderer.drawFogBands()`, screen-space bands).
- Whether the backdrop gets a soft top edge (a stretched gradient): only if it measures free on
  device.
- The town's fog colour, backdrop height and silhouette settings, tuned from screenshots. Building
  models get `castsFogSilhouette: true`; huts probably not.
- Docs: a "Fog" section in `docs/` where `Camera3d` draw distance and fade are explained, plus the
  renderer rule's summary line.
