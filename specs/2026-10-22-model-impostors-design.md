# Model impostors (#345)

Status: investigation, not implemented.

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

## Expected gain, and what to measure first

If the impostor held for most moving frames in terrain, the chapel's ~13ms would drop to
under 1ms (scale fit) or ~4.5ms (corner pin) - roughly 8-12ms of a ~73ms moving frame.
The unknown is the hit rate: how many moving frames stay under the tolerance and angle
limits along terrain's profile path. The first prototype step should be to compute the
fits and log hit rates per tolerance, without drawing through them, using the existing
`profile=stages` path.

## Not covered

- Impostors for non-model objects. Billboards are already single blits.
- Rendering far models into a shared atlas, or at lower resolution.
- Making the corner pin itself cheaper.
