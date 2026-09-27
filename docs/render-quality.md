---
title: Render Quality
group: Guides
order: 5
---

# Render Quality

The engine draws at one of five quality levels - Basic, Low, Medium, High and Ultra.
Each level is a bundle of draw-quality settings: how far the camera draws, how many
slices a ground plane uses, how small triangles are drawn, and when billboards can
use a cheaper draw call.

## Default: chosen for the device

You don't need to do anything. When your `Game` is created, the engine picks a
starting level from the Roku model it's running on - the newest Roku Ultra models
start at Ultra (older Ultras at High or Medium), a Roku Express at Low, the simulator at Medium. A model the engine doesn't know is
guessed from its model number, falling back to Medium.

## Hold a frame rate automatically

```brighterscript
game = new BGE.Game(1280, 720)
game.enableAdaptiveQuality()
```

The target defaults to 20fps; pass `{targetFps: 30}` to aim higher. The level drops
quickly if the frame rate falls below the target, and rises one level after about
2 seconds of headroom. Keep it within a range with `minLevel`/`maxLevel`:

```brighterscript
game.enableAdaptiveQuality({minLevel: BGE.RenderQualityLevel.low, maxLevel: BGE.RenderQualityLevel.high})
```

The debug FPS display (`game.enableStandardDebugUi()`) shows the current level.

Under the hood this is a plain step-down/step-up controller, not a PID loop: it
steps down fast (average frame rate below 90% of target), and only steps up after
frame rate has stayed comfortably above target for a few seconds straight, one
level at a time. A level that steps up but doesn't hold goes into a backoff and
isn't retried for a while (doubling on each repeated failure) - the headroom time
that earns a probe keeps accruing while the next level up is in that backoff, so
once the backoff ends the very next frame's worth of headroom can trigger the
probe immediately.

## Pick a level yourself

```brighterscript
game.setQualityLevel(BGE.RenderQualityLevel.high)
```

This also turns adaptive tuning off - handy for testing, or for a settings menu.

## Draw distance

A level scales your camera's `maxDrawDistance` rather than replacing it: Basic
draws 0.4x as far, Medium exactly what you set, Ultra 1.5x. Set `maxDrawDistance` to
what suits your game at Medium. The distance actually used is
`camera.getEffectiveMaxDrawDistance()`, which is also capped per device to avoid
running out of memory.

Ground planes (`DrawablePlane`) are the exception: they always draw out to your
`maxDrawDistance` (capped per device), whatever the level, so the horizon never
jumps when the level changes. Only other objects are culled closer or further.

## Change what a level does

```brighterscript
' this game's world is small - never draw further than 300 at High
game.renderQuality.overridePreset(BGE.RenderQualityLevel.high, {drawDistanceOverride: 300})
' smoother ground at Medium
game.renderQuality.overridePreset(BGE.RenderQualityLevel.medium, {planeSliceCount: 50})
```

Fields you don't name keep the engine's values. See `BGE.RenderQualitySettings`
for every field.

## Scale your own content

Every entity and scene gets `onQualityChanged(level)` when the level changes:

```brighterscript
override sub onQualityChanged(level as integer)
  m.sparks.maxParticles = [20, 40, 80, 120, 200][level]
end sub
```

## Plane memory

Every textured `DrawablePlane` on screen keeps a scratch bitmap sized off
`maxDrawDistance`, and a `tiledImage` plane also caches a "supertexture" bitmap sized
the same way. They grow with the square of the distance, so keep `maxDrawDistance`
modest in scenes with several textured planes. Because planes ignore the quality
level's draw-distance scale, a level change never rebuilds them.
