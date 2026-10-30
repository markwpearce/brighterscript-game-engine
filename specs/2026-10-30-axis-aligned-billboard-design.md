# axisAligned draw mode: design (#391)

## Intent

Characters, trees and props in a 3D world need to stand upright on the ground and turn to face
the camera around the vertical axis only. When the camera looks down on them, they should get
shorter with real perspective, the classic cylindrical billboard.

Neither existing mode does this:

- `directScaled` keeps the image square to the screen and only scales it with distance. Seen from
  a steep angle, it looks like a cardboard cutout held up to the camera.
- `oriented` uses the entity's own rotation, so the image turns side-on as the camera goes round.

`examples/thirdPerson` (#385, PR #392) fakes it today. `Knight.squashForViewAngle()` sets
`scale.y = cos(pitch) / cos(12°)` every frame and calls `invalidateGeometry()`.

## Goals

- A new `BGE.SceneObjectDrawMode.axisAligned` that billboard drawables (`Image`, `Sprite`,
  `AnimatedImage`, `DrawableOrientedSprite`) can use.
- The image faces the camera's yaw, stays upright in the world, and foreshortens vertically with
  real perspective.
- A configurable **full-height angle**: the elevation the camera sees the object from (the angle
  of the line from the camera down to it) at which the art is drawn at full height. The default
  is 0° (camera level with the object).
- The anchor (`setAnchor`, e.g. feet at `(0.5, 1)`) stays planted while the top leans away.
- Honour `banksWithCameraRoll` the way the other billboard modes do.
- One native draw call per frame, the same cost as `directScaled`.

## Non-goals

- No horizontal foreshortening. Width follows distance only, like `directScaled`.
- No per-elevation-band full-height angles for `DrawableOrientedSprite`. There's one per
  drawable; per-band angles can come later if switching bands visibly jumps.
- No exact keystone. The top and bottom edges of a projected upright quad differ slightly in
  width under pitch. The cheap rotated-rectangle blit ignores that (see Drawing).
- No changes to `directScaled` or the other existing modes.

## Anti-goals

- Making `directScaled` users pay any extra per-frame cost.
- A mode that combines a negative scale with a nonzero rotation in a native draw call. Real Roku
  only mirrors at rotation 0 (CLAUDE.md).

## Decided

- **Name:** `SceneObjectDrawMode.axisAligned`, appended to the enum as value 9 so existing
  values don't change. `MAX_DRAW_MODE` and `getDrawModeName()` are updated to match.
- **Full-height angle:** configurable, default 0°. (Mark)
- **Field:** `Drawable.axisAlignedFullHeightPitch` (degrees, default `0`). (My call on the name.)
  For the knight it would be 12, the elevation its sheet was rendered from.

## How it works

`directScaled` builds its quad in world space from the camera's right and up vectors
(`SceneObjectBillboard.getCameraFacingQuadWorldCorners`) and then projects it. `axisAligned`
builds the same quad from two different vectors:

- **across:** the camera's level right vector, which is horizontal and perpendicular to the
  camera's yaw (`Camera3d.getLevelRightVector()`; check that it ignores pitch, not just roll).
- **up:** world up, `(0, 1, 0)`.

The result is an upright card facing the camera's yaw. Projecting it through the camera gives
the vertical foreshortening for free: its on-screen height is roughly `cos(elevation)` of the
unforeshortened height, where elevation is the angle the camera looks down (or up) at the
object. To make the art full height at the reference angle, the quad's world height is
`drawnHeight / cos(axisAlignedFullHeightPitch)`.

My call: this uses each object's own elevation from the camera, not the camera's pitch (the
issue asks for "real perspective"). It's
what real perspective does (an object almost under the camera squashes more than one far
ahead), and in a third-person view it's very close to the camera pitch anyway.

The pretranslation (anchor) offset is applied along the same `across`/`up` vectors as
`getCameraFacingQuadWorldCorners` does now, except that its vertical term is multiplied by the
same `1 / cos(axisAlignedFullHeightPitch)` as the height. Otherwise a feet anchor sinks by
`drawnHeight × (1/cos(ref) − 1)` (about 2% of the sprite at 12°). The anchor point is the one
fixed point.

### Camera roll

The world-up quad, projected through a rolled camera, rolls on screen with the world. That is
the `banksWithCameraRoll = true` behaviour. For the default (`false`), rotate the projected
canvas quad back by the camera's roll around the anchor's canvas point, so the image stays
upright on screen. Without a `Camera3d` (2D cameras), `axisAligned` behaves exactly like
`directScaled`.

### Drawing

Draw with the existing `drawRegionAsRotatedQuad` (one `DrawTransformedObject`), using the
quad's average width and height. The small keystone difference between the top and bottom
edges is ignored. That's my call, on cost grounds: an exact `drawPinnedCorners` warp is many
draw calls per frame per sprite.

When the projected height is under one pixel (the camera nearly straight above or below), skip
the draw. At exactly straight down, `Camera3d`'s level vectors switch to a fallback axis and
stop following yaw; that's acceptable, since nothing is drawn there anyway.

## Where draw modes are special-cased

`directScaled` is checked by name in about ten files (`SceneObject.bs`,
`SceneObjectBillboard.bs`, `SceneObjectRectangle.bs`, `SceneObjectCircle.bs`,
`SceneObjectPolygon.bs`, `SceneObjectModel.bs`, `Renderer.bs`, `Drawable.bs`,
`DrawableSphere.bs`, `GameEntity.bs`). For each check, decide whether `axisAligned` belongs with
it. My expectation:

- `isScreenAlignedDrawMode()` includes `axisAligned`. It is never backface-culled and has no
  plane, so it can't be a BSP node.
- Culling, depth sort, outline/debug drawing and `isOnScreen` treat it like `directScaled`,
  measuring off the projected quad.
- Shading for `isShaded` drawables matches `directScaled`.
- Drawables that aren't image billboards (rectangle, circle, polygon, sphere, model): use
  `axisAligned` where `directScaled`'s quad path already serves them; otherwise fall back to
  `directScaled`. The builder decides each case. Images are the target.

## Testing

- Specs in `SceneObjectBillboard.spec.bs` (or a new `axisAligned` spec file, one suite per file).
  `cos(elevation)` is only approximate under perspective (the card's top and bottom are at
  different depths), so size checks use a small tolerance, around 2%, on an object straight
  ahead of the camera:
  - camera level → projected height ≈ drawn height (ref 0);
  - camera pitched down 45° → height ≈ cos 45° × drawn height, width unchanged;
  - with a 12° full-height angle, pitched 12° → full height;
  - the anchor's canvas point stays fixed as pitch changes;
  - camera yaw changes don't change the on-screen width (it always faces the camera);
  - rolled camera with and without `banksWithCameraRoll`;
  - `getDrawModeName(axisAligned) = "axisAligned"`.
- `examples/rendererTest`: a demo with a few upright sprites anchored at their feet on a ground
  plane, with the camera orbiting and pitching, plus `directScaled` copies alongside to compare.
- A run on a real device. The rotated blit with roll is the risky part there.

## Follow-up

Once PR #392 (thirdPerson) is on `main`, switch the knight to `axisAligned` with
`axisAlignedFullHeightPitch = 12` and delete `squashForViewAngle()`. thirdPerson isn't on `main`
yet, so that can't be part of this PR.

## Left to the builder

- The exact spec file layout and the rendererTest demo's look.
- How the anchor and roll maths are factored inside `SceneObjectBillboard`.
- Per-drawable fallbacks for non-image drawables (see above).
- Docs: add the mode to the `SceneObjectDrawMode` table and billboard section in
  `docs/drawables-and-scene-objects.md`.
