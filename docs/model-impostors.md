---
title: Model Impostors
group: Guides
order: 21
---

# Model Impostors

A model impostor is a reused picture of a model. A `DrawableModel` draws its faces in full
when it's drawn fresh, and keeps that drawing in a bitmap. While only the camera moves, the
engine draws the bitmap scaled and shifted to where the model now sits, instead of projecting
every vertex and drawing every face again. This is experimental: the fields and quality
settings below may change between releases.

It pays off for big models that stay put while the camera moves around them - a building or a
prop seen while the player walks or orbits. A model that moves or turns itself redraws every
frame anyway, so an impostor gives it nothing; the `flightSim` example turns it off for its
biplane and keeps it on for the course rings, which never move. A model close to the camera,
or one whose view changes a lot, often fails the fit and redraws, so check the frame cost
with the model on and off before you rely on it. The `terrain` example's chapel is the
case where the simple version didn't hit often enough to be worth it.

## How a moving frame is drawn

Each frame the model's capture is still usable, the engine tries these in order:

1. **Single blit.** The capture is scaled and shifted to the model's new place on screen. This
   is the cheapest, and it holds while the change stays inside the render quality's limits
   (see [Quality settings](#quality-settings)).
2. **Strips** (`useImpostorStrips`, on by default). The capture is drawn as vertical strips,
   each scaled to follow the perspective change, so the verticals of a building stay upright
   as the camera turns. It costs more than one blit, but far less than a redraw.
3. **Redraw.** The model is drawn in full and the capture is refreshed.

A redraw also happens when the model itself moves or turns, when its lighting changes by more
than `modelImpostorMaxLightChange`, when the render quality level changes, and when a side that
faced away at capture turns into view (`impostorRedrawOnNewFace`). Small details that turn into
view don't count: sides under `impostorNewFaceMinArea` of the model's surface are ignored.

## Turn it on

`useImpostor` is on for every `DrawableModel`. Set it in the constructor's options or on the
drawable:

```brighterscript
class Barn extends BGE.GameEntity

  override sub onCreate(args as roAssociativeArray)
    m.isStatic = true
    m.position = BGE.Math.VectorOps.create(args.x, 0, args.z)
    drawable = new BGE.DrawableModel(m, m.game.get3dModel("barn"))
    ' the default is on; a model that moves itself gains nothing, so a moving one would set this false
    drawable.useImpostor = true
    m.addDrawable("barn", drawable)
  end sub

end class
```

`examples/flightSim` shows both sides: `Biplane.bs` passes `useImpostor: false` for the moving
plane and its propeller, and `CourseRing.bs` keeps the impostor for rings that never move.
`examples/3d` sets `useImpostor` on every model from one `useImpostors()` switch, which
`?impostor=0` turns off.

## Strips and blit roll

`useImpostorStrips` (default `true`) lets a model try strips before it redraws. Turn it off to
fall back to a redraw as soon as the single blit no longer fits:

```brighterscript
drawable.useImpostorStrips = false
```

`impostorBlitRollOnly` (default `false`) rotates the single blit only to follow the camera's
roll. Turning, orbiting or moving without rolling then scales and shifts the capture without
tilting it, so vertical edges stay vertical. When that stops fitting, strips or a redraw take
over. Use it when the camera rolls and the model is mostly flat-faced:

```brighterscript
drawable.impostorBlitRollOnly = true
```

## Tuning fields

Every `impostor*` field is a public `DrawableModel` field, set after construction. The
"Short key" column is the name `applyImpostorOptions()` reads from a bag of values, the same
way deep-link params arrive.

| Field | Default | Short key | What it does |
| --- | --- | --- | --- |
| `useImpostor` | `true` | `impostor` | Reuse the capture while only the camera moves. |
| `useImpostorStrips` | `true` | `strips` | Try strips before a redraw. |
| `impostorBlitRollOnly` | `false` | `blitRoll` | Rotate the single blit only for camera roll. |
| `impostorStripStepPx` | `2.5` | `stripStep` | How far (px) a strip's scale may leave any column from the fitted warp. Smaller means more, narrower strips. Ignored when `impostorStripWidth` is set. |
| `impostorStripWidth` | `0` | `stripWidth` | A fixed strip width in pixels of the capture. `0` sizes strips by `impostorStripStepPx`. |
| `impostorStripKnots` | `3` | `stripKnots` | Hint points for the strip fit. `0` uses the bounding box's visible vertical edges; 2 or more places knots across the model. |
| `impostorStripMaxPoints` | `48` | `stripPoints` | The most visible vertices a strip fit uses. |
| `impostorStripPerspective` | `true` | `stripLinear` | Interpolate strips with perspective. `stripLinear=1` fits them linearly in screen x instead (`impostorStripPerspective = false`). |
| `impostorStripMaxError` | `0.0` | `stripError` | How far (px) strips may put a vertex from where it is. `0` uses the quality level's error. |
| `impostorStripMaxStrips` | `32` | `stripMax` | The most strips one redraw may take. Past it, the model is redrawn. |
| `impostorStripMaxAngleDegrees` | `0.0` | `stripAngle` | How far (degrees) the view may turn and still try strips. `0` uses the quality level. |
| `impostorStripErrorScale` | `0.0` | `stripScale` | Scales the quality level's error for strips. `0` uses the quality level. Ignored when `impostorStripMaxError` is set. |
| `impostorStripLevel` | `true` | `stripLevel` | Fit and draw strips in a level view so they follow a camera that looks down. `stripLevel=0` keeps them upright on the canvas. |
| `impostorBlitErrorScale` | `1.0` | `blitScale` | Scales the single blit's allowed error, so it can hand over to strips sooner. |
| `impostorBlitMaxAngleDegrees` | `0.0` | `blitAngle` | How far (degrees) the view may turn before the single blit hands over to strips. `0` uses the quality level. |
| `impostorBlitAngleScale` | `0.75` | `blitAngleScale` | Scales the single blit's angle limit when strips are on. |
| `impostorBlitMaxDepthRatio` | `0.0` | `blitDepth` | How deep the model may reach, as a multiple of its nearest point's depth, and still use the single blit. `0` uses the quality level. |
| `impostorBlitRollOnly` | `false` | `blitRoll` | See [Strips and blit roll](#strips-and-blit-roll). |
| `impostorRedrawOnNewFace` | `true` | `newFace` | Redraw when a side that faced away at capture turns into view. |
| `impostorNewFaceMinArea` | `0.01` | `newFaceArea` | Sides smaller than this fraction of the model's surface don't force a redraw. |

A `0` on a field that says "uses the quality level" keeps the level's value, so the level
still decides unless you set the field.

### Setting them from launch params

`applyImpostorOptions()` takes a bag of short keys and sets only the fields it finds. A key
that's missing, or whose value won't parse, leaves its field alone. Pass it the params a
[launch](/launch-params) gave you, picked down to the keys you want:

```brighterscript
' strips=0 stripStep=4 blitRoll=1 on the command line
strips = params.pick(["strips", "stripStep", "blitRoll"])
drawable.applyImpostorOptions(strips)
```

`examples/thirdPerson/src/source/ImpostorStrips.bs` does this for every model it creates, from
the `strips` deep link, and `examples/terrain` does it for its chapel. Setting a field in code
works the same way and is the place to put settings you keep.

## Quality settings

The fields above say how a model may be reused. The render quality level says how far a reuse
may be off, and that is what changes between Basic and Ultra. Each one has a value at all five
levels, in order Basic, Low, Medium, High and Ultra:

| Setting | Basic to Ultra | What it limits |
| --- | --- | --- |
| `modelImpostorError` | 0.10, 0.075, 0.05, 0.04, 0.03 | How far off the single blit may be, as a fraction of the model's size on screen. |
| `modelImpostorMaxSizeChange` | 3.0, 2.0, 1.4, 1.25, 1.15 | How much the capture may grow or shrink on screen (a ratio, either way) before a redraw. |
| `modelImpostorMaxAngleDegrees` | 12, 10, 8, 3, 2 | How far the direction the model is seen from may turn before a redraw. |
| `modelImpostorMaxDepthRatio` | 4.0, 3.0, 2.5, 2.0, 1.5 | How deep the model may reach for its distance and still reuse at all. Past it, the model draws its faces each frame. |
| `modelImpostorBlitMaxDepthRatio` | 1.0, 0.75, 0.5, 0.4, 0.3 | The same, for the single blit alone. A deeper model goes to strips or a redraw. |
| `modelImpostorStripMaxAngleDegrees` | 25, 25, 25, 15, 10 | How far the view may turn and still try strips. |
| `modelImpostorStripErrorScale` | 2.0, 2.0, 2.0, 1.5, 1.25 | How much further off than `modelImpostorError` strips may be before a redraw. |
| `modelImpostorStripMaxErrorPixels` | 6, 5, 4, 3, 2 | The most, in pixels, strips may put any visible vertex off, however big the model is. |
| `modelImpostorMaxLightChange` | 0.10, 0.075, 0.05, 0.03, 0.02 | How much the light reaching a model may change (per colour channel, 0-1) before it's relit. |

Change them for one level with `overridePreset()`, the same way as the other
[render quality](/render-quality#change-what-a-level-does) settings:

```brighterscript
' keep the car scene's models on their capture for longer at High
game.renderQuality.overridePreset(BGE.RenderQualityLevel.high, {modelImpostorMaxAngleDegrees: 5.0, modelImpostorError: 0.06})
```

`BGE.RenderQualitySettings` lists every field.

## See also

- [Render Quality](/render-quality) - the levels these settings belong to, and adaptive quality.
- [Drawables and SceneObjects](/drawables-and-scene-objects#textured-3d-models-model3d-objparser) - the textured model drawable the impostor belongs to.
- [Launch Params](/launch-params) - the deep links that feed `applyImpostorOptions()`.
