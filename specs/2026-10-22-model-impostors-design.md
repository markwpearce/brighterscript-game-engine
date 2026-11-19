# Model impostors (#345)

Status: experimental prototype (`DrawableModel.useImpostor`, see [Prototype](#prototype-draft-350)).
The hit-rate probe (see [Results](#results)) said it isn't worth it for terrain's chapel at a
fixed px tolerance; in `examples/3d`'s car scene it cuts a moving frame from ~330ms to ~20ms.
The Design and Settings sections below are the original plan - the prototype section says
what was actually built.

## Problem

In `examples/terrain` (Roku Ultra, `--param profile=stages`, fastShrink policy) a moving
frame is ~73ms, and the one chapel model is ~13ms of it: ~9-12ms in
`SceneObjectModel.performDraw()` (per-face rasters, with per-face reuse) plus ~4ms in
`updateCanvasPosition()` projecting every vertex and rebuilding the face list. Still
frames cost it ~0.1ms, because the whole-model temp bitmap is reused.

A model already renders into a temp bitmap, and `SceneObjectModel.attemptTransformTempBitmap()`
can reuse it while moving - but only for a pure zoom (rotation under 0.001 rad, scaleX
within 1% of scaleY), judged from the silhouette's left/top/right/bottom extreme points.
That almost never passes while the camera strafes or turns, which is most of terrain's
movement, so the reuse path is effectively still-only.

## Measured blit costs

`rendererTest`'s `impostor-blit-benchmark`: a 360x300 source drawn into an offscreen
1280x720 bitmap, `Finish()` inside the timing, Roku Ultra.

| draw | ms each |
| --- | --- |
| `DrawScaledObject`, non-uniform scale | ~0.03 |
| `DrawTransformedObject`, rotate + scale | ~0.02 |
| `drawPinnedCorners`, slightly skewed quad | ~4 |
| `drawPinnedCorners`, the same quad rotated 20 degrees | ~5.3 |

The scaled blits are at the timer's resolution, so treat them as "well under 0.1ms".
`circle-fast-draw-benchmark` still measures ~111ms per exact pinned 120px circle panel
(re-run on the same device), so something in that path - the 400px circle resource, or
how its triangles hit the triangle cache - is far costlier than a pin of a plain bitmap.
Worth its own look; it doesn't apply here.

So reusing the bitmap is a big win even through the exact corner pin (4ms vs ~13ms), and
a near-free one when an axis-aligned scale is close enough.

## Design

### Capture

When a model draws fully fresh (every face rasterized this frame - `lastDrawWasFullyFresh`),
keep, alongside the temp bitmap:

- the camera pose it was drawn from (position, orientation, roll)
- a set of world-space sample points with their canvas positions at capture - the 8 world
  bounding box corners (`modelWorldBounds`), optionally plus the convex hull vertices
- the temp bitmap's canvas origin

The sample points are fixed 3D points, so they're true correspondences between the
capture view and the current one. The current check uses silhouette extreme points, whose
identity changes as the model turns, which is why it has to refuse any rotation.

### Reuse attempt, each frame the model or camera moved

1. Project the sample points at the current view (`Camera3d.projectPointsWithDepth()`,
   8 points - much cheaper than the full `updateCanvasPosition()`). Any point that won't
   project: redraw.
2. Fit, cheapest first, a mapping from capture canvas positions to current ones, and
   measure the worst residual over the sample points:
   - **scale + translate** (least squares per axis, `x' = sx*x + tx`, `y' = sy*y + ty`) -
     drawn with `DrawScaledObject`
   - **rotate + scale + translate** - `DrawTransformedObject`, for camera roll
   - **corner pin** - fit an affine (or projective) map from the 8 correspondences, map
     the bitmap's 4 corners through it, and `drawPinnedCorners` onto that quad
3. Take the first fit whose worst residual is under the tolerance. Otherwise redraw fully,
   which refreshes the capture.

The residual measures parallax: a fit is exact for points on one plane, and error grows
with the model's depth extent and how far the view has moved. Points inside the bounding
box move smoothly between the corners, so the corners' worst error is a reasonable bound
for what's drawn (not a strict one - a concave model's interior can do slightly worse).

### Limits beyond the residual

- **View angle**: which faces are visible, their self-occlusion and `isShaded` brightness
  (it's camera-facing, see `getOutwardNormalFacingAmount`) all depend on the direction from
  the camera to the model. Redraw once that direction has turned more than a few degrees
  from capture (a `RenderQualitySettings` knob), even if the silhouette still fits.
- **Staleness**: a separate frame limit, so a model is redrawn fully every N frames anyway.
  Not `DrawableModel.maxStaleFrames` - that defaults to 1 for per-face reuse, which would
  redraw the impostor every other frame.
- **Quality**: a `qualityVersion` change redraws, as today.
- **Occluders**: a `fastShrink` occluder's claim already shrinks by the stretch threshold
  while it may run (`getOccluderInset()`); add the impostor tolerance there. `exact` takes
  no impostor path. (Since #486 it shrinks only on frames that blit the capture, by that
  frame's fit error + 1px; redrawn faces are exact.)
- **Clusters**: a model in a multi-member overlap cluster draws per face
  (`drawPrimitive`), so it never uses the impostor - unchanged.

### Settings

Two new `RenderQualitySettings` fields (values at all five levels, monotonic):

- `modelImpostorTolerance` (px) - looser at low quality. Probably ~2 at Ultra up to ~8 at
  Basic, to be tuned on device.
- `modelImpostorMaxAngleDegrees` - the view-direction limit above.

With the tolerance at 0 the feature is off and behavior is today's.

### What replaces what

This would replace `SceneObjectModel.attemptTransformTempBitmap()`'s pure-zoom check
(the scale + translate fit covers a pure zoom with residual 0), not sit beside it. The
per-face raster reuse (`drawFaceWithReuse()`) stays as the next fallback after the
impostor and before a full redraw.

## Expected gain, and what to measure first (before the probe)

If the impostor held for most moving frames in terrain, the chapel's ~13ms would drop to
under 1ms (scale fit) or ~4.5ms (corner pin) - roughly 8-12ms of a ~73ms moving frame.
The unknown is the hit rate: how many moving frames stay under the tolerance and angle
limits along terrain's profile path. The first prototype step should be to compute the
fits and log hit rates per tolerance, without drawing through them, using the existing
`profile=stages` path.

## Results

`examples/terrain` `--param profile=impostor` (`ImpostorProbe.bs`, fits from
`BGE.ImpostorFit`) flies the profile path once with fastShrink and, for every moving frame,
simulates the reuse loop above without drawing through it: fit the capture to this frame,
take the first fit under the tolerance, otherwise count a redraw and recapture. Roku Ultra,
the chapel on screen every moving frame (~12fps along this path):

| samples | tolerance | scale | rotate | pin | redraw | est. chapel ms/frame (vs 13) |
| --- | --- | --- | --- | --- | --- | --- |
| box corners | 1px | 5% | 0% | 1% | 93% | 12.2 |
| box corners | 2px | 14% | 0% | 1% | 84% | 11.1 |
| box corners | 4px | 27% | 0% | 0% | 72% | 9.5 |
| box corners | 8px | 48% | 2% | 1% | 49% | 6.7 |
| model vertices | 1px | 3% | 2% | 0% | 94% | 12.3 |
| model vertices | 2px | 15% | 0% | 0% | 85% | 11.1 |
| model vertices | 4px | 26% | 1% | 0% | 73% | 9.7 |
| model vertices | 8px | 45% | 0% | 0% | 54% | 7.3 |

The estimate uses 13ms for a redraw, 4.5ms for a pin and 0.5ms for a scaled blit.

- The view-angle limit (2, 5 and 10 degrees in a first run) never decided anything - the
  pixel tolerance always ran out first.
- The corner pin almost never rescues a frame the scale fit missed. The error isn't a 2D
  warp but parallax: the chapel is big and close (~330 units tall at ~300 away), and the
  camera moves several units a frame here, so its near and far parts slide apart within a
  frame or two.
- Fitting every vertex instead of the box corners gives the same answer, so the box isn't
  what makes it pessimistic.
- At a tolerance that wouldn't show (1-2px) it saves ~1-2ms of a ~73ms moving frame. 4px
  saves ~3.5ms, 8px ~6ms, but a model jumping 8px when it's redrawn would be visible.

So it isn't worth building for a model like the chapel. It would pay for models that are
small or far away on screen (less parallax per unit of camera motion), and at higher frame
rates (less motion per frame) - neither is where terrain spends its time. If it's revisited,
gate it on the model's depth extent relative to its distance, and drop the corner pin -
the scale fit does nearly all the work.

## Not covered

- Impostors for non-model objects. Billboards are already single blits.
- Rendering far models into a shared atlas, or at lower resolution.
- Making the corner pin itself cheaper.

## Prototype (draft #350)

`DrawableModel.useImpostor` (experimental, on by default; set it false to use per-face reuse instead). The limits come from the quality
level: `modelImpostorError` (error allowed as a fraction of the diagonal of the part of the model's box on the canvas,
2px at least, capped at the model's 64px reuse threshold for an occluder only), `modelImpostorMaxSizeChange` (how far
the bitmap may grow or shrink; was `modelImpostorMaxZoom`, enlarging only, until #486) and `modelImpostorMaxAngleDegrees` (how far the view direction
may turn) - no frame limit. A reused frame projects only the 8 box corners, not every
vertex. A quality step down keeps the reused rendering; only a step up redraws it. It's
off while `Renderer.computeOverlapClusters` is on (clusters draw per face), and never used
by an occluder under the `exact` policy. Only scale + translate is drawn - no rotation, no
corner pin - and the model itself moving or turning still redraws it.

`examples/3d` CarScene, holding up/down, Roku Ultra at a fixed Ultra level:
~330ms per moving frame with the impostor off, ~80ms with it on before the projection
skip, ~42-46ms after. Some runs came in at 100-150ms: per-face raster reuse was still
running for a non-occluder, and a frame that reused any face couldn't be captured. With
that off (as intended), three runs with adaptive quality on came in at 19.5-20ms.

## Two-level fit (draft, follow-up to #350)

The reuse now tries two fits, each with its own limits in `RenderQualitySettings`:

1. Scale + rotate + translate (`BGE.ImpostorFit.fitRotateScale`) against the 8 box corners,
   drawn with one `DrawTransformedObject`. `modelImpostorError` is a little tighter than
   #350's (0.03 at Ultra to 0.10 at Basic).
2. If that misses, a corner pin of the cached bitmap (`drawPinnedCorners`, top left to
   bottom right diagonal), fitted against the visible faces' outline (their canvas convex
   hull, up to 24 points, captured with the rendering). `fitPinnedCorners` solves for all
   4 corners at once by least squares, each point weighted into the pin triangle it falls
   in, so the two triangles always agree along the diagonal. Limits:
   `modelImpostorPinError` (0.05 at Ultra to 0.16 at Basic) and
   `modelImpostorPinMaxAngleDegrees` (6 to 16). The pin's two triangles are cached under one
   id per model, dropped when the rendering is recaptured.

`DrawableModel.useImpostorPin` (default true) turns the pin off; `examples/3d` deep link
`pin=0`. `quality=<0-4>` pins the quality level, and the scenes print
`[3d moving] <scene> frames= avgMs=` each time the camera stops.

`examples/3d` CarScene, Roku Ultra, `quality=4`, scripted holds (up, down, x3, 3s each), ms
per moving frame weighted by frames, three runs per setting:

| | runs | zoom in holds | zoom out holds |
| --- | --- | --- | --- |
| pin on | 45, 41, 41 | 25-34 | 45-106 |
| pin off | 56, 52, 54 | 33-44 | 68-162 |

About 20-25% faster with the pin, most of it on the way out. How it looks while pinned
hasn't been checked by eye yet.

After the review fixes (lazy outline, hull pre-filter, indexed triangle cache), same script,
two runs each: pin on 47, 44; pin off 54, 43. The runs are noisy enough that the pin's edge
is now within the spread - zooming out with the pin still has 64-100ms holds, which are
full redraws (#352).

## Tighter limits and a four-triangle pin (#360)

With #345 cutting model texture memory, the limits were tightened so models redraw more:

- High/Ultra view angle 6°/4° → 3°/2°, max zoom 3x/2.5x → 2x/1.5x.
- High/Ultra no longer corner pin at all (`modelImpostorPinMaxAngleDegrees` = 0 turns the
  pin off); Basic to Medium are unchanged.

The pin is now four triangles meeting at a fitted centre (`drawPinnedCorners` with
`splitIntoFour` and `center`) instead of two along the top left to bottom right diagonal.
`fitPinnedCorners` solves for 5 points (4 corners + centre) the same way. A free centre
follows perspective foreshortening better: worst-case error on a 9x7 grid of a bitmap seen
with its far edge 1.1x / 1.25x / 1.5x / 2x as far away drops from 3.9 / 9.4 / 17.5 / 30.8px
to 2.9 / 6.9 / 12.3 / 20.4px (200x150 bitmap). It costs 4 triangle warps instead of 2.

Review follow-ups: a pinned impostor's bounds now include every breakpoint of the pin
(`ImpostorFit.mapPinnedRect()`: where the bounds' edges cross the pin's triangle edges, and
the centre), the zoom limit is checked against the pin's most stretched triangle edge
(`pinMaxStretch()`), and the four-triangle pin is a quality setting,
`modelImpostorPinFourTriangles` - off at Basic, which keeps the cheaper two-triangle pin.

## Pin removed; columns while turning (#451)

With textured faces drawn as texture columns (#450), a fresh redraw got 3-6x cheaper, and the
pin stopped paying for itself. rendererTest's `model-faces-benchmark` on a Roku Ultra, camera
orbiting still models, ms per frame:

| scene | columns, no impostor | impostor with pin | impostor, rotate only |
|---|---|---|---|
| 4 cubes (12 faces each) | 35.5 | 42.8 | 19.3 |
| 9 cubes | 81.3 | 145.3 | 32.6 |
| sphere (176 faces) | 73.6 | 30.6 | 17.7 |

The pin's four triangle warps cost more than redrawing the faces as columns, so it was removed
(`useImpostorPin`, the `modelImpostorPin*` quality settings, `ImpostorFit.fitPinnedCorners()`
and its helpers). The rotate-scale impostor stays: one `DrawTransformedObject` beats any face
redraw.

A model that moves or turns itself can't use a capture, so it now draws its textured faces
straight to the canvas as columns, as a model without an impostor does, instead of into its
temp bitmap and then blitting that. Once its transform stops changing, it draws into the temp
bitmap again for the impostor to capture. Spinning in place, 4 cubes with an impostor went from
53.5 to 46.2 ms (42.1 without one) and 9 cubes from 114.9 to 101.7 ms (94.7). With the camera
orbiting, the rotate-only impostor takes 17.6 / 28.6 / 19.5 ms for the three scenes, against
35.6 / 81.6 / 74.9 ms without one.

## Vertical strips with hint points (#556 spike)

Idea: when one rotate-scale map misses, redraw the capture as vertical strips, Doom style.
Capture x maps to current x, and each column gets its own vertical scale and offset, all
linear in capture x between knots. That's exact for vertical walls under a camera that only
turns and moves, so it should catch the two faces either side of the near corner turning
opposite ways, which a single map can't. `BGE.ImpostorFit` gained `fitColumnsToEdges()` (knots
from vertical edges' tops and bottoms), `fitColumns()` (least squares for given knots),
`mapColumns()`, `columnsResidual()` and `columnSegmentStrips()` (strips needed to keep each
strip's single scale within a step of the warp).

`profile=impostor` now also runs "front" variants. Each measures error on the vertices of the
faces that faced the camera at capture, since only those are in the bitmap. `front-rot` is a
single rotate-scale blit; `strip-edge` tries that, then strips hinted by the world box's
visible vertical edges (the two outermost on screen plus the nearest, which is the crease);
`strip-lsq` uses the same knots but least-squares fits the strips to every front vertex (an
upper bound - it projects every vertex, which defeats the point). Strips are costed at 0.4ms
each (one region `DrawScaledObject`, from the draw2d benchmark's ~2.5k/sec), with a 1px strip
step.

First run headlessly in brs-cli (the path is frame-indexed and these are pure geometry), then
rerun on a Roku Ultra: every row matched to within a few percent, so the table holds for both.
The device's 8px rows ran slightly higher on strips (strip-lsq max 23). Share of moving frames:

| variant | tolerance | single blit | strips (avg / max) | redraw | est. ms/frame (vs 13) |
| --- | --- | --- | --- | --- | --- |
| box (today) | 1px | 7% | - | 93% | 12.2 |
| box (today) | 2px | 16% | - | 84% | 11.0 |
| box (today) | 4px | 27% | - | 72% | 9.5 |
| box (today) | 8px | 51% | - | 50% | 6.7 |
| front-rot | 1px | 6% | - | 94% | 12.3 |
| front-rot | 2px | 17% | - | 83% | 10.9 |
| front-rot | 4px | 30% | - | 70% | 9.3 |
| front-rot | 8px | 52% | - | 48% | 6.5 |
| strip-edge | 1px | 6% | 0% | 94% | 12.3 |
| strip-edge | 2px | 17% | 1% (3 / 3) | 82% | 10.8 |
| strip-edge | 4px | 27% | 6% (4.1 / 6) | 67% | 9.0 |
| strip-edge | 8px | 50% | 4% (7.2 / 11) | 46% | 6.4 |
| strip-lsq | 1px | 5% | 3% (2.8 / 4) | 92% | 12.0 |
| strip-lsq | 2px | 12% | 13% (3.7 / 7) | 74% | 9.9 |
| strip-lsq | 4px | 23% | 15% (6 / 13) | 62% | 8.5 |
| strip-lsq | 8px | 35% | 27% (9.3 / 17) | 38% | 6.2 |

- Box-edge hints barely help: at most 6% more frames reuse, ~0.3ms of the chapel's 13ms.
- Even the impractical least-squares bound saves ~1ms at 2px, where it reuses 9 more frames in
  100. At the 1-2px that wouldn't show, ~75-90% of moving frames still redraw.
- The strip counts climb with tolerance (avg 4-9, up to 17), so a looser strip pays back much
  of what it saves.

The column model isn't what fails. The error is still parallax inside the model (the steeple,
roof and porch sit at different depths from the walls the box edges hint), and along this path
the camera moves enough a frame that it shows within a frame or two - the same finding as the
scale fit above. So strips aren't worth building for the chapel. They'd fit a wide, boxy, mostly
vertical model seen from a camera turning more than moving; the fits and the probe stay for
measuring one.

### Prototype: drawing the strips (#556)

`DrawableModel.useImpostorStrips` (off by default) tries strips when the single blit misses,
tuned by `impostorStripStepPx`, `impostorStripWidth`, `impostorStripKnots` (0 = box-edge
hints, N = N evenly spaced knots least-squares fitted to the visible vertices),
`impostorStripMaxError`, `impostorStripMaxStrips` and `impostorStripMaxAngleDegrees` (strips
may be tried past the single blit's view-angle limit). Each strip is a region of the capture
drawn with `DrawTransformedObject` (no rotation), 1px wider to hide seams. terrain and
thirdPerson take them as deep links (`strips=1 stripKnots=3 stripAngle=20 ...`); terrain's
profiler also prints what the chapel's impostor did each moving frame and why it missed.

Terrain chapel, Medium (the device's seeded level), moving frames:

| config | single blit | strips (avg strips) | redraw | main miss reasons |
| --- | --- | --- | --- | --- |
| strips off | 79% | - | 21% | view angle 39 of 49 |
| box edges | 78% | 1% (10.5) | 21% | view angle 39 |
| box edges, stripAngle 20 | 75% | 5% (11.6) | 20% | strip error 38 (31px vs 25px allowed) |
| 5 knots, stripAngle 20 | 79% | 0% | 21% | stretch/scale 30, unfittable segment 17 |
| 3 knots, stripAngle 20 | 57% | 26% (15.4) | 17% | strip error 30 |

The real impostor's error allowance (a fraction of the model's size on screen) is far looser
than the probe's 1-8px, so the single blit already covers ~79%. Strips cut redraws by at most
4 points, and each strip frame costs ~15 draws instead of one; keeping a capture alive longer
also makes the single blit fit less often.

thirdPerson town, `orbit=0.4 perf=phases`, Basic (quality=0), Roku Ultra, ms per frame (last
4 PERF samples of a 50s run):

| config | frame ms | fps |
| --- | --- | --- |
| strips off | 81.8 / 82.0 (two runs) | 12.2 |
| strips=1 (box edges) | 85.4 | 11.7 |
| strips=1 stripKnots=3 stripAngle=20 | 88.2 | 11.3 |

Strips make the orbit 3.5-6ms slower, mostly from attempting a strip fit (projecting the
visible vertices, fitting) on every frame the single blit misses, paid even when refused.

Split per frame (`perf=1` stages): capturing the hints ~2.2ms (≈1.6 captures a frame), fit
attempts ~1.2ms, strip draws ~0.3-0.4ms. Reusing the mesh's projected corners for the hints and
inlining the fit loops cut the overhead to +2.1ms (box edges) and +1.7ms (3 knots).

#### A middle tier, and the view-direction limit

Strips are meant to sit between the single blit and a redraw, so `impostorBlitErrorScale` /
`impostorBlitMaxAngleDegrees` shrink the single blit's allowance and `impostorStripErrorScale`
widens the strips' (deep links `blitScale`, `blitAngle`, `stripScale`). Terrain chapel, Basic:

| config | single blit | strips (avg strips) | redraw | moving ms |
| --- | --- | --- | --- | --- |
| strips off | 92% | - | 8% | 48.5 |
| 3 knots, stripAngle 20 | 90% | 3% (28) | 7% | 48.3 |
| + blitScale 0.5, stripScale 1.5 | 33% | 61% (21) | 6% | 50.4 |
| + blitScale 0.3, stripScale 2 | 21% | 73% (19) | 6% | 50.4 |
| + stripStep 3 | 7% | 90% (11) | 3% | 49.4 |

A capture taken at the edge of the view and reused straight ahead leans (thirdPerson's gate):
the rotate fit absorbs the perspective as a tilt. With strips on, the single blit is now also
limited by the change in the model's direction in camera space (`projectImpostorSamples`'
`viewDirection`), so a turn hands over to strips, which are exact for a camera turn without
pitch. `impostorBlitRollOnly` (deep link `blitRoll`, off) only rotates the blit when the camera
rolled.

thirdPerson orbit, Basic, A/B against main (two interleaved runs each, avg frame ms):

| build / config | frame ms |
| --- | --- |
| main | 81.7 / 81.5 |
| before the view-direction limit: 3 knots, stripAngle 20 | 84.0 |
| before: + blitScale 0.3, stripScale 2, stripStep 3 | 91.7 |
| view-direction limit: 3 knots, stripAngle 20 | 90.3 |
| view-direction limit: + blitAngle 4 | 97.5 |

Every frame strips replace a single blit costs more (a dozen-plus draws instead of one); they
only pay off where they replace a redraw, and at Basic redraws are already rare (6-8%). The view
limit fixes the lean but costs ~6ms more on the orbit. Strips stay off by default.

#### Perspective between hint points

The first prototype interpolated each hint's x, vertical scale and offset linearly in capture
x. Along a flat wall turning in perspective, current x is a projective function of capture x
(the far end squeezes), so features slid along walls and the error grew with the turn. With the
camera only turning and moving (no pitch), a column's vertical scale is its depth at capture
over its depth now, so the fitted scales already carry the depths: `1 / scale` and
`offset / scale` are linear in capture x, and current x is the knots' x weighted by
`(1 - t) / scale0` and `t / scale1`. `ImpostorFit.makeColumnsProjective()` /
`fitColumns(..., projective)` / `fitColumnsToEdges(..., projective)`; the least-squares fit
solves the vertical map backwards (capture y from current y is linear in the unknowns), then x
with the perspective weights. Exact for flat walls between hints; no depths are captured.
`DrawableModel.impostorStripPerspective` (default true; deep link `stripLinear=1` for the
linear fit).

Headless, a 4x4-subdivided cube orbited 10 degrees at 180 units: linear strips leave 3.4px,
perspective strips 1.4px (the capture's vertices are rounded to whole pixels; that's the floor).
At 15-20 degrees that close, the strip stretch limit (`modelImpostorMaxSizeChange`, 1.4x at
Medium) refuses the strips before their error does.

On device (perspective strips are the default; `stripLinear=1` is the first fit):

| run | perspective | linear |
| --- | --- | --- |
| thirdPerson orbit, Basic, 3 knots, stripAngle 25 (main 84.9ms) | 93.7ms | 93.9ms |
| chapel, Basic, 3 knots: blit / strips / redraw | 91 / 2 / 7% | 90 / 3 / 7% |
| chapel, Basic, box edges | 92 / 1 / 7% | 91 / 2 / 7% |
| chapel, Medium, 3 knots | 78 / 11 / 10% | 80 / 10 / 10% |

No change: the strip fits the chapel refuses miss by 45-80px against a 40-64px allowance, far
more than the few pixels perspective accounts for. Most of that error isn't the interpolation
between hints, so something the column model can't represent at all dominates - the likely
suspects are parts at different depths in one column (tower in front of nave, parallax as the
camera moves), sloped roofs, and camera pitch.

#### Tuning in play, and spikes (#557)

thirdPerson's `perf=phases` line now also gives the impostor outcomes (share of drawn impostor
frames that single-blit, draw strips or redraw, and why they missed), the frame-time spread
(median, p90, max, frames over 1.5x the median) and the most redraws in one frame; `runid=`
tags the lines. Roku Ultra, town orbit (`orbit=0.4`), Basic, `stripKnots=3 stripAngle=25
blitAngleScale=0.75`, last 4 samples:

| config | frame ms | p90 / max | blit / strips (avg) / redraw |
| --- | --- | --- | --- |
| strips off | 83-85 | ~101 / 105-130 | 73 / - / 27% |
| stripStep 1.5 | 92-95 | ~110 / 114-151 | 25 / 48% (12.2) / 27% |
| stripStep 2.5 | 90-94 | ~108 / 113-143 | 24 / 52% (10) / 25% |
| stripStep 4 | 89-92 | ~105 / 115-134 | 25 / 50% (7.8) / 25% |
| stripKnots 2, stripStep 2.5 | 89-91 | ~107 / 113-142 | 23 / 53% (9.5) / 24% |

- Strips replace single blits, not redraws: the redraw share barely moves. Most refused strip
  fits are `stripsClipped` (part of the model off the canvas edge), then `stripsError` and
  `stripsCount`.
- They look clearly better: with strips off, houses lean as the camera turns (the rotate fit
  absorbing perspective as a tilt); with strips their verticals stay upright. Wider strips
  (stripStep 4) show slight stair-stepping on roof edges at Basic.
- A steady orbit doesn't spike (0-1 frames in ~35 over 1.5x the median), strips or not.

The stutter is the camera starting to move from still. Stop-start orbit (`orbitPause=3,3`),
adaptive quality, the first 10 moving frames (ms, level) after 3s still at Ultra:

```
191(L4) 349(L4) 275(L3) 168(L3) 188(L3) 219(L1) 89(L1) 104(L1) 101(L1) 134(L0)
```

The quality controller only heard about the move after the first frame drew (it runs after
the buffer swap), then waited a settle and a sample before each step down, and frames over
0.25s weren't counted at all. Now `QualityController` remembers the level in force while the
camera last moved, and `RenderQualityManager.beforeDraw()` (called by `Game` after the update,
before drawing) drops straight to it when the camera starts moving from still
(`Camera.isMovingThisFrame()`); impostors keep their captures through a drop. Same run:

```
82(L0) 96(L0) 77(L0) 85(L0) 91(L0) 96(L0) 73(L0) 64(L0) 65(L0) 75(L0)
```

The first move after a scene starts has no moving level yet, so it still steps down as before.
Climbing back to Ultra once still redraws up to ~11 models in one frame (170-380ms), which
shows less since nothing moves.

#### Cheaper strips that replace redraws (#557)

More knots made it worse: at stripStep 2.5, 4/5/6 knots ran 95/98/101ms with 33/42/49%
redraws, against 3 knots' 94ms and 25%. Evenly spaced knots asked low-poly props for more
than their vertices could pin (fewer than 2 per knot) or left segments empty. Knots now sit
at quantiles of the visible vertices' x, no more than they support (`ImpostorFit.placeKnots()`);
5 knots still lose to 3, but no longer by failing to fit.

Each strip frame cost ~1.2ms fitting and ~1.1ms drawing (~110µs a strip: a new roRegion and four
`mapColumns()` calls). Now `ImpostorFit.stripPlacements()` maps each cut once in one loop, the
strip regions are kept on the capture (its knots are fixed, so the cuts mostly repeat), a fit
uses at most `impostorStripMaxPoints` (48) visible vertices, and a capture clipped to the
canvas margin may draw strips as long as the warped clip rect still covers the frame
(`ImpostorFit.columnsCoverFrame()`), as the single blit already could. Town orbit, Basic,
`stripKnots=3 stripAngle=25 blitAngleScale=0.75 stripStep=2.5`:

| build | frame ms | blit / strips / redraw | stripsClipped per 3s |
| --- | --- | --- | --- |
| strips off | 82-87 | 72 / - / 28% | - |
| strips, before | 91-95 | 23 / 52 / 25% | ~22 |
| strips, now | 87-90 | 22 / 58 / 19% | ~8 |
| strips, now, stripScale 2 | 86-88 | 22 / 62 / 15% | ~9 |

Strips now replace redraws too, for ~3-4ms over strips off, with upright verticals. The 48-point
cap barely mattered here (few of the town's models have more). stripScale 2 showed only a slight
bow along one house's base in screenshots.

Strips are now on by default with the tuned values: `useImpostorStrips = true`,
`impostorStripKnots = 3`, `impostorStripStepPx = 2.5`, `impostorStripMaxAngleDegrees = 25`,
`impostorBlitAngleScale = 0.75`, `impostorStripErrorScale = 2`. They were tuned at Basic in the
thirdPerson town; High/Ultra are untested, and moving them into `RenderQualityPresets` per level
is still to do.

## Strips in a level view, and other accuracy fixes

The column warp is exact only where world verticals project vertical, i.e. for a camera with
no pitch or roll. thirdPerson's chase camera always looks down (~8.5° at rest, more with tilt),
so verticals converge and their lean changes as a model crosses the view; upright strips can't
follow that. Headless, a box corner (~310x200px, left of centre) with knots right on the crease
was off 2.1-2.7px at 8.5° pitch and 5-5.9px at 20°, against ~0 level.

- **Level view**: hints, knots and the fit now live in the camera turned level at the same eye
  (`ImpostorFit.levelBasis()`, no pitch or roll). A strip's corners are mapped capture canvas →
  capture level view → warp → current level view → current canvas (`mapCaptureToNow()`), and each
  strip is drawn turned to follow the line through its middle (`stripTransforms()`), still one
  `DrawTransformedObject`. A pitched turn is exact again (the same corner: < 0.01px).
  `DrawableModel.impostorStripLevel` (default true; deep link `stripLevel=0`) fits on the canvas
  with upright strips instead, as before.
- **Knots**: placed from every visible vertex before the hint points are cut down to
  `impostorStripMaxPoints`, and the cut keeps the outline's leftmost, rightmost, top and bottom
  vertices (`subsetWithExtremes()`), so the outer knots reach the outline and its error is
  measured. With 3+ knots, the inner knot nearest the box's nearest vertical edge moves onto it
  (`snapKnotTo()`): a segment then spans one wall, which the perspective warp is exact for.
- **Cuts**: a projective segment is cut evenly in current x (`levelStripCuts()`), where a flat
  wall's top and bottom are straight, instead of evenly in capture x. The stretch limit still
  checks a segment's average stretch: checking its worst end refused ~5x as many strip frames on
  device (each a redraw) and cost ~8ms on the orbit.
- **Mapping**: views from one eye differ by a 3x3 homography (`homographyBetween()`), kept on
  the capture for its camera to and from its level view, so cuts, strip corners, bounds and
  sample points are mapped in inlined batch loops (`mapPointsCaptureToNow()`).
- **Seams**: a strip's region takes a pixel more of the source past its right edge, drawn at the
  true scale, instead of the strip being stretched a pixel wider.
- **Per level**: `modelImpostorStripMaxAngleDegrees` (25, 25, 25, 15, 10) and
  `modelImpostorStripErrorScale` (2, 2, 2, 1.5, 1.25) are quality settings now; the drawable's
  `impostorStripMaxAngleDegrees` / `impostorStripErrorScale` default to 0 (the level's).
- Hint points are projected exactly rather than taken from the capture's whole-pixel positions,
  which also lowers residuals: the close-orbit linear fit went from ~3.4px to ~1.6px.

thirdPerson town orbit, Basic (`strips=1 orbit=0.4 perf=phases quality=0`), Roku Ultra, same
session, average of the last 5 lines:

| build | frame ms | blit / strips / redraw | stripsError / stripsStretch per 3s |
| --- | --- | --- | --- |
| main | 95.4 | 18 / 63 / 19% | 3-8 / 1-3 |
| level view, worst-end stretch check | 109.7 | 18 / 59 / 23% | 0-1 / 7-17 |
| same, `stripLevel=0` | 108.3 | 18 / 59 / 24% | 4-7 / 5-10 |
| level view, homographies, average stretch | 100.6 | 19 / 61 / 21% | 0-2 / 6-8 |
| same, no crease knot | 101.7 | 17 / 63 / 20% | 1-2 / 1-5 |

So the level view costs ~5ms (~5%) at Basic over main, for strip error that's almost gone; how
it looks needs eyes on the device (`stripLevel=0` for the upright strips).
