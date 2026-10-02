# examples/rpg — Slice C: Story, NPCs, shop, saving (design)

Issue: #257. Follows Slice A (`specs/2026-09-27-rpg-slice-a-world-design.md`, #63) and Slice B (`specs/2026-09-30-rpg-slice-b-combat-design.md`, #256).

Slice C gives the rpg example a story to follow: townsfolk you can talk to, a quest that opens the castle gate, a shop, an inventory, a sewer to grind coins in, and save/load. It also adds word wrapping to the engine's `BGE.UI.Label`, which the dialogue box needs.

The story layer (flags, items, conditions/effects, dialogue pages, event rules, quest log) is deliberately generic and data-driven, modelled on RPG Maker's switches/variables + event pages, Flare's `requires_status`/`set_status` dialogue, and Solarus's key/value savegame. It stays in the example (`examples/rpg/src/source/Story/`), engine-free, so Slice D can decide whether it's worth promoting to the engine.

## Story

**"The Witch of the Keep."** A witch has taken the castle. Her goblins hold the hall, bats nest in the rafters, and rats pour out of the cellars into town. The knight at the gate lets no one in.

Slice C covers the first three beats. Slice D (#289) adds goblins, the goblin captain and throne-room key, the witch boss fight, and the ending.

| Beat | What happens | What moves it on |
|------|--------------|------------------|
| 1. Rats in the streets | Elder Bram (fountain) asks you to clear the rats the witch brought. | Kill 4 rats (town or sewer), then talk to Bram. He gives 10 coins and promises to vouch for you. |
| 2. Arm yourself | The knight says Bram's word isn't enough with that rusty blade. Merchant Hilde sells a steel sword. | Buy the steel sword. |
| 3. The gate | The knight steps aside. The castle door works. | (End of Slice C.) Walking in shows the castle as today, with bats. |

Bram, from beat 2 on: *"Short on coin? The sewers are crawling with the witch's rats. Kill all you like."*

### Quest flags

The rats quest is `rats.stage` (0 not started, 1 hunting, 2 report to Bram, 3 done) plus `rats.kills`. The gate is `gate.open` (boolean). They're set by data, not code. See [Story layer](#story-layer).

| Situation | Flags |
|-----------|-------|
| New game | nothing set (missing = 0/false) |
| Bram asked | `rats.stage = 1` |
| 4 rats killed while hunting | `rats.stage = 2` |
| Reported to Bram | `rats.stage = 3`, +10 coins, `bram.vouched = true` |
| Vouched and holding `steelSword` | `gate.open = true` (set by an event rule, see below) |

Rat kills only count while `rats.stage = 1`. Enemies respawn on every area entry, so kills accumulate across reloads.

### Shop (Merchant Hilde, market stalls)

| Item | Price | Max | Effect |
|------|-------|-----|--------|
| Steel sword | 10 | 1 | Sword damage 1 → 2. A rat (2 HP) dies in one hit. |
| Heart container | 15 | 1 | Max health +2 half-hearts (one heart), and heals that heart. |
| Healing potion | 4 | 3 | Use from the inventory: heals 4 half-hearts (two hearts), capped at max. |

Bram's reward covers the sword, so the critical path needs no grinding. The heart and potions are optional and paid for from rat coin drops.

## Goals

- NPCs from the Fantasy RPG NPCs sheet: three quest NPCs (Bram, the knight, Hilde) and four ambient villagers, two of whom wander.
- OK talks to an NPC you're facing, and otherwise swings the sword.
- A paged dialogue box (wrapped text, 3 lines a page, OK to advance, optional choice buttons) that pauses gameplay while open.
- A generic, data-driven story layer: flags, inventory, conditions/effects, dialogue pages, event rules, quest log.
- A gate that stays blocked until the story allows it, including after loading a save.
- A shop and an inventory panel (Play/Pause), including drinking a potion and showing the current objective.
- A smaller town (~32×22 cells) and a new sewer area where rats keep respawning.
- Autosave on door transitions, quest flag changes and purchases, with a "Saving…" note. Continue / New Game on launch when a save exists.
- `BGE.UI.Label` word wrapping in the engine (`wrapWidth`), plus a `BGE.UI.wrapText()` helper.

## Non-goals

Goblins, the witch, the throne room, keys, the ending (Slice D). Promoting the story layer to the engine (decided in Slice D). Saving the exact position (you resume at the spawn point of the area you last entered). Multiple save slots. Voice/portraits in dialogue. Shops selling back. Changing the player's sprite for the steel sword (the adventurer sheet bakes in its sword; the upgrade shows in the inventory and in damage). Changes to the castle beyond what the gate needs.

## Assets and licensing

- `sprites/npcs.png`, from `npcs.png` in [Fantasy RPG NPCs](https://opengameart.org/content/fantasy-rpg-npcs) by Mandi Paugh. CC-BY-SA 3.0. The original has a magenta background and labels below the art. It's converted offline (ImageMagick or `pngjs`) to alpha and repacked into a regular grid of equal cells, so `BGE.Sprite` can index it. The repacking is recorded in `CREDITS.md` ("background made transparent, frames repacked into a grid"). Characters used:

  | Character (sheet) | Role |
  |---|---|
  | Bald old man, blue robe | Elder Bram (fountain) |
  | Armoured knight | Gate knight |
  | Brunette girl, pink dress | Merchant Hilde (market stall) |
  | Blonde boy | Wanderer, plaza |
  | Brunette girl, teal | Wanderer, market |
  | Dark-haired boy, green | Child by the well (still) |
  | Grey-haired old woman | On the dock bench (still) |

  Exact cell sizes and facing rows are found while repacking. Each character gets stand and walk frames for down/up/left/right; where the sheet only has one side view, the other is a horizontal flip.

- Item icons (34×34). The potion comes from "RPG Icons Extra" by Ails (Henrique Lazarini, ails.deviantart.com), CC-BY 3.0 per its `info.txt`, copied into `sprites/items/`:
  - `potion.png`: `icon_29.png` (round red flask), the healing potion.
  - `swordSteel.png`: `broadsword_icon.png` (34×34, supplied by the repo owner), the steel sword.
  - `swordRusty.png`: the same broadsword icon recoloured to rust with ImageMagick, the starting sword. `CREDITS.md` notes it's a modified copy.
  
  The heart container reuses `heart.png` (9×9) drawn at 4×, so it sits at about the same size as the 34px icons on a 720p UI canvas. The panels draw every icon at an integer scale picked from the UI canvas height, like `HeartsHud`.
- `images/title.jpg`: the monster-free "Broadsword" key art for the title screen, generated with Google Gemini and supplied by the repo owner, credited alongside the existing splash/icon art in `CREDITS.md`. It's scaled to 1280×720 when added.
- Tiles for the sewer come from the sheets already in the example: `stoneFloor`, `brick` and `water` from Castle2.png, plus two new atlas regions there: the dark tunnel archway (≈ x 430, y 222) as the sewer entrance in town, and the ladder (≈ x 64, y 256) as the exit in the sewer. Exact rectangles are measured when adding them.

## Engine: word wrapping (`src/source/engine/ui/`)

### `BGE.UI.wrapText()` (`ui/TextWrap.bs`, new file)

```brighterscript
namespace BGE.UI
  ' Splits text into lines no wider than maxWidth when drawn in font.
  ' Existing newlines are kept. Words are split on spaces; a single word wider than
  ' maxWidth is broken between characters.
  '
  ' @param {string} text
  ' @param {roFont} font
  ' @param {float} maxWidth - in pixels; 0 or less means no wrapping (split on newlines only)
  ' @return {string[]} the lines, without trailing spaces
  function wrapText(text as string, font as roFont, maxWidth as float) as string[]
end namespace
```

Greedy: add words to the current line while `font.GetOneLineWidth(line, 10000) <= maxWidth`. An empty string returns `[""]`. Repeated spaces collapse to one at a wrap point but are kept within a line.

### `BGE.UI.Label.wrapWidth`

```brighterscript
' Width in pixels to wrap the text at. 0 (the default) means no wrapping.
wrapWidth as float = 0
```

When `wrapWidth > 0`, `draw()` sets the `DrawableText`'s text to the wrapped lines joined with `Chr(10)`. The wrapped string is cached and only recomputed when the text, the font or `wrapWidth` changes. `setText()` stores the unwrapped text, so changing `wrapWidth` re-wraps the original. `m.width`/`m.height` after a draw reflect the wrapped size.

### `BGE.DrawableText` multi-line sizing fixes

`getTextImage()` measures width with `GetOneLineWidth(m.text)` over the whole string, newlines and all. For multi-line text it should be the widest line. Its bitmap reuse check also reads inverted (`m.width < m.tempCanvas.GetWidth()` recreates the bitmap when the new text is *smaller*, and keeps a too-small one when it's larger). Both get fixed here and covered by tests, since wrapped labels are the first heavy user of multi-line text.

### Tests

`ui/TextWrap.spec.bs` (one suite): no wrap needed, wrap at spaces, newline preserved, a long word broken by character, `maxWidth <= 0`, empty string. Uses a real font from `Game` (`game.getFont("default")` or similar - confirmed in the plan). `Label.spec.bs` and `DrawableText.spec.bs` (existing or new) gain cases for wrapped and multi-line size.

Docs: `wrapWidth` is mentioned in `CLAUDE.md`'s UI section and in any `docs/` guide that covers `Label`.

## Story layer (`examples/rpg/src/source/Story/`)

Pure, engine-free modules (no `BGE` dependency), unit tested in `examples/rpg/tests/`. Conditions and effects are plain AAs, so content is data.

### `StoryFlags` (`Story/StoryFlags.bs`)

A flat blackboard of `{key: boolean | integer | string}`. A missing key reads as `invalid`, and the numeric helpers treat it as 0.

```brighterscript
class StoryFlags
  function get(key as string) as dynamic
  function getInt(key as string) as integer   ' invalid -> 0
  function isSet(key as string) as boolean   ' true for true or any non-zero/non-empty value
  sub set(key as string, value as dynamic)
  sub add(key as string, amount as integer)
  function toAA() as roAssociativeArray       ' for saving
  sub loadAA(data as roAssociativeArray)
end class
```

Keys are dotted by convention (`rats.stage`, `gate.open`). Flags are case-sensitive: the store is a `roAssociativeArray` with `SetModeCaseSensitive()`.

### Items and `Inventory` (`Story/Items.bs`, `Story/Inventory.bs`)

`getItemDefinitions()` returns item definitions by id:

```brighterscript
{
  steelSword: {name: "Steel sword", icon: "swordSteel", max: 1},
  heartContainer: {name: "Heart container", icon: "heart", max: 1, onAcquire: [{addMaxHealth: 2}, {heal: 2}]},
  potion: {name: "Healing potion", icon: "potion", max: 3, onUse: [{heal: 4}]}
}
```

`Inventory` maps item ids to counts: `count(id)`, `has(id)`, `canAdd(id)` (respects `max`), `add(id)`, `remove(id)`, `toAA()`/`loadAA()`. Sword damage isn't stored. It's derived: `swordDamageFor(inventory)` returns 2 with `steelSword`, otherwise 1.

### Conditions and effects (`Story/Conditions.bs`, `Story/Effects.bs`)

A context `ctx` is `{flags as StoryFlags, inventory as Inventory, player as roAssociativeArray}`, where `player` exposes `health`, `maxHealth`, `coins` as plain fields (the `Player` entity itself satisfies this, so tests can pass a plain AA).

Conditions (all must pass; an empty or missing list passes):

| Condition | Passes when |
|---|---|
| `{flag: k, eq: v}` | `flags.get(k) = v` (missing compared as 0/false) |
| `{flag: k, gte: n}` / `{flag: k, lt: n}` | integer comparisons |
| `{flag: k}` | `flags.isSet(k)` |
| `{notFlag: k}` | not `flags.isSet(k)` |
| `{hasItem: id}` / `{notItem: id}` | inventory has / doesn't have it |
| `{coinsGte: n}` | `player.coins >= n` |

`evaluateConditions(conditions, ctx) as boolean`. An unknown condition key fails (logs a warning), so a typo in data can't silently pass.

Effects (applied in order):

| Effect | Does |
|---|---|
| `{set: k, value: v}` | `flags.set` |
| `{add: k, amount: n}` | `flags.add` |
| `{giveItem: id}` / `{takeItem: id}` | inventory add/remove; giving runs the item's `onAcquire` effects |
| `{giveCoins: n}` / `{takeCoins: n}` | player coins (never below 0) |
| `{heal: n}` | player health + n half-hearts, capped at `maxHealth` |
| `{addMaxHealth: n}` | player `maxHealth` + n |
| `{post: eventName}` | records the event name in the returned list |

`applyEffects(effects, ctx) as object` returns `{changedFlags as boolean, posts as string[]}`. The pure function never touches the engine. The `Story` entity posts the returned events with `game.postGameEvent()` and saves if anything changed.

### Dialogue pages (`Story/DialogueData.bs`)

`getDialogueData()` returns, per NPC id, an ordered list of pages. The first page whose `when` passes is used (so the most specific pages go first):

```brighterscript
bram: [
  {when: [{flag: "rats.stage", eq: 2}], speaker: "Elder Bram", lines: ["You did it! The streets are quieter already.", "Take this, and I'll put in a word with the guard."], then: [{giveCoins: 10}, {set: "rats.stage", value: 3}, {set: "bram.vouched", value: true}]},
  {when: [{flag: "rats.stage", eq: 1}], speaker: "Elder Bram", lines: ["Still rats about. ${rats.kills} of 4 so far."]},
  {when: [{flag: "rats.stage", gte: 3}], speaker: "Elder Bram", lines: ["Short on coin? The sewers are crawling with the witch's rats. Kill all you like."]},
  {speaker: "Elder Bram", lines: ["A witch has taken the castle, and her rats are spilling into our streets.", "Clear four of them for me, would you?"], then: [{set: "rats.stage", value: 1}]}
]
```

`selectDialoguePage(pages, ctx)` returns the matching page or `invalid`. `${key}` in a line is replaced with that flag's value (`interpolateFlags(text, flags)`). A page's optional `choices` is a list of `{label, then: [effects], open?: "shop"}`. `open` is a UI action the dialogue box performs after the effects, rather than an effect, since it isn't story state.

The knight's pages cover: not vouched ("No one goes in. Witch's orders, or near enough."), vouched without the sword ("Bram vouches for you. But with that rusty blade you'll not last a minute in there."), and the gate already open ("Go on, then. Light preserve you."). Hilde's single page ends with choices `Browse wares` (`open: "shop"`) and `Leave`. Each ambient villager has one or two pages, some keyed on `rats.stage` or `gate.open`.

### Event rules (`Story/EventRules.bs`)

Things that happen without dialogue. `getEventRules()` returns a list of `{on: eventName, match: {k: v}, when: [conditions], then: [effects]}`. `match` compares fields of the event's data AA. Every matching rule runs, in list order (unlike dialogue pages, where only the first runs):

```brighterscript
{on: "enemyKilled", match: {kind: "rat"}, when: [{flag: "rats.stage", eq: 1}], then: [{add: "rats.kills", amount: 1}]},
{on: "enemyKilled", match: {kind: "rat"}, when: [{flag: "rats.stage", eq: 1}, {flag: "rats.kills", gte: 4}], then: [{set: "rats.stage", value: 2}]},
{on: "storyChanged", when: [{flag: "bram.vouched"}, {hasItem: "steelSword"}, {notFlag: "gate.open"}], then: [{set: "gate.open", value: true}, {post: "gateOpened"}]}
```

`rulesFor(rules, eventName, data, ctx)` returns the effects lists to apply. After applying any effects that changed flags or items, the `Story` entity fires a synthetic `storyChanged` event through the rules once more (but not recursively beyond a fixed depth of 4, which logs a warning). That's how "vouched and bought the sword, in either order" opens the gate without special code.

### Quest log (`Story/QuestData.bs`)

`getQuestData()` returns an ordered list of `{id, title, stages: {<flag value as string>: "objective text with ${flags}"}, stageFlag}`. `currentObjectives(quests, flags) as string[]` returns the text for every quest whose stage flag has an entry. For Slice C:

```brighterscript
{id: "rats", title: "Rats in the streets", stageFlag: "rats.stage", stages: {"1": "Kill rats (${rats.kills}/4)", "2": "Return to Elder Bram"}},
{id: "gate", title: "The castle gate", stageFlag: "gate.stage", stages: {"1": "Buy a better sword from Hilde", "2": "Enter the castle"}}
```

`gate.stage` is a derived flag kept up to date by two more `storyChanged` rules, so the objective text needs no code:

```brighterscript
{on: "storyChanged", when: [{flag: "bram.vouched"}, {notItem: "steelSword"}], then: [{set: "gate.stage", value: 1}]},
{on: "storyChanged", when: [{flag: "gate.open"}], then: [{set: "gate.stage", value: 2}]}
```

A `set` that writes the value already stored doesn't count as a change, so these rules can't loop.

### Placement gating

A map placement may carry `when: [conditions]`. `AreaScene` only adds a placement (prop, solid, npc, door, enemy) whose `when` passes at scene build. The town gate uses this:

```brighterscript
p.push({type: "solid", col: 22, row: 3, w: 3, h: 1, when: [{notFlag: "gate.open"}]})  ' plugs the arch
p.push({type: "npc", id: "knight", col: 23, row: 5, facing: FacingDirection.down, when: [{notFlag: "gate.open"}]})
```

When `gateOpened` is posted mid-scene (always from the shop, since buying the sword is the last condition met, or from Bram's dialogue if the sword was bought first), `TownScene` rebuilds itself once the panel closes: `changeSceneWithFade("TownScene", {spawn: "gate"})`. The rebuilt scene skips the gated placements, so the knight and plug are gone, and the fade reads as a deliberate story beat ("the gate creaks open"). `BGE.SolidWorld` can't remove a solid (a Slice B non-goal), and this avoids adding that.

## The `Story` entity (`Story/Story.bs`)

A persistent, non-pauseable `GameEntity` named `"Story"`, with no drawables. It owns the `StoryFlags` and `Inventory`, and holds a reference to the `Player`.

- `onGameEvent()`: runs event rules for every event it sees (it listens to `enemyKilled`), applies their effects, re-runs `storyChanged`, posts any `post` events, then autosaves if anything changed.
- `runDialogueEffects(effects)` and `runChoice(choice)`: called by the dialogue box when a page or choice finishes.
- `buy(itemId)` and `useItem(itemId)`: called by the shop and inventory panels. They delegate to pure helpers in `Story/Shop.bs`:
  - `canBuy(itemId, price, ctx) as string`: `""` if allowed, otherwise the reason (`"Not enough coins"`, `"Already owned"`, `"Can't carry more"`).
  - `canUse(itemId, ctx) as string`: e.g. `"Already at full health"` for a potion.
- `objectives()`: returns `currentObjectives(...)` for the inventory panel.
- `save()`: builds and writes the save, and shows the "Saving…" note.

`Enemy.die()` posts `enemyKilled` with `{kind}` (`"rat"`/`"bat"`). `Enemy.hurt()` gains an `amount as integer = 1` parameter. The player passes `swordDamageFor(inventory)`.

Shop prices live in `Story/ShopData.bs` as `{itemId, price}` rows, so the shop panel and its rules both read one table.

## NPCs (`Entities/Npc.bs`)

```brighterscript
' args: {id, x, y (feet), facing, cell (index into npcs.png's character table), wander (radius px, 0 = still), solidWorld}
class Npc extends BGE.GameEntity
  npcId as string
  sub faceToward(x as float, y as float)
  sub setTalking(talking as boolean)   ' stops wandering and turns to the player while talking
end class
```

- Tagged `"npc"`. Its sprite is built from a character entry in `getNpcSheet()` (pure data in `Entities/NpcSheet.bs`: per character, the frame rectangle per facing for stand and walk).
- Depth sort the same way as everything else: `position.z = -feetY`.
- Still NPCs add a feet-sized solid (about 20×12) to the area's `SolidWorld`, so the player can't walk through them.
- A wanderer isn't solid. It picks a random target within `wander` of its home, walks there at 40 px/s with `solidWorld.moveAndSlide()`, idles 1–3 s, and repeats. If a move gets fully blocked it picks a new target.
- NPCs are pauseable, so they freeze while the dialogue box has the game paused.

## Talking (`Entities/Player.bs`, `Entities/Combat.bs`)

On an OK press the player first checks for someone to talk to:

- `talkBox(facing)` (pure, in `Combat.bs`) is the same shape as `swordBox(facing)`, relative to the feet.
- `nearestInBox(box, candidates)` (pure) returns the index of the candidate whose feet point is inside the box and nearest the player, or -1.
- If there's an NPC, the player posts `talkRequested {npcId}` (no swing). Otherwise it swings as today.

The `Story` entity handles `talkRequested`: it picks the dialogue page, turns the NPC toward the player, and opens the `DialogueBox`. With no matching page, nothing happens.

The player also stops moving and swinging while the game is paused (it's pauseable already, so this comes for free with `game.Pause()`).

## UI (`examples/rpg/src/source/UI/`)

All panels stay inside the title-safe area (≥10% in from every canvas edge).

### `DialogueBox` (`UI/DialogueBox.bs`)

A `BGE.UI.UiContainer` added to `gameUi` while open and removed after (the same build-fresh/tear-down pattern as `MessagePanel`, because of focus registration).

- Layout: a translucent dark panel across the bottom of the title-safe area, the speaker's name in the `hud` font, the body in a `Label` with `wrapWidth` set to the panel's inner width, and a small ▼ marker when more pages follow.
- Pages: every line of the page is wrapped with `BGE.UI.wrapText()`, then all lines are grouped into pages of 3. Each original `lines[]` entry starts a new page, so a writer can force a break.
- OK press advances. On the last page, if there are `choices`, they appear as `BGE.UI.Button`s (`FocusManager` list mode, Up/Down). OK on a choice runs it. Back closes the box from any page without running the page's `then` effects (so you can't skip a quest-giver and still lose the quest step, nor double-trigger rewards).
- While open: `game.Pause()` on open, `game.Resume()` on close, and `input.consume()` in its `onInput` so nothing else gets the press. `AreaScene.onInput()`'s Back-to-exit is skipped while a panel is open.
- On finishing the last page (OK with no choices, or a choice picked): call `Story.runDialogueEffects(page.then)` and then run the choice, so effects are applied once.

### `ShopPanel` (`UI/ShopPanel.bs`)

A `BGE.UI.MessagePanel` titled "Hilde's Wares", with one button per `ShopData` row (`"Steel sword — 10"`, with `(owned)` or `(max)` appended where relevant) and `Leave`. Activating a row calls `Story.buy()`. On success it plays the coin sound, refreshes the labels and saves. On refusal it shows the reason in the panel's message line. The game stays paused while the shop is open.

### `InventoryPanel` (`UI/InventoryPanel.bs`)

Toggled with **Play/Pause** (`*` stays the debug toggle). A `MessagePanel` titled "Inventory" that pauses the game and shows, as its message, the coins, the sword (rusty or steel), the heart container if owned, the potion count, and the current objectives under a "Quest" heading. Buttons: `Drink potion` (only when the potion count is above 0; refusal reasons like full health show in the message line) and `Close`. Play/Pause or Back closes it too.

### `SaveIndicator` (`UI/SaveIndicator.bs`)

A `UiWidget` in the bottom-right title-safe corner that shows "Saving…" in the `hud` font when `show()` is called, holds it for 1 s, then fades over 0.5 s. It lives on `gameUi` permanently, like the HUD.

### HUD

`HeartsHud` already reads `player.maxHealth`, so the extra heart shows with no change. (Confirm in the plan.)

## Saving (`Story/SaveGame.bs`)

One JSON string in the registry section `"bge-rpg"`, key `"save"`, through the engine's `registryWrite()`/`registryRead()`:

```json
{"version": 1, "scene": "TownScene", "spawn": "gate", "flags": {...}, "inventory": {...}, "player": {"health": 6, "maxHealth": 6, "coins": 12}}
```

- `buildSaveData(sceneName, spawn, flags, inventory, player) as roAssociativeArray` and `parseSaveData(json as string) as object` are pure. `parseSaveData` returns `invalid` for an empty string, unparseable JSON, a missing or different `version`, or a missing field, so a bad save behaves as no save.
- On load, `health` is clamped to 1..`maxHealth`, so a save made mid-defeat can't load a dead player.
- `Story.save()` runs:
  - when an area finishes building (end of `AreaScene.onCreate`, after `placeAt`), saving that scene and spawn;
  - when story effects or an event rule changed flags or the inventory;
  - after a purchase or using an item.
- Saves are skipped while `--param scene=...` or `--param stage=...` deep links are active, so testing doesn't overwrite a real save.
- `deleteSave()` writes an empty string for New Game.

## Start menu, scenes and deep links

- `TitleScene` (new) is always the first scene. Its background is the "Broadsword" key art without monsters (the same Gemini artwork as the splash; credited the same way), supplied by the repo owner as `images/title.jpg` and scaled to fill the UI canvas. The art has the logo across the top and the hero in the centre, so the menu goes **on the left**: a vertical stack of `BGE.UI.Button`s (`FocusManager` list mode) on a translucent dark backing, below the logo, inside the title-safe area. It's a small custom `TitleMenu` container rather than a `MessagePanel`, since `MessagePanel` always centres itself. The buttons are **Continue** (only when a save exists, and focused first) and **New Game**. The player and HUD are hidden on this scene (the HUD draws nothing while the current scene is `TitleScene`).
  - Continue: load flags, inventory and player stats into `Story`/`Player`, then `changeSceneWithFade(save.scene, {spawn: save.spawn})`.
  - New Game: `deleteSave()`, reset `Story` and `Player`, `changeSceneWithFade("TownScene", {spawn: "start"})`.
- Back on `TitleScene` exits the channel, like the areas.
- Deep links (main.bs): `--param scene=X` (existing) skips the menu. A new `--param stage=N` seeds flags for a story checkpoint (0 new, 1 hunting, 2 report, 3 vouched, 4 gate open with the sword), mainly for on-device checks. Both disable saving.

## Maps

### Town (smaller, ~32×22)

Redrawn `getTownRows()`/`getTownPlacements()` keeping the same pieces closer together:

- The castle wall and gate along the top (the gate keeps its arch solids and door, plus the gated plug solid and the knight).
- The fountain plaza in the centre, Bram beside the fountain.
- The market to the north-east with Hilde behind a stall.
- The well to the west, the child next to it, and the sewer tunnel entrance in the western wall.
- A small dock with water in the south-west, and the old woman on a bench.
- Two wanderers (plaza, market), 4 rats placed around the edges, and a `start` spawn in the plaza for New Game.

`TownGate.spec.bs` is updated for the new gate position, and gains a case that the plug solid blocks the arch until `gate.open`.

### Sewer (`Scenes/SewerScene.bs`, ~24×16)

A small maze: stone walkways, solid water channels and brick walls, using new ground characters if needed (e.g. `=` sewer water, drawn with the water tile). A ladder prop is the door back to town (spawn `sewer` in town, beside the tunnel). Placements include 4 rats and 3–4 `{type: "drain"}` points.

`RatSpawner` (`World/RatSpawner.bs`): a non-drawing entity added by `SewerScene`. Every 6 s, if fewer than 4 rats are alive (`game.getAllEntities("Rat")`, ignoring dying ones), it spawns a rat at a random drain whose cell is clear of the player (more than 96 px away), so a rat never appears on top of you.

## Testing

**Engine (`npm run check`)**: `TextWrap.spec.bs`, plus wrapped/multi-line cases in `Label.spec.bs` and `DrawableText.spec.bs`.

**Example (`cd examples/rpg && npm test`)**, one suite per file as Rooibos requires, added to `tests/bsconfig.test.json`'s explicit file list:

- `StoryFlags.spec.bs`: get/set/add, missing keys, case-sensitivity, `toAA`/`loadAA` round trip.
- `Inventory.spec.bs`: max counts, add/remove, `swordDamageFor`.
- `Conditions.spec.bs`: every condition kind, empty list, unknown key fails.
- `Effects.spec.bs`: every effect kind, coin floor at 0, heal cap, `onAcquire` runs on `giveItem`, `posts` returned.
- `DialogueData.spec.bs`: first match wins for each NPC at each story checkpoint, and `${}` interpolation.
- `EventRules.spec.bs`: rat kills only count at stage 1, the 4th kill advances, the gate opens with vouch+sword in either order, depth limit.
- `QuestData.spec.bs`: objective text for each checkpoint.
- `Shop.spec.bs`: can/can't buy (coins, owned, max), can/can't use a potion.
- `SaveGame.spec.bs`: round trip, wrong version, bad JSON, missing field, health clamp.
- `Talk.spec.bs`: `talkBox`/`nearestInBox` per facing, nearest wins, none in range.
- `TownGate.spec.bs` (updated).

**On device (rokubot, see the `rokubot-examples` skill)**, using `--param stage=N`:

- Each quest NPC's dialogue at each checkpoint (screenshots), paging and wrapping.
- The shop at stage 3 with and without enough coins, buying the sword and watching the gate open.
- The inventory panel, drinking a potion, the objective text.
- The "Saving…" note on a door transition.
- The title screen with and without a save (menu on the left, title-safe, readable over the art).
- Relaunch after a save: Continue / New Game, Continue puts you back in the right area and stage.
- The sewer: entering, the ladder back.
- Title-safe positions for every panel.

Combat and grinding in the sewer are real-time, so the repo owner plays those and reports how they feel.

## Docs

- `examples/rpg/src/sprites/CREDITS.md`: the NPC sheet, the Ails item icons (noting the rust recolour), and the title art.
- `CLAUDE.md`: the UI section gets `Label.wrapWidth`/`BGE.UI.wrapText()`. The rpg bullet gets the story layer, NPCs, the shop/inventory, saving, the sewer, and `--param stage`.
- `docs/`: mention `wrapWidth` wherever a guide covers `Label`.
- Slice D is #289 (goblins, captain and key, throne room, witch boss, ending, and whether to promote the story layer). Slice E is #290 (music and sound pass).
