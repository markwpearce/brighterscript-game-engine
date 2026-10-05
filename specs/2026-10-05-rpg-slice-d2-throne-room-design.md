# examples/rpg — Slice D2: Throne room, witch boss, ending (design)

Issue: #296. Follows Slice D1 (`specs/2026-10-04-rpg-slice-d1-dungeon-design.md`, #289).

D1 ends at the sealed great door in the king's hall, with the throne key in hand. D2 opens that door, adds the throne room and the witch fight, then plays the ending: every castle monster vanishes, Elder Bram closes the story, and a credits scene returns to the title. It also decides the story layer's promotion question: it stays in the example (see [Story layer: stays in the example](#story-layer-stays-in-the-example)).

Like D1, everything is built on the Slice C story layer (flags, conditions, effects, event rules, live placements), so it saves for free.

## Story

| Beat | What happens | What moves it on |
|------|--------------|------------------|
| 8. The audience | The throne key turns; the witch's voice answers and the great door opens. | Using the throne key on the great door. |
| 9. The witch | The shutter closes behind you; the witch speaks, then fights. | Defeating her. |
| 10. Peace | She crumbles to dust; every goblin in the keep vanishes. | Returning to Elder Bram. |
| 11. The end | Bram's closing words, then the credits, then the title screen. | (End of the game.) |

### Quest `keep` (continued)

| `keep.stage` | Objective |
|---|---|
| 3 | Enter the throne room. (Was "The throne room is sealed by dark magic"; the seal is now just the witch's, and the key opens it.) |
| 4 | Return to Elder Bram. (Set when the witch is defeated.) |
| 5 | (Complete: no stages entry, so the quest drops off the log.) |

### Flags

| Flag | Meaning |
|------|---------|
| `dng.throneDoor.open` | the great door is open |
| `throne.introSeen` | the witch's opening speech has played |
| `witch.defeated` | the witch is dead; castle monsters are gone |
| `game.complete` | Bram's closing page has been read |

`dng.throneDoor.tried` (D1) is still set when the key turns, and nothing reads it any more; an old D1 save holding the throne key just turns it again, so no migration is needed.

## The great door

The D1 great door placement becomes live, gated on `notFlag: "dng.throneDoor.open"`, and its unlock changes:

```
unlock: {
  when: [{hasItem: "throneKey"}],
  effects: [
    {set: "dng.throneDoor.tried", value: true},
    {set: "dng.throneDoor.open", value: true},
    {message: "So the little hero wants an audience. Come in, then.", speaker: "The Witch"}
  ],
  lockedMessage: "A great door, sealed by the witch's magic. The keyhole is shaped like a heart."
}
```

The throne key stays in the inventory (a keepsake; nothing else uses it). A live north `Door` to `ThroneRoomScene` (gated on `flag: "dng.throneDoor.open"`) sits behind the gate, as D1's locked doors do. Gate removal already fades it out.

### `message` effect: optional speaker

`{message: "text", speaker: "name"}` shows the box with that speaker; without `speaker` it is speaker-less, as in D1. `StoryResult.messages` becomes `StoryMessage[]` (`{text, optional speaker}`) instead of `string[]`, and `Story.showMessage(text, speaker = "")` takes an optional speaker.

## Throne room (`ThroneRoomScene`)

One screen (20×11 cells of 32px), built with `buildRoomRows("s")` like the other rooms, in `Maps/DungeonData.bs` and `Scenes/DungeonScenes.bs`.

| Placement | Notes |
|---|---|
| Throne | Prop at the north wall, centre (from `Castle2.png`; region picked in the plan and checked on a device). Banners and statues either side. |
| Summoning circles | Four `drain` placements (the existing type the sewer uses), each also drawing a dark violet ring on the floor (a `DrawableCircle` outline, or a small `SummonCircle` prop). |
| Perches | Three or four new `perch` placements: points the witch blinks to. `AreaScene` collects them like `drains` (`m.perches as Point[]`). |
| Shutter | South, `{type: "gate", style: "shutter", live: true, when: [{notFlag: "witch.defeated"}]}`. Spawn point one cell inside it, as everywhere else. |
| Witch | `{type: "enemy", kind: "witch", col: 9, row: 4, when: [{notFlag: "witch.defeated"}]}` (not live). |
| South door | Back to `KingsHallScene`. |

### The intro

The first time the scene is entered (`notFlag: throne.introSeen`), it opens a speakered dialogue page from the witch, two or three lines (*"Goblins, rats, a little lock and key... and still you came."* ...). Its effects set `throne.introSeen`. Dialogue pauses the game, so the fight starts when the box closes. Later entries (e.g. after dying) skip it. The page lives in `getDialogueData()` under `witch`, with `when: [{notFlag: "throne.introSeen"}]` and no fallback page. `ThroneRoomScene.onCreate` calls a new `Story.startScripted("witch")`, which opens the first passing page the same way talking to an NPC does, and does nothing when none passes.

## The witch (`Entities/Witch.bs`)

An `Enemy` subclass, from the repo owner's `lpcfemalechainpreview.png`, imported as `sprites/witch.png`: a standard LPC sheet, 832×1344, 13 columns × 21 rows of 64×64.

| Rows | Animation | Frames |
|---|---|---|
| 0-3 | spellcast (up, left, down, right) | 7 |
| 8-11 | walk | 9 |
| 20 | hurt / death | 6 |

The facing order (up, left, down, right) is LPC's, different again from the goblin's; `Witch` has its own row map. Feet pinned near (32, 60). A dark violet tint (`WITCH_TINT`) makes her plain chain-mail-and-tunic sheet read as the witch; checked on a device and adjusted there.

- 16 HP. `BossBar` shows "The Witch" while she's alive.
- Never chases. She drifts away from the player (slowly, through the `SolidWorld`) when the player is within ~96 px, and otherwise stands and casts.

### The cycle

A state machine in the style of `GoblinKing` and the platformer's `PlantBoss`:

1. **Volley** — plays spellcast, then fires a fan of 3 bolts aimed at the player, 2-3 times about 0.8 s apart.
2. **Summon** — spellcast again (a longer tell, ~0.8 s), then a wave of 2 goblins appears, each at a circle chosen by `pickDrain` at least 96 px from the player (a circle may be reused if fewer are far enough away; if none is, the wave waits a frame). Each summoned goblin is a normal `Goblin` with `summoned: true` in its args, so it drops no loot.
3. **Shielded** — while any goblin she summoned is alive, a ring is drawn around her and sword hits bounce off: no damage, a small "clink" marker in place of a damage number, and the player is knocked back slightly. She keeps casting volleys while shielded.
4. **Exhausted** — once the wave is dead, she slumps (hurt row, first frames) for ~2 s, unshielded.
5. **Hit** — any sword hit while unshielded deals damage as usual and then she **blinks**: fades out over ~0.2 s, reappears at the perch farthest from the player (`pickPerch`), and the cycle restarts at 1.

Phase 2 (at or below half health): 5-bolt fans, bolts 1.3× faster, waves of 3 goblins.

`hurt()` returns `false` (no hit) while shielded or blinking; a hit doesn't knock her back (`knockbackScale = 0`), and she doesn't `recoil()` after touching the player (like the king).

### `WitchBolt` (`Entities/WitchBolt.bs`)

A small glowing violet circle (`DrawableCircle`, plus a fainter larger one as a glow) moving in a straight line at ~140 px/s (phase 2: ~180). It has a `body` collider and the `enemy` tag so `Player`'s existing contact damage applies (one heart, with the usual invulnerability window); it is destroyed when it touches the player, when it would move into a `SolidWorld` solid, or after 4 s. The sword ignores bolts (no `hurt()` on them; `Player` skips enemies tagged `projectile`).

### Pure helpers (`Entities/WitchLogic.bs`, engine-free, tested)

- `boltFan(dirX, dirY, count, spreadDegrees) as Point[]` — unit directions for a fan centred on the aim.
- `pickPerch(perches, playerX, playerY, currentIndex) as integer` — the farthest perch from the player that isn't the current one.
- `isShielded(summonsAlive) as boolean`, and the phase thresholds.

### Death

Plays the death row (row 20), holds (`deathHoldSeconds`), then the existing fade. `onDying()` destroys every live summoned goblin with the same fade. `enemyKilled {kind: "witch"}` runs:

```
{event: "enemyKilled", match: {kind: "witch"}, effects: [
  {set: "witch.defeated", value: true},
  {set: "keep.stage", value: 4},
  {message: "The witch crumbles to dust. Across the keep, the goblins vanish like smoke."}
]}
```

which also opens the shutter (live placement). Dying mid-fight reloads the scene at `lastSpawn` as today, so the witch comes back at full health and the intro doesn't replay.

## The keep at peace

Every enemy placement in the castle rooms (`CastleScene`, the five D1 rooms, `ThroneRoomScene`) gets `notFlag: "witch.defeated"` added, by one helper in `DungeonData.bs` (`withKeepEnemiesGone(placements)`) applied when each room's placements are built, so no placement has to remember it. The sewer's rats are not affected: the sewer is under the town, not part of the keep, and stays a place to earn coins.

New pages, most specific first:

- **Mara**: `witch.defeated` → *"It's over? The keep feels... lighter. Go and tell Elder Bram."*
- **Townsfolk**: `witch.defeated` → one line each about the castle (*"The castle lights are back on!"*).
- **Gate Knight**: `witch.defeated` → *"You did it. I'll be telling my grandchildren about you."*
- **Elder Bram**:
  - `keep.stage = 4` → the closing page: two or three lines of thanks and an ending note; effects `{set: "keep.stage", value: 5}`, `{set: "game.complete", value: true}`; one choice `{label: "The End", open: "credits"}`.
  - `game.complete` → *"The town owes you everything. Rest a while."* (for wandering after a Continue).

## Ending: the credits

`DialogueChoice.open` gains `"credits"` beside `"shop"`. `Story.finishDialogue` runs the page's effects, saves, then (once the box has closed) calls `game.changeSceneWithFade("CreditsScene")`.

### `CreditsScene` (`Scenes/CreditsScene.bs`)

Not an `AreaScene`: a plain `GameScene` that draws on the UI canvas, so the player and HUD aren't shown (the persistent `Player`/`Story` entities are hidden or paused while it's up; the plan checks how `TitleScene` handles this and does the same).

- A dark background (the title art, dimmed, if it reads well).
- A vertical list that scrolls up slowly from the bottom: the game's title, *"The End"*, *"Thanks for playing"*, then the art credits, one heading and a line or two per asset, from `Story/CreditsData.bs`, kept in step with `sprites/CREDITS.md` by hand (a note at the top of `CREDITS.md` says so).
- Every line stays inside the title-safe area horizontally (≥10% in from the left/right edges; centred, wrapped with `BGE.UI.wrapText` at 80% of the width). Lines scroll through the full height, but nothing is drawn in the top or bottom 10% band (they appear and disappear at the safe area's edges).
- Auto-scroll; Down speeds it up while held; OK or Back skips to the end. When the last line has scrolled past (or it's skipped) it fades to `TitleScene`.
- `TitleScene`'s Continue loads the completed save, which starts in town at peace.

## Checkpoints

| Stage | State | Start |
|-------|-------|-------|
| 7 | Stage 6 + `dng.throneDoor.tried`, `dng.throneDoor.open` | `ThroneRoomScene` (intro not seen) |
| 8 | Stage 7 + `throne.introSeen`, `witch.defeated`, `keep.stage = 4` | `TownScene` |

`checkpointScene()` and `--param stage=` extend to 0-8.

## Debug launch params

No new params. `scene=ThroneRoomScene` works with the D1 params; `peaceful=1` skips `enemy` placements, so the room is empty (no witch). `GoblinShowcaseScene` gains the witch frozen in each pose (cast, shielded, exhausted, blinking, dying) and a bolt fan, so her sprite, tint and scale can be checked in one screenshot. `scene=CreditsScene` opens the credits directly.

## Story layer: stays in the example

Issue #296 asks whether `examples/rpg/src/source/Story/` should move to the engine. **Decision: not now.**

Evidence from D1 and D2:

- The layer generalised well inside the rpg. D1's locks, switches, shutters and keys needed only `live` placements, one new effect (`message`) and two routed events. D2's door, boss and ending need one effect option (`speaker`), one `open` target (`credits`) and a way to start a page from a scene.
- But it splits into two halves. The **core** is generic: `StoryFlags`, conditions (`flag`/`eq`/`gte`/`lt`/`notFlag`), event rules with `match`, the `storyChanged` settle loop, and the live-placement diff. The **vocabulary** is this game's: effects like `giveCoins`/`heal`/`addMaxHealth`, `PlayerStats`, `Inventory`'s item definitions, quests, shop rules, save data, and `Story` the entity, which owns the rpg's UI panels.
- Promoting only the core means designing a pluggable condition/effect registry so a game can add its own vocabulary. With one consumer, any such API is shaped by this game alone and is likely to be wrong for the second.

So the layer stays in the example. A follow-up issue records the split above and a sketch of a `BGE.Story` (flags + conditions + event rules + settle, with `registerEffect(name, handler)`/`registerCondition(name, handler)`), to pick up when a second example (or a user) needs it.

## Testing

- **Rooibos, `examples/rpg/tests/`**: the great door's unlock effects; `message` with a speaker; the witch's `enemyKilled` rule and the `keep` stages 3-5; `withKeepEnemiesGone()` (castle rooms gain the condition, the sewer doesn't); Bram's/Mara's page selection after victory; checkpoints 7 and 8 and `checkpointScene()`; `boltFan`, `pickPerch`, `isShielded`; every door in `getAreaMaps()` (now including `ThroneRoomScene`) leads somewhere real.
- **On a device**: screenshots only, via deep links (the throne room with and without the witch, the opened great door, the showcase poses, the credits, title-safe checks). The fight itself is played by hand.

## Non-goals

- Promoting the story layer (see above).
- Reflecting bolts, a second witch form, or a dungeon map.
- New game+ or post-game content beyond wandering.
- Music and sound (Slice E, #290).

## Assets and credits

- `sprites/witch.png` — `lpcfemalechainpreview.png` from "LPC Combat Armor for women" by Matthew Krohn (makrohn), adapted from art by Johannes Sjölund. https://opengameart.org/content/lpc-combat-armor-for-women License: CC-BY-SA 3.0 / GPL 3.0 / OGA-BY 3.0. Unmodified (tinted in code). Credited in `sprites/CREDITS.md`.
- The throne prop and any extra props come from sheets already in the repo (`Castle2.png`, `indoorTiles.png`).

## Docs

Update the rpg bullet in `CLAUDE.md` (throne room, witch, ending, credits, checkpoints 7-8, the promotion decision) and the `rokubot-examples` skill's rpg notes. File the story-layer follow-up issue.
