# Voxel terrain PR 2: the terrain drawable, implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `BGE.DrawableVoxelTerrain` draws a `VoxelMap` from the renderer's `Camera3d` in a fixed
`terrain` stage, hides sorted objects behind hills, handles roll, fog and quality, with pitch modes
`horizonShift` and `exact` benchmarked on the Ultra.

**Architecture:** A pure march (`BGE.VoxelTerrainView`, `renderer/voxel/`) turns a camera pose into
per-column spans (top, height, RGBA, nearest depth) with no drawing, so it's unit-testable like
`WallsView`. `SceneObjectVoxelTerrain` builds the pose from the camera each frame, runs the view
(or keeps last frame's spans when nothing changed), and draws spans to the target, or under roll
into its own level bitmap that it rotates on. The renderer registers one terrain like the walls,
draws it in a new stage, and asks it in `drawSortedObject()` whether an object is hidden or needs
spans redrawn over it.

**Tech Stack:** BrighterScript, Rooibos v6, rokubot (device runs on 192.168.41.102).

Design: `specs/2026-11-21-voxel-terrain-drawable-design.md` (PR 2 section). Spike reference:
`examples/rendererTest/src/source/Tests/VoxelTerrainTest.bs` (`buildTables()`, `march()`,
`compose()`).

## Global Constraints

- Quality values: `voxelColumns` 50/64/80/100/100, `voxelBandSteps` 20/20/20/20/28 (basic → ultra).
- Keep from the spike: steps double per band; mip level = coarser of column gap (floor) and step
  (`log2Floor(dz * 1.4142)`); whole-pixel span tops; merged same-colour spans; 16 fog bands, none
  for the nearest half; no interlace; no shear roll.
- Renderer colours are RGBA (`0xRRGGBBAA`); palette and `Fog.color` are RGB.
- `Camera3d` only; one terrain per renderer.
- No single-line `if`; real types; `import` used files; no `=` between objects.
- `npm run check` passes after every task.

---

### Task 1: `VoxelTerrainView`, the march

**Files:**
- Create: `src/source/engine/renderer/voxel/VoxelTerrainView.bs`
- Test: `src/source/engine/renderer/voxel/VoxelTerrainView.spec.bs`

**Interfaces (produced):**
- `interface BGE.VoxelTerrainPose extends roAssociativeArray`: `camX`, `camZ` (map cells, float),
  `camHeight` (height units), `forwardX`, `forwardZ`, `rightX`, `rightZ` (level, map plane),
  `focal` (px), `viewWidth`, `viewHeight` (px of the level view), `horizon` (px, level view),
  `pitch` (radians, up positive; used by `exact`), `exactPitch` (boolean), `distance` (cells),
  `cellSize`, `heightScale` (world units).
- `class BGE.VoxelTerrainView`: `new(map as object)`; `columns`, `bandSteps` (integers);
  `fogColor` (RGB, -1 = none), `fogStart` (fraction); `march(pose)`; results:
  `columnSpans` (roArray of float[] per column: top, height, rgba, nearestDepth (world units)
  repeated), `columnWidth` (float), `spanCount`, `stepCount` (integers);
  `occluderTopAt(column, depth) as float` (top of the last span starting nearer than depth, or
  `viewHeight` if none).

- [ ] **Step 1: failing tests**: on a 64 map, flat height 0 except a wall row (z = 10..11, height 200)
  coloured index 1, palette [green, red]; camera at (32, 0.5) height 50 looking +z:
  - every column's first span is green, from the view bottom; the middle column has a red span above
    it with nearest depth ≈ 9.5 × cellSize (within one step); `spanCount` ≥ columns.
  - same-colour runs merge (a flat map gives exactly one span per column).
  - span tops are whole numbers; spans in a column don't overlap and rise monotonically.
  - `occluderTopAt` behind the wall returns the wall's top; in front, the ground span's top.
  - steps double per band: `stepCount` for distance 600, bandSteps 20 is the spike's count.
  - mip levels: band level = max(gap level, step level), capped at the map's last level.
  - `exactPitch` at pitch 0 gives the same spans as horizon shift; looking down 20° the wall top
    moves as the pitched projection says (one hand-computed value).
  - `edgeMode` flat: a camera looking off the map's edge sees flat-height spans in the flat colour.
  - fog: with `fogColor` set, a far span's colour is blended towards it; near half untouched.
- [ ] **Step 2:** run (`TEST_SHARDS=renderer-parts`) → fails.
- [ ] **Step 3:** implement from the spike: tables keyed on distance/columns/steps/width/focal/fog;
  bases rebuilt each march; per column per band, under flat edges, the in-map step range by a
  ray-box test (steps outside read `flatHeight`/`flatColor` from tables); exact pitch projects
  `y = horizon0 - focal * (dh * cos - d * sin) / (d * cos + dh * sin)` per step (horizon0 = view
  centre), skipping steps with a non-positive denominator.
- [ ] **Step 4:** run → passes.
- [ ] **Step 5:** commit `VoxelTerrainView: heightmap march into column spans (#637)`.

### Task 2: drawable, scene object, renderer stage, quality

**Files:**
- Create: `src/source/engine/drawables/DrawableVoxelTerrain.bs`,
  `src/source/engine/renderer/sceneObjects/SceneObjectVoxelTerrain.bs`
- Modify: `src/source/engine/renderer/sceneObjects/SceneObject.bs` (enum `VoxelTerrain`),
  `src/source/engine/renderer/Renderer.bs` (register one terrain, `terrain` stage after
  `fogSilhouettes`, `getVoxelTerrain()`), `src/source/engine/quality/RenderQualitySettings.bs`,
  `RenderQualityPresets.bs`, `RenderQualityPresets.spec.bs`
- Test: `src/source/engine/drawables/DrawableVoxelTerrain.spec.bs`

**Interfaces (produced):**
- `enum BGE.VoxelPitchMode` `horizonShift`, `exact`.
- `class BGE.DrawableVoxelTerrain extends BGE.Drawable`: `new(owner, map, args = {})`; fields
  `map`, `cellSize` (1.0), `heightScale` (1.0), `pitchMode` ("horizonShift"), `fade` (dynamic,
  `{color, start}` or invalid), `hideTolerance` (float, default = cellSize); `heightAt(worldX,
  worldZ) as float` (world y); `worldToMap(worldX, worldZ)`.
- `class BGE.SceneObjectVoxelTerrain extends SceneObject`: `view as VoxelTerrainView`;
  `marchedLastFrame as boolean`; `rolledLastFrame as boolean`; `getHiddenState(points as float[],
  depth as float) as integer` (0 visible, 1 partly, 2 all hidden; points are projected x, y pairs
  on the target); `redrawOver(rendererObj, left, top, right, bottom, depth)`.

- [ ] **Step 1: failing tests** (real `BGE.Game` + `Camera3d`, as `RendererWalls.spec.bs` does):
  draws spans with a `Camera3d` and nothing with a `Camera2d`; `heightAt` in world units with an
  offset owner, cellSize 4, heightScale 2; a second terrain is refused with a warning; a still
  camera doesn't march again (`marchedLastFrame` false) but redraws; moving marches; quality
  change (columns) marches; presets complete and monotonic for the new fields.
- [ ] **Step 2:** run (`TEST_SHARDS=drawables,renderer,engine-ui`) → fails.
- [ ] **Step 3:** implement. Pose from the camera: position/owner offset/cellSize → cells;
  level forward = normalised (o.x, o.z); right = `getLevelRightVector()` (x, z); pitch =
  atan2(o.y, |o.xz|); horizon = h/2 + focal × tan(pitch) (horizonShift); distance =
  `getCurrentDrawDistance()` / cellSize; focal = `getFocalLength()`. Fog: `Camera3d.fog.enabled` →
  its colour, start 0.5; else `fade`.
- [ ] **Step 4:** run → passes.
- [ ] **Step 5:** commit `DrawableVoxelTerrain: Camera3d-driven terrain stage (#637)`.

### Task 3: objects behind hills

**Files:**
- Modify: `src/source/engine/renderer/Renderer.bs` (`drawSortedObject()`, cluster queue),
  `SceneObjectVoxelTerrain.bs`
- Test: `src/source/engine/renderer/RendererVoxelTerrain.spec.bs`

- [ ] **Step 1: failing tests**: an image entity behind the wall row is skipped and latched
  (`isCulled()`), one in front draws, one half above the wall draws and gets spans redrawn
  (count via the terrain's `redrawsLastFrame`); cluster members queue redraws until after the
  cluster.
- [ ] **Step 2:** run → fails.
- [ ] **Step 3:** implement: test points from `getOcclusionTestPoints()` (when
  `canBeOccluded()`) or `getBoundingPointsThisFrame()`, projected with
  `projectPointsWithDepth(markBehind true)`; limit depth = level depth of
  `getDepthPosition()` − `hideTolerance`; redraw clips each nearer span to the box, one column
  wider each side.
- [ ] **Step 4:** run → passes.
- [ ] **Step 5:** commit `Renderer: hide sorted objects behind voxel hills (#637)`.

### Task 4: roll

**Files:** Modify `SceneObjectVoxelTerrain.bs`; test in `RendererVoxelTerrain.spec.bs`.

- [ ] **Step 1: failing tests**: roll 30° marches a square level view as wide as the frame's
  diagonal (`view` width = `ceil(hypot(w, h))`) and blits it once; the hidden test maps target
  points into level-view coordinates (a point rotated by the roll about the centre lands on the
  same column); redraws under roll go through the rotated 1 px path.
- [ ] **Step 2:** run → fails.
- [ ] **Step 3:** implement: own alpha bitmap (kept, not the scratch pool, so a still frame is one
  blit), cleared transparent each march; `drawRotatedImageWithCenterTo()` as the spike's `compose()`;
  redraw spans with a 1 px white bitmap via `DrawTransformedObject` (scale = span size, rotation
  = roll, tinted RGBA) about the centre.
- [ ] **Step 4:** run → passes.
- [ ] **Step 5:** commit `SceneObjectVoxelTerrain: roll by rotating the level view (#637)`.

### Task 5: demo switch, device benchmarks, docs

**Files:**
- Modify: `examples/rendererTest/src/source/Tests/VoxelTerrainTest.bs` (use the drawable; keep
  `sweep`/`still`/`quality`/`roll` params; add `pitch=` and `pitchMode=`)
- Create: `docs/voxel-terrain.md`; Modify: `.claude/rules/renderer.md`, `.claude/rules/voxel.md`,
  `docs/render-quality.md` (new fields), `jsdoc.json` if the guide needs a menu entry

- [ ] **Step 1:** switch the demo; `node scripts/examples.js validate` for rendererTest.
- [ ] **Step 2:** sideload to 192.168.41.102 (rokubot skill, sandbox off, `NO_PROXY='*'`; check the
  dev app isn't in use), run `sweep=1` for `pitchMode=horizonShift` and `exact` at pitch 0 and
  15°; record fps/terrain ms per level; screenshots at 0/15/30°.
- [ ] **Step 3:** pick the default `pitchMode` from the numbers; write the doc (map, baking,
  drawable, quality table with the measured fps, pitch modes and limits, roll, fog, objects,
  limits: one terrain, walls on top, `Camera3d` only).
- [ ] **Step 4:** `npm run check:all` → passes.
- [ ] **Step 5:** commit `Voxel terrain: rendererTest uses the drawable; docs and benchmarks (#637)`.
