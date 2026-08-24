---
title: SceneGraph Shape Components
group: Guides
order: 4
---

# SceneGraph Shape Components

BGE ships four SceneGraph components under `components/Shapes/` - `RoundedRectangle`,
`Circle`, `Triangle`, `Polygon` - that render shapes SceneGraph has no native node for, using
`BGE.Renderer` internally. Drop one in your scene and get a rendered shape with no
offscreen-bitmap plumbing of your own: no `BGE.Game`, no `Room`, no `roScreen`. See
`examples/scenegraph` for a runnable demo of all four.

Internally each component is a `Group` wrapping a child `Poster` and a shared render `Task`,
but none of that is visible to a consumer - same tags, same fields, same positioning via
`translation` as a simpler `Poster`-extends design would have. That's the point: it hides an
off-render-thread redraw behind an interface indistinguishable from a native node's.

## Usage

```xml
<RoundedRectangle
  translation="[100, 100]"
  width="220" height="160" cornerRadius="24"
  color="0xFF6B35FF"
  outlineColor="0x1B1B1BFF" outlineWidth="4" />

<Circle
  translation="[380, 100]"
  width="180" height="180"
  color="0x3AAFA9FF"
  outlineColor="0x1B1B1BFF" outlineWidth="4" outlineSegments="48" />
```

`Triangle` and `Polygon` take a `vertices` field (`vector2darray`) - points local to the shape's
own bitmap - settable directly from XML:

```xml
<Polygon
  translation="[860, 180]"
  width="200" height="200"
  color="0xE85D75FF"
  vertices="[[100,0],[200,60],[160,200],[40,200],[0,60]]" />
```

or imperatively as an array of `{x, y}` associative arrays (both forms are accepted):

```brightscript
m.polygon.vertices = [{x: 100, y: 0}, {x: 200, y: 100}, {x: 100, y: 200}, {x: 0, y: 100}]
```

`Triangle.vertices` is optional - when empty (the default), it draws a right triangle sized
from `width`/`height` instead. `Polygon.vertices` is required; nothing is drawn until it's set.

### Common fields

| Field | Type | Notes |
| --- | --- | --- |
| `color` | `color` | Fill color, packed RGBA (`0xRRGGBBAA`) - the same convention every `BGE.Renderer.draw*` call uses. |
| `width` / `height` | `float` | The shape's own bitmap size. |
| `outlineColor` | `color` | Packed RGBA. |
| `outlineWidth` | `integer` | Outline is only drawn when this is `> 0` - there's no separate on/off flag. `RoundedRectangle`/`Polygon` stroke a real `outlineWidth`-thick ring; `Circle`/`Triangle` always draw a single-pixel stroke regardless of this value (it just gates whether one is drawn), since `drawCircleOutline`/`drawTriangleOutlineTo` have no thickness parameter. |

### Shape-specific fields

- `RoundedRectangle.cornerRadius` (`float`) - clamped to at most half of `width`/`height`.
- `Circle.outlineSegments` (`integer`) - number of line segments approximating the outline circle.
- `Triangle.vertices` / `Polygon.vertices` (`vector2darray`, optional/required respectively) - see above.

## How it works

Each shape component is a `Group` wrapping one child `Poster` (`id="image"`) and one persistent
child `BGE_ShapeRenderTask`-style `Task` node created once in `init()` and reused across
redraws. The child `Poster`'s `width`/`height` are never set - only its `uri` is ever swapped,
and only once a render has actually finished - so there's no frame where a stale image gets
stretched into a newly-set box (see "A fixed bug" below). Every field that affects the rendered
shape is observed by a single `onShapeFieldChanged` handler, which:

1. Hashes the shape type plus the current field values (`roEVPDigest` SHA1) into a
   `tmp:/bge_shape_<hash>.png` filename and checks whether that file already exists
   (`BGE.ShapeComponentHelpers.checkShapeCache()`) - synchronously, on the render thread, with
   no bitmap/`Task` work either way.
2. On a cache hit, skips rendering entirely and just points the internal `Poster.uri` (and the
   component's own `uri` field) at the existing file.
3. On a miss, pushes the draw parameters onto the component's persistent render `Task` and sets
   `control="RUN"`. The `Task` (off the render thread) draws via its own private
   `BGE.Renderer`/`roBitmap`, calls `Finish()` (there's no `roScreen` anywhere in a
   pure-SceneGraph process to force a draw through, but plain `Finish()` alone is enough to
   realize the queued draws here - confirmed on real hardware, see below), encodes to PNG
   (`GetPng()`), and writes it to `tmp:/`. The component observes the `Task`'s `resultUri` field
   and, once it fires, sets the internal `Poster.uri` and the component's own `uri`.

This makes repeated/discrete field values (toggling between a couple of colors, resizing to a
value you've already used) free after the first render. A continuously-varying value - most
notably an `Animation`-driven tween - produces a new hash every single frame and never benefits
from the cache; see "Animating a shape" below for what that costs in practice.

All four shape components share one `ShapeRenderTask` component (`components/Shapes/
ShapeRenderTask.xml`/`.bs`) rather than four near-duplicate `Task` subclasses - it takes a
`shapeType` field plus the union of draw parameters every shape might need, and dispatches
internally to the matching `BGE.Renderer.draw*To`/`draw*OutlineTo` call(s).

## Animating a shape (not recommended)

You can drive any field with a SceneGraph `Animation`/`*FieldInterpolator` node the same way you
would any other node field, but measured on real hardware (`examples/scenegraph`, a `roTimespan`
timing each redraw end-to-end), **every shape costs roughly the same ~150-200ms per redraw**,
regardless of shape complexity:

| Shape | Draw+encode+write | Full round trip (redraw -> visible) |
| --- | --- | --- |
| `RoundedRectangle` | ~55-70ms | ~150-200ms |
| `Circle` | ~55-75ms | ~150-165ms |
| `Triangle` | ~50-60ms | ~150-165ms |
| `Polygon` (4-vertex diamond) | ~55-75ms | ~150-180ms |

The draw call itself is cheap and does scale with shape complexity as expected, but it's a small
fraction of the total - PNG encoding (`GetPng()`), the `tmp:/` file write, and the `Poster`'s own
image decode dominate for every shape alike. That caps every shape at roughly 5-7 redraws/second,
too slow for smooth continuous animation - **all four are redraw-on-change components, not
animate-safe ones**, regardless of shape type. A discrete/repeated value (toggling between a
couple of colors) is still free after the first render, per the caching above.

Because the draw+encode+write work now runs on the shared `Task` (see below), a continuous
`Animation` blocks the render thread far less than the original synchronous design did - but
**not to zero**, measured with all four shapes animating at once (`examples/scenegraph`'s demo,
a 50ms heartbeat `Timer`): moving the redraw off-thread removes the ~150-200ms draw+encode+write
blocking window entirely, but the internal `Poster`'s own image decode still runs synchronously
on the render thread (`loadSync="true"`, required - see "A fixed bug" and "Hardware findings"
below for why), and with four shapes redrawing concurrently that residual cost still produced
heartbeat gaps up to ~287ms over a 20-second sustained run (100 gaps over 70ms in that window),
not far below the original fully-synchronous design's worst case of ~316ms. **Treat "moves
redraw off the render thread" as a real, measured improvement in the common case (one shape
redrawing occasionally), not as a guarantee of zero blocking under sustained multi-shape
animation** - the remaining cost is dominated by synchronous image decode and/or thread
scheduling contention between four concurrent `Task`s and the render thread on real hardware,
not anything the `Task` itself left undone. Regardless, the shape itself still only visibly
updates at ~5-7 redraws/second, since each individual render still costs ~150-200ms - expect a
shape driven by a fast `Animation` to visibly lag a step or two behind the interpolator's actual
current value, not to redraw at the interpolator's own frame rate.

## Hardware findings (issue #61)

- **`Finish()` alone is sufficient** to realize a `Triangle`/`Polygon` draw with zero `roScreen`
  anywhere in the process. `BGE.Renderer.forceDraw()` (used internally by the lazy
  `getRightTriangleResource()` build the first time any triangle is drawn) has a dummy-screen
  fallback path for realizing queued draws on real hardware, but that path only runs when
  `m.dummyScreen` is valid - which it never is for a `Renderer` constructed without a `Game`, as
  every shape component's private `Renderer` is. Plain `Finish()` on the bitmap was enough; no
  workaround (constructing a throwaway `roScreen` inside the component) was needed.
- **`roFileSystem` is MAIN|TASK-only** - `CreateObject("roFileSystem")` fails on the SceneGraph
  render thread every shape component script runs on, confirmed by a real crash on hardware
  (`'Dot' Operator attempted with invalid BrightScript Component or interface reference`). The
  global `MatchFiles()` function has no such restriction and is used for the cache-hit check
  instead.
- **`Poster.uri` does not accept a `roBitmap` directly** - assigning one instead of a file URI
  silently renders nothing (confirmed on hardware). The PNG-file round trip isn't an optional
  optimization opportunity; it's the only path found to get pixels into a `Poster` here.
- **A field's `onChange` XML attribute and a same-name `m.top.observeField()` call both fire** -
  registering both (an early draft of these components did, redundantly) doubles every redraw,
  including the initial paint. Fixed by relying on `onChange` alone.
- **`control="RUN"` on an already-idle `Task` node can be set again to re-run it** - no
  `control="STOP"` needed first. Confirmed on real hardware: each shape component keeps one
  `ShapeRenderTask` instance for its whole lifetime and just reassigns its fields plus
  `control="RUN"` on every cache-miss redraw.
- **The internal `Poster`'s `loadSync` must stay `"true"`, even with `Task`-based rendering** -
  tried removing it (since the `Task` now naturally throttles how often `uri` actually changes,
  to ~5-7/second, the same rate that made the original `TaskCircle` prototype's default-async
  load safe). Confirmed on real hardware that this does **not** hold for the shipped multi-shape
  design: with `loadSync` left at `Poster`'s async default, all four shapes went completely
  blank under `examples/scenegraph`'s concurrent 4-shape `Animation` (redraw counts kept
  climbing normally - the render/cache/`Task` pipeline was working - but nothing ever displayed).
  Reverting to `loadSync="true"` fixed it. Root cause not fully isolated, but the width/height
  race this component design already exists to avoid (see below) is the likely mechanism:
  something about very-close-together async decodes on the same `Poster` node under load
  apparently loses image data rather than just lagging. Async is not worth the risk here even
  though it measurably reduces render-thread blocking (see "Task-based rendering" below) - a
  blank shape is a worse failure than an occasionally-janky heartbeat.

## A fixed bug: width/height auto-scale race

An earlier version of these components extended `Poster` directly and reused `Poster`'s own
native `width`/`height` fields as the redraw trigger. `Poster` auto-scales its currently-loaded
`uri` image to fit those fields on every composited frame - so the instant an `Animation` (or
any other caller) changed `width`/`height`, `Poster` immediately stretched the *previous* (stale)
bitmap into the newly-set box, and only once the redraw finished ~150-200ms later did `uri` catch
up to a correctly-proportioned image. This was visible as `RoundedRectangle`'s corners briefly
distorting into ellipses (and similar distortion for the other shapes) during any width/height
change - moving that redraw onto a `Task` (see below) made the window *longer*, not shorter, so
this had to be fixed regardless of sync-vs-`Task`.

The fix: every shape component is a `Group`, not a `Poster`, wrapping one child `Poster`
(`id="image"`) whose `width`/`height` are never explicitly set - it always displays its loaded
image at native pixel size, so there's no frame where size and image can disagree. Only the
child `Poster`'s `uri` is ever swapped, and only once a render has actually finished.

## Task-based rendering (issue #61)

Moving a shape's draw+encode+write work onto a `Task` node was prototyped first (`CircleTask`/
`TaskCircle`, since removed) to check whether it frees up the render thread during a redraw
before committing to the architecture change - it measurably does, and this is now the shipped
design (see "How it works" above: one persistent `ShapeRenderTask` per component instance,
reused via `control="RUN"`). Measured with a 50ms heartbeat `Timer` on the render thread (a gap
much larger than 50ms means the render thread was blocked):

- The original direct/synchronous shape redraw blocked the render thread for its whole
  ~150-200ms - confirmed by heartbeat gaps of up to 316ms while 4 shapes redrew in sequence at
  startup.
- A `Task`-based redraw's **first ever run costs ~780ms** (Task thread spin-up overhead) but a
  **subsequent ("warm") run costs ~200ms**, matching the direct approach's own cost.
- With a single shape redrawing occasionally (the original `TaskCircle` prototype's test), no
  large heartbeat gap was produced at all - the render thread stayed fully responsive.
- With all four shapes redrawing concurrently and continuously (`examples/scenegraph`'s
  `Animation` demo, the harder and more realistic stress case), the render thread was **not**
  fully insulated: over a sustained 20-second run, 100 heartbeat gaps exceeded 70ms (out of
  ~400 expected heartbeats), with a worst case of ~287ms - close to (if usually somewhat better
  than) the original synchronous design's own worst case of ~316ms measured the same way. This
  residual cost is not the draw+encode+write work (confirmed moved off-thread), but is
  consistent with the internal `Poster`'s synchronous image decode (`loadSync="true"`, required -
  see "Hardware findings" above) plus general OS-level thread-scheduling contention between four
  concurrent `Task`s and the render thread on real hardware.

So a `Task` is a real, measured improvement - it eliminates the single largest cost
(draw+encode+write) from the render thread and keeps things fully smooth for the common case of
one shape occasionally redrawing - but **does not eliminate render-thread blocking down to zero
once several shapes redraw concurrently and continuously**. Don't repeat "moves rendering off
the render thread" as a blanket "the UI never stutters" claim; it's a substantial mitigation, not
a complete fix, for this shipped multi-shape design. Separately, there's still a one-time
~780ms latency hit the first time each component instance actually
redraws (its `ShapeRenderTask`'s first `control="RUN"`), which a latency-sensitive consumer may
want to pay upfront (e.g. constructing the shape off-screen ahead of when it needs to appear)
rather than on the shape's first real use.

## ROPM component names

Following this engine's [README](https://github.com/markwpearce/brighterscript-game-engine#readme)
guidance and adding `brighterscript-game-engine` to your own project's `ropm.noprefix`, the
components are available under their plain names: `<RoundedRectangle>`, `<Circle>`,
`<Triangle>`, `<Polygon>`. Without `noprefix`, `ropm` prefixes every component name with your
installed package alias, e.g. `<brighterscriptgameengine_RoundedRectangle>` -
`ropm install` output tells you the exact alias it chose (`ropm: Copying
brighterscript-game-engine@x.y.z as <alias>`).
