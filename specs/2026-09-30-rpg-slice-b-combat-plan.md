# rpg Slice B: Combat — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Sword combat, rats/bats, health/knockback, coins and a hearts HUD in `examples/rpg`, with `SolidWorld` promoted to `BGE.SolidWorld`.

**Architecture:** `BGE.SolidWorld` is pure rectangle maths in `engine/colliders/`. The example's combat maths lives in a pure `Entities/Combat.bs`; `Enemy` is a `GameEntity` base with `Rat`/`Bat` subclasses; the `Player` gains a swing/knockback/defeat state; `HeartsHud` is a `gameUi` widget reading the persistent player each frame. Overlaps use ordinary compositor colliders filtered by collider name (`feet`, `sword`, `body`, `pickup`).

**Tech Stack:** BrighterScript, Rooibos v6, rokubot.

**Spec:** `specs/2026-09-30-rpg-slice-b-combat-design.md`

## Global Constraints

- One `@suite` class per `*.spec.bs`.
- `bslint`: no single-line `if`; consts are plain literals.
- Any file that uses another file's symbol `import`s it (examples import engine files as `pkg:/source/engine/...`).
- Never compare two objects with `=`; compare ids.
- Discrete input actions are guarded with `input.press`.
- Assign `new X(...)` to a local before passing it to `addEntity`.
- HUD stays ≥10% inside every canvas edge.
- Rectangles are `{x, y, w, h}`, bottom-left corner, world +y up. A `RectangleCollider` for a box whose bottom is `by` relative to the entity uses `offset_y = by + h`.
- Sounds: only `Blip_Select.wav` from the Damaged Panda pack.

## Review Focus

1. The sword collider touching a `Door` would change scene mid-swing. `Door` must only react to the player's `feet` collider.
2. Two contact hits in one frame, or a hit during a fade, must not double-defeat. `takeHit` checks invulnerability and `isTransitioning()`; defeat is latched.
3. Knockback into a wall or corner must never leave a mover inside a solid. It goes through `moveAndSlide` with `cornerNudge: 0` (tested in `SolidWorld.spec.bs`).
4. A knockback source exactly on top of the target must not give NaN. `Combat.knockbackVector` has a fixed fallback (tested).
5. An enemy placed on a solid cell would be stuck, and a coin dropped over water (bats) would be unreachable. `EnemyPlacements.spec.bs` checks every placement is free, and coin drops check `isAreaFree`.

---

### Task 1: `BGE.SolidWorld` in the engine

**Files:** Create `src/source/engine/colliders/SolidWorld.bs` and `SolidWorld.spec.bs`.

**Produces:** `BGE.SlideOptions {optional cornerNudge, optional maxStep}` and `BGE.SlideResult {x, y, blockedX, blockedY}`. `BGE.SolidWorld` with `new(bucketSize = 128)`, `addSolid(x, y, w, h)`, `addBounds(x, y, w, h, thickness = 64)`, `getSolidCount()`, `isAreaFree(x, y, w, h) as boolean` (touching edges count as free), and `moveAndSlide(mover, dx, dy, options = {}) as BGE.SlideResult`.

- [ ] Port the example's class verbatim into the `BGE` namespace. Replace `SOLID_MAX_STEP`/`SOLID_CORNER_NUDGE` with option reads (`DoesExist`) defaulting to 4/8, and `SOLID_BUCKET_SIZE` with a constructor field. Nudging only happens when `cornerNudge > 0` and the move is single-axis.
- [ ] Port all 13 example tests to `BGE.SolidWorld`. Add tests for:
  - `cornerNudge: 0` disables the 2px nudge (y stays 0, x = 10).
  - `cornerNudge: 12` eases a 10px overlap (block at y = 2 → y ≈ -10).
  - `maxStep: 1` still stops flush at a thin wall.
  - `addBounds(0, 0, 100, 100)` clamps a 20×12 box to x ∈ [0, 80] and y ∈ [0, 88], and adds 4 solids.
  - Bucket size 32 still finds a solid spanning many buckets.
  - `isAreaFree`: overlap → false, touching edge → true.
- [ ] `npm run check` passes. Commit.

### Task 2: Example uses `BGE.SolidWorld`

**Files:**
- Delete `examples/rpg/src/source/World/SolidWorld.bs` and `examples/rpg/tests/SolidWorld.spec.bs`.
- Modify `Player.bs`, `AreaScene.bs`, `TileMapEntity.bs`, `Prop.bs`, `MapData.bs` and `tests/TownGate.spec.bs` to use `BGE.SolidWorld`, importing `pkg:/source/engine/colliders/SolidWorld.bs`.
- `TileMapEntity`'s four bounds solids become `world.addBounds(0, 0, mapWidth, mapHeight)`.
- `examples/rpg/bsconfig.test.json`: add the engine file to `files` as `{"src": "../../../src/source/engine/colliders/SolidWorld.bs", "dest": "source/engine/colliders/SolidWorld.bs"}`.

- [ ] `cd examples/rpg && npm test` passes, and `npx bsc --create-package=false` validates. Commit.

### Task 3: Assets and loading

**Files:**
- `examples/rpg/src/sprites/`: `rat.png`, `bat.png`, `heart.png` (`heart_shaded`), `coin.png` (`coin_shaded`), plus `CREDITS.md` entries.
- `examples/rpg/src/sounds/`: `sword.wav`, `enemy_hit.wav`, `enemy_die.wav`, `die.wav`, `coin.wav`, `low_health.wav` (plus the existing `pain.wav`), and a new `CREDITS.md`.
- `examples/rpg/src/fonts/`: `quill-and-antler-expanded.ttf`, `license.txt`, `readme.txt`, `CREDITS.md`.
- `main.bs`:
  - `loadBitmap` for rat, bat, heart and coin, plus `coinWorld`: an 18×18 empty bitmap that the 9×9 coin is `DrawScaledObject`-ed into at 2×.
  - `loadSound` for sword, enemyHit, enemyDie, pain, die, coin and lowHealth.
  - `registerFont`, then `loadFont("hud", "Quill and Antler Expanded", Int(uiHeight / 20), false, false)`.

- [ ] Before any code uses them, check the rat/bat row order by cropping the sheets. Commit.

### Task 4: `Combat.bs` pure helpers

**Files:** Create `examples/rpg/src/source/Entities/Combat.bs` and `examples/rpg/tests/Combat.spec.bs`; add `Combat.bs` to `bsconfig.test.json`.

**Produces:**
- `swordBox(facing) as object` — `{x, y, w, h}` relative to the feet point, reaching 28px out from the 20×12 feet box, 32px across.
- `knockbackVector(fromX, fromY, toX, toY, distance) as object` — `{x, y}`; when the two points are within 0.001, returns `{x: 0, y: -distance}`.
- `heartStates(health, maxHealth) as string[]` — `"full"`, `"half"` or `"empty"` per heart.

- [ ] Tests: the box for each facing, a knockback that's diagonal and one that's exactly overlapping, and heart states for 0–6 of 6. Commit.

### Task 5: Enemies (Enemy, Rat, Bat, Coin, placements)

**Files:**
- Create `Entities/Enemy.bs`, `Rat.bs`, `Bat.bs` and `Coin.bs`.
- Modify `MapData.bs` (enemy placements), `AreaScene.bs` (spawn enemies), `Door.bs` (feet only).
- Add a test, `tests/EnemyPlacements.spec.bs`.

**Produces:**
- `Enemy` (tag `"enemy"`, collider `"body"`) with `hurt(fromX, fromY) as boolean` and `isDying`, and a protected `moveEnemy(dt)` / `applyMove(dx, dy, options)`.
- `Coin` posts game event `"coinCollected"` when the player's `feet` collider enters its `pickup` collider.

- [ ] Placement test first: each enemy's 16×10 feet box at `((col + 0.5) * 32 - 8, cellBottomY + 10)` is `isAreaFree` in the area's full world. It fails until placements exist, then passes.
- [ ] Implement, and `npm test` passes. Commit.

### Task 6: Player sword, health, knockback, defeat, coins

**Files:** Modify `Entities/Player.bs` and `Scenes/AreaScene.bs` (`placeAt` gets the spawn id).

- OK press starts or buffers a swing. The swing is 0.5s with the hit window from 0.125s to 0.25s, during which the `sword` collider follows `swordBox`. Each enemy is hit once per swing.
- Contact with an enemy's `body` through `feet` calls `takeHit`: -1 health, pain, knockback of 32px over 0.2s, 1s invulnerability with a 10Hz blink.
- At ≤2 health, `lowHealth` plays every 3s.
- At 0 health: `die`, then after 1s `changeSceneWithFade(currentScene, {spawn: lastSpawn})`. `placeAt` restores health.
- `onGameEvent("coinCollected")` increments `coins`.

- [ ] Validate, and `npm test`. Commit.

### Task 7: HUD

**Files:** Create `examples/rpg/src/source/UI/HeartsHud.bs` and add it to `gameUi` in `main.bs`.

- Scale is `max(1, Int(uiH / 180))`, and the origin is `(Int(uiW * 0.1), Int(uiH * 0.1))`.
- Full heart: normal tint. Empty heart: tint `&h404040FF`. Half heart: the empty heart, with a cached 5×9 region of the full heart over it.
- The coin icon and count go below the hearts.

- [ ] Validate. Commit.

### Task 8: Docs, follow-up issue, and on-device check

- [ ] CLAUDE.md: a `BGE.SolidWorld` bullet under Collision, and an updated rpg bullet (combat, `moveAndSlide` now in the engine). Add a short `docs/game-engine-overview.md` note if its collision section fits.
- [ ] File an issue to promote `autoTilePiece()`.
- [ ] `npm run check:all`.
- [ ] rokubot: town and castle with enemies, the HUD, a swing in each facing. Then hand real-time play to the user.
