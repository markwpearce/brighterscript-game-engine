# Night of the Barrow King — design

Finishing `examples/thirdPerson` (#385) as a short game. Kept in `specs/`, not `docs/`, so it
stays off the published site.

## Intent

`examples/thirdPerson` has an engine showcase but not a game: no title, no saving, no
checkpoints, no items. Turn it into a **20–40 minute showcase game** that starts at a title
screen and ends with the Barrow King dead and the credits rolling. The game should show off the 3D
renderer and the engine's game-shell pieces (saves, menus, audio, story) the way `rpg` does in 2D.

- **Goals:** play start to finish with a controller (Roku remote still works); a title screen
  with Continue / New Game; saving at bonfires; souls-lite inventory and gear; drop-and-recover
  coins on death; music and sound; an optional forest with an orc camp; new enemies (goblin,
  hobgoblin, werewolf).
- **Non-goals:** a store-ready product, multiple save slots, armour slots or random loot with stats,
  new knight animations (tracked separately in #385's comment), a day/night cycle.
- **Anti-goals:** dropping below the target frame rate (30fps mid-range, holding on HD) or
  overrunning HD's 64 MB texture memory, for example by loading every creature atlas at once.
  Making the existing areas harder to reach. Engine changes that only this example needs: those
  belong in the example.

## Approaches

1. **Sub-issues under #385, one PR each (chosen).** Each piece lands, gets tested on a device and is
   reviewed separately, in dependency order. Fits the repo's one-PR-per-issue rule.
2. One long branch for #385. It reaches a playable whole sooner, but makes a huge PR that's hard
   to review and to test on a device.
3. Build everything as a spike, then split it into PRs. That's double the work, and splitting
   afterwards tends to leave PRs tangled together.

## What exists today (builds on)

- Scenes: Town (start), Graveyard, Crypt (3 levels; Crypt Warden, Barrow King), Keep/Chapel
  interiors, Field (test arena). `ThirdPersonScene` is the shared base (knight, fog, camera, talk,
  respawn).
- Combat, stamina, lock-on, HUD (health/stamina, boss bar, banner), `BGE.Story` dialogue with a run
  long `StorySession` (`TownStory.bs`, `src/story/town.json`).
- Engine pieces already there: `BGE.SaveSlot`/`SaveProfile` (versioned, `migrate()`),
  `StorySession.toSaveData()`/`loadSaveData()`, `BGE.PauseMenu`, `BGE.UI.MenuList`/`Slider`/
  `CreditsView`, `SplashSequence`, `Game.loadSound()/playSound()`, `Game.musicPlay()/musicStop()`.
- Death today respawns the knight *in the current scene* at its entrance.

## The game

### Story beats (main path)

1. **Title → New Game.** The knight starts in the town square at night.
2. **Lord Aldric** (keep) sends you to the crypt (existing dialogue).
3. **Graveyard** (south gate) → **Crypt**: the Crypt Warden, Ossuary, Deep Tomb, then the
   **Barrow King**.
4. Killing the Barrow King plays a closing banner, returns you to Aldric for his existing
   "slain" lines, then **credits** (`BGE.UI.CreditsView`), then back to the title. The save is
   kept, so Continue loads the finished world.

**Optional side path:** a **north gate** behind the keep opens on a forest road. In the forest:
goblins and hobgoblins, a roaming werewolf (rare elite), and the **orc camp** with an **Orc
Chieftain** mini-boss (a scaled, tinted heavy orc, like the Crypt Warden). Clearing the camp gives
you a better sword and coins. A villager's dialogue hints at the orcs raiding the north road. One
new story flag: `forest.chieftainSlain`.

### Bonfires (checkpoints)

- A bonfire is a lit prop with a warm `PointLight` (`Torch`'s flame at a bigger size, on a ring of
  stones and a sword stuck in the ground). Walk up and press OK to **rest**.
- Resting: full health, draughts refilled, non-boss enemies respawn, **game saved**, and this
  bonfire becomes the respawn point. A short banner ("Bonfire lit" the first time, "Rested" after).
- Placement (5): town square (by the well), graveyard (by the gate), crypt level 1 (entrance),
  crypt level 3 (before the King's hall), forest (the road's mid-point, before the camp).
- Respawning crosses scenes: dying in the crypt can put you back in the graveyard if that's where
  you last rested. `ThirdPersonScene.respawnKnight()` becomes "change scene to the last bonfire's
  scene + spot". Before the first rest (a New Game, a deep link, the Field) it keeps today's
  behaviour: the current scene's entrance.

### Death and coins

- Enemies drop coins when they die (an amount per `EnemyType`, more from bosses).
- On death you **drop all carried coins** where you fell, shown as a glowing marker (a small
  `Torch`-style spirit flame). Reach it again to pick them up. Dying again before then loses them,
  and the new drop replaces the old one. One marker at a time, saved with its
  location (scene plus its args: the crypt level, or keep or chapel, since `CryptScene` and
  `InteriorScene` each run several places) and position.
- Bosses stay dead once killed (saved); other enemies come back when you rest or die.

### Inventory and gear (souls-lite)

- **Healing draughts:** 3 to start, max 5 (2 upgrades to find: one in the crypt, one at the orc
  camp). A quick slot; a gamepad button (and a remote button: see *Left to the
  builder*) drinks one: a short animation-lock, heals 40% max.
- **Coins:** HUD counter bottom right.
- **Weapons (stats only; the sprite keeps drawing the same sword):**
  - *Longsword*: start; balanced.
  - *Orc Cleaver*: orc camp reward; more damage, slower, more stamina.
  - *Warden's Blade*: from the merchant, expensive; faster, slightly less damage.
- **Shields (stats only):** *Heater Shield* (start) and *Tower Shield* (merchant; blocks more,
  slower stamina regen while raised).
- **Key items:** none needed for the main path. *Chieftain's Tusk* (proof for a villager line).
- **Merchant:** an existing townsperson becomes the trader (the old man by the square, using the
  existing sheet), selling draught upgrades, the Warden's Blade and the Tower Shield, through
  dialogue choices in `town.json` plus a small buy-list screen.
- **Inventory screen** from the pause menu: equip weapon and shield, view key items and draughts.
  Built from `BGE.UI.MenuList` with item icons.
- HUD quick slots bottom left: shield, weapon, draught (with count). Title-safe, and above the
  boss bar (`Hud.drawBossBar()` spans 20–80% of the width near the bottom), which they and the
  coin counter mustn't overlap.

### Title screen and menus

- `TitleScene`: a live 3D backdrop: the graveyard at night with the camera slowly circling, fog on,
  the logo text over it. Menu: **Continue** (only if a save exists), **New Game** (asks before
  overwriting), **Options**, **Credits**.
- **Options:** music on/off and sound volume (`BGE.UI.Slider`), saved in a `SaveProfile` separate
  from the game save. Music is on/off, not a slider: `Game.musicPlay()` uses `roAudioPlayer`,
  which has no volume control (only `playSound()` takes a volume).
- **Pause menu** (`BGE.PauseMenu`; not its default `play`, which blocks; see *Left to the
  builder*): Resume, Inventory, Options, Quit to Title (no save: progress is only kept at
  bonfires).
- Deep links still go straight into a scene (testing), skipping the title. A deep-linked launch
  turns the game save off (`SaveSlot.enabled = false`) so a test run can't overwrite a real save.
- **New Game, Continue and Quit to Title reset run state:** the story session (`TownStory.session()`
  is made once in `main()`) and `GetGlobalAA().cryptBossesSlain` are rebuilt from scratch or from
  the save, so nothing unsaved carries over.

### Saving

- One slot, `BGE.SaveSlot("nightOfTheBarrowKing", "save", version 1)`.
- Written when: resting at a bonfire; a boss dies; **on death** (so quitting can't undo losing the
  coins); buying from the merchant.
- Contents: last bonfire id; coins; draughts (count, max); owned and equipped gear; key items;
  bosses killed; dropped-coins marker (scene, scene args, x, z, amount);
  `StorySession.toSaveData()`.
- Not saved: health (full after a load), non-boss enemies, position other than the bonfire.

### Audio

Everything downsampled: music to mono MP3 at ~64–96 kbps / 22–32 kHz (about 1–2 MB a track); sound
effects to 16-bit mono WAV at 22.05 kHz, trimmed. Only the sounds the game uses are copied in.

| Music (HitCtrl, CC-BY 3.0) | Used for |
| --- | --- |
| The March Upon the Red Mountain | Title, boss fights |
| RPG Music (The Lost Town) | Town, keep, chapel |
| RPG – Foreboding Ambiance | Graveyard, crypt |
| The Wraiths of Winter | Forest, orc camp |

Sound effects from *RPG Sound Pack* (artisticdude, CC0): `swing*` attacks; `sword-unsheathe*`
equip weapon / pick up gear; `interface*` menus; `coin*` coins; `bottle`/`bubble*` drinking;
`metal-small*`/`metal-ringing` block and parry; `armor-light`/`chainmail*` dodge; `door` scene
doors; `ogre*` orcs; `giant*` heavy orc and chieftain; `gutteral beast/mnstr*` werewolf;
`shade*` skeletons and crypt bosses; `beetle/bite-small*` goblins.

**Gaps (nothing in the pack):** sword hitting flesh, footsteps, bonfire crackle, death sting,
skeleton bone rattle. Placeholder: reuse the nearest sound (`metal-small` for a hit), or leave it
silent.

## New content

### Forest (`ForestScene`, `src/maps/forest.txt`)

- A text grid of 2 m cells, like the town (`BGE.CharGrid`). About 40×60 cells: a winding road from
  the north gate, a clearing with the bonfire, dense trees either side (`Y` billboards, kept
  sparse enough for the frame rate), and the orc camp at the far end behind a palisade: tents, a
  campfire (point light), totems, crates.
- Fog like the town's (`useTownFog`), a forest ground texture painted by a tools script like
  `town-ground.py`.
- Enemies: goblin packs of 2–3 along the road, hobgoblins with them, one werewolf that roams
  between two points, then orcs, heavy orcs and the chieftain in the camp. They wake on sight like
  the graveyard's skeletons.
- Loads only the forest creatures' atlases (goblin, hobgoblin, werewolf, orc, orc_heavy).

### Creatures (`EnemyTypes.bs` entries)

- **Goblin** (Clint Bellanger, CC-BY 3.0, `goblin.blend`): small, fast, weak, flanks, quick jab.
- **Hobgoblin** (VWolfdog, CC-BY 3.0, `knife_hobgoblin.blend`): a goblin with more health and a
  double-stab combo.
- **Werewolf** (VWolfdog, CC-BY 3.0, `Werewolf.blend`): fast, big lunge, a long reach, staggers
  rarely. The forest's elite.
- **Orc Chieftain:** `orc_heavy` scaled ×1.4, tinted dark red, boss bar; a combo like the Barrow
  King's.

All rendered through the existing pipeline (`convert-flare.py` in Blender 2.79, then
`render-character.py --packed` with entries in `tools/characters.py`), 16 directions like the
others. Check each sheet with `rokubot textures` on HD.

## Sub-issues (order = PR order)

1. **Title screen, save/continue, pause menu, options.** `TitleScene`, `SaveSlot` wrapper
   (`GameSave.bs`), the pause menu, the options sliders, plus renaming the channel (manifest title,
   splash and icons as placeholders). Saving at this point = on scene change only, so it's testable.
2. **Bonfires and death.** Bonfire prop/entity, cross-scene respawn, coin drops and the recover
   marker, enemies reset on rest, bosses stay dead; save moves to the rules above.
3. **Inventory, gear and merchant.** Items, equip stats, draughts and quick slots, the HUD coin
   counter, the inventory screen, the merchant.
4. **Audio.** Music per scene and boss, sound effects wired into combat, UI and items; the music
   toggle and sound volume take effect; CREDITS rows.
5. **New creatures.** Render goblin, hobgoblin and werewolf; `EnemyTypes`; test them in the Field
   scene. `FieldScene` loads every atlas in `EnemyTypes.all()`, so give it a pick of types (e.g.
   `types=goblin,werewolf`; `enemies=` is already the count cap) instead of loading all six
   creature sheets at once on HD.
6. **Forest and orc camp.** North gate, `ForestScene`, map, ground art, camp props, chieftain,
   rewards, story lines.
7. **Ending and credits; README and `rokubot-examples` row.** Closing banner, credits roll, back to
   the title; closes #385.

Items 4 and 5 don't depend on 2 and 3 and can be developed alongside them.

## Art needed (placeholders first, procedural where possible)

Placeholders I'll make (procedural, by tools scripts, CC0). Replace any that you want:

- **Title logo**: text for now. Wanted: a "Night of the Barrow King" logo (PNG with alpha,
  about 900×250).
- **Channel icon and splash** (HD/SD): regenerated with the new name over a dark backdrop.
  Wanted: proper key art.
- **Item icons** (64×64): draught, coin, the three swords, two shields, the tusk. Placeholders are
  simple drawn shapes.
- **Bonfire**: ring of stones and a sword, made by `make-props.py`.
- **Coin marker**: reuses the spirit flame.
- **Forest**: more tree variety (pines/dead trees; the 5 existing tree sprites are reused at first),
  bushes, rocks, a forest-floor texture.
- **Orc camp**: tents, palisade wall, campfire ring, totems, crates. Low-poly from `make-props.py`.

From you, if you want better than placeholders: the logo, the key art (splash and icon), and the
forest tree sprites (the existing trees' source is still a CREDITS TODO). Everything else is fine
procedural.

**Audio needed:** the gaps listed under Audio (hit, footsteps, bonfire, death sting, bone rattle).

## Constraints

- BrighterScript conventions in `CLAUDE.md`: real types, explicit imports, no single-line `if`,
  no `=` between objects.
- Every new asset named in `examples/thirdPerson/CREDITS.md` (`npm run check:credits`).
- Title-safe UI (≥10% from each edge).
- Each PR: `npm run check:all` green, sideloaded and played on a device (the frame rate checked on
  HD/Express for content PRs), simulator first per the shepherd rule.

## Left to the builder

Exact enemy stats, coin amounts and prices; the exact grid of the forest map; which gamepad and
remote buttons drink a draught and open the pause menu (they must not clash with the existing
bindings in `main.bs`); the icon and menu styling within the existing `talkTheme()` look.
The remote has no free button today: the arrows move, `OK` attacks, `play` blocks, `fastforward`
parries, `back` and `replay` both dodge, `rewind` locks on, and `*` is the debug-panel toggle
(`enableDebugToggle`). So the draught and the pause menu need one freed, for example `replay` for
the draught and `*` for pause, with the debug toggle moved behind a deep link.
