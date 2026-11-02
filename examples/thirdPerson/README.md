# Third Person

A third-person, souls-like action game in 3D ([#385](https://github.com/markwpearce/brighterscript-game-engine/issues/385)). So far: a knight on a flat field with a chase camera, movement and combat actions, and enemies that keep spawning 20-50 m away (a skeleton, an orc and a heavy orc in turn, up to 3 at once) to fight. The map, stamina, ripostes and checkpoints come later.

## Playing

| Action | Gamepad | Roku remote |
| --- | --- | --- |
| Move (relative to the camera) | Left stick | D-pad |
| Orbit the camera | Right stick | - |
| Recenter the camera behind the knight | R3 or Y | Rewind |
| Attack (press again during a swing to chain) | R1 or A | OK |
| Block (hold; walk slowly) | L1 | Play |
| Parry | L2 | Fast-forward |
| Dodge (roll toward the stick, or step back) | B | Back or Replay |
| Debug panels (FPS, input, memory, GC, log) and entity details | - | `*` |

Movement is relative to the camera, and the camera stays put until you move it.

Each enemy telegraphs its attack with a wind-up, strikes, then recovers, which is your opening. Hitting it during the wind-up interrupts it; a parry during the strike leaves it staggered; blocking takes a fifth of the damage; dodging (mid-roll) takes none. Only one enemy attacks at a time, with a short gap between attacks, and only from where the camera can see it; the rest circle until it's their turn. A hit knocks an enemy back, and most then back off for a moment. Hits spray blood (bone dust from the skeleton), and blocks and parries throw sparks. When the knight dies the field clears and he gets up again.

## How it works

- `World.bs`: the world scale (32 units per metre, so the knight is 64 units tall) and heading helpers.
- `ThirdPersonCamera.bs`: the chase camera. It sits 4 m behind and 1.8 m up, looking at 1.2 m, so the knight fills about half the screen. The right stick orbits (x) and tilts (y) it around that point.
- `Entities/Knight.bs`: a 16-direction `DrawableOrientedSprite`, drawn `axisAligned` so he foreshortens as the camera tilts down, and a small state machine (idle, run, attack, block, parry, dodge). Chained attacks replay the attack with `playOrientedAnimation(name, restart = true)`.
- `Entities/Fighter.bs`: what the knight and the enemies share: health, a round body, knockback and a red flash when hit.
- `Entities/HitEffect.bs`: a one-off particle burst where a blow lands (blood, bone dust, block and parry sparks), using `DrawableParticles` with its particles made by hand so they fan out round the ground direction of the hit.
- `CombatDirector.bs`: knows the player and the enemies, pushes overlapping bodies apart (so nobody walks through anybody; lighter bodies move further), finds who a swing hits, hands out the attack slot (one at a time, with a gap between attacks, only to enemies in view).
- `Entities/Enemy.bs`: a 16-direction monster, rendered like the knight, with a small AI. While it's waiting for an attack slot (or out of view) it circles the player; otherwise it closes in (straight, or flanking round to the player's side first) and attacks: wind-up, strike, recover, then either stays close or backs off. A hit knocks it back and, during the wind-up, interrupts it, after which it backs off; some enemies block hits from the front, and heavy ones shrug hits off.
- `Entities/EnemyTypes.bs`: the three enemies, as data. Everything that makes one different (size, blood colour, speed, health, weight, how it approaches, what it does after attacking, block chance, and the attack's range, reach, arc, timing, damage and lunge) is a field of `EnemyType`, so a new enemy is a new function here:
  - Skeleton: flanks, sometimes blocks, a quick sword swing.
  - Orc: quick, no armour; comes straight at you, chops, then backs off.
  - Heavy orc: slow and tough, blocks often, never flinches; a long wind-up and a heavy hit.
- `Scenes/FieldScene.bs`: the ground plane, the enemy spawner, respawning, the control hints and the health bar.

## Sprite sheets

The knight and the monsters are re-rendered from Flare-style Blender sources (Clint Bellanger's knight and skeleton, johndh's orc; see [CREDITS.md](CREDITS.md)) at the chase camera's angle (12 degrees above horizontal), all at the same scale (64 px for the knight's 1.8 Blender units, which is 2 m in the game), 16 directions, front first then clockwise from above. Flare's monsters are big next to its hero, so they're rendered a little smaller (`--height 56`, or 58 for the heavy orc, against the knight's 64). The orcs' skin is recoloured a paler, sickly green with dark hair (`ORC_COLOURS` in the script), and the monsters' melee gets two in-between frames (6 in place of Flare's 4). Each direction's frames follow on from the last, wrapping to stay within the device's 2048 px bitmap limit.

| Sheet | Source | Frames per direction | Cell | Texture |
| --- | --- | --- | --- | --- |
| `knight.png` | [`isometric_hero_heroine_blend.zip`](https://opengameart.org/content/isometric-hero-and-heroine): `steel_armor.blend` with `male_head1`, `longsword` and `shield` | 21 | 92×92 | 10.8 MB |
| `skeleton.png` | `skeleton_0.blend` | 24 | 112×75 | 12.3 MB |
| `orc.png` | `orc_flare_0.blend`, layer 2 (hand axe) | 23 | 100×83 | 11.7 MB |
| `orc_heavy.png` | `orc_flare_0.blend`, layer 5 (armour, shield, axe) | 20 | 116×101 | 14.3 MB |

1. The sources are Blender 2.49 files, and Blender 5 drops their animation and their procedural textures. Convert each one with Blender 2.79, which re-saves it and rebuilds its materials as Cycles nodes:

```
blender -b skeleton_0.blend --python tools/convert-flare.py -- <converted>/skeleton_0.blend
```

2. Render with Blender 5 (Cycles, with a shadow catcher for the ground shadow). `--character` picks the frames, layers and parts (see `CHARACTERS` at the top of the script). It prints the cell size, the feet anchor, the frame columns of each animation and the texture size, which go in `Knight.bs` or `EnemyTypes.bs`:

```
Blender -b <converted>/steel_armor.blend --python tools/render-character.py -- --character knight --parts <converted> --out <somewhere>/knight.png
Blender -b <converted>/skeleton_0.blend --python tools/render-character.py -- --character skeleton --height 56 --columns 16 --out <somewhere>/skeleton.png
Blender -b <converted>/orc_flare_0.blend --python tools/render-character.py -- --character orc --height 56 --columns 16 --out <somewhere>/orc.png
Blender -b <converted>/orc_flare_0.blend --python tools/render-character.py -- --character orc-heavy --height 58 --columns 16 --out <somewhere>/orc_heavy.png
```

Add `--packed` to trim each frame and pack them into sheets of at most `--sheet-size` (2048) px, with a `.json` frame list for `Game.getSpriteFrames()`. Add `--mirror` to render only the front-to-back half of the directions, for `DrawableOrientedSprite.mirrorBuckets`. The sheets in `src/sprites` are still full grids.

The frames it renders are kept in a `<character>_<height>_frames` folder next to the sheet, so render outside `src/` and copy the sheet in. They aren't keyed by colour, so clear them after changing `colours`.

Flare's actions put stance at frames 1-4, run 5-12 and melee 13-16; the skeleton has block 17-18, hit 19-20 and die 21-28, and the orc hit 17-18, die 17-24, cast 25-28 and block 29-32.

## Still needed

- [ ] The four sheets take ~49 MB of texture memory, too much for HD devices (64 MB). Most of each cell is empty, so per-frame cell sizes ([#397](https://github.com/markwpearce/brighterscript-game-engine/issues/397)) would help most; or fewer directions or frames, or split by animation once #386 lands.
- [ ] Ground texture and the map.
- [ ] Stamina, ripostes and backstabs, checkpoints.
- [ ] Hit and death art for the knight (he holds a frame and changes colour for now).
