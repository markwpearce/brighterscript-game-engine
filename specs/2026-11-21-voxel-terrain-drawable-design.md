# Voxel terrain drawable: design (#637)

## Intent

The #549 spike (`specs/2026-11-21-voxel-terrain-spike.md`) showed a Comanche-style heightmap terrain
runs on Roku at ~30 fps on the Ultra with 50-80 columns. It only exists inside the rendererTest demo
(`VoxelTerrainTest.bs`), with its own camera and sprites, drawing straight to the screen, so no game
can use it. This turns it into engine pieces: a map, a generator, a baking tool, a drawable driven by
`Camera3d`, and a camera pitch mode that keeps objects on the hills.

## Goals

- A game loads a baked map, adds a terrain drawable, and gets hills drawn from the `Camera3d` it
  already has, with its objects hidden behind the hills.
- Objects and the camera can stand on the terrain (`heightAt`).
- Quality levels trade columns and depth steps; fog and draw distance come from the camera.
- Roll at any angle; pitch as accurate as the chosen mode allows, with the trade-offs measured.

## Non-goals

- Collision or raycasts against the terrain (beyond `heightAt`).
- More than one terrain per renderer.
- Ordering walls against hills: walls draw over the terrain.
- Interlacing, shear roll, or the "skip hidden runs" trick (all tried in the spike; none worth it).
- Editing the map at runtime (rebuild the map and hand it over instead).

## Delivery

One spec, three PRs:

1. **Map data**: `VoxelMap`, `VoxelMapGenerator`, `.bvox` files, `tools/voxel-map.py`.
2. **Terrain drawable**: drawable + scene object, object hiding, quality fields, roll, fog, docs,
   demo switch, pitch modes `horizonShift` and `exact` benchmarked.
3. **Shear pitch camera**: `Camera3d.pitchMode = shear`, the projection audit, and the A/B/C
   comparison.

## PR 1: map data (`src/source/engine/voxel/`)

### `BGE.VoxelMap`

Pure data, no rendering.

- Square, size a power of 2 from 64 to 1024. Each level's heights (0-255) and colours (palette
  indexes) are an `roByteArray` (a 1024 map as integer roArrays would be tens of MB and slow to
  load), with `palette` up to 256 RGB colours (`0xRRGGBB`). A colour index past the palette draws
  as palette colour 0; only `fromArrays` checks them.
- Mip levels `heightLevels[n]`/`colorLevels[n]`: level n covers 2ⁿ×2ⁿ cells; level 0 is the map
  itself. Up to 6 levels (fewer for small maps: a level is never under 8x8).
- Builders live in `BGE.VoxelMaps` (a namespace function returning a class from its own file can
  corrupt types). Each logs why and returns `invalid` on bad input:
  - `fromArrays(size, heights, colors, palette, options)`: integer arrays; validates values, then
    builds the mips: heights averaged over each 2x2 (rounded down), colours the most common of the
    4 (ties: the first in row order).
  - `fromLevels(sizeShift, palette, heightLevels, colorLevels, options)`: mips already built (the
    generator's re-shaded ones); checks counts and sizes.
  - `fromFile(path)`: a `.bvox`, each level read straight into its byte array with a ranged
    `ReadFile` (no loop over cells). `fromByteArray(bytes)` for one in memory.
- `map.saveToFile(path)` / `map.toByteArray()`. A bad magic, unknown version, wrong size or
  truncated file logs why and returns `invalid`.
- Edges, `edgeMode`:
  - `wrap` (default): the map repeats, as in the spike. Needs a tileable map to look right.
  - `flat`: past the edge is a floor at `flatHeight` coloured palette index `flatColor` (sea round
    an island).
- Lookups in cells, all honouring `edgeMode`:
  - `cellHeight(ix, iz)`, `colorAt(ix, iz)`: integer cells.
  - `heightAt(cellX, cellZ)`: bilinear between the four surrounding cells, for standing on it.

### `.bvox` format (version 1)

Every field is one byte:

| Field | Size |
|---|---|
| magic `BGEV` | 4 |
| version (1) | 1 |
| size shift (log2 of size) | 1 |
| level count | 1 |
| edge mode (0 wrap, 1 flat), flat height, flat colour | 3 |
| palette count (1-256; 0 means 256) | 1 |
| palette, RGB per entry | 3 × count |
| per level: heights, then colours | 2 × (size >> level)² |

### `BGE.VoxelMapGenerator`

The spike's diamond-square and biome generator, moved into the engine.

- Options: `size`, `seed`, `roughness` (0.55), `seaLevel` (70), `biomes` (array of
  `{top, rgb}`, the spike's six by default), `slopeShading` (true).
- `generate()` returns a `VoxelMap`; each biome has 4 shades, and each mip level is re-shaded from
  its own averaged heights and slopes (as the spike does, which reads better than most-common-of-4
  for generated maps).
- Documented as slow (~1.3 s for 256x256 on the Ultra, a watchdog risk on slower devices): loading
  a baked map is the default path for games.

### `tools/voxel-map.py`

`voxel-map.py heights.png colors.png out.bvox [--edge wrap|flat --flat-height N --flat-color RRGGBB]`

- Heights: a grayscale PNG (any bit depth, scaled to 0-255). Colours: a PNG of the same size,
  quantised by median cut to 256 colours or fewer (exact if it already has ≤256; 255 with a flat
  edge whose colour isn't in the map, leaving it a slot). Standard library only, non-interlaced.
- Bakes the mips with the same rules as `fromArrays`, so the tool's file and `fromArrays` on the
  same data are identical.
- Size must be a power of 2 from 64 to 1024; anything else is an error with a clear message.

### Tests

Rooibos: mip averaging and most-common-of-4 (with ties); save → load round trip; bad magic, version,
size, truncated file; `heightAt` bilinear values, including across the wrap and into the flat edge;
generator deterministic for a seed, heights in 0-255, palette has 4 shades per biome. A small fixture
`.bvox` made by the tool (`VoxelMapTool.spec.bvox`; `*.spec.*` is kept out of the package build),
whose heights and colours exercise rounding and every kind of colour tie, loads and matches
`fromArrays` on the same data.

## PR 2: the terrain drawable

### `BGE.DrawableVoxelTerrain(owner, map, options)`

Registers a `SceneObjectVoxelTerrain`.

- `cellSize`: world units per map cell (default 1).
- `heightScale`: world units per height unit (default 1).
- Placement: the owner's position is map cell (0, 0). Map x/z is world x/z; world y is
  height × `heightScale` + owner y.
- `pitchMode` (`VoxelPitchMode`): `horizonShift` (default) or `exact`. Ignored when the camera's
  own `pitchMode` is `shear` (PR 3).
- `fade`: `{color (RGB), start (fraction of the draw distance, default 0.5)}`, used when
  `Camera3d.fog` is off. It fades far terrain into a colour (the sky's, typically) as the spike
  does. Without it the terrain ends at the draw distance.
- `heightAt(worldX, worldZ)`: world y, through the map's bilinear `heightAt`.
- `Camera3d` only; one terrain per renderer (a second logs a warning and is not drawn).

### Drawing

- A new fixed stage `terrain` after `fogSilhouettes` and before `walls`.
- Each frame it reads the camera's position, level forward and right, effective FOV (zoom
  included), effective max draw distance, and pitch.
- Step tables (depth, projection factor, fog row, band starts, band mip levels) are rebuilt only
  when the distance, columns, steps per band or FOV change. The projection base follows the camera
  height every frame (~0.2 ms), as in the spike.
- The march is the spike's: column by column, 16.16 fixed-point map positions, steps doubling per
  band, mip level the coarser of the column gap and the step, whole-pixel span edges, same-coloured
  spans merged, early stop once nothing farther can show. Spans go to the target with `DrawRect`,
  and each column keeps its spans (top, height, colour, nearest depth).
- Map edges: under `wrap`, map indexes are masked as in the spike. Under `flat`, each column works
  out per band which steps are inside the map (a ray-box test, per column per band, not per step);
  steps outside use the flat height and colour.
- Still frames: while the camera pose, projection, quality, map and options are unchanged, the
  march is skipped and the stored spans are drawn again.
- Pitch:
  - `horizonShift`: the horizon moves by focal × tan(pitch), as in the spike. Accurate to about
    ±15°; past that, objects float or sink against the hills.
  - `exact`: each step projects y with the pitched camera (one divide per step). Heights match at
    any pitch; columns still can't lean, so objects near the screen edges drift sideways a little
    at steep pitch.
- Roll ≠ 0: the level view is marched into a scratch bitmap as wide as the screen's diagonal
  (alpha on, cleared transparent), then rotated onto the target in one blit, as `SceneObjectPlane`
  does. The diagonal-size bitmap means ~15% more columns.

### Fog and fade

- `Camera3d.fog` on: the fog colour, with the fog's fixed draw distance, drives a 16-band table
  (palette index × fog band → colour), no fog for the nearest half, then towards the fog colour.
- Fog off: `fade` drives the same table, or there is no table and the palette is used directly.
- The table is rebuilt only when its colour, start or the palette changes.

### Objects behind hills

In `Renderer.drawSortedObject()`, beside the walls test:

- A column's spans run from the screen bottom upward with increasing depth, so a column's
  "occluder top" at depth d is the top of the last span that starts nearer than d.
- Before an object draws, its screen box is tested against the columns it covers:
  - every column's occluder top is above the box's top and the object `canBeOccluded()`: it's
    skipped and latched like a wall-hidden one (`markSkippedOccluded`).
  - some column's nearer spans overlap the box: it draws, then the nearer spans are drawn again
    over it, clipped to its box, one column wider each side. Members of a cluster queue this
    until after the cluster, as `pendingWallRedraws` does.
- With roll, the redrawn spans are a 1 px white bitmap tinted, scaled and rotated about the view
  centre.
- Exact at column resolution; a merged span counts at its nearest depth, so an object may be hidden
  a little early at the far end of a long same-coloured run (as in the spike).

### Quality

New `RenderQualitySettings` fields, with presets and the presets spec's completeness and
monotonicity checks:

| Field | basic | low | medium | high | ultra |
|---|---|---|---|---|---|
| `voxelColumns` | 50 | 64 | 80 | 100 | 100 |
| `voxelBandSteps` | 20 | 20 | 20 | 20 | 28 |

The draw distance is the camera's effective max draw distance (quality-scaled, eased, device-capped;
fixed while fog is on).

### Profiling

`profileStages` adds a `terrain` stage; the renderer exposes last-frame counts of spans, steps and
span redraws for the demo and benchmarks.

### Benchmarks

On the Ultra (192.168.41.102), each quality level, flying and turning, objects in view, for
`horizonShift` and `exact`: fps and terrain ms. The default `pitchMode` is chosen from these, and the
numbers go in the doc. Express (.118) numbers if time allows.

### Docs, demo, tests

- `docs/voxel-terrain.md` (map, baking, drawable, quality, pitch, limits), linked from the docs
  site, and a line in `.claude/rules/renderer.md`.
- The rendererTest demo uses the drawable and keeps its `sweep`/`still` benchmark params.
- Rooibos: spans for a tiny map from a fixed camera (count, colours, positions); `heightAt` in world
  units; hidden/partial/visible decisions against known spans; still frames skip the march; roll
  takes the scratch-bitmap path; quality fields are read; a second terrain is refused.

### Results (PR 2, Roku Ultra, 1280x720)

Flying and turning over the generated 256 map, terrain only (`demo=voxel-terrain sweep=1 objects=0`):

| Level | `horizonShift` | `exact` | `horizonShift`, 20° roll |
|---|---|---|---|
| basic | 17.5 ms, 48 fps | 23.4 ms, 38 fps | 21.8 ms, 39 fps |
| low | 22.4 ms, 39 fps | 29.4 ms, 31 fps | |
| medium | 29.5 ms, 30 fps | 40.4 ms, 23 fps | 36.8 ms, 24 fps |
| high | 38.0 ms, 24 fps | 51.2 ms, 18 fps | |
| ultra | 44.6 ms, 21 fps | 58.3 ms, 16 fps | 54.3 ms, 17 fps |

- The march costs ~3.8-4.0 µs per column per step, the same as the spike. `exact` is +31-37% (it was
  +40-57% until its per-step constants moved into per-march tables), so `horizonShift` stays the
  default.
- Under roll the columns are scaled by the level view's width over the frame's, so the screen keeps
  as many as unrolled (the spike did the same).
- Loading a 256 `.bvox` takes 2 ms.
- Merged spans start at their nearest depth but reach much farther (flat ground of one colour is one
  span), so hiding uses each column's exact top-by-depth profile (`columnTops`, bisected), not span
  depths. The hill test costs ~5 ms for ~40 objects in view.
- With 160 billboards, the engine's per-object update (~23 ms a frame) and their draws cost more than
  the terrain. That's the general billboard cost, not the terrain's.

## PR 3: shear pitch camera

### `Camera3d.pitchMode`

`rotate` (default, today) or `shear`.

- Under `shear` the view matrix uses the level orientation (pitch removed), and the pitch becomes a
  vertical principal-point offset, `principalOffsetY = -focal × tan(pitch)` (looking down moves the
  image up), read through `camera.getPrincipalOffsetY()` (0 under `rotate`).
- Vertical lines stay vertical; objects follow the terrain's horizon shift exactly.
- Pitch is clamped to ±60° under `shear`.
- A change of `pitchMode` bumps `projectionVersion`.

### Projection audit

Every projection honours the offset: `worldPointToCanvasPoint`, `projectPointsWithDepth`,
`projectOutlineCutAtNear`, the frustum rays and normals (so culling matches), and
`getHorizonLine`/`getLevelHorizonLine`. Every other site that assumes the image centre is the screen
centre (QuadColumnDrawer, WallsView, SceneObjectPlane, SceneObjectSkybox, SceneObjectModel,
ImpostorFit, Renderer, Game: ~40, by grep) either reads the offset or is noted as not needing it.

The terrain under a `shear` camera uses its horizon-shift march with the camera's offset.

### Tests and comparison

- Rooibos: under `shear`, a point projects to the level camera's projection plus the offset;
  culling agrees with projection at the top and bottom edges; the plane and skybox horizon lines
  move by the offset; spot checks for walls and quad columns.
- Device: screenshots of `horizonShift`, `exact` and `shear` at 0°, 15° and 30° in the demo, and
  objects/planes/walls scenes under `shear` to catch regressions. Results go in a section at the
  end of this spec.

## Open questions

- Express performance (expected 2-3x slower than the Ultra).
