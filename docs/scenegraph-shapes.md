---
title: SceneGraph Shape Components
group: Guides
order: 4
---

# SceneGraph Shape Components

BGE ships four `Poster`-extending SceneGraph components under `components/Shapes/` -
`RoundedRectangle`, `Circle`, `Triangle`, `Polygon` - that render shapes SceneGraph has no
native node for, using `BGE.Renderer` internally. Drop one in your scene and get a rendered
shape with no offscreen-bitmap plumbing of your own: no `BGE.Game`, no `Room`, no `roScreen`.
See `examples/scenegraph` for a runnable demo of all four.

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

`Triangle` and `Polygon` take a `vertices` field - an array of `{x, y}` points local to the
shape's own bitmap - which can't be expressed as a plain XML attribute, so set it from code:

```brightscript
m.polygon.vertices = [
  {x: 100, y: 0},
  {x: 200, y: 100},
  {x: 100, y: 200},
  {x: 0, y: 100}
]
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
- `Triangle.vertices` / `Polygon.vertices` (`array`, optional/required respectively) - see above.

## How it works

Each component owns exactly one private `BGE.Renderer` over its own `roBitmap`. Every field
that affects the rendered shape is observed by a single `onShapeFieldChanged` handler, which:

1. Hashes the shape type plus the current field values (`roEVPDigest` SHA1) into a
   `tmp:/bge_shape_<hash>.png` filename.
2. If that file already exists, skips rendering entirely and just points `uri` at it - a cache
   hit, since identical field values always hash to the same filename.
3. Otherwise draws via the private `Renderer`, calls `Finish()` (there's no `roScreen` anywhere
   in a pure-SceneGraph process to force a draw through, but plain `Finish()` alone is enough
   to realize the queued draws here - confirmed on real hardware, see below), encodes to PNG
   (`GetPng()`), writes it to `tmp:/`, and sets `uri`.

This makes repeated/discrete field values (toggling between a couple of colors, resizing to a
value you've already used) free after the first render. A continuously-varying value - most
notably an `Animation`-driven tween - produces a new hash every single frame and never benefits
from the cache; see "Animating a shape" below for what that costs in practice.

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

Driving `width`/`height` continuously via an `Animation` also hit an unresolved rendering bug in
testing - forcing `loadSync="true"` (see below) fixed one cause of the shape going blank, but the
shape still intermittently disappeared under a fast repeated-field-change load in
`examples/scenegraph`'s demo. Root cause wasn't isolated given the numbers above already rule out
animation as a supported use case; treat continuous per-frame animation as unsupported rather than
just slow.

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

## Task experiment (issue #61)

Moving a shape's draw+encode+write work onto a `Task` node was prototyped (`CircleTask`/
`TaskCircle` in `examples/scenegraph`, not part of the shipped components) to see whether it
frees up the render thread during a redraw. Measured with a 50ms heartbeat `Timer` on the render
thread (a gap much larger than 50ms means the render thread was blocked):

- A direct/synchronous shape redraw (the shipped design) blocks the render thread for its whole
  ~150-200ms - confirmed by heartbeat gaps of up to 316ms while 4 shapes redrew in sequence at
  startup.
- A `Task`-based redraw's **first ever run costs ~780ms** (Task thread spin-up overhead) but a
  **subsequent ("warm") run costs ~200ms**, matching the direct approach's own cost - and neither
  produced a large heartbeat gap, i.e. the render thread stayed responsive throughout, unlike the
  direct approach.

So a `Task` genuinely improves perceived responsiveness (the rest of the UI keeps ticking during
a redraw) without making that shape's own content appear any faster once warmed up - the
trade-off is a large one-time latency hit on a `Task`'s first use, which a real consumer would
want to pay upfront (e.g. a throwaway warm-up run at app start) rather than on first real use.
This wasn't adopted for the shipped components (it's a real architecture change - one Task node
per shape instance, or a shared pool - beyond this issue's scope) but is a solid direction for a
follow-up if redraw-blocking the render thread becomes a real problem for a consumer.

## ROPM component names

Following this engine's [README](https://github.com/markwpearce/brighterscript-game-engine#readme)
guidance and adding `brighterscript-game-engine` to your own project's `ropm.noprefix`, the
components are available under their plain names: `<RoundedRectangle>`, `<Circle>`,
`<Triangle>`, `<Polygon>`. Without `noprefix`, `ropm` prefixes every component name with your
installed package alias, e.g. `<brighterscriptgameengine_RoundedRectangle>` -
`ropm install` output tells you the exact alias it chose (`ropm: Copying
brighterscript-game-engine@x.y.z as <alias>`).
