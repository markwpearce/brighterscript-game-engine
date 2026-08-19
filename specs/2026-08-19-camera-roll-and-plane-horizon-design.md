# Camera roll and an angled plane horizon

Design toward [#53](https://github.com/markwpearce/brighterscript-game-engine/issues/53). This is
the first of several sub-projects that request grew into; texture tiling (#53's literal scope),
plane color fill, and composable tiled/non-tiled planes are deliberately deferred - see
[Non-goals](#non-goals).

## Problem

`Camera3d` has no concept of roll (rotation about its own forward/view axis) at all today:

- `getUpVector()` always derives "up" from world-up projected against the forward vector - there
  is no roll state to apply even if there were one.
- `computeWorldToCameraMatrix()` calls `Matrix44.lookAt()`, which hardcodes world-up internally.
  Even if `getUpVector()` did account for roll, the view matrix used to project every ordinary 3D
  point (billboards, models) would still ignore it.
- `SceneObjectPlane.drawPerspectiveBmpSlicesToByCamera()` draws the ground as a stack of
  horizontal trapezoidal slices between a fixed `destTop` and a `horizonY` read from
  `horizon[0].y` - a comment on that line already says `TODO: need to account for camera roll`.
  This algorithm has no way to represent a horizon that isn't horizontal.

The user's request (issue discussion) also wants vertical camera movement/pitch to "make sense"
for draw distance and the horizon - a real, separate, pre-existing issue (see
[Non-goals](#non-goals)) - and, as "extra credit," a camera roll with a correctly angled horizon.
Given the scope, roll is being tackled first, as its own design.

## Approach

### A. Camera3d gets a real roll axis

Add `rollDegrees as float = 0` to `Camera3d`, dirty-checked the same way `fieldOfViewDegrees`
already is. Aviation convention: positive = right side down.

`getUpVector()`/`getRightVector()` keep computing their current "level" result first, then rotate
both around `m.orientation` (the forward axis) by `rollDegrees` before returning. Because
`CameraFrustumNormals`/`CameraFrustumRays` are already built from `getUpVector()`/`getRightVector()`
rather than any hardcoded axis, frustum culling and the frustum rays inherit correct roll behavior
with no changes of their own.

### B. The view matrix has to actually carry roll

`Matrix44.lookAt(from, lookTo)` gains an optional third parameter, `up` (defaults to today's
hardcoded `{x:0, y:1, z:0}` so `Camera2d`/base `Camera` - which never call it with an explicit up -
are unaffected). `Camera3d.computeWorldToCameraMatrix()` passes `m.getUpVector()`.

This is what makes ordinary 3D objects bank with the camera "for free": any point projected via
`worldPointToCanvasPoint()` (every billboard, every model face) goes through `worldToCamera`, which
now reflects the real roll. No per-object-type changes are needed for this to work.

### C. Cache/dirty-check fixes for pure-roll frames

`MotionChecker.check(position, rotation)` compares `rotation` as a plain direction vector - it has
no way to represent "spun around that same direction." A frame where only `rollDegrees` changes
(camera not translating or turning) would otherwise be invisible to:

- `Camera3d.onCameraMovement()` / `recomputeFrustum()` - frustum normals/rays would go stale.
- `m.worldToCamera` - only rebuilt when invalid; nothing currently invalidates it on roll.
- `SceneObjectPlane.performDraw()`'s cache shortcut, which skips all perspective work when
  `not m.objMovedInRelationToCamera(camera)` - a roll-only frame must not take that shortcut.

`Camera3d` will track `lastRollDegrees` itself (mirroring the existing `lastProjectionFieldOfView`
pattern). On a roll-only change it explicitly calls `recomputeFrustum(true)`, invalidates
`m.worldToCamera`, and marks the frame as moved (so `movedLastFrame()` reports `true` for any
downstream consumer, including the plane's cache check).

### D. SceneObjectPlane: render level, then rotate the framebuffer

For a pure roll, the projected image is exactly the `rollDegrees = 0` image rotated about its own
center by the roll angle - perspective division only touches x/y in camera space, and roll is
defined as the rotation of that same x/y plane around a fixed forward (z) axis, so the two commute.
This means `SceneObjectPlane`'s existing slice-based rasterization doesn't need to change at all -
only how its result reaches the screen does.

- `Camera3d` exposes `getLevelUpVector()`/`getLevelRightVector()`: today's pre-roll math, kept
  available under a new name. `SceneObjectPlane.getPerspectivePointsByCamera()` and
  `getHorizonLine()`'s caller use these instead of the real (rolled) up/right, so all of the
  plane's existing geometry - frustum-style rays to the plane, corner points, `horizonY` - is
  computed exactly as it is today, entirely independent of roll.
- The composited result (today's `m.tempBitmap`: ground texture below the horizon line,
  transparent above) is built into a **larger square canvas**, sized to the camera frame's
  diagonal (`ceil(sqrt(frameWidth^2 + frameHeight^2))` on each side, centered on the frame), so
  that rotating it can never expose empty corners within the visible frame.
- That canvas is rotated by `-rollDegrees` around its own center via the existing
  `Renderer.drawRotatedImageWithCenterTo()`, then center-cropped/blitted to the actual destination
  in place of today's direct `drawObject(0, 0, m.tempBitmap)`.
- Because the pre-rotation canvas already has real alpha (ground pixels below the level horizon,
  `&h00000000` above it, per the existing `Clear` calls), rotating it naturally produces "ground
  below a *tilted* line, transparent above" with no separate sky-clipping logic - whatever the
  renderer already drew behind it (the background/other scene objects) shows through correctly.
- `m.tempBitmap`'s cached-bitmap fast path in `performDraw()` (skip all recompute when the camera
  hasn't moved) is unaffected: it now caches the *rotated, cropped* result, still invalidated by
  the same movement/roll dirty-checks from section C.

### Terrain example: pitch and roll become live controls

`examples/terrain`'s `MainRoom` currently bakes a fixed `downwardTilt` constant into
`updateCameraOrientation()`. This becomes a live, held-continuous control alongside the new roll
control, tracked the same way existing turn/drive input already is (state set on press/held,
cleared on release, applied every `onUpdate` tick rather than only on the input event itself):

| Button | Action |
|---|---|
| D-pad left/right | yaw (unchanged) |
| D-pad up/down | drive forward/back (unchanged) |
| OK | toggle track/checkerboard texture (unchanged) |
| Instant Replay (held) | roll left |
| Options (held) | roll right |
| Rewind (held) | pitch down |
| FastForward (held) | pitch up |
| Play/Pause (press) | reset pitch and roll to their defaults |
| Back (press) | quit (unchanged) |
| Back (held 2s) | toggle debug info (moved off Options, which roll-right now owns) |

A new oriented billboard marker (`SceneObjectDrawMode.oriented`, not `directToCamera`) is planted
at a fixed world position along the track. Since it renders through the ordinary per-point
projection path (section B), it visibly banks/tilts with roll independent of the plane's own
render-then-rotate path (section D) - a second, independent confirmation that both mechanisms
agree with each other. No changes are needed to `examples/3d` for this.

## Non-goals

Explicitly out of scope for this design, called out so they aren't mistaken for dropped work:

- **Texture tiling** (#53's literal scope) - replacing the plane's finite-decal texture with
  wrapping sampling. Independent of camera roll; a separate design.
- **The slice-height easing-curve heuristic** in `drawPerspectiveBmpSlicesToByCamera()`
  (`ExponentialEaseOut(firstHeight, 1, i, maxSliceCount)` with a hardcoded `firstHeight = 50`) -
  this distributes screen-space slice heights by an arbitrary curve rather than deriving them from
  true perspective, which is almost certainly why vertical camera movement/steep pitch already
  looks questionable today. This is a pre-existing, orthogonal bug: the render-then-rotate
  approach in section D doesn't fix or worsen it, since it operates on whatever the level-camera
  render already produces. Worth its own follow-up.
- **Plane color fill** (a `color`-only plane with no texture, mirroring `DrawableRectangle.color`).
- **Composable tiled + non-tiled planes** (a tiling "out of bounds" backdrop plus a finite decal
  "playable area" plane together in one scene) - depends on tiling landing first.

## Testing

- Rooibos specs (`Camera3d.spec.bs`): `getUpVector()`/`getRightVector()` banking correctly at known
  `rollDegrees` values (including 90/180/270 edge cases); `getLevelUpVector()`/
  `getLevelRightVector()` staying roll-invariant; the roll-only dirty-check forcing
  `recomputeFrustum`/`worldToCamera` invalidation and `movedLastFrame()` to report `true`.
- A new spec for `Matrix44.lookAt()`'s up-vector parameter, confirming the default preserves
  today's world-up behavior and an explicit up rotates the resulting basis as expected.
- Rooibos specs for `SceneObjectPlane`'s new canvas-sizing (diagonal calculation) and
  rotate/center-crop math against known angles.
- On-device/simulator verification via the `rokubot-examples` skill is mandatory before this is
  considered done, per project convention - this class of bug (visual artifacts, seams, corner
  gaps) does not show up in any automated check. Using the terrain example's new controls:
  screenshot at level (0°), a shallow bank (~15°), a steep bank (~45-60°), and near-90°, checking:
  the horizon renders as a straight line at the expected angle; the ground fills correctly below it
  with no wedge-shaped gaps or stale pooled-bitmap artifacts at the frame corners (the exact
  `ScratchBitmapPool`-not-cleared gotcha already documented on this code); the track texture isn't
  stretched/duplicated oddly under rotation; and the oriented billboard marker visibly banks in
  agreement with the horizon.
