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

## Animation experiment — findings and resulting redesign

Measured on real hardware: all four shapes cost ~150-200ms per redraw (PNG encode/decode
dominates, not draw complexity) — none are animate-safe at a real per-frame rate. A synchronous
redraw (`Poster`-extending component doing the render inline) fully blocks the render thread for
that whole span (confirmed via a heartbeat timer showing gaps up to 316ms). A `Task`-based redraw
costs about the same wall-clock warm (~200ms; ~780ms cold, one-time thread spin-up) but with
**zero render-thread blocking** — this is the escalation the original issue anticipated
("Poster first, Task as an escalation... if measurement shows it janks").

Separately, a real bug: `extends="Poster"` reusing Poster's own native `width`/`height` fields
for the redraw trigger means Poster's built-in auto-scale-to-fit stretches the *previous*
(stale) bitmap to the newly-set size on every composited frame until the redraw finishes and
swaps `uri` — visibly distorting a rounded rectangle's corners into ellipses during any
width/height change. Async (Task-based) rendering makes this window *longer*, not shorter, so it
must be fixed regardless of sync-vs-Task.

**Resulting design (shipped)**: every shape component extends `Group`, not `Poster`, with one
child `Poster` node (`id="image"`) whose `width`/`height` are never explicitly set (so it always
displays its loaded image at native pixel size — no auto-scale, no race) — only its `uri` is
ever swapped, and only once a render actually finishes. A plain custom `uri` field is
re-declared on the `Group` wrapper itself (safe, since `Group` has no native `uri` semantics) so
external consumers observing `<shape>.uri` for "redraw completed" keep working unchanged.
Rendering itself runs in **one shared, generic `Task` component**
(`components/Shapes/ShapeRenderTask.xml`/`.bs`, not four near-duplicate Task subclasses) that
takes a `shapeType` field, a `uri` field (the target cache file, computed by the calling
component), and the union of draw-parameter fields the four shapes need (`width`, `height`,
`color`, `outlineColor`, `outlineWidth`, `cornerRadius`, `outlineSegments`, `vertices`), and
dispatches internally to the matching `Renderer.draw*To`/`draw*OutlineTo` call(s) — the same
`shapeType`-driven pattern `ShapeComponentHelpers` already used for cache-key hashing. Each
component creates one persistent instance of this Task in `init()` and reuses it across redraws
by reassigning fields and setting `control="RUN"` again (confirmed on real hardware: no
`control="STOP"` needed first) — so the ~780ms cold-start cost is paid once per component
instance, not per redraw, the same "pay once, cache after" pattern
`Renderer.getRightTriangleResource()` already uses for its own one-time cost.

The cache-hit check (`BGE.ShapeComponentHelpers.checkShapeCache()`, `MatchFiles` against the
content-hash filename) stays synchronous in the component's own script, run *before* ever
touching the Task, so a cache hit costs nothing beyond the hash + file check and never spins up
the Task at all. On a miss, `BGE.ShapeComponentHelpers.createShapeRenderState()` (called from
inside the Task, off the render thread) creates the `roBitmap`/`BGE.Renderer` pair to draw into,
and `finishShapeRender()` (unchanged) does the `Finish()`/`GetPng()`/`WriteFile()`. This is the
split `beginShapeRender()` was refactored into: the old function's cache-check half became
`checkShapeCache()` (now callable from the render thread with no bitmap involved), and its
render-setup half became `createShapeRenderState()` (now callable from the Task thread, always
past a confirmed cache miss).

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
