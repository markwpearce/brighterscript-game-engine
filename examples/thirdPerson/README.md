# Third Person

A third-person, souls-like action game in 3D ([#385](https://github.com/markwpearce/brighterscript-game-engine/issues/385)). This first pass is just the player: a knight on a flat field with a chase camera, movement and combat actions. The map, monsters, HUD, stamina, lock-on and checkpoints come later.

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

## How it works

- `World.bs`: the world scale (32 units per metre, so the knight is 64 units tall) and heading helpers.
- `ThirdPersonCamera.bs`: the chase camera. It sits 4 m behind and 1.8 m up, looking at 1.2 m, so the knight fills about half the screen. The right stick orbits (x) and tilts (y) it around that point.
- `Entities/Knight.bs`: a 16-direction `DrawableOrientedSprite`, drawn `axisAligned` so he foreshortens as the camera tilts down, and a small state machine (idle, run, attack, block, parry, dodge). Chained attacks replay the attack with `playOrientedAnimation(name, restart = true)`.
- `Scenes/FieldScene.bs`: the ground plane and the control hints.

## Sprite sheets

The knight (`src/sprites/knight.png`) is re-rendered from Clint Bellanger's [Blender sources](https://opengameart.org/content/isometric-hero-and-heroine) (`isometric_hero_heroine_blend.zip`) at the chase camera's angle: 16 directions × 21 frames, 64 px tall, 92×92 cells, one row per direction (front first, then clockwise from above). The attack uses in-between frames sampled from the original animation.

1. The sources are Blender 2.49 files, and Blender 5 drops their animation. Open and re-save `steel_armor.blend`, `male_head1.blend`, `longsword.blend` and `shield.blend` in Blender 2.79 first, e.g. with a script that calls `bpy.ops.wm.save_as_mainfile(filepath=..., copy=True)`.
2. Render with Blender 5 (Cycles, with a shadow catcher for the ground shadow). It prints the cell size, the feet anchor and the texture size:

```
Blender -b <converted>/steel_armor.blend --python tools/render-knight.py -- --parts <converted> --out src/sprites/knight.png --directions 16 --height 64
```

`tools/prepare-sheet.js` repacks Flare's ready-made 8-direction sheets (stance 0-3, run 4-11, melee 12-15, block 16-17, hit and die 18-23, cast 24-27, bow 28-31; rows face l, ul, u, ur, r, dr, d, dl), for the monsters. It keeps a range of columns, trims every cell to one shared box, wraps each direction over several rows to stay under the device's bitmap size, and prints the cell size and feet anchor. It needs Chrome (`CHROME=/path/to/chrome` if it isn't in the default place).

## Still needed

- [ ] The knight's sheet is ~10.8 MB of texture memory; trim it (fewer directions or frames, or split by animation once #386 lands) before adding monsters on HD.
- [ ] Ground texture and the map.
- [ ] Monsters, hits and damage, stamina, lock-on, checkpoints and the HUD.
