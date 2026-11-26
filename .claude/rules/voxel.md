---
paths:
  - "src/source/engine/voxel/**"
  - "src/source/engine/renderer/voxel/**"
  - "src/source/engine/renderer/sceneObjects/SceneObjectVoxelTerrain.bs"
  - "src/source/engine/drawables/DrawableVoxelTerrain.bs"
  - "tools/voxel-map.py"
---

# Voxel terrain

Design: `specs/2026-11-21-voxel-terrain-drawable-design.md` (spike: `specs/2026-11-21-voxel-terrain-spike.md`).

- `VoxelMap` is data only: per level an `roByteArray` of heights (0-255) and one of palette indexes, `edgeMode` wrap/flat. Only `fromArrays()` validates colour indexes; renderer colour tables must cover all 256 so a bad index from a file can't crash a draw. Functions that make or load maps live in `VoxelMaps.bs`, not the class file (bsc self-reference bug).
- Mip rules are shared with `tools/voxel-map.py` and must stay identical: heights `(a+b+c+d) \ 4`; colours most common of the 2x2, ties to the first in (x,z), (x+1,z), (x,z+1), (x+1,z+1). `VoxelMapTool.spec.bs` checks a tool-made fixture (`VoxelMapTool.spec.bvox`; `*.spec.*` is kept out of the package build) against `fromArrays`. Regenerate it with the command in that spec if the format changes.
- `.bvox` v1 layout is documented on `VoxelMaps.fromByteArray()` and, with offsets and the size formula, in `docs/voxel-terrain.md`: update both, and bump the version byte, for any change.
- `fromFile()` reads each level with a ranged `ReadFile` (no per-cell loop): keep it that way, it's the games' load path.
- `VoxelMapGenerator` is slow (~1.3 s for 256 on the Ultra): games load baked maps.
- Doc: `docs/voxel-terrain.md`. Benchmark on device with rendererTest `demo=voxel-terrain sweep=1` (`objects=0` for terrain only, `bank=`, `pitchModes=`, `qualityList=`); its `VOXEL stages` lines break the frame down.
- The march is the hot path (~4 µs per column per step on the Ultra): the two pitch projections are separate loop copies, per-step constants live in tables (`exact` ones rebuilt per march), and flat edges sample a one-cell map instead of branching per step. Keep it branch-free.
- Colour tables cover all 256 indexes (stride 256) so a bad index from a file can't crash a draw.
