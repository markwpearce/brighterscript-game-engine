# SceneGraph shape components (#61)

## Goal

Ship reusable SceneGraph components — `RoundedRectangle`, `Circle`, `Triangle`, `Polygon` —
that behave like native nodes (`<Rectangle>`) but render shapes SceneGraph has no native node
for, using `BGE.Renderer` internally. A consumer `ropm install`s the engine, drops one tag in
their scene, and gets a rendered shape with no offscreen-bitmap plumbing of their own.

## Prior art / grounding

`BGE.Renderer` works over any `ifDraw2d` surface with no `Game`/`roScreen` required
(`Renderer.spec.bs`, `examples/rendererTest`). The QR-code SceneGraph library
(paramount-engineering/QR-Code-generator-brightscript) proves the `Poster`-extends,
`Finish()`+`GetPng()`+`tmp:/`-file pattern works in production for `roBitmap`/`ifDraw2D` draws
inside a SceneGraph component script, and its content-hash filename trick doubles as a cache.

## Hardware risk, narrowed by reading `Renderer.bs`

`forceDraw()` (needed because draws to an offscreen bitmap are queued rather than realized on
real hardware) falls back to `drawSurface.Finish()` alone whenever `m.dummyScreen` is invalid —
true for any `Renderer` built without a `Game`, which is exactly this use case. Tracing every
`forceDraw()` call site:

- `RoundedRectangle`/`Circle` never call it — pure `DrawRect` + a scanline-filled circle
  resource (`createCircleResource`), no scratch bitmaps involved.
- `Triangle`/`Polygon` call it exactly once **per `Renderer` instance**, inside the lazy
  `getRightTriangleResource()` build the first time any triangle is drawn (cached
  afterward in `m.resources.rightTriangle`), not per-draw.

So the one real "does `Finish()` alone work with zero `roScreen` in the whole process" question
is narrow and cheap to verify on real hardware: draw one `Triangle`/`Polygon` in a pure
SceneGraph app and confirm it isn't blank/garbage.

## Architecture

- `src/components/Shapes/`: four `Poster`-extending components, each a thin XML+`.bs` pair.
- `BGE.ShapeRenderer` (`src/source/utils/` or a components-local helper) holds the shared
  redraw/cache logic; each component's script supplies its own draw call:
  - `RoundedRectangle` → `drawRoundedRectangleTo` (+ `drawRectangleOutlineTo` for outline)
  - `Circle` → `drawCircleTo` (+ `drawCircleOutline` for outline)
  - `Triangle` → `drawTriangleTo` (+ `drawTriangleOutlineTo`)
  - `Polygon` → `drawPolygonTo` (+ `drawPolygonOutlineTo`)
- Each component owns exactly one private `BGE.Renderer` over its own `roBitmap`, 1:1 — no
  surface reuse needed, so plain (non-`To`) or `To`-suffixed calls are equivalent; use the `To`
  form for explicitness.

## Fields

Common to all: `color` (fill RGBA), `width`, `height`, `outlineColor`, `outlineWidth`.
Shape-specific: `cornerRadius` (`RoundedRectangle`), `outlineSegments` (`Circle`, feeds
`drawCircleOutline`'s `line_count`), `vertices` (`Polygon`, required array of points; `Triangle`,
optional — defaults to a right triangle sized from `width`/`height` when absent).

## Redraw + caching

Every redraw-triggering field's `onChange` points at one observer function that:

1. Hashes the shape type + current field values (`roEVPDigest` SHA1, same as the QR component)
   into `tmp:/bge_shape_<hash>.png`.
2. If that file already exists, skip the render and just set `m.top.uri` — a cache hit.
3. Otherwise render via the private `Renderer`, `Finish()`, `GetPng()`, `WriteFile`, then set
   `m.top.uri`.

This makes repeated/discrete field values free, but a continuously-varying tween (many distinct
values) redraws every value — no caching benefit there.

## Animation experiment

Try driving a field via a SceneGraph `Animation` node (genuine per-frame redraws, no cache hits)
and measure real FPS/jank per shape on hardware. `RoundedRectangle`/`Circle` are cheap
(`DrawRect`/blit); `Polygon` with many vertices could be expensive (triangle rasterization is
~500/sec per the repo's own benchmark numbers). Each shape documents itself as
animate-safe or static-only based on what's actually measured — this is expected to differ
per shape, not a pass/fail for the whole feature.

## Example

`examples/scenegraph` — pure SceneGraph app (manifest `main_scene`, `roSGScreen` only, no
`roScreen` fallback anywhere in the process, unlike `examples/hybrid`). Demonstrates all four
shapes, static and (where it survives measurement) animated.

## Definition of done

- All four components ship under `src/components/Shapes/`, verified via
  `npm run test:ropm-consumer` (not `validate-examples`, which bypasses ROPM prefixing).
- Verified on real hardware: renders correctly, `Finish()`-alone confirmed sufficient for the
  Triangle/Polygon resource build, animation performance measured and documented per shape.
- `examples/scenegraph` demonstrates all four; a `docs/` guide covers usage and the
  animate-vs-static caveat per shape.
