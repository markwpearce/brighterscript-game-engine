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
| `outlineWidth` | `integer` | Outline is only drawn when this is `> 0` - there's no separate on/off flag. `Triangle`'s outline is always a single-pixel stroke regardless of this value (it just gates whether one is drawn), since `drawTriangleOutlineTo` has no thickness parameter. |

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

## Animating a shape

You can drive any field with a SceneGraph `Animation`/`*FieldInterpolator` node the same way you
would any other node field:

```xml
<Animation id="anim" repeat="true" duration="2.0">
  <FloatFieldInterpolator key="[0, 0.5, 1]" keyValue="[80.0, 220.0, 80.0]" fieldToInterp="roundedRect.width" />
</Animation>
```

Every redraw this drives is a real, uncached render (see above) - measured on real hardware
(`examples/scenegraph`, redraws/sec counted per shape via a 1-second `Timer`, animating `width`/
`height` continuously on all four shapes at once):

| Shape | Animate-safe? | Notes |
| --- | --- | --- |
| `RoundedRectangle` | Yes | Backed by `DrawRect` + a cached circle-resource blit for the corners - cheap per the repo's own draw-cost benchmarks. |
| `Circle` | Yes | A single scaled blit of the shared circle resource, plus a handful of `DrawLine` calls for the outline. |
| `Triangle` | Yes | Two `drawTransformedObjectTo` calls per triangle (see `drawTriangleTo`) - not free, but well within a per-frame budget for one shape. |
| `Polygon` | Static-only for anything but a small vertex count | Fan-triangulated (`BGE.QuickHull` + one `drawTriangleTo` per resulting triangle) - cost scales with vertex count, and rasterizing a rotated/warped triangle is one of the most expensive `ifDraw2D` operations on real hardware (see `examples/rendererTest`'s benchmarks). A 4-vertex diamond animated smoothly in testing; a polygon with many more vertices should be redraw-on-change only, not continuously animated. |

Note that `Polygon`'s `vertices` are fixed local coordinates, independent of `width`/`height` -
animating `width`/`height` alone (as the `examples/scenegraph` demo does, purely to measure
redraw cost) reshapes the bitmap without rescaling the points, which visibly clips the polygon
as it shrinks. A real scaling animation should recompute and re-assign `vertices` directly
instead.

## Hardware findings (issue #61)

Two things called out as open questions in this feature's design were verified on a real Roku,
not just the simulator:

- **`Finish()` alone is sufficient** to realize a `Triangle`/`Polygon` draw with zero `roScreen`
  anywhere in the process. `BGE.Renderer.forceDraw()` (used internally by the lazy
  `getRightTriangleResource()` build the first time any triangle is drawn) has a dummy-screen
  fallback path for realizing queued draws on real hardware, but that path only runs when
  `m.dummyScreen` is valid - which it never is for a `Renderer` constructed without a `Game`, as
  every shape component's private `Renderer` is. Plain `Finish()` on the bitmap was enough; no
  workaround (constructing a throwaway `roScreen` inside the component) was needed.
- **Animation cost is genuinely per-shape**, not a single yes/no for the feature - see the table
  above.

## ROPM component names

Following this engine's [README](https://github.com/markwpearce/brighterscript-game-engine#readme)
guidance and adding `brighterscript-game-engine` to your own project's `ropm.noprefix`, the
components are available under their plain names: `<RoundedRectangle>`, `<Circle>`,
`<Triangle>`, `<Polygon>`. Without `noprefix`, `ropm` prefixes every component name with your
installed package alias, e.g. `<brighterscriptgameengine_RoundedRectangle>` -
`ropm install` output tells you the exact alias it chose (`ropm: Copying
brighterscript-game-engine@x.y.z as <alias>`).
