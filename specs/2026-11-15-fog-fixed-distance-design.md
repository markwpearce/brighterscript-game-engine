# Fog owns the draw distance (#529, replaces the keep)

## Problem

With fog on, the far edge of the world moves whenever auto quality changes level: the eased
draw distance, the fade band, the backdrop and the silhouette reach all scale with
`drawDistanceScale`. Every step down pulls fog over things the player was just looking at, and
every patch for that (#529's keep) brings its own seams: walls fade while models don't, a kept
building snaps to a fog box when its picture goes stale, the skyline shrinks (#533).

Other engines don't move fog for speed. Unreal's `r.ViewDistanceScale` is a player setting, not a
runtime one, and fog is per level. Unity's Adaptive Performance can shrink view distance under
thermal load, but its fog scaler thickens the fog in step with it. A fixed fog wall reads as
atmosphere; a moving one reads as the game struggling.

## Rule

**With `Camera3d.fog.enabled`, the draw distance is fixed:** `maxDrawDistance` (still device
capped), whatever the quality level. The renderer treats fog on exactly like
`SceneQualityOptions.fixedDrawDistance` today. Everything hanging off the draw distance then stops
moving together:

- object fade band (`drawDistanceFadeFraction`): models, images and walls fade on one curve of
  world distance, so they always agree (walls no longer fade while models stay)
- backdrop top, silhouette reach (`silhouetteReach` x a fixed distance: fixes #533's skyline)
- plane draw distance
- an object's fade depends only on where it is, so redrawing its picture can't change how fogged
  it looks (no building snapping to a fog box when it redraws)

With fog off nothing changes: the draw distance follows quality and eases, as today. There's
nothing to hide its edge, so a shorter one is the cheapest lever there.

`Fog.followsQuality` (default false) opts back into the old behaviour for a game that wants the
speed and accepts the moving edge. When on, a step down eases over
`Fog.qualityTransitionSeconds` (default a few seconds, much slower than
`drawDistanceTransitionSeconds`) so it creeps rather than jumps. No keep.

## What quality changes inside the fog instead

Fog fixes the distance, so a step down has to save its time elsewhere. Already quality-scaled and
unaffected: triangle skip size, quick-draw step, impostor and reuse limits, plane slices,
billboard fast-draw tolerances, wall LOD fraction.

New, if the town still can't hold its target at the lowest level (measure first):
`RenderQualitySettings.farDetailFraction`, the fraction of the draw distance past which objects use
their cheapest picture: impostors with looser limits (`modelImpostorError` x2), replay accepted
while moving within the billboard reuse error, walls at the coarse LOD. Like Unity's LOD bias:
what's far gets cheaper, nothing disappears. 1.0 at Ultra, down to ~0.5 at the lowest level.

## Changes

1. `Camera.fixesDrawDistance()` (true for a `Camera3d` with fog on and not `followsQuality`);
   `Renderer.setupCameraForFrame()` treats it like `fixedDrawDistance`.
2. The #529 keep is reverted (`Fog.keepCachedImages` and everything behind it).
3. `Fog.followsQuality` + `qualityTransitionSeconds`: `Camera3d.advanceDrawDistance()` eases over
   the longer of it and `drawDistanceTransitionSeconds`.
4. thirdPerson needs nothing: the town and graveyard have fog on. Crypt's explicit
   `fixedDrawDistance` is now redundant but harmless.
5. Docs: `docs/render-quality.md` Draw distance, `docs/drawables-and-scene-objects.md` Fog,
   `.claude/rules/renderer.md`.
6. Tests: fog on → draw and plane distance ignore the level; `followsQuality` → follows it,
   eased over `qualityTransitionSeconds`; `fixesDrawDistance()` gates.
7. `farDetailFraction`: not built; its own issue if the device numbers call for it.

## Costs and risks

- At Ultra the view no longer reaches 1.5x: the base distance is all you get. Raise a scene's
  `maxDrawDistance` if it can afford more (thirdPerson's town is tuned to 33 m).
- Lower levels save less. Measured on the device, thirdPerson's town at its default spawn, old
  distances emulated with `draw=`:

  | level | camera | fixed 33 m | old (Basic 24.75 m, Ultra 49.5 m) |
  | --- | --- | --- | --- |
  | Basic | still | 50.1 fps | 57.7 |
  | Basic | orbiting | 12.0 | 13.3 |
  | Ultra | still | 45.2 | 38.7 |
  | Ultra | orbiting | 4.4 | 3.9 |

  Basic gives up ~10% orbiting (~13% still), Ultra gains back the same from not reaching 1.5x.
  The town's 16 fps target is missed orbiting at Basic either way, so the loss is worth winning
  back elsewhere: that's `farDetailFraction`'s issue.
- #533 closes with this (reach no longer follows quality) unless `followsQuality` is on, where it's
  accepted as part of the moving edge.
