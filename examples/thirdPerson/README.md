# Third Person

A third-person, souls-like action game in 3D ([#385](https://github.com/markwpearce/brighterscript-game-engine/issues/385)). So far: a knight on a flat field with a chase camera, movement and combat actions, and enemies that keep spawning 20-50 m away (a skeleton, an orc and a spider in turn, up to 3 at once) to fight. The map, stamina, lock-on, ripostes and checkpoints come later.

## Playing

| Action | Gamepad | Roku remote |
| --- | --- | --- |
| Move (relative to the camera) | Left stick | D-pad |
| Orbit the camera | Right stick | - |
| Recenter the camera | Y | Rewind |
| Attack (press again during a swing to chain) | R1 or A | OK |
| Block (hold; walk slowly) | L1 | Play |
| Parry | L2 | Fast-forward |
| Dodge (roll toward the stick, or step back) | B | Back or Replay |
| Debug panels (FPS, input, memory, GC, log) and entity details | - | `*` |

Movement is relative to the camera, and the camera stays put until you move it.

Each enemy telegraphs its attack with a wind-up, strikes, then recovers, which is your opening. Hitting it during the wind-up interrupts it; a parry during the strike leaves it staggered; blocking takes a fifth of the damage; dodging (mid-roll) takes none. Only two enemies attack at a time, and the rest circle until it's their turn. When the knight dies the field clears and he gets up again.

## How it works

- `World.bs`: the world scale (32 units per metre, so the knight is 64 units tall) and heading helpers.
- `ThirdPersonCamera.bs`: the chase camera. It sits 4 m behind and 1.8 m up, looking at 1.2 m, so the knight fills about half the screen. The right stick orbits (x) and tilts (y) it around that point.
- `Entities/Knight.bs`: a 16-direction `DrawableOrientedSprite`, drawn `axisAligned` so he foreshortens as the camera tilts down, and a small state machine (idle, run, attack, block, parry, dodge). Chained attacks replay the attack with `playOrientedAnimation(name, restart = true)`.
- `Entities/Fighter.bs`: what the knight and the enemies share: health, a round body, knockback and a red flash when hit.
- `CombatDirector.bs`: knows the player and the enemies, pushes overlapping bodies apart (so nobody walks through anybody; lighter bodies move further), finds who a swing hits, and hands out the attack slots.
- `Entities/Enemy.bs`: an 8-direction Flare monster with a small AI. While it's waiting for an attack slot it circles the player; otherwise it closes in (straight, or flanking round to the player's back first) and attacks: wind-up, strike, recover, then either stays close or backs off. A hit during the wind-up interrupts it, and some enemies block hits from the front.
- `Entities/EnemyTypes.bs`: the three enemies, as data. Everything that makes one different (speed, health, weight, how it approaches, what it does after attacking, block chance, and the attack's range, reach, arc, timing, damage and lunge) is a field of `EnemyType`, so a new enemy is a new function here:
  - Skeleton: flanks, sometimes blocks, a quick sword swing.
  - Orc: slow and tough, comes straight at you, a long wind-up and a heavy hit, barely flinches.
  - Spider: fast and fragile, leaps in from 4.5 m, bites, then backs off.
- `Scenes/FieldScene.bs`: the ground plane, the enemy spawner, respawning, the control hints and the health bar.

## Sprite sheets

The knight (`src/sprites/knight.png`) is re-rendered from Clint Bellanger's [Blender sources](https://opengameart.org/content/isometric-hero-and-heroine) (`isometric_hero_heroine_blend.zip`) at the chase camera's angle: 16 directions × 21 frames, 64 px tall, 92×92 cells, one row per direction (front first, then clockwise from above). The attack uses in-between frames sampled from the original animation.

1. The sources are Blender 2.49 files, and Blender 5 drops their animation. Open and re-save `steel_armor.blend`, `male_head1.blend`, `longsword.blend` and `shield.blend` in Blender 2.79 first, e.g. with a script that calls `bpy.ops.wm.save_as_mainfile(filepath=..., copy=True)`.
2. Render with Blender 5 (Cycles, with a shadow catcher for the ground shadow). It prints the cell size, the feet anchor and the texture size:

```
Blender -b <converted>/steel_armor.blend --python tools/render-knight.py -- --parts <converted> --out src/sprites/knight.png --directions 16 --height 64
```

`tools/prepare-sheet.js` repacks Flare's ready-made 8-direction sheets (stance 0-3, run 4-11, melee 12-15, block 16-17, hit and die 18-23, cast 24-27, bow 28-31; rows face l, ul, u, ur, r, dr, d, dl), for the monsters. It keeps a range of columns, trims every cell to one shared box, wraps each direction over several rows to stay under the device's bitmap size, and prints the cell size and feet anchor. It needs Chrome (`CHROME=/path/to/chrome` if it isn't in the default place).

The monsters come from DungeonHack's copies of Flare's sheets (`skeleton_0.png`, `orc_regular_0.png`, `spider_0.png`), keeping frames 0-23 wrapped 12 to a row, e.g.:

```
node tools/prepare-sheet.js <DungeonHack>/assets/images/skeleton_0.png src/sprites/skeleton.png 0 23 12
```

Together they add about 21 MB of texture memory.

## Still needed

- [ ] The knight's sheet is ~10.8 MB of texture memory; trim it (fewer directions or frames, or split by animation once #386 lands) before adding monsters on HD.
- [ ] Ground texture and the map.
- [ ] Stamina, lock-on, ripostes and backstabs, checkpoints.
- [ ] Hit and death art for the knight (he holds a frame and changes colour for now).
