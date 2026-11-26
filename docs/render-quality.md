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
quickly if the frame rate falls below the target, and rises about a second after
there's headroom - two levels at once when the frame rate is at least double the
target. Keep it within a range with `minLevel`/`maxLevel`:

```brighterscript
game.enableAdaptiveQuality({minLevel: BGE.RenderQualityLevel.low, maxLevel: BGE.RenderQualityLevel.high})
```

The debug FPS display (`game.enableStandardDebugUi()`) shows the current level.

### Per scene

A scene can hold its own frame rate and range, in force while it's the current scene.
Set its `qualityOptions` in `new()` or `onCreate()`; fields it leaves out use the game's:

```brighterscript
sub new(game as BGE.Game)
  super(game)
  m.name = "TownScene"
  ' a busy scene: settle for 16fps and a richer view
  m.qualityOptions = {targetFps: 16}
end sub
```

The options apply once the scene has loaded (after `onCreate()`), and the next scene's
replace them. `minLevel`/`maxLevel` move the level into range straight away.

### When the camera stops

A still camera lets the renderer reuse cached drawings, so there's usually plenty of
headroom. Once the camera has been still for `stillCameraSeconds` (0.2), quality climbs
straight up by the measured headroom - a level per doubling of the frame rate over the
target, or right to the top when frames come at the display's refresh rate - usually
within a second. When the camera moves again, the level drops straight back to the one
that held the last time it moved, before that first moving frame draws. Then, if frames
still fall short, it steps down after just 0.3s of frames, by a level plus one per halving of
the frame rate under the target, and keeps doing that until moving frames hold the
target. Together these drop at most `cameraMoveMaxStepDown` (2) levels below the still level;
past that the usual step-down timings take over (`cameraMoveMaxStepDown: 0` for no limit). Set
`stillCameraSeconds: 0` to turn this off.

### How it decides

It's a plain step-down/step-up controller, not a PID loop: it steps down fast (average
frame rate below 90% of target), and only steps up after the frame rate has stayed
comfortably above target for a while. A level that steps up but doesn't hold goes into
a backoff and isn't retried for 4s (`probeBackoffSeconds`), doubling on each repeated
failure up to 16s and starting over once the level holds. A still camera keeps its own,
shorter backoffs (1s, up to 4s, `stillProbeBackoffSeconds`), since a level that failed
while moving can hold when still. A level that drops because the camera started or
stopped moving doesn't count as failing. The headroom that earns a probe keeps accruing while the next level up is in
backoff, so it's tried the moment the backoff ends.

## Pick a level yourself

```brighterscript
game.setQualityLevel(BGE.RenderQualityLevel.high)
```

This also turns adaptive tuning off - handy for testing, or for a settings menu.
`game.applyLaunchQuality(params)` does it from a `quality=<0-4>` deep link (see
[Launch Params](/launch-params)).

## Draw distance

A level scales your camera's `maxDrawDistance` rather than replacing it: Basic
draws 0.75x as far, Low 0.825x, Medium exactly what you set, High 1.25x, Ultra 1.5x. Set `maxDrawDistance` to
what suits your game at Medium.

To keep the draw distance from changing with the level - walls in a maze that would
otherwise reach farther or cut off nearer as the level moves - set `fixedDrawDistance`
in a scene's `qualityOptions`: it draws out to `maxDrawDistance` at every level. Other
settings still follow the level. A camera with [fog](/drawables-and-scene-objects) on does this
anyway, ignoring any level's `drawDistanceOverride` too, unless `fog.followsQuality` is set: a fog edge that moves with the level looks like the
game struggling.

```brighterscript
m.qualityOptions = {fixedDrawDistance: true}
```

The distance actually used is
`camera.getEffectiveMaxDrawDistance()`, which is also capped per device to avoid
running out of memory: 900 in the simulator, 1000 on an HD Roku, 2500 on an FHD one.

A change in draw distance, from a level change or a new `maxDrawDistance`, eases in over
`camera.drawDistanceTransitionSeconds` (0.75 by default), so far objects fade in or out
rather than popping. Set it to 0 to apply changes at once, or call `camera.snapDrawDistance()`
to skip one transition, e.g. after a camera cut.

Ground planes (`DrawablePlane`) are the exception: whatever the current level, they draw
out to the farthest any level draws objects. That's `maxDrawDistance` times the biggest
level scale (1.5x, from Ultra), or the biggest `drawDistanceOverride` if that's farther,
capped per device. So the horizon never jumps when the level changes. Only other objects
are culled closer or further. With `fixedDrawDistance` or fog on, planes draw to
`maxDrawDistance` like everything else.

## Change what a level does

```brighterscript
' this game's world is small - never draw further than 300 at High
game.renderQuality.overridePreset(BGE.RenderQualityLevel.high, {drawDistanceOverride: 300})
' smoother ground at Medium
game.renderQuality.overridePreset(BGE.RenderQualityLevel.medium, {planeSliceCount: 50})
```

Fields you don't name keep the engine's values. See `BGE.RenderQualitySettings`
for every field.

Two fields control when a billboard (an image, rectangle, polygon and so on facing the
camera) reuses last frame's rendering instead of drawing again:

- `billboardReuseError` - how far off the reused rendering may be while it moves, as a
  fraction of its size on screen. 0.08 at Basic down to 0 at Ultra, where 0 means a fixed
  16 pixels.
- `billboardReuseMaxAngleDegrees` - how far the direction it's seen from may turn before it's
  redrawn. 180 (no limit) up to Medium, 20 at High, 10 at Ultra.

## Walls

[`DrawableWalls`](/drawables-and-scene-objects) (and `DrawableGridWalls`) draws one strip per
`wallStripWidth` pixels, so that setting sets its cost. Wider strips are cheaper and a little
coarser (a fine stair-step along wall feet and tops).

| Level  | `wallStripWidth` |
| ------ | ---------------- |
| Basic  | 16               |
| Low    | 8                |
| Medium | 8                |
| High   | 6                |
| Ultra  | 4                |

Override it like any other field, e.g. `{wallStripWidth: 6}` at Medium. Halving the strip
width roughly doubles the walls' cost, which is why High sits at 6 between Medium's 8 and Ultra's 4.

Fog silhouettes (`Camera3d.fog`, see [Drawables](/drawables-and-scene-objects)) are filled
with rects stepping down each edge in stairs at most `fogSilhouetteBand` pixels tall and across
(at least 1). A near-upright wall costs a rect or two; a sloped edge, a pitched roof say, costs
about one rect per band it spans, so smaller bands follow it more closely for more draws.

| Level  | `fogSilhouetteBand` |
| ------ | ------------------- |
| Basic  | 8                   |
| Low    | 6                   |
| Medium | 4                   |
| High   | 3                   |
| Ultra  | 2                   |

Past `wallLodDistanceFraction` of the current draw distance, walls draw one strip per two rays,
twice as wide: far walls are small on screen, and each strip costs about the same however big
it is. Every ray still closes exactly, so hiding and floors are unchanged.

| Level  | `wallLodDistanceFraction` |
| ------ | ------------------------- |
| Basic  | 0.25                      |
| Low    | 0.3                       |
| Medium | 0.4                       |
| High   | 0.6                       |
| Ultra  | 1 (never)                 |

A [voxel terrain](/voxel-terrain) marches `voxelColumns` screen columns, each taking
`voxelBandSteps` depth steps before its step doubles. Its cost is about columns x steps
(~4 µs each on a Roku Ultra), so these are its two levers.

| Level  | `voxelColumns` | `voxelBandSteps` |
| ------ | -------------- | ---------------- |
| Basic  | 50             | 20               |
| Low    | 64             | 20               |
| Medium | 80             | 20               |
| High   | 100            | 20               |
| Ultra  | 100            | 28               |

An oriented sprite (`BGE.DrawableOrientedSprite`) with a `lodDistance` plays the far
stand-in you gave `setLodAnimation()` (an idle loop held on one frame, say) past that distance
from the camera. Set `lodDistance` for Medium: `animationLodDistanceScale` scales it, so
higher levels keep characters animating further out.

```brighterscript
m.sprite.lodDistance = World.metres(10)   ' 10 m at Medium, 20 m at Ultra
m.sprite.setLodAnimation("idle", "still")
```

| Level  | `animationLodDistanceScale` |
| ------ | --------------------------- |
| Basic  | 0.6                         |
| Low    | 0.8                         |
| Medium | 1                           |
| High   | 1.5                         |
| Ultra  | 2                           |

## Scale your own content

Every entity and scene gets `onQualityChanged(level)` when the level changes:

```brighterscript
override sub onQualityChanged(level as BGE.RenderQualityLevel)
  m.sparks.maxParticles = [20, 40, 80, 120, 200][level]
end sub
```

## Plane memory

Every textured `DrawablePlane` on screen keeps a scratch bitmap sized off
`maxDrawDistance`, and a `tiledImage` plane also caches a "supertexture" bitmap sized
the same way. They grow with the square of the distance, so keep `maxDrawDistance`
modest in scenes with several textured planes. Because planes already reach as far
as any level draws, a level change never rebuilds them.
