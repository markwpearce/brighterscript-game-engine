---
paths:
  - "src/source/engine/voxel/**"
  - "tools/voxel-map.py"
---

# Voxel terrain

Design: `specs/2026-11-21-voxel-terrain-drawable-design.md` (spike: `specs/2026-11-21-voxel-terrain-spike.md`).

- `VoxelMap` is data only: per level an `roByteArray` of heights (0-255) and one of palette indexes, `edgeMode` wrap/flat. Only `fromArrays()` validates colour indexes; renderer colour tables must cover all 256 so a bad index from a file can't crash a draw. Functions that make or load maps live in `VoxelMaps.bs`, not the class file (bsc self-reference bug).
- Mip rules are shared with `tools/voxel-map.py` and must stay identical: heights `(a+b+c+d) \ 4`; colours most common of the 2x2, ties to the first in (x,z), (x+1,z), (x,z+1), (x+1,z+1). `VoxelMapTool.spec.bs` checks a tool-made fixture (`VoxelMapTool.spec.bvox`; `*.spec.*` is kept out of the package build) against `fromArrays`. Regenerate it with the command in that spec if the format changes.
- `.bvox` v1 layout is documented on `VoxelMaps.fromByteArray()`; bump the version byte for any change.
- `fromFile()` reads each level with a ranged `ReadFile` (no per-cell loop): keep it that way, it's the games' load path.
- `VoxelMapGenerator` is slow (~1.3 s for 256 on the Ultra): games load baked maps.
