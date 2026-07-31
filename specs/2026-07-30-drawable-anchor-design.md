# Consistent, configurable anchoring for every Drawable

Design doc for issue #50.

## Problem

Anchoring exists today, but only for `Image`, and only in Roku-native terms:

- `Drawable.getPretranslation()` returns `(0,0)`; only `Image` overrides it, reading its
  `roRegion`'s native pretranslation.
- Engine code applies it in exactly two places: the oriented branch of
  `SceneObjectBillboard.updateWorldPosition()`, and `directScaled`'s camera-facing quad
  (`updateCanvasPointsForCameraFacingQuad`).
- In the plain 2D fast path (`directToCamera`, which is what a `Camera2d` resolves
  `matchCamera` to) it works *implicitly*, because Roku's `DrawObject`/`DrawScaledObject`
  apply a region's native pretranslation automatically - no BrighterScript math involved.
- `BGE.getRegionsFromAtlas` (`utils.bs`'s `TexturePacker_GetRegions`) already sets a
  region's pretranslation from a sprite atlas's normalised `pivot`, so there's a real,
  working consumer of the underlying mechanism today.

Consequences: `DrawableRectangle` and `DrawableText` have no anchoring at all, and because
the mechanism is half native / half computed, the geometry the renderer calculates can
disagree with where Roku actually blits (the bug fixed in #47). `DrawableText` separately
has its own bespoke, `alignment`-based horizontal anchoring, implemented as a one-off
`getWorldPosition()` override with what looks like a pre-existing bug (right-align shifts
by `-height` instead of `-width`).

This also retires the standing TODO in `SceneObjectBillboard.drawToCanvas`:

> may need to change this to add some sort of "locked position" so that things like trees
> have the bottom of the tree locked to the ground, instead of the center of the tree
> being locked to the ground - this would prevent weird scaling issues where the tree
> appears to grow out of the ground as it scales up

## Scope

In scope: `Image` (and its subclasses `Sprite`/`AnimatedImage`), `DrawableRectangle`,
`DrawableText` - the drawables with an unambiguous rectangular width/height.

Out of scope: `DrawablePolygon` and `DrawableLine` already define their own point sets
around the origin (no implicit box to anchor); `DrawablePlane`/`Model3d` aren't
billboard-anchored the same way. None of these gain an `anchor` field in this pass.

## Design

### 1. Core mechanism (`Drawable` base class)

- `protected anchor as BGE.Math.Vector = BGE.Math.VectorOps.create(0, 0)` - normalised
  0-1, default `(0,0)` = top-left, identical to today's behaviour for every drawable that
  never calls `setAnchor()`.
- `protected anchorIsSet as boolean = false` - lets `Image` distinguish "anchor was
  explicitly set" from "still using whatever the region/atlas already had."
- `getAnchor() as BGE.Math.Vector` - accessor, returns a copy.
- `setAnchor(x as float, y as float)` - mutator. Sets `anchor`, `anchorIsSet = true`, calls
  `invalidateGeometry()`. Mirrors the existing `DrawableRectangle.setSize()` pattern: a
  resize/anchor change isn't movement, so the renderer's per-frame dirty-checking
  (`MotionChecker`) can't see it, and it must be declared explicitly.
- `getPretranslation()` becomes a real base implementation:
  `BGE.Math.VectorOps.create(-m.width * m.anchor.x, -m.height * m.anchor.y)`.

At the default anchor this returns `(0,0)`, exactly like today's base implementation, so
`DrawableRectangle` (which never overrode `getPretranslation()`) is unaffected until
`setAnchor()` is called - and once it is, oriented and `directScaled` draw modes pick it up
correctly with zero further changes, since both already consume `getPretranslation()`.

### 2. `Image` / `Sprite` / `AnimatedImage` - native region write-through

`Image.getPretranslation()` already reads straight from the region's native
pretranslation, which is what makes the plain 2D fast path work for free via Roku's own
blit. So `Image` does not override `getPretranslation()` - it overrides `setAnchor()` to
push the computed value onto the region instead:

```
override sub setAnchor(x as float, y as float)
  super.setAnchor(x, y)
  m.applyAnchorToRegion()
end sub

protected sub applyAnchorToRegion()
  if m.anchorIsSet and invalid <> m.region
    m.region.SetPretranslation(-m.width * m.anchor.x, -m.height * m.anchor.y)
  end if
end sub
```

`getPretranslation()` stays exactly as it is today (reads the region), so oriented/
directScaled naturally read back whatever was last pushed to the region - which is also
how the "atlas pivot vs. anchor" precedence resolves itself: whichever was set on the
region most recently wins, with no special-casing needed.

**`AnimatedImage` gotcha**: `AnimatedImage.update()` swaps `m.region` to a different cell
region every frame (and updates `m.width`/`m.height` to match, since cells can differ in
size). A one-time `setAnchor()` push would only reach whichever region happened to be
active at that moment; the next swapped-in cell would silently lose the anchor. Fix: add
one line to `AnimatedImage.update()`, right after it reassigns `m.region`/`m.width`/
`m.height`: `m.applyAnchorToRegion()`. No-op when `anchorIsSet` is false, so this is safe
for every existing `AnimatedImage`/`Sprite` consumer. `Sprite.applyPreTranslation()` (an
existing lower-level escape hatch that sets raw pixels across every cell region at once)
is untouched and doesn't conflict.

### 3. `DrawableText` - unifying with the existing `alignment` field

Delete `DrawableText.getWorldPosition()`'s bespoke override entirely (the `-width/2` for
center, buggy `-height` for right), reverting to the plain `Drawable.getWorldPosition()`.
`alignment` becomes sugar for `anchor.x` (`left` -> 0, `center` -> 0.5, `right` -> 1),
which also fixes the bug (right-align becomes a correct `-width` shift via the unified
formula).

`alignment` is a plain public field, so a direct assignment can't be intercepted -
`DrawableText` needs a per-frame dirty-check, the same idiom this codebase already uses
for `Camera3d.fieldOfViewDegrees` (a public field feeding a derived, cached value):

```
protected lastAlignment as BGE.UI.HorizAlignment = BGE.UI.HorizAlignment.left

override sub update()
  if m.alignment <> m.lastAlignment
    m.lastAlignment = m.alignment
    x = 0
    if m.alignment = BGE.UI.HorizAlignment.center
      x = 0.5
    else if m.alignment = BGE.UI.HorizAlignment.right
      x = 1
    end if
    m.setAnchor(x, m.anchor.y)
  end if
end sub
```

`anchor.y` stays independently settable via `setAnchor()` for vertical anchoring (default
0 = top, matching today). `getPretranslation()` is inherited unchanged from the `Drawable`
base - no `Image`-style region trick is needed, since `DrawableText`'s temp region is
rebuilt fresh in `getTextImage()` with no pretranslation ever baked into it. So oriented
and `directScaled` modes are correct automatically; only the plain 2D fast path needs
help, covered next.

### 4. `DrawableRectangle` and `DrawableText`'s plain 2D fast path

The one real gap: `SceneObjectBillboard.updateCanvasPosition()`'s `isDirectDrawMode`
branch never consults pretranslation at all. `Image` gets it for free via the native
region blit; `DrawableRectangle` (no region, plain `drawRectangle` fill) and `DrawableText`
(temp region carries no pretranslation) have no such native channel.

Fix, isolated to one opt-in hook so `Image`'s behaviour can't be touched:

```
' SceneObjectBillboard.bs
protected function needsManualPretranslationForDirectMode() as boolean
  return false  ' default: rely on native region blit (Image), or no anchor at all
end function
```

In `updateCanvasPosition`'s `isDirectDrawMode` branch, before projecting: if
`needsManualPretranslationForDirectMode()`, offset `worldPosition` by
`(pretrans.x * m.drawable.scale.x, -pretrans.y * m.drawable.scale.y, 0)` before calling
`worldPointToCanvasPoint`. `SceneObjectRectangle` and `SceneObjectText` override the hook
to `true`; every other subclass (crucially `SceneObjectImage`) keeps the default `false`,
so nothing changes for `Image` anywhere, in any draw mode.

## Testing

- `Drawable.spec.bs`: default anchor is a no-op (`getPretranslation()` returns `(0,0)`,
  matches today); `setAnchor()` bumps `geometryVersion`.
- `Image.spec.bs`: `setAnchor()` writes through to the region's native pretranslation;
  an `AnimatedImage`'s anchor survives a cell swap (new region picks it up too).
- `DrawableText.spec.bs`: `alignment` sets `anchor.x` correctly for all three values
  (including the right-align bug fix), `anchor.y` is independently settable.
- `SceneObjectRectangle.spec.bs` / `SceneObjectText.spec.bs`: the plain 2D fast path
  (`directToCamera`) picks up a set anchor; `SceneObjectImage` behaviour is unchanged
  (hook defaults to `false`).

## Worked example

Extend `examples/3d`'s `ImagesRoom` with a second `directScaled` roku-logo billboard
anchored at `(0.5, 1)` (bottom-center), sitting on the room's ground level next to the
existing top-left-anchored one. Dollying the camera closer/further visibly demonstrates
the bottom-anchored sprite's base staying planted while it scales, versus the default
sprite's center-of-mass staying fixed instead - closing out the `SceneObjectBillboard`
TODO comment this issue was filed to retire.
