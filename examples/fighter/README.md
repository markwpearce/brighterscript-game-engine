# Fighter

A two-player, *Street Fighter 2*-style fighting game ([#295](https://github.com/markwpearce/brighterscript-game-engine/issues/295)). This is a rough first pass at the fight itself. Menus, a title screen and an intro come later.

## Playing

Each player uses their own controller (`multi_controllers=1`; every remote, gamepad and browser controller gets its own player index). Player 1 is whoever presses first. Until a second controller presses a button, P2 is a practice dummy that stands still. Their first press joins them and restarts the match.

| Action | Gamepad | Roku remote | Browser controller |
| --- | --- | --- | --- |
| Walk / jump / crouch | D-pad or left stick | D-pad | Stick 1 |
| Block | Hold away from the opponent (crouch to block lows) | same | same |
| Light / heavy punch | X / Y | Rewind / Play | x / y |
| Light / heavy kick | A / B | OK / Fast-forward (and Back) | ok / b |
| Show colliders | - | `*` | - |

Launch params: `p2=1` joins P2 straight away, and `dummy=stand` or `dummy=crouch` makes the dummy guard whenever it's attacked. For example:

```
node node_modules/rokubot/dist/cli.js launch dev --param dummy=crouch
```

## How it works

- `Fight/MoveData.bs`: every attack's frame data (startup/active/recovery in 60 Hz ticks, damage, stun, knockback, block height, hitbox).
- `Fight/FrameLogic.bs`, `Fight/MatchRules.bs`: pure rules (move phases, blocking, push-apart, damage, rounds, the health-bar trail and the fixed-step clock), covered by `tests/` (`npm test`).
- `Entities/Fighter.bs`: movement and the move state machine, with separate `hurt` and `attack` colliders. The attack collider is enabled only during a move's active frames.
- `Scenes/FightScene.bs`: reads both players' controls, runs the simulation at a fixed 60 Hz (so frame data means the same thing at 30 or 60 fps), resolves hits (hit-pause, sparks, wall pushback), and handles the camera, round flow and HUD.

## Still needed

### Art

- [x] **Fighter sprites**, from the [Mustermann 2 karate template](https://opengameart.org/content/fighting-character-template-mustermann-2-a001aaaa001-karate): `art/Orangeblack.png` for P1, `art/Blueehite.png` for P2. Each sheet is a 35x29 grid of 997 unlabelled frames, about 8000x6900 px, far too big for a Roku texture. `npm run build-sprites` cuts the frames named in `src/sprites/fighters/animations.json` out of both sheets, at half size with the feet aligned, into `p1.png`/`p2.png` (158 frames, 3264x868, ~11MB of texture memory each) plus `atlas.json`. Attack animations list `startup`/`active`/`recovery` frames, and each list is stretched over that phase of the move, so the extended limb shows exactly while the hitbox is out. Facing left mirrors with a negative `scale.x`.
- [ ] Frame picks are a first pass from eyeballing the sheet. Still to do: a proper walk cycle, crouch hit and block poses, a pre-jump squat, and retuning the hitboxes in `MoveData.bs` to the art.
- [ ] Floor/ground strip for the stage (the industrial pack has none, so the floor is a flat rectangle).
- [ ] Hit and block spark animations (currently a growing square).
- [ ] HUD art: health bar frame, round-win markers, a KO badge and character portraits.
- [ ] Announcement text art ("Round 1", "Fight!", "K.O.", "Time", "Perfect").

### Sound

The `sounds/` files are generated tone/noise placeholders.

- [ ] `jump`, `land`
- [ ] `whiffLight`, `whiffHeavy` (attack swings)
- [ ] `hitLight`, `hitHeavy`, `block`
- [ ] Announcer: `announceRound` (ideally one per round number), `announceFight`, `announceKo`, `announceTime`, `announceWin`
- [ ] Stage music and KO/victory stings

### Later

- Title screen, character select, pause menu and intro.
- A CPU opponent.
- Throws, special moves (motion inputs), knockdowns and wake-up, and a juggle limit.
- Possible engine promotions to discuss: a hitbox/hurtbox frame-data helper, and a health bar widget with a damage trail in `BGE.UI`.

## Credits

- Fighters: [Fighting character template Mustermann 2 (karate)](https://opengameart.org/content/fighting-character-template-mustermann-2-a001aaaa001-karate) by Puffolotti, CC0.
- Stage: [Industrial Parallax Background](https://opengameart.org/content/industrial-parallax-background) by Luis Zuno ([@ansimuz](https://ansimuz.com)), CC0.
- Font: Viper Command, from [FontSpace](https://www.fontspace.com/viper-command-font-f157886) (see `src/fonts/CREDITS.md`).
