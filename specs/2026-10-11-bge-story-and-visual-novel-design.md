# BGE.Story and the visual novel example - design

Issues: #298 (promote a generic `BGE.Story`), #294 (visual novel example).
Ships as two stacked PRs from this one design:

- **PR 1 (#298):** a new engine module `BGE.Story` (`src/source/story/`), and `examples/rpg` moved onto it.
- **PR 2 (#294):** `examples/visualnovel` - "The Mutiny", a short sci-fi visual novel built on `BGE.Story`.

## Goal

A story layer in the engine that two very different games share: an action RPG that picks NPC lines from the
world state, and a visual novel that branches through a graph of scenes. The API is shaped by both, not by
the rpg alone (the reason #298 waited for a second consumer).

## Prior art

We surveyed Ren'Py, ink, Yarn Spinner 2/3, Twine, Dialogic, Naninovel, and rule-based dialogue (Valve /
Ruskin GDC 2012, Hades). What we take from them:

- **Rules pick the entry, a graph runs the conversation.** Yarn Spinner 3's node groups (several nodes share
  one title, each with a `when:` header, and a saliency strategy picks one) are the model: the rpg's per-NPC
  page list is already a node group. Hades and Valve's system work the same way.
- **Visit counts per node** (ink, Yarn, Twine, Ren'Py, Hades), and **`once`** content built on them.
- **Two jumps:** `goto` (ink divert, Yarn jump) and `call`, which returns when the called node runs out
  (ink tunnel, Yarn detour, Ren'Py call). We use the plain words.
- **Choices** can be hidden or shown disabled when their conditions fail (Ren'Py, Yarn), and a choice with no
  label is a **fallback** taken automatically when nothing else is available (ink).
- **Saliency strategies:** first match (Yarn "First") and random-least-viewed (Yarn's default "Random Best
  Least Recently Viewed", Hades' random pick).
- **Save** is variables + visit counts + playback position (including the call stack); a **backlog** of shown
  lines is separate from rollback.

Deliberately not taken: an expression language (structured condition/effect AAs stay - safe, no parser,
articy/Hades-like), rollback, threads, inline conditional text beyond `${flag}`, specificity/priority
selection.

## Part 1: `BGE.Story` (engine)

All in namespace `BGE.Story`, under `src/source/story/`. Pure BrighterScript: no `Game`, no UI, no
registry, so every unit is testable with plain Rooibos specs. Nothing here draws anything or reads input.

### Story data

A story is a `StoryData` AA, written as an AA literal in code or loaded from a JSON file - both parse to the
same thing.

```
StoryData:  {nodes: {id: NodeEntry}, rules?: EventRule[], items?: {id: ItemDefinition}}
NodeEntry:  StoryNode | StoryNode[] | {select: "first" | "random", candidates: StoryNode[]}
StoryNode:  {when?, once?, speaker?, lines?: (string | StoryLine)[], effects?, choices?, call?, goto?, end?}
StoryLine:  {text, speaker?, ...}            ' extra keys pass through (e.g. portrait, background)
StoryChoice: {label?, when?, once?, showDisabled?, effects?, goto?, call?, id?, ...}  ' extra keys pass through
EventRule:  {event, match?, when?, effects}  ' unchanged from the rpg
```

- A node entry is one node, or a **candidate group**: a plain array means `select: "first"`.
- `speaker` on a node is the default for its lines; a line object can override it.
- Keys the engine doesn't know (a line's `portrait`, a choice's `open: "shop"`) are left alone for the game
  to read. The engine never strips or validates them.
- `then` is a BrightScript reserved word, so nothing uses it as a key (unchanged from the rpg).

### Conditions and effects

A condition or effect is an AA identified by its first recognized key. Every condition in a `when` list must
pass; a missing or empty list passes.

Built-in conditions:

| Condition | Passes when |
|---|---|
| `{flag}` / `{flag, eq}` / `{flag, gte}` / `{flag, lt}` | flag is set / equals / >= / < (unchanged semantics) |
| `{notFlag}` | flag is not set |
| `{hasItem}` / `{notItem}` | carried / not carried |
| `{visited}` / `{visited, gte}` / `{notVisited}` | node (or candidate group) entered at least once / at least n times / never |
| `{any: [conditions]}` | at least one of the nested conditions passes |

Built-in effects: `{set, value}`, `{add, amount}`, `{giveItem}` (runs the item's `onAcquire`), `{takeItem}`,
`{post}` (queue a game event name), `{message, speaker?}` (queue a message for the game to show).

**Game vocabulary** is registered on a `StoryState`:

```brighterscript
state.registerCondition("coinsGte", function(condition, state, context) as boolean ... end function, player)
state.registerEffect("heal", function(effect, state, context) as boolean ... end function, player)
```

- The handler receives the condition/effect AA, the `StoryState`, and the `context` passed at registration
  (BrightScript functions don't capture closures; this is how the rpg reaches its `Player`).
- An effect handler returns `true` if it changed story state (drives saving and the settle loop).
- A registered key wins over a built-in one with the same name. An unknown key logs one
  `[BGE.Story] warning` and fails (condition) or does nothing (effect), as today.

### `StoryFlags`, `Inventory`, `valueKind`

Moved from the rpg unchanged except for the namespace. `Inventory` takes item definitions
(`{id: {max, onAcquire?, ...}}`); games add their own fields (`name`, `icon`, `onUse`) and read them back.

### `StoryState`

Owns the story's mutable state and its vocabulary.

```brighterscript
state = new BGE.Story.StoryState(storyData)
state.flags            ' BGE.Story.StoryFlags
state.inventory        ' BGE.Story.Inventory, built from storyData.items
state.evaluate(conditions) as boolean
state.applyEffects(effects) as StoryResult
state.runEvent(eventName, data) as StoryResult   ' every matching rule, in order
state.settle() as StoryResult                   ' "storyChanged" rules until stable (max 4 passes, then a warning)
state.visitCount(nodeId) as integer
state.interpolate(text) as string                ' ${flag} -> value
state.toSaveData() as StorySaveData              ' {flags, inventory, visits}
state.loadSaveData(data)                         ' sanitizes like StoryFlags.loadAA/Inventory.loadAA do today
```

`StoryResult` is unchanged: `{changed, posts, messages}`.

`interpolate` replaces each `${key}` with the flag's value: a string as-is, an integer/float via `toStr()`,
a boolean as `true`/`false`, and a **missing flag as `""`** (the rpg's version used `0`; set a counter to 0
explicitly if text shows it before it's first counted). A `${` with no closing `}` is left as written.

### `DialogueRunner`

A UI-free state machine that plays nodes. A game's dialogue box asks it what to show and tells it what the
player did.

```brighterscript
runner = new BGE.Story.DialogueRunner(state, storyData)
runner.start(nodeId) as boolean          ' false if no candidate passes
runner.isActive() as boolean
runner.currentLine() as StoryLineView    ' {text (interpolated), speaker, line (the raw StoryLine AA)}, or invalid while choosing
runner.advance() as StoryResult          ' next line; at the node's end, see below
runner.isChoosing() as boolean
runner.choices() as ChoiceView[]         ' {label (interpolated), enabled, choice (raw AA)}
runner.choose(index) as StoryResult
runner.backlog as StoryLineView[]        ' lines shown so far, oldest first, capped at backlogLimit (default 100)
runner.getPosition() as RunnerPosition   ' save mid-conversation
runner.restore(position) as boolean
```

**Entering a node** (by `start`, `goto` or `call`): if the id is a candidate group, pick a candidate (below).
The picked node's visit count goes up, and so does the group's, so `{visited: "bram"}` works for a group.
A candidate's own visit key is `<groupId>#<index>`.

**Selection:** a candidate is eligible when its `when` passes and it isn't a `once` node that's been visited.
- `first` (default): the first eligible candidate.
- `random`: the eligible candidates with the fewest visits, then one of those at random. The random function
  is injectable (`runner.random = function(count) as integer`) so tests are deterministic.

**End of a node's lines:** the node's `effects` run (once, when the player leaves the last line - backing out
before then runs nothing). Then, in order:
1. `choices` - the runner switches to choosing. Each choice is evaluated: passing ones are enabled, failing
   ones are dropped unless `showDisabled`, in which case they're listed with `enabled: false`. A `once`
   choice that's been taken (visit key `<nodeKey>/<choice id or label>`) is dropped. If no labelled choice
   is enabled and a choice with no `label` (a fallback) passes, it's taken immediately.
2. `call` - push a return point and enter the called node; when the called conversation runs out, resume
   here and continue with step 3.
3. `goto` - enter that node.
4. `end: true` - the whole conversation ends, call stack and all.
5. Otherwise the node has run out: pop the call stack and resume there, or end the conversation if it's
   empty.

**Choosing:** the choice's `effects` run, then its `call` (returning re-shows the calling node's choices,
re-evaluated - the hub pattern), else its `goto`, else the node has run out (step 5). Pass-through keys
(e.g. `open`) are the game's to act on after `choose()` returns.

A node with no lines goes straight to its end-of-node steps, so a node can be a pure router (a candidate
group whose candidates only `goto`).

**Saving a position:** `getPosition()` returns `{stack: [{node, line, choosing}]}` with node keys; `restore()`
returns `false` if a key no longer exists (e.g. the story file changed), in which case the game restarts the
node or the story.

The runner returns every `StoryResult` it produced from `advance()`/`choose()`; the game settles, saves and
posts as it does today.

### Loading and validation

```brighterscript
story = BGE.Story.loadStory("pkg:/story/mutiny.json")   ' StoryData, or invalid (logs why)
errors = BGE.Story.validateStory(story, state)          ' string[], empty when fine
```

`validateStory` reports: `goto`/`call` targets that don't exist, condition/effect keys that aren't
built in or registered on `state`, candidate groups with an unknown `select` or no candidates, and nodes
with nothing to do (no lines, choices, call, goto or end). `loadStory` only parses; call `validateStory` after
registering the game's vocabulary. Both games run it in a spec over their real story data.

### Files

`src/source/story/`: `ValueKinds.bs`, `StoryFlags.bs`, `Inventory.bs`, `StoryTypes.bs`, `Conditions.bs`,
`Effects.bs`, `StoryState.bs`, `Selection.bs`, `DialogueRunner.bs`, `StoryLoader.bs`, `StoryValidation.bs`,
each with a colocated `*.spec.bs` (one `@suite` per file).

### Docs

A new published guide, `docs/story.md` (group Guides): flags and conditions first, then a talking NPC (rpg
style), then a branching scene (visual novel style), then registering your own vocabulary and saving.
CLAUDE.md gains a `BGE.Story` bullet; the rpg bullet stops saying the story layer stays in the example.

## Part 1b: moving the rpg onto `BGE.Story`

- **Deleted from the rpg** (now in the engine): `ValueKinds.bs`, `StoryFlags.bs`, `Inventory.bs`, `Text.bs`,
  the generic halves of `Conditions.bs`, `Effects.bs`, `EventRules.bs`, `DialogueData.bs` (selection) and
  `StoryTypes.bs`.
- **Stays, rewritten against the engine:** a `StoryData` built in code (`getStoryData()`: `nodes` from today's
  dialogue, `rules` from `getEventRules()`, `items` from `getItemDefinitions()`), `RpgVocabulary.bs`
  registering `coinsGte`, `giveCoins`, `takeCoins`, `heal`, `addMaxHealth`, plus `PlayerStats`, items' game
  fields, shop, quests, checkpoints, credits, save data, `filterPlacements`/live placements (now calling
  `state.evaluate`), and the `Story` entity, which owns a `StoryState` and a `DialogueRunner`.
- **`DialogueBox`** takes the runner instead of a page: it shows `currentLine()` paged as today, calls
  `advance()`, shows `choices()`, and calls `choose()`. `choice.open` (`"shop"`, `"credits"`) is still read by
  the rpg.
- **Townsfolk** (`wanderPlaza`, `wanderMarket`, `child`, `oldWoman`) get two or three interchangeable lines
  per story stage as `select: "random"` groups - the showcase for random selection.
- **Save data** goes to version 2, adding `visits`. A version 1 save still loads (empty visits) - the rpg's
  only story state that would care is dialogue `once`, which it doesn't use yet.
- **Missing flags interpolate as `""` now:** Bram's quest-start page also sets `rats.kills` to 0, so "Still
  rats about. ${rats.kills} of 4" reads "0 of 4" before the first kill, as it does today.
- **One behavior change:** a page's effects now run when its last line is read, before its choices show,
  rather than after the choice. Backing out of a choice list no longer undoes them. Only Bram's final page
  has both effects and choices; its "The End" choice is the only one, so nothing is lost.
- The rpg's tests: generic specs move to the engine; the rpg keeps specs for its own vocabulary, data
  (including `validateStory` over `getStoryData()`), shop, quests and checkpoints. Its `bsconfig.test.json`
  pulls in `src/source/story/*.bs` as it does `SolidWorld.bs` today.
- Verified by `npm run check`, the rpg's own `npm test`, and an on-device run through talking to Bram,
  the gate and the shop, plus a random townsfolk line repeating only after the others.

## Part 2: "The Mutiny" (`examples/visualnovel`)

### Story

The player is the Captain of the survey ship *Centaur* (never shown). About 15 nodes, three endings.

Cast (Justin Nichol's portraits):
- **Husk** (`Husk_thumb.png`) - the ship's synthetic first officer. Unreadable; the obvious suspect.
- **Dr. Ilan Voss** (`science-officer.png`) - science officer. Hiding something, not the mutineer.
- **Chief Dario Castell** (`SecurityOfficer.png`) - head of security. Charming; the real mutineer, who wants
  the derelict's technology to sell.
- **Lt. Mira Sato** (`StarPilot.png`) - star pilot. Sure the distress call is a trap.

Locations: the *Centaur*'s bridge (`centaurbridgeRender.png`), the derelict *Greyan* bridge
(`greyan_bridge.png`), the research lab (`ancientartefactresearch/render.png`).

Outline:
1. **Bridge** - a distress call from the Greyan ship. Answer it or log it; Castell pushes to board either way.
2. **Briefing** - each officer argues; choices set per-officer trust flags.
3. **Away team** - take Sato or Castell. Each reveals different things.
4. **Greyan bridge** - the data core (clue item).
5. **Lab** - Voss decodes the signal: a warning, not a distress call. He asks you to keep it quiet.
6. **Night shift** - Husk reports the nav log was altered (clue).
7. **Interview hub** - Sato, Castell, Voss, Husk in any order. Each conversation is a choice `call` back to
   the hub; clue questions are `once`; Husk's idle lines are a `random` group; `{visited}` unlocks "I've
   heard enough".
8. **Confrontation** - accuse someone. Accusations without enough clues are `showDisabled`; a fallback "Stand
   down" is always there.

Endings: **Accuse Castell with the clues** (mutiny stopped, the warning heeded - best); **accuse the wrong
officer** (Castell takes the ship); **stand down** (jump away safe, never knowing). The story exercises every
engine feature: candidate groups both ways, `goto`, `call`, `once` nodes and choices, `visited`, `any`, items
as clues, `showDisabled`, a fallback choice, `${flag}` text, and event rules (a `storyChanged` rule that
notices when all three clues are held).

Written as `src/story/mutiny.json`. Lines carry `background` and `portrait` keys the game reads; `speaker`
names the character.

### Screen

Game canvas 1280x720; everything drawn in `gameUi` (keeping UI-canvas text crisp).
- **Background** - a full-screen image, cross-faded when a line's `background` changes.
- **Portraits** - up to two framed cards, left and right (the art has flat grey backdrops, so a frame suits
  it; one pose per character, no expressions). The speaker is full brightness, the other dimmed.
- **Text box** - bottom of the screen, title-safe, with a name tab. Text types out; OK completes the line,
  the next OK advances.
- **Choices** - a vertical list of buttons above the text box; disabled ones greyed and unfocusable.
- **Backlog** - `*`, or Up while reading a line (not while choosing, where Up moves focus), opens a scrollable list of past lines (`runner.backlog`); Back closes it.

### Saving and title

- `TitleScene`: Continue (if a save exists), New Game, and the endings seen so far.
- Autosave on every node entry: `{version, state: state.toSaveData(), position: runner.getPosition(),
  backlog}` under registry section `bge-visualnovel`. A position that won't restore starts the story over.
- Endings seen are a separate registry key, kept across New Game.

### Input

Remote; gamepad (`multi_controllers=1`, A/B as OK/Back via button aliases, the left stick moves focus); the
phone controller through the existing controller-web dispatch. The FocusManager in `list` mode handles
choices.

### Assets and loading

- Backgrounds committed pre-sized to 1280x720 JPG (the bridge render is 3840x2160 - far too big for an HD
  Roku's 64MB of texture memory). Portraits pre-sized to a card height (~480px).
- `StageScene` loads the backgrounds through its `onLoad` `AssetLoader`; the portraits are small enough to
  load together.
- `src/images/CREDITS.md` with each asset's licence and attribution, checked on its OpenGameArt page, and
  the title screen credits them.
- No music or sound in this version.

### Code

- `main.bs` - game setup, scenes, deep links (`--param node=<id>`, `flags=`, `items=`; saving off when used).
- `Scenes/TitleScene.bs`, `Scenes/StageScene.bs` (owns the `StoryState` and `DialogueRunner`, drives the UI).
- `UI/`: `TextBox`, `ChoiceList`, `PortraitCard`, `BacklogPanel`.
- `Story/Vocabulary.bs` (registers anything the VN needs beyond the built-ins - expected to be nothing,
  which is itself the test of the core), `Story/SaveData.bs`.

### Testing

- `examples/visualnovel/tests/`: `validateStory` over `mutiny.json`, every ending reachable by a scripted
  playthrough (a spec drives a `DialogueRunner` with fixed choices to each ending), save/restore round trip.
- On-device via rokubot: title, a playthrough to one ending, backlog, Continue after relaunch. The user
  plays through the rest.

## Out of scope

- An expression language or a text script format (JSON only).
- Rollback, auto-advance, text speed settings, music.
- Priority/specificity selection.
- Reusable VN UI widgets in `BGE.UI` (the VN's UI stays in the example until a second user needs it).
