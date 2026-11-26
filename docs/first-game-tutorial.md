---
title: Build Your First Game
group: Guides
order: 0
---

# Build Your First Game

This guide builds one small, playable game from an empty project: a coin collector. You move a square around the screen with the d-pad, collect coins that appear in random places, watch your score and a countdown, and get a game-over screen where OK starts a new round.

Each step ends with something new you can run and see. Every step is a complete, runnable project, so if you get stuck you can compare your code with the known-good version in [`examples/tutorial`](https://github.com/markwpearce/brighterscript-game-engine/tree/main/examples/tutorial).

For a topic-by-topic reference once you know what you're looking for, see [Building a Game with BGE](/game-engine-overview).

## Before you start

You need a clone of the engine repository with its dependencies installed (`npm install` at the root), and a Roku on your network. Put the Roku's address and developer password in a `.env` file at the root of the repo, as described in [Cloning and Running Examples](https://github.com/markwpearce/brighterscript-game-engine#cloning-and-running-examples) in the README. The tutorial's commands run from the repo root.

Each step ends with a screenshot and a **Try it** line that says what to press and what you should see.

## Step 1: Set up the project

We start from the project template. `npm run create-example` copies it into `examples/` with the splash screen, the channel icons and a `src/source` folder. We replace the template's `main.bs` with our own, which creates a single scene and shows its title.

```
npm run create-example -- coinCollector "Coin Collector"
```

Delete `src/source/Scenes/MainScene.bs` (we use our own scene), then replace `src/source/main.bs` with:

**`src/source/main.bs`**

```brighterscript
sub Main(args as dynamic)
  game = new BGE.Game(1280, 720) ' the game canvas size; the engine scales it to fit the screen
  game.fitCanvasToScreen()

  game.defineScene(new PlayScene(game))
  game.changeScene("PlayScene")

  ' The engine splash plays first. Deep link with splash=0 to skip it while testing.
  game.applyLaunchSplash(new BGE.LaunchParams(args))
  game.play()
end sub
```

and create `src/source/Scenes/PlayScene.bs`:

**`src/source/Scenes/PlayScene.bs`**

```brighterscript
' The game itself. For now it only shows the title.
class PlayScene extends BGE.GameScene

  sub new(game as BGE.Game)
    super(game)
    m.name = "PlayScene"
  end sub

  override sub onCreate(args as roAssociativeArray)
    m.addTitle()
  end sub

  override sub onInput(input as BGE.GameInput)
    if input.isRemoteBack()
      m.game.End()
    end if
  end sub

  ' The title, centred at the top of the screen
  private sub addTitle()
    title = new BGE.UI.Label(m.game)
    title.setText("Coin Collector")
    title.customPosition = true
    title.horizAlign = "center"
    title.customX = m.game.uiCanvas.getWidth() / 2
    title.customY = m.game.uiCanvas.getHeight() * 0.1
    m.addUi(title)
  end sub

end class
```

`Main()` is the entry point. `Game` owns the game loop, and `defineScene`/`changeScene` tell it which `GameScene` to show. `play()` runs until the game ends. The engine shows its splash screen first. Deep link with `splash=0` to skip it while testing (`npm run run-example -- coinCollector splash=0`).

A scene is one state of your game, such as a title screen, a level or a game-over screen. You subclass `BGE.GameScene` and fill in its hooks.

The title is a `BGE.UI.Label` added to the scene with `addUi()`. It is placed 10% in from the top, centred. Keep anything on screen at least 10% in from each edge, so it stays visible on every TV.

Run it from the repo root:

```
npm run run-example -- coinCollector
```

![Step 1: the title on a blank scene](images/tutorial-step1.jpg)

**Try it:** after the splash, you should see "Coin Collector" at the top of an otherwise empty screen. Press Back to quit.

## Step 2: Draw the player

Entities are the things in your game world: the player, coins, enemies. A `GameEntity` draws nothing on its own. You attach a drawable to it, such as a rectangle, an image or a circle, and the drawable moves with the entity.

The player is a blue square. Create `src/source/Entities/Player.bs`:

**`src/source/Entities/Player.bs`**

```brighterscript
' The blue square the player steers with the d-pad
class Player extends BGE.GameEntity

  size = 40.0

  sub new(game as BGE.Game)
    super(game)
    m.name = "Player"
  end sub

  override sub onCreate(args as roAssociativeArray)
    m.position.x = m.game.canvas.getWidth() / 2
    m.position.y = m.game.canvas.getHeight() / 2

    ' Drawn centred on position: the rectangle's top-left corner is half a size up and left
    half = m.size / 2
    m.addRectangle("body", m.size, m.size, {
      color: &h3DA5FF,
      offset: BGE.Math.VectorOps.create(-half, half)
    })
  end sub

end class
```

Add the player to the scene in `src/source/Scenes/PlayScene.bs`, in `onCreate()`:

**`src/source/Scenes/PlayScene.bs`**

```brighterscript
' The game itself. For now it shows the title and the player.
class PlayScene extends BGE.GameScene

  sub new(game as BGE.Game)
    super(game)
    m.name = "PlayScene"
  end sub

  override sub onCreate(args as roAssociativeArray)
    m.game.addEntity(new Player(m.game))
    m.addTitle()
  end sub

  override sub onInput(input as BGE.GameInput)
    if input.isRemoteBack()
      m.game.End()
    end if
  end sub

  ' The title, centred at the top of the screen
  private sub addTitle()
    title = new BGE.UI.Label(m.game)
    title.setText("Coin Collector")
    title.customPosition = true
    title.horizAlign = "center"
    title.customX = m.game.uiCanvas.getWidth() / 2
    title.customY = m.game.uiCanvas.getHeight() * 0.1
    m.addUi(title)
  end sub

end class
```

`onCreate()` runs once when the scene starts. `addEntity()` calls the entity's own `onCreate()`, then adds it to the game.

The square is drawn centred on the entity's `position`. The rectangle's top-left corner sits at `position`, so the offset moves it up and left by half its size.

> **Why centre things?** `position` is the entity's centre, which makes rotation, scaling and collision easier to reason about. Positions are in world space, where +y points up the screen.

![Step 2: a blue square in the middle of the screen](images/tutorial-step2.jpg)

**Try it:** a blue square appears in the middle of the screen. It doesn't move yet.

## Step 3: Move with the d-pad

Now the player responds to the d-pad. The engine calls `onInput()` on the scene and its entities whenever a button is pressed, held or released. We set the player's `velocity` from the d-pad direction, and the engine moves the player each frame.

Update `src/source/Entities/Player.bs`:

**`src/source/Entities/Player.bs`**

```brighterscript
' The blue square the player steers with the d-pad
class Player extends BGE.GameEntity

  size = 40.0
  speed = 300.0 ' world units per second

  sub new(game as BGE.Game)
    super(game)
    m.name = "Player"
  end sub

  override sub onCreate(args as roAssociativeArray)
    m.position.x = m.game.canvas.getWidth() / 2
    m.position.y = m.game.canvas.getHeight() / 2

    ' Drawn centred on position: the rectangle's top-left corner is half a size up and left
    half = m.size / 2
    m.addRectangle("body", m.size, m.size, {
      color: &h3DA5FF,
      offset: BGE.Math.VectorOps.create(-half, half)
    })
  end sub

  override sub onInput(input as BGE.GameInput)
    ' input.x and input.y are -1, 0 or 1 while a d-pad direction is held, and 0 on release
    m.velocity.x = input.x * m.speed
    m.velocity.y = input.y * m.speed
  end sub

end class
```

> **Why does the engine multiply by time?** `velocity` is in units per second, so `300` means 300 units every second whatever the frame rate. Each frame, the engine moves the entity by `velocity * dt`, where `dt` is the time since the last frame in seconds. A slow Roku and a fast one move the player the same distance per second.

> **Why is `input.y` +1 for up?** The game uses world space, where +y points up the screen. Screen coordinates, as used by most drawing code, point the other way.

> **Why check `input.press` for one-shot actions?** A button fires when it's pressed, and again when it's released, with `x` and `y` set to 0. A rule such as "fire a bullet" needs `input.press and input.isButton("ok")`, or it'll run twice per press. Movement, like this step, is fine to handle on every event.

![Step 3: the player moves after a d-pad press](images/tutorial-step3.jpg)

**Try it:** press and hold the d-pad. The square moves in the direction you hold, and stops when you release. Hold Right for long enough and it runs off the screen. Step 4 fixes that.

## Step 4: Keep the player on screen

The player should stay title-safe, which means at least 10% in from each edge of the 1280x720 game canvas. We store that rectangle when the player is created, and clamp the player's position into it every frame.

Update `src/source/Entities/Player.bs`:

**`src/source/Entities/Player.bs`**

```brighterscript
' The blue square the player steers with the d-pad
class Player extends BGE.GameEntity

  size = 40.0
  speed = 300.0 ' world units per second

  ' The area the player's centre may move in: 10% in from each edge of the canvas
  safeArea as BGE.Math.Rectangle

  sub new(game as BGE.Game)
    super(game)
    m.name = "Player"
  end sub

  override sub onCreate(args as roAssociativeArray)
    m.position.x = m.game.canvas.getWidth() / 2
    m.position.y = m.game.canvas.getHeight() / 2

    ' Drawn centred on position: the rectangle's top-left corner is half a size up and left
    half = m.size / 2
    m.addRectangle("body", m.size, m.size, {
      color: &h3DA5FF,
      offset: BGE.Math.VectorOps.create(-half, half)
    })

    width = m.game.canvas.getWidth()
    height = m.game.canvas.getHeight()
    m.safeArea = new BGE.Math.Rectangle(width * 0.1, height * 0.1, width * 0.8, height * 0.8)
  end sub

  override sub onInput(input as BGE.GameInput)
    ' input.x and input.y are -1, 0 or 1 while a d-pad direction is held, and 0 on release
    m.velocity.x = input.x * m.speed
    m.velocity.y = input.y * m.speed
  end sub

  override sub onUpdate(deltaTime as float)
    BGE.Math.clampToRect(m.position, m.safeArea, m.size / 2, m.size / 2)
  end sub

end class
```

`onUpdate()` runs once per frame for each entity, after input and before the engine moves things. `clampToRect()` moves the centre back inside the rectangle if it has wandered out. We pass half the size as the margin, so the whole square stays inside.

> **Why does the rectangle start at 10%?** Some TVs crop the edges of the picture, so anything closer than 10% to an edge can be hidden. Keeping the game inside that margin means the player is always visible.

![Step 4: the player stops at the edge of the safe area](images/tutorial-step4.jpg)

**Try it:** hold any direction into an edge. The square stops short of the edge and doesn't leave the screen.

## Step 5: Add a coin

A coin is a second kind of entity. It has the same shape as the player: a `GameEntity` with a drawable. Its drawable is a gold circle, and it is placed at a random spot inside the safe area.

Create `src/source/Entities/Coin.bs`:

**`src/source/Entities/Coin.bs`**

```brighterscript
' A gold coin. For now it just appears at a random spot.
class Coin extends BGE.GameEntity

  radius = 16.0

  sub new(game as BGE.Game)
    super(game)
    m.name = "Coin"
  end sub

  override sub onCreate(args as roAssociativeArray)
    m.addCircle("body", m.radius, {
      offset: BGE.Math.VectorOps.create(-m.radius, m.radius),
      color: &hFFD700
    })
    m.respawn()
  end sub

  ' Moves the coin to a random spot inside the title-safe area
  sub respawn()
    margin = 150.0 ' 10% of the width, plus the coin's radius, rounded up
    m.position.x = BGE.Math.randomFloat(margin, m.game.canvas.getWidth() - margin)
    m.position.y = BGE.Math.randomFloat(margin, m.game.canvas.getHeight() - margin)
  end sub

end class
```

Add a coin to the scene in `src/source/Scenes/PlayScene.bs`:

**`src/source/Scenes/PlayScene.bs`**

```brighterscript
' The game itself. For now it shows the title, the player and a coin.
class PlayScene extends BGE.GameScene

  sub new(game as BGE.Game)
    super(game)
    m.name = "PlayScene"
  end sub

  override sub onCreate(args as roAssociativeArray)
    m.game.addEntity(new Player(m.game))
    m.game.addEntity(new Coin(m.game))
    m.addTitle()
  end sub

  override sub onInput(input as BGE.GameInput)
    if input.isRemoteBack()
      m.game.End()
    end if
  end sub

  ' The title, centred at the top of the screen
  private sub addTitle()
    title = new BGE.UI.Label(m.game)
    title.setText("Coin Collector")
    title.customPosition = true
    title.horizAlign = "center"
    title.customX = m.game.uiCanvas.getWidth() / 2
    title.customY = m.game.uiCanvas.getHeight() * 0.1
    m.addUi(title)
  end sub

end class
```

`BGE.Math.randomFloat(min, max)` returns a random number between `min` and `max`. The margin keeps the coin's whole circle inside the safe area.

Like the player, the coin's position is its centre. The circle's drawable is offset so that it's centred on that position.

![Step 5: a gold coin at a random spot](images/tutorial-step5.jpg)

**Try it:** a gold coin appears somewhere on the screen. Quit and launch again, and it appears somewhere else.

## Step 6: Collect the coin

The coin needs a collider so the engine knows when the player touches it. A collider is an invisible shape used for collision detection. It is separate from the drawable, which is only what you see. The player gets a circle collider of the same size as its square, and the coin gets one that matches its circle.

Update `src/source/Entities/Player.bs`:

**`src/source/Entities/Player.bs`**

```brighterscript
' The blue square the player steers with the d-pad
class Player extends BGE.GameEntity

  size = 40.0
  speed = 300.0 ' world units per second

  ' The area the player's centre may move in: 10% in from each edge of the canvas
  safeArea as BGE.Math.Rectangle

  sub new(game as BGE.Game)
    super(game)
    m.name = "Player"
  end sub

  override sub onCreate(args as roAssociativeArray)
    m.position.x = m.game.canvas.getWidth() / 2
    m.position.y = m.game.canvas.getHeight() / 2

    ' Drawn centred on position: the rectangle's top-left corner is half a size up and left
    half = m.size / 2
    m.addRectangle("body", m.size, m.size, {
      color: &h3DA5FF,
      offset: BGE.Math.VectorOps.create(-half, half)
    })
    ' A circle collider sits centred on position, so it lines up with the square
    m.addCircleCollider("body", half)

    width = m.game.canvas.getWidth()
    height = m.game.canvas.getHeight()
    m.safeArea = new BGE.Math.Rectangle(width * 0.1, height * 0.1, width * 0.8, height * 0.8)
  end sub

  override sub onInput(input as BGE.GameInput)
    ' input.x and input.y are -1, 0 or 1 while a d-pad direction is held, and 0 on release
    m.velocity.x = input.x * m.speed
    m.velocity.y = input.y * m.speed
  end sub

  override sub onUpdate(deltaTime as float)
    BGE.Math.clampToRect(m.position, m.safeArea, m.size / 2, m.size / 2)
  end sub

end class
```

Update `src/source/Entities/Coin.bs`:

**`src/source/Entities/Coin.bs`**

```brighterscript
' A gold coin. Touching it moves it to a new random spot.
class Coin extends BGE.GameEntity

  radius = 16.0

  sub new(game as BGE.Game)
    super(game)
    m.name = "Coin"
  end sub

  override sub onCreate(args as roAssociativeArray)
    m.addCircle("body", m.radius, {
      offset: BGE.Math.VectorOps.create(-m.radius, m.radius),
      color: &hFFD700
    })
    m.addCircleCollider("coin", m.radius)
    m.respawn()
  end sub

  override sub onCollisionEnter(myCollider as BGE.Collider, otherCollider as BGE.Collider, otherEntity as BGE.GameEntity)
    if otherEntity.name = "Player"
      m.respawn()
    end if
  end sub

  ' Moves the coin to a random spot inside the title-safe area
  sub respawn()
    margin = 150.0 ' 10% of the width, plus the coin's radius, rounded up
    m.position.x = BGE.Math.randomFloat(margin, m.game.canvas.getWidth() - margin)
    m.position.y = BGE.Math.randomFloat(margin, m.game.canvas.getHeight() - margin)
  end sub

end class
```

`onCollisionEnter()` runs once, on the first frame two colliders overlap. The coin checks that the other entity is the player, and if so moves to a new random spot. `onCollision()` would run every frame the two overlap, which is wrong for a pickup. A one-shot reaction like this belongs in `onCollisionEnter()`.

> **Why are colliders separate from drawables?** A drawable only decides what's on the screen. A collider decides what gets hit. Keeping them separate means you can draw a big image and still use a small, forgiving hitbox.

![Step 6: the coin jumps to a new spot after the player touches it](images/tutorial-step6.jpg)

**Try it:** drive the square into the coin. The coin jumps to a new random spot. Touching it again moves it again.

## Step 7: Keep score

A coin should add a point. The coin doesn't know about the score, and it shouldn't have to: that's the scene's job. The coin posts a game event, `coinCollected`, and any entity or scene that listens for it can react.

Update `src/source/Entities/Coin.bs`:

**`src/source/Entities/Coin.bs`**

```brighterscript
' A gold coin. Touching it scores a point and moves it to a new random spot.
class Coin extends BGE.GameEntity

  radius = 16.0

  sub new(game as BGE.Game)
    super(game)
    m.name = "Coin"
  end sub

  override sub onCreate(args as roAssociativeArray)
    m.addCircle("body", m.radius, {
      offset: BGE.Math.VectorOps.create(-m.radius, m.radius),
      color: &hFFD700
    })
    m.addCircleCollider("coin", m.radius)
    m.respawn()
  end sub

  override sub onCollisionEnter(myCollider as BGE.Collider, otherCollider as BGE.Collider, otherEntity as BGE.GameEntity)
    if otherEntity.name = "Player"
      m.game.postGameEvent("coinCollected", {})
      m.respawn()
    end if
  end sub

  ' Moves the coin to a random spot inside the title-safe area
  sub respawn()
    margin = 150.0 ' 10% of the width, plus the coin's radius, rounded up
    m.position.x = BGE.Math.randomFloat(margin, m.game.canvas.getWidth() - margin)
    m.position.y = BGE.Math.randomFloat(margin, m.game.canvas.getHeight() - margin)
  end sub

end class
```

Update `src/source/Scenes/PlayScene.bs`:

**`src/source/Scenes/PlayScene.bs`**

```brighterscript
' The game itself: the player, the coins, the title and the score.
class PlayScene extends BGE.GameScene

  score = 0
  scoreLabel as BGE.UI.Label

  sub new(game as BGE.Game)
    super(game)
    m.name = "PlayScene"
  end sub

  override sub onCreate(args as roAssociativeArray)
    m.score = 0
    m.game.addEntity(new Player(m.game))
    m.game.addEntity(new Coin(m.game))
    m.addTitle()
    m.addScoreLabel()
  end sub

  override sub onInput(input as BGE.GameInput)
    if input.isRemoteBack()
      m.game.End()
    end if
  end sub

  override sub onGameEvent(eventName as string, data as roAssociativeArray)
    if eventName = "coinCollected"
      m.score += 1
      m.scoreLabel.setText("Score: " + m.score.toStr())
    end if
  end sub

  ' The title, centred at the top of the screen
  private sub addTitle()
    title = new BGE.UI.Label(m.game)
    title.setText("Coin Collector")
    title.customPosition = true
    title.horizAlign = "center"
    title.customX = m.game.uiCanvas.getWidth() / 2
    title.customY = m.game.uiCanvas.getHeight() * 0.1
    m.addUi(title)
  end sub

  ' The score, top left. Labels sit 10% in from the edges so they stay title-safe.
  private sub addScoreLabel()
    m.scoreLabel = new BGE.UI.Label(m.game)
    m.scoreLabel.customPosition = true
    m.scoreLabel.customX = m.game.uiCanvas.getWidth() * 0.1
    m.scoreLabel.customY = m.game.uiCanvas.getHeight() * 0.1
    m.scoreLabel.setText("Score: 0")
    m.addUi(m.scoreLabel)
  end sub

end class
```

`postGameEvent()` sends the event to every entity and to the current scene. `onGameEvent()` on the scene adds the point and updates the label. `setText()` changes what a `Label` shows.

> **Why post an event rather than call the scene directly?** A coin that calls the scene directly has to know the scene's type and name. Events keep entities independent, so you can add a coin sound or a particle burst later without touching the coin's collection code.

![Step 7: the score label counts up with each coin](images/tutorial-step7.jpg)

**Try it:** collect a few coins. The score in the top left goes up by one each time.

## Step 8: Add the timer and a game-over scene

Now the round has a time limit. A `BGE.CountdownTimer` starts at 30 seconds and goes down with each frame's `dt`. When it runs out, the game changes to a second scene, `GameOverScene`, which shows the score. Pressing OK there starts a new round.

Replace `src/source/main.bs`, so the game knows about both scenes:

**`src/source/main.bs`**

```brighterscript
sub Main(args as dynamic)
  game = new BGE.Game(1280, 720) ' the game canvas size; the engine scales it to fit the screen
  game.fitCanvasToScreen()

  game.defineScene(new PlayScene(game))
  game.defineScene(new GameOverScene(game))
  game.changeScene("PlayScene")

  ' The engine splash plays first. Deep link with splash=0 to skip it while testing.
  game.applyLaunchSplash(new BGE.LaunchParams(args))
  game.play()
end sub
```

Replace `src/source/Scenes/PlayScene.bs`:

**`src/source/Scenes/PlayScene.bs`**

```brighterscript
' The game itself: the player, the coins, the score and the countdown.
class PlayScene extends BGE.GameScene

  ' How long one round lasts, in seconds
  roundSeconds = 30.0

  score = 0
  scoreLabel as BGE.UI.Label
  timeLabel as BGE.UI.Label
  timeLeft as BGE.CountdownTimer

  sub new(game as BGE.Game)
    super(game)
    m.name = "PlayScene"
  end sub

  override sub onCreate(args as roAssociativeArray)
    m.score = 0
    m.timeLeft = new BGE.CountdownTimer()
    m.timeLeft.start(m.roundSeconds)

    m.game.addEntity(new Player(m.game))
    m.game.addEntity(new Coin(m.game))

    m.addTitle()
    m.addScoreLabel()
    m.addTimeLabel()
  end sub

  override sub onUpdate(deltaTime as float)
    m.timeLeft.tick(deltaTime)
    secondsLeft = Int(m.timeLeft.remaining())
    m.timeLabel.setText("Time: " + secondsLeft.toStr())

    if not m.timeLeft.isActive()
      m.game.changeScene("GameOverScene", {score: m.score})
    end if
  end sub

  override sub onInput(input as BGE.GameInput)
    if input.isRemoteBack()
      m.game.End()
    end if
  end sub

  override sub onGameEvent(eventName as string, data as roAssociativeArray)
    if eventName = "coinCollected"
      m.score += 1
      m.scoreLabel.setText("Score: " + m.score.toStr())
    end if
  end sub

  ' The title, centred at the top of the screen
  private sub addTitle()
    title = new BGE.UI.Label(m.game)
    title.setText("Coin Collector")
    title.customPosition = true
    title.horizAlign = "center"
    title.customX = m.game.uiCanvas.getWidth() / 2
    title.customY = m.game.uiCanvas.getHeight() * 0.1
    m.addUi(title)
  end sub

  ' The score, top left. Labels sit 10% in from the edges so they stay title-safe.
  private sub addScoreLabel()
    m.scoreLabel = new BGE.UI.Label(m.game)
    m.scoreLabel.customPosition = true
    m.scoreLabel.customX = m.game.uiCanvas.getWidth() * 0.1
    m.scoreLabel.customY = m.game.uiCanvas.getHeight() * 0.1
    m.scoreLabel.setText("Score: 0")
    m.addUi(m.scoreLabel)
  end sub

  ' The time left, top right
  private sub addTimeLabel()
    m.timeLabel = new BGE.UI.Label(m.game)
    m.timeLabel.customPosition = true
    m.timeLabel.horizAlign = "right"
    m.timeLabel.customX = m.game.uiCanvas.getWidth() * 0.9
    m.timeLabel.customY = m.game.uiCanvas.getHeight() * 0.1
    m.addUi(m.timeLabel)
  end sub

end class
```

Create `src/source/Scenes/GameOverScene.bs`:

**`src/source/Scenes/GameOverScene.bs`**

```brighterscript
' Shown when the time runs out. OK starts a new round.
class GameOverScene extends BGE.GameScene

  finalScore = 0

  sub new(game as BGE.Game)
    super(game)
    m.name = "GameOverScene"
  end sub

  override sub onCreate(args as roAssociativeArray)
    m.finalScore = args.score

    height = m.game.uiCanvas.getHeight()
    m.addLine("GAME OVER", height * 0.3)
    m.addLine("Score: " + m.finalScore.toStr(), height * 0.45)
    m.addLine("Press OK to play again", height * 0.6)
  end sub

  override sub onInput(input as BGE.GameInput)
    if input.isRemoteBack()
      m.game.End()
    else if input.press and input.isButton("ok")
      m.game.changeScene("PlayScene")
    end if
  end sub

  ' A line of text centred horizontally, at `y` pixels down from the top of the screen
  private sub addLine(text as string, y as float)
    label = new BGE.UI.Label(m.game)
    label.setText(text)
    label.customPosition = true
    label.horizAlign = "center"
    label.customX = m.game.uiCanvas.getWidth() / 2
    label.customY = y
    m.addUi(label)
  end sub

end class
```

`onUpdate()` on the scene ticks the timer and updates the time label. When the timer runs out, `changeScene()` switches to the game-over scene and passes the score in its `args`. `onCreate()` on the game-over scene reads it back.

`changeScene()` is deferred until the end of the frame, so it's safe to call from `onUpdate()` or `onInput()`. Each time a scene is entered, its `onCreate()` runs again, which is why `PlayScene` resets the score and the timer there. Anything the old visit added, such as labels and entities, is removed when you leave.

> **Why is the timer dt-driven?** `BGE.CountdownTimer` counts down with the same `dt` as movement, so it pauses when the game pauses. `BGE.GameTimer` measures real wall-clock time instead, which keeps running whatever the game is doing.

![Step 8: the game-over screen with the final score](images/tutorial-step8.jpg)

**Try it:** let the timer run out. The game-over screen shows your score. Press OK to start a new round, which resets the score and the time to 30.

## Step 9 (optional): Pop in the coin

A tween changes a value smoothly over time, here the coin's scale. A coin that grows from a dot each time it appears is a small thing that makes the game feel finished. `tweenManager.to()` writes the interpolated value straight onto the target object each frame, so there's no per-frame bookkeeping.

Update `src/source/Entities/Coin.bs`:

**`src/source/Entities/Coin.bs`**

```brighterscript
' A gold coin. Collecting it scores a point and moves it to a new random spot.
class Coin extends BGE.GameEntity

  radius = 16.0

  sub new(game as BGE.Game)
    super(game)
    m.name = "Coin"
  end sub

  override sub onCreate(args as roAssociativeArray)
    m.addCircle("body", m.radius, {
      offset: BGE.Math.VectorOps.create(-m.radius, m.radius),
      color: &hFFD700
    })
    m.addCircleCollider("coin", m.radius)
    m.respawn()
  end sub

  override sub onCollisionEnter(myCollider as BGE.Collider, otherCollider as BGE.Collider, otherEntity as BGE.GameEntity)
    if otherEntity.name = "Player"
      m.game.postGameEvent("coinCollected", {})
      m.respawn()
    end if
  end sub

  ' Moves the coin to a random spot inside the title-safe area, and pops it in from small
  sub respawn()
    margin = 150.0 ' keeps the coin 10% in from the edges, plus its radius
    m.position.x = BGE.Math.randomFloat(margin, m.game.canvas.getWidth() - margin)
    m.position.y = BGE.Math.randomFloat(margin, m.game.canvas.getHeight() - margin)

    m.scale.x = 0.1
    m.scale.y = 0.1
    m.game.tweenManager.to(m.scale, {x: 1.0, y: 1.0}, 250, BGE.Tweens.Easing.QuadraticEaseOut, {
      owner: m
    })
  end sub

end class
```

`tweenManager.to()` takes the object to change, the values to end at, a duration in milliseconds, an easing curve and options. Passing `owner: m` lets the engine cancel the tween if the coin is destroyed, for example when the scene changes.

> **Why tween `scale` on the entity?** Scale applies to all of an entity's drawables at once, so the coin's circle grows without you changing its size.

![Step 9: the coin grows in at its new spot](images/tutorial-step9.jpg)

**Try it:** collect a coin. The new coin grows in at its new spot over a quarter of a second.

## Where to go next

- [Building a Game with BGE](/game-engine-overview) covers sprites, tweens, camera and collision in more depth.
- [Game Session](/game-session) provides a score, lives and a game-over flow, ready to use, instead of the hand-written version here.
- [Splash Screen](/splash-screen) shows how to restyle or remove the splash you saw at launch.
- The `examples/` folder has complete games built on the engine, such as `pong`, `asteroids` and `platformer`.
