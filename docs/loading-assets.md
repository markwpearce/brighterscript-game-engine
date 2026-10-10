---
title: Loading Assets
group: Guides
order: 9
---

# Loading Assets

Loading a big model or building a large level in one go freezes the screen. A scene can instead queue its loading work in `onLoad()`. The engine runs that work a little each frame, shows a loading screen, and calls `onCreate()` when it's all done. For the rest of the engine, see the [Game Engine Overview](/game-engine-overview).

## Loading in `onLoad`

```brightscript
class LevelScene extends BGE.GameScene

  override sub onLoad(loader as BGE.AssetLoader, args as roAssociativeArray)
    loader.loadBitmap("ground", "pkg:/images/ground.png")
    loader.load3dModel("ship", "pkg:/models/ship.obj")
    loader.loadSound("boom", "pkg:/sounds/boom.wav")
    loader.registerFont("pkg:/fonts/title.ttf")
  end sub

  override sub onCreate(args as roAssociativeArray)
    ' everything queued above is loaded by now
    ship = m.game.get3dModel("ship")
  end sub

end class
```

When you call `changeScene()`, the old scene and its entities are removed first, then `onLoad()` runs. If it queued anything, the engine works through the queue each frame, within `game.loadingBudgetMs` (12ms by default). A loading screen appears if loading takes longer than a quarter of a second. When the queue is empty, `onCreate()` runs at the end of that frame and the fade-in starts. If `onLoad()` queues nothing, `onCreate()` runs straight away, as it always did.

While loading, the scene and any entities it added get no `onUpdate()`, `onInput()` and so on. If something calls `changeScene()` meanwhile, the change waits and happens right after the loading scene's `onCreate()`.

`loader.getProgress()` weights each task by its `weight` (default 1). Set a higher weight on a task you know is big so the progress bar moves at a believable rate:

```brightscript
task = loader.load3dModel("terrain", "pkg:/models/terrain.stl")
task.weight = 10
```

## Your own work

`loader.addStep()` calls a function once per step until it says it's done. Return `true` when finished, or a number from 0 to 1 for progress (done at 1). This builds a level one row at a time:

```brightscript
override sub onLoad(loader as BGE.AssetLoader, args as roAssociativeArray)
  m.rowsBuilt = 0
  context = {scene: m}
  task = loader.addStep(buildRowStep, context)
  context.task = task
end sub

function buildRowStep(context as object) as dynamic
  context.task.waitingForNextFrame = true
  context.scene.buildNextRow()
  return context.scene.rowsBuilt / 20.0
end function
```

Setting `waitingForNextFrame` tells the loader not to call this task again until next frame, so you get one step per frame and the loading screen can show each row appearing. Leave it off and the loader keeps calling the step until the frame's budget runs out.

For something more involved, extend `BGE.LoadTask`. `step(budgetMs)` does a bit of work and returns `true` when finished, and `getProgress()` reports 0 to 1:

```brightscript
class SpawnEnemiesTask extends BGE.LoadTask

  private scene as BGE.GameScene
  private spawned as integer = 0

  sub new(scene as BGE.GameScene)
    super()
    m.name = "spawn enemies"
    m.weight = 3
    m.scene = scene
  end sub

  override function step(budgetMs as integer) as boolean
    ' ... create a few enemies ...
    m.spawned++
    return m.spawned >= 100
  end function

  override function getProgress() as float
    return m.spawned / 100.0
  end function

end class
```

Queue it with `loader.addTask(new SpawnEnemiesTask(m))`. If a task needs another to finish first, chain `task.after(otherTask)`. When the first one fails, the dependent task fails without running. A task that sets `error` or throws counts as finished, so one bad file doesn't stall the scene.

## Errors

A failed task is logged and its message kept. Check for them in `onCreate()`:

```brightscript
override sub onCreate(args as roAssociativeArray)
  for each message in m.game.getSceneLoader().getErrors()
    m.game.log("load problem: " + message)
  end for
end sub
```

## Loading screens

The default screen is a black background with a progress bar and the label "Loading". To change its colours or label, set `game.loadingScreen`:

```brightscript
screen = new BGE.DefaultLoadingScreen(game.getFont("hud"))
screen.backgroundColor = BGE.Colors.Blue
screen.barColor = BGE.Colors.Yellow
screen.label = "Getting ready"
game.loadingScreen = screen
```

For your own look, extend `BGE.LoadingScreen` and override `draw()`. It's drawn on the UI canvas, above the game UI and the fade overlay:

```brightscript
class DotsLoadingScreen extends BGE.LoadingScreen

  sub new()
    super()
    m.showAfterSeconds = 0.1
  end sub

  override sub draw(renderer as BGE.Renderer, progress as float, dt as float)
    size = renderer.getCanvasSize()
    renderer.drawRectangle(0, 0, size.x * progress, 10, BGE.Colors.White)
  end sub

end class
```

`onShow()` and `onHide()` are also available. A single scene can use its own screen by overriding `getLoadingScreen()` to return one. Otherwise `game.loadingScreen` is used, then `DefaultLoadingScreen`. Because the scene's `getLoadingScreen()` is called while it's loading, build the screen there rather than relying on anything `onCreate()` sets up. `game.isLoading()` and `game.getLoadingProgress()` are there if you want to draw progress yourself.

## Background loading

`game.assets` is a second `AssetLoader` that runs every frame, even when no scene is loading. Use it to fetch things the player will need later while they play. It's limited to `game.assetsBudgetMs` per frame (4ms by default), so it won't hurt the frame rate.

```brightscript
game.assets.loadBitmap("level2_bg", "pkg:/images/level2.png")
game.assets.load3dModel("boss", "pkg:/models/boss.obj")
game.assets.onComplete = sub(loader as BGE.AssetLoader)
  print "level 2 assets ready"
end sub
```

`onComplete` is called once when the queue empties. Adding more tasks afterwards starts a new batch, with progress and errors starting over.

One native call can't be split up, so reading a huge file, decoding one big image or loading one sound still takes a single frame and will hitch the frame it lands in. Models are the exception: `.obj` and `.stl` files are parsed a slice at a time. Splitting a big image into a few smaller ones spreads the cost across frames.

See `examples/loading` for a runnable example: one scene loads every model and some large textures under a loading screen with a timing readout, and another builds a tile grid a row per frame under a custom screen.
