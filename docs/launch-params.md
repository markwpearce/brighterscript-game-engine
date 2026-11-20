---
title: Launch Params
group: Guides
order: 16
---

# Launch Params

Deep links and `rokubot launch dev --param key=value` pass launch params to `Main()`.
`BGE.LaunchParams` reads them with types, and your game picks the keys.

```brighterscript
sub Main(args as dynamic)
  params = new BGE.LaunchParams(args)
  game = new BGE.Game(1280, 720)

  ' quality=<0-4> pins the render quality level; otherwise pick your own default
  if not game.applyLaunchQuality(params)
    game.enableAdaptiveQuality()
  end if

  game.defineScene(new TitleScene(game))
  game.defineScene(new LevelScene(game))

  ' scene=LevelScene (any case) or an alias; anything else starts on the title
  startScene = params.sceneName(game.getSceneNames(), "TitleScene", {level: "LevelScene"})
  game.changeScene(startScene, {level: params.getInt("level", 1, 1, 9)})
  game.play()
end sub
```

`new BGE.LaunchParams(args)` takes `Main()`'s args as they come: an AA, an AA in a
one-element array, values in one-element arrays, or invalid. It also works on any args AA,
such as a scene's, where values may already be numbers or booleans.

## Getters

A param that's missing, or doesn't parse, gives the default. `level=abc` isn't read as level 0.

| Call | `key=` | Gives |
|---|---|---|
| `getString("name", "")` | `name=bram` | `"bram"` |
| `getInt("level", 1, 1, 9)` | `level=12` | `9` (clamped to `min`..`max`) |
| `getFloat("tilt", 0)` | `tilt=0.25` | `0.25` |
| `getBool("debug")` | `debug=1` | `true` (`1/true/yes/on`, `0/false/no/off`) |
| `getList("items")` | `items=key,map` | `["key", "map"]` |
| `getIntList("at")` | `at=4,7,90` | `[4, 7, 90]`, or invalid if an entry isn't whole |
| `getFloatList("at")` | `at=4,7,22.5` | `[4.0, 7.0, 22.5]`, or invalid if an entry isn't a number |
| `getCounts("items")` | `items=key:2,map` | `{key: 2, map: 1}` |

`has(name)` checks a param is there. `pick(names)` copies the given ones into a new AA, e.g. to
pass a whitelist on as scene args. `toAA()` copies them all.

## Starting scene

`sceneName(sceneNames, default, aliases, key = "scene")` checks the `scene=` param against
`game.getSceneNames()`. It follows `aliases` (alias -> scene name) first and ignores case.
An unknown scene logs a warning and starts on `default`, so a typo doesn't start a scene that
doesn't exist.

## Quality

`game.applyLaunchQuality(params)` pins the [render quality](/render-quality) level from
`quality=<0-4>` and returns true. With no param, or a bad one, it changes nothing and returns
false, so the game chooses its own default (adaptive quality, a profiling level...).

Debug state for a story game (`flags=`, `items=`) goes through
`BGE.Story.applyDebugState()`, which takes the strings as given: see [Story](/story). Turn
saving off (`slot.enabled = false`, see [Saving](/saving)) while a deep link is testing a level.
