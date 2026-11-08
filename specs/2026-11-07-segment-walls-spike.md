# Segment walls spike (#468): results

## Question

Can one kind of wall replace both `DrawableGridWalls` (raycast grid mazes, cost per screen
strip) and `DrawableWall` (one sorted quad per wall, cost per wall), and handle walls at any
angle with their own heights, so a level can be loaded as data?

## What was built

`examples/rendererTest`'s `segment-walls` demo (`Tests/SegmentWalls/`): a prototype
`SegmentWallRenderer`. Walls are 2D floor segments, each with a foot and top height, a
texture, tile width and stacked tile count, one- or two-sided.

It doesn't cast rays against the level. It projects segments onto the same strip fan
`GridWallsView` uses, DOOM-style:

1. Segments facing the camera and inside the fan get their ray range from the tangents of
   their (near-clipped) endpoints, and are sorted by their nearest point.
2. They're walked nearest first. Per ray in range, the ray/segment intersection is one divide
   (numerator and denominator are linear in the ray's tangent), then the foot and top are
   projected through `worldToCamera`, as `GridWallStripBuilder` does.
3. Each ray keeps an open window of elevation slopes, `(height - eye) / forward depth`. It
   starts at "nothing below, the screen's top edge above". A wall standing on the lowest floor,
   or covering the window's bottom, raises the bottom to its top. A wall covering the window's
   top lowers the top to its foot. A ray whose window closes costs nothing more, and when every
   ray is closed the walk stops. A short wall leaves the window open above it, so taller walls
   behind still draw: several hits per ray come for free.
4. **This is exact at any pitch.** Every wall point on one ray's bearing lies in one vertical
   plane through the eye, which projects to one screen line, so a 1D window along that line is
   exact.
5. Visible pieces are recorded front to back and drawn back to front. A piece partly behind a
   nearer short wall is drawn whole and painted over, and wholly hidden pieces are skipped.
   Strips wholly off the canvas are skipped, as in the grid builder.
6. Stacked vertical tiles are pre-composed into one tall column texture, so each strip is one
   draw. Drawing one strip per tile doubled the draws on 8 m walls.

`map=grid` loads the grid-walls maze as 21 merged segments, and `walls=engine` draws the same
maze with `DrawableGridWalls` for comparison. `map=hall` is 38 segments: 8 m outer walls,
6 m pillars, a 12 m tower, a 4 m room with a doorway, and 1 m and 2.5 m walls, some at angles.

## Results (Roku Ultra, camera turning, pitch sweeping 15° up to 35° down)

fps at three pitches; draws in brackets.

| map / walls | level | -35° | -22° | -10° |
| --- | --- | --- | --- | --- |
| grid / engine `DrawableGridWalls` | Basic | 46.9 (121) | 39.1 | 50.7 |
| grid / segments | Basic | 60.6 (124) | 61.0 | 62.4 |
| grid / engine | Medium | 28.9 (236) | 28.6 | 32.8 |
| grid / segments | Medium | 34.9 (241) | 34.4 | 45.3 |
| grid / engine | Ultra | 15.9 (466) | 15.7 | 20.2 |
| grid / segments | Ultra | 22.9 (475) | 21.8 | 28.9 |
| hall / segments | Basic | 60.3 | 63.2 | 62.4 |
| hall / segments | Medium | 32.9 (221) | 38.8 | 40.7 |
| hall / segments | Ultra | 18.4 (490) | 22.7 | 24.1 |

- On the same maze, segments are about 20-45% faster than grid walls at every level, with
  the same strip count. At Medium, walls take about 16 ms per frame vs 26 ms (engine:
  cast+build+shade 20.7 ms plus strips 5.4 ms).
- The cost is per ray actually reaching a wall, not per segment: `visited` was 2-9 segments
  per frame.
- The hall's extra cost over the grid is several hits per ray: low walls in front of tall
  ones. That's the expected cost of mixed heights.
- With a still camera, the engine's grid walls reuse their cast, and the prototype doesn't
  yet (the grid at Medium: 62 fps engine vs 53 fps segments).
- Projection and window work (`cast`) is now about two-thirds of the wall time, and the draw
  calls are the rest. At 35° down the fan reaches well past the canvas, and those rays are
  still intersected and projected before the off-canvas cull.

## Recommendation

Build it out as the one wall system, replacing both:

- **`BGE.WallSegments` (data) + `BGE.DrawableWalls` (drawable) + `SceneObjectWalls`**, drawn
  in the existing `gridWalls` stage (rename it `walls`).
- **`GridWallsMap` stays as authoring.** It gains `toSegments()`, merging edges as the demo's
  `gridSegments()` does. `DrawableGridWalls` becomes a thin wrapper, then is deprecated.
- **`DrawableWall` folds in as a segment.** For a few walls on entities that move (doors),
  keep a dynamic flag that re-sorts those segments each frame; static ones use a 2D BSP
  built once.
- **Reuse the grid-walls pieces unchanged in spirit:** strip width and light interval
  quality settings, the per-face light cache (per segment bucket), the far-to-near draw, and
  the per-strip depth buffer for hiding sprites and `drawWorld*`. The buffer becomes a window
  per strip, so a sprite above a low wall still shows.

Production work the spike skipped, in priority order:

1. **Cache the walk while the camera is still**, as grid walls do (the main gap above).
2. **Exact ordering:** a 2D BSP built once. Sorting by nearest point is wrong for some
   overlapping layouts.
3. **Sprite hiding against the windows**, with the partial-hide redraw.
4. **Trim the fan to the canvas** before intersecting, which matters most when pitched down.
5. **Light invalidation** on `lightingVersion`, and distance fade (the prototype fades but
   never relights).
6. Later: per-sector floors and ceilings, wall tops seen from above, and a level file
   format/loader.
