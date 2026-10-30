# axisAligned draw mode: implementation plan (#391)

> For agentic workers: use superpowers:executing-plans. Steps use `- [ ]` checkboxes.

**Goal:** `SceneObjectDrawMode.axisAligned`, an upright billboard that faces the camera's yaw
and foreshortens with real perspective.

**Architecture:** `axisAligned` reuses every `directScaled` code path (camera-facing quad,
rotated-quad blit, occlusion, rectangle fast path). The only differences are inside
`SceneObjectBillboard.getCameraFacingQuadWorldCorners` (level right + world up, height and
vertical anchor ÷ cos(ref)) and a roll correction on the projected quad when the drawable
doesn't bank.

**Tech stack:** BrighterScript, Rooibos v6 (`npm run check`).

**Spec:** `specs/2026-10-30-axis-aligned-billboard-design.md`

## Global constraints

- Enum value `axisAligned = 9`; `MAX_DRAW_MODE = 9`. Existing values unchanged.
- `Drawable.axisAlignedFullHeightPitch as float = 0` (degrees).
- No negative scale combined with a nonzero rotation in a native draw.
- One native draw per frame per sprite.

## Review focus

- A camera nearly straight above: the projected height drops under 1 px, so the draw is skipped (returns true, so nothing latches as failed).
- A full-height angle ≥ 90°: clamp to 89° so the 1/cos doesn't blow up.
- A Camera2d: there are no level vectors, so it behaves exactly like `directScaled`.
- A drawable switched between `directScaled` and `axisAligned` keeps drawing.
- Camera roll with and without `banksWithCameraRoll`.

---

### Task 1: Enum and classification helpers

**Files:** `src/source/engine/renderer/sceneObjects/SceneObject.bs`,
`SceneObjectDrawMode.spec.bs`

- [ ] Test: `getDrawModeName(axisAligned) = "axisAligned"`; `isScreenAlignedDrawMode(axisAligned)`
  is true; new `isCameraFacingQuadDrawMode(mode)` is true only for `directScaled` and
  `axisAligned`; the lookup array has `MAX_DRAW_MODE + 1` entries (existing test).
- [ ] Add the enum value, bump `MAX_DRAW_MODE`, extend the names, add
  `isCameraFacingQuadDrawMode(drawMode as SceneObjectDrawMode) as boolean`, and build
  `isScreenAlignedDrawMode` from it.
- [ ] `npm run check` passes; commit.

### Task 2: The quad

**Files:** `src/source/engine/drawables/Drawable.bs`,
`src/source/engine/renderer/sceneObjects/SceneObjectBillboard.bs`,
`SceneObjectRectangle.bs`, new `SceneObjectAxisAligned.spec.bs` (one suite)

**Consumes:** `isCameraFacingQuadDrawMode` from Task 1.

- [ ] Tests (64×64 image anchored at its feet `(0.5, 1)`, entity 500 units in front of the
  camera; sizes within 2%):
  - level camera, ref 0: canvas quad height ≈ the `directScaled` quad's height;
  - camera raised to look down 45° at the object (same distance): height ≈ cos 45° × the level
    height; width ≈ the level width;
  - ref 12°, camera looking down 12°: height ≈ the level height at ref 0;
  - the anchor's canvas point (bottom-centre of the quad) equals the projected entity position
    at 0° and at 45°;
  - camera roll 30°: avg rotation ≈ 0 by default; |rotation| > 0.1 with `banksWithCameraRoll`;
  - camera straight above: the draw is skipped without failing (no draw calls, the next level
    frame draws);
  - switching `directScaled` ↔ `axisAligned` keeps drawing.
- [ ] Add `axisAlignedFullHeightPitch` to `Drawable` with a consumer doc comment.
- [ ] In `getCameraFacingQuadWorldCorners`, for `axisAligned` on a `Camera3d`: use
  `getLevelRightVector()` and world up; multiply the height and the vertical pretranslation
  term by `1 / cos(min(ref, 89°))`.
- [ ] In `updateCanvasPointsForCameraFacingQuad`, for `axisAligned` without
  `banksWithCameraRoll` and a nonzero roll: rotate the four canvas corners by the roll around
  the anchor's canvas point (`m.canvasPosition`) so the image is upright on screen.
- [ ] Replace the three `= directScaled` / `<> directScaled` checks in `SceneObjectBillboard`
  and the one in `SceneObjectRectangle` with `isCameraFacingQuadDrawMode`. In the draw branch,
  skip (return true) when the quad's average height is under 1 px.
- [ ] `npm run check` passes; commit.

### Task 3: Demo and docs

**Files:** `examples/rendererTest/src/source/Tests/AxisAlignedBillboards.bs` (new),
`examples/rendererTest/src/source/DemoList.bs`, `docs/drawables-and-scene-objects.md`

- [ ] Demo: a ground plane, a row of upright feet-anchored sprites in `axisAligned` next to the
  same sprites in `directScaled`, and a camera that orbits and pitches between level and about
  60° down.
- [ ] Docs: a row in the draw-mode table, and a short paragraph with a code example for
  `axisAligned` and `axisAlignedFullHeightPitch` in the billboard section.
- [ ] `npm run check:all` passes; run the demo on the simulator and a device; commit; PR.
