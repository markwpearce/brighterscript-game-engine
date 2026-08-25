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
   into `cachefs:/bge_shape_<hash>.png` — `cachefs:/`, not `tmp:/`, so identical inputs stay
   cached permanently across app relaunches, not just within one session (the filename is a
   pure function of the inputs, so this is always safe; the OS may still evict it under storage
   pressure, handled by re-rendering on a miss like any other cache miss).
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
costs about the same wall-clock warm (~200ms; ~780ms cold, one-time thread spin-up); with a
single shape redrawing occasionally, this produced **zero measurable render-thread blocking** —
this is the escalation the original issue anticipated ("Poster first, Task as an escalation... if
measurement shows it janks").

**Update after shipping the full multi-shape design** (see "Resulting design" below): the
single-shape "zero blocking" result does not fully hold once all four shapes redraw concurrently
and continuously (`examples/scenegraph`'s `Animation` demo). Over a sustained 20-second run, 100
heartbeat gaps exceeded 70ms, worst case ~287ms — a real improvement over the fully-synchronous
design's own worst case (~316ms, same test) but not the complete fix "zero blocking" implies.
The residual cost isn't the draw+encode+write work (confirmed moved off-thread); it's consistent
with the internal `Poster`'s synchronous image decode (`loadSync="true"`, required — see below)
plus general OS-level thread-scheduling contention between four concurrent `Task`s and the
render thread on real hardware. See docs/scenegraph-shapes.md's "Task-based rendering" section
for the full numbers and caveat.

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

The internal `Poster`'s `loadSync` field must stay `"true"` even with `Task`-based rendering —
tried defaulting it to `Poster`'s normal async load instead (reasoning: the `Task` now throttles
`uri` reassignment to ~5-7/second on its own, the same rate that already made the `TaskCircle`
prototype's async load safe), but confirmed on real hardware this doesn't hold for the shipped
four-shape design: with async load, all four shapes went completely blank under sustained
concurrent animation (redraw counts kept climbing normally — the pipeline was working — nothing
ever displayed). Reverted to `loadSync="true"`. Root cause not fully isolated; the async
regression traded a worse failure (blank shape) for a smaller one (more render-thread blocking),
so `loadSync="true"` stays the shipped default despite its real render-thread cost — see
"Update after shipping" above.

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

## Multi-attribute redraw coalescing (issue #61 follow-up)

A shape constructed with several redraw-triggering fields set as XML attributes on one tag
(e.g. `<RoundedRectangle width="220" height="160" cornerRadius="24" color="0xFF6B35FF" />`)
redrew once per attribute, not once per tag — a real cache-miss render each time, since the
whole point of the fix is to still work correctly on the very first construction (no cache hit
yet). A first attempt switched the redraw trigger from XML `onChange=` to `observeField()`
registered once in `init()`, on the theory that SceneGraph batches a tag's XML-attribute
application into one signal after construction finishes. **That theory is wrong** — proven on
real hardware with diagnostic call-count logging: `observeField()` fires exactly once per field,
exactly like `onChange=` did; there is no batching. The true construction order is `init()` runs
first (queuing its own initial redraw with default field values), then each XML attribute is
applied afterward, each one independently notifying its observer. That first attempt's apparent
success was an accident of Task pre-emption: reusing one `ShapeRenderTask` instance across
redraws means an in-flight run's fields get silently overwritten by a later `redraw()` call
before it completes, so only the *last* of several redraws actually finished and got cached —
`redraw()` itself was still being called once per attribute, it just wasn't visible in the
render-completion counts, and this behavior isn't guaranteed to hold under different timing.

The actual fix is a debounce, not a change of trigger mechanism: `onShapeFieldChanged` (and
`init()`'s own initial trigger) never call `redraw()` directly — they restart a `duration="0"`
`Timer` child node (`m.redrawTimer.control = "stop"` then `"start"`), and only the timer's own
`fire` event calls the real `redraw()`. SceneGraph applies every attribute on an XML tag
synchronously before the render thread next processes timer/event callbacks, so N attribute
values set on one tag restart the timer N times but only the last restart survives to fire —
coalescing into exactly one real redraw. Verified on real hardware with temporary diagnostic
prints counting both "field changed, timer restarted" and "timer fired, real redraw ran" calls
directly (not inferred from render-completion log lines, which is exactly what masked the first
attempt's real behavior): every shape showed the targeted N:1 ratio, e.g. `RoundedRectangle`
with 4 attributes set produced 4 restarts and exactly 1 real redraw; a zero-attribute
`<Circle />` relying entirely on defaults produced 0 restarts and exactly 1 real redraw (from
`init()`'s own trigger). A single post-construction imperative field change (the demo's
Left-button color toggle) still redraws correctly, with the debounce adding roughly 1ms of
latency on real hardware — negligible against the ~150-200ms render round trip. The sustained
`Animation`-driven redraw path (repeated field changes at runtime, a different scenario from
construction-time batching) was re-verified over a 20-second run and continues to work
unchanged by the debounce. See `docs/scenegraph-shapes.md`'s "Hardware findings" section for the
full write-up.

## Example

`examples/scenegraph` — pure SceneGraph app (manifest `main_scene`, `roSGScreen` only, no
`roScreen` fallback anywhere in the process, unlike `examples/hybrid`). Demonstrates all four
shapes, static and (where it survives measurement) animated.

## Mass-construction stress test (issue #61 follow-up)

The 4-shape `examples/scenegraph` demo never exercises more than 4 concurrent `ShapeRenderTask`
instances - each shape component owns its own persistent Task, not a shared pool, so a scene
with 20-30 shape instances means 20-30 near-simultaneous Task spin-ups. This was never measured.
Added `examples/scenegraph`'s `StressScene` (reachable via `scene=stress`/`spec=<variant>:<count>`
launch params, not the default view) to build a grid of `RoundedRectangle`-only or mixed-type
shapes and measure this on real hardware.

**Found and fixed**: every shape component's private `Renderer` used the default
`useBitmapPooling: true`, eagerly preallocating a ~44MB `ScratchBitmapPool` (10 scratch bitmaps
at the device's scratch-tier size) per `Renderer`, regardless of whether that render ever needs
one. At 25+ concurrent shapes this exhausted available bitmap memory on real hardware -
`Failed to create bitmap for ScratchBitmap with id: N` spam, individual render times up to 10x
the documented baseline, and several shapes permanently stuck mid-render. Fixed in
`BGE.ShapeComponentHelpers.createShapeRenderState()` by passing `{useBitmapPooling: false}` -
correct since a shape component's `Renderer` is one-shot and disposable, never reused, so pooling
has nothing to amortize. Verified fixed: 25 and 30 concurrent `RoundedRectangle` instances both
completed with zero bitmap-creation failures post-fix (construction time 2213ms/2498ms, max
heartbeat gap 848ms/627ms - both above the 4-shape demo's ~287ms worst case, but no failures).

**Found, not fixed**: mixing all four shape types at count 30 still measured 4-6 shapes (of 30)
silently never completing - no error anywhere, including after adding a diagnostic print to
`ShapeRenderTask.doRender()`'s one known silent-failure path (a failed primary bitmap create).
That print never fired, so the failure lies elsewhere in the `Triangle`/`Polygon` path under this
specific concurrency level. Bisected: `mixed:10`/`mixed:20`/`mixed:25` and `rects:30` (no
triangles/polygons) all completed cleanly and repeatably; only `mixed:30` reproduced the hang,
and the exact count of stuck shapes varied between runs (24/30 and 26/30 observed), suggesting a
resource-contention race rather than a deterministic logic bug. Not root-caused within this
session - documented as a known limitation. See docs/scenegraph-shapes.md's "Mass construction"
section for the user-facing writeup.

Also fixed in the same investigation: setting `StressScene.spec` from `main.bs` after scene
creation used to fire a second, overlapping build on top of the scene's own non-empty XML
default - each `ShapeRenderTask` keeps running once started regardless of its owning node being
torn down, so this stacked extra concurrent Task load on top of the intended count (confirmed via
a real "unusually high number of tasks" OS warning at 51 tasks when only 30 were intended).
Fixed by defaulting `spec` to empty in XML and only building when it's actually set - `main.bs`
now always sets it exactly once, so exactly one build ever happens per launch.

## Definition of done

- All four components ship under `src/components/Shapes/`, verified via
  `npm run test:ropm-consumer` (not `validate-examples`, which bypasses ROPM prefixing).
- Verified on real hardware: renders correctly, `Finish()`-alone confirmed sufficient for the
  Triangle/Polygon resource build, animation performance measured and documented per shape.
- `examples/scenegraph` demonstrates all four; a `docs/` guide covers usage and the
  animate-vs-static caveat per shape.
