# Platformer boss level: Venus fly trap

A new final level (level 7) for `examples/platformer`: a one-screen arena with a
giant, pixelated man-eating plant that shoots fireballs and dies after three stomps
on its head.

## Goals

- A boss fight that's the last level, reached by clearing level 6's goal flag.
- Uses the supplied art/sound: the plant frames (bevouliin, via
  [OpenGameArt](https://opengameart.org/content/man-eating-plant-animation-sprites-for-game-developers)),
  `orange_fireball.png` ([OpenGameArt](https://opengameart.org/content/fireball-3))
  and `src/sounds/fire.wav` ([OpenGameArt](https://opengameart.org/content/fire-evil-spell)).
- Example code only, no engine changes.

## Gameplay

### Arena (level 7)

- 10 tiles wide (640px, exactly one camera frame, so the camera never scrolls), the
  same `NumRows` as every other level.
- Full-width solid floor (top edge at y = 128, like the other levels). One one-way
  (`-`) platform on each side, 3 tiles wide, 2 tiles above the floor (top edge at
  y = 256), clear of the plant.
- Player spawns on the left. No `G` in the layout (the goal flag appears when the boss dies), no coins or dino enemies.
- A new `B` marker in the level rows spawns the boss, rooted on the floor at that
  column's center.

### The plant

- About 180px tall on the 640x360 canvas (half the screen), rooted at the center of the
  floor, playing the chomp loop.
- Always faces the player: mirrored via `sprite.scale.x = ±1` whenever the player is
  on the other side of the plant's root x (with a small dead zone so it doesn't flicker
  when the player is directly above).
- Two colliders, both moved to the mirrored offset when it turns:
  - **head**: covers the cap and jaws. Touching it while falling with feet at or
    above its top edge is a stomp (same test `Player` already uses for `Enemy`), and
    the player bounces. Any other contact hurts.
  - **stem**: covers the stalk and rocks below the jaws. Contact always hurts.

### States and phases

Health is 3; the phase is `4 - health` (1 at full health, 3 after two stomps).

| Phase | Volley | Interval | Fireball speed |
|---|---|---|---|
| 1 | 1 fireball aimed at the player | 2.5s | 220 px/s |
| 2 | 3-fireball fan (aimed, ±18°) | 2.5s | 220 px/s |
| 3 | 3-fireball fan (aimed, ±18°) | 1.6s | 300 px/s |

State machine (`PlantBoss.state`):

- `rising`: tweens up out of the ground (~0.5s). Can't be hurt, doesn't fire.
- `up`: fires volleys on the phase interval. Each volley has a ~0.3s telegraph first
  (a quick scale-up tween), then fires from the mouth and plays `fire`. After 6s up
  without being hit it goes to `sinking` (same phase).
- `hurt`: on a stomp, health drops by 1. It flashes red (the sprite's `color` alternates
  red/white every ~0.08s) and shakes (a small x jitter) while sinking into the ground.
  Can't be hurt. If health is still above 0, it goes to `hidden`, otherwise to `dying`.
- `sinking`: sinks without flashing, then `hidden`.
- `hidden`: fully underground for ~1.5s, colliders disabled, then `rising` in the
  current phase.
- `dying`: the 3rd stomp. It flashes and shakes as it sinks, slowly (~4s), and never
  comes back. Once it's fully under, it posts `bossDefeated` and `MainScene` spawns a
  goal flag where it sank (growing out of the ground). Touching the flag wins, the
  same way as every other level: it's the last level, so `Goal` posts
  `levelComplete`, which shows the existing "You won" panel in `GameStateManager`.

**Player death resets the fight.** The boss listens for the existing `playerHurt` game
event: it restores full health (phase 1), destroys every live fireball, and restarts
from `hidden`, so the respawned player gets a moment before the next volley. Game over,
then Retry, reloads the scene as today, which also starts the fight at full health.

### Fireballs

- A `Fireball` entity: the 2-frame 32x32 sheet, looping, rotated to its direction of
  travel (the art points right). Its hitbox is a circle smaller than the sprite.
- Flies straight at a constant velocity. When it touches the player the player takes
  damage (same `takeDamage()` path and invulnerability gate as a dino hit). It's
  destroyed when it hits a solid (`#`) tile or leaves the arena. It passes through
  one-way platforms, since a platform shouldn't be a perfect shield.

## Implementation

### Assets

- `src/sprites/plant_boss.png`: all 37 frames, pixelated:
  1. Each source frame (136x173) is box-downscaled so the finished plant is about
     180px tall (to ~73x93).
  2. Alpha is thresholded to hard edges.
  3. Colors are remapped to one palette shared by every frame (built from all
     37 frames together, around 24 colors), so the palette can't shimmer between frames.
  4. The frame is nearest-neighbour upscaled 2x (2px chunks), baked into the PNG
     rather than scaled at draw time, so Roku scale filtering can't blur it.
  5. The frames are packed into a 10-column grid.
  The ImageMagick commands used go in the platformer's `CREDITS.md` entry so the
  sheet can be regenerated.
- `src/sprites/fireball.png`: `orange_fireball.png` copied as-is (already pixel art).
- `src/sounds/fire.wav`: already in place.
- `CREDITS.md`: entries for all three with their OpenGameArt sources.

### Code (all under `examples/platformer/src/source/`)

- `LevelData.bs`: `getLevel7Rows()` added to `getAllLevels()`, and the `B` marker added
  to the legend.
- `Entities/PlantBoss.bs` (new): the state machine, facing, colliders, volley
  firing, flash/shake/sink, and the `playerHurt` reset. It sits behind the ground so
  sinking needs no clipping: `position.z` is slightly negative, and `Camera2d` draws
  lower z first, so `Level`'s floor tiles draw over the part that's underground. The
  sink/rise is a tween of the sprite drawable's own offset, so `position` (the root)
  and the colliders' anchor stay put. Colliders are disabled while it's not `up`.
- `Entities/Fireball.bs` (new): velocity, rotation, bounds/tile checks, destroyed
  on hit.
- `Entities/Player.bs`: `onCollision()` handles `PlantBoss` (by collider name: head
  stomp or hurt, stem hurt) and `Fireball` (hurt).
- `Scenes/MainScene.bs`: spawns `PlantBoss` for `B`.
- `main.bs`: loads `plantBoss`/`fireball` bitmaps and the `fire` sound.
- `GameStateManager`: no change expected. Its "Level N/M" HUD picks up 7 levels
  automatically.

### Risks to check early

- **Draw order**: confirm a negative `position.z` puts the plant behind `Level`'s baked
  floor images but still in front of `MainScene`'s parallax background layers. If the
  background layers turn out to be depth-sorted with it, pick a z between them.
- **Sprite tint**: `Drawable.color` is multiplied in at draw time, so red (`&hFF4040`)
  on a sprite should read as a red flash. Confirm on device.
- **Texture memory**: the sheet is about 1460x744 (about 4.3MB decoded). If that's a
  problem on low-end hardware, drop every other frame.

## Testing

- `npm run validate-examples` (platformer) and `npm run check`, which is unaffected
  since no engine files change.
- There's no Rooibos suite for the platformer, and the boss logic is timing and
  collision driven, so verification is on device: sideload via rokubot, launch straight
  into the fight with `--param level=7`, and screenshot the non-real-time states (arena
  layout, facing, sunk/hidden, the flash). Per the no-real-time-play rule, the user
  plays the fight itself (stomps, fireball dodging, death reset, win panel) and reports
  back.
