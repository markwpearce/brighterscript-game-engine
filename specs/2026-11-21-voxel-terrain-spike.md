# Spike: Comanche-style voxel heightmap terrain (issue #549)

## Question

Can a "Voxel Space" heightmap renderer (NovaLogic's Comanche, 1992) run on Roku fast enough to give a
flight or driving game real hills, which the flat `SceneObjectPlane` ground can't? If so, how would it
sit with the engine's other drawables, and what quality levers does it have?

The demo is in `examples/rendererTest`: Benchmarks → **Voxel Terrain (#549)**
(`src/source/Tests/VoxelTerrainTest.bs`). See its header for controls and launch params. All numbers
below are from the **Roku Ultra**, 1280x720.

## How it works

- **Maps:** a 256x256 tileable heightmap and colour map (palette indexes), made once by diamond-square
  as flat arrays.
- **March:** each frame, each screen column marches a ray front to back over the heightmap. When the
  terrain rises above what the column has drawn so far, it draws a vertical span (`DrawRect`). Spans
  never overlap within a column, so there's no overdraw.
- **Inner loop cost-cutters:**
  - Map positions are 16.16 fixed-point integers, stepped by a fixed amount within each depth band.
  - Per-step values (depth, projection, fog row) come from tables shared by all columns. They're
    cached until the distance, columns or steps change; only the projection base, which follows the
    camera height, is rebuilt per frame (~0.2 ms).
  - Same-coloured spans in a column merge into one draw.
- **Steps:** the depth step doubles every N steps (a "band").
- **Mips:** each band samples a mip level (height and colour maps averaged 2^n x 2^n). It uses the
  coarser of the gap between neighbouring columns' rays and the step along the ray.
- **Projection:** `Camera3d`'s: focal length = half width / tan(fov / 2), map x/y = world x/z.
  Pitch is a horizon shift, as in the original.

## Cost model

The march and its spans cost ~3.2-3.8 µs per column per depth step; the march alone is ~80% of that.
Render time is almost exactly columns x steps (12.9k iterations ≈ 49 ms, 44.9k ≈ 151 ms). So the real
levers are **fewer columns and fewer depth steps**.

These didn't help:

| Tried | Result |
|---|---|
| Row-major (the classic depth-by-depth loop) vs column-major | same cost |
| Skipping runs of steps a coarse max-height map says are hidden | 25-35% fewer steps on this rough terrain, but the bookkeeping cancelled the saving |
| Marching neighbouring near columns as one while their rays are within a cell | ≤3% |
| Interlacing (half the columns per frame) | ~2x faster, but combs/shimmers while moving (every other column is a frame old) |

## Image stability

Flicker was measured as the share of pixels whose colour changes sharply (>60/255) between two shots with
the camera 1 cell apart. About 0.7% is the floor: trees and near terrain really move. At 64 columns:

| Sampling | Flicker |
|---|---|
| full-resolution map everywhere (no mips) | 5.89% |
| mips sized to the column gap | 3.58% |
| one level finer than below (`mipBias=-1`) | 2.36% |
| **mips sized to the coarser of column gap and step** | **0.72%** |

- **Step growth:** steps must double per band so each step is a whole mip texel. With x1.5 growth the
  flicker was 4.93%, and still 3.53% with rounded levels.
- **Seams:** span edges had to be snapped to whole pixels; fractional tops left 1 px sky-coloured seams.
- **Fog:** 16 bands instead of 8, so colours don't jump at band edges.

## Quality levels (as in the demo)

| Level | Columns | Steps per band | Distance | FPS (moving, shear roll) | FPS (moving, rotate roll) | Flicker |
|---|---|---|---|---|---|---|
| basic | 50 | 20 | 500 | 37.9 | 30.0 | 0.68% |
| low | 64 | 20 | 600 | 32.1 | 29.9 | 0.72% |
| medium | 80 | 20 | 700 | 29.8 | 24.6 | 0.68% |
| high | 100 | 20 | 800 | 23.7 | 19.2 | 0.68% |
| ultra | 100 | 28 | 800 | 20.0 | 16.2 | 0.70% |

"Moving" means flying and turning, averaged over 90 frames, with 31-48 objects in view (3-7 ms of it).

## Other things in the scene

- **Objects (trees, balloons) hide behind hills with no depth buffer.**
  - Each column keeps its last march's spans, with the depth where each began.
  - Objects are drawn far to near after the terrain, each followed by the spans in front of it in its
    columns (only those overlapping the sprite).
  - That's exact at column resolution and costs 3-7 ms for ~35-45 objects. It's the same pattern
    `Renderer.drawSortedObject()` uses to redraw walls over objects partly behind them.
- **Roll:**
  - *Shear* (move each column's horizon) is free and fine to ~30°, but objects stay upright.
  - *Rotate* renders the level view into a square as wide as the screen's diagonal (~15% more columns),
    then rotates it onto the screen in one blit, as `SceneObjectPlane` does. Any angle works and
    objects rotate with it. It costs 4-6 fps at the higher levels, little at the lower ones.
- **Standing on the terrain:** `heightAt(x, y)` is the lookup objects and the camera use.
- **Loading time:** generating a 256x256 map takes ~1.3 s on the Ultra, a watchdog risk on slower
  devices. Loading a binary map (`roByteArray.ReadFile`) is the likely fix.

## Verdict

**Go**, as a low-resolution, retro-look terrain drawable. A flight sim at ~30 fps on the Ultra fits
50-80 columns with coarse steps (basic to medium). Expect the Express to be 2-3x slower (not measured).

Turning it into an engine drawable that any game can use is follow-up work: a map class and generator,
a fixed-stage scene object driven by `Camera3d`, a `drawSortedObject()` hook to redraw nearer spans over
objects, and `RenderQualitySettings` fields for columns and steps per band.
