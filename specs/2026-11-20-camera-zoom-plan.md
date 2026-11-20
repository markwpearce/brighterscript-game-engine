# Camera zoom: implementation plan (#588)

> For agentic workers: use superpowers:executing-plans. Steps use `- [ ]` checkboxes.

**Goal:** `camera.zoom` enlarges the view about its middle on `Camera2d` and `Camera3d`, with an
eased `zoomTo()`.

**Spec:** `specs/2026-11-20-camera-zoom-design.md`

## Global constraints

- Zoom 1 must leave every projection, size and cache key exactly as before (existing specs pass
  unchanged).
- Hot per-point paths (`worldPointToCanvasPoint`, `projectPointsWithDepth`) get no extra calls:
  zoom goes into the cached focal length / matrix.
- `directToCamera` with a `Camera3d` is untouched.

## Review focus

- `Camera2d` bounds clamping and pixel snapping at a fractional zoom.
- Tile seams at zoom 1.5 (far-corner sizing).
- Everything that read `fieldOfViewDegrees` directly now reads the effective FOV.
- `zoomTo()` and a direct write to `zoom` in the same frame.

---

### Task 1: Camera zoom state and zoomTo

**Files:** `cameras/Camera.bs`, `cameras/Camera.spec.bs`

- [ ] Tests: `getEffectiveZoom()` clamps 0/-1/1000; a zoom change bumps `projectionVersion`;
  `zoomTo(4, 1)` + `advanceZoom(0.05)` x 10 gives 2 at the half-way point (linear easing in log
  space) and exactly 4 at the end; `zoomTo(2, 0)` snaps; writing `zoom` mid-ease cancels it.
- [ ] `zoom` field, `CAMERA_MIN_ZOOM`/`CAMERA_MAX_ZOOM`, `getEffectiveZoom()`, zoom in
  `projectionChangedThisFrame()`, `zoomTo()`/`isZooming()`/`stopZooming()`/`advanceZoom()`,
  driven from `checkMovement()` by the camera's own clock.

### Task 2: Camera2d

**Files:** `cameras/Camera2d.bs`, `cameras/Camera2d.spec.bs`

- [ ] Tests: zoom 2 projects a point twice as far from the canvas centre; `isInView` box halves;
  bounds clamp against `frameSize / zoom`; `pixelsPerWorldUnitAt()` = zoom; zoomTo drives
  bounds the same frame.
- [ ] Matrix half extents / zoom, pixel snapping, `applyBounds()`, `pixelsPerWorldUnitAt()`,
  advance the zoom before following/clamping.

### Task 3: Camera3d

**Files:** `cameras/Camera3d.bs`, `cameras/Camera3d.spec.bs`, `cameras/OrbitCamera.bs`,
`sceneObjects/SceneObjectSkybox.bs`, `sceneObjects/SceneObjectPlane.bs`

- [ ] Tests: zoom 2 doubles `getFocalLength()`; `getEffectiveFieldOfViewDegrees()` is 90 at
  zoom 1 and `2 atan(0.5)` at 2; a projected point's offset from centre doubles; a point near
  the edge leaves the frustum at zoom 2; changing zoom bumps `projectionVersion`.
- [ ] `getEffectiveFieldOfViewDegrees()`, used for the frustum, convergence, vertical FOVs and
  focal length (cache keyed on zoom). Skybox, plane corner rays and `OrbitCamera` use it.

### Task 4: 2D sizes

**Files:** `sceneObjects/SceneObjectBillboard.bs`, `SceneObjectRectangle.bs`,
`SceneObjectParticle.bs`, `SceneObjectParallaxLayer.bs` and their specs

- [ ] Tests: a 2D Image at zoom 2 blits at scale 2; a rectangle fills twice the size; two
  adjacent 10 px tiles at zoom 1.5 share an edge; 2D particles and parallax tiles scale.
- [ ] Billboard direct mode stores its canvas size (far corner projected under a `Camera2d`
  with zoom; size x zoom when rotated), used by `drawToCanvas`, the direct-mode corner points
  and the rectangle's axis-aligned rect. Particles and parallax scale by `pixelsPerWorldUnitAt()`
  when the camera isn't perspective.

### Task 5: Docs and examples

- [ ] `docs/third-person-cameras.md` (zoom section), `docs/game-engine-overview.md` and
  `docs/engine-internals.md` mentions, `.claude/rules/cameras.md`.
- [ ] `examples/rpg`: Replay toggles `zoomTo(2)`/`zoomTo(1)`. `examples/collisions3d`: Replay
  does the same. `examples/thirdPerson`: `zoom=<n>` deep link.
- [ ] `npm run check`, validate the touched examples, device screenshots at zoom 1 and 2.
