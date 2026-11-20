---
paths:
  - "src/source/engine/renderer/cameras/**"
---

# Cameras

Doc: `docs/third-person-cameras.md`.

- `Camera2d.follow()`/`setBounds()` apply in `checkMovement()` after updates — set targets in `onUpdate`, not `onDrawBegin`.
- `BGE.OrbitCamera`: third-person orbit; pass the look vector to `update()` in `onPostUpdate`; `lockOn(entity)` keeps a second entity in view (`lockDeadZone`/`lockEase` let it move round the middle without turning the view). Pairs with `BGE.Math.cameraRelativeMove()`.
- `BGE.CameraBoom`: keeps a chase camera in front of 3D colliders (pull in at once, ease out). Give blockers their own `memberFlags` bit so characters don't count.
- `BGE.GridWallsCameraBoom`: a `CameraBoom` that marches a `GridWallsMap` (`stepLength`) instead of raycasting colliders; `stepLength` is read from args after `super()` since subclass field defaults are set after it.
- World size to pixels: `camera.pixelsPerWorldUnitAt(point)` (1 on `Camera2d`; `Camera3d` is `getFocalLength() / viewDepth(point)`, 0 behind the eye). Use it rather than recomputing focal/depth; inline it only in hot per-point loops.
- `camera.zoom` (both cameras; `zoomTo(target, seconds, easing)` eases it on the camera's own clock, log-space; a direct write cancels it). Read it via `getEffectiveZoom()` (clamped 0.1-100). `Camera2d`: ortho box / zoom, bounds clamp `frameSize / zoom`, direct-mode billboards/particles/parallax scale by it. `Camera3d`: focal length x zoom; use `getEffectiveFieldOfViewDegrees()`, never `fieldOfViewDegrees`, for anything about what's on screen. Design: `specs/2026-11-20-camera-zoom-design.md`.
