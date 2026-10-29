# Third Person

A third-person, souls-like action game in 3D ([#385](https://github.com/markwpearce/brighterscript-game-engine/issues/385)). This first pass is just the player: a knight on a flat field with a chase camera, movement and combat actions. The map, monsters, HUD, stamina, lock-on and checkpoints come later.

## Playing

| Action | Gamepad | Roku remote |
| --- | --- | --- |
| Move (relative to the camera) | Left stick | D-pad |
| Orbit the camera | Right stick | - |
| Recenter the camera | Y | `*` |
| Attack (press again late in a swing to chain) | R1 or A | OK |
| Block (hold; walk slowly) | L1 | Play |
| Parry | L2 | Fast-forward |
| Dodge (roll toward the stick, or step back) | B | Back or Replay |

With no camera input, the camera drifts back behind the knight while he runs.

## How it works

- `World.bs`: the world scale (32 units per metre, so the knight is 64 units tall) and heading helpers.
- `ThirdPersonCamera.bs`: the chase camera. It sits 4.3 m behind and 1.9 m up, looking at 1.4 m, which puts the horizon about 43% down the screen and the knight's feet near the bottom.
- `Entities/Knight.bs`: an 8-direction `DrawableOrientedSprite` and a small state machine (idle, run, attack, block, parry, dodge). Chained attacks alternate between two identical animations because replaying the one already playing doesn't restart it.
- `Scenes/FieldScene.bs`: the ground plane and the control hints.

## Sprite sheets

`tools/prepare-sheet.js` turns a Flare 8-direction sheet (4096x1024, 16-bit) into one the game uses. It keeps a range of frame columns, trims every cell to one shared bounding box, wraps each direction over several rows to stay under the device's bitmap size, and prints the cell size and the feet anchor (the centre of the baked-in shadow). It needs Chrome (`CHROME=/path/to/chrome` if it isn't installed in the default place).

```
node tools/prepare-sheet.js <path>/male_hero_knight.png src/sprites/male_hero_knight.png 0 19 10 --keep-shadow
```

The source sheet's columns are stance 0-3, run 4-11, melee 12-15, block 16-17, hit and die 18-23, cast 24-27 and bow 28-31; rows face l, ul, u, ur, r, dr, d, dl. The game keeps columns 0-19, so in the prepared sheet a frame's cell is `row * 20 + column`.

## Still needed

- [ ] Re-render the knight at the camera's angle and a higher resolution (he's ~43 px tall in the sheet and fills half the screen).
- [ ] Ground texture and the map.
- [ ] Monsters, hits and damage, stamina, lock-on, checkpoints and the HUD.
