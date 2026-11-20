# Camera zoom: design (#588)

## Intent

`Camera.zoom` exists but does nothing. Both cameras should zoom: 1 is the view as it is now, 2
shows the area round the middle of the view twice as big. A game should be able to ease into it
("zoom in on a hit", a cutscene) without driving the field every frame itself.

What's there now, and why it isn't enough:

- `Camera3d.fieldOfViewDegrees` can be narrowed by hand, but there's no zoom API and the
  relationship (zoom 2 is not half the FOV) is left to the game.
- `Canvas.scale`/`offset` enlarges the whole canvas from its top-left, including anything
  else drawn to it. It isn't a camera feature.

## Goals

- `camera.zoom = 2` doubles the size of everything the renderer draws, about the middle of the view,
  on both `Camera2d` and `Camera3d`. `zoom = 1` changes nothing (same pixels as today).
- `Camera2d`: `follow()` keeps the entity in the middle; `setBounds()` clamps against the
  smaller (or bigger) visible area, `frameSize / zoom`.
- `Camera3d`: real perspective. Zoom multiplies the focal length, so the effective field of view
  narrows, and the frustum, culling, near cut and every projection follow it.
- `zoomTo(target, seconds, easing)` eases the zoom; writing `zoom` yourself cancels it.
- A zoom change counts as a projection change (`projectionVersion`), so cached draws, culling
  latches, occlusion maps and fog silhouettes all refresh.

## Non-goals

- Zooming the UI canvas. It has its own renderer and camera, and stays at 1.
- Changing the draw distance with zoom. A zoomed-in 3D camera still stops drawing at the same
  world distance (a telephoto lens doesn't see through fog). Raise `maxDrawDistance` if a scene
  needs it.
- Scaling line and outline widths in 2D. They stay in pixels.

## Design

### Shared (`Camera`)

- `zoom as float = 1`, a plain field (consumers write it directly, as with `fieldOfViewDegrees`),
  dirty-checked in `projectionChangedThisFrame()`. Read through `getEffectiveZoom()`, which
  clamps to `[BGE.CAMERA_MIN_ZOOM, BGE.CAMERA_MAX_ZOOM]` (0.1 to 100), so a zero or negative zoom
  can't divide by zero or mirror the view.
- `zoomTo(target, seconds = 0.5, easing = SinusoidalEaseInOut)`, `isZooming()`, `stopZooming()`
  and `advanceZoom(dt)` (called by `checkMovement()` from the camera's own clock, like
  `advanceDrawDistance()`; public for tests). The step is clamped to 0.1 s, so a hitch doesn't
  finish the zoom in one jump.
- The ease runs in log space: `zoom = from * (target / from) ^ eased(t)`. Equal steps of the
  curve then look like equal changes in size. A linear 1 -> 4 zoom races through 1 -> 2 and
  crawls through 3 -> 4.

**Why not `TweenManager`?** It would work (`zoom` is a plain field, so
`game.tweenManager.to(camera, {zoom: 2}, 500)` does work), but it is owned by `Game`, and a
`Renderer` and its camera are used without one (`examples/rendererTest`). It also eases linearly
in the value. `zoomTo()` reuses the same easing functions (`BGE.Tweens.GetTweens()`), so the
curves match.

### `Camera2d`

- `computeWorldToCameraMatrix()` builds the orthographic box from half the frame divided by
  zoom, so world-to-canvas is scaled about the canvas centre and `isInView()`/`isAnyInView()`
  cull against the smaller view.
- The centre snaps to whole canvas pixels (`Int(position * zoom + 0.5) / zoom`) rather than
  whole world units, so every object still shares one integer shift (#255) and a zoomed camera
  scrolls a canvas pixel at a time instead of `zoom` pixels at a time. At zoom 1 it's what it was.
- `applyBounds()` clamps against `frameSize / zoom`.
- `pixelsPerWorldUnitAt()` returns the zoom.
- **Sizes.** Projecting positions isn't enough: a screen-aligned (`directToCamera`) drawable is
  drawn at its own pixel size at its projected corner. With a `Camera2d` (not a perspective
  camera) the billboard path now measures its size on the canvas by projecting its far corner
  too, so an image, text, circle or rectangle is drawn `zoom` times as big. Measuring both corners,
  rather than multiplying by zoom, keeps edge-to-edge tiles meeting exactly at a fractional zoom
  (mid-`zoomTo`), because neighbouring tiles share each rounded edge. Rotated drawables can't
  share edges, so they just scale by zoom.
- Particles and parallax layers draw in pixels, so with a `Camera2d` their sizes and tile
  steps scale by the zoom too. In 2D a pixel and a world unit are the same thing at zoom 1, so
  `sizeInWorldUnits` makes no difference there.
- `directToCamera` with a `Camera3d` is left alone. That mode means "this many pixels" in 3D
  (HUD-like markers), and an optical zoom shouldn't change it.

**Why not draw at 1x and scale the result up?** The issue's alternative for 3D. Drawing the
visible `frameSize / zoom` area into a scratch bitmap and blitting it scaled would need no
per-drawable work, but: a full-frame blit every zoomed frame, a scratch bitmap that grows as the
zoom goes below 1, and `worldPointToCanvasPoint()` would mean two different things, depending on
whether you ask during `render()` or after it (in `onDrawEnd`, e.g. for health bars).
Scaling the projection keeps one meaning.

### `Camera3d`

- `getEffectiveFieldOfViewDegrees()` = `2 * atan(tan(fieldOfViewDegrees / 2) / zoom)` (exactly
  `fieldOfViewDegrees` at zoom 1). Everything inside the camera that read `fieldOfViewDegrees`
  reads this instead: the frustum normals and rays, the convergence point, the vertical FOVs,
  `getProjectionNear()` (focal length; cached per frame width, FOV **and zoom**).
- `getFocalLength()` therefore grows with zoom, and everything that already goes through it follows:
  walls, quad columns, model faces, particles (`sizeInWorldUnits`), impostor fits,
  `pixelsPerWorldUnitAt()`, `getFovDegreesForCanvasSize()`.
- Outside the camera, the code that read `fieldOfViewDegrees` directly switches to the effective FOV:
  the skybox (visible slice and its redraw key), the ground plane's corner rays, and
  `OrbitCamera.lockTargetScreenOffset()` (the lock-on dead zone is a fraction of the screen).

## Audit: things that assumed the focal length (#588)

| Thing | Finding | Change |
|---|---|---|
| Particles, `sizeInWorldUnits` (#491) | Both draw paths use `getFocalLength()` / `pixelsPerWorldUnitAt()`. | None in 3D; they follow zoom. Pixel-sized particles stay in pixels in 3D (like `directToCamera`). With a `Camera2d`, every particle scales by zoom. |
| Fog silhouettes | Projected with `projectPointsWithDepth()` (focal-aware); `fogSilhouetteBand` is in pixels; the repeat key includes `projectionVersion`. Reach is a depth. | None. A zoom change re-projects them. |
| Fog backdrop | Its top and foot are projected points. | None. |
| Impostor reuse thresholds | Fits and residuals are measured between projected canvas points, so error limits are in on-screen pixels. Angle limits are view directions (which faces show, and their shading), which zoom doesn't change. `modelImpostorMaxSizeChange` bounds how far a capture is stretched while zooming, then it recaptures. | None. |
| Ground plane draw distance | `getPlaneDrawDistance()` is world units and doesn't use the FOV. The plane's corner rays did (`fieldOfViewDegrees`). | Corner rays use the effective FOV. The top-down bitmap stays sized from the unzoomed FOV: it always holds just the visible ground, so a zoomed-in view (a narrower wedge in the same pixel budget) gets *more* texels per world unit, which a magnified view needs anyway. Resizing it while zooming would reallocate a big bitmap every frame. |
| Near cut (`QuadColumnNearZ`, `getNearDepth()`) | `focal / 64`, so it moves out as zoom grows. | None. It exists to keep projected points within 64x the frame, which scales the same way. Documented. |
| Occlusion span map, walls, draw replay, cull latches | Keyed on `projectionVersion` / focal length. | None, once zoom bumps `projectionVersion`. |

## Testing

- `Camera.spec.bs`: zoom bumps `projectionVersion`; `getEffectiveZoom()` clamps; `zoomTo()`
  eases (in log space) and lands exactly; 0 seconds snaps; writing `zoom` cancels; `isZooming()`.
- `Camera2d.spec.bs`: zoom 2 halves the visible box (`isInView`); a point projects twice as far
  from the centre; bounds clamp with the smaller view; `pixelsPerWorldUnitAt()` is the zoom.
- `Camera3d.spec.bs`: zoom 2 doubles `getFocalLength()`; effective FOV; zoom 1 is exactly
  today's; a projected point doubles its offset from the centre; frustum narrows; a zoom
  change bumps `projectionVersion`.
- Scene objects: a 2D image/rectangle draws twice as big at zoom 2; adjacent tiles still meet at
  zoom 1.5; 2D particles scale; parallax tile steps scale.
- Device: `examples/rpg` (2D, Replay toggles zoom) and `examples/3d` (fast-forward toggles
  zoom), plus `examples/thirdPerson zoom=2` for fog, ground, impostors and particles together.
