---
paths:
  - "src/source/engine/renderer/cameras/**"
---

# Cameras

Doc: `docs/third-person-cameras.md`.

- `Camera2d.follow()`/`setBounds()` apply in `checkMovement()` after updates — set targets in `onUpdate`, not `onDrawBegin`.
- `BGE.OrbitCamera`: third-person orbit; pass the look vector to `update()` in `onPostUpdate`; `lockOn(entity)` keeps a second entity in view. Pairs with `BGE.Math.cameraRelativeMove()`.
- `BGE.CameraBoom`: keeps a chase camera in front of 3D colliders (pull in at once, ease out). Give blockers their own `memberFlags` bit so characters don't count.
