# examples/platformer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `examples/platformer`, a side-scrolling platformer example demonstrating collision *resolution* (built on the engine's detection-only `Collider`), gravity/jump feel, analog/gamepad input, and a `BGE.UI`-based menu system (title, pause, win/game-over).

**Architecture:** One `Level` entity holds every static tile as a named collider+drawable pair (no per-tile entities). `Player` reads movement through `BGE.Controller.ControlMap` (`onControls`), integrates gravity itself, and resolves collisions against `Level`/`Enemy` by comparing a pre-move position snapshot against velocity sign in `onCollision`. `Coin`/`Enemy`/`Goal` are small independent entities that react to the player by name check and broadcast via `Game.postGameEvent()`. `GameStateManager` owns score/lives and the `gameUi` HUD/win/game-over panels. `TitleRoom` and a pause overlay use `BGE.UI` (`UiContainer`/`Button`/`Label`) with the engine's default list-mode focus navigation.

**Tech Stack:** BrighterScript / `BGE` engine (this repo), `npm run create-example` scaffolding, `rokubot-examples` skill for on-device/simulator smoke checks.

**Spec:** `specs/2026-09-05-platformer-example-design.md`

## Global Constraints

- Closes GitHub issue #62. Do not modify engine (`src/source/`) code — this is an example-only build (per the spec: collision resolution is proven in the example first, engine extraction is a separate future issue).
- World space is +y up (per `CLAUDE.md`); only the renderer's projection flips to screen space. Gravity is negative acceleration on `velocity.y`; jump impulse is positive.
- Never compare two custom-class/native-component instances with `=` (runtime `Type Mismatch`, not caught by `bsc`/lint) — compare a stable `name`/`id` field instead. Every `onCollision` check in this plan uses `otherEntity.name = "..."`, never `otherEntity = someEntityRef`.
- An entity callback can invalidate/delete the entity or trigger a room change mid-callback — re-check `m.isValidEntity(entity)`/`entity.isValid()` after any callback that might do that before touching the entity again, matching the engine's own convention.
- Rooibos does not exercise example entity/room code (confirmed: zero `examples/*/**/*.spec.bs` files exist anywhere in this repo). Verification here is `npm run check`/`npm run validate-examples` (compile/type/lint only) plus scripted smoke checks via the `rokubot-examples` skill — not unit tests. Each task's "Verify" step says exactly what to run and what to look for.
- Tile size is a shared constant, `TileSize = 64` (pixels/world-units), defined once in `LevelData.bs` and imported everywhere it's needed.
- All new files live under `examples/platformer/src/source/`, following this repo's existing example conventions (plain classes, no namespace, `Entities/`/`Rooms/` subfolders) — not the engine's `BGE` namespace.

---

## File Structure

```
examples/platformer/
  src/
    source/
      main.bs                       # Task 1
      LevelData.bs                  # Task 2 (tile legend, TileSize const, level rows)
      Entities/
        Level.bs                    # Task 2 (static tile colliders+drawables)
        Player.bs                   # Tasks 3, 4, 6
        Coin.bs                     # Task 7
        Enemy.bs                    # Task 8
        Goal.bs                     # Task 9
        GameStateManager.bs         # Task 10 (score/lives/HUD/win/game-over panels)
      Rooms/
        TitleRoom.bs                # Task 11
        MainRoom.bs                 # Tasks 2, 5, 11, 12 (wires everything together)
      sprites/                      # copied placeholder art (Task 1)
      sounds/                       # copied placeholder audio (Task 1)
      images/                       # Channel_Icon_*/Splash_* (from create-example scaffold)
```

---

### Task 1: Scaffold the example, copy placeholder assets, wire input bindings

**Files:**
- Create: `examples/platformer/` (via `npm run create-example`)
- Create: `examples/platformer/src/sprites/player.png` (copy of `examples/pixels/src/sprites/walkingsprite.png`)
- Create: `examples/platformer/src/sprites/ground.png` (copy of `examples/terrain/src/sprites/grass.png`)
- Create: `examples/platformer/src/sprites/sky.png` (copy of `examples/parallax/src/sprites/parallax-mountain-bg.png`)
- Create: `examples/platformer/src/sprites/CREDITS.md`
- Create: `examples/platformer/src/sounds/jump.wav` (copy of `examples/pong/src/sounds/hit.wav`)
- Modify: `examples/platformer/src/source/main.bs`

**Interfaces:**
- Produces: a runnable, empty example (`MainRoom` from the template) with `game.controls` bound for `"move"` (axis) and `"jump"`/`"pause"` (actions), ready for later tasks to read via `onControls()`.

- [ ] **Step 1: Scaffold the example**

Run: `npm run create-example -- platformer "Platformer"`

Expected: `examples/platformer/` created (manifest, bsconfig, icon/splash, minimal `MainRoom`), and a new "Platformer" entry appears in the root `.vscode/tasks.json` example picker.

- [ ] **Step 2: Copy placeholder art/audio**

```bash
mkdir -p examples/platformer/src/sprites examples/platformer/src/sounds
cp examples/pixels/src/sprites/walkingsprite.png examples/platformer/src/sprites/player.png
cp examples/terrain/src/sprites/grass.png examples/platformer/src/sprites/ground.png
cp examples/parallax/src/sprites/parallax-mountain-bg.png examples/platformer/src/sprites/sky.png
cp examples/pong/src/sounds/hit.wav examples/platformer/src/sounds/jump.wav
cp examples/exampleTemplate/src/sounds/score.wav examples/platformer/src/sounds/coin.wav 2>/dev/null || cp scripts/exampleTemplate/src/sounds/score.wav examples/platformer/src/sounds/coin.wav
cp scripts/exampleTemplate/src/sounds/die.wav examples/platformer/src/sounds/die.wav
cp examples/pong/src/sounds/hit.wav examples/platformer/src/sounds/stomp.wav
```

- [ ] **Step 3: Write the asset credits file**

```markdown
# Art & Audio Credits

Placeholder assets reused from other examples in this repo:

- `player.png` — copied from `examples/pixels/src/sprites/walkingsprite.png`.
  Added directly to this repo's own history in 2021; no separate license
  file was ever attached to it in `examples/pixels`.
- `ground.png` — copied from `examples/terrain/src/sprites/grass.png`.
- `sky.png` — copied from `examples/parallax/src/sprites/parallax-mountain-bg.png`,
  created by [Luis Zuno (@ansimuz)](https://ansimuz.com), licensed
  [CC0](http://creativecommons.org/publicdomain/zero/1.0/).
- `jump.wav`/`stomp.wav` — copied from `examples/pong/src/sounds/hit.wav`.
- `coin.wav` — copied from the generic `score.wav` shared by most examples
  (`scripts/exampleTemplate/src/sounds/score.wav`).
- `die.wav` — copied from `scripts/exampleTemplate/src/sounds/die.wav`.
```

- [ ] **Step 4: Wire input bindings and asset loading in `main.bs`**

```brightscript
sub Main()
  game = new BGE.Game(1280, 720)
  game.fitCanvasToScreen()
  game.enableControllerInput()

  ' "move" falls back to the remote d-pad automatically when no stick input
  ' is present (ControlMap.getAxis()), so the Roku remote alone is enough -
  ' a connected phone/web controller (examples/controller's protocol) or an
  ' analog gamepad stick adds smoother movement on top, with no extra code.
  game.controls.bindAxis("move", "1", 0, "Move")
  game.controls.bindAction("jump", "OK", "a", 0, "Jump")
  game.controls.bindAction("pause", "options", "start", 0, "Pause")

  game.loadBitmap("player", "pkg:/sprites/player.png")
  game.loadBitmap("ground", "pkg:/sprites/ground.png")
  game.loadBitmap("sky", "pkg:/sprites/sky.png")
  game.loadSound("jump", "pkg:/sounds/jump.wav")
  game.loadSound("coin", "pkg:/sounds/coin.wav")
  game.loadSound("stomp", "pkg:/sounds/stomp.wav")
  game.loadSound("die", "pkg:/sounds/die.wav")

  firstRoom = new TitleRoom(game)
  game.defineRoom(firstRoom)
  game.changeRoom(firstRoom.name)

  game.enableStandardDebugUi({memory: false, garbageCollector: false, log: false})

  game.play()
end sub
```

This references `TitleRoom`, which doesn't exist yet — that's fine, it's created in Task 11. For this task, temporarily point `firstRoom` at the template's own `MainRoom` (leave `MainRoom.bs` untouched from the scaffold) so the example builds and runs standalone; Task 2 replaces `MainRoom`'s body and Task 11 swaps `main.bs`'s `firstRoom` back to `TitleRoom` once it exists. Use this substitute for now:

```brightscript
firstRoom = new MainRoom(game)
```

- [ ] **Step 5: Verify it builds and runs**

Run: `cd examples/platformer && npm install && npm run build`
Expected: no compile errors.

Then use the `rokubot-examples` skill to sideload and launch `examples/platformer` — expect the template's default empty black `MainRoom` with no crash.

- [ ] **Step 6: Commit**

```bash
git add examples/platformer .vscode/tasks.json
git commit -m "examples/platformer: scaffold example, placeholder assets, input bindings"
```

---

### Task 2: Level data + `Level` entity + background

**Files:**
- Create: `examples/platformer/src/source/LevelData.bs`
- Create: `examples/platformer/src/source/Entities/Level.bs`
- Modify: `examples/platformer/src/source/Rooms/MainRoom.bs`

**Interfaces:**
- Produces: `LevelData.TileSize` (const, `64`), `LevelData.getRows() as string[]` (10 rows × 40 cols, legend below), `LevelData.NumCols`/`LevelData.NumRows` consts.
- Produces: `Level` (class extending `BGE.GameEntity`) — `onCreate` builds every tile from `LevelData.getRows()`; no public methods needed by later tasks (they identify it via `otherEntity.name = "Level"` and read `otherCollider.tagsList.hasTag("solid"|"oneWay")`/`otherCollider.offset`/`.width`/`.height`).
- Consumes (Task 3+): tile world position formula — for row `r` (0 = top row of the string array) and column `c`: `topY = (LevelData.NumRows - r) * LevelData.TileSize`, `leftX = c * LevelData.TileSize`. A tile's collider/drawable offset is `(leftX, topY)` (top-left anchor, per `DrawableRectangle`'s documented convention — the same offset value is passed to both the drawable and the collider, mirroring `examples/breakout/src/source/entities/Ball.bs`'s `cornerOffset` pattern).

- [ ] **Step 1: Write `LevelData.bs`**

```brightscript
' The platformer's level layout, as one row-of-characters-per-string array -
' no tilemap format/editor, per this example's design spec. Row 0 is the top
' of the level; row (NumRows - 1) is the bottom. Legend:
'   #  solid tile (blocks from every side)
'   -  one-way platform (land on top only, pass through from below/side)
'   o  coin spawn
'   e  enemy patrol spawn
'   P  player spawn
'   G  goal spawn
'   .  empty
const TileSize = 64
const NumCols = 40
const NumRows = 10

function getLevelRows() as string[]
  return [
    "........................................",
    "........................................",
    "................ooo.....................",
    "...............-----....................",
    "........................................",
    "........................................",
    "........................................",
    "........................................",
    ".P...ooo...................e...oo...G...",
    "####################..##################"
  ]
end function
```

- [ ] **Step 2: Write `Entities/Level.bs`**

```brightscript
import "../LevelData.bs"

' Holds every static tile in the level as one named collider + one matching
' drawable each - not one GameEntity per tile, so the static layout costs
' nothing in per-frame onUpdate/onInput dispatch. See LevelData.bs for the
' row/column -> world-position formula this class implements.
class Level extends BGE.GameEntity

  sub new(game as BGE.Game)
    super(game)
    m.name = "Level"
    m.persistent = false
  end sub

  override sub onCreate(args as roAssociativeArray)
    rows = getLevelRows()
    groundBitmap = m.game.getBitmap("ground")
    for r = 0 to rows.count() - 1
      row = rows[r]
      for c = 0 to row.len() - 1
        tileChar = row.mid(c, 1)
        if tileChar = "#" or tileChar = "-"
          m.addTile(r, c, tileChar, groundBitmap)
        end if
      end for
    end for
  end sub

  private sub addTile(r as integer, c as integer, tileChar as string, groundBitmap as roBitmap)
    topY = (NumRows - r) * TileSize
    leftX = c * TileSize
    tileName = "tile_" + r.toStr() + "_" + c.toStr()

    if tileChar = "#"
      region = CreateObject("roRegion", groundBitmap, 0, 0, groundBitmap.GetWidth(), groundBitmap.GetHeight())
      image = m.addImage(tileName, region, {
        offset: BGE.Math.VectorOps.create(leftX, topY),
        drawMode: BGE.SceneObjectDrawMode.matchCamera
      })
      image.width = TileSize
      image.height = TileSize
    else
      m.addRectangle(tileName, TileSize, TileSize, {
        offset: BGE.Math.VectorOps.create(leftX, topY),
        color: &h8B5A2BFF ' wood-brown, distinguishes one-way platforms from solid ground
      })
    end if

    collider = m.addRectangleCollider(tileName, TileSize, TileSize, leftX, topY)
    if tileChar = "#"
      collider.tagsList.add("solid")
    else
      collider.tagsList.add("oneWay")
    end if
  end sub

end class
```

`addImage`'s `args.drawMode` is set to `matchCamera` (the default) explicitly for clarity since a flat 2D platformer never rotates its camera; check `Image.width`/`.height` are plain settable fields (they are — every `Drawable` subclass exposes them) so the tile draws at exactly `TileSize` regardless of the source bitmap's native resolution.

- [ ] **Step 3: Add a background image and wire `Level` into `MainRoom`**

Replace `MainRoom.bs`'s contents entirely:

```brightscript
import "../LevelData.bs"
import "../Entities/Level.bs"

class MainRoom extends BGE.Room

  sub new(game as BGE.Game)
    super(game)
    m.name = "MainRoom"
  end sub

  override sub onCreate(args as roAssociativeArray)
    skyBitmap = m.game.getBitmap("sky")
    skyRegion = CreateObject("roRegion", skyBitmap, 0, 0, skyBitmap.GetWidth(), skyBitmap.GetHeight())
    skyImage = m.addImage("sky", skyRegion, {
      offset: BGE.Math.VectorOps.create(0, NumRows * TileSize),
      zIndex: -100
    })
    skyImage.width = NumCols * TileSize
    skyImage.height = NumRows * TileSize

    m.game.addEntity(new Level(m.game))
  end sub

  override sub onInput(input as BGE.GameInput)
    if input.press and input.isButton("back")
      m.game.End()
    end if
  end sub

end class
```

`zIndex: -100` on the sky image keeps it drawn behind every tile/entity added afterward (lower `zIndex` draws first — confirm this matches `GameEntity`/drawable insertion-order convention already used elsewhere in the codebase before relying on it; if `zIndex` isn't a real `args` field on `Image`, drop it and rely on insertion order instead, since `Level`/`Player`/etc. are all added to the scene *after* this sky image in the same frame).

- [ ] **Step 4: Verify**

Run: `npm run build && npm run validate` (from repo root) — expect clean.
Run (from `examples/platformer`): `npm run build` — expect clean.

Sideload via `rokubot-examples` and screenshot `MainRoom`: expect to see the sky backdrop, brown one-way platform, ground tiles with a visible 2-tile gap, and nothing else yet (no player/coins/enemy/goal sprites — those are still just characters in `LevelData`, not spawned entities, until later tasks).

- [ ] **Step 5: Commit**

```bash
git add examples/platformer
git commit -m "examples/platformer: level data, Level entity, background"
```

---

### Task 3: `Player` movement — gravity, run, jump, coyote time, jump buffering (no collision resolution yet)

**Files:**
- Create: `examples/platformer/src/source/Entities/Player.bs`
- Modify: `examples/platformer/src/source/Rooms/MainRoom.bs`

**Interfaces:**
- Consumes: `LevelData.getRows()` (to find the `P` spawn cell), `TileSize`/`NumRows` consts (Task 2).
- Produces: `Player` (class extending `BGE.GameEntity`) with public fields `grounded as boolean`, `positionBeforeMove as BGE.Math.Vector`, `spawnPosition as BGE.Math.Vector`, and a public `sub respawn()`. Later tasks (4, 6, 8) extend this same file's `onCollision`/`onUpdate`.

- [ ] **Step 1: Write `Player.bs` (movement only)**

```brightscript
import "../LevelData.bs"

class Player extends BGE.GameEntity

  width = 56.0
  height = 72.0

  runSpeed = 350.0
  gravity = 2000.0
  terminalVelocity = -1400.0
  jumpVelocity = 900.0
  coyoteTime = 0.1
  jumpBufferTime = 0.12

  grounded = false
  coyoteTimer = 0.0
  jumpBufferTimer = 0.0
  jumpHeldLastFrame = false

  positionBeforeMove = BGE.Math.VectorOps.create()
  spawnPosition = BGE.Math.VectorOps.create()

  moveIntentX = 0.0
  wantsJump = false
  jumpHeld = false

  sprite as BGE.Sprite
  facingRight = true

  sub new(game as BGE.Game)
    super(game)
    m.name = "Player"
  end sub

  override sub onCreate(args as roAssociativeArray)
    m.spawnPosition = BGE.Math.VectorOps.create(m.position.x, m.position.y)

    m.sprite = m.addSprite("body", m.game.getBitmap("player"), 144, 180)
    m.sprite.applyPreTranslation(-72, -180)
    m.sprite.scale = BGE.Math.VectorOps.create(0.4, 0.4, 1)
    m.sprite.addAnimation("idle_right", {startFrame: 0, frameCount: 1}, 12, BGE.SpritePlayMode.Forward)
    m.sprite.addAnimation("idle_left", {startFrame: 17, frameCount: 1}, 12, BGE.SpritePlayMode.Forward)
    m.sprite.addAnimation("run_right", {startFrame: 1, frameCount: 8}, 16, BGE.SpritePlayMode.Loop)
    m.sprite.addAnimation("run_left", {startFrame: 9, frameCount: 8}, 16, BGE.SpritePlayMode.Loop)
    m.sprite.playAnimation("idle_right")

    m.addRectangleCollider("body", m.width, m.height, -m.width / 2.0, m.height)
  end sub

  ' Restores the player to its level-start position with zero velocity -
  ' called on the initial spawn (implicitly, since m.position is already the
  ' spawn point from MainRoom) and again whenever the player is hurt (Task 8).
  sub respawn()
    m.position = BGE.Math.VectorOps.create(m.spawnPosition.x, m.spawnPosition.y)
    m.velocity = BGE.Math.VectorOps.create()
    m.grounded = false
  end sub

  override sub onControls(controls as BGE.Controller.ControlMap)
    move = controls.getAxis("move")
    m.moveIntentX = move.x
    m.wantsJump = controls.isActionPressed("jump")
    m.jumpHeld = controls.isActionHeld("jump")
  end sub

  override sub onUpdate(dt as float)
    m.positionBeforeMove = BGE.Math.VectorOps.create(m.position.x, m.position.y)

    ' Horizontal run + facing/animation.
    m.velocity.x = m.moveIntentX * m.runSpeed
    if m.moveIntentX > 0.05
      m.facingRight = true
    else if m.moveIntentX < -0.05
      m.facingRight = false
    end if
    if m.grounded
      if abs(m.moveIntentX) > 0.05
        m.sprite.playAnimation(m.facingAnimation("run"))
      else
        m.sprite.playAnimation(m.facingAnimation("idle"))
      end if
    end if

    ' Coyote time + jump buffering.
    if m.grounded
      m.coyoteTimer = m.coyoteTime
    else
      m.coyoteTimer = m.coyoteTimer - dt
    end if
    if m.wantsJump
      m.jumpBufferTimer = m.jumpBufferTime
    else
      m.jumpBufferTimer = m.jumpBufferTimer - dt
    end if
    if m.jumpBufferTimer > 0.0 and m.coyoteTimer > 0.0
      m.velocity.y = m.jumpVelocity
      m.grounded = false
      m.coyoteTimer = 0.0
      m.jumpBufferTimer = 0.0
    end if

    ' Variable jump height: cut the rise short if the button releases early.
    if not m.jumpHeld and m.jumpHeldLastFrame and m.velocity.y > 0.0
      m.velocity.y = m.velocity.y * 0.5
    end if
    m.jumpHeldLastFrame = m.jumpHeld

    ' Gravity, capped so one frame's fall never exceeds one tile (avoids
    ' tunneling through a thin floor without needing substeps).
    m.velocity.y = m.velocity.y - m.gravity * dt
    if m.velocity.y < m.terminalVelocity
      m.velocity.y = m.terminalVelocity
    end if

    ' Assume airborne; onCollision() re-grounds this same frame if the
    ' player is actually resting on something (Task 4).
    m.grounded = false
  end sub

  private function facingAnimation(prefix as string) as string
    if m.facingRight
      return prefix + "_right"
    end if
    return prefix + "_left"
  end function

end class
```

- [ ] **Step 2: Spawn the player from `LevelData`'s `P` marker in `MainRoom`**

Add to `MainRoom.bs`'s imports: `import "../Entities/Player.bs"`.

Add to the end of `onCreate`, after `m.game.addEntity(new Level(m.game))`:

```brightscript
    for r = 0 to (getLevelRows()).count() - 1
      row = (getLevelRows())[r]
      for c = 0 to row.len() - 1
        if row.mid(c, 1) = "P"
          player = m.game.addEntity(new Player(m.game)) as Player
          player.position.x = c * TileSize + TileSize / 2.0
          player.position.y = (NumRows - r) * TileSize
        end if
      end for
    end for
```

(This duplicated grid-walk is intentionally simple for a reference example; Task 7-9 reuse the same pattern for coins/enemy/goal rather than introducing a generic spawn-table abstraction — YAGNI for a level this small.)

- [ ] **Step 3: Verify**

Run: `npm run build` (repo root), `npm run build` (in `examples/platformer`) — expect clean.

Sideload via `rokubot-examples`: expect the player sprite to appear at its spawn tile and immediately fall (no collision resolution yet, so it falls through the ground and off the bottom of the level — this is the *expected*, temporary state for this task only). Confirm via screenshots that: the sprite is visibly scaled/centered reasonably, pressing the d-pad left/right visibly flips the run animation's facing direction before the player falls out of view, and pressing OK while falling doesn't crash (jump input is simply ignored since `grounded` is never true yet).

- [ ] **Step 4: Commit**

```bash
git add examples/platformer
git commit -m "examples/platformer: Player movement (gravity/run/jump/coyote/buffer), no collision resolution yet"
```

---

### Task 4: Player collision resolution against `Level` (solid + one-way)

**Files:**
- Modify: `examples/platformer/src/source/Entities/Player.bs`

**Interfaces:**
- Consumes: `Level`'s tile colliders (Task 2) — named `tile_<r>_<c>`, tagged `"solid"`/`"oneWay"`, with `offset`/`width`/`height` giving the tile's top-left world position and size.
- Produces: `Player.grounded` now becomes reliably true when resting on a solid or one-way tile, for Task 6 (particles) and Task 8 (enemy stomp) to read.

- [ ] **Step 1: Add `onCollision` to `Player.bs`**

```brightscript
  override sub onCollision(myCollider as BGE.Collider, otherCollider as BGE.Collider, otherEntity as BGE.GameEntity)
    if otherEntity.name <> "Level"
      return
    end if

    tileTop = otherCollider.offset.y
    tileBottom = otherCollider.offset.y - otherCollider.height
    tileLeft = otherCollider.offset.x
    tileRight = otherCollider.offset.x + otherCollider.width
    isOneWay = otherCollider.tagsList.hasTag("oneWay")

    playerBottomBefore = m.positionBeforeMove.y - m.height
    playerTopBefore = m.positionBeforeMove.y
    playerLeftBefore = m.positionBeforeMove.x - m.width / 2.0
    playerRightBefore = m.positionBeforeMove.x + m.width / 2.0

    landedOnTop = m.velocity.y <= 0.0 and playerBottomBefore >= tileTop - 1.0
    if landedOnTop
      m.position.y = tileTop + m.height
      m.velocity.y = 0.0
      m.grounded = true
      return
    end if

    if isOneWay
      ' One-way platforms only ever block a landing-from-above - every
      ' other case (rising into it, approaching from a side) passes through.
      return
    end if

    hitHead = m.velocity.y > 0.0 and playerTopBefore <= tileBottom + 1.0
    if hitHead
      m.position.y = tileBottom - m.height
      m.velocity.y = 0.0
      return
    end if

    ' Horizontal: push out the side the player was already outside of.
    if playerRightBefore <= tileLeft + 1.0
      m.position.x = tileLeft - m.width / 2.0
      m.velocity.x = 0.0
    else if playerLeftBefore >= tileRight - 1.0
      m.position.x = tileRight + m.width / 2.0
      m.velocity.x = 0.0
    end if
  end sub
```

- [ ] **Step 2: Verify**

Run: `npm run build` (root + example) — expect clean.

Sideload via `rokubot-examples` and check via screenshots/act sequence:
- Player spawns standing on the ground row, doesn't sink in.
- Walking left/right stops at the level edges (nowhere to walk off at column 0, but the 2-tile gap near column 20 should be jumpable — screenshot the player mid-air over the gap after a jump input, then screenshot it landing safely on the far side).
- Jumping onto the one-way platform (row 3) from below does nothing (passes through); jumping from the side and coming down onto its top surface lands normally; standing on it and pressing down+jump (or just walking off the side) drops through.
- Walking into the gap without jumping causes the player to fall out of the level (expected — no bottomless-pit recovery is in scope yet; Task 8's `respawn()`/hurt flow is what will eventually catch this once wired to a kill-plane, added in Task 10).

- [ ] **Step 3: Commit**

```bash
git add examples/platformer
git commit -m "examples/platformer: Player collision resolution vs Level tiles (solid + one-way)"
```

---

### Task 5: Scrolling camera, clamped to level bounds

**Files:**
- Modify: `examples/platformer/src/source/Rooms/MainRoom.bs`

**Interfaces:**
- Consumes: `Player` entity (Task 3) via `m.game.getEntityByName("Player")`.

- [ ] **Step 1: Add camera-follow to `MainRoom`'s `onUpdate`**

```brightscript
  override sub onUpdate(dt as float)
    player = m.game.getEntityByName("Player") as Player
    if invalid = player
      return
    end if

    camera = m.game.canvas.renderer.camera
    halfViewWidth = camera.frameSize.x / 2.0
    levelWidth = NumCols * TileSize

    targetX = player.position.x
    minX = halfViewWidth
    maxX = levelWidth - halfViewWidth
    if targetX < minX
      targetX = minX
    else if targetX > maxX
      targetX = maxX
    end if

    camera.setTarget(BGE.Math.VectorOps.create(targetX, camera.frameSize.y / 2.0))
  end sub
```

(`camera.frameSize.y / 2.0` keeps the vertical framing fixed — this level's total height, `NumRows * TileSize = 640`, is close enough to the 720px game canvas that vertical scrolling isn't needed for this reference level; a taller level would need the same min/max clamp applied to Y too, left out here as genuinely out of scope for this level's size.)

Add `import "../Entities/Player.bs"` to `MainRoom.bs` if not already present from Task 3.

- [ ] **Step 2: Verify**

Run: `npm run build` (root + example) — expect clean.

Sideload via `rokubot-examples`: walk the player right across the whole level; screenshot partway through to confirm the camera is following (player stays roughly centered) and screenshot at the very start/end of the level to confirm the camera stops scrolling past the level edges (background/ground tiles don't run out with visible empty space beyond them).

- [ ] **Step 3: Commit**

```bash
git add examples/platformer
git commit -m "examples/platformer: scrolling camera clamped to level bounds"
```

---

### Task 6: Squash/stretch + jump/landing dust particles

**Files:**
- Modify: `examples/platformer/src/source/Entities/Player.bs`

**Interfaces:**
- Consumes: `Game.tweenManager.to()` (existing engine API), `GameEntity.addParticles()`/`DrawableParticles.burst()` (existing engine API).

- [ ] **Step 1: Add a dust emitter and squash/stretch tween helper in `onCreate`**

```brightscript
    m.dust = m.addParticles("dust", BGE.ParticleShape.Rectangle, {
      lifetime: 0.35,
      lifetimeSpread: 0.1,
      velocitySpreadMagnitude: 90.0,
      startColor: BGE.Colors.White,
      endColor: BGE.Colors.White,
      startAlpha: 180.0,
      endAlpha: 0.0,
      startSize: 6.0,
      endSize: 1.0,
      offset: BGE.Math.VectorOps.create(0, 4)
    })
```

Add a `dust as BGE.DrawableParticles` field declaration near the top of the class alongside `sprite`.

- [ ] **Step 2: Trigger squash/stretch + dust on jump takeoff**

In `onUpdate`, right where the jump actually fires (`if m.jumpBufferTimer > 0.0 and m.coyoteTimer > 0.0`), add before resetting the timers:

```brightscript
      m.game.tweenManager.to(m.scale, {x: 0.8, y: 1.25}, 80, BGE.Tweens.Easing.EaseOutQuad)
      m.dust.burst(5)
```

- [ ] **Step 3: Trigger landing squash + dust in `onCollision`'s "landed on top" branch**

In the `landedOnTop` branch added in Task 4, after `m.grounded = true`, add:

```brightscript
      fallSpeed = -m.velocity.y ' velocity.y at the moment of landing was already zeroed above, so capture it first
```

Correction — capture the impact speed *before* zeroing it. Revise the branch to:

```brightscript
    landedOnTop = m.velocity.y <= 0.0 and playerBottomBefore >= tileTop - 1.0
    if landedOnTop
      impactSpeed = -m.velocity.y
      m.position.y = tileTop + m.height
      m.velocity.y = 0.0
      m.grounded = true
      if impactSpeed > 300.0
        m.game.tweenManager.to(m.scale, {x: 1.3, y: 0.7}, 60, BGE.Tweens.Easing.EaseOutQuad)
        m.game.tweenManager.to(m.scale, {x: 1.0, y: 1.0}, 180, BGE.Tweens.Easing.EaseOutQuad, {delay: 60})
        m.dust.burst(8)
      end if
      return
    end if
```

Also add, right after the jump-takeoff tween in Step 2, its own return-to-normal tween so the stretch doesn't stick if the player lands again very quickly:

```brightscript
      m.game.tweenManager.to(m.scale, {x: 1.0, y: 1.0}, 150, BGE.Tweens.Easing.EaseOutQuad, {delay: 80})
```

(Confirmed: `TweenManager.to()`'s `options` associative array supports `delay` — `src/source/engine/TweenManager.bs:90-96` reads `options.delay` directly.)

- [ ] **Step 4: Verify**

Run: `npm run build` (root + example) — expect clean.

Sideload via `rokubot-examples`: jump and screenshot mid-air (expect a visibly stretched sprite and a small dust puff at the takeoff point) and screenshot immediately after a landing from a height (expect a visibly squashed sprite for a brief moment and a dust puff at the landing point). A short hop shouldn't show landing dust (the `impactSpeed > 300.0` threshold) — confirm via a small tap-jump vs. a fall from the one-way platform.

- [ ] **Step 5: Commit**

```bash
git add examples/platformer
git commit -m "examples/platformer: squash/stretch + jump/landing dust particles"
```

---

### Task 7: `Coin` entity

**Files:**
- Create: `examples/platformer/src/source/Entities/Coin.bs`
- Modify: `examples/platformer/src/source/Rooms/MainRoom.bs`

**Interfaces:**
- Produces: `Coin` (class extending `BGE.GameEntity`) — posts `Game.postGameEvent("coinCollected", {})` on pickup (consumed by `GameStateManager`, Task 10).

- [ ] **Step 1: Write `Coin.bs`**

```brightscript
class Coin extends BGE.GameEntity

  radius = 16.0

  sub new(game as BGE.Game)
    super(game)
    m.name = "Coin"
  end sub

  override sub onCreate(args as roAssociativeArray)
    m.addCircle("body", m.radius, {
      offset: BGE.Math.VectorOps.create(-m.radius, m.radius),
      color: &hFFD700FF
    })
    m.addCircleCollider("body", m.radius, -m.radius, m.radius)
    m.sparkle = m.addParticles("sparkle", BGE.ParticleShape.Rectangle, {
      lifetime: 0.4,
      velocitySpreadMagnitude: 120.0,
      startColor: &hFFD700FF,
      endColor: &hFFFFAAFF,
      startAlpha: 255.0,
      endAlpha: 0.0,
      startSize: 5.0,
      endSize: 1.0
    })
  end sub

  override sub onCollision(myCollider as BGE.Collider, otherCollider as BGE.Collider, otherEntity as BGE.GameEntity)
    if otherEntity.name <> "Player"
      return
    end if
    m.sparkle.burst(10)
    m.game.playSound("coin")
    m.game.postGameEvent("coinCollected", {})
    m.invalidate()
  end sub

end class
```

Add a `sparkle as BGE.DrawableParticles` field declaration.

- [ ] **Step 2: Spawn coins from `LevelData`'s `o` markers in `MainRoom`**

Add `import "../Entities/Coin.bs"`. Extend the same grid-walk loop from Task 3 (the one currently checking for `"P"`) with an `else if`:

```brightscript
        else if row.mid(c, 1) = "o"
          coin = m.game.addEntity(new Coin(m.game)) as Coin
          coin.position.x = c * TileSize + TileSize / 2.0
          coin.position.y = (NumRows - r) * TileSize - TileSize / 2.0
```

- [ ] **Step 3: Verify**

Run: `npm run build` (root + example) — expect clean.

Sideload via `rokubot-examples`: screenshot the coins near the player spawn and above the one-way platform; walk/jump the player into one and screenshot immediately after — expect the coin gone and a brief sparkle burst visible in that frame.

- [ ] **Step 4: Commit**

```bash
git add examples/platformer
git commit -m "examples/platformer: Coin entity (pickup, sparkle, coinCollected event)"
```

---

### Task 8: `Enemy` entity + stomp/hurt resolution in `Player`

**Files:**
- Create: `examples/platformer/src/source/Entities/Enemy.bs`
- Modify: `examples/platformer/src/source/Entities/Player.bs`
- Modify: `examples/platformer/src/source/Rooms/MainRoom.bs`

**Interfaces:**
- Produces: `Enemy` (class extending `BGE.GameEntity`) with a public `sub stomp()`.
- Modifies: `Player.onCollision` gains an `otherEntity.name = "Enemy"` branch; `Player` gains `sub takeDamage()` and an `invulnerableTimer` field.

- [ ] **Step 1: Write `Enemy.bs`**

```brightscript
class Enemy extends BGE.GameEntity

  width = 48.0
  height = 48.0
  patrolSpeed = 100.0
  patrolRange = 128.0
  spawnX = 0.0

  sub new(game as BGE.Game)
    super(game)
    m.name = "Enemy"
  end sub

  override sub onCreate(args as roAssociativeArray)
    m.spawnX = m.position.x
    m.velocity.x = m.patrolSpeed
    m.addRectangle("body", m.width, m.height, {
      offset: BGE.Math.VectorOps.create(-m.width / 2.0, m.height),
      color: &hCC3333FF
    })
    m.addRectangleCollider("body", m.width, m.height, -m.width / 2.0, m.height)
    m.poof = m.addParticles("poof", BGE.ParticleShape.Rectangle, {
      lifetime: 0.35,
      velocitySpreadMagnitude: 100.0,
      startColor: &hCC3333FF,
      endColor: &h662222FF,
      startAlpha: 220.0,
      endAlpha: 0.0,
      startSize: 6.0,
      endSize: 1.0
    })
  end sub

  override sub onUpdate(dt as float)
    if m.position.x <= m.spawnX - m.patrolRange
      m.velocity.x = m.patrolSpeed
    else if m.position.x >= m.spawnX + m.patrolRange
      m.velocity.x = -m.patrolSpeed
    end if
  end sub

  ' Called by Player.onCollision() when a stomp is detected. Bursts, plays a
  ' sound, and removes this entity - Player handles its own bounce velocity.
  sub stomp()
    m.poof.burst(12)
    m.game.playSound("stomp")
    m.game.postGameEvent("enemyStomped", {})
    m.invalidate()
  end sub

end class
```

Add a `poof as BGE.DrawableParticles` field declaration.

- [ ] **Step 2: Extend `Player.bs`'s `onCollision` with an `Enemy` branch, plus a `takeDamage()` method**

Add fields: `invulnerableTime = 0.5`, `invulnerableTimer = 0.0`, `bounceVelocity = 700.0`.

In `onUpdate`, near the top (after the `positionBeforeMove` snapshot), decrement the timer:

```brightscript
    if m.invulnerableTimer > 0.0
      m.invulnerableTimer = m.invulnerableTimer - dt
    end if
```

Add to `onCollision`, before the `if otherEntity.name <> "Level"` check (so it runs for any `otherEntity`, not just `"Level"`):

```brightscript
    if otherEntity.name = "Enemy"
      enemy = otherEntity as Enemy
      playerBottomBefore = m.positionBeforeMove.y - m.height
      if m.velocity.y <= 0.0 and playerBottomBefore >= enemy.position.y - 4.0
        enemy.stomp()
        m.velocity.y = m.bounceVelocity
      else if m.invulnerableTimer <= 0.0
        m.takeDamage()
      end if
      return
    end if

    if otherEntity.name <> "Level"
      return
    end if
```

Add `import "Enemy.bs"` to the top of `Player.bs`.

Add the `takeDamage()` method:

```brightscript
  sub takeDamage()
    m.invulnerableTimer = m.invulnerableTime
    m.game.postGameEvent("playerHurt", {})
    m.respawn()
  end sub
```

- [ ] **Step 3: Spawn the enemy from `LevelData`'s `e` marker in `MainRoom`**

Add `import "../Entities/Enemy.bs"`. Extend the grid-walk loop with another `else if`:

```brightscript
        else if row.mid(c, 1) = "e"
          enemy = m.game.addEntity(new Enemy(m.game)) as Enemy
          enemy.position.x = c * TileSize + TileSize / 2.0
          enemy.position.y = (NumRows - r) * TileSize
```

- [ ] **Step 4: Verify**

Run: `npm run build` (root + example) — expect clean.

Sideload via `rokubot-examples`: screenshot the enemy patrolling back and forth near column 27. Jump on top of it — expect it destroyed with a poof burst and the player bouncing upward. Walk into it from the side without jumping — expect the player to respawn at the level start (confirm via screenshot: player back at column 1).

- [ ] **Step 5: Commit**

```bash
git add examples/platformer
git commit -m "examples/platformer: Enemy entity (patrol, stomp, hurt) + Player damage/respawn"
```

---

### Task 9: `Goal` entity

**Files:**
- Create: `examples/platformer/src/source/Entities/Goal.bs`
- Modify: `examples/platformer/src/source/Rooms/MainRoom.bs`

**Interfaces:**
- Produces: `Goal` — posts `Game.postGameEvent("levelComplete", {})` on touch (consumed by `GameStateManager`, Task 10).

- [ ] **Step 1: Write `Goal.bs`**

```brightscript
class Goal extends BGE.GameEntity

  width = 48.0
  height = 96.0

  sub new(game as BGE.Game)
    super(game)
    m.name = "Goal"
  end sub

  override sub onCreate(args as roAssociativeArray)
    m.addRectangle("body", m.width, m.height, {
      offset: BGE.Math.VectorOps.create(-m.width / 2.0, m.height),
      color: &h33AAFFFF
    })
    m.addRectangleCollider("body", m.width, m.height, -m.width / 2.0, m.height)
  end sub

  override sub onCollision(myCollider as BGE.Collider, otherCollider as BGE.Collider, otherEntity as BGE.GameEntity)
    if otherEntity.name <> "Player"
      return
    end if
    m.game.postGameEvent("levelComplete", {})
  end sub

end class
```

- [ ] **Step 2: Spawn the goal from `LevelData`'s `G` marker in `MainRoom`**

Add `import "../Entities/Goal.bs"`. Extend the grid-walk loop:

```brightscript
        else if row.mid(c, 1) = "G"
          goal = m.game.addEntity(new Goal(m.game)) as Goal
          goal.position.x = c * TileSize + TileSize / 2.0
          goal.position.y = (NumRows - r) * TileSize
```

- [ ] **Step 3: Verify**

Run: `npm run build` (root + example) — expect clean.

Sideload via `rokubot-examples`: walk/jump the player to the goal at the far end of the level and screenshot on contact. No visible win-screen reaction yet (Task 10 adds that) — this task only confirms the goal renders and the collision fires without crashing (temporarily verify by having `Goal.onCollision` also `print "levelComplete"` during this task's manual check, then remove the `print` before committing — `postGameEvent` alone gives no observable signal until `GameStateManager` exists).

- [ ] **Step 4: Commit**

```bash
git add examples/platformer
git commit -m "examples/platformer: Goal entity (levelComplete event)"
```

---

### Task 10: `GameStateManager` — score, lives, HUD, win/game-over panels

**Files:**
- Create: `examples/platformer/src/source/Entities/GameStateManager.bs`
- Modify: `examples/platformer/src/source/Rooms/MainRoom.bs`

**Interfaces:**
- Consumes: `"coinCollected"`, `"enemyStomped"`, `"playerHurt"`, `"levelComplete"` game events (Tasks 7-9); `Player.respawn()` (Task 3).
- Produces: a `gameUi` HUD (score/lives `Label`s) and win/game-over `UiContainer` panels, shown via `m.game.gameUi.addChild()`/`removeChild()`.

- [ ] **Step 1: Write `GameStateManager.bs`**

```brightscript
import "Player.bs"

' Tracks score/lives, listens for the game events Coin/Enemy/Goal post
' (BGE.Game.postGameEvent), and owns the HUD + win/game-over BGE.UI panels -
' the same "entity reacts to broadcast events, doesn't know who sent them"
' pattern as examples/breakout's ScoreHandler, but with real BGE.UI widgets
' instead of a drawText overlay.
class GameStateManager extends BGE.GameEntity

  score = 0
  lives = 3
  gameOver = false
  won = false

  scoreLabel as BGE.UI.Label
  livesLabel as BGE.UI.Label
  endPanel as BGE.UI.UiContainer
  endMessageLabel as BGE.UI.Label

  sub new(game as BGE.Game)
    super(game)
    m.name = "GameStateManager"
    m.persistent = true
  end sub

  override sub onCreate(args as roAssociativeArray)
    width = m.game.uiCanvas.getWidth()
    height = m.game.uiCanvas.getHeight()

    m.scoreLabel = new BGE.UI.Label(m.game)
    m.scoreLabel.customPosition = true
    m.scoreLabel.customX = width * 0.1
    m.scoreLabel.customY = height * 0.05
    m.scoreLabel.setText("Score: 0")
    m.game.gameUi.addChild(m.scoreLabel)

    m.livesLabel = new BGE.UI.Label(m.game)
    m.livesLabel.customPosition = true
    m.livesLabel.customX = width * 0.8
    m.livesLabel.customY = height * 0.05
    m.livesLabel.setText("Lives: 3")
    m.game.gameUi.addChild(m.livesLabel)

    m.endPanel = new BGE.UI.UiContainer(m.game)
    m.endPanel.customPosition = true
    m.endPanel.customX = width * 0.3
    m.endPanel.customY = height * 0.35

    m.endMessageLabel = new BGE.UI.Label(m.game)
    m.endMessageLabel.customPosition = true
    m.endMessageLabel.customX = 0
    m.endMessageLabel.customY = 0
    m.endPanel.addChild(m.endMessageLabel)

    retryButton = new BGE.UI.Button(m.game)
    retryButton.setLabel("Retry")
    retryButton.customPosition = true
    retryButton.customX = 0
    retryButton.customY = 60
    retryButton.width = width * 0.2
    retryButton.height = height * 0.07
    retryButton.onActivate = sub(button as BGE.UI.Button)
      button.game.resetRoom()
    end sub
    m.endPanel.addChild(retryButton)

    quitButton = new BGE.UI.Button(m.game)
    quitButton.setLabel("Quit to Title")
    quitButton.customPosition = true
    quitButton.customX = 0
    quitButton.customY = 60 + height * 0.09
    quitButton.width = width * 0.2
    quitButton.height = height * 0.07
    quitButton.onActivate = sub(button as BGE.UI.Button)
      button.game.changeRoom("TitleRoom")
    end sub
    m.endPanel.addChild(quitButton)
  end sub

  override sub onGameEvent(eventName as string, data as roAssociativeArray)
    if m.gameOver or m.won
      return
    end if

    if eventName = "coinCollected"
      m.score += 10
      m.scoreLabel.setText("Score: " + m.score.toStr())
    else if eventName = "enemyStomped"
      m.score += 25
      m.scoreLabel.setText("Score: " + m.score.toStr())
    else if eventName = "playerHurt"
      m.lives -= 1
      m.livesLabel.setText("Lives: " + m.lives.toStr())
      if m.lives <= 0
        m.gameOver = true
        m.showEndPanel("Game Over - Score: " + m.score.toStr())
      end if
    else if eventName = "levelComplete"
      m.won = true
      m.showEndPanel("You Win! - Score: " + m.score.toStr())
    end if
  end sub

  private sub showEndPanel(message as string)
    m.endMessageLabel.setText(message)
    m.game.gameUi.addChild(m.endPanel)
    m.game.pause()
  end sub

end class
```

- [ ] **Step 2: Add `GameStateManager` to `MainRoom`**

Add `import "../Entities/GameStateManager.bs"`. Add to `onCreate`, alongside the other `addEntity` calls:

```brightscript
    m.game.addEntity(new GameStateManager(m.game))
```

- [ ] **Step 3: Verify**

Run: `npm run build` (root + example) — expect clean.

Sideload via `rokubot-examples`:
- Screenshot the HUD after collecting a coin (score increments) and after taking damage from the enemy (lives decrements).
- Deliberately lose all 3 lives (walk into the enemy repeatedly) — expect the game-over panel to appear with Retry/Quit to Title buttons, and the game visibly frozen behind it (`Game.pause()` in effect).
- Press OK on Retry (focus should already be seeded on it, per the engine's default list-mode focus) — expect the level to fully reset (`Game.resetRoom()`).
- Reach the `Goal` — expect the win panel instead, with the same two buttons.

- [ ] **Step 4: Commit**

```bash
git add examples/platformer
git commit -m "examples/platformer: GameStateManager (score/lives HUD, win/game-over UI panels)"
```

---

### Task 11: `TitleRoom` (start menu)

**Files:**
- Create: `examples/platformer/src/source/Rooms/TitleRoom.bs`
- Modify: `examples/platformer/src/source/main.bs`

**Interfaces:**
- Produces: `TitleRoom` (class extending `BGE.Room`) registered in `main.bs`, replacing `MainRoom` as the game's actual first room.

- [ ] **Step 1: Write `TitleRoom.bs`**

```brightscript
class TitleRoom extends BGE.Room

  sub new(game as BGE.Game)
    super(game)
    m.name = "TitleRoom"
  end sub

  override sub onCreate(args as roAssociativeArray)
    m.game.gameUi.clearChildren()

    width = m.game.uiCanvas.getWidth()
    height = m.game.uiCanvas.getHeight()

    title = new BGE.UI.Label(m.game)
    title.customPosition = true
    title.customX = width * 0.35
    title.customY = height * 0.3
    title.setText("Platformer")
    m.game.gameUi.addChild(title)

    hint = new BGE.UI.Label(m.game)
    hint.customPosition = true
    hint.customX = width * 0.32
    hint.customY = height * 0.42
    hint.setText("Move: d-pad/stick   Jump: OK   Pause: Options")
    m.game.gameUi.addChild(hint)

    startButton = new BGE.UI.Button(m.game)
    startButton.setLabel("Start Game")
    startButton.customPosition = true
    startButton.customX = width * 0.4
    startButton.customY = height * 0.55
    startButton.width = width * 0.2
    startButton.height = height * 0.08
    startButton.onActivate = sub(button as BGE.UI.Button)
      button.game.changeRoom("MainRoom")
    end sub
    m.game.gameUi.addChild(startButton)
  end sub

  override sub onInput(input as BGE.GameInput)
    if input.press and input.isButton("back")
      m.game.End()
    end if
  end sub

end class
```

- [ ] **Step 2: Point `main.bs` at `TitleRoom` for real, and register `MainRoom`**

```brightscript
sub Main()
  game = new BGE.Game(1280, 720)
  game.fitCanvasToScreen()
  game.enableControllerInput()

  game.controls.bindAxis("move", "1", 0, "Move")
  game.controls.bindAction("jump", "OK", "a", 0, "Jump")
  game.controls.bindAction("pause", "options", "start", 0, "Pause")

  game.loadBitmap("player", "pkg:/sprites/player.png")
  game.loadBitmap("ground", "pkg:/sprites/ground.png")
  game.loadBitmap("sky", "pkg:/sprites/sky.png")
  game.loadSound("jump", "pkg:/sounds/jump.wav")
  game.loadSound("coin", "pkg:/sounds/coin.wav")
  game.loadSound("stomp", "pkg:/sounds/stomp.wav")
  game.loadSound("die", "pkg:/sounds/die.wav")

  game.defineRoom(new MainRoom(game))

  titleRoom = new TitleRoom(game)
  game.defineRoom(titleRoom)
  game.changeRoom(titleRoom.name)

  game.enableStandardDebugUi({memory: false, garbageCollector: false, log: false})

  game.play()
end sub
```

- [ ] **Step 3: Verify**

Run: `npm run build` (root + example) — expect clean.

Sideload via `rokubot-examples`: expect the title screen on launch with a "Start Game" button already focused (default list-mode seeding). Press OK — expect `MainRoom` to load and gameplay to begin normally. Press Back on the title screen — expect the channel to exit cleanly (`Game.End()`).

- [ ] **Step 4: Commit**

```bash
git add examples/platformer
git commit -m "examples/platformer: TitleRoom (start menu)"
```

---

### Task 12: Pause menu

**Files:**
- Create: `examples/platformer/src/source/Entities/PauseMenu.bs`
- Modify: `examples/platformer/src/source/Rooms/MainRoom.bs`

**Interfaces:**
- Consumes: `Game.pause()`/`Game.resume()`/`Game.isPaused()` (existing engine API — confirmed `processUiInput()` runs every frame regardless of `m.paused`, so `gameUi` stays interactive while gameplay is frozen).

- [ ] **Step 1: Write `PauseMenu.bs`**

```brightscript
' A persistent, non-pauseable entity that toggles a BGE.UI pause panel in
' step with Game.pause()/resume() - following the same "own persistent
' entity for a meta/housekeeping concern" pattern as examples/breakout's
' PauseHandler, but with a real UI panel instead of a drawText overlay.
class PauseMenu extends BGE.GameEntity

  panel as BGE.UI.UiContainer
  isOpen = false

  sub new(game as BGE.Game)
    super(game)
    m.name = "PauseMenu"
    m.persistent = true
    m.pauseable = false
  end sub

  override sub onCreate(args as roAssociativeArray)
    width = m.game.uiCanvas.getWidth()
    height = m.game.uiCanvas.getHeight()

    m.panel = new BGE.UI.UiContainer(m.game)
    m.panel.customPosition = true
    m.panel.customX = width * 0.35
    m.panel.customY = height * 0.3

    title = new BGE.UI.Label(m.game)
    title.customPosition = true
    title.customX = 0
    title.customY = 0
    title.setText("Paused")
    m.panel.addChild(title)

    resumeButton = new BGE.UI.Button(m.game)
    resumeButton.setLabel("Resume")
    resumeButton.customPosition = true
    resumeButton.customX = 0
    resumeButton.customY = 50
    resumeButton.width = width * 0.2
    resumeButton.height = height * 0.07
    resumeButton.onActivate = sub(button as BGE.UI.Button)
      pauseMenu = button.game.getEntityByName("PauseMenu") as PauseMenu
      pauseMenu.close()
    end sub
    m.panel.addChild(resumeButton)

    restartButton = new BGE.UI.Button(m.game)
    restartButton.setLabel("Restart Level")
    restartButton.customPosition = true
    restartButton.customX = 0
    restartButton.customY = 50 + height * 0.09
    restartButton.width = width * 0.2
    restartButton.height = height * 0.07
    restartButton.onActivate = sub(button as BGE.UI.Button)
      button.game.resume()
      button.game.resetRoom()
    end sub
    m.panel.addChild(restartButton)

    quitButton = new BGE.UI.Button(m.game)
    quitButton.setLabel("Quit to Title")
    quitButton.customPosition = true
    quitButton.customX = 0
    quitButton.customY = 50 + height * 0.18
    quitButton.width = width * 0.2
    quitButton.height = height * 0.07
    quitButton.onActivate = sub(button as BGE.UI.Button)
      button.game.resume()
      button.game.changeRoom("TitleRoom")
    end sub
    m.panel.addChild(quitButton)
  end sub

  override sub onControls(controls as BGE.Controller.ControlMap)
    if controls.isActionPressed("pause")
      if m.isOpen
        m.close()
      else
        m.open()
      end if
    end if
  end sub

  sub open()
    m.isOpen = true
    m.game.gameUi.addChild(m.panel)
    m.game.pause()
  end sub

  sub close()
    m.isOpen = false
    m.game.gameUi.removeChild(m.panel)
    m.game.resume()
  end sub

end class
```

- [ ] **Step 2: Add `PauseMenu` to `MainRoom`**

Add `import "../Entities/PauseMenu.bs"`. Add to `onCreate`:

```brightscript
    m.game.addEntity(new PauseMenu(m.game))
```

- [ ] **Step 3: Verify**

Run: `npm run build` (root + example) — expect clean.

Sideload via `rokubot-examples`: mid-level, press the pause action (Options on the remote) — expect the pause panel to appear and gameplay (player/enemy movement) to visibly freeze in subsequent screenshots. Press OK on Resume — expect gameplay to continue. Reopen and press Restart Level — expect the level to fully reset with the panel closed. Reopen and press Quit to Title — expect `TitleRoom` to load.

- [ ] **Step 4: Commit**

```bash
git add examples/platformer
git commit -m "examples/platformer: pause menu (BGE.UI panel + Game.pause()/resume())"
```

---

### Task 13: Documentation

**Files:**
- Modify: `README.md`
- Modify: `docs/game-engine-overview.md`

**Interfaces:** none (docs only).

- [ ] **Step 1: Add `examples/platformer` to `README.md`'s example table/screenshot gallery**

Follow the existing table row format for the other examples (check the table's exact columns — name, description, screenshot — before adding; match column order and any screenshot-image convention already used there). Describe it as: "A side-scrolling platformer demonstrating gravity, jumping, and collision *resolution* built on top of the engine's detection-only collider system."

- [ ] **Step 2: Add it to `docs/game-engine-overview.md`'s sample-channel list (around line 19) and reference it from the collision section**

Add one line to the sample-channel list matching the existing entries' format. In the collision-handling section of that guide, add a short paragraph noting `examples/platformer` as the first example that resolves collisions (depenetration, grounded state, one-way platforms) rather than just detecting them, with a pointer to `examples/platformer/src/source/Entities/Player.bs`'s `onCollision` as the concrete pattern to read.

- [ ] **Step 3: Verify**

Run: `npm run docs` — expect it to build without errors (confirms no broken markdown/frontmatter).

- [ ] **Step 4: Commit**

```bash
git add README.md docs/game-engine-overview.md
git commit -m "docs: add examples/platformer to README and engine overview guide"
```

---

### Task 14: Full-playthrough smoke test and handoff

**Files:** none (verification only).

- [ ] **Step 1: Run the full quality gate**

Run: `npm run check` (lint + validate + headless tests) and `npm run validate-examples` (validates every example, including this one) from the repo root — expect both clean.

- [ ] **Step 2: Scripted end-to-end smoke test via `rokubot-examples`**

Sideload and launch `examples/platformer`. Drive through, screenshotting at each stage: title screen → Start → collect at least one coin → jump the gap → stomp the enemy → take a hit from the enemy (confirm respawn) → pause and resume → reach the goal (confirm win panel) → Retry from the win panel (confirm the level resets). Confirm no crash and no black-screen frames at any step (a black screenshot usually means CPU overload, not a rendering bug — check FPS via the debug UI first if one appears).

- [ ] **Step 3: Hand off for a human playtest**

Per this repo's own convention (`rokubot` act→screenshot latency is too slow to judge real-time feel), tell the user the scripted smoke test passed and ask them to actually play it — specifically for jump arc feel, coyote time, whether one-way platforms feel right, and squash/stretch timing — since none of that can be assessed from screenshots alone.

- [ ] **Step 4: Final commit (if any smoke-test fixes were needed)**

```bash
git add -A
git commit -m "examples/platformer: fixes from full-playthrough smoke test"
```

If nothing needed fixing, skip this commit — the branch is ready for the user's playtest and, after that, a PR.

---

## Self-Review Notes

- **Spec coverage:** every scope bullet in `specs/2026-09-05-platformer-example-design.md` maps to a task — level data/Level entity (2), player run/jump/gravity/coyote/buffer (3), collision resolution (4), camera (5), squash/stretch + particles (6), coins (7), enemy (8), goal (9), HUD/win/game-over (10), input/analog (1, 3), title/pause menus (11, 12), docs (13), verification (14).
- **Two APIs this plan wasn't 100% sure of were checked against the real source before finalizing:** `TweenManager.to()`'s `options.delay` (confirmed real, `TweenManager.bs:90-96`) and `UiContainer.getChildByName()` (confirmed it does *not* exist — `GameStateManager` uses a direct `endMessageLabel` field reference instead, no by-name lookup needed).
- **Type/name consistency checked:** `Player.grounded`/`.positionBeforeMove`/`.spawnPosition`/`.respawn()` (Task 3) are used as-named in Tasks 4, 6, 8, 10; `Level`'s tile naming/tagging (Task 2) is read the same way in Task 4; `Enemy.stomp()` (Task 8) matches its call site in `Player.onCollision`; `GameStateManager`'s event name strings (`"coinCollected"`, `"enemyStomped"`, `"playerHurt"`, `"levelComplete"`) match exactly what `Coin`/`Enemy`/`Player`/`Goal` post.
