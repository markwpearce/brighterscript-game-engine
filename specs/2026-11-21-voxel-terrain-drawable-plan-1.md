# Voxel terrain PR 1: map data, implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `BGE.VoxelMap` (heights, palette colours, mip levels, edge modes, lookups), `.bvox` load/save,
`BGE.VoxelMapGenerator`, and `tools/voxel-map.py` (PNG → `.bvox`).

**Architecture:** Pure data under `src/source/engine/voxel/`. The class (`VoxelMap.bs`) holds data
and lookups; namespace functions that build or load maps live in `VoxelMaps.bs` (CLAUDE.md: a
namespace function returning a class from the same file can corrupt types). The generator reuses
`VoxelMaps.averageHeights()`. The tool is stdlib-only Python with its own minimal PNG reader.

**Tech Stack:** BrighterScript, Rooibos v6, Python 3 stdlib (zlib, struct).

Design: `specs/2026-11-21-voxel-terrain-drawable-design.md` (PR 1 section).

## Global Constraints

- Size a power of 2 from 64 to 1024; level count `min(6, sizeShift - 2)` (no level under 8x8).
- Heights 0-255; colours are palette indexes 0-255; palette up to 256 RGB (`0xRRGGBB`) entries.
- Height mip: `(a + b + c + d) \ 4` over each 2x2. Colour mip: most common of the 4 in row order
  (x,z), (x+1,z), (x,z+1), (x+1,z+1); a tie goes to the first of the tied values in that order.
- `.bvox` v1 layout exactly as the design's table.
- No single-line `if`; real types; `import` every file whose symbols are used.
- Engine logs from data code with `print "[BGE.VoxelMap] " + message` (no `Game` here), as
  `TiledParser` does.
- `npm run check` passes at the end.

---

### Task 1: `VoxelMap` data, mips and lookups

**Files:**
- Create: `src/source/engine/voxel/VoxelMap.bs`, `src/source/engine/voxel/VoxelMaps.bs`
- Test: `src/source/engine/voxel/VoxelMap.spec.bs`

**Interfaces (produced):**
- `enum BGE.VoxelEdgeMode` `wrap = "wrap"`, `flat = "flat"`.
- `interface BGE.VoxelMapOptions extends roAssociativeArray`: `optional edgeMode as string`,
  `optional flatHeight as integer`, `optional flatColor as integer`,
  `optional heightLevels as dynamic`, `optional colorLevels as dynamic`.
- `class BGE.VoxelMap`: fields `size`, `sizeShift`, `mask` (integers), `palette as integer[]`,
  `heightLevels as roArray` (of `integer[]`), `colorLevels as roArray`, `edgeMode as string`,
  `flatHeight as integer`, `flatColor as integer`. `new(sizeShift, palette, heightLevels,
  colorLevels)`; `getLevelCount() as integer`; `cellHeight(ix, iz) as integer`;
  `colorAt(ix, iz) as integer`; `heightAt(x as float, z as float) as float` (bilinear about cell
  centres: cell i's height is at i + 0.5).
- `BGE.VoxelMaps.maxLevelCount(sizeShift) as integer`, `BGE.VoxelMaps.sizeShiftOf(size) as integer`
  (-1 if not a power of 2 in 64-1024), `BGE.VoxelMaps.averageHeights(heights, levelShift) as
  integer[]` (one level down), `BGE.VoxelMaps.mostCommonColors(colors, levelShift) as integer[]`,
  `BGE.VoxelMaps.fromArrays(size, heights, colors, palette, options = {}) as dynamic`
  (`VoxelMap` or `invalid`).

- [ ] **Step 1: failing tests** in `VoxelMap.spec.bs` (`@suite("BGE.VoxelMap")`):
  - `sizeShiftOf`: 64→6, 1024→10, 32→-1, 100→-1, 2048→-1.
  - `maxLevelCount`: 6→4, 8→6, 10→6.
  - `averageHeights` on a 2x2-blocked 64 map (block values 0,1,2,3 → 1; 10,10,10,13 → 10).
  - `mostCommonColors`: [5,7,7,5] → 5 (tie, first); [1,2,3,3] → 3; [4,4,4,9] → 4.
  - `fromArrays` builds 4 levels for 64, level sizes 64²,32²,16²,8²; rejects size 100, a heights
    array of the wrong length, a colour index ≥ palette count, a palette over 256, a height
    outside 0-255 — each returns `invalid`.
  - Uses supplied `heightLevels`/`colorLevels` when given (same object at level 1).
  - `cellHeight`/`colorAt` under wrap: (-1, 0) reads (63, 0); (64, 65) reads (0, 1).
  - Under flat (`flatHeight` 40, `flatColor` 2): (-1, 0), (64, 3) → 40 and 2; inside unchanged.
  - `heightAt`: on a map where height = ix (wrapping aside), `heightAt(10.5, 3.5)` = 10.0,
    `heightAt(11.0, 3.5)` = 10.5; at the flat edge `heightAt(64.0, 3.5)` blends 63 and 40 = 51.5.
- [ ] **Step 2:** `TEST_SHARDS=engine npm run test:ci` → fails (`cannot-find-name` at build).
- [ ] **Step 3:** implement `VoxelMap.bs` and `VoxelMaps.bs` (code in the commit; follows the
  Interfaces above exactly).
- [ ] **Step 4:** `TEST_SHARDS=engine npm run test:ci` → passes.
- [ ] **Step 5:** commit `VoxelMap: heights, palette colours, mips, edge modes (#637)`.

### Task 2: `.bvox` load and save

**Files:**
- Modify: `src/source/engine/voxel/VoxelMap.bs` (add `saveToFile(path) as boolean`,
  `toByteArray() as roByteArray`), `src/source/engine/voxel/VoxelMaps.bs` (add
  `fromFile(path) as dynamic`, `fromByteArray(bytes as roByteArray) as dynamic`)
- Test: `src/source/engine/voxel/VoxelMapFile.spec.bs`

**Interfaces:** consumes Task 1; produces `fromFile`, `fromByteArray`, `saveToFile`,
`toByteArray`.

- [ ] **Step 1: failing tests** (`@suite("BGE.VoxelMap files")`):
  - Round trip through `tmp:/bge_voxel_test.bvox`: size, palette, every level's heights and
    colours, edge mode, flat height and colour equal.
  - `toByteArray()` header bytes: `42 47 45 56 01 06 04 01 28 02 03`… for a flat 64 map with 3
    colours (magic, version, shift, levels, edge, flat height 40, flat colour 2, palette count 3).
  - 256 colours write palette count 0 and read back 256.
  - `fromByteArray` → `invalid` for: bad magic, version 2, shift 5, shift 11, level count 0,
    level count past the max, one byte short, one byte long, a colour index ≥ palette count.
  - `fromFile("tmp:/bge_voxel_missing.bvox")` → `invalid`.
- [ ] **Step 2:** run → fails.
- [ ] **Step 3:** implement. Validate the length exactly before reading levels; check colour
  indexes against the palette while copying.
- [ ] **Step 4:** run → passes.
- [ ] **Step 5:** commit `VoxelMap: .bvox load and save (#637)`.

### Task 3: `VoxelMapGenerator`

**Files:**
- Create: `src/source/engine/voxel/VoxelMapGenerator.bs`
- Test: `src/source/engine/voxel/VoxelMapGenerator.spec.bs`

**Interfaces:**
- Consumes: `VoxelMaps.averageHeights`, `VoxelMaps.maxLevelCount`, `VoxelMaps.sizeShiftOf`,
  `VoxelMaps.fromArrays` (with `heightLevels`/`colorLevels`).
- Produces: `interface BGE.VoxelBiome extends roAssociativeArray` (`top as integer`,
  `rgb as integer`); `interface BGE.VoxelMapGeneratorOptions` (all optional: `size`, `seed`,
  `roughness`, `seaLevel`, `biomes`, `slopeShading`); `class BGE.VoxelMapGenerator` with
  `new(options = {})` and `generate() as dynamic` (a `VoxelMap`, `invalid` on a bad size).
  Palette: biome b, shade s (0-3, factors 0.6/0.8/1.0/1.15) at index b * 4 + s.

- [ ] **Step 1: failing tests**: same seed → identical level-0 heights (compare a checksum and
  a few cells); different seed → different; heights 0-255 and none under `seaLevel`; palette count
  = biomes × 4; level count 4 for size 64; every level's colours are re-shaded (a colour at level 1
  equals the biome of its averaged height, shade any); bad size → `invalid`.
- [ ] **Step 2:** run → fails.
- [ ] **Step 3:** port the spike's `generateMap()`/`colorMap()`/`scaleColor()` (and `rand()`),
  parametrised by the options. Palette stored as RGB (`0xRRGGBB`), not RGBA.
- [ ] **Step 4:** run → passes.
- [ ] **Step 5:** commit `VoxelMapGenerator: diamond-square + biome maps (#637)`.

### Task 4: `tools/voxel-map.py`, fixture test, rules

**Files:**
- Create: `tools/voxel-map.py`, `src/source/engine/voxel/VoxelMapTool.spec.bs`,
  `.claude/rules/voxel.md`

**Interfaces:** consumes the `.bvox` format and mip rules.

- [ ] **Step 1:** write the tool: stdlib PNG reader (non-interlaced; colour types 0, 2, 3, 4, 6;
  bit depth 8 or 16; all five filters), heights scaled to 0-255 (16-bit: `>> 8`), alpha ignored,
  colours exact if ≤ 256 distinct else quantised by median cut to 256, mips by the global rules,
  `--edge wrap|flat --flat-height N --flat-color RRGGBB` (flat colour added to the palette if
  missing), `--write-test-pngs DIR` writes the fixture source PNGs.
- [ ] **Step 2:** make two 64x64 PNGs with the tool's own `--write-test-pngs DIR` (a ramp
  heightmap and a 3-colour checker) and bake them to `src/source/engine/voxel/VoxelMapTool.spec.bvox` (`--edge flat --flat-height 10`); `bsconfig.build.json` excludes `**/*.spec.*` so it never ships.
- [ ] **Step 3: test**: `VoxelMapTool.spec.bs` loads that fixture via `fromFile` and must equal `fromArrays` on the same data built in BrightScript (the ramp
  and checker formulas), level by level.
- [ ] **Step 4:** run → passes. Rules file: paths `src/source/engine/voxel/**`, `tools/voxel-map.py`;
  points at the design spec and states the mip rules shared with the tool.
- [ ] **Step 5:** `npm run check` → passes; commit `tools/voxel-map.py: PNG heightmaps to .bvox (#637)`.
