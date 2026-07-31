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
- A `rendererTest` demo proving the mechanics and measuring cost.

Out of scope (explicitly deferred):
- Any dedicated end-to-end example (`examples/parallax` or similar) demonstrating this via
  a real `Game`/`Room`/`Camera2d.setTarget()`-follow setup — filed as its own follow-up
  issue once this lands, matching how #79 followed #60 (`TweenManager`) with
  `examples/tweens`. Not needed for this issue's own definition of done.
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

### Camera-movement dirty-checking (the one real gotcha)

`SceneObject.update()`'s `forceRecompute` (`SceneObject.bs:214`) is currently gated on the
*drawable* having moved, not the camera — correct for ordinary drawables, wrong for a
parallax layer whose *effective* position changes purely from camera movement even when
the drawable itself is static. `SceneObjectParallaxLayer` overrides the recompute
condition to also fire when `cameraObj.movedLastFrame()` is true, mirroring how
`negDistanceFromCamera`'s own recompute already ORs in camera movement at
`SceneObject.bs:220`. Without this, a parallax layer would visibly freeze on every frame
where only the camera pans.

### Sub-pixel accumulation

The per-axis parallax offset must be carried as a float through to the final canvas
position, and only rounded (`cint()`/similar) at the point of handing coordinates to
`renderer.drawObject()` — the same rounding boundary `Game.shouldUseIntegerMovement`
already respects elsewhere. Rounding earlier would make slow layers (small factor, moving
a fraction of a pixel per frame) visibly stutter. This falls out naturally as long as step
1 above stays in float world-space math until the very last conversion.

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
- A `rendererTest` demo (real, permanent — registered in `DemoList.bs`, not a scratch
  spike) showing 2-3 procedurally-drawn layers (flat-color shapes via `roBitmap` draw
  calls — mountains/hills/sun, no external image assets needed) at different parallax
  factors scrolling as a simulated camera pans, with the automatic fps/draw-call timing
  every `rendererTest` demo gets for free.
- `docs/drawables-and-scene-objects.md` updated alongside the other drawable/scene-object
  pairs.
- A follow-up issue filed for a dedicated `examples/parallax` (or folded into
  `examples/platformer`, #62, once that exists) demonstrating this through a real
  `Game`/`Room`/`Camera2d.setTarget()`-follow setup — not required for this issue's own
  completion.
