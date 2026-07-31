# Parallax / scrolling background layers — design

Issue: [#67](https://github.com/markwpearce/brighterscript-game-engine/issues/67)

## Goal

A drawable that scrolls at a configurable fraction of the camera's movement (parallax),
optionally tiling to cover an arbitrarily wide/tall level, so a side-scroller can get
depth cues (distant mountains drifting slowly behind mid-ground trees) without any
consumer having to hand-roll repositioning or texture repetition themselves.

## Spike: `roRegion.SetWrap()` does not help here

Before settling on an implementation approach, `SetWrap(true)` was tested directly against
this engine's rendering path (a scratch demo in `examples/rendererTest`, since torn down).
Result, confirmed both by a runtime crash on-device and by the Roku SDK docs/reference
benchmark app:

- `SetWrap` only produces tiling through the `roCompositor`/`roSprite` pipeline
  (`compositor.NewSprite()` + `sprite.OffsetRegion()`), not through plain `ifDraw2D` draw
  calls (`DrawObject`/`DrawScaledObject`) — confirmed via the
  [roku-draw2d-performance](https://github.com/markwpearce/roku-draw2d-performance)
  benchmark app's own `testCompositorWrapMethod`, and via the `ifSprite.OffsetRegion` docs.
- This engine's `Renderer` draws directly via `ifDraw2D` — `roCompositor` is used
  elsewhere only for collision (`Collider`), never for general drawing.
- Requesting a `roRegion` larger than its underlying bitmap and calling `SetWrap` on it
  crashed on-device (`Interface not a member of BrightScript Component`), confirming it
  isn't a usable plain-region feature outside the compositor/sprite path either.

Conclusion: tiling is done manually — draw the tile bitmap 2-4 times side by side (option
1 from the original issue), positions wrapped modulo tile size. Per the existing
[draw2d benchmarks](https://github.com/markwpearce/roku-draw2d-performance), a plain blit
runs ~16-17k/sec, so a handful of extra blits per frame is effectively free. Bringing in a
`roCompositor` pipeline just for background tiling was considered and rejected as
disproportionate.

## Scope

In scope:
- A single new drawable, `DrawableParallaxLayer`, rendering one tiled/scrolling bitmap
  layer.
- Per-axis parallax factor and per-axis repeat flags.
- Correct behavior under camera movement, including sub-pixel accumulation (no stutter on
  slow layers).
- A dedicated `examples/parallax` example, demonstrating this through a real
  `Game`/`Room`/`Camera2d.setTarget()`-follow setup with a controllable entity and 2-3
  layers at different depths (plus a foreground layer, to show `factor > 1`). This
  replaces a `rendererTest` demo as this issue's own proof/demonstration: `rendererTest`
  deliberately never exercises `Drawable`/`SceneObject`/`GameEntity` (every existing demo
  calls `Renderer`'s raw draw methods directly), and `DrawableParallaxLayer` requires a
  `GameEntity` owner (which itself requires a real `Game`) - the same reason no other
  `Drawable`/`SceneObject` pair (`Image`, `DrawableRectangle`, etc.) has a `rendererTest`
  demo either. `examples/parallax` is built as part of this same issue rather than as a
  deferred follow-up.

Out of scope (explicitly deferred):
- A general "explicit draw layer"/priority system (#59) — v1 relies entirely on the
  existing distance-from-camera sort.
- Non-image content (solid color fill, lines, rectangles) — bitmap/image only.
- Vertical infinite scrolling beyond `repeatY`'s simple tiling (no separate "infinite
  plane" concept — this is 2D tiling, unrelated to `DrawablePlane`'s Mode-7 plane).

## Components

### `DrawableParallaxLayer` (`src/source/engine/drawables/DrawableParallaxLayer.bs`)

New class extending `BGE.Drawable`, following the same shape as `Image`:

```brightscript
class DrawableParallaxLayer extends BGE.Drawable

  region as roRegion

  ' Per-axis fraction of camera movement this layer scrolls at. {1,1} (the default)
  ' behaves exactly like an ordinary drawable - full 1:1 world-space scrolling. {0,0}
  ' pins the layer to the camera (e.g. a UI-like backdrop). 0 < factor < 1 is parallax;
  ' factor > 1 is a foreground layer that scrolls faster than the world.
  parallaxFactor as BGE.Math.Vector = BGE.Math.VectorOps.create(1, 1)

  ' Whether this layer tiles to cover the canvas along each axis. Both default false
  ' except repeatX, matching the common side-scroller case (repeat horizontally, not
  ' vertically).
  repeatX as boolean = true
  repeatY as boolean = false

  sub new(owner as BGE.GameEntity, region as roRegion, args = {} as roAssociativeArray)
    ' same pattern as Image.new() - sets width/height from region, then m.append(args)
  end sub

  override function addToScene(rendererObj as Renderer) as BGE.SceneObject
    return m.addSceneObjectToRenderer(new BGE.SceneObjectParallaxLayer(m.getSceneObjectName("parallaxLayer"), m), rendererObj)
  end function

end class
```

Position/offset combine with the owning entity exactly like every other `Drawable`
(`owner.position + offset`, per existing `Drawable.getWorldPosition()`) — there is no
special "independent of owner" positioning mode. A consumer who wants a fixed background
attaches the layer to a dedicated static entity themselves; the engine doesn't enforce
that.

### `SceneObjectParallaxLayer` (`src/source/engine/renderer/sceneObjects/SceneObjectParallaxLayer.bs`)

New class extending `BGE.SceneObject` **directly** (not `SceneObjectBillboard`) — a
parallax layer is always flat 2D (never oriented/backface-culled/temp-bitmap-warped), and
may draw several tiled copies per frame, so it deliberately avoids
`SceneObjectBillboard`'s per-object 3D/orientation machinery entirely. Its own draw path
is a handful of direct `renderer.drawObject()`/`drawScaledObject()` calls.

Responsibilities:

1. **Effective world position.** Each recompute (see dirty-checking below), compute the
   parallax-shifted position per axis:
   `effective = ownerWorldPosition + (1 - parallaxFactor) * (cameraPosition - referencePosition)`
   where `referencePosition` is the layer's own base world position at rest (not to be
   confused with `Drawable.anchor`, the unrelated normalized 0-1 pivot-point concept used
   by `setAnchor()`) — so a factor of exactly `{1,1}` is a no-op —
   `effective == ownerWorldPosition` regardless of camera position, matching ordinary
   drawable behavior. `referencePosition` is captured once, the first time this scene
   object computes its world position (construction/first frame) — a fixed baseline the
   camera-relative shift is measured against, independent of whether the owning entity
   itself moves afterward. Convert to canvas space via the existing
   `Renderer.worldPointToCanvasPoint()` (same as every other `SceneObject`).
2. **Tile enumeration.** If `repeatX`, compute `tileWidth = region.getWidth() * scale.x`
   (`tileHeight` analogously for `repeatY`), figure out how many copies are needed to
   cover the canvas viewport in that axis
   (`ceil(canvasSize / tileSize) + 1` — the `+1` covers a partially-scrolled edge), and the
   first copy's position via `effectiveCanvasPos mod tileSize` (adjusted so the leftmost/
   topmost visible copy is always at or before the viewport edge). Store this as a plain
   array of draw positions recomputed only when dirty, not built fresh every single frame
   redundantly inside `draw()`.
3. **Draw.** For each computed tile position, call `rendererObj.drawObject()` (or
   `drawScaledObject()` if `scale <> {1,1}`), each call already counted by the renderer's
   existing `drawCallsLastFrame` bookkeeping — no separate cost-tracking needed.

### Camera-movement dirty-checking (the one real gotcha — resolved without touching `SceneObject`)

The original concern here: `SceneObject.update()`'s `forceRecompute` (`SceneObject.bs:214`)
is gated on the *drawable* having moved, not the camera, and `update()` is explicitly
documented "Do not override this function!" — so a naive override was never actually an
option.

Closer reading of `SceneObject.bs` found this doesn't need solving in `update()` at all.
`SceneObject.draw()` (also not to be overridden) decides whether to recompute *canvas*
position via `objMovedInRelationToCamera(cameraObj)`, and that method's **default
implementation already ORs in camera movement**:
`m.drawable.movedLastFrame(true) or cameraObj.movedLastFrame()` (`SceneObject.bs:375`).
That means the parallax math belongs entirely in an overridden `findCanvasPosition()` —
called from `draw()`, already re-invoked correctly whenever the camera moves, with zero
changes to the shared base class. `updateWorldPosition()` (the `update()`-phase hook)
keeps the inherited default (`m.worldPosition = m.drawable.getWorldPosition()` —
just the plain owner-relative position, unaffected by parallax); the parallax shift and
tile enumeration both happen in `findCanvasPosition()`:

```brightscript
protected override function findCanvasPosition(rendererObj as Renderer, drawMode as SceneObjectDrawMode) as boolean
  cameraPos = rendererObj.camera.position
  delta = BGE.Math.VectorOps.subtract(cameraPos, m.referencePosition)
  shift = BGE.Math.VectorOps.multiply(BGE.Math.VectorOps.subtract(BGE.Math.VectorOps.create(1, 1), m.drawable.parallaxFactor), delta)
  effective = BGE.Math.VectorOps.add(m.worldPosition, shift)
  baseCanvasPos = rendererObj.worldPointToCanvasPoint(effective)
  ' ... tile enumeration (below) builds m.tileCanvasPositions from baseCanvasPos
  return invalid <> baseCanvasPos
end function
```

`m.referencePosition` is captured once (first call) as `m.worldPosition` at that point —
the fixed baseline the camera-relative shift is measured against, per the effective-
position formula above. This composes cleanly with `worldPointToCanvasPoint()`'s existing
camera subtraction: passing `effective` through the normal projection (which already
subtracts `cameraPosition` once) combined with `effective`'s own `(1 - factor)` term
nets out to exactly `-factor` sensitivity to camera movement — `factor = 1` cancels to
ordinary 1:1 scrolling, `factor = 0` pins to the camera, and no separate case is needed
for either end of the range.

### Sub-pixel accumulation

Resolved the same way, for free: `Camera2d.worldPointToCanvasPoint()` already does the
one and only rounding (`fix()`) at the very end of its own conversion. As long as
`findCanvasPosition()` keeps `effective` in float world-space and calls the existing
`worldPointToCanvasPoint()` rather than rounding anything itself, there's no separate
"don't round early" mechanism to build — this falls out of reusing the existing camera
projection rather than reimplementing any part of it.

### Draw order

v1 relies entirely on the existing distance-from-camera sort in `Renderer.drawScene()` —
no renderer changes. A consumer places a background layer behind everything by giving its
owning entity/offset a suitably negative Z (or a positive Z for a foreground layer scrolling
in front of gameplay). This is an explicit v1 simplification; a more robust mechanism is
left to #59.

## Testing

- `DrawableParallaxLayer.spec.bs`: construction/field defaults, combines with owner
  position like a normal drawable.
- `SceneObjectParallaxLayer.spec.bs` (constructing a real `Game`/`GameEntity`, per this
  repo's Rooibos conventions):
  - factor `{1,1}` behaves identically to an ordinary drawable regardless of camera
    position/movement.
  - a moved camera with factor `{0.5, 0.5}` shifts the effective position by exactly half
    the camera's delta.
  - tile count/position math for a few canvas-size/tile-size combinations, including the
    "+1 safety tile" edge case.
  - sub-pixel offsets aren't lost to premature rounding (assert against an accumulated
    float delta smaller than 1px, across several small camera moves).
  - recompute fires on camera-only movement (regression test for the dirty-checking gotcha
    above) — reuses the "bracket-index a private field to construct a targeted regression"
    technique already established for `TweenManager`'s delay-timer test.

## Definition of done

- `DrawableParallaxLayer`/`SceneObjectParallaxLayer` implemented and unit-tested per above.
- `examples/parallax` (scaffolded via `npm run create-example -- parallax "Parallax
  Example"`): a real `Game`/`Room`, a controllable entity, `Camera2d.setTarget()` following
  it, and 2-3 procedurally-drawn layers (flat-color shapes via `roBitmap` draw calls —
  mountains/hills/sun, no external image assets needed) at different parallax factors,
  including at least one foreground layer (`factor > 1`).
- `docs/drawables-and-scene-objects.md` updated alongside the other drawable/scene-object
  pairs.
