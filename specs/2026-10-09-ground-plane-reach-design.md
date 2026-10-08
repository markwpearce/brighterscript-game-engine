# Ground plane reach (issue #307)

## Problem

In `examples/terrain`, distant trees and guards stand above the ground's far edge, as if
floating in the sky. Two separate causes:

1. **The far edge is a circle, objects are clipped at a flat depth.** When the camera's top
   frustum rays miss the ground (a level or upward-looking camera, WorldScene's default),
   `SceneObjectPlane.getPerspectivePointsByCamera()` builds the far corners by rotating
   `cameraPointOnPlane + projectedForward * F` by +/-hFOV/2. Those corners sit on a circle of
   radius F, so straight ahead the ground only reaches a forward depth of F*cos(hFOV/2): 707
   at F = 1000 and 90 degrees. `Camera3d.isInView()` clips objects at a forward depth of F, so
   everything 707-1000 units away stands past the ground edge, at every quality level.
   (1280x720, camera height 50: ground edge at canvas y 405, an object at depth 1000 at 392.)
2. **Objects outreach the ground at High/Ultra.** Objects clip at
   `getEffectiveMaxDrawDistance()` (`maxDrawDistance` x the level's `drawDistanceScale`,
   1.25/1.5 at High/Ultra), while the plane uses `getPlaneDrawDistance()`, which ignores the
   level (#251) so the horizon doesn't jump and the plane's bitmaps don't grow with distance
   squared.

## Rule

Objects that belong on the ground are never drawn above it: the ground always reaches at
least as far as any object can be drawn, and objects fade out (#125) inside its edge.

## Goals

- The ground's far edge is the same forward-depth plane objects are clipped at.
- The ground reaches the farthest distance any quality level would draw objects, fixed
  across level changes (the horizon doesn't move when the level changes).
- Object clipping never exceeds the ground's reach, even transiently.
- Plane memory and draw cost stay at today's default.

## Non-goals

- Fading the ground's own horizon.
- The slice wedge's near-distance mismatch (rows assume depth 0, the quad starts at the
  bottom ray's hit). Pre-existing and unrelated to floating.
- `SceneObjectSkybox`, parallax layers, `Camera2d`.

## Design

### 1. Far edge on the forward-depth plane (`SceneObjectPlane.getPerspectivePointsByCamera`)

Replace the rotated-circle fallback. With `F = camera.getPlaneDrawDistance()`, `projFwd` the
normalized camera forward projected onto the plane, and `right` the plane-projected level
right vector (perpendicular to `projFwd` on the plane):

- depth along `projFwd` to reach forward depth F:
  `d = (F - dot(cameraPointOnPlane - camera.position, orientation)) / dot(projFwd, orientation)`
  (d = F for a level camera)
- `farCenter = cameraPointOnPlane + projFwd * d`
- `halfWidth = F * tan(hFOV / 2)` (the frustum's half width at forward depth F)
- `topLeft = farCenter - right * halfWidth`, `topRight = farCenter + right * halfWidth`.
  Same handedness as today: `topRight` is rotated by -hFOV/2 about the plane's +y normal,
  which takes forward (0,0,-1) to +x, the camera's right.

Apply when a top ray misses the ground **or** hits it past forward depth F (camera pitched
slightly down), so the quad never reaches past what the pre-perspective bitmap covers.
Bottom corners keep today's behavior. The rolled branch uses the same formula with its level
vectors and enlarged FOV. This matches what `getPrePerspectiveBmp()` (a 2F*tan x F wedge) and
the slice pass already assume, so the warp's `horizScale` becomes ~1.0.

### 2. Ground reach = the highest level's distance

- New `Camera` fields, pushed every frame by `Renderer.setupCameraForFrame()` next to
  `drawDistanceScale`/`drawDistanceOverride`: `planeDrawDistanceScale as float = 1.0` and
  `planeDrawDistanceOverride as float = 0.0`.
- New `Renderer` fields `planeDrawDistanceScale`/`planeDrawDistanceOverride`, defaulting to
  the renderer's own `qualitySettings` values (so a `Renderer` without a `Game`, e.g.
  `examples/rendererTest`, behaves as today at its own level).
- `RenderQualityManager` sets them on its renderer to the **largest** `drawDistanceScale`
  and the largest `drawDistanceOverride` across all five levels' settings (presets plus
  `overridePreset()` overrides), recomputed whenever presets are overridden. All five levels,
  not just the adaptive range, so `setQualityLevel()` never moves the horizon either.
- `Camera3d.getPlaneDrawDistance()` becomes
  `max(maxDrawDistance * planeDrawDistanceScale, planeDrawDistanceOverride, getEffectiveMaxDrawDistance())`,
  then device-capped (`getMaxDrawDistanceDeviceCap()`). The `getEffectiveMaxDrawDistance()`
  term guarantees the invariant even if a game sets `drawDistanceScale`/`drawDistanceOverride`
  on the camera directly. Taking the max scale and max override independently can
  overestimate (a level with both); overestimating only makes the ground reach farther.
- Level changes don't change `getPlaneDrawDistance()`, so plane bitmaps aren't rebuilt and the
  horizon doesn't move.

### 3. Object clipping never exceeds the ground

`Camera3d.getCurrentDrawDistance()` returns `min(eased distance, getPlaneDrawDistance())`. In
steady state the eased distance is already <= the plane distance, so nothing changes; it only
bites right after a game shrinks `maxDrawDistance` (the ground shrinks at once, the eased
object distance would otherwise linger beyond it for up to `drawDistanceTransitionSeconds`).
The fade band follows the capped value, so objects fade out inside the ground edge.

### 4. Pixel budget for the pre-perspective bitmap

`getPrePerspectiveBmp()` is 1 px per world unit: `2F*tan(hFOV/2)` x `F`. Cap its pixel count at
today's default (F = 1000, 90 degrees: 2000 x 1000 = 2,000,000 px) with a uniform resolution
scale `s = min(1, sqrt(2000000 / (width * height)))` applied to both dimensions. Everything
downstream already works in the bitmap's own pixel units (`populatePerspectiveBmp()` derives
its scales from the destination region's size; the slice pass derives depth from the bitmap
height and width from depth x tan), so no other change is needed except scaling
`SCENE_OBJECT_PLANE_NEAR_DISTANCE` (0 today) by `s` if it's ever nonzero. The tiled
supertexture already caps its own size (`getMaxSuperTextureDimension()`), and its scratch
bitmap scales with `superTextureScale`.

Tradeoff: under a `Game` the ground reaches the highest level's distance at **every** level
(that's what keeps the horizon fixed), so on real FHD hardware with terrain's defaults the
ground is 1500 deep at all levels, Medium included: the top-down bitmap samples at 0.67 px per
world unit and the tiled grass supertexture is ~28% softer, with a one-time build about twice
as long. Memory and per-frame draw cost match today's default. The simulator is unaffected
(its 900 device cap was already the limit). (Corrected after review: an earlier draft said
Medium was unchanged, which contradicted the fixed-horizon goal.)

A static decal's rotated texture now goes into its own scratch bitmap sized to the rotated
decal (grow-only, at most ~1.41x the texture's size), shifted so the whole decal fits. The
texture-sized pooled scratch it used before only held the part of the decal within one
texture-width of the quad's far corner, so with the longer reach the decal mostly vanished.

### 5. Docs

- CLAUDE.md: update the `maxDrawDistance`, render quality and `SceneObjectPlane` bullets
  (ground reach = highest level's distance; the depth-plane far edge; the pixel budget; the
  plane cap on `getCurrentDrawDistance()`). Remove the stale claim that the plane uses the
  effective distance.
- `docs/drawables-and-scene-objects.md`: the plane section's reach and the draw-distance fade
  section's note that objects always fade inside the ground.

## Testing

Rooibos (headless):

- **Far edge vs. objects (the repro):** `Game(1280, 720)`, `Camera3d` at (0,50,0) looking -z,
  `maxDrawDistance` 1000, a color-fill `DrawablePlane` at the origin, a point at (0,0,-950):
  `isInView` is true and the ground far edge's canvas y (`worldPointToCanvasPoint` of
  `perspectivePoints.actual.topLeft`) is <= the point's canvas y. Fails today (405 vs 394).
- **High/Ultra:** with a `RenderQualityManager` at Ultra, a point at depth 1400 is in view and
  the ground's far edge is still at or above it on screen.
- **Fixed horizon:** `getPlaneDrawDistance()` is the same at every level once the manager has
  pushed its max scale; changing level doesn't change it.
- **Invariant:** `getPlaneDrawDistance() >= getEffectiveMaxDrawDistance()`, including with a
  per-level `drawDistanceOverride` and with `drawDistanceScale` set directly on the camera.
- **Clip cap:** after shrinking `maxDrawDistance` mid-transition, `getCurrentDrawDistance()`
  is <= `getPlaneDrawDistance()`.
- **Pixel budget:** the pre-perspective bitmap's width x height <= 2,000,000 at F = 1500, and
  unchanged (2000 x 1000) at F = 1000.
- **Pitched down:** a top-ray hit beyond forward depth F is pulled back to depth F.

On device (`rokubot-examples`):

- terrain at Medium and Ultra (pinned): back up for ~7s, screenshot; nothing stands above the
  ground edge.
- Parked/moving FPS at Ultra vs. `main`.
- A quality change with adaptive on: the horizon doesn't move.
