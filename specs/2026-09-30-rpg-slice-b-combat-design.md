# examples/rpg — Slice B: Combat (design)

Issue: #256. Follow-up to Slice A (`specs/2026-09-27-rpg-slice-a-world-design.md`, issue #63).

Slice B adds *Link to the Past*-style action combat to the rpg example: a sword swing, two enemy types, player health with knockback and invulnerability, coin drops, and a hearts + coins HUD. It also promotes the example's `SolidWorld` into the engine as `BGE.SolidWorld`, since enemies are its second user.

## Goals

- Sword swing on OK using the adventurer sheet's attack1/attack2 rows, alternating per swing.
- Two enemies with contact damage and knockback: rats (town, walk through solids) and bats (castle, fly over solids).
- Player health (3 hearts, half-heart damage), invulnerability blink, low-health beep, defeat-and-respawn.
- Coins dropped by enemies, a coin counter, and a title-safe hearts + coins HUD.
- `BGE.SolidWorld` in the engine, with the example and its tests switched over.

## Non-goals

`autoTilePiece()` promotion (filed as its own issue), saving health/coins (Slice C), bosses, enemy projectiles, enemy AI beyond wander/chase, combos beyond alternating attack1/attack2, movers blocking each other, one-way solids, removing solids at runtime.

## Assets and licensing

Sprites (`examples/rpg/src/sprites/`, credited in its `CREDITS.md`):

- `rat.png` — `rodent-1.0/PNG/32x32/rat.png` from [Rodents (Rat Rework)](https://opengameart.org/node/82869) by Tuomo Untinen (Reemax) & Jordan Irwin (AntumDeluge). CC-BY 3.0 / CC-BY-SA 3.0. 96×128: 3 walk frames × 4 rows (N/E/S/W), 32×32 cells; the centre frame is idle.
- `bat.png` — `bat-1.3/PNG/48x64/bat-NESW.png` from [Bat (Rework)](https://opengameart.org/node/77508) by bagzie. OGA-BY 3.0 / CC-BY 3.0. 144×256: 3 flap frames × 4 rows (N/E/S/W), 48×64 cells.
- `heart.png`, `heart_empty.png`, `coin.png` — 9×9 icons (`heart_shaded`, `heart_noborder_simple` dimmed or similar, `coin_shaded`) from [RetroPixel Icons V1 (9x9)](https://opengameart.org/content/retropixel-icons-v1-9x9) by Anton Revin. CC0 (credit optional, given anyway).

Sounds (`examples/rpg/src/sounds/`, new `CREDITS.md`):

| File | When | Source |
|------|------|--------|
| `pain.wav` | player takes damage | supplied by the repo owner for this example |
| `low_health.wav` | every 3s at ≤1 heart | `Blip_Select.wav` from [100+ Game Sound Effects](https://opengameart.org/content/100-plus-game-sound-effects-wavoggm4a) by Damaged Panda, CC-BY 3.0 |
| `sword.wav` | sword swing | copy of `examples/platformer/src/sounds/slide.wav` (no license on file) |
| `enemy_hit.wav` | enemy hit, survives | copy of `examples/breakout/src/sounds/hit.wav` (supplied by repo owner, no license on file) |
| `enemy_die.wav` | enemy defeated | copy of `examples/platformer/src/sounds/monster_die.wav` (no license on file) |
| `die.wav` | player defeated | copy of `scripts/exampleTemplate/src/sounds/die.wav` |
| `coin.wav` | coin picked up | copy of `examples/platformer/src/sounds/coin.wav` (the template's `score.wav`) |

Font (`examples/rpg/src/fonts/`): `quill-and-antler-expanded.ttf` (family "Quill and Antler Expanded") by MagicBear, [SIL OFL 1.1](https://fontstruct.com/fontstructions/show/2907796). The OFL readme requires `license.txt` and `readme.txt` to ship alongside the `.ttf`, so all three are copied. A `CREDITS.md` names it.

## Engine: `BGE.SolidWorld` (`src/source/engine/colliders/SolidWorld.bs`)

The example's `World/SolidWorld.bs` moves into the engine, next to `TileCollision.bs`, with its behaviour unchanged: axis-aligned solid rectangles `{x, y, w, h}` (bottom-left corner, world +y up), grid-bucketed, and `moveAndSlide()` with sub-stepping and the union-of-hits corner nudge. It complements `BGE.resolveAabbTileCollision` (platformer tiles, one-way platforms) for top-down games; neither replaces `Collider`/`roCompositor` overlap detection.

API:

```brighterscript
namespace BGE
  interface SlideOptions extends roAssociativeArray
    ' Max perpendicular overlap eased around a corner when moving on one axis. 0 = off. Default 8.
    optional cornerNudge as float
    ' Longest sub-step, so a fast move can't tunnel a thin solid. Default 4.
    optional maxStep as float
  end interface

  interface SlideResult
    x as float        ' new bottom-left x of the box
    y as float
    blockedX as boolean
    blockedY as boolean
  end interface

  class SolidWorld
    sub new(bucketSize = 128 as integer)
    sub addSolid(x as float, y as float, w as float, h as float)
    ' Four solids of `thickness` surrounding the rectangle, so movers stay inside it.
    sub addBounds(x as float, y as float, w as float, h as float, thickness = 64 as float)
    function getSolidCount() as integer
    function moveAndSlide(mover as object, dx as float, dy as float, options = {} as BGE.SlideOptions) as BGE.SlideResult
  end class
end namespace
```

- `SlideResult` is an `interface` (pure data, built as an AA literal), following `BGE.RaycastHit`.
- The nudge and step constants become per-call options with today's values as defaults. The bucket size becomes a constructor argument.
- Options are read via `DoesExist()` (bsc can't iterate an options interface).

Tests: `src/source/engine/colliders/SolidWorld.spec.bs` — the example's 13 existing tests retargeted to `BGE.SolidWorld`, plus: `cornerNudge: 0` disables the nudge; a custom `maxStep` still can't tunnel; `addBounds` keeps a box inside on all four sides; a non-default bucket size still finds solids spanning buckets. One `@suite` class in the file.

The example deletes `World/SolidWorld.bs` and `tests/SolidWorld.spec.bs`; `Player`, `AreaScene`, `TileMapEntity`, `Prop`, `MapData` use `BGE.SolidWorld`. The rpg's own test build (`examples/rpg/bsconfig.test.json`) lists files explicitly and `MapData.bs` references the solid world, so it needs the engine's `SolidWorld.bs` (via `roku_modules`) or `MapData`'s solid-world dependency split out — resolved in the plan.

Docs: public doc comments on the class for game developers; a CLAUDE.md Collision bullet next to `resolveAabbTileCollision`; the rpg bullet no longer calls `moveAndSlide` "example code for now"; a short `SolidWorld` subsection in the collision part of `docs/game-engine-overview.md` if one fits there.

## Example: gameplay

### Sword (Player)

- OK press starts a swing if not already swinging. Swings alternate `attack1_<facing>` / `attack2_<facing>` (sheet rows 8–15), played with `SpritePlayMode.Forward` at 16 fps (8 frames ≈ 0.5s).
- During a swing, movement is ignored and facing is locked, so no mid-swing animation change restarts the frame clock.
- The hit window is the arc frames (2–3, ≈ 0.125–0.25s into the swing). During it a `RectangleCollider` "sword" (~28×24) is enabled, placed in front of the feet in the facing direction (`Combat.swordBox(facing)`), and disabled otherwise.
- Each enemy can be hit at most once per swing (a per-swing set of hit enemy ids).
- An OK press during the last 0.15s of a swing is buffered (`BGE.CountdownTimer`) and starts the next swing the moment the current one ends.
- The swing is timed by the player's own elapsed-time counter (not by reading the sprite's frame), so the hit window doesn't depend on sprite internals.

### Enemies

`Enemy` base class (extends `BGE.GameEntity`): `health`, contact collider "body", `hurt(fromX, fromY)` (flash, knockback, sound, death), a 0.15s knockback, death fade + 50% coin drop. Subclasses supply movement and animation.

- **Rat** (2 health): 32×32 sprite, walk animation per facing (rows N/E/S/W → up/right/down/left), idle = centre frame. Wanders in a random 4-way direction for 1–2s, pauses, repeats; within ~120px of the player it chases. Moves (and is knocked back) through the area's `BGE.SolidWorld` with a ~16×10 feet box. `position.z = -feetY`, like the player.
- **Bat** (1 health): 48×64 sprite, flap animation per facing. Flies toward the player on a sine wobble, ignoring solids, clamped to the map bounds. Drawn at a fixed height above its ground point, with a small dark ellipse shadow on the ground; z from the ground point so it depth-sorts correctly.
- On hit: white/red flash (~0.1s) via the sprite's color, knockback ~24px over 0.15s away from the player (`Combat.knockbackVector`), `enemy_hit` sound. Knockback uses `cornerNudge: 0`.
- On last hit: `enemy_die` sound, colliders disabled, fade out over ~0.3s, 50% chance to spawn a `Coin` at its feet, then `delete()`.
- Placement: `{type: "enemy", kind: "rat" | "bat", col, row}` entries in `MapData` placement lists (a few rats in town, a few bats in the castle). Not persistent — re-entering an area respawns them.

### Player health

- `maxHealth = 6` half-hearts (3 hearts). Contact with an enemy's "body" collider costs 1 half-heart, checked in `onCollision` while not invulnerable (so standing inside an enemy keeps hurting after the window ends).
- On damage: `pain.wav`, knockback ~32px over 0.2s away from the enemy through `moveAndSlide` (`cornerNudge: 0`), input ignored during knockback, 1s invulnerability (`BGE.CountdownTimer`) with the sprite blinking (alpha toggled ~10 Hz).
- Low health: while `health <= 2`, `low_health.wav` plays every 3s.
- Defeat at 0: `die.wav`, input locked, after ~1s `changeSceneWithFade(currentScene, {spawn: <first spawn>})` and health restored to max on arrival. Coins are kept.

### Coins

`Coin` entity: 9×9 icon drawn at 2× (art pixels match the 32px tiles' scale), a small bob tween, a "pickup" collider. When the player's "feet" collider enters it: `coin.wav`, `player.coins += 1`, delete. Coins live on the persistent `Player`, so they carry between areas (not saved).

### HUD (`UI/HeartsHud.bs`)

A `gameUi` child, title-safe (≥10% inset from every canvas edge, top-left):

- A row of 3 hearts, each full, half, or empty from `Combat.heartStates(health, maxHealth)` (returns `"full" | "half" | "empty"` per heart). Half = the left half of the full icon drawn over the empty icon.
- Below it, the coin icon and the count in Quill and Antler Expanded.
- Icons drawn at an integer scale of the UI canvas so pixels stay crisp. Redraws from the player's current state each frame (no events needed).

### Combat helpers (`Entities/Combat.bs`)

Pure functions with no engine state, unit tested:

- `swordBox(facing, feetX, feetY)` → `{x, y, w, h}` in front of the feet for each facing.
- `knockbackVector(fromX, fromY, toX, toY, distance)` → `{x, y}` away from the source; exactly-overlapping positions push down (a fixed fallback, never NaN).
- `heartStates(health, maxHealth)` → array of heart states.

## Controls

`main.bs` keeps the "move" axis; OK is read in `Player.onInput` with `input.press and input.isButton("OK")`. Back still exits the channel.

## Testing

- Engine: `SolidWorld.spec.bs` (ported + new cases). `npm run check`.
- Example: `examples/rpg/tests/Combat.spec.bs` — sword box per facing, knockback direction including the overlap fallback, heart states for 0–6. `cd examples/rpg && npm test`.
- `npm run check:all`.
- On-device via rokubot (mandatory): both areas load with enemies; HUD at full/half/empty and title-safe; a swing in each facing; a coin drop and pickup. Real-time fighting is handed to the repo owner to playtest.

## Open follow-ups

- Promote `autoTilePiece()` to `utils/tilemap/`, generalised to 4/8-bit neighbour masks (new issue).
- Sword/enemy sounds without license info on file should be replaced before this is presented as shippable art.
