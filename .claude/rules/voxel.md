---
paths:
  - "src/source/engine/voxel/**"
  - "tools/voxel-map.py"
---

# Voxel terrain

Design: `specs/2026-11-21-voxel-terrain-drawable-design.md` (spike: `specs/2026-11-21-voxel-terrain-spike.md`).

- `VoxelMap` is data only (heights 0-255, palette indexes, mip levels, `edgeMode` wrap/flat). Functions that make or load maps live in `VoxelMaps.bs`, not the class file (bsc self-reference bug).
- Mip rules are shared with `tools/voxel-map.py` and must stay identical: heights `(a+b+c+d) \ 4`; colours most common of the 2x2, ties to the first in (x,z), (x+1,z), (x,z+1), (x+1,z+1). `VoxelMapTool.spec.bs` checks a tool-made fixture (`VoxelMapTool.spec.bvox`; `*.spec.*` is kept out of the package build) against `fromArrays`. Regenerate it with the command in that spec if the format changes.
- `.bvox` v1 layout is documented on `VoxelMaps.fromByteArray()`; bump the version byte for any change.
- `VoxelMapGenerator` is slow (~1.3 s for 256 on the Ultra): games load baked maps.
