# Ironyard Brawl (fighter)

A *Street Fighter 2*-style fighting game ([#295](https://github.com/markwpearce/brighterscript-game-engine/issues/295)): one player against the CPU, two players on their own controllers, or training against a dummy. There are four fighters (Blaze and Frost with four colour palettes each, Bruno and Nova with two), each with three special moves, plus throws, knockdowns, best-of-3 rounds, an announcer and music.

## Playing

The title menu picks **Arcade** (vs CPU), **2 Players** or **Training**, the CPU's level (Easy, Normal, Hard), and **Controllers**. On the select screen, move with left/right and pick with an attack button. Each button picks a different colour (LP, HP, LK, HK are palettes 1-4). In 2 Players, P2 joins by pressing any button. Against the CPU, a second controller pressing a button is a new challenger and goes back to the select screen for a 2-player match. In Training, it takes over the dummy.

Each player uses their own controller (`multi_controllers=1`; every remote, gamepad and phone gets its own player index, in the order they're first used). On the select screen, whichever controller presses first is P1 (and in 2 Players, the next one is P2). The **Controllers** screen sets P1 and P2 up front, and shows a QR code for using a phone as a controller.

| Action | Gamepad | Roku remote | Browser controller |
| --- | --- | --- | --- |
| Walk / jump / crouch | D-pad or left stick | D-pad | Stick 1 |
| Block | Hold away from the opponent (crouch to block lows) | same | same |
| Light / heavy punch | X / Y | Rewind / Play | x / y |
| Light / heavy kick | A / B | OK / Fast-forward | ok / b |
| Pause | - | Back | - |
| Debug info (FPS, then everything with colliders, then off) | - | `*` | - |

Moves, in numpad notation (6 is toward the opponent, 2 down). The diagonals are optional, since the remote's d-pad can't press them:

| Move | Input | Notes |
| --- | --- | --- |
| Special 1 | 2, 3, 6 + punch | Blaze/Frost/Nova: fireball (heavy punch throws a faster one; one on screen at a time; fireballs cancel). Bruno: shoulder charge, travels forward and knocks down. |
| Special 2 | 6, 2, 3 + punch | Blaze/Frost: rising uppercut. Nova: flip kick. Both can't be hit for their first frames (anti-air), knock down, and are slow to recover if blocked. Bruno: overhead hammer fist (block it standing). |
| Special 3 | 2, 1, 4 + kick | Blaze/Frost: cartwheel kick. Bruno/Nova: slide kick (hits low). Both travel forward and knock down. |
| Throw | Toward or away + heavy punch, up close | Can't be blocked. Holding away throws them behind you. |
| Sweep | Crouching heavy kick | Hits low and knocks down. |

Knocked-down fighters can't be hit until they're back up. An airborne fighter can be hit twice (a juggle) before they're safe until they land.

### Launch params

`scene=fight` skips the menus. It takes `mode=cpu|versus|training`, `p1=blaze:0` and `p2=frost:2` (character and palette), `cpu=1-3`, and `dummy=stand|crouch` for how the training dummy guards. `scene=select` goes straight to the select screen. For example:

```
npm run run-example -- fighter scene=fight mode=training dummy=crouch
```

## How it works

- `Scenes/TitleScene.bs`, `Scenes/SelectScene.bs` (select and VS screens), `Scenes/FightScene.bs`.
- `Fight/MoveData.bs`: every attack's frame data (startup/active/recovery in 60 Hz ticks, damage, stun, knockback, block height, hitbox), plus the specials and the throw.
- `Fight/MotionInput.bs`: the input history and motion detection for specials.
- `Fight/FrameLogic.bs`, `Fight/MatchRules.bs`, `Fight/Roster.bs`: pure rules (move phases, blocking, push-apart, damage, rounds, the health-bar trail, the fixed-step clock, picks and palettes). These and the motion inputs are covered by `tests/` (`npm test`).
- `Fight/PlayerSlots.bs`: which controller (engine player index) each fighter's `p0...`/`p1...` actions are bound to. `Scenes/ControlsScene.bs` sets it up.
- `Fight/CpuBrain.bs`: the CPU. Every so often it looks at the distance and what the player is doing, picks a short plan (block, anti-air, fireball, jump in, a normal or two, a throw), and plays it out as stick directions and presses, so it uses the same input path as a player.
- `Fight/Announcer.bs`: voice lines and stings go on sound channel 1 (`game.playSound(name, volume, channel)`), so hit sounds on channel 0 don't cut them off.
- `Entities/Fighter.bs`: movement and the move state machine, with separate `hurt` and `attack` colliders. The attack collider is enabled only during a move's active frames. `Entities/Projectile.bs`, `Entities/HitSpark.bs`.
- `UI/FightHud.bs`: health bars with a recent-damage trail, portraits, timer, KO badge, round stars, combo counter and announcements, drawn on the UI canvas (1280x720).

The fight runs at a fixed 60 Hz (so frame data means the same thing at 30 or 60 fps) on a 448x252 game canvas.

## Assets

Generated assets are rebuilt with scripts (each needs `npm install` at the repo root for `canvas`):

- `npm run build-sprites` cuts the animation frames named in `src/sprites/fighters/animations-<set>.json` out of each character's source art in `art/`: the two Mustermann sheets (35x29 grids of 997 frames, about 8000x6900 px), the RJD sheet (34x43) and Nova's animated GIF (561 frames, extracted with `ffmpeg`). Each frame is scaled, trimmed to its visible pixels and shelf-packed into one 2048-wide atlas per character and palette (about 2048x450, ~3.7 MB of texture memory; only the two fighting are loaded). `atlas.json` keeps each frame's rectangle and where the feet are in it, and the fighter sets its anchor per frame. Palette swaps recolour clothes by hue. It also writes `portraits.webp`. Attack animations list `startup`/`active`/`recovery` frames, and each list is stretched over that phase of the move, so the extended limb shows exactly while the hitbox is out.
- `npm run preview-animations` draws every animation as a strip of frames (attack strips mark the active frames) into `out/animation-previews/<character>.png`, for checking frame picks without running the game.
- `npm run build-ui-art` draws the announcement words, logo, HUD pieces, hit sparks, fireballs, floor and shadow into `src/sprites/ui/ui.webp` + `ui.json`. It also draws the splash screens, channel icons and title backdrop.
- `npm run synth-audio` synthesizes the whooshes, jump/land thuds, fireball, menu blips and the KO sting.

The voice lines, hits and grunts were converted from their packs to 22.05 kHz mono WAV, and the music to 64 kbps MP3, with `ffmpeg`.

## Still needed

- Frame picks and hitboxes in `MoveData.bs` are tuned by eye; they'd benefit from a careful pass against the art.
- More characters (Blaze and Frost share a moveset; Bruno and Nova have their own specials but share the normal-move frame data).
- More stages.
- Possible engine promotions to discuss: a hitbox/hurtbox frame-data helper, a motion-input reader, and a health bar widget with a damage trail in `BGE.UI`.

## Credits

- Blaze and Frost: [Fighting character template Mustermann 2 (karate)](https://opengameart.org/content/fighting-character-template-mustermann-2-a001aaaa001-karate) by Puffolotti, CC0.
- Bruno: [RJD MUGEN/Fighting character](https://opengameart.org/content/rjd-mugenfighting-character-based-on-bud-spencer-something-left-to-be-fixed) by Puffolotti, CC0.
- Nova: [Generic woman for fighting games (stardrinkers style)](https://opengameart.org/content/generic-woman-for-fighting-games-stardrinkers-style) by Puffolotti, CC0.
- Music: [Strap Yourselves In](https://opengameart.org/content/strap-yourselves-in) (title) and [To the Wire](https://opengameart.org/content/to-the-wire) (fight loop and victory outro) by congusbongus, CC-BY 4.0 / OGA-BY.
- Stage: [Industrial Parallax Background](https://opengameart.org/content/industrial-parallax-background) by Luis Zuno ([@ansimuz](https://ansimuz.com)), CC0.
- Announcer: [Voiceover Pack: Fighter](https://kenney.nl/assets/voiceover-pack-fighter) by Kenney, CC0.
- Hit and block sounds: [Fleshy Fight Sounds](https://opengameart.org/content/fleshy-fight-sounds) by will_leamon, OGA-BY 3.0.
- Grunts: [DAMAGE SOUNDS (Male) - Audio Pack](https://opengameart.org/content/damage-sounds-male-audio-pack) by VoiceBosch, CC-BY-SA 4.0. The converted `grunt*.wav` files are shared under the same license.
- Font: Viper Command, from [FontSpace](https://www.fontspace.com/viper-command-font-f157886) (see `src/fonts/CREDITS.md`).
- Synthesized sounds, logo and UI art: made for this example (`scripts/`).
