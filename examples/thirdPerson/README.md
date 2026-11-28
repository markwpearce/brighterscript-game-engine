# Night of the Barrow King

A third-person, souls-like action game in 3D ([#385](https://github.com/markwpearce/brighterscript-game-engine/issues/385)). So far: a walled town to start in, a graveyard and a three-level crypt below it with two bosses, a forest north of the town with an orc camp and its chieftain, and a knight on a flat field with a chase camera, movement and combat actions, and enemies that keep spawning 20-50 m away (a skeleton, an orc and a heavy orc in turn, up to 3 at once) to fight, with stamina, lock-on and a souls-style HUD, at night under a full moon with torches on the pillars. Bonfires are the checkpoints; enemies drop coins, and you drop them all where you die. Ripostes come later.

## Scenes

| Scene | Deep link | What's there |
| --- | --- | --- |
| Title (`TitleScene`) | (default) | The key art (the knight kneeling before the Barrow King), still, with the menu in a row along the bottom. **Continue** (when there's a save) picks up beside the last bonfire you rested at (before any, at the entrance of the scene the save was made in), **New Game** asks before wiping a save, **Options** has the music and sound volumes, **Controls** shows the remote's buttons and a QR code that opens the phone controller page (`game.enableControllerInput()`, port 8888), **Credits** rolls the credits. |
| Town (`TownScene`) | `scene=town` (`at=<col>,<row>[,<heading>]`) | A walled town at night: houses, huts and a keep round a cobbled square with a well and a bonfire beside it, fenced fields, a pig pen, torches, and townsfolk standing about, who'll talk to you (walk up and press OK). The gate in the south wall leads to the graveyard; the north gate, behind the keep, to the forest. |
| Forest (`ForestScene`) | `scene=forest` (`at=<col>,<row>[,<heading>]`, `bonfire=forest`, `slay=<seconds>`) | Optional: nothing on the main path needs it. A road winds north from the town's north gate between dense trees, past packs of goblins and hobgoblins, to a bonfire in a clearing, then past a werewolf roaming the road to the orc camp behind its palisade: hide tents, totems, crates and a campfire, orcs and heavy orcs, and the Orc Chieftain by the fire. Killing him gives the Orc Cleaver, a Barrow Flask and the Chieftain's Tusk; he stays dead for the run. The road's south end leads back into town. See [Forest](#forest). |
| Field (`FieldScene`) | `scene=field` (`enemies=<n>`, `types=<kind>,...`) | The arena for trying out combat: enemies keep spawning, a skeleton, an orc and a heavy orc in turn, or the kinds `types` lists (`skeleton`, `orc`, `heavyOrc`, `ghoul`, `graveBrute`, `goblin`, `hobgoblin`, `werewolf`, `orcChieftain`; `EnemyTypes.named()`), loading only their sheets; `enemies` caps how many at once (default 3). Nothing leads here; it's for testing. |
| Graveyard (`GraveyardScene`) | `scene=graveyard` | A fenced churchyard at night: graves, trees, a chapel, the gravedigger's hut and a well. Three skeletons wait among the graves, two of them heaps of bones, and wake when you come within 10 m (or hit one), the heaps getting up as their fall played backwards; killed ones stay dead until you rest or die. A bonfire stands just inside the gap in the fence. The mausoleum's door at the far end leads down into the crypt; the gap in the fence leads back to the town. |
| Crypt (`CryptScene`) | `scene=crypt` (`level=<1-3>`, `at=<col>,<row>[,<heading>]`) | A torch-lit stone maze three levels deep. The undead sleep in its corridors (every other skeleton as a heap of bones, which gets up as it wakes) and wake when they see you within 12 m, then find their way round the walls to you. Each level's name shows as you arrive. **The Crypt**: skeletons, and the Crypt Warden, a huge pale skeleton, in the hall at the far end; spirit fire seals the stairs down in its hall until it dies. **The Ossuary**, lit by blue spirit fire: skeletons, ghouls and a grave brute. **The Deep Tomb**, lit by green grave fire: the Barrow King guards the altar. A boss's health bar runs along the bottom once it wakes, and once killed it stays dead for the run. Bonfires burn by the first level's way up and in the Deep Tomb's corridor before the King's hall. The first level's way up leads to the graveyard. |
| Inside (`InteriorScene`) | `scene=keep`, `scene=chapel` (`at=<col>,<row>[,<heading>]`) | Walk up to the keep's door in town, or the chapel's in the graveyard, to go in. The keep's great hall: long tables and benches, a hearth either side, red and blue banners, the lord beside his throne. The chapel: pews either side of the aisle, stained glass windows, the priest before a candle-lit altar between two torches, candles in front of him. Walking into the doorway leads back out in front of the building. |

## Playing

| Action | Gamepad | Roku remote |
| --- | --- | --- |
| Move (relative to the camera) | Left stick | D-pad |
| Orbit the camera | Right stick | - |
| Lock onto the enemy in front, or release it; with none in front, recenter the camera behind the knight | L2 | Replay |
| Switch lock-on target | Flick the right stick left or right | - |
| Attack (press again during a swing to chain) | X | OK |
| Block (hold; walk slowly) | L1 | Play |
| Parry | B | Fast-forward |
| Dodge (roll toward the stick, or step back) | A | Rewind |
| Drink a healing draught | Y | `*` |
| Pause menu (Resume, Inventory, Options, Controls, Quit to Title); Back again closes it | Select | Back |

There are no control hints on screen: the pause menu's **Controls** page shows the remote and a gamepad side by side, each button labelled with what it does (`Menus/ControlsPanel.bs`). Its labels come from the control map (`describeBindings()`), so they follow the bindings in `main.bs`; where each button is in the pictures (the engine's input debug window's, `pkg:/source/engine/debug/images/`) is in `Menus/ControlPictures.bs`. The remote has no free button left for drinking, so `*` drinks and the debug panels (FPS, input, memory, GC, log, then entity details) need the `debug=1` deep link, where `*` cycles them too; the last level shows the knight's state top right (and the enemy count on the field).

Movement is relative to the camera, and the camera stays put until you move it.

**Items** (`Items.bs`, carried in `RunState`): healing draughts (3, refilled at a bonfire; drinking stands the knight still for about a second and heals 40% of his health, and a hit before then wastes it; a Barrow Flask adds one, up to 5), weapons and shields, which change only his numbers, and key items (the Chieftain's Tusk, for the forest). The pause menu's **Inventory** equips a weapon and a shield, with each one's numbers, and shows the draughts and key items. Quick slots bottom left show the shield, weapon and draughts left; coins are bottom right.

| Gear | Damage | Swing | Stamina | Where |
| --- | --- | --- | --- | --- |
| Longsword | 30 | 0.58 s | 22 | Start |
| Orc Cleaver | 40 | 0.70 s | 30 | The Orc Chieftain (forest) |
| Warden's Blade | 26 | 0.48 s | 18 | Merchant, 2400 |

| Shield | Blocks | Stamina per point blocked | Stamina regen while raised | Where |
| --- | --- | --- | --- | --- |
| Heater Shield | 80% | 1.5 | 35% | Start |
| Tower Shield | 92% | 1.2 | 20% | Merchant, 1600 |

Old Tobias, the old man by the square (`M` in `src/maps/town.txt`), sells them and a Barrow Flask (800) once each: his "Show me your wares" posts `openShop`, and the scene opens `Menus/ShopPanel.bs` when the conversation ends. The item icons are placeholders drawn by `tools/item-icons.py` (`src/images/item_icons.png`).

Deep links (`scene=...`, `at=...`) skip the title and don't save; debug links: `bonfire=<town|graveyard|crypt1|crypt3|forest>` wakes beside that bonfire, `save=1` loads the save and keeps saving, `die=<seconds>` kills the knight that long after arriving, `coins=<n>` sets the coins carried, `gear=<id>,...` gives and equips weapons and shields, `items=<id>,...` gives any items (ids in `Items.bs`: `longsword`, `orcCleaver`, `wardensBlade`, `heaterShield`, `towerShield`, `chieftainsTusk`, `barrowFlask`), `health=<percent>` starts the knight wounded, `slay=<seconds>` kills the Orc Chieftain that long after arriving in the forest (his rewards and banners without the fight). Otherwise the game saves on resting, a boss's death, your death, picking up dropped coins, equipping, buying, and arriving in each scene (`GameSave.bs`: one `BGE.SaveSlot`, registry section `nightOfTheBarrowKing`, with the scene, its entrance args, the story, the bosses killed and the `RunState`). Continue wakes you at the last bonfire, so progress is where you last rested, though coins and story carry on from the last save; the volumes are kept apart from it in a `BGE.SaveProfile` (`GameSettings.bs`), so a new game keeps them. The sound volume scales every effect; the music player (`roAudioPlayer`) has no volume, so the music slider only turns the music off at 0 (see Audio).

Locked on, the camera turns to keep the enemy in view beyond the knight, a white dot marks it, and the knight keeps facing it: he runs toward it, side-steps round it, backs away from it, and swings at it. Flicking the right stick switches to the next enemy in view that way. The lock drops when the enemy dies or gets more than 20 m away.

Each enemy telegraphs its attack with a wind-up, strikes, then recovers, which is your opening. Hitting it during the wind-up interrupts it; a parry during the strike leaves it staggered; blocking takes a fifth of the damage; dodging (mid-roll) takes none. Only one enemy attacks at a time, with a short gap between attacks, and only from where the camera can see it; the rest circle until it's their turn. A hit knocks an enemy back, and most then back off for a moment. Hits spray blood (bone dust from the skeleton), and blocks and parries throw sparks. When the knight dies the field clears and he gets up again.

Attacking, dodging and parrying cost stamina, and so does every hit you block (more for heavier hits). It refills after a short pause, more slowly while the shield is up. With none left you can't attack, dodge or parry (the stamina bar flashes), and a blocked hit that empties it breaks your guard and stuns you for a moment.

## Audio

The music streams; it isn't in the package (the BrightScript Simulator refuses a zip over about 7.1 MB). The four tracks in `music/` (mono 80 kbps 32 kHz MP3s, outside `src/`) play from `https://raw.githubusercontent.com/markwpearce/brighterscript-game-engine/<ref>/examples/thirdPerson/music/<file>` with `game.musicPlay(url, true, false)`, so a track shared by the next scene carries on.

| Track | Where |
| --- | --- |
| `the_march_upon_the_red_mountain.mp3` | The title screen, and a boss fight (from when the boss wakes until it dies, or you die or leave; then the area's track starts again from the top) |
| `RPG_The_Lost_Town.mp3` | The town, the keep and the chapel |
| `foreboding_theme.mp3` | The graveyard, the crypt and the field |
| `the_wraiths_of_winter.mp3` | The forest |

Deep links: `musicRef=<branch>` streams the tracks from another branch (e.g. `musicRef=feat/754-audio` before they reach `main`), `music=0` turns the music off, `sfxLog=1` prints each sound effect on the console. The console always shows `[audio]` lines: the track's URL as it starts and the music player's status (`start of play`, or `music failed: ...`).

`GameAudio.bs` (a persistent entity, `Audio.current(game)`) owns it all. A scene picks its music with `m.musicTrack = MusicTrack.<track>` in its constructor (`ThirdPersonScene.readCommonArgs()` starts it); `playArea()` and `setBossFight()` do the rest (`CryptScene` calls `setBossFight()` every frame). Effects are sound groups played with `Audio.current(m.game).play("<group>")`: one of the group's variants at random, at the sound volume setting, and not again within the group's gap. The knight, the world and the menus play on channel 0 and enemy voices on channel 1 (the Express has 2; a one-channel device plays both on 0, and a new sound on a channel cuts off the last).

| Group | When | Sounds (`src/sounds/`) |
| --- | --- | --- |
| `swing` | the knight swings | `swing1`, `swing2` |
| `dodge` | he rolls or steps back | `dodge` |
| `block`, `parry` | a blocked hit (his or an enemy's), a parry | `block`, `parry` |
| `drink` | a draught heals (`draughtDrunk`) | `drink` |
| `coin` | coins from a kill, picked up, or spent at the shop | `coin` |
| `equip` | equipping gear | `sword_unsheathe` |
| `door` | going through any scene exit | `door` |
| `bonfire` | resting | `bonfire` |
| `orc`, `giant`, `undead`, `beast`, `bite` | an enemy's voice (`EnemyType.voice`): as it winds up an attack, is hit and dies. Orcs and ghouls `orc`; heavy orcs, grave brutes and the Barrow King `giant`; skeletons and the Crypt Warden `undead`; `beast` (werewolves) and `bite` (goblins) for the forest | `orc1`-`2`, `giant1`-`2`, `shade1`-`2`, `beast`, `bite` |
| menus | focus and click on every button (`game.uiFocusSoundKey`/`uiClickSoundKey`, at `game.uiSoundVolume`) | `ui_focus`, `ui_click` |

No sound yet for a blade hitting flesh, footsteps, the bonfire's crackle, death, or rattling bones (the pack has none).

## Bonfires, death and coins

- Walk up to a bonfire and press OK (X) to rest: full health, draughts refilled, the scene's enemies (not bosses) back in their places, the game saved, and this bonfire is where you wake. "BONFIRE LIT" the first time, "RESTED" after. You can't rest with an enemy awake within 12 m.
- Dying wakes you at the last bonfire, in another scene if it's elsewhere (`changeSceneWithFade()` with `Bonfires.sceneArgs()`); before any, where you came into the scene. Enemies come back; bosses stay dead.
- Each `EnemyType` has `coins` (bosses many more). On death every coin carried drops where you fell, as a small spirit flame (`Entities/CoinMarker.bs`); walk onto it to get them back. Dying again first loses them.
- `Bonfires.bs` lists every bonfire (id, scene, crypt level, cell, and the cell beside it you wake toward); `ThirdPersonScene.addBonfires()` places a scene's own. `RunState.bs` holds the run: coins, draughts, the bonfire to wake at, the ones lit, the dropped coins. The bonfire's stones and sword are `bonfire.obj` from `tools/make-props.py` (62 triangles) under a big `Torch` flame.

## How it works

- `Scenes/TitleScene.bs` draws the key art (`src/images/Splash_HD.jpg`, the splash screen's own image, so the splash runs straight into the title) and the menu in a row along its bottom (`Menus/TitleMenu.bs`: text items stepped through with left and right, the focused one underlined). `Menus/` has the options panel (a `BGE.UI.MenuList` with two `BGE.UI.Slider`s over its Done button), the controls page (a `BGE.UI.MenuList` that draws the remote and gamepad pictures with labelled leader lines above its Done button), the pause menu (a `BGE.PauseMenu` on the raw Back button: a remote binding would also match a gamepad's B, an alias of Back) and the menus' colours (`MenuTheme.bs`, the dialogue box's too). The title and headings are in Bluu Next, everything else in EB Garamond (`src/fonts`). The channel icons and splash are painted key art with the title lettered on (`art/title/`).
- `World.bs`: the world scale (32 units per metre, so the knight is 64 units tall) and heading helpers.
- The chase camera is a `BGE.OrbitCamera` with a `BGE.CameraBoom`, set up in `Scenes/FieldScene.bs`. It sits 4 m behind and 1.8 m up, looking at 1.2 m, so the knight fills about half the screen. The right stick orbits (x) and tilts (y) it around that point.
- `Entities/Knight.bs`: a 16-direction `DrawableOrientedSprite`, drawn `axisAligned` so he foreshortens as the camera tilts down, and a small state machine (idle, run, strafe, attack, block, parry, dodge). Locked on, moving sideways plays the side-step (backwards to step left) and moving away plays the run backwards, both at 1.8 m/s with their frame rates matched to it so the feet don't slide. Chained attacks replay the attack with `playOrientedAnimation(name, restart = true)`.
- `Stamina.bs`: the knight's stamina pool. `spend()` starts an action if there's any stamina left (it can take it to zero); `drain()` takes a blocked hit's cost and says whether the guard held.
- `Hud.bs`: health and stamina bars, top left in the title-safe area. Lost health stays as a pale chunk that drains after a moment.
- `Entities/Fighter.bs`: what the knight and the enemies share: health, a round body, knockback and a red flash when hit.
- `Night.bs`: the moonlight (a cool `DirectionalLight` from where the moon is in the sky) and a blue `AmbientLight`. They shade the ground, the pillars and the fighters' sprites (`isShaded`, lit as cut-outs facing the camera, with `lightWrap` 0.5 so a back-lit figure stays dim rather than black).
- `Entities/Torch.bs`: a flame and a `PointLight` that pools on the ground and lights the pillars and anyone near it: warm firelight, or cold blue spirit fire. The lights never flicker, because a changing light relights everything it reaches every frame. The flame is one unlit, looping `AnimatedImage` drawn once per kind at startup (squares that rise, shrink and cool), shared by every torch: a particle emitter per torch cost about 1 ms a frame each.
- The sky is a `DrawableSkybox` panorama drawn by `tools/night-sky.py` (`python3 tools/night-sky.py src/sprites/night_sky.webp`, needs ImageMagick): deep blue with clouds, stars, a distant tree line and the moon, placed where `Night.bs`'s moonlight comes from. The far half of the 40 m draw distance fades out (`drawDistanceFadeFraction` 0.5) into the sky's dark below the horizon.
- `Entities/HitEffect.bs`: a one-off particle burst where a blow lands (blood, bone dust, block and parry sparks), using `DrawableParticles` with its particles made by hand so they fan out round the ground direction of the hit.
- `CombatDirector.bs`: knows the player and the enemies, pushes overlapping bodies apart (so nobody walks through anybody; lighter bodies move further), finds who a swing hits, hands out the attack slot (one at a time, with a gap between attacks, only to enemies in view).
- `Entities/Enemy.bs`: a 16-direction monster, rendered like the knight, with a small AI. While it's waiting for an attack slot (or out of view) it circles the player; otherwise it closes in (straight, or flanking round to the player's side first) and attacks: wind-up, strike, recover, then either stays close or backs off. A hit knocks it back and, during the wind-up, interrupts it, after which it backs off; some enemies block hits from the front, and heavy ones shrug hits off.
- `Entities/EnemyTypes.bs`: the enemies, as data. Everything that makes one different (size, blood colour, speed, health, weight, how it approaches, what it does after attacking, block chance, and the attack's range, reach, arc, timing, damage and lunge) is a field of `EnemyType`, so a new enemy is a new function here:
  - Skeleton: flanks, sometimes blocks, a quick sword swing.
  - Orc: quick, no armour; comes straight at you, chops, then backs off.
  - Heavy orc: slow and tough, blocks often, never flinches; a long wind-up and a heavy hit.
  - Ghoul and grave brute: the orc and heavy orc greyed (`tint`), with a faint `glow` so they show in the dark; the ghoul is quicker and frailer than the orc.
  - The Barrow King: the heavy orc half again as big and bronze-dark, with a long reach and a crushing swing that often comes twice.
  - Goblin: small, fast and frail, with a spear; flanks round to your side, jabs quickly, then backs off.
  - Hobgoblin: a bigger goblin with a knife and twice the health; comes straight in, and more often than not stabs twice (`comboChance`).
  - Werewolf: the forest's elite. Fast, with a long reach and a leaping swipe that covers 2 m; barely flinches and recovers quickly from a parry. Its sheet is rendered `--mirror` (`mirrored`: `DrawableOrientedSprite.mirrorBuckets` draws its left side flipped).
  - The Orc Chieftain: the heavy orc 1.4 times as big and dark red, with a wide reach and a heavy swing that often comes twice (`comboChance`); quicker and frailer than the Barrow King.
  - Crypt Warden: the skeleton's sheet drawn half again as big (`scale`), pale (`tint`) and faintly glowing (`glow`, its sprite's `ambientBrightness`), so it shows in the dark. Never flinches, reaches far, and half its strikes go straight into a second, quicker one (`comboChance`: the second wind-up is half as long), so roll twice or block the second.
- Given a `BGE.NavGrid` (`nav`), an enemy wakes only when it can see the knight, and with a wall in the way it follows a path round it instead of circling: a `BGE.NavFollower` checks sight four times a second and re-plans twice a second. The crypt builds one from its `SolidWorld`, its walls grown by the biggest body radius among that level's undead.
- `Hud.drawBossBar()` and `drawBanner()`: a boss's name and health along the bottom, and a line that fades in and out across the middle (a level's name, "THE WARDEN FALLS").
- `Crypt/CryptLevels.bs`: each crypt level as data: its text grid (`E` up, `D` down, enemy and prop characters; the key is above `layout1()`), ambient light, what its torches burn (`FlameKind`) and its boss. `CryptScene` is every level: changing to it with `{level, from: "above" | "below"}` reloads it as that level, starting by the stairs you came through, and loads only the sprite atlases that level's enemies use.
- `Scenes/FieldScene.bs`: loads every character's packed sprite sheets in `onLoad()` (`loader.loadSpriteAtlas()`; each sprite then gets its shared frames from `game.getSpriteAtlasFrames()`), the ground plane (grass at 2 world units per texel, so the device's plane cap lets it reach twice as far), the sky, lights and torches (deep link `night=0` turns them off, for measuring), the enemy spawner, respawning and the HUD.
- `Scenes/GraveyardScene.bs` and `Graveyard/GraveyardMap.bs`: the graveyard is a text grid of 2 m cells (`GraveyardMap.layout()`, its key in the comment above it), so editing the layout is editing text. Every map here (`CryptLayout`, `InteriorLayout`, `GraveyardLayout`, `TownLayout`, `ForestLayout`) extends the engine's `BGE.CharGrid`, which finds the groups and runs of characters and places cells in the world; each map decides what its characters mean. Runs of `f` become one `Fence` each (a see-through, double-sided `DrawableWall` repeating the picket image every 3 m). Each group of `p`, `c` or `h` cells is one building (`PropModel`: a textured `.obj` in metres, scaled to the world, with a camera blocker), centred on its cells. Graves and trees (`Prop`, shaded camera-facing cut-outs) are jittered by a random number fixed per cell, so the layout looks the same every time. Fences, buildings, graves and trunks are solids in a `BGE.SolidWorld`, which keeps the knight and the skeletons out of them: each is tracked (`SolidWorld.track()`) and `ThirdPersonScene` calls `resolveTracked()` once bodies have been pushed apart, before the camera follows (the crypt and interiors do the same for their walls).
- `Scenes/` pass `{from: ...}` to `changeSceneWithFade()`, so the next scene starts you at the matching entrance: up from the crypt you're outside the mausoleum door, down from the graveyard you're just inside the crypt's doorway.

## Town

- `src/maps/town.txt`: the town as a text grid of 2 m cells (its key is the comment at the top). `Town/TownMap.bs` reads it at runtime (`ReadAsciiFile`) and finds each connected block of a building kind, so there can be many houses. A building's door faces whichever end of it has more street or path next to it; a house or hut on its side (4×3 rather than 3×4 cells) turns to face east or west.
- `tools/town-ground.py` (`python3 tools/town-ground.py`, needs Pillow and numpy) paints the ground from the same file into `src/sprites/town_ground.webp`, 16 texels per cell: cobbles, dirt, grass, crops, ploughed earth and mud, with ragged edges and a glow round each standing torch. `TownScene` draws it as one `staticImage` `DrawablePlane` at 4 world units per texel. A static plane gets no light pools, hence the baked glow.
- The town has a 33 m draw distance (`draw=<metres>` overrides it), its end hidden by the engine fog (`camera.fog`, set up in `ThirdPersonScene.useTownFog()`, which the graveyard shares): things fade into the fog colour rather than into the sky, and buildings and the town wall stay on the skyline as fog-coloured silhouettes past the draw distance. `fog=0` turns it off, in the graveyard too. Occlusion culling is off in the town (its open streets hide too little to pay for it; `occlusion=1` turns it on).
- Every prop (`PropModel`) is `isStatic`, so it never checks collisions itself, and only the big buildings block the camera.
- The town wall is four inward-facing `DrawableWall`s (`Entities/TownWall.bs`), since the knight never sees the outside: far cheaper than the `wall_segment` models. The corner towers and the gate are models.
- Talking: walk up to someone and face them, and OK (X) talks instead of swinging. `TownStory.bs` plays `src/story/town.json` through a `BGE.Story.StorySession` in a `BGE.Story.DialogueView` box along the bottom (OK reads on, up and down pick a choice, Back leaves; the box pauses the game). One session lasts the whole run, so what's been said carries between scenes; the crypt posts `cryptBossSlain`, and the story's rules turn it into `crypt.*` flags. Lord Aldric in the keep sends you to the crypt, Father Edmund in the chapel can bless you (heals), and the villagers say a line each. A scene makes someone talk with `addTalker(entity, node, name)`; `ThirdPersonScene.beginUpdate()`, first in every scene's `onUpdate()`, runs the conversation.
- `Scenes/InteriorScene.bs`, `Interior/Interiors.bs`: inside the keep and the chapel. Each is a text grid of 2 m cells (its key above `Interiors.keep()`) like the crypt's: one `DrawableGridWalls` for its stone walls, a `BGE.GridWallsCameraBoom` that pulls the camera in by marching the walls' grid (no colliders), black fog. Furniture has no art: each rectangle of a furniture character is a plain shaded box (`Entities/BoxProp.bs`, each box its own model so it sorts by its own centre), with a solid. The hearths and throne are boxes too, built in the scene. `Torch`'s `size` makes the candles small. The door, banners (`f`) and windows (`w`, unlit so the glass glows) are `Prop` images flat on the walls, from `tools/interior-art.py` (`python3 tools/interior-art.py src/sprites`, needs ImageMagick).
- `Dressing.bs` has the scenery the town and graveyard place the same way: picket fences, trees (`Y` in `town.txt`, `T` in the graveyard), torches on wall brackets, and the graveyard's stone lantern posts: firelight, except the blue spirit flames either side of the mausoleum's door, the only blue light above ground.
- Torches stand on a flat post image (`Torch`'s `post` arg, far cheaper than a model while the camera moves) or hang from `torch_wall` brackets (by the gate, either side of the keep's door, which `keep.obj` draws 2.5 m off the middle of its front, and by the doors of the houses turned to face a cross street), the flame at the bracket's tip.
- `Entities/Townsfolk.bs` stands a person, picked and turned by a number fixed per cell (most face the well); only those within 10 m of the camera (at Medium quality: 6 m at Basic, 20 m at Ultra, by the quality's `animationLodDistanceScale`) play their idle loop, the rest hold one frame. `Town/TownsfolkTypes.bs` has each sheet's anchor and frames. `Entities/Pig.bs` ambles round the pen.

## Forest

- `src/maps/forest.txt`: the forest as a text grid of 2 m cells, 40 by 60 (its key is the comment at the top; comment lines start `# `, since a row of dense forest starts with `#`). `Forest/ForestMap.bs` reads it at runtime; `#` is solid, one `SolidWorld` solid per row's run of it. `Scenes/ForestScene.bs` places a `Dressing.addTree()` on each `Y` (52 of them), the enemies (`g`, `h`, `w`, `o`, `O`, `C`, asleep until they see the knight within 12 m, or the chieftain within 10 m, through a `BGE.NavGrid` like the crypt's, so the trunks and the palisade block their sight and they path round them), and the camp: each straight run of `p` is a 3 m palisade (a `Fence` with the palisade tile, `Dressing.palisadeRegion()`), each 2x2 `T` a tent facing the campfire, `F` the campfire (`campfire.obj` under a big `Torch` with a 14 m light), `t` totems, `c` crates, `l` torches on posts.
- The werewolf roams between the two `w` cells while it sleeps (`Enemy`'s `roamTo`: it walks at 40% of its speed and turns back at either end).
- The Orc Chieftain (`EnemyTypes.orcChieftain()`) has the boss bar once he wakes. When he dies the scene marks him killed (`SaveData.markBossSlain("chieftain")`, saved in `bossesKilled`, so he stays dead), posts `forestBossSlain` (town.json's rules set `forest.chieftainSlain`, and a villager talks of the orcs on the north road until then, and of the tusk after), grants the Orc Cleaver, a Barrow Flask and the Chieftain's Tusk (`RunState.grantItem()`), shows a banner for each, and saves.
- `tools/forest-ground.py` (`python3 tools/forest-ground.py`, needs Pillow and numpy) paints the ground from the same file into `src/sprites/forest_ground.webp`, 16 texels per cell, like the town's: the road, forest floor, leaf litter, mud, dark undergrowth under the dense forest and the camp's trampled earth, with dark roots round each tree and glows round the fires. Drawn as one `staticImage` plane at 4 world units per texel; fog as the town's (`useTownFog`), a 30 m draw distance.
- Only the forest's sheets load: goblin, hobgoblin, werewolf, orc and heavy orc (the chieftain is the heavy orc's), and the knight's. On the Roku Ultra the whole scene takes about 92 MB of texture memory (of 240 MB).
- Frame rate on the Roku Ultra (`perf=phases`, adaptive quality on): about 20 fps on the road with the camera orbiting or walking, 40 standing still; about 18 orbiting in the camp, 56 still. On the road the trees are the cost (about 0.25 ms each while the camera moves, mostly updating and culling ones out of view): 74 trees ran at 18.5 fps, so there are 52; `trees=0` leaves them out, for measuring. In the camp it's the models (about 3 ms each drawn while the camera moves), so it has 3 tents, 2 totems and 3 crates.
- Music: the forest's track (The Wraiths of Winter), and the boss track while the chieftain fights (`Audio.current(game).setBossFight()`, as in the crypt).

## Graveyard art

- `src/models/props/`: the mausoleum, hut, well and fence, the town's walls, gate, tower, house, keep and torches, the bonfire, the orc camp's tent, campfire, totem and crate (6 to 36 triangles each) and palisade tile, one 256×384 px texture atlas for all of them, and the gravestones. All procedural, from `tools/make-props.py` (`python3 tools/make-props.py`, needs Pillow and numpy), which writes them there.
- `src/models/chapel/`: the chapel from `examples/terrain`.
- `src/sprites/tree_<n>.webp`: five autumn trees. The originals are isometric sprites with a shadow drawn in; `node tools/trees.js <folder of Sprite_0N.png>` clears the shadow (near-black, at most half opaque), trims them and scales them to 320 px tall. Each trunk's foot is in `Dressing.addTree()`, since some trees' low branches hang below it.

## Sprite sheets

The knight and the monsters are re-rendered from Flare-style Blender sources (Clint Bellanger's knight and skeleton, johndh's orc; see [CREDITS.md](CREDITS.md)) at the chase camera's angle (12 degrees above horizontal), all at the same scale (64 px for the knight's 1.8 Blender units, which is 2 m in the game), 16 directions, front first then clockwise from above. Flare's monsters are big next to its hero, so they're rendered a little smaller (`--height 56`, or 58 for the heavy orc, against the knight's 64). The orcs' skin is recoloured a grey-green (about `#9AAE93` once lit) with dark hair (`ORC_COLOURS` in `tools/characters.py`), and every attack gets in-between frames: 9 for the knight; for the monsters 8 drawing back to the top of the swing and 4 for the strike, in place of Flare's 4. The knight's block, hit and death get in-betweens too, so every action plays at 12 fps or more: a monster's wind-up plays at 12 fps or faster and then holds the top of its swing (`BGE.frameRateFor()`'s `minFrameRate`). Each sheet is packed: every frame is trimmed to its own pixels and placed 2 px from the next (so a neighbour doesn't bleed in when an HD device loads the sheet shrunk), and a `.json` alongside lists each frame's rect and its offset in the untrimmed cell (loaded with `loader.loadSpriteAtlas()`).

| Sheet | Source | Frames per direction | Untrimmed cell | Texture |
| --- | --- | --- | --- | --- |
| `knight.webp` | [`isometric_hero_heroine_blend.zip`](https://opengameart.org/content/isometric-hero-and-heroine): `steel_armor.blend` with `male_head1`, `longsword` and `shield`, plus the moves `tools/knight-moves.py` keys | 54 | 92×89 | 14.9 MB |
| `skeleton.webp` | `skeleton_0.blend` | 30 | 112×75 | 8.2 MB |
| `orc.webp` | `orc_flare_0.blend`, layer 2 (hand axe) | 29 | 102×84 | 7.0 MB |
| `orc_heavy.webp` | `orc_flare_0.blend`, layer 5 (armour, shield, axe) | 26 | 116×101 | 9.2 MB |
| `goblin.webp` | [`goblin.blend`](https://opengameart.org/content/goblin) (`--height 64`) | 29 | 94×51 | 3.4 MB |
| `hobgoblin.webp` | [`knife_hobgoblin.blend`](https://opengameart.org/content/flare-mod-hobgoblin) (`--height 76`) | 29 | 87×54 | 4.3 MB |
| `werewolf.webp` | [`Werewolf.blend`](https://opengameart.org/content/flare-mod-werewolf) (`--height 76 --mirror`: 9 directions) | 29 | 99×81 | 4.4 MB |
| `peasant_m.webp` | [Flare NPCs](https://opengameart.org/content/flare-npcs-animated-pack-1) `art/npcs/MalePeasant.blend` (`--height 62`) | 4 (idle) | 62×68 | 1.0 MB |
| `peasant_f.webp` | `FemalePeasant4.blend` (`--height 61`) | 4 | 73×68 | 1.0 MB |
| `nobleman.webp` | `Nobleman.blend` (`--height 60 --mirror`) | 4 | 51×67 | 0.4 MB |
| `noblewoman.webp` | `NobleWoman1.blend` (`--height 64`) | 4 | 64×65 | 1.0 MB |
| `old_man.webp` | `OldMan.blend` (`--height 58`) | 4 | 57×63 | 1.0 MB |
| `priest.webp` | `LuxPriestNPC.blend` (`--height 60`) | 4 | 76×79 | 1.1 MB |
| `pig.webp` | `Pig.blend` (`--height 34 --mirror`): idle, and a walk from `Armature.001Action` | 12 | 40×23 | 0.3 MB |

1. The sources are in `art/` (the townsfolk in `art/npcs/`), unchanged from their downloads. The knight's, the skeleton's, the orc's and the goblin's are Blender 2.49 files, the hobgoblin's and werewolf's 2.6x and the townsfolk's 2.79, and Blender 5 drops their animation (the 2.49 ones) and their procedural textures. Convert each one with Blender 2.79, which re-saves it and rebuilds its materials as Cycles nodes:

```
blender -b art/skeleton_0.blend --python tools/convert-flare.py -- <converted>/skeleton_0.blend
```

   Then, for the knight, key the moves Flare doesn't have (a roll, a backstep and a side-step) into the converted `steel_armor.blend`, `male_head1.blend`, `longsword.blend` and `shield.blend`, with Blender 5. It poses the rig from Flare's own frames, in code, so it's re-run rather than edited in Blender:

```
Blender -b --python tools/knight-moves.py -- <converted>
```

2. Render with Blender 5 (Cycles, with a shadow catcher for the ground shadow), using the engine's generic `tools/render-character.py` at the repo root. `--config tools/characters.py` gives it this game's characters, and `--character` picks one: its frames, layers, parts and colours (see `CHARACTERS` in `tools/characters.py`). `--packed` trims and packs the frames into sheets of at most `--sheet-size` (2048) px, with the `.json` frame list. It prints the cell size, the feet anchor, the frame columns of each animation and the texture size; the anchor and columns go in `Knight.bs` or `EnemyTypes.bs`:

```
Blender -b <converted>/steel_armor.blend --python ../../tools/render-character.py -- --config tools/characters.py --character knight --parts <converted> --packed --out <somewhere>/knight.webp
Blender -b <converted>/skeleton_0.blend --python ../../tools/render-character.py -- --config tools/characters.py --character skeleton --height 56 --packed --out <somewhere>/skeleton.webp
Blender -b <converted>/orc_flare_0.blend --python ../../tools/render-character.py -- --config tools/characters.py --character orc --height 56 --packed --out <somewhere>/orc.webp
Blender -b <converted>/orc_flare_0.blend --python ../../tools/render-character.py -- --config tools/characters.py --character orc-heavy --height 58 --packed --out <somewhere>/orc_heavy.webp
Blender -b <converted>/goblin.blend --python ../../tools/render-character.py -- --config tools/characters.py --character goblin --height 64 --packed --out <somewhere>/goblin.webp
Blender -b <converted>/knife_hobgoblin.blend --python ../../tools/render-character.py -- --config tools/characters.py --character hobgoblin --height 76 --packed --out <somewhere>/hobgoblin.webp
Blender -b <converted>/Werewolf.blend --python ../../tools/render-character.py -- --config tools/characters.py --character werewolf --height 76 --packed --mirror --out <somewhere>/werewolf.webp
```

Copy the `.webp` sheets and the `.json` into `src/sprites`. Without `--packed` it writes a full grid instead, wrapping at `--columns`. Add `--mirror` to render only the front-to-back half of the directions, for `DrawableOrientedSprite.mirrorBuckets`.

The frames it renders are kept in a `<character>_<height>_frames` folder next to the sheet, so render outside `src/`. They aren't keyed by colour, so clear them after changing `colours`.

Flare's actions put stance at frames 1-4, run 5-12 and melee 13-16 (drawn back at about 14.5); the knight has block 17-18, hit 19-20, die 21-24, cast 25-28 and a thrust 29-32, and `knight-moves.py` adds a roll 41-48, a backstep 49-52 and a side-step to his right 53-60; the skeleton has block 17-18, hit 19-20 and die 21-28, and the orc hit 17-18, die 17-24, cast 25-28 and block 29-32. The goblins differ: stance 1-4, a hop 5-12, run 13-20, a jab 21-24, a throw 25-28, hit 29-30 and die 37-40; and the werewolf's action has stance 0-8, run 9-16, a rearing swipe 17-20, a recoil 21-23 and die 24-28. The goblins' skin is recoloured (dark green, and a ruddy brown for the hobgoblin), and the werewolf's pale fur toned down so it doesn't burn out white. The goblin is rendered at the knight's scale (64) and the hobgoblin and werewolf a little over it (76), so they stand up to him; the werewolf is unarmed and near enough symmetric for `--mirror`.

## Still needed

- [ ] The four packed sheets take ~39 MB of texture memory, still a lot for HD devices (64 MB). Mirrored directions (`--mirror`) can't help: the characters are handed (sword in the right hand, shield in the left), so a mirrored direction would swap them.
- [ ] Furniture art for the interiors.
- [ ] Ripostes and backstabs.
