# examples/rpg — Slice D1: The keep dungeon (design)

Issue: #289 (split: this is D1; D2 is a follow-up issue). Follows Slice C (`specs/2026-10-02-rpg-slice-c-story-design.md`, #257).

Slice C ends with the castle gate opening. D1 turns the castle into a small Zelda-style dungeon: six one-screen rooms, small keys and locked doors, floor switches, clear-the-room shutters, breakable pots, goblins, and a goblin king mini-boss who drops the throne-room key. The throne-room door stays sealed; D2 adds the throne room, the witch boss, the ending, and the decision on promoting the story layer to the engine.

Locks, switches and shutters are built on the Slice C story layer (flags, conditions, effects, event rules) rather than a separate dungeon state, so they save for free and give D2 real evidence on how well that vocabulary generalises.

## Story

**"The Witch of the Keep"**, continued. Past the gate, a wounded servant lies in the entry hall. Goblins have taken the keep; their king carries the key to the throne room, where the witch has sealed herself in.

| Beat | What happens | What moves it on |
|------|--------------|------------------|
| 4. The keep | The servant explains the situation. The way north is barred, the east door is locked. | Talking to the servant starts the `keep` quest. |
| 5. Keys and switches | Clear the guardroom for a key, open the barracks, step on its switch to raise the hall's portcullis, solve the antechamber's two switches for a second key. | Unlocking the king's hall. |
| 6. The goblin king | Shutters close; mini-boss fight. | Defeating him drops the heart-shaped throne key. |
| 7. Sealed | The throne key turns in the great door, but dark magic holds it shut. | (End of D1.) |

Elder Bram gets one new page once the gate is open: he points the player to the keep and its servant.

### Quest `keep`

| `keep.stage` | Objective |
|---|---|
| 1 | Find a way through the keep. |
| 2 | Defeat the goblin king. (Set on entering the antechamber's far door, i.e. when `dng.L2.open` is set.) |
| 3 | The throne room is sealed by dark magic. (Set when the player holds `throneKey`.) |

## Map

Six rooms, each one screen: 20×11 cells of 32px on the 640×360 canvas (top rows brick wall, `x` void sides, as today's castle). Each room is its own `AreaScene`; doors fade between them with the existing `Door` + `changeSceneWithFade`.

```
                 [ THRONE ROOM ]  (D2 — great door stays sealed in D1)
                        ║ great door (throneKey)
                 [ KING'S HALL ]  shutters, goblin king
                        │ L2
   [ STOREROOM ]   [ ANTECHAMBER ]  two-switch puzzle → small key #2
        │                ║ portcullis (raised by barracks switch)
   [ GUARDROOM ]──[ ENTRY HALL ]──L1──[ BARRACKS ]  switch, goblins
     shutters → key #1    │ servant, bats
                        (town)
```

| Room | Scene | Contents |
|------|-------|----------|
| Entry hall | `CastleScene` (map replaced with a one-screen room) | Servant NPC (`redGirl` row of `npcs.png`), bats, south door to town, west to guardroom, east locked door L1, north portcullis. |
| Guardroom | `GuardroomScene` | Shutters close until 3 goblins are dead; clearing drops small key #1. North to storeroom. |
| Storeroom | `StoreroomScene` | Optional. Many pots, and a heart container pickup that is there whether or not one was bought in the shop: the player starts with 3 hearts, so the shop's and this one make 5. It bypasses the `heartContainer` inventory item (max 1) and applies its effects directly: `{type: "pickup", icon: "heartIcon", when: [{notFlag: "dng.heartTaken"}], effects: [{addMaxHealth: 2}, {heal: 2}, {set: "dng.heartTaken", value: true}]}`. |
| Barracks | `BarracksScene` | 2 goblins, the switch that raises the entry hall's portcullis. |
| Antechamber | `AntechamberScene` | Goblins, bats, pots. Two floor switches; pressing both drops small key #2. North locked door L2. |
| King's hall | `KingsHallScene` | Shutters close until the goblin king is defeated. Great door (north), sealed. |

The existing castle props (banners, blacksmith corner, statues, storeroom furniture) are redistributed across the new rooms. `Goblin showcase` (`GoblinShowcaseScene`) is a seventh, debug-only room; see [Debug launch params](#debug-launch-params).

Spawn points sit one cell inside every doorway so a shutter closed on entry never overlaps the player.

## Story layer additions

### Live placements

Today `AreaScene.onCreate` filters placements by `when` once, at scene build. D1 adds `live: true` on a `MapPlacement`: the scene keeps every live placement and re-evaluates it whenever the story changes, spawning those whose `when` now passes and removing those whose `when` now fails. `Story` posts a new `storyUpdated` game event after any change it applies (dialogue, event rules, pickups, unlocks).

The diff ("given these live placements, what's currently present, and this context, what to add and what to remove") is a pure function in its own file so it can be tested.

Most dungeon mechanics are just live placements:

| Thing | Placement |
|---|---|
| Portcullis | `{type: "gate", style: "bars", live: true, when: [{notFlag: "dng.portcullis"}]}` |
| Shutter | `{type: "gate", style: "shutter", live: true, when: [{notFlag: "dng.guard.cleared"}]}` |
| Locked door | `{type: "gate", style: "locked", live: true, when: [{notFlag: "dng.L1.open"}], unlock: {when: [{hasItem: "smallKey"}], effects: [{takeItem: "smallKey"}, {set: "dng.L1.open", value: true}], lockedMessage: "Locked. A small key would fit."}}` |
| Key drop | `{type: "pickup", item: "smallKey", live: true, when: [{flag: "dng.guard.cleared"}, {notFlag: "dng.guard.keyTaken"}], effects: [{giveItem: "smallKey"}, {set: "dng.guard.keyTaken", value: true}]}` |
| Goblin king | `{type: "enemy", kind: "goblinKing", when: [{notFlag: "dng.kingDefeated"}]}` (not live) |

### New effects, events and items

- **Effect `{message: "text"}`**: opens a one-page, speaker-less dialogue box (the existing `DialogueBox`, pausing gameplay the same way). Used by switches and locked doors.
- **Events routed by `Story.onGameEvent`** to the event rules: `roomCleared {room}` and `switchPressed {id}`, alongside the existing `enemyKilled`.
- **Items**: `smallKey` (max 3) and `throneKey` (max 1), silver and gold keys from "Locks and Keys" (`items/keySilver.png`/`keyGold.png`, 8-frame spin sheets - pickups spin, the HUD and inventory use the first frame). A silver key opens silver locks, the gold key the great door's gold lock.

### Event rules (sketch)

```
{event: "roomCleared", match: {room: "GuardroomScene"}, effects: [{set: "dng.guard.cleared", value: true}]}
{event: "storyChanged", when: [{flag: "dng.ante.a"}, {flag: "dng.ante.b"}], effects: [{set: "dng.ante.solved", value: true}]}
{event: "storyChanged", when: [{flag: "dng.L2.open"}, {flag: "keep.stage", lt: 2}], effects: [{set: "keep.stage", value: 2}]}
{event: "storyChanged", when: [{hasItem: "throneKey"}, {flag: "keep.stage", lt: 3}], effects: [{set: "keep.stage", value: 3}]}
```

The antechamber's key is a live pickup gated on `dng.ante.solved`; the king's throne key is a live pickup gated on `dng.kingDefeated` and `notItem: throneKey`, so leaving without it brings it back.

### Flags

| Flag | Meaning |
|------|---------|
| `keep.stage` | quest stage (above) |
| `dng.guard.cleared`, `dng.guard.keyTaken` | guardroom shutters open; its key collected |
| `dng.L1.open`, `dng.L2.open` | locked doors opened |
| `dng.portcullis` | barracks switch pressed |
| `dng.ante.a`, `dng.ante.b`, `dng.ante.solved`, `dng.ante.keyTaken` | antechamber switches and key |
| `dng.kingDefeated` | goblin king beaten; king's hall shutters open |
| `dng.heartTaken` | storeroom heart container collected |
| `dng.throneDoor.tried` | throne key used on the great door (for the servant/door text) |

## Entities

### `Gate` (`World/Gate.bs`)

A solid in the room's `SolidWorld`, a sprite, and a trigger collider slightly larger than the solid.

- **Styles**: `bars` (portcullis), `shutter` (closes behind you), `locked` (needs a key), `great` (the throne door). Art comes from `Castle2.png` (barred arch, doorway; turned for side/south walls in `castleWalls.png`) and `items/locks.png` (silver lock on locked doors, gold on the great door); exact regions are picked in the plan and checked on a device.
- **Unlocking**: when the player's `feet` enter the trigger (`onCollisionEnter`, once per contact), a `locked`/`great` gate runs `unlock.effects` if `unlock.when` passes, otherwise shows `lockedMessage` via the `message` effect.
- **Opening**: when its live placement is removed, the gate fades out over ~0.3s, then removes its solid (`SolidWorld.removeSolid`) and itself.
- **The great door** in D1: without the throne key, *"A great door, sealed by the witch's magic. The keyhole is shaped like a heart."* With it, *"The key turns, but dark magic holds the door shut."* (sets `dng.throneDoor.tried`). It never opens in D1.

### `FloorSwitch` (`World/FloorSwitch.bs`)

Drawn from the teal floor tiles of the indoor tileset expansion at 2× (16px source tiles), darker when pressed. Pressed when the player's `feet` overlap it; stays pressed. Its pressed state is read from its flag on scene build, so it's still down after loading a save. Placement: `{type: "switch", id, flag, effects}`; pressing runs `effects` and posts `switchPressed {id}`.

### `Pickup` (`World/Pickup.bs`)

A generic item on the floor (key, heart container, potion) with an `effects` list run on touch. Its sprite comes from `item`'s icon, or an explicit `icon` for a pickup that isn't an inventory item (the storeroom heart). `Coin` stays as it is. A pickup whose `item` is at its cap stays on the floor.

### `Pot` (`World/Pot.bs`)

A clay vase from `PathAndObjects.png` (already loaded): a solid in `SolidWorld` plus a `body` collider the sword hits. One hit breaks it: the solid is removed, a few rectangle shards scatter and fade, and it rolls the loot table: 25% healing potion (a `Pickup`), 25% coin, 50% nothing. Pots respawn on every room entry, like Zelda; no flags.

### `Goblin` (`Entities/Goblin.bs`)

An `Enemy` subclass from `goblinsword.png` (LPC Goblin, Redshrike, CC-BY 3.0): 704×320, 11 columns × 5 rows of 64×64. Rows face down, right, up, left (a different order from the rat/bat sheets, so `Goblin` has its own row map); about 7 walk frames then 4 swing frames per row; row 4 is the death animation. Feet pinned near (32, 58).

- 3 HP, walks at 60 px/s, chases within 160 px.
- Within ~48 px it plants for 0.4s playing the swing frames (the tell), then lunges at ~3× speed for 0.25s. Damage is the existing 1-heart contact damage, so `Player` is unchanged.
- Hitting it during the tell cancels the lunge.
- Recoils and retreats like the rats (`recoil()`/`isRetreating()`). The death row plays before the existing fade.

### `GoblinKing` (`Entities/GoblinKing.bs`)

A `Goblin` subclass: 1.5× scale, gold/red tint, a wider feet box and body collider, 12 HP, heavier knockback resistance.

- A state machine (in the style of the platformer's `PlantBoss`): chase slowly; every ~3s plant and flash for 0.6s (the tell), then charge in a straight line until it hits a wall; stunned for 1.2s on impact, which is the safe window to hit him.
- Phase 2 (at or below half health): 1.3× charge speed, and two charges back-to-back before he can be stunned.
- A boss health bar across the top of the screen while he's alive, title-safe.
- On death: plays the death row, sets `dng.kingDefeated` (via an `enemyKilled {kind: "goblinking"}` event rule), which brings in the throne key pickup and opens the shutters.

### Loot

`Enemy.dropCoin()`'s hardcoded 50% coin becomes an overridable `dropLoot()`. Rats and bats keep a 50% coin; goblins drop 30% coin, 10% potion; the king drops nothing (his key comes from the flag). A pure `pickLoot(table, roll)` helper is shared with `Pot`.

### Room clears

`AreaScene` counts its `enemy`-tagged entities; when the last one dies it posts `roomCleared {room: sceneName}`. Goblins respawn on re-entry, but shutters stay open because they're tied to the flag.

## HUD

`HeartsHud` shows a small-key icon and count next to the hearts while the player carries at least one small key, title-safe. The throne key appears in the inventory panel only.

## Engine change: `SolidWorld.removeSolid`

`BGE.SolidWorld.addSolid()` returns the solid's id (a string, as `SolidWorldSolid.id` already is); new `removeSolid(id)` takes the solid out of its grid buckets (and `getSolids()`). Existing callers that ignore the return value are unaffected. Covered by the engine's `SolidWorld.spec.bs`.

## Checkpoints

| Stage | State | Start |
|-------|-------|-------|
| 5 | Stage 4 + talked to the servant (`keep.stage = 1`) | `CastleScene` |
| 6 | Stage 5 + every `dng.*` flag up to the king's defeat, holding `throneKey`, `keep.stage = 3` | `KingsHallScene` |

## Debug launch params

For checking what a screen looks like with a screenshot, never for driving the player. They extend the existing `scene=` / `stage=` deep link and, like it, turn saving off.

| Param | Effect |
|---|---|
| `spawn=<id>` | spawn point to start at (default `start`) |
| `flags=a,b,c` | set these flags to `true` (e.g. to see open gates or pressed switches) |
| `items=smallKey:2,throneKey` | give items (count after `:`, default 1) |
| `peaceful=1` | skip `enemy` placements so the room is still |
| `open=inventory` | open the inventory panel once the scene is up |

`GoblinShowcaseScene` (deep link only) places goblins and a goblin king, each frozen in one pose (walk, tell, lunge, stunned, dying), so their sprites and scale can be checked in one screenshot.

## Testing

- **Rooibos, `examples/rpg/tests/`**: the live-placement diff; `pickLoot`; the `message` effect; event rules for `roomCleared`, the antechamber's two switches and the `keep` stages; checkpoints 5 and 6; parsing the `flags=`/`items=` params.
- **Rooibos, engine**: `SolidWorld.removeSolid`.
- **On a device**: screenshots only, via the debug launch params above (each room, gate states, HUD with keys, inventory, goblin showcase). No driving the player through rokubot; real-time play is checked by hand.

## Non-goals

- The throne room, the witch, the ending, and the story-layer promotion decision (D2).
- Pushable blocks, chests, a dungeon map/compass.
- Persisting broken pots or killed goblins.
- Music and sound (Slice E, #290).

## Assets and credits

New files under `examples/rpg/src/sprites/`, each credited in `sprites/CREDITS.md`:

- `goblinsword.png` — LPC Goblin, Redshrike, CC-BY 3.0 (https://opengameart.org/content/lpc-goblin).
- `items/locks.png`, `items/keySilver.png`, `items/keyGold.png` — "Locks and Keys" by Kelvin Shadewing, CC-BY-SA 4.0 (https://opengameart.org/content/locks-and-keys).
- The indoor tileset expansion (https://opengameart.org/content/rpg-indoor-tileset-expansion-1) — only the floor-switch tiles are needed. The source PNG is RGB with no alpha, so its background colour is converted to transparency when imported.

The witch sheet (`lpcfemalechainpreview.png`, a full 832×1344 LPC sheet, sliceable despite #289's note) is D2's.

## Docs

Update the rpg bullet in `CLAUDE.md` (dungeon, live placements, new debug params) and the `rokubot-examples` skill's rpg notes with the new params. File the D2 issue.
