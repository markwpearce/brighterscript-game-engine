# Draw-distance fade (issue #125)

## Problem

`Camera3d.isInView()` far-clips with a hard test, `forwardDistance <= getEffectiveMaxDrawDistance()`.
An object crossing that limit appears or vanishes in a single frame. Separately, a render
quality level change (issue #251/#126) rescales the effective draw distance instantly
(e.g. High's 1.25x to Medium's 1.0x), so every object between the old and new limit pops
at once - and with adaptive quality on, that happens whenever the controller steps.

## Goals

- Objects fade out across a band just inside the far-clip instead of popping.
- A change to the effective draw distance (quality level, `drawDistanceOverride`, or the
  game changing `maxDrawDistance`) sweeps the limit smoothly instead of snapping it.
- On by default for every `Camera3d` game, with a single knob to turn it off.
- No re-rasterizing cached bitmaps just because an object is fading.

## Non-goals

- `SceneObjectPlane`'s hard horizon (it uses `getPlaneDrawDistance()`, which already
  ignores the quality level, so it doesn't pop on a level change). Separate follow-up issue.
- `SceneObjectSkybox`, `SceneObjectParallaxLayer` (no meaningful distance) and `Camera2d`
  (no far-clip).
- Fading for any reason other than draw distance (near-clip, occlusion).

## Approach

The camera owns an eased *current* draw distance and a fade band derived from it. Each
`SceneObject` turns its forward distance into a fade alpha once per frame (only when its
depth or the far distance changed), and applies it at the final blit only.

The rejected alternative was easing each object's alpha over time. An object past a
*shrunk* limit is already far-clipped, so it couldn't fade out without relaxing the clip per
object; animating the limit itself gets the same visible result with no per-object state.

## Design

### 1. `Camera3d`

New public fields:

- `drawDistanceFadeFraction as float = 0.15` - the fade band is the last 15% of the current
  draw distance. `0` disables fading (hard clip, today's behavior). A fraction rather than
  world units so the band scales with quality levels and device caps.
- `drawDistanceTransitionSeconds as float = 0.75` - how long the current draw distance takes
  to reach a new target. `0` snaps.

New public methods:

- `getCurrentDrawDistance() as float` - the eased distance actually used for clipping and
  fading. On the first frame (and after `snapDrawDistance()`) it equals
  `getEffectiveMaxDrawDistance()`. After that it moves linearly toward that target at
  `|target - startOfTransition| / drawDistanceTransitionSeconds` per second; a target change
  mid-transition starts a new transition from the current value.
- `snapDrawDistance()` - jump straight to the target (e.g. on a scene change or camera cut).
- `getDistanceFadeAlpha(point as BGE.Math.Vector) as float` - `1.0` up to
  `current * (1 - fraction)`, linear down to `0.0` at `current`, `0.0` beyond. Uses the same
  forward distance as `isInView()` (`dot(point - position, orientation)`), so alpha 0 lines
  up exactly with the far-clip. Always `1.0` when the fraction is `<= 0`.
- `farDistanceChangedThisFrame() as boolean` - true on a frame where the current draw
  distance or `drawDistanceFadeFraction` changed (either one changes every object's fade).

Changes:

- `isInView()` far test uses `getCurrentDrawDistance()`.
- The base `Camera` gets `getDistanceFadeAlpha()` returning `1.0` and
  `farDistanceChangedThisFrame()` returning `false`, so `SceneObject` code needs no casts
  and `Camera2d` is unaffected.
- **The far distance no longer bumps `projectionVersion`.** Today
  `projectionChangedThisFrame()` counts an effective-distance change as a projection change,
  which forces every object to recompute its canvas geometry. The projection itself doesn't
  depend on the far distance, and during a transition this would repeat every frame. That
  check is replaced by `farDistanceChangedThisFrame()`, which only bypasses the cull latch
  (see section 2).
- Easing is driven from `checkMovement()` (already called once per frame by
  `Renderer.setupCameraForFrame()`) using a camera-owned `roTimespan` for dt, clamped to
  0.1s per frame so one slow frame can't complete a transition (a tighter 1/30s clamp, like
  `ScreenFade`'s, would stretch a 0.75s transition past 1s at 20fps and outlast the adaptive
  settle extension in section 4). The
  stepping itself is a separate `advanceDrawDistance(dt)` method so specs can drive it
  deterministically. No `Renderer`/`Game` signature changes are needed, and a `Renderer`
  used without a `Game` (e.g. `examples/rendererTest`) eases too.
- `SceneObjectPlane` keeps using `getPlaneDrawDistance()`; unchanged.

### 2. `SceneObject`

- New field `distanceFadeAlpha as float = 1.0`.
- In `update()`, recompute it when `depthChangedThisFrame` or
  `cameraObj.farDistanceChangedThisFrame()`, from the **nearest** of the object's bounding
  points (`getBoundingPoints()`, the same points the frustum check uses) via
  `Camera.getDistanceFadeAlphaForPoints()`. (Changed after review: fading by `depthPosition`
  culled a long wall or big model whose near end was beside the camera.) Skipped, with alpha
  reset to 1, when `Camera.fadesWithDistance()` is false (2D cameras, fraction 0).
- New overridable `participatesInDistanceFade() as boolean` (default `true`).
  `SceneObjectPlane`, `SceneObjectSkybox` and `SceneObjectParallaxLayer` return `false` and
  always keep `1.0`.
- `isPotentiallyOnScreen()`: the "nothing moved, repeat last answer" shortcut is skipped on a
  frame where `farDistanceChangedThisFrame()` is true, so a far-culled object is re-checked as
  the limit grows (and a drawn one as it shrinks). Nothing else is recomputed.
- An object whose `distanceFadeAlpha` is `0` is treated as culled (doesn't enter the draw
  path, latches like a frustum cull).

### 3. Applying the alpha - final blit only

The fade is a multiplier on the alpha channel of whatever rgba the final draw call uses. It
combines with (doesn't replace) `Drawable.alpha`. A small helper,
`BGE.RendererHelpers.applyAlphaFade(rgba as integer, fade as float) as integer`, scales the
low byte; `fade = 1.0` returns `rgba` unchanged and an rgba of `-1` (Renderer's "no color")
becomes `&hFFFFFF00 + alpha`.

- **Cached temp bitmaps** (`SceneObjectBillboard.performDraw()`'s `drawObject` and
  `drawTransformedObject` blits of `m.tempBitmapRegion`, and `SceneObjectModel`'s equivalent)
  pass `applyAlphaFade(-1, m.distanceFadeAlpha)`. The raster inside the temp bitmap never
  includes the fade, so a fading object - stationary or not - keeps reusing its cached
  bitmap exactly as it does today. Fading does not affect `isRedrawToCanvasRequired()`.
- **Direct paths** (`drawToCanvas()` in every billboard type, `drawFastPath()`,
  `drawOutlineToCanvas()`, lines, polygons, text): `getDrawColorRGBA()` and
  `getOutlineDrawColorRGBA()` stay un-faded, because the temp-bitmap raster paths
  (`SceneObjectBillboard.drawToTempBitmap()`, `SceneObjectPolygon`'s and
  `SceneObjectRectangle`'s temp-bitmap draws) use them and must never bake the fade in. New
  `getCanvasDrawColorRGBA()`/`getCanvasOutlineDrawColorRGBA()` wrap them with the fade, and
  every call site that draws straight to the canvas switches to those. The name makes the
  cache-safe vs. canvas distinction visible at each call site.
- **`SceneObjectModel` per-face (cluster) path**: each face's color gets the fade. Known
  artifact: a model drawn face by face shows faint overlapping faces while in the band.
- **`SceneObjectParticle`**: opts out of the object-level fade; each particle fades by its
  own distance in `performDraw()` (`Camera.getDistanceFadeAlpha(particle.position)`),
  multiplied into its existing interpolated alpha. (Changed after review: one fade per
  emitter let a single near particle keep a whole far plume opaque, and went stale with
  the emitter and camera parked.)

### 4. Adaptive quality

A step down now saves its frame time over the transition instead of immediately. With a
0.25s settle and 0.75s step-down cooldown, `QualityController` could read the mid-transition
frames as still slow and drop a second level. Fix: `Camera.isDrawDistanceTransitioning()`;
while it's true, `RenderQualityManager.update()` resets the controller's window instead of
feeding it a frame, so the normal settle starts once the distance lands. (Changed after
review: a fixed extra settle of `drawDistanceTransitionSeconds` ran out early below 10fps,
where the 0.1s step clamp stretches the transition, and also applied to level changes
that don't move the draw distance.)

### 5. Docs

- Doc comments on the new `Camera3d` fields/methods, written for game developers.
- CLAUDE.md: extend the `maxDrawDistance` bullet with the eased current distance, the fade
  band, and the projection-version decoupling.
- `docs/drawables-and-scene-objects.md`: a short section on draw-distance fading.

## Testing

Rooibos (headless):

- `Camera3d`: fade alpha at the band start (1.0), midpoint (0.5), limit (0.0) and beyond;
  fraction `0` gives 1.0 everywhere; `advanceDrawDistance()` eases from one target to another
  over the transition time and stops exactly on the target; first frame starts at the target;
  `snapDrawDistance()`; a far-distance change does not bump `projectionVersion`.
- `SceneObject`/billboard: the fade reaches the blit's rgba (spy on `drawObject`/
  `drawTransformedObject`/`drawRegion`); a stationary in-band object with a temp bitmap never
  re-rasterizes while its fade changes; fade `0` behaves as culled; a far-culled object draws
  again once the limit grows past it; plane/skybox stay at 1.0.
- `RendererHelpers.applyAlphaFade()`: identity at 1.0, `-1` input, rounding.
- `QualityController`: the extended settle ignores frames inside the transition.

On device (`rokubot-examples`, plus the user playing):

- `examples/terrain`: fly toward and away from trees; trees fade in at the horizon.
- Force quality level changes (adaptive on); the limit sweeps instead of popping.
- Compare FPS with `drawDistanceFadeFraction` at 0.15 and 0 - partial-alpha blits on Roku
  hardware haven't been measured, so the cost is checked, not assumed.
- `examples/3d` and `examples/collisions3d` still render correctly (static BSP path).
