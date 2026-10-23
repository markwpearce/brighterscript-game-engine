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
  no impostor path.
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
level: `modelImpostorError` (error allowed as a fraction of the model's on-screen diagonal,
2px at least, capped at the model's 64px reuse threshold for an occluder only), `modelImpostorMaxZoom` (how far
the bitmap may be enlarged) and `modelImpostorMaxAngleDegrees` (how far the view direction
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
