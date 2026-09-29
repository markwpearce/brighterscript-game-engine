# Platformer Boss Level Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add level 7 to `examples/platformer`: a one-screen arena with a pixelated Venus fly trap boss that pops up and down, fires aimed fireballs in three phases, dies after three head stomps, and resets to full health if the player dies.

**Architecture:** Everything is example code under `examples/platformer/src/`. Level 7 is one more row array in `LevelData.bs`, with a new `B` marker that `MainScene` spawns as a `PlantBoss` entity. `PlantBoss` is a state machine (`rising`/`up`/`hurt`/`sinking`/`hidden`/`dying`) that spawns `Fireball` entities. The plant sinks by moving its sprite drawable's offset down behind the floor tiles, which draw in front because of z ordering under `Camera2d`. `Player.onCollision()` gets two new branches, for the boss and for fireballs.

**Tech Stack:** BrighterScript, the BGE engine (from `../../src` via the example's `bsconfig.json`), ImageMagick 7 (`magick`) for the one-off sprite processing, and rokubot plus the Roku simulator for verification.

**Spec:** `specs/2026-09-29-platformer-boss-level-design.md`

## Global Constraints

- Branch: `platformer_boss`. Never commit to or push `main`.
- End every commit message with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- No engine changes under `src/`. Everything goes under `examples/platformer/`.
- Canvas is 640x360. `TileSize = 64`, `NumRows = 11`. The floor tile top is at world y = 128 and the one-way platform top at y = 256. World +y is up.
- Boss health is 3. Phase = `4 - health`. The phase table: phase 1 fires 1 shot every 2.5s at 220 px/s; phase 2 fires a 3-shot fan (±18°) every 2.5s at 220 px/s; phase 3 fires a 3-shot fan (±18°) every 1.6s at 300 px/s.
- Timings: rise 0.5s. Up for 6s without a hit, then sink. Telegraph 0.3s. Hurt sink 0.6s. Hidden 1.5s. Dying sink 1.5s. Red flash toggles every 0.08s.
- Player death (`playerHurt` event) resets the boss to full health and destroys every `Fireball`.
- `Drawable.color` is packed **RGB** (`&hFF4040`), not RGBA.
- Guard one-shot input with `input.press`. Never compare two class instances with `=`.
- Assign `new X(m.game)` to a local variable before passing it to `addEntity()` (see the inline-`new` bug memory).
- Rotation is in radians. BrightScript has no `atan2`, so use the helper in Task 3.
- Before running rokubot, read the `rokubot-examples` skill (`.claude/skills/rokubot-examples/SKILL.md`). The user asked for the simulator: run `node node_modules/rokubot/dist/cli.js` with `--host 127.0.0.1 --password rokudev`.
- Don't play the fight in real time via rokubot. Screenshot static states only, and have the user play it.
- Keep code comments concise (1-3 lines, only the "why").

## Review Focus

1. **Stomp and hurt in the same frame.** A player landing on the head must never also take damage from the stem that frame. The head and stem hitboxes don't overlap vertically (stem y 0..52, head y 52..160). Task 4 Step 6 checks this with the collider overlay.
2. **Player dies while the boss is mid-hurt or dying.** A leftover fireball kills the player after the 3rd stomp. The win must still happen and the boss must not come back. `onGameEvent` ignores `playerHurt` once the state is `dying`, and every fireball is destroyed as soon as dying starts (Task 4).
3. **Player directly above the root.** Facing must not flicker every frame. A 16px dead zone handles this (Task 2), and Task 2 Step 6 checks it with a screenshot.
4. **Fireball leaving the arena at the top.** A shot aimed upward at a player on a platform must still be destroyed off-screen, not live forever. The bounds check covers all four sides (Task 3).
5. **Game over, then Retry.** The scene resets, so the boss is back at full health with no stale fireballs. Task 5's user playtest checklist covers this.

---

### Task 1: Pixelated boss and fireball assets, loaded by the game

**Files:**
- Create: `examples/platformer/src/sprites/plant_boss.png`, `examples/platformer/src/sprites/fireball.png`
- Modify: `examples/platformer/src/sprites/CREDITS.md`, `examples/platformer/src/source/main.bs:27-44`
- Add to git: `examples/platformer/src/sounds/fire.wav` (already on disk, untracked)

**Interfaces:**
- Produces: bitmaps `"plantBoss"` (146x186 cells, 10 columns x 4 rows, 37 frames, every frame faces right, roots at the cell's bottom edge) and `"fireball"` (32x32 cells, 2 frames, faces right). Sound `"fire"`.

- [ ] **Step 1: Build the pixelated sheet** (run from the repo root, scratch files in the session scratchpad)

```bash
SRC=/Users/mpearce/Downloads/Man_eating_plant_animation_sprites/sprites_file
TMP=/private/tmp/claude-502/-Users-mpearce-redspace-roku-brighterscript-game-engine/eb3ef6ed-ff9f-46f8-8771-415bf0e1ec2a/scratchpad/boss
mkdir -p $TMP/small $TMP/big
# 1. box-downscale each 136x173 frame to 73x93 and harden alpha
for f in $SRC/e_0*.png; do
  magick "$f" -filter box -resize 73x93! -channel A -threshold 50% +channel "$TMP/small/$(basename $f)"
done
# 2. one palette shared by all frames so colors don't shimmer frame to frame
magick $TMP/small/e_0*.png +append -alpha off -dither None -colors 24 -unique-colors $TMP/palette.png
# 3. remap each frame to that palette, then 2x nearest-neighbour (2px chunks)
for f in $TMP/small/e_0*.png; do
  magick "$f" -dither None -remap $TMP/palette.png -filter point -resize 200% "$TMP/big/$(basename $f)"
done
# 4. pack into a 10-column grid of 146x186 cells, transparent background
magick montage $TMP/big/e_0*.png -tile 10x -geometry 146x186+0+0 -background none examples/platformer/src/sprites/plant_boss.png
cp /Users/mpearce/Downloads/orange_fireball.png examples/platformer/src/sprites/fireball.png
magick identify examples/platformer/src/sprites/plant_boss.png
```

Expected: `plant_boss.png PNG 1460x744`. If `montage` fails with `unable to read font` (as it did during brainstorming), replace step 4 with 4 `+append` rows (10 frames each, the last row 7) joined by `-append`, with `-background none`.

- [ ] **Step 2: Check the sheet visually.** Open `plant_boss.png` with the Read tool. Expect 37 chunky plants with no stray opaque background pixels and colors that stay consistent across frames. If the remap left transparent pixels opaque, add `-channel A -threshold 50% +channel` after `-remap` in step 3 and rebuild.

- [ ] **Step 3: Load the assets in `main.bs`.** After `game.loadBitmap("goal", ...)`, add:

```brighterscript
  game.loadBitmap("plantBoss", "pkg:/sprites/plant_boss.png")
  game.loadBitmap("fireball", "pkg:/sprites/fireball.png")
```

After `game.loadSound("flag", ...)`, add:

```brighterscript
  game.loadSound("fire", "pkg:/sounds/fire.wav")
```

- [ ] **Step 4: Credits.** Append to `examples/platformer/src/sprites/CREDITS.md`:

```markdown
- `plant_boss.png` — the level 7 boss, built from the 37-frame
  [Man Eating Plant Animation Sprites](https://opengameart.org/content/man-eating-plant-animation-sprites-for-game-developers)
  by [bevouliin.com](http://bevouliin.com). Pixelated: each frame box-downscaled
  to 73x93, alpha thresholded, remapped to one shared 24-color palette, then 2x
  nearest-neighbour upscaled and packed 10 columns wide in 146x186 cells (the
  ImageMagick steps are in `specs/2026-09-29-platformer-boss-level-plan.md`, Task 1).
- `fireball.png` — [Fireball](https://opengameart.org/content/fireball-3) from
  OpenGameArt, used as-is (2 frames, 32x32).
- `../sounds/fire.wav` — [Fire Evil Spell](https://opengameart.org/content/fire-evil-spell)
  from OpenGameArt.
```

Check each OpenGameArt page's license (WebFetch) and add it to that entry (CC0, CC-BY, and so on). If a page says CC-BY, include the author's name as that page gives it.

- [ ] **Step 5: Validate.** Run `cd examples/platformer && npx bsc --validate --create-package=false`. Expected: 0 errors.

- [ ] **Step 6: Commit**

```bash
git add examples/platformer/src/sprites/plant_boss.png examples/platformer/src/sprites/fireball.png examples/platformer/src/sounds/fire.wav examples/platformer/src/sprites/CREDITS.md examples/platformer/src/source/main.bs
git commit -m "platformer: add pixelated plant boss, fireball and fire sound assets"
```

---

### Task 2: Level 7 arena and a static, player-facing `PlantBoss` (draw-order and tint spike)

This task settles the spec's two risks (draw order and sprite tint) on the simulator before any gameplay depends on them.

**Files:**
- Modify: `examples/platformer/src/source/LevelData.bs` (legend comment, new `getLevel7Rows()`, `getAllLevels()`)
- Create: `examples/platformer/src/source/Entities/PlantBoss.bs`
- Modify: `examples/platformer/src/source/Scenes/MainScene.bs` (import, `B` spawn, background z)

**Interfaces:**
- Consumes: bitmap `"plantBoss"` (Task 1).
- Produces: class `PlantBoss extends BGE.GameEntity`, `m.name = "PlantBoss"`, with fields `sprite as BGE.Sprite`, `head as BGE.RectangleCollider`, `stem as BGE.RectangleCollider`, `facingRight as boolean`, and methods `getHeadTop() as float` (world y of the head collider's top edge), `getMouthPosition() as BGE.Math.Vector` (world point fireballs spawn from), `setSinkDepth(depth as float)` (0 = fully up, 190 = fully under). Its `position` is the root point on the floor top.

- [ ] **Step 1: Level 7 rows.** Add `'   B  boss spawn (rooted on the ground tile below)` to the legend in the header comment. Add this function after `getLevel6Rows()`:

```brighterscript
' The final level: a one-screen boss arena (10 columns = exactly one 640px camera
' frame, so the camera never scrolls), a one-way platform on each side.
function getLevel7Rows() as string[]
  return [
    "..........",
    "..........",
    "..........",
    "..........",
    "..........",
    "..........",
    "..........",
    "---....---",
    ".P...B....",
    "##########",
    "##########",
    "##########",
    "##########",
    "##########",
    "##########"
  ]
end function
```

Then add `getLevel7Rows()` as the last entry of `getAllLevels()`. The `B` in column 5 puts the root at x = 352, just right of center. That's fine because the art's mass sits to the right of its root.

- [ ] **Step 2: Put the background layers behind everything.** In `MainScene.onCreate()`, after the three `m.addDrawable("bg...", ...)` calls, add:

```brighterscript
    ' Pushed back so the boss (z = -1) can sit between the backgrounds and the
    ' level's floor tiles (z = 0) and sink out of sight behind the floor.
    for each bgName in ["bgBack", "bgFar", "bgMiddle"]
      m.getDrawable(bgName).offset.z = -10
    end for
```

(Check that `GameEntity.getDrawable(name)` exists with `grep -n "function getDrawable" src/source/engine/GameEntity.bs`. If it doesn't, keep the three `newBackgroundLayer()` return values in local variables and set `.offset.z` on each.)

- [ ] **Step 3: Minimal `PlantBoss`.** Create `examples/platformer/src/source/Entities/PlantBoss.bs`:

```brighterscript
import "pkg:/source/engine/colliders/RectangleCollider.bs"

' Level 7's boss - a giant Venus fly trap rooted in the floor. position is the root
' point on the floor's top edge. Every sheet frame faces right, so facing left
' mirrors the sprite and the collider offsets around that root.
class PlantBoss extends BGE.GameEntity

  ' Measured on the pixelated sheet (146x186 cells), relative to the root, facing right.
  headOffsetX = -14.0
  headBottom = 52.0
  headWidth = 110.0
  headHeight = 108.0
  stemOffsetX = -26.0
  stemWidth = 38.0
  stemHeight = 52.0
  mouthOffset = BGE.Math.VectorOps.create(84, 90)
  fullSinkDepth = 190.0
  ' Don't flip facing while the player is within this many px of the root, or
  ' standing right above it flips every frame.
  facingDeadZone = 16.0

  sprite as BGE.Sprite
  head as BGE.RectangleCollider
  stem as BGE.RectangleCollider
  facingRight = true
  sinkDepth = 0.0

  sub new(game as BGE.Game)
    super(game)
    m.name = "PlantBoss"
  end sub

  override sub onCreate(args as roAssociativeArray)
    ' Behind the floor tiles (z = 0), in front of the backgrounds (z = -10) - see MainScene.
    m.position.z = -1

    m.sprite = m.addSprite("body", m.game.getBitmap("plantBoss"), 146, 186)
    ' Root: the middle of the rock pile, 45px in from the cell's left edge.
    m.sprite.applyPreTranslation(-45, -186)
    m.sprite.addAnimation("chomp", {startFrame: 0, frameCount: 37}, 18, BGE.SpritePlayMode.Loop)
    m.sprite.playAnimation("chomp")

    m.head = m.addRectangleCollider("head", m.headWidth, m.headHeight, m.headOffsetX, m.headBottom + m.headHeight)
    m.stem = m.addRectangleCollider("stem", m.stemWidth, m.stemHeight, m.stemOffsetX, m.stemHeight)
  end sub

  override sub onUpdate(dt as float)
    m.updateFacing()
  end sub

  ' World y of the head hitbox's top edge - Player's stomp test compares its feet to this.
  function getHeadTop() as float
    return m.position.y + m.headBottom + m.headHeight
  end function

  ' World point fireballs spawn from, mirrored with facing.
  function getMouthPosition() as BGE.Math.Vector
    x = m.mouthOffset.x
    if not m.facingRight
      x = -x
    end if
    return BGE.Math.VectorOps.create(m.position.x + x, m.position.y + m.mouthOffset.y - m.sinkDepth)
  end function

  ' 0 = fully up, fullSinkDepth = fully under the floor.
  sub setSinkDepth(depth as float)
    m.sinkDepth = depth
    m.sprite.offset.y = -depth
  end sub

  private sub updateFacing()
    playerEntity = m.game.getEntityByName("Player")
    if invalid = playerEntity
      return
    end if
    dx = playerEntity.position.x - m.position.x
    if dx > m.facingDeadZone
      m.facingRight = true
    else if dx < -m.facingDeadZone
      m.facingRight = false
    end if
    if m.facingRight
      m.sprite.scale.x = 1.0
      m.head.offset.x = m.headOffsetX
      m.stem.offset.x = m.stemOffsetX
    else
      m.sprite.scale.x = -1.0
      m.head.offset.x = -m.headOffsetX - m.headWidth
      m.stem.offset.x = -m.stemOffsetX - m.stemWidth
    end if
  end sub

end class
```

- [ ] **Step 4: Spawn it.** In `MainScene.bs`, add `import "../Entities/PlantBoss.bs"` with the other imports, and add this branch to the spawn loop's `if/else if` chain:

```brighterscript
        else if row.mid(c, 1) = "B"
          bossEntity = new PlantBoss(m.game)
          m.game.addEntity(bossEntity)
          bossEntity.position.x = c * TileSize + TileSize / 2.0
          ' Rooted on the ground tile's top edge, like Enemy/Goal.
          bossEntity.position.y = (NumRows - r - 1) * TileSize
```

- [ ] **Step 5: Validate.** Run `cd examples/platformer && npx bsc --validate --create-package=false`. Expected: 0 errors.

- [ ] **Step 6: Spike on the simulator.** Build and sideload (`npm run build` in `examples/platformer`, then rokubot sideload `out/bge-platformer.zip`), and launch with `--param level=7`. Screenshot and check:
  1. The plant stands on the floor at about half the screen's height, in front of the jungle background, facing the player (on the left, so the plant faces left).
  2. **Draw order:** temporarily set `setSinkDepth(95)` at the end of `onCreate()`. Rebuild and screenshot. The lower half must be hidden by the floor while the upper half still shows over the background. If the background now covers the plant, or the floor doesn't cover it, stop and report to the user. Fallback: spawn the boss before `Level` in `MainScene` and keep every z at 0, relying on insertion-order tie-breaks.
  3. **Tint:** temporarily set `m.sprite.color = &hFF4040` in `onCreate()`. Rebuild and screenshot. The plant must read clearly red. If it doesn't, stop and report.
  4. Press `info` (the debug overlay, which draws colliders). The head box covers the cap and jaws, the stem box covers the stalk and rocks, and they don't overlap vertically. Walk the player (hold `right` about 0.8s) past the root and screenshot: the plant and both boxes are mirrored.
  Remove the temporary `setSinkDepth(95)` and `color` lines afterwards. If a box looks misaligned, adjust the constants at the top of the class and write down why in one comment line.

- [ ] **Step 7: Commit**

```bash
git add examples/platformer/src/source/LevelData.bs examples/platformer/src/source/Entities/PlantBoss.bs examples/platformer/src/source/Scenes/MainScene.bs
git commit -m "platformer: add level 7 boss arena with a player-facing plant boss"
```

---

### Task 3: `Fireball` entity and player damage

**Files:**
- Create: `examples/platformer/src/source/Entities/Fireball.bs`
- Modify: `examples/platformer/src/source/Entities/Player.bs` (import and `onCollision()`)

**Interfaces:**
- Consumes: bitmap `"fireball"`, `Player.takeDamage()`, `Player.invulnerableTimer`.
- Produces: class `Fireball extends BGE.GameEntity`, `m.name = "Fireball"`, with `launch(from as BGE.Math.Vector, direction as BGE.Math.Vector, speed as float)` (direction need not be normalized) and the free function `fireballAtan2(y as float, x as float) as float`.

- [ ] **Step 1: Create `Fireball.bs`**

```brighterscript
import "pkg:/source/engine/colliders/CircleCollider.bs"

' A straight-flying boss projectile. Destroyed on a solid tile or once it leaves the
' arena. Passes through one-way platforms so they aren't a perfect shield.
class Fireball extends BGE.GameEntity

  radius = 9.0
  ' Arena bounds plus a margin, in world units.
  minX = -32.0
  maxX = 672.0
  minY = -32.0
  maxY = 392.0

  sub new(game as BGE.Game)
    super(game)
    m.name = "Fireball"
  end sub

  override sub onCreate(args as roAssociativeArray)
    sprite = m.addSprite("body", m.game.getBitmap("fireball"), 32, 32)
    sprite.applyPreTranslation(-16, -16)
    sprite.addAnimation("burn", {startFrame: 0, frameCount: 2}, 10, BGE.SpritePlayMode.Loop)
    sprite.playAnimation("burn")
    ' The art's bright core sits right of center; the hitbox is smaller than the sprite.
    m.addCircleCollider("fireball", m.radius, 4, 0)
  end sub

  sub launch(from as BGE.Math.Vector, direction as BGE.Math.Vector, speed as float)
    m.position = BGE.Math.VectorOps.create(from.x, from.y)
    length = BGE.Math.VectorOps.length(direction)
    if length < 0.001
      direction = BGE.Math.VectorOps.create(1, 0)
      length = 1.0
    end if
    m.velocity = BGE.Math.VectorOps.create(direction.x / length * speed, direction.y / length * speed)
    ' The art points right (+x) - rotate it to face the direction of travel.
    m.rotation.z = fireballAtan2(m.velocity.y, m.velocity.x)
  end sub

  override sub onUpdate(dt as float)
    if m.position.x < m.minX or m.position.x > m.maxX or m.position.y < m.minY or m.position.y > m.maxY
      m.invalidate()
    end if
  end sub

  override sub onCollision(myCollider as BGE.Collider, otherCollider as BGE.Collider, otherEntity as BGE.GameEntity)
    if otherEntity.name = "Level" and otherCollider.tagsList.hasTag("solid")
      m.invalidate()
    end if
  end sub

end class

' BrightScript has no atan2 - this is the standard quadrant-corrected atn().
function fireballAtan2(y as float, x as float) as float
  if x > 0
    return atn(y / x)
  else if x < 0 and y >= 0
    return atn(y / x) + BGE.Math.PI
  else if x < 0
    return atn(y / x) - BGE.Math.PI
  else if y > 0
    return BGE.Math.PI / 2
  else if y < 0
    return -BGE.Math.PI / 2
  end if
  return 0.0
end function
```

(Check the `addCircleCollider` offset sign and the rotation direction on screen in Step 5: a fireball flying up-left must point up-left. If it points the mirror way, negate the angle in `launch()`.)

- [ ] **Step 2: Player takes fireball damage.** In `Player.bs`, add `import "Fireball.bs"` and add this as the first branch of `onCollision()`, above the `Enemy` branch:

```brighterscript
    if otherEntity.name = "Fireball"
      if not m.invulnerableTimer.isActive()
        otherEntity.invalidate()
        m.takeDamage()
      end if
      return
    end if
```

- [ ] **Step 3: Temporary test fire.** In `PlantBoss.onUpdate()`, temporarily add a 2-second timer that launches one fireball from `m.getMouthPosition()` at the player's center (`playerEntity.position` + `(0, 27)`) at 220 px/s:

```brighterscript
    ' TEMP (Task 3 check) - removed in Task 4
    m.tempFireTimer.tick(dt)
    if not m.tempFireTimer.isActive()
      m.tempFireTimer.start(2.0)
      playerEntity = m.game.getEntityByName("Player")
      if invalid <> playerEntity
        from = m.getMouthPosition()
        fireballEntity = new Fireball(m.game)
        m.game.addEntity(fireballEntity)
        fireballEntity.launch(from, BGE.Math.VectorOps.create(playerEntity.position.x - from.x, playerEntity.position.y + 27 - from.y), 220)
      end if
    end if
```

Also add the field `tempFireTimer = new BGE.CountdownTimer()` and `import "Fireball.bs"` in `PlantBoss.bs`.

- [ ] **Step 4: Validate.** Run `cd examples/platformer && npx bsc --validate --create-package=false`. Expected: 0 errors.

- [ ] **Step 5: Simulator check.** Build, sideload and launch with `level=7`. Stand still at spawn and take screenshots about 1 second apart. Expect: fireballs leave the mouth, point toward the player, and fly toward them. When one hits, the player plays the death animation and a life drops (the HUD "Lives" count). Jump onto the left platform (`press select`) and screenshot: a fireball aimed upward still flies and leaves the screen (read the debug overlay's entity count if you can, and check it doesn't grow).

- [ ] **Step 6: Commit** (the temp fire code stays in until Task 4 replaces it)

```bash
git add examples/platformer/src/source/Entities/Fireball.bs examples/platformer/src/source/Entities/Player.bs examples/platformer/src/source/Entities/PlantBoss.bs
git commit -m "platformer: add fireball projectile that damages the player"
```

---

### Task 4: Boss state machine: phases, volleys, stomps, flash/shake, death and reset

**Files:**
- Modify: `examples/platformer/src/source/Entities/PlantBoss.bs` (replace the temp fire code, add the state machine)
- Modify: `examples/platformer/src/source/Entities/Player.bs` (`PlantBoss` branch in `onCollision()`)

**Interfaces:**
- Consumes: `Fireball.launch()`, `PlantBoss.getHeadTop()`/`getMouthPosition()`/`setSinkDepth()` (Task 2), sounds `"fire"`/`"stomp"`/`"monsterDie"`, game events `"playerHurt"` (listened for) and `"levelComplete"`/`"enemyStomped"` (posted).
- Produces: `PlantBoss.stomp() as boolean` (true if the stomp counted, i.e. the boss was `up`) and `PlantBoss.state as string`.

- [ ] **Step 1: Replace the fields and `onUpdate()`.** Remove `tempFireTimer` and the temporary block. Add these fields to `PlantBoss`:

```brighterscript
  maxHealth = 3
  health = 3
  ' rising | up | hurt | sinking | hidden | dying | dead
  state = "hidden"
  stateTimer = new BGE.CountdownTimer()
  volleyTimer = new BGE.CountdownTimer()
  telegraphTimer = new BGE.CountdownTimer()
  telegraphing = false
  flashTimer = new BGE.CountdownTimer()
  flashRed = false

  riseTime = 0.5
  upTime = 6.0
  telegraphTime = 0.3
  hurtSinkTime = 0.6
  sinkTime = 0.6
  hiddenTime = 1.5
  dyingSinkTime = 1.5
  flashInterval = 0.08
  shakeAmount = 3.0
  fanSpreadRadians = 18.0 * BGE.Math.PI / 180.0
  ' Aim at the player's middle, not their feet.
  playerAimHeight = 27.0
```

At the end of `onCreate()`, start fully sunk so the fight opens with it rising after a beat:

```brighterscript
    m.enterHidden()
```

Replace `onUpdate()`:

```brighterscript
  override sub onUpdate(dt as float)
    ' Same first-frame hitch clamp as Player - keeps timers/sinking from jumping.
    if dt > 1 / 30.0
      dt = 1 / 30.0
    end if
    m.updateFacing()
    m.stateTimer.tick(dt)

    if m.state = "rising"
      m.setSinkDepth(m.fullSinkDepth * m.stateRemainingFraction(m.riseTime))
      if not m.stateTimer.isActive()
        m.enterUp()
      end if
    else if m.state = "up"
      m.updateVolleys(dt)
      if not m.stateTimer.isActive()
        m.enterSink("sinking", m.sinkTime)
      end if
    else if m.state = "hurt" or m.state = "sinking" or m.state = "dying"
      m.setSinkDepth(m.fullSinkDepth * (1.0 - m.stateRemainingFraction(m.stateDuration)))
      if m.state <> "sinking"
        m.updateFlashAndShake(dt)
      end if
      if not m.stateTimer.isActive()
        if m.state = "dying"
          m.state = "dead"
          m.game.postGameEvent("levelComplete", {})
        else
          m.enterHidden()
        end if
      end if
    else if m.state = "hidden"
      if not m.stateTimer.isActive()
        m.enterRising()
      end if
    end if
  end sub
```

- [ ] **Step 2: State transitions.** Add the field `stateDuration = 0.0` and these methods:

```brighterscript
  private sub enterRising()
    m.state = "rising"
    m.startState(m.riseTime)
  end sub

  private sub enterUp()
    m.state = "up"
    m.setSinkDepth(0)
    m.setCollidersEnabled(true)
    m.startState(m.upTime)
    m.telegraphing = false
    m.volleyTimer.start(m.getVolleyInterval())
  end sub

  ' kind: "hurt" | "sinking" | "dying"
  private sub enterSink(kind as string, duration as float)
    m.state = kind
    m.setCollidersEnabled(false)
    m.telegraphing = false
    m.scale.x = 1.0
    m.scale.y = 1.0
    m.startState(duration)
    m.flashRed = true
    m.flashTimer.start(m.flashInterval)
  end sub

  private sub enterHidden()
    m.state = "hidden"
    m.setSinkDepth(m.fullSinkDepth)
    m.setCollidersEnabled(false)
    m.sprite.color = &hFFFFFF
    m.sprite.offset.x = 0
    m.startState(m.hiddenTime)
  end sub

  private sub startState(duration as float)
    m.stateDuration = duration
    m.stateTimer.start(duration)
  end sub

  ' 1.0 at the start of the current state, 0.0 once its timer runs out.
  private function stateRemainingFraction(duration as float) as float
    if duration <= 0
      return 0.0
    end if
    return m.stateTimer.remaining() / duration
  end function

  private sub setCollidersEnabled(enabled as boolean)
    m.head.enabled = enabled
    m.stem.enabled = enabled
  end sub

  private sub updateFlashAndShake(dt as float)
    m.flashTimer.tick(dt)
    if not m.flashTimer.isActive()
      m.flashRed = not m.flashRed
      m.flashTimer.start(m.flashInterval)
    end if
    if m.flashRed
      m.sprite.color = &hFF4040
    else
      m.sprite.color = &hFFFFFF
    end if
    m.sprite.offset.x = (rnd(0) * 2.0 - 1.0) * m.shakeAmount
  end sub
```

- [ ] **Step 3: Phases and volleys.**

```brighterscript
  private function getPhase() as integer
    return m.maxHealth + 1 - m.health
  end function

  private function getVolleyInterval() as float
    if m.getPhase() >= 3
      return 1.6
    end if
    return 2.5
  end function

  private function getFireballSpeed() as float
    if m.getPhase() >= 3
      return 300.0
    end if
    return 220.0
  end function

  ' A short swell before each volley is the "about to fire" tell - the art has no attack frames.
  private sub updateVolleys(dt as float)
    if m.telegraphing
      m.telegraphTimer.tick(dt)
      if not m.telegraphTimer.isActive()
        m.telegraphing = false
        m.fireVolley()
        m.volleyTimer.start(m.getVolleyInterval())
      end if
      return
    end if
    m.volleyTimer.tick(dt)
    if not m.volleyTimer.isActive()
      m.telegraphing = true
      m.telegraphTimer.start(m.telegraphTime)
      halfMs = cint(m.telegraphTime * 500)
      m.game.tweenManager.to(m.scale, {x: 1.08, y: 1.08}, halfMs, BGE.Tweens.Easing.QuadraticEaseOut)
      m.game.tweenManager.to(m.scale, {x: 1.0, y: 1.0}, halfMs, BGE.Tweens.Easing.QuadraticEaseIn, {delay: halfMs})
    end if
  end sub

  private sub fireVolley()
    playerEntity = m.game.getEntityByName("Player")
    if invalid = playerEntity
      return
    end if
    from = m.getMouthPosition()
    aim = BGE.Math.VectorOps.create(playerEntity.position.x - from.x, playerEntity.position.y + m.playerAimHeight - from.y)
    m.spawnFireball(from, aim, 0.0)
    if m.getPhase() >= 2
      m.spawnFireball(from, aim, m.fanSpreadRadians)
      m.spawnFireball(from, aim, -m.fanSpreadRadians)
    end if
    m.game.playSound("fire")
  end sub

  private sub spawnFireball(from as BGE.Math.Vector, aim as BGE.Math.Vector, angleOffset as float)
    c = cos(angleOffset)
    s = sin(angleOffset)
    direction = BGE.Math.VectorOps.create(aim.x * c - aim.y * s, aim.x * s + aim.y * c)
    fireballEntity = new Fireball(m.game)
    m.game.addEntity(fireballEntity)
    fireballEntity.launch(from, direction, m.getFireballSpeed())
  end sub
```

(The tweens can outlive the telegraph if the boss is hurt mid-swell. `enterSink()` resets `m.scale`, but a pending second tween could still write to it. If the plant visibly pulses while sinking, store both tween handles and `m.game.tweenManager.cancel()` them in `enterSink()`.)

- [ ] **Step 4: Stomp, death and reset.**

```brighterscript
  ' Called by Player on a head stomp. Returns true if it counted (only while fully up).
  function stomp() as boolean
    if m.state <> "up"
      return false
    end if
    m.health -= 1
    m.game.playSound("stomp")
    m.game.postGameEvent("enemyStomped", {})
    if m.health <= 0
      m.game.playSound("monsterDie")
      m.game.destroyAllEntities("Fireball")
      m.enterSink("dying", m.dyingSinkTime)
    else
      m.enterSink("hurt", m.hurtSinkTime)
    end if
    return true
  end function

  override sub onGameEvent(eventName as string, data as roAssociativeArray)
    ' A player death restarts the fight at full health - but never undoes a win.
    if eventName <> "playerHurt" or m.state = "dying" or m.state = "dead"
      return
    end if
    m.health = m.maxHealth
    m.game.destroyAllEntities("Fireball")
    m.scale.x = 1.0
    m.scale.y = 1.0
    if m.state = "hidden"
      m.startState(m.hiddenTime)
    else if m.state <> "sinking" and m.state <> "hurt"
      m.enterSink("sinking", m.sinkTime)
    end if
  end sub
```

(`enemyStomped` gives the existing +25 score per hit.)

- [ ] **Step 5: Player stomps or gets hurt by the boss.** In `Player.bs`, add `import "PlantBoss.bs"` and add this branch after the `Fireball` branch (Task 3) in `onCollision()`:

```brighterscript
    if otherEntity.name = "PlantBoss"
      bossEntity = otherEntity as PlantBoss
      ' Same feet-above-the-top stomp test as the Enemy branch, against the head only.
      if otherCollider.name = "head" and m.velocity.y <= 0.0 and m.positionBeforeMove.y >= bossEntity.getHeadTop() - 4.0
        if bossEntity.stomp()
          m.velocity.y = m.bounceVelocity
        end if
      else if not m.invulnerableTimer.isActive()
        m.game.playSound("monsterEat")
        m.takeDamage()
      end if
      return
    end if
```

`PlantBoss.bs` must **not** import `Player.bs`. It only uses `getEntityByName("Player")` as a plain `BGE.GameEntity`, which keeps the import graph acyclic.

- [ ] **Step 6: Validate and check on the simulator.** Run `cd examples/platformer && npx bsc --validate --create-package=false` (0 errors), then from the repo root run `npm run lint` (0 new issues in `examples/platformer`, if lint covers examples; otherwise skip). Build, sideload and launch with `level=7`. Screenshot the static checks:
  1. At launch the plant is hidden, then about 1.5s later it rises (screenshot at about 1s and about 2.5s).
  2. With the `info` overlay on, the head and stem boxes are visible while up and gone while hidden.
  3. After about 6s up with no hit, it sinks by itself, then rises again.
  Don't try to stomp it via rokubot. That's the user's playtest in Task 5.

- [ ] **Step 7: Commit**

```bash
git add examples/platformer/src/source/Entities/PlantBoss.bs examples/platformer/src/source/Entities/Player.bs
git commit -m "platformer: boss phases, volleys, stomp damage, death and reset on player death"
```

---

### Task 5: Docs, full check and user playtest

**Files:**
- Modify (only if they describe the level list or boss behavior): `CLAUDE.md`, `examples/platformer/README.md` (if it exists), `docs/*.md` mentioning the platformer's levels.

- [ ] **Step 1: Doc sweep.** Run `grep -rn "platformer" CLAUDE.md docs/ examples/platformer/*.md .claude/skills/ 2>/dev/null`. Update anything that states the level count (6 → 7) or lists the platformer's entities. Add a line to the `rokubot-examples` skill's platformer gotchas if the boss adds one (for example, "`--param level=7` jumps straight to the boss").

- [ ] **Step 2: Full gates.** From the repo root, run `npm run check` (expected: PASS, since no engine change) and `npm run validate-examples` (expected: platformer is clean, and the other examples are the same as on `main`).

- [ ] **Step 3: Full-run smoke check.** Launch with `level=6` and screenshot to confirm the HUD reads "Level 6/7". Clearing level 6 isn't automated, so the user covers it in Step 4.

- [ ] **Step 4: Hand off the playtest to the user.** Ask them to play `level=7` on the simulator and report on:
  - 3 stomps kill it, each with a red flash and shake as it sinks. The phase 2 fan and faster phase 3 are noticeable.
  - Landing on the head never hurts. Touching the stem or jaws from the side does.
  - Dying mid-fight resets the boss to full health and clears fireballs.
  - After the 3rd stomp: flash, shake, sink, then the "You Win!" panel.
  - Game over, then Retry, restarts the fight at full health.
  - Clearing level 6's flag leads into the boss level.
  Fix anything they report, then re-run Step 2.

- [ ] **Step 5: Commit** any doc updates and playtest fixes:

```bash
git add -A examples/platformer CLAUDE.md docs .claude/skills
git commit -m "platformer: docs for the level 7 boss fight"
```
