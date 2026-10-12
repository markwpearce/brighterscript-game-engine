# BGE.Story (PR 1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Promote the rpg's story layer to an engine module, `BGE.Story` (flags, inventory, conditions, effects, event rules, a node-graph `DialogueRunner`, JSON loading and validation), add a tiny text-only `examples/story`, and move `examples/rpg` onto the engine module (closes #298).

**Architecture:** Pure BrighterScript under `src/source/story/`, namespace `BGE.Story`, with no `Game`/UI/registry dependency. `StoryState` owns the mutable state (flags, inventory, visit counts) and the condition/effect vocabulary (built-ins plus `registerCondition`/`registerEffect`). `DialogueRunner` is a UI-free state machine over a `StoryData` graph: candidate-group selection (`first`/`random`), lines, choices, `goto`/`call`/`end`, `once`, a backlog, and save/restore of its position. Games own all UI.

**Tech Stack:** BrighterScript (`bsc` 1.0.0-alpha), Rooibos v6 (`rooibos-roku`), `brs-cli` headless tests, rokubot for on-device checks.

**Spec:** `specs/2026-10-11-bge-story-and-visual-novel-design.md` (Part 1, 1a, 1b). Part 2 (the visual novel) is a separate plan: `specs/2026-10-11-visual-novel-plan.md`.

## Global Constraints

- Branch: `feature/issue-298-bge-story` (already created; the spec commits are on it). Never commit to `main`.
- All engine code is in namespace `BGE.Story`, under `src/source/story/`, one `@suite` per `*.spec.bs`, specs colocated.
- Every file that uses another file's symbol `import`s it (CLAUDE.md conventions).
- `goto`, `call` and `end` are BrightScript reserved words: engine code reads them only with brackets (`node["goto"]`); BrighterScript AA literals write them quoted (`{"goto": "hub"}`). Never `node.goto`. `then` and `stop` are never used as keys or method names.
- Never compare a possibly-`invalid` or mixed-type value with `=`/`<>` directly: use `BGE.Story.valueKind()`/`BGE.Story.isTrue()` first (a missing flag is `invalid`, and `invalid = 2` can crash).
- `assertEqual` is type-strict (Integer vs Float); compare scalars, not whole objects with circular references.
- Missing flags interpolate as `""`.
- Warnings print with the prefix `[BGE.Story] warning: `.
- Doc comments are written for game developers using the engine; implementation notes are inline comments, kept to 1-3 sentences.
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Quality gate after every engine task: `npm run validate` and `npm run test:ci` pass. Before the PR: `npm run check:all`, `cd examples/rpg && npm test`, and on-device runs of `examples/story` and `examples/rpg` via the `rokubot-examples` skill.

## Review Focus

1. **A `goto`/`call` to a node whose candidates all fail** - the conversation must continue (call) or end cleanly (goto), with a warning, never hang or crash. Tested in Task 5.
2. **Nodes that route to each other without ever showing a line** (a `goto` cycle through line-less nodes) - the runner must stop after `RUNNER_MAX_STEPS` with a warning, not freeze the Roku. Tested in Task 5.
3. **A saved position that no longer matches the story** (node renamed, line index past the end, junk registry data) - `restore()` must return `false` and leave the runner inactive. Tested in Task 6.
4. **Malformed JSON or data** (a choice that isn't an AA, a `when` that isn't a list, an unknown condition key, a non-string `goto`) - `validateStory` reports it, and the runner doesn't crash on it at runtime (unknown keys warn and fail). Tested in Tasks 2 and 7.
5. **A choice list where every labelled choice is disabled-but-shown and no fallback exists** - the node must not get stuck in "choosing" with nothing selectable; it continues to `call`/`goto`/run out. Tested in Task 6.

---

## File structure

**Engine (new), `src/source/story/`:**

| File | Responsibility |
|---|---|
| `ValueKinds.bs` | `valueKind()`, `isTrue()` |
| `StoryFlags.bs` | `StoryFlags` class (moved from rpg) |
| `Inventory.bs` | `Inventory` class (moved from rpg) |
| `Text.bs` | `interpolateFlags()` |
| `StoryTypes.bs` | every interface: data, results, views, frames, handlers |
| `Conditions.bs` | `evaluateConditions()`, `conditionPasses()`, `flagEquals()`, `isBuiltInConditionKey()` |
| `Effects.bs` | `applyEffects()`, `applyEffect()`, `newStoryResult()`, `mergeStoryResult()`, `isBuiltInEffectKey()` |
| `EventRules.bs` | `runEventRules()`, `ruleMatches()`, `settleRules()` |
| `StoryState.bs` | `StoryState` class |
| `Selection.bs` | `getCandidates()`, `getSelectMode()`, `selectNode()`, `resolveNodeKey()`, `defaultRandom()`, `newFrame()`, `lineCount()`, `isLabelled()`, `choiceKey()` |
| `DialogueRunner.bs` | `DialogueRunner` class |
| `StoryLoader.bs` | `loadStory()` |
| `StoryValidation.bs` | `validateStory()` and its helpers |

Specs: `ValueKinds.spec.bs`, `StoryFlags.spec.bs`, `Inventory.spec.bs`, `Text.spec.bs`, `Conditions.spec.bs`, `Effects.spec.bs`, `EventRules.spec.bs`, `StoryState.spec.bs`, `Selection.spec.bs`, `DialogueRunner.spec.bs`, `DialogueRunnerChoices.spec.bs`, `DialogueRunnerPosition.spec.bs`, `StoryLoader.spec.bs`, `StoryValidation.spec.bs`.

**Example (new):** `examples/story/` (scaffolded by `npm run create-example`), with `src/story/jokes.json`, `src/source/main.bs`, `src/source/Scenes/StoryScene.bs`, `src/source/UI/ChoiceButton.bs`, `tests/Jokes.spec.bs`, `bsconfig.test.json`.

**Docs:** `docs/story.md` (new), `CLAUDE.md` (edit).

**rpg:** delete `Story/ValueKinds.bs`, `Story/StoryFlags.bs`, `Story/Inventory.bs`, `Story/Text.bs`, `Story/Conditions.bs`, `Story/Effects.bs`, `Story/DialogueData.bs`; rewrite `Story/StoryTypes.bs`, `Story/EventRules.bs`, `Story/Items.bs`, `Story/ShopData.bs`, `Story/QuestData.bs`, `Story/SaveData.bs`, `Story/Checkpoints.bs`, `Story/Story.bs`, `UI/DialogueBox.bs`, `Maps/LivePlacements.bs`, `Maps/MapTypes.bs`, consumers listed in Task 10; new `Story/StoryData.bs`, `Story/RpgVocabulary.bs`.

---

### Task 1: Value kinds, flags, inventory, interpolation

Move the four leaf pieces into the engine. `StoryFlags` and `Inventory` keep their exact behaviour; `interpolateFlags` changes one thing (missing flag → `""`).

**Files:**
- Create: `src/source/story/ValueKinds.bs`, `src/source/story/StoryFlags.bs`, `src/source/story/Inventory.bs`, `src/source/story/Text.bs`, and a minimal `src/source/story/StoryTypes.bs` (only `ItemDefinition` and `StoryEffect` for now - Task 2 fills in the rest)
- Test: `src/source/story/ValueKinds.spec.bs`, `StoryFlags.spec.bs`, `Inventory.spec.bs`, `Text.spec.bs`

**Interfaces:**
- Produces: `BGE.Story.valueKind(value as dynamic) as string` ("integer"/"float"/"boolean"/"string"/"invalid"/lowercased type); `BGE.Story.isTrue(value as dynamic) as boolean`; `class BGE.Story.StoryFlags` with `clear()`, `get(key) as dynamic`, `getInt(key) as integer`, `isSet(key) as boolean`, `set(key, value) as boolean`, `add(key, amount) as boolean`, `toAA()`, `loadAA(data)`; `class BGE.Story.Inventory` with `new(definitions as roAssociativeArray)`, `clear()`, `count(id)`, `has(id)`, `canAdd(id)`, `add(id) as boolean`, `remove(id) as boolean`, `toAA()`, `loadAA(data)`; `BGE.Story.interpolateFlags(text as string, flags as StoryFlags) as string`; `interface BGE.Story.ItemDefinition extends roAssociativeArray {max as integer, optional onAcquire as StoryEffect[]}`.

- [ ] **Step 1: Write the failing specs**

Copy the rpg's `examples/rpg/tests/StoryFlags.spec.bs`, `Inventory.spec.bs` and `ValueKinds.spec.bs` to `src/source/story/` with these changes: rename classes `StoryFlags`→`BGE.Story.StoryFlags`, `Inventory`→`BGE.Story.Inventory`, `valueKind`→`BGE.Story.valueKind`; in `Inventory.spec.bs` replace `getItemDefinitions()` with a local fixture:

```brighterscript
    private function items() as roAssociativeArray
      return {
        sword: {max: 1},
        potion: {max: 3}
      }
    end function
```

and rename item ids in its tests (`steelSword`→`sword`, `potion` stays; any other rpg id → `sword` or `potion` matching its `max`). Prefix each `@suite` name with `BGE.Story.` (e.g. `@suite("BGE.Story.StoryFlags")`). Add to `ValueKinds.spec.bs`:

```brighterscript
    @it("isTrue is true only for a boolean true")
    function _()
      m.assertTrue(BGE.Story.isTrue(true))
      m.assertFalse(BGE.Story.isTrue(false))
      m.assertFalse(BGE.Story.isTrue(invalid))
      m.assertFalse(BGE.Story.isTrue(1))
      m.assertFalse(BGE.Story.isTrue("true"))
    end function
```

Create `src/source/story/Text.spec.bs`:

```brighterscript
namespace tests
  @suite("BGE.Story.interpolateFlags")
  class StoryTextTests extends rooibos.BaseTestSuite

    private flags as BGE.Story.StoryFlags

    protected override function beforeEach()
      m.flags = new BGE.Story.StoryFlags()
    end function

    @it("replaces each ${key} with the flag's value, of any kind")
    function _()
      m.flags.set("name", "Castell")
      m.flags.set("count", 3)
      m.flags.set("ratio", 1.5)
      m.flags.set("open", true)
      m.assertEqual("Castell has 3 at 1.5, true", BGE.Story.interpolateFlags("${name} has ${count} at ${ratio}, ${open}", m.flags))
    end function

    @it("reads a missing flag as an empty string")
    function _()
      m.assertEqual("You accused .", BGE.Story.interpolateFlags("You accused ${mutiny.accused}.", m.flags))
    end function

    @it("leaves an unclosed ${ as written")
    function _()
      m.assertEqual("broken ${name", BGE.Story.interpolateFlags("broken ${name", m.flags))
    end function

    @it("returns text without placeholders unchanged")
    function _()
      m.assertEqual("plain", BGE.Story.interpolateFlags("plain", m.flags))
    end function

  end class
end namespace
```

- [ ] **Step 2: Run the tests to see them fail**

Run: `npm run test:ci`
Expected: the build fails with `cannot-find-name` for `BGE.Story.*`.

- [ ] **Step 3: Implement**

`src/source/story/ValueKinds.bs`:

```brighterscript
namespace BGE.Story

  ' The kind of a story value, the same on a real Roku and the simulator (which name boxed types
  ' differently, e.g. roInt vs roInteger).
  '
  ' @param {dynamic} value
  ' @return {string} "integer", "float", "boolean", "string", "invalid", or the lowercased type name
  function valueKind(value as dynamic) as string
    valueType = LCase(type(value))
    if Left(valueType, 2) = "ro"
      valueType = Mid(valueType, 3)
    end if
    if valueType = "int" or valueType = "integer" or valueType = "longinteger"
      return "integer"
    else if valueType = "float" or valueType = "double"
      return "float"
    else if valueType = "boolean"
      return "boolean"
    else if valueType = "string"
      return "string"
    end if
    return valueType
  end function

  ' True only for a boolean true - safe on a missing (invalid) or non-boolean value.
  '
  ' @param {dynamic} value
  ' @return {boolean}
  function isTrue(value as dynamic) as boolean
    if valueKind(value) = "boolean"
      return value
    end if
    return false
  end function

end namespace
```

`src/source/story/StoryFlags.bs`: the rpg's `examples/rpg/src/source/Story/StoryFlags.bs` verbatim, wrapped in `namespace BGE.Story` ... `end namespace`, with its class doc comment rewritten for engine users:

```brighterscript
  ' The story's blackboard: named values (booleans, integers, floats, strings) that story data reads
  ' with conditions and changes with effects - quest stages, who you've talked to, what you chose.
```

`src/source/story/Inventory.bs`: the rpg's `Inventory.bs` verbatim inside `namespace BGE.Story`, importing `"ValueKinds.bs"` and `"StoryTypes.bs"` (not `Items.bs`), with the constructor doc `' @param {roAssociativeArray} definitions - item id -> ItemDefinition (at least a max)`.

`src/source/story/StoryTypes.bs` (minimal; Task 2 replaces it with the full file):

```brighterscript
namespace BGE.Story

  ' One entry in an effects list. See the Story guide for every built-in effect.
  interface StoryEffect extends roAssociativeArray
    optional set as string
    optional value as boolean or integer or float or string
    optional add as string
    optional amount as integer
    optional giveItem as string
    optional takeItem as string
    optional post as string
    optional message as string
    optional speaker as string
  end interface

  ' An item the inventory can hold. Add any fields your game needs (name, icon) alongside these.
  interface ItemDefinition extends roAssociativeArray
    ' how many can be carried
    max as integer
    ' effects run each time one is gained
    optional onAcquire as StoryEffect[]
  end interface

end namespace
```

`src/source/story/Text.bs`:

```brighterscript
import "StoryFlags.bs"

namespace BGE.Story

  ' Replaces each ${key} in text with that flag's value. A missing flag reads as "", a boolean as
  ' true/false, and a ${ with no closing } is left as written.
  '
  ' @param {string} text
  ' @param {StoryFlags} flags
  ' @return {string}
  function interpolateFlags(text as string, flags as StoryFlags) as string
    result = ""
    rest = text
    while true
      start = Instr(1, rest, "${")
      if start = 0
        return result + rest
      end if
      finish = Instr(start + 2, rest, "}")
      if finish = 0
        return result + rest
      end if
      key = Mid(rest, start + 2, finish - start - 2)
      value = flags.get(key)
      kind = valueKind(value)
      if kind = "invalid"
        valueText = ""
      else if kind = "string"
        valueText = value
      else
        valueText = value.toStr()
      end if
      result = result + Left(rest, start - 1) + valueText
      rest = Mid(rest, finish + 1)
    end while
    return result
  end function

end namespace
```

`Text.bs` also needs `import "ValueKinds.bs"`.

- [ ] **Step 4: Run the tests**

Run: `npm run validate && npm run test:ci`
Expected: PASS. If `true.toStr()` prints something other than `true` under brs-engine, read the failure diff and make `interpolateFlags` map booleans explicitly (`if value then "true" else "false"`), keeping the test as written.

- [ ] **Step 5: Commit**

```bash
git add src/source/story
git commit -m "BGE.Story: flags, inventory, value kinds and interpolation (#298)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Types, StoryState and conditions

**Files:**
- Modify: `src/source/story/StoryTypes.bs` (full version below)
- Create: `src/source/story/Conditions.bs`, `src/source/story/StoryState.bs`, plus stub `Effects.bs`/`EventRules.bs` (Task 3 fills them; create them now with the functions StoryState calls, returning `newStoryResult()`)
- Test: `src/source/story/Conditions.spec.bs`, `src/source/story/StoryState.spec.bs`

**Interfaces:**
- Consumes: Task 1.
- Produces:
  - `class BGE.Story.StoryState` - `new(story = invalid as StoryData)`, fields `flags as StoryFlags`, `inventory as Inventory`, `items as roAssociativeArray`, `rules as EventRule[]`; methods `registerCondition(key as string, handler as StoryHandlerFunction, context = invalid as dynamic)`, `registerEffect(key, handler, context = invalid)`, `isKnownCondition(condition as roAssociativeArray) as boolean`, `isKnownEffect(effect as roAssociativeArray) as boolean`, `findConditionHandler(condition) as dynamic` (a `StoryHandler` or invalid), `findEffectHandler(effect) as dynamic`, `evaluate(conditions as StoryCondition[]) as boolean`, `applyEffects(effects as StoryEffect[]) as StoryResult`, `runEvent(eventName as string, data = {} as roAssociativeArray) as StoryResult`, `settle() as StoryResult`, `visitCount(key as string) as integer`, `recordVisit(key as string)`, `interpolate(text as string) as string`, `reset()`, `toSaveData() as StorySaveData`, `loadSaveData(data as dynamic)`.
  - `BGE.Story.evaluateConditions(conditions as StoryCondition[], state as StoryState) as boolean`, `BGE.Story.isBuiltInConditionKey(key as string) as boolean`.
  - The handler signature everywhere: `function(item as roAssociativeArray, state as object, context as dynamic) as boolean` (`state` is `as object` - the bsc self-reference workaround, since it's the `StoryState`).

- [ ] **Step 1: Write the full `StoryTypes.bs`**

```brighterscript
' Shapes of story data, results and runner state. See the Story guide (docs/story.md).
namespace BGE.Story

  ' One entry in a `when` list. Identified by its first known key: flag (optionally with eq, gte or
  ' lt), notFlag, hasItem, notItem, visited (optionally with gte), notVisited, any - or a key your
  ' game registered with StoryState.registerCondition().
  interface StoryCondition extends roAssociativeArray
    optional flag as string
    optional eq as boolean or integer or string
    optional gte as integer
    optional lt as integer
    optional notFlag as string
    optional hasItem as string
    optional notItem as string
    optional visited as string
    optional notVisited as string
    optional any as StoryCondition[]
  end interface

  ' One entry in an `effects` list: set (with value), add (with amount), giveItem, takeItem, post,
  ' message (with an optional speaker) - or a key your game registered with registerEffect().
  interface StoryEffect extends roAssociativeArray
    optional set as string
    optional value as boolean or integer or float or string
    optional add as string
    optional amount as integer
    optional giveItem as string
    optional takeItem as string
    optional post as string
    optional message as string
    optional speaker as string
  end interface

  ' An item the inventory can hold. Add any fields your game needs (name, icon) alongside these.
  interface ItemDefinition extends roAssociativeArray
    ' how many can be carried
    max as integer
    ' effects run each time one is gained
    optional onAcquire as StoryEffect[]
  end interface

  ' A story change that happens on a game event. Every rule whose event, match and when pass runs.
  interface EventRule extends roAssociativeArray
    event as string
    ' each key must equal the same field of the event's data
    optional match as roAssociativeArray
    optional when as StoryCondition[]
    effects as StoryEffect[]
  end interface

  ' A line written as an object. Any other keys (a portrait, a background) are left for your game.
  interface StoryLine extends roAssociativeArray
    text as string
    optional speaker as string
  end interface

  ' A button at the end of a node. A choice with no label is a fallback, taken automatically when no
  ' labelled choice is available. It may also have "goto" or "call" (read with brackets - they're
  ' reserved words) and any keys your game reads itself.
  interface StoryChoice extends roAssociativeArray
    optional label as string
    ' names the choice for `once` (defaults to its label)
    optional id as string
    optional when as StoryCondition[]
    optional once as boolean
    ' listed but not selectable when `when` fails, instead of hidden
    optional showDisabled as boolean
    optional effects as StoryEffect[]
  end interface

  ' One node: lines to show, then effects, then choices, "call", "goto" or "end" (bracket keys).
  interface StoryNode extends roAssociativeArray
    optional when as StoryCondition[]
    optional once as boolean
    ' the speaker of lines that don't name their own
    optional speaker as string
    ' each a string or a StoryLine
    optional lines as dynamic[]
    optional effects as StoryEffect[]
    optional choices as StoryChoice[]
  end interface

  ' A whole story. Each node id maps to a StoryNode, a list of candidate StoryNodes (the first whose
  ' `when` passes is used), or {select: "first" | "random", candidates: StoryNode[]}.
  interface StoryData extends roAssociativeArray
    nodes as roAssociativeArray
    optional rules as EventRule[]
    ' item id -> ItemDefinition
    optional items as roAssociativeArray
  end interface

  ' A message effect: text to show, and who says it ("" for nobody).
  interface StoryMessage
    text as string
    speaker as string
  end interface

  ' What a batch of effects or rules did.
  interface StoryResult
    ' true if any story state changed (save, and settle the rules)
    changed as boolean
    ' event names from post effects, in order
    posts as string[]
    messages as StoryMessage[]
  end interface

  ' StoryState.toSaveData(): plain values, safe to write with BGE.registryWrite().
  interface StorySaveData extends roAssociativeArray
    flags as roAssociativeArray
    inventory as roAssociativeArray
    visits as roAssociativeArray
  end interface

  ' A line as DialogueRunner shows it.
  interface StoryLineView
    ' with ${flags} filled in
    text as string
    speaker as string
    ' the line as written ({text} for a plain string), for your game's own keys
    line as roAssociativeArray
    ' true for a choice the player took (in the backlog)
    isChoice as boolean
  end interface

  ' A choice as DialogueRunner lists it.
  interface ChoiceView
    ' with ${flags} filled in
    label as string
    ' false for a showDisabled choice whose `when` fails
    enabled as boolean
    ' the choice as written, for your game's own keys
    choice as StoryChoice
    ' its index in the node's choices
    index as integer
  end interface

  ' A registered condition or effect.
  interface StoryHandler
    fn as function(item as roAssociativeArray, state as object, context as dynamic) as boolean
    context as dynamic
  end interface

  ' One node in the runner's stack (internal).
  interface RunnerFrame
    ' the node's visit key: an id, or "<groupId>#<index>" for a candidate ("" for startNode())
    key as string
    node as StoryNode
    line as integer
    ' the last line added to the backlog
    shownLine as integer
    ' lines, choices, choosing, choiceCall, call, afterCall, runOut
    phase as string
  end interface

  ' A saved RunnerFrame.
  interface RunnerFrameData
    key as string
    line as integer
    phase as string
  end interface

  ' DialogueRunner.getPosition(): plain values, safe to save.
  interface RunnerPosition extends roAssociativeArray
    stack as RunnerFrameData[]
  end interface

  ' A node picked by selectNode().
  interface SelectedNode
    key as string
    node as StoryNode
  end interface

end namespace
```

If bsc rejects the typed `fn` field or the `any` field name, read the diagnostic: use `fn as function` for the former (and keep the signature in a comment); for the latter, stop and report - the spec names it `any`.

- [ ] **Step 2: Write the failing specs**

`src/source/story/Conditions.spec.bs`:

```brighterscript
namespace tests
  @suite("BGE.Story conditions")
  class StoryConditionsTests extends rooibos.BaseTestSuite

    private state as BGE.Story.StoryState

    protected override function beforeEach()
      m.state = new BGE.Story.StoryState({nodes: {}, items: {key: {max: 1}}})
    end function

    @it("passes an empty or missing list")
    function _()
      m.assertTrue(m.state.evaluate([]))
      m.assertTrue(m.state.evaluate(invalid))
    end function

    @it("compares a missing flag as 0/false")
    function _()
      m.assertTrue(m.state.evaluate([{flag: "stage", eq: 0}]))
      m.assertFalse(m.state.evaluate([{flag: "stage", eq: 2}]))
      m.assertTrue(m.state.evaluate([{flag: "open", eq: false}]))
      m.assertTrue(m.state.evaluate([{flag: "stage", lt: 1}]))
      m.assertTrue(m.state.evaluate([{flag: "name", eq: ""}]))
    end function

    @it("checks eq, gte and lt on a set flag, and string eq")
    function _()
      m.state.flags.set("kills", 3)
      m.state.flags.set("partner", "Sato")
      m.assertTrue(m.state.evaluate([{flag: "kills", eq: 3}, {flag: "kills", gte: 3}]))
      m.assertFalse(m.state.evaluate([{flag: "kills", gte: 4}]))
      m.assertFalse(m.state.evaluate([{flag: "kills", lt: 3}]))
      m.assertTrue(m.state.evaluate([{flag: "partner", eq: "Sato"}]))
      m.assertFalse(m.state.evaluate([{flag: "partner", eq: "Castell"}]))
    end function

    @it("checks flag, notFlag, hasItem and notItem")
    function _()
      m.assertTrue(m.state.evaluate([{notFlag: "vouched"}, {notItem: "key"}]))
      m.state.flags.set("vouched", true)
      m.state.inventory.add("key")
      m.assertTrue(m.state.evaluate([{flag: "vouched"}, {hasItem: "key"}]))
    end function

    @it("checks visited, visited gte and notVisited")
    function _()
      m.assertTrue(m.state.evaluate([{notVisited: "hub"}]))
      m.state.recordVisit("hub")
      m.state.recordVisit("hub")
      m.assertTrue(m.state.evaluate([{visited: "hub"}, {visited: "hub", gte: 2}]))
      m.assertFalse(m.state.evaluate([{visited: "hub", gte: 3}]))
      m.assertFalse(m.state.evaluate([{notVisited: "hub"}]))
    end function

    @it("passes any when one nested condition passes, and fails when none do")
    function _()
      m.assertFalse(m.state.evaluate([{any: [{flag: "a"}, {flag: "b"}]}]))
      m.state.flags.set("b", true)
      m.assertTrue(m.state.evaluate([{any: [{flag: "a"}, {flag: "b"}]}]))
    end function

    @it("fails an unknown condition rather than crashing")
    function _()
      m.assertFalse(m.state.evaluate([{coinsGte: 3}]))
      m.assertFalse(m.state.evaluate([{eq: 3}]))
    end function

    @it("uses a registered condition, passing its context")
    function _()
      wallet = {coins: 5}
      m.state.registerCondition("coinsGte", function(condition as roAssociativeArray, state as object, context as dynamic) as boolean
        return context.coins >= condition.coinsGte
      end function, wallet)
      m.assertTrue(m.state.evaluate([{coinsGte: 5}]))
      m.assertFalse(m.state.evaluate([{coinsGte: 6}]))
      m.assertTrue(m.state.isKnownCondition({coinsGte: 1}))
      m.assertFalse(m.state.isKnownCondition({gemsGte: 1}))
      m.assertTrue(m.state.isKnownCondition({flag: "x", eq: 1}))
    end function

  end class
end namespace
```

`src/source/story/StoryState.spec.bs`:

```brighterscript
namespace tests
  @suite("BGE.Story.StoryState")
  class StoryStateTests extends rooibos.BaseTestSuite

    private state as BGE.Story.StoryState

    protected override function beforeEach()
      m.state = new BGE.Story.StoryState({nodes: {}, items: {key: {max: 2}}})
    end function

    @it("builds its inventory from the story's items")
    function _()
      m.assertTrue(m.state.inventory.add("key"))
      m.assertFalse(m.state.inventory.add("map"))
    end function

    @it("works with no story at all")
    function _()
      empty = new BGE.Story.StoryState()
      m.assertEqual(0, empty.visitCount("anything"))
      m.assertFalse(empty.settle().changed)
    end function

    @it("counts visits, case-insensitively")
    function _()
      m.assertEqual(0, m.state.visitCount("hub"))
      m.state.recordVisit("hub")
      m.state.recordVisit("Hub")
      m.assertEqual(2, m.state.visitCount("HUB"))
    end function

    @it("interpolates with its flags")
    function _()
      m.state.flags.set("n", 2)
      m.assertEqual("2 of 4", m.state.interpolate("${n} of 4"))
    end function

    @it("round-trips flags, inventory and visits through save data")
    function _()
      m.state.flags.set("stage", 3)
      m.state.inventory.add("key")
      m.state.recordVisit("hub")
      saved = m.state.toSaveData()
      other = new BGE.Story.StoryState({nodes: {}, items: {key: {max: 2}}})
      other.loadSaveData(saved)
      m.assertEqual(3, other.flags.getInt("stage"))
      m.assertEqual(1, other.inventory.count("key"))
      m.assertEqual(1, other.visitCount("hub"))
    end function

    @it("treats junk save data as a fresh state, dropping non-integer visits")
    function _()
      m.state.flags.set("stage", 3)
      m.state.loadSaveData("junk")
      m.assertEqual(0, m.state.flags.getInt("stage"))
      m.state.loadSaveData({flags: {}, inventory: {}, visits: {hub: "lots", lab: 2, bad: -1}})
      m.assertEqual(0, m.state.visitCount("hub"))
      m.assertEqual(2, m.state.visitCount("lab"))
      m.assertEqual(0, m.state.visitCount("bad"))
    end function

    @it("reset clears flags, inventory and visits but keeps the same objects")
    function _()
      flagsBefore = m.state.flags
      flagsBefore.set("x", 1)
      m.state.inventory.add("key")
      m.state.recordVisit("hub")
      m.state.reset()
      m.assertEqual(0, flagsBefore.getInt("x"))
      m.assertEqual(0, m.state.inventory.count("key"))
      m.assertEqual(0, m.state.visitCount("hub"))
    end function

  end class
end namespace
```

- [ ] **Step 3: Run to see them fail**

Run: `npm run test:ci`
Expected: build fails, `BGE.Story.StoryState` not found.

- [ ] **Step 4: Implement**

`src/source/story/Conditions.bs`:

```brighterscript
import "ValueKinds.bs"
import "StoryFlags.bs"
import "StoryTypes.bs"
import "StoryState.bs"

namespace BGE.Story

  ' True when every condition passes. An empty or missing list passes.
  '
  ' @param {StoryCondition[]} conditions - or invalid
  ' @param {StoryState} state
  ' @return {boolean}
  function evaluateConditions(conditions as StoryCondition[], state as StoryState) as boolean
    if type(conditions) <> "roArray"
      return true
    end if
    for each condition in conditions
      if not conditionPasses(condition, state)
        return false
      end if
    end for
    return true
  end function

  ' Never compares a stored flag with = directly - a missing one is invalid, and invalid = 2 can crash.
  function conditionPasses(condition as StoryCondition, state as StoryState) as boolean
    if type(condition) <> "roAssociativeArray"
      print "[BGE.Story] warning: a condition isn't an object: " + FormatJson(condition)
      return false
    end if
    handler = state.findConditionHandler(condition)
    if handler <> invalid
      return handler.fn(condition, state, handler.context)
    end if
    flags = state.flags
    if condition.DoesExist("any")
      if type(condition.any) <> "roArray"
        return false
      end if
      for each nested in condition.any
        if conditionPasses(nested, state)
          return true
        end if
      end for
      return false
    else if condition.DoesExist("flag")
      key = condition.flag
      if condition.DoesExist("eq")
        return flagEquals(flags, key, condition.eq)
      else if condition.DoesExist("gte")
        return flags.getInt(key) >= condition.gte
      else if condition.DoesExist("lt")
        return flags.getInt(key) < condition.lt
      end if
      return flags.isSet(key)
    else if condition.DoesExist("notFlag")
      return not flags.isSet(condition.notFlag)
    else if condition.DoesExist("hasItem")
      return state.inventory.has(condition.hasItem)
    else if condition.DoesExist("notItem")
      return not state.inventory.has(condition.notItem)
    else if condition.DoesExist("visited")
      if condition.DoesExist("gte")
        return state.visitCount(condition.visited) >= condition.gte
      end if
      return state.visitCount(condition.visited) > 0
    else if condition.DoesExist("notVisited")
      return state.visitCount(condition.notVisited) = 0
    end if
    print "[BGE.Story] warning: unknown story condition " + FormatJson(condition)
    return false
  end function

  function flagEquals(flags as StoryFlags, key as string, expected as boolean or integer or string) as boolean
    expectedKind = valueKind(expected)
    if expectedKind = "boolean"
      return flags.isSet(key) = (expected as boolean)
    end if
    if expectedKind = "string"
      value = flags.get(key)
      if valueKind(value) <> "string"
        return (expected as string) = ""
      end if
      return value = expected
    end if
    return flags.getInt(key) = (expected as integer)
  end function

  ' The keys that name a built-in condition (modifiers like eq and gte don't count).
  function isBuiltInConditionKey(key as string) as boolean
    return key = "flag" or key = "notFlag" or key = "hasItem" or key = "notItem" or key = "visited" or key = "notVisited" or key = "any"
  end function

end namespace
```

`src/source/story/StoryState.bs`:

```brighterscript
import "ValueKinds.bs"
import "StoryFlags.bs"
import "Inventory.bs"
import "Text.bs"
import "StoryTypes.bs"
import "Conditions.bs"
import "Effects.bs"
import "EventRules.bs"

namespace BGE.Story

  ' A story's state - flags, the inventory and how often each node was visited - and the
  ' conditions and effects its data can use. Built-in vocabulary is in the Story guide; add your
  ' game's own with registerCondition() and registerEffect().
  class StoryState

    flags as StoryFlags = invalid
    inventory as Inventory = invalid
    ' item id -> ItemDefinition, from the story's items
    items as roAssociativeArray = invalid
    rules as EventRule[] = []
    ' node/choice visit key -> count (case-insensitive, like node ids)
    private visits as roAssociativeArray = invalid
    ' key -> StoryHandler
    private conditionHandlers as roAssociativeArray = invalid
    private effectHandlers as roAssociativeArray = invalid

    ' @param {StoryData} story - its items and rules are used; may be invalid
    sub new(story = invalid as StoryData)
      m.items = {}
      m.rules = []
      if type(story) = "roAssociativeArray"
        if type(story.items) = "roAssociativeArray"
          m.items = story.items
        end if
        if type(story.rules) = "roArray"
          m.rules = story.rules
        end if
      end if
      m.flags = new StoryFlags()
      m.inventory = new Inventory(m.items)
      m.visits = {}
      m.conditionHandlers = {}
      m.conditionHandlers.SetModeCaseSensitive()
      m.effectHandlers = {}
      m.effectHandlers.SetModeCaseSensitive()
    end sub

    ' Adds a condition key, e.g. coinsGte. A registered key takes priority over a built-in one.
    '
    ' @param {string} key - the condition's identifying key
    ' @param {function} handler - function(condition, state, context) as boolean: true if it passes
    ' @param {dynamic} context - passed to the handler (BrightScript functions can't capture variables)
    sub registerCondition(key as string, handler as function(item as roAssociativeArray, state as object, context as dynamic) as boolean, context = invalid as dynamic)
      m.conditionHandlers[key] = {fn: handler, context: context}
    end sub

    ' Adds an effect key, e.g. heal.
    '
    ' @param {string} key - the effect's identifying key
    ' @param {function} handler - function(effect, state, context) as boolean: true if story state changed
    ' @param {dynamic} context - passed to the handler
    sub registerEffect(key as string, handler as function(item as roAssociativeArray, state as object, context as dynamic) as boolean, context = invalid as dynamic)
      m.effectHandlers[key] = {fn: handler, context: context}
    end sub

    ' @return {dynamic} the StoryHandler for a registered key of this condition, or invalid
    function findConditionHandler(condition as roAssociativeArray) as dynamic
      for each key in m.conditionHandlers
        if condition.DoesExist(key)
          return m.conditionHandlers[key]
        end if
      end for
      return invalid
    end function

    ' @return {dynamic} the StoryHandler for a registered key of this effect, or invalid
    function findEffectHandler(effect as roAssociativeArray) as dynamic
      for each key in m.effectHandlers
        if effect.DoesExist(key)
          return m.effectHandlers[key]
        end if
      end for
      return invalid
    end function

    ' @return {boolean} true if a key of this condition is built in or registered
    function isKnownCondition(condition as roAssociativeArray) as boolean
      for each key in condition
        if isBuiltInConditionKey(key) or m.conditionHandlers.DoesExist(key)
          return true
        end if
      end for
      return false
    end function

    ' @return {boolean} true if a key of this effect is built in or registered
    function isKnownEffect(effect as roAssociativeArray) as boolean
      for each key in effect
        if isBuiltInEffectKey(key) or m.effectHandlers.DoesExist(key)
          return true
        end if
      end for
      return false
    end function

    ' @param {StoryCondition[]} conditions - or invalid (passes)
    ' @return {boolean} true if every condition passes
    function evaluate(conditions as StoryCondition[]) as boolean
      return BGE.Story.evaluateConditions(conditions, m)
    end function

    ' @param {StoryEffect[]} effects - or invalid
    ' @return {StoryResult}
    function applyEffects(effects as StoryEffect[]) as StoryResult
      return BGE.Story.applyEffects(effects, m)
    end function

    ' Runs every event rule for this event whose match and when pass.
    '
    ' @param {string} eventName
    ' @param {roAssociativeArray} data - the event's data, matched against each rule's match
    ' @return {StoryResult}
    function runEvent(eventName as string, data = {} as roAssociativeArray) as StoryResult
      return BGE.Story.runEventRules(m.rules, eventName, data, m)
    end function

    ' Runs "storyChanged" rules until nothing more changes. Call it after anything changes the story.
    '
    ' @return {StoryResult}
    function settle() as StoryResult
      return BGE.Story.settleRules(m.rules, m)
    end function

    ' @param {string} key - a node id, a candidate's "<id>#<index>", or a choice's "<node>/<id or label>"
    ' @return {integer}
    function visitCount(key as string) as integer
      count = m.visits[key]
      if valueKind(count) = "integer"
        return count
      end if
      return 0
    end function

    sub recordVisit(key as string)
      m.visits[key] = m.visitCount(key) + 1
    end sub

    ' @return {string} text with each ${flag} filled in
    function interpolate(text as string) as string
      return interpolateFlags(text, m.flags)
    end function

    ' Clears flags, the inventory and visits (for a new game). Registered vocabulary stays.
    sub reset()
      m.flags.clear()
      m.inventory.clear()
      m.visits = {}
    end sub

    ' @return {StorySaveData}
    function toSaveData() as StorySaveData
      visitsCopy = {}
      visitsCopy.Append(m.visits)
      return {flags: m.flags.toAA(), inventory: m.inventory.toAA(), visits: visitsCopy}
    end function

    ' Loads toSaveData()'s output. Anything malformed is dropped, so a bad save gives a fresh state.
    '
    ' @param {dynamic} data
    sub loadSaveData(data as dynamic)
      m.reset()
      if type(data) <> "roAssociativeArray"
        return
      end if
      m.flags.loadAA(data.flags)
      m.inventory.loadAA(data.inventory)
      if type(data.visits) = "roAssociativeArray"
        for each key in data.visits
          count = data.visits[key]
          if valueKind(count) = "integer"
            if count > 0
              m.visits[key] = count
            end if
          end if
        end for
      end if
    end sub

  end class

end namespace
```

Stubs so it builds (Task 3 replaces both files):

`src/source/story/Effects.bs`:

```brighterscript
import "StoryTypes.bs"
import "StoryState.bs"

namespace BGE.Story
  function newStoryResult() as StoryResult
    return {changed: false, posts: [], messages: []}
  end function
  function applyEffects(effects as StoryEffect[], state as StoryState) as StoryResult
    return newStoryResult()
  end function
  function isBuiltInEffectKey(key as string) as boolean
    return false
  end function
end namespace
```

`src/source/story/EventRules.bs`:

```brighterscript
import "StoryTypes.bs"
import "StoryState.bs"
import "Effects.bs"

namespace BGE.Story
  function runEventRules(rules as EventRule[], eventName as string, data as roAssociativeArray, state as StoryState) as StoryResult
    return newStoryResult()
  end function
  function settleRules(rules as EventRule[], state as StoryState) as StoryResult
    return newStoryResult()
  end function
end namespace
```

- [ ] **Step 5: Run the tests**

Run: `npm run validate && npm run test:ci`
Expected: PASS. If bsc reports a `field-inheritance-mismatch`/self-reference error in `StoryState.bs` for the handler signature, change `state as object` stays as is; if it still fails, change the param type to `handler as function` (untyped) and keep the signature in the doc comment.

- [ ] **Step 6: Commit**

```bash
git add src/source/story
git commit -m "BGE.Story: StoryState, story types and conditions (#298)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Effects and event rules

**Files:**
- Modify: `src/source/story/Effects.bs`, `src/source/story/EventRules.bs` (replace the stubs)
- Test: `src/source/story/Effects.spec.bs`, `src/source/story/EventRules.spec.bs`

**Interfaces:**
- Consumes: Task 2's `StoryState`.
- Produces: `BGE.Story.applyEffects(effects, state) as StoryResult`, `BGE.Story.newStoryResult() as StoryResult`, `BGE.Story.mergeStoryResult(into as StoryResult, source as StoryResult)`, `BGE.Story.isBuiltInEffectKey(key) as boolean`, `BGE.Story.runEventRules(rules, eventName, data, state) as StoryResult`, `BGE.Story.ruleMatches(match, data) as boolean`, `BGE.Story.settleRules(rules, state) as StoryResult`, `const BGE.Story.STORY_SETTLE_MAX_PASSES = 4`.

- [ ] **Step 1: Write the failing specs**

`src/source/story/Effects.spec.bs`:

```brighterscript
namespace tests
  @suite("BGE.Story effects")
  class StoryEffectsTests extends rooibos.BaseTestSuite

    private state as BGE.Story.StoryState

    protected override function beforeEach()
      m.state = new BGE.Story.StoryState({
        nodes: {},
        items: {
          key: {max: 1},
          clue: {max: 1, onAcquire: [{add: "clues", amount: 1}, {post: "clueFound"}, {message: "A clue!", speaker: "Husk"}]}
        }
      })
    end function

    @it("returns an unchanged result for no effects")
    function _()
      result = m.state.applyEffects(invalid)
      m.assertFalse(result.changed)
      m.assertEqual(0, result.posts.count())
    end function

    @it("sets and adds flags, reporting a change only when the value changes")
    function _()
      m.assertTrue(m.state.applyEffects([{set: "stage", value: 1}]).changed)
      m.assertFalse(m.state.applyEffects([{set: "stage", value: 1}]).changed)
      m.state.applyEffects([{add: "stage", amount: 2}])
      m.assertEqual(3, m.state.flags.getInt("stage"))
    end function

    @it("gives an item and runs its onAcquire effects")
    function _()
      result = m.state.applyEffects([{giveItem: "clue"}])
      m.assertTrue(result.changed)
      m.assertEqual(1, m.state.flags.getInt("clues"))
      m.assertEqual(["clueFound"], result.posts)
      m.assertEqual("A clue!", result.messages[0].text)
      m.assertEqual("Husk", result.messages[0].speaker)
    end function

    @it("doesn't give past an item's max, and takes items")
    function _()
      m.state.applyEffects([{giveItem: "key"}])
      m.assertFalse(m.state.applyEffects([{giveItem: "key"}]).changed)
      m.assertTrue(m.state.applyEffects([{takeItem: "key"}]).changed)
      m.assertFalse(m.state.applyEffects([{takeItem: "key"}]).changed)
    end function

    @it("queues posts and messages without counting them as changes")
    function _()
      result = m.state.applyEffects([{post: "doorOpened"}, {message: "Click."}])
      m.assertFalse(result.changed)
      m.assertEqual(["doorOpened"], result.posts)
      m.assertEqual("", result.messages[0].speaker)
    end function

    @it("ignores an unknown effect")
    function _()
      m.assertFalse(m.state.applyEffects([{heal: 2}]).changed)
    end function

    @it("uses a registered effect, passing its context")
    function _()
      wallet = {coins: 1}
      m.state.registerEffect("giveCoins", function(effect as roAssociativeArray, state as object, context as dynamic) as boolean
        context.coins += effect.giveCoins
        return true
      end function, wallet)
      m.assertTrue(m.state.applyEffects([{giveCoins: 4}]).changed)
      m.assertEqual(5, wallet.coins)
      m.assertTrue(m.state.isKnownEffect({giveCoins: 1}))
      m.assertTrue(m.state.isKnownEffect({set: "x", value: 1}))
      m.assertFalse(m.state.isKnownEffect({value: 1}))
    end function

  end class
end namespace
```

`src/source/story/EventRules.spec.bs`:

```brighterscript
namespace tests
  @suite("BGE.Story event rules")
  class StoryEventRulesTests extends rooibos.BaseTestSuite

    private state as BGE.Story.StoryState

    protected override function beforeEach()
      m.state = new BGE.Story.StoryState({
        nodes: {},
        rules: [
          {event: "enemyKilled", match: {kind: "rat"}, when: [{flag: "hunting"}], effects: [{add: "kills", amount: 1}]},
          {event: "storyChanged", when: [{flag: "kills", gte: 2}, {notFlag: "done"}], effects: [{set: "done", value: true}, {post: "huntDone"}]},
          {event: "storyChanged", when: [{flag: "done"}, {flag: "reward", lt: 1}], effects: [{set: "reward", value: 1}]}
        ]
      })
    end function

    @it("runs a rule only when its event, match and when pass")
    function _()
      m.assertFalse(m.state.runEvent("enemyKilled", {kind: "rat"}).changed)
      m.state.flags.set("hunting", true)
      m.state.runEvent("enemyKilled", {kind: "bat"})
      m.state.runEvent("enemyKilled", {kind: "rat"})
      m.assertEqual(1, m.state.flags.getInt("kills"))
    end function

    @it("doesn't match when the data is missing the field or has another type")
    function _()
      m.state.flags.set("hunting", true)
      m.state.runEvent("enemyKilled", {})
      m.state.runEvent("enemyKilled", {kind: 7})
      m.state.runEvent("enemyKilled")
      m.assertEqual(0, m.state.flags.getInt("kills"))
    end function

    @it("settles chained storyChanged rules in one call")
    function _()
      m.state.flags.set("kills", 2)
      result = m.state.settle()
      m.assertTrue(result.changed)
      m.assertEqual(["huntDone"], result.posts)
      m.assertEqual(1, m.state.flags.getInt("reward"))
    end function

    @it("stops a rule loop after the maximum passes")
    function _()
      looping = new BGE.Story.StoryState({nodes: {}, rules: [{event: "storyChanged", effects: [{add: "n", amount: 1}]}]})
      looping.settle()
      m.assertEqual(4, looping.flags.getInt("n"))
    end function

  end class
end namespace
```

- [ ] **Step 2: Run to see them fail**

Run: `npm run test:ci`
Expected: FAIL (stub `applyEffects` changes nothing).

- [ ] **Step 3: Implement**

`src/source/story/Effects.bs`:

```brighterscript
import "ValueKinds.bs"
import "StoryTypes.bs"
import "StoryState.bs"

namespace BGE.Story

  ' @return {StoryResult} an empty result
  function newStoryResult() as StoryResult
    return {changed: false, posts: [], messages: []}
  end function

  ' Adds source's changes, posts and messages to into.
  sub mergeStoryResult(into as StoryResult, source as StoryResult)
    into.changed = into.changed or source.changed
    into.posts.append(source.posts)
    into.messages.append(source.messages)
  end sub

  ' Applies effects in order.
  '
  ' @param {StoryEffect[]} effects - or invalid
  ' @param {StoryState} state
  ' @return {StoryResult}
  function applyEffects(effects as StoryEffect[], state as StoryState) as StoryResult
    result = newStoryResult()
    if type(effects) <> "roArray"
      return result
    end if
    for each effect in effects
      if applyEffect(effect, state, result)
        result.changed = true
      end if
    end for
    return result
  end function

  ' @return {boolean} true if story state changed
  function applyEffect(effect as StoryEffect, state as StoryState, result as StoryResult) as boolean
    if type(effect) <> "roAssociativeArray"
      print "[BGE.Story] warning: an effect isn't an object: " + FormatJson(effect)
      return false
    end if
    handler = state.findEffectHandler(effect)
    if handler <> invalid
      return handler.fn(effect, state, handler.context)
    end if
    if effect.DoesExist("set")
      return state.flags.set(effect.set, effect.value)
    else if effect.DoesExist("add")
      return state.flags.add(effect.add, effect.amount)
    else if effect.DoesExist("giveItem")
      if not state.inventory.add(effect.giveItem)
        return false
      end if
      definition = state.items[effect.giveItem] as ItemDefinition
      mergeStoryResult(result, applyEffects(definition.onAcquire, state))
      return true
    else if effect.DoesExist("takeItem")
      return state.inventory.remove(effect.takeItem)
    else if effect.DoesExist("post")
      result.posts.push(effect.post)
      return false
    else if effect.DoesExist("message")
      speaker = ""
      if valueKind(effect.speaker) = "string"
        speaker = effect.speaker
      end if
      result.messages.push({text: effect.message, speaker: speaker})
      return false
    end if
    print "[BGE.Story] warning: unknown story effect " + FormatJson(effect)
    return false
  end function

  ' The keys that name a built-in effect (modifiers like value and amount don't count).
  function isBuiltInEffectKey(key as string) as boolean
    return key = "set" or key = "add" or key = "giveItem" or key = "takeItem" or key = "post" or key = "message"
  end function

end namespace
```

`src/source/story/EventRules.bs`:

```brighterscript
import "ValueKinds.bs"
import "StoryTypes.bs"
import "StoryState.bs"
import "Conditions.bs"
import "Effects.bs"

namespace BGE.Story

  const STORY_SETTLE_MAX_PASSES = 4

  ' Runs every rule for this event whose match and when pass, in order.
  '
  ' @param {EventRule[]} rules
  ' @param {string} eventName
  ' @param {roAssociativeArray} data - the event's data
  ' @param {StoryState} state
  ' @return {StoryResult}
  function runEventRules(rules as EventRule[], eventName as string, data as roAssociativeArray, state as StoryState) as StoryResult
    total = newStoryResult()
    for each rule in rules
      if rule.event = eventName and ruleMatches(rule.match, data) and evaluateConditions(rule.when, state)
        mergeStoryResult(total, applyEffects(rule.effects, state))
      end if
    end for
    return total
  end function

  ' @return {boolean} true if every key of match equals the same field of data
  function ruleMatches(match as roAssociativeArray, data as roAssociativeArray) as boolean
    if type(match) <> "roAssociativeArray"
      return true
    end if
    for each key in match
      if type(data) <> "roAssociativeArray" or not data.DoesExist(key)
        return false
      end if
      ' Compare kinds first so <> never sees mismatched types.
      if valueKind(data[key]) <> valueKind(match[key])
        return false
      end if
      if data[key] <> match[key]
        return false
      end if
    end for
    return true
  end function

  ' Runs "storyChanged" rules until nothing more changes, at most STORY_SETTLE_MAX_PASSES times.
  '
  ' @return {StoryResult} across every pass
  function settleRules(rules as EventRule[], state as StoryState) as StoryResult
    total = newStoryResult()
    for pass = 1 to STORY_SETTLE_MAX_PASSES
      result = runEventRules(rules, "storyChanged", {}, state)
      total.posts.append(result.posts)
      total.messages.append(result.messages)
      if not result.changed
        return total
      end if
      total.changed = true
    end for
    print "[BGE.Story] warning: story rules still changing after " + STORY_SETTLE_MAX_PASSES.toStr() + " passes"
    return total
  end function

end namespace
```

`runEvent(eventName)` with no data passes `{}` (the default param), so `ruleMatches` with a `match` returns false - matching the test.

- [ ] **Step 4: Run the tests**

Run: `npm run validate && npm run test:ci`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/source/story
git commit -m "BGE.Story: effects, event rules and the settle loop (#298)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Node selection

**Files:**
- Create: `src/source/story/Selection.bs`
- Test: `src/source/story/Selection.spec.bs`

**Interfaces:**
- Consumes: `StoryState.evaluate()`, `visitCount()`.
- Produces: `BGE.Story.getCandidates(entry as dynamic) as dynamic` (a `StoryNode[]` or invalid), `BGE.Story.getSelectMode(entry as dynamic) as string` ("first" default; "" for a non-string `select`), `BGE.Story.selectNode(id as string, story as StoryData, state as StoryState, random as function(count as integer) as integer) as SelectedNode` (or invalid), `BGE.Story.resolveNodeKey(key as string, story as StoryData) as StoryNode` (or invalid), `BGE.Story.defaultRandom(count as integer) as integer`, `BGE.Story.newFrame(key as string, node as StoryNode) as RunnerFrame`, `BGE.Story.lineCount(node as StoryNode) as integer`, `BGE.Story.isLabelled(choice as StoryChoice) as boolean`, `BGE.Story.choiceKey(nodeKey as string, choice as StoryChoice, index as integer) as string`.

- [ ] **Step 1: Write the failing spec**

`src/source/story/Selection.spec.bs`:

```brighterscript
namespace tests
  @suite("BGE.Story node selection")
  class StorySelectionTests extends rooibos.BaseTestSuite

    private state as BGE.Story.StoryState
    private story as BGE.Story.StoryData
    ' indexes the fake random function returns, in order
    private rolls as integer[]

    protected override function beforeEach()
      m.story = {
        nodes: {
          single: {lines: ["hi"]},
          gated: {when: [{flag: "open"}], lines: ["open"]},
          firstMatch: [
            {when: [{flag: "late"}], lines: ["late"]},
            {once: true, lines: ["intro"]},
            {lines: ["default"]}
          ],
          chatter: {select: "random", candidates: [
            {lines: ["a"]},
            {lines: ["b"]},
            {when: [{flag: "never"}], lines: ["c"]}
          ]}
        }
      }
      m.state = new BGE.Story.StoryState(m.story)
    end function

    private function pick(id as string) as dynamic
      return BGE.Story.selectNode(id, m.story, m.state, function(count as integer) as integer
        return 0
      end function)
    end function

    @it("selects a single node by its id")
    function _()
      m.assertEqual("single", m.pick("single").key)
    end function

    @it("returns invalid for an unknown id or a single node whose when fails")
    function _()
      m.assertInvalid(m.pick("nope"))
      m.assertInvalid(m.pick("gated"))
      m.state.flags.set("open", true)
      m.assertEqual("gated", m.pick("gated").key)
    end function

    @it("takes the first passing candidate, skipping a visited once node")
    function _()
      m.assertEqual("firstMatch#1", m.pick("firstMatch").key)
      m.state.recordVisit("firstMatch#1")
      m.assertEqual("firstMatch#2", m.pick("firstMatch").key)
      m.state.flags.set("late", true)
      m.assertEqual("firstMatch#0", m.pick("firstMatch").key)
    end function

    @it("picks randomly among the least-visited passing candidates")
    function _()
      m.assertEqual("chatter#0", m.pick("chatter").key)
      m.state.recordVisit("chatter#0")
      ' only #1 has the fewest visits now, whatever the roll
      m.assertEqual("chatter#1", m.pick("chatter").key)
      m.state.recordVisit("chatter#1")
      m.assertEqual("chatter#0", m.pick("chatter").key)
    end function

    @it("passes the pool size to the random function")
    function _()
      seen = {count: -1}
      GetGlobalAA().selectionTestSeen = seen
      BGE.Story.selectNode("chatter", m.story, m.state, function(count as integer) as integer
        GetGlobalAA().selectionTestSeen.count = count
        return count - 1
      end function)
      m.assertEqual(2, seen.count)
    end function

    @it("resolves keys back to nodes")
    function _()
      m.assertEqual("hi", BGE.Story.resolveNodeKey("single", m.story).lines[0])
      m.assertEqual("b", BGE.Story.resolveNodeKey("chatter#1", m.story).lines[0])
      m.assertInvalid(BGE.Story.resolveNodeKey("chatter#9", m.story))
      m.assertInvalid(BGE.Story.resolveNodeKey("chatter", m.story))
      m.assertInvalid(BGE.Story.resolveNodeKey("gone", m.story))
    end function

    @it("names choices by id, then label, then index")
    function _()
      m.assertEqual("hub/ask", BGE.Story.choiceKey("hub", {id: "ask", label: "Ask"}, 0))
      m.assertEqual("hub/Ask", BGE.Story.choiceKey("hub", {label: "Ask"}, 0))
      m.assertEqual("hub/3", BGE.Story.choiceKey("hub", {}, 3))
    end function

    @it("defaultRandom stays in range")
    function _()
      for i = 1 to 20
        roll = BGE.Story.defaultRandom(3)
        m.assertTrue(roll >= 0 and roll <= 2)
      end for
    end function

  end class
end namespace
```

- [ ] **Step 2: Run to see it fail**

Run: `npm run test:ci` - Expected: build fails, `BGE.Story.selectNode` not found.

- [ ] **Step 3: Implement**

`src/source/story/Selection.bs`:

```brighterscript
import "ValueKinds.bs"
import "StoryTypes.bs"
import "StoryState.bs"

namespace BGE.Story

  ' @param {dynamic} entry - a story.nodes value
  ' @return {dynamic} its candidate list, or invalid for a single node
  function getCandidates(entry as dynamic) as dynamic
    if type(entry) = "roArray"
      return entry
    end if
    if type(entry) = "roAssociativeArray" and type(entry.candidates) = "roArray"
      return entry.candidates
    end if
    return invalid
  end function

  ' @return {string} "first" (the default), "random", whatever string was written, or "" for a non-string
  function getSelectMode(entry as dynamic) as string
    if type(entry) = "roAssociativeArray" and entry.DoesExist("select")
      if valueKind(entry.select) = "string"
        return entry.select
      end if
      return ""
    end if
    return "first"
  end function

  function isEligibleNode(node as dynamic, key as string, state as StoryState) as boolean
    if type(node) <> "roAssociativeArray"
      return false
    end if
    if isTrue(node.once) and state.visitCount(key) > 0
      return false
    end if
    return state.evaluate(node.when)
  end function

  ' Picks the node to play for an id: the node itself, or one of its candidates.
  '
  ' @return {SelectedNode} or invalid if nothing passes
  function selectNode(id as string, story as StoryData, state as StoryState, random as function(count as integer) as integer) as SelectedNode
    entry = story.nodes[id]
    if entry = invalid
      return invalid
    end if
    candidates = getCandidates(entry)
    if candidates = invalid
      if isEligibleNode(entry, id, state)
        return {key: id, node: entry}
      end if
      return invalid
    end if
    eligible = [] as integer[]
    for i = 0 to candidates.count() - 1
      if isEligibleNode(candidates[i], id + "#" + i.toStr(), state)
        eligible.push(i)
      end if
    end for
    if eligible.count() = 0
      return invalid
    end if
    chosen = eligible[0]
    if getSelectMode(entry) = "random"
      ' Least-visited first, so every line is heard before any repeats.
      fewest = -1
      pool = [] as integer[]
      for each i in eligible
        visits = state.visitCount(id + "#" + i.toStr())
        if fewest = -1 or visits < fewest
          fewest = visits
          pool = [i]
        else if visits = fewest
          pool.push(i)
        end if
      end for
      chosen = pool[random(pool.count())]
    end if
    return {key: id + "#" + chosen.toStr(), node: candidates[chosen]}
  end function

  ' @return {StoryNode} the node a visit key names, or invalid
  function resolveNodeKey(key as string, story as StoryData) as StoryNode
    hash = Instr(1, key, "#")
    if hash = 0
      entry = story.nodes[key]
      if type(entry) <> "roAssociativeArray" or getCandidates(entry) <> invalid
        return invalid
      end if
      return entry
    end if
    candidates = getCandidates(story.nodes[Left(key, hash - 1)])
    index = Mid(key, hash + 1).toInt()
    if candidates = invalid or index < 0 or index >= candidates.count()
      return invalid
    end if
    return candidates[index]
  end function

  ' @return {integer} a random index from 0 to count - 1
  function defaultRandom(count as integer) as integer
    return Rnd(count) - 1
  end function

  function newFrame(key as string, node as StoryNode) as RunnerFrame
    return {key: key, node: node, line: 0, shownLine: -1, phase: "lines"}
  end function

  function lineCount(node as StoryNode) as integer
    if type(node.lines) = "roArray"
      return node.lines.count()
    end if
    return 0
  end function

  function isLabelled(choice as StoryChoice) as boolean
    if valueKind(choice.label) = "string"
      return choice.label <> ""
    end if
    return false
  end function

  ' The visit key for a choice, used by `once`.
  function choiceKey(nodeKey as string, choice as StoryChoice, index as integer) as string
    if valueKind(choice.id) = "string"
      if choice.id <> ""
        return nodeKey + "/" + choice.id
      end if
    end if
    if isLabelled(choice)
      return nodeKey + "/" + choice.label
    end if
    return nodeKey + "/" + index.toStr()
  end function

end namespace
```

`entry = invalid` is safe here (`entry` is an object or invalid, never a scalar). If bsc complains about `entry = story.nodes[id]` comparisons, use `type(entry) = "roInvalid" or type(entry) = "Invalid"` via `valueKind(entry) = "invalid"`.

- [ ] **Step 4: Run the tests** - `npm run validate && npm run test:ci`, expected PASS.

- [ ] **Step 5: Commit**

```bash
git add src/source/story
git commit -m "BGE.Story: node selection (first match and least-visited random) (#298)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: DialogueRunner - lines, goto, call, end

The whole runner class is written here (choices included, since `pump()` needs them); Task 6 adds the choice, backlog and position specs.

**Files:**
- Create: `src/source/story/DialogueRunner.bs`
- Test: `src/source/story/DialogueRunner.spec.bs`

**Interfaces:**
- Consumes: Tasks 2-4.
- Produces: `class BGE.Story.DialogueRunner` - `new(state as StoryState, story as StoryData)`; fields `backlog as StoryLineView[]`, `backlogLimit as integer = 100`, `random as function(count as integer) as integer`; methods `start(id as string) as StoryResult`, `startNode(node as StoryNode) as StoryResult`, `cancel()`, `isActive() as boolean`, `isChoosing() as boolean`, `currentLine() as StoryLineView` (or invalid), `advance() as StoryResult`, `choices() as ChoiceView[]`, `choose(index as integer) as StoryResult`, `getPosition() as RunnerPosition` (or invalid), `restore(position as dynamic) as boolean`; `const BGE.Story.RUNNER_MAX_STEPS = 200`.

- [ ] **Step 1: Write the failing spec**

`src/source/story/DialogueRunner.spec.bs`:

```brighterscript
namespace tests
  @suite("BGE.Story.DialogueRunner lines and jumps")
  class DialogueRunnerTests extends rooibos.BaseTestSuite

    private state as BGE.Story.StoryState
    private runner as BGE.Story.DialogueRunner

    protected override function beforeEach()
      story = {
        nodes: {
          intro: {speaker: "Husk", lines: ["Captain.", {text: "Look, ${name}.", speaker: "Sato", portrait: "sato"}], effects: [{set: "met", value: true}], "goto": "after"},
          after: {lines: ["After."]},
          withCall: {lines: ["Before the call."], "call": "aside", "goto": "after"},
          aside: {lines: ["An aside."]},
          ender: {lines: ["Bye."], "end": true, "goto": "after"},
          router: {effects: [{set: "routed", value: true}], "goto": "after"},
          deadEnd: {lines: ["Into nothing."], "goto": "gated"},
          gated: {when: [{flag: "never"}], lines: ["unreachable"]},
          loopA: {"goto": "loopB"},
          loopB: {"goto": "loopA"},
          silent: {when: [{flag: "never"}], lines: ["no"]}
        }
      }
      m.state = new BGE.Story.StoryState(story)
      m.state.flags.set("name", "Captain")
      m.runner = new BGE.Story.DialogueRunner(m.state, story)
    end function

    @it("shows each line with its speaker, then runs effects and follows goto")
    function _()
      m.runner.start("intro")
      m.assertTrue(m.runner.isActive())
      line = m.runner.currentLine()
      m.assertEqual("Captain.", line.text)
      m.assertEqual("Husk", line.speaker)
      m.runner.advance()
      line = m.runner.currentLine()
      m.assertEqual("Look, Captain.", line.text)
      m.assertEqual("Sato", line.speaker)
      m.assertEqual("sato", line.line.portrait)
      m.assertFalse(m.state.flags.isSet("met"))
      result = m.runner.advance()
      m.assertTrue(result.changed)
      m.assertTrue(m.state.flags.isSet("met"))
      m.assertEqual("After.", m.runner.currentLine().text)
      m.runner.advance()
      m.assertFalse(m.runner.isActive())
      m.assertInvalid(m.runner.currentLine())
    end function

    @it("counts visits for every node entered")
    function _()
      m.runner.start("intro")
      m.runner.advance()
      m.runner.advance()
      m.assertEqual(1, m.state.visitCount("intro"))
      m.assertEqual(1, m.state.visitCount("after"))
    end function

    @it("returns from a call and carries on with goto")
    function _()
      m.runner.start("withCall")
      m.runner.advance()
      m.assertEqual("An aside.", m.runner.currentLine().text)
      m.runner.advance()
      m.assertEqual("After.", m.runner.currentLine().text)
    end function

    @it("end stops the whole conversation, ignoring goto")
    function _()
      m.runner.start("ender")
      m.runner.advance()
      m.assertFalse(m.runner.isActive())
    end function

    @it("runs a line-less node's effects on start")
    function _()
      result = m.runner.start("router")
      m.assertTrue(result.changed)
      m.assertEqual("After.", m.runner.currentLine().text)
    end function

    @it("is inactive after starting a node that doesn't pass or doesn't exist")
    function _()
      m.runner.start("silent")
      m.assertFalse(m.runner.isActive())
      m.runner.start("missing")
      m.assertFalse(m.runner.isActive())
    end function

    @it("ends cleanly when a goto leads to a node that doesn't pass")
    function _()
      m.runner.start("deadEnd")
      m.runner.advance()
      m.assertFalse(m.runner.isActive())
    end function

    @it("stops a goto loop that never shows a line")
    function _()
      m.runner.start("loopA")
      m.assertFalse(m.runner.isActive())
    end function

    @it("cancel ends the conversation without running effects")
    function _()
      m.runner.start("intro")
      m.runner.cancel()
      m.assertFalse(m.runner.isActive())
      m.assertFalse(m.state.flags.isSet("met"))
    end function

    @it("startNode plays a one-off node without recording visits")
    function _()
      m.runner.start("intro")
      m.runner.startNode({speaker: "", lines: ["A message."]})
      m.assertEqual("A message.", m.runner.currentLine().text)
      m.runner.advance()
      m.assertFalse(m.runner.isActive())
    end function

    @it("advance does nothing when there's no conversation")
    function _()
      m.assertFalse(m.runner.advance().changed)
    end function

  end class
end namespace
```

- [ ] **Step 2: Run to see it fail** - `npm run test:ci`, build fails (`DialogueRunner` not found).

- [ ] **Step 3: Implement**

`src/source/story/DialogueRunner.bs`:

```brighterscript
import "ValueKinds.bs"
import "StoryTypes.bs"
import "StoryState.bs"
import "Effects.bs"
import "Selection.bs"

namespace BGE.Story

  ' Stops a story whose nodes keep jumping without ever showing a line or a choice.
  const RUNNER_MAX_STEPS = 200

  ' Plays a story's nodes - lines, then choices or jumps - for your dialogue UI to show. It draws
  ' nothing: ask it for currentLine() or choices(), and tell it advance() or choose(index).
  ' Each of start/advance/choose returns a StoryResult: settle the story (StoryState.settle()),
  ' save and act on its posts and messages as your game needs.
  class DialogueRunner

    ' Lines shown so far, oldest first, with each choice taken (isChoice true).
    backlog as StoryLineView[] = []
    ' The most entries kept in the backlog.
    backlogLimit as integer = 100
    ' Picks the index (0 to count - 1) of a random candidate. Replace it for repeatable tests.
    random as function(count as integer) as integer = invalid

    private state as StoryState = invalid
    private story as StoryData = invalid
    ' The node playing now is last; the frames below it wait for a call to return.
    private stack as RunnerFrame[] = []

    ' @param {StoryState} state
    ' @param {StoryData} story - the same story the state was built from
    sub new(state as StoryState, story as StoryData)
      m.state = state
      m.story = story
      m.random = BGE.Story.defaultRandom
    end sub

    ' Starts a conversation at a node id (a single node or a candidate group). Afterwards
    ' isActive() is false if no candidate passed, or the node ended straight away.
    '
    ' @param {string} id
    ' @return {StoryResult}
    function start(id as string) as StoryResult
      m.cancel()
      result = newStoryResult()
      if m.enter(id, false)
        m.pump(result)
      end if
      return result
    end function

    ' Plays a node that isn't in the story, e.g. a one-off message. It records no visits, and
    ' getPosition() returns invalid while it plays.
    '
    ' @param {StoryNode} node
    ' @return {StoryResult}
    function startNode(node as StoryNode) as StoryResult
      m.cancel()
      result = newStoryResult()
      m.stack.push(newFrame("", node))
      m.pump(result)
      return result
    end function

    ' Ends the conversation. Effects of the node being read don't run.
    sub cancel()
      m.stack = []
    end sub

    function isActive() as boolean
      return m.stack.count() > 0
    end function

    ' @return {boolean} true while waiting for choose()
    function isChoosing() as boolean
      if not m.isActive()
        return false
      end if
      return m.top().phase = "choosing"
    end function

    ' @return {StoryLineView} the line to show, or invalid while choosing or when inactive
    function currentLine() as StoryLineView
      if not m.isActive()
        return invalid
      end if
      frame = m.top()
      if frame.phase <> "lines"
        return invalid
      end if
      return m.lineView(frame)
    end function

    ' Moves past the current line. After a node's last line its effects run, then its choices
    ' show, or it calls, jumps or ends.
    '
    ' @return {StoryResult}
    function advance() as StoryResult
      result = newStoryResult()
      if not m.isActive()
        return result
      end if
      frame = m.top()
      if frame.phase <> "lines"
        return result
      end if
      frame.line = frame.line + 1
      m.pump(result)
      return result
    end function

    ' @return {ChoiceView[]} the choices to show while choosing (empty otherwise)
    function choices() as ChoiceView[]
      if not m.isChoosing()
        return []
      end if
      return m.choiceViews(m.top())
    end function

    ' Takes a choice from choices(). A disabled or out-of-range index does nothing.
    '
    ' @param {integer} index - into choices()
    ' @return {StoryResult}
    function choose(index as integer) as StoryResult
      result = newStoryResult()
      if not m.isChoosing()
        return result
      end if
      views = m.choiceViews(m.top())
      if index < 0 or index >= views.count()
        return result
      end if
      if not views[index].enabled
        return result
      end if
      m.takeChoice(m.top(), views[index].index, result)
      m.pump(result)
      return result
    end function

    ' @return {RunnerPosition} where the conversation is, to save; invalid if inactive or playing startNode()
    function getPosition() as RunnerPosition
      if not m.isActive()
        return invalid
      end if
      frames = [] as RunnerFrameData[]
      for each frame in m.stack
        if frame.key = ""
          return invalid
        end if
        frames.push({key: frame.key, line: frame.line, phase: frame.phase})
      end for
      return {stack: frames}
    end function

    ' Resumes a saved conversation. The backlog isn't part of the position - save and restore it
    ' yourself if you show one.
    '
    ' @param {dynamic} position - from getPosition()
    ' @return {boolean} false (and inactive) if it doesn't fit this story any more
    function restore(position as dynamic) as boolean
      m.cancel()
      if type(position) <> "roAssociativeArray"
        return false
      end if
      if type(position.stack) <> "roArray"
        return false
      end if
      if position.stack.count() = 0
        return false
      end if
      frames = [] as RunnerFrame[]
      for each saved in position.stack
        if type(saved) <> "roAssociativeArray"
          return false
        end if
        if valueKind(saved.key) <> "string" or valueKind(saved.line) <> "integer" or valueKind(saved.phase) <> "string"
          return false
        end if
        node = resolveNodeKey(saved.key, m.story)
        if node = invalid
          return false
        end if
        frame = newFrame(saved.key, node)
        frame.line = saved.line
        frame.shownLine = saved.line
        frame.phase = saved.phase
        frames.push(frame)
      end for
      top = frames[frames.count() - 1]
      if top.phase = "lines"
        if top.line < 0 or top.line >= lineCount(top.node)
          return false
        end if
      else if top.phase <> "choosing"
        return false
      end if
      for i = 0 to frames.count() - 2
        if frames[i].phase <> "choiceCall" and frames[i].phase <> "afterCall"
          return false
        end if
      end for
      m.stack = frames
      return true
    end function

    private function top() as RunnerFrame
      return m.stack[m.stack.count() - 1]
    end function

    ' Selects and pushes a node. warn: log when nothing passes (a goto or call into a dead end).
    private function enter(id as string, warn as boolean) as boolean
      selected = selectNode(id, m.story, m.state, m.random)
      if selected = invalid
        if warn
          print "[BGE.Story] warning: no node passes for '" + id + "'"
        end if
        return false
      end if
      m.state.recordVisit(id)
      if selected.key <> id
        m.state.recordVisit(selected.key)
      end if
      m.stack.push(newFrame(selected.key, selected.node))
      return true
    end function

    ' Runs the story on until it needs the player (a line or a choice) or the conversation ends.
    private sub pump(result as StoryResult)
      for steps = 1 to RUNNER_MAX_STEPS
        if m.stack.count() = 0
          return
        end if
        frame = m.top()
        node = frame.node
        if frame.phase = "lines"
          if frame.line < lineCount(node)
            if frame.shownLine <> frame.line
              frame.shownLine = frame.line
              m.addToBacklog(m.lineView(frame))
            end if
            return
          end if
          mergeStoryResult(result, m.state.applyEffects(node.effects))
          frame.phase = "choices"
        else if frame.phase = "choices"
          if m.hasEnabledChoice(frame)
            frame.phase = "choosing"
            return
          end if
          fallback = m.findFallback(frame)
          if fallback >= 0
            m.takeChoice(frame, fallback, result)
          else
            frame.phase = "call"
          end if
        else if frame.phase = "call"
          frame.phase = "afterCall"
          target = node["call"]
          if valueKind(target) = "string"
            m.enter(target, true)
          end if
        else if frame.phase = "afterCall"
          target = node["goto"]
          if isTrue(node["end"])
            m.cancel()
            return
          else if valueKind(target) = "string"
            m.stack.pop()
            m.enter(target, true)
          else
            frame.phase = "runOut"
          end if
        else if frame.phase = "runOut"
          m.stack.pop()
          if m.stack.count() > 0
            caller = m.top()
            if caller.phase = "choiceCall"
              caller.phase = "choices"
            end if
          end if
        else
          ' choosing: wait for the player
          return
        end if
      end for
      print "[BGE.Story] warning: the story ran " + RUNNER_MAX_STEPS.toStr() + " steps without a line or choice; stopping"
      m.cancel()
    end sub

    private sub takeChoice(frame as RunnerFrame, index as integer, result as StoryResult)
      choice = frame.node.choices[index]
      if frame.key <> ""
        m.state.recordVisit(choiceKey(frame.key, choice, index))
      end if
      if isLabelled(choice)
        m.addToBacklog({text: m.state.interpolate(choice.label), speaker: "", line: choice, isChoice: true})
      end if
      mergeStoryResult(result, m.state.applyEffects(choice.effects))
      callTarget = choice["call"]
      gotoTarget = choice["goto"]
      if valueKind(callTarget) = "string"
        frame.phase = "choiceCall"
        if not m.enter(callTarget, true)
          frame.phase = "choices"
        end if
      else if valueKind(gotoTarget) = "string"
        m.stack.pop()
        m.enter(gotoTarget, true)
      else
        frame.phase = "runOut"
      end if
    end sub

    private function choiceViews(frame as RunnerFrame) as ChoiceView[]
      views = [] as ChoiceView[]
      list = frame.node.choices
      if type(list) <> "roArray"
        return views
      end if
      for i = 0 to list.count() - 1
        choice = list[i]
        if type(choice) = "roAssociativeArray"
          if isLabelled(choice) and not m.isUsedUp(frame, choice, i)
            enabled = m.state.evaluate(choice.when)
            if enabled or isTrue(choice.showDisabled)
              views.push({label: m.state.interpolate(choice.label), enabled: enabled, choice: choice, index: i})
            end if
          end if
        end if
      end for
      return views
    end function

    private function hasEnabledChoice(frame as RunnerFrame) as boolean
      for each view in m.choiceViews(frame)
        if view.enabled
          return true
        end if
      end for
      return false
    end function

    ' @return {integer} the index of the first passing unlabelled choice, or -1
    private function findFallback(frame as RunnerFrame) as integer
      list = frame.node.choices
      if type(list) <> "roArray"
        return -1
      end if
      for i = 0 to list.count() - 1
        choice = list[i]
        if type(choice) = "roAssociativeArray"
          if not isLabelled(choice) and not m.isUsedUp(frame, choice, i) and m.state.evaluate(choice.when)
            return i
          end if
        end if
      end for
      return -1
    end function

    private function isUsedUp(frame as RunnerFrame, choice as StoryChoice, index as integer) as boolean
      if not isTrue(choice.once)
        return false
      end if
      return m.state.visitCount(choiceKey(frame.key, choice, index)) > 0
    end function

    private function lineView(frame as RunnerFrame) as StoryLineView
      raw = frame.node.lines[frame.line]
      speaker = ""
      if valueKind(frame.node.speaker) = "string"
        speaker = frame.node.speaker
      end if
      text = ""
      line = {}
      if type(raw) = "roAssociativeArray"
        line = raw
        if valueKind(raw.speaker) = "string"
          speaker = raw.speaker
        end if
        if valueKind(raw.text) = "string"
          text = raw.text
        end if
      else
        if valueKind(raw) = "string"
          text = raw
        end if
        line = {text: text}
      end if
      return {text: m.state.interpolate(text), speaker: speaker, line: line, isChoice: false}
    end function

    private sub addToBacklog(view as StoryLineView)
      m.backlog.push(view)
      while m.backlog.count() > m.backlogLimit
        m.backlog.Shift()
      end while
    end sub

  end class

end namespace
```

- [ ] **Step 4: Run the tests** - `npm run validate && npm run test:ci`, expected PASS. A failure in "stops a goto loop" that hangs means `pump`'s step cap isn't reached - check `enter()` pushes each time.

- [ ] **Step 5: Commit**

```bash
git add src/source/story
git commit -m "BGE.Story: DialogueRunner with lines, goto, call and end (#298)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: DialogueRunner - choices, backlog and saved positions

Specs only (the code is in Task 5); fix `DialogueRunner.bs` where they fail.

**Files:**
- Test: `src/source/story/DialogueRunnerChoices.spec.bs`, `src/source/story/DialogueRunnerPosition.spec.bs`
- Modify (only if a spec fails): `src/source/story/DialogueRunner.bs`

**Interfaces:** Consumes Task 5. Produces nothing new.

- [ ] **Step 1: Write the specs**

`src/source/story/DialogueRunnerChoices.spec.bs`:

```brighterscript
namespace tests
  @suite("BGE.Story.DialogueRunner choices")
  class DialogueRunnerChoicesTests extends rooibos.BaseTestSuite

    private state as BGE.Story.StoryState
    private runner as BGE.Story.DialogueRunner

    protected override function beforeEach()
      story = {
        nodes: {
          hub: {
            lines: ["Who do you talk to?"],
            effects: [{add: "hubReads", amount: 1}],
            choices: [
              {label: "Sato", once: true, "call": "sato"},
              {label: "Locked", when: [{flag: "key"}], showDisabled: true, "goto": "vault"},
              {label: "Hidden", when: [{flag: "key"}], "goto": "vault"},
              {label: "Leave, ${who}", effects: [{set: "left", value: true}]},
              {"goto": "vault"}
            ]
          },
          sato: {lines: ["Sato here."]},
          vault: {lines: ["The vault."]},
          onlyFallback: {lines: ["..."], choices: [{label: "Gated", when: [{flag: "key"}], showDisabled: true}, {"goto": "vault"}], "goto": "sato"},
          noneAvailable: {lines: ["..."], choices: [{label: "Gated", when: [{flag: "key"}], showDisabled: true}], "goto": "sato"}
        }
      }
      m.state = new BGE.Story.StoryState(story)
      m.state.flags.set("who", "Captain")
      m.runner = new BGE.Story.DialogueRunner(m.state, story)
    end function

    private function labels() as string[]
      result = [] as string[]
      for each view in m.runner.choices()
        result.push(view.label)
      end for
      return result
    end function

    @it("lists labelled choices after the last line, hiding failed ones unless showDisabled")
    function _()
      m.runner.start("hub")
      m.assertFalse(m.runner.isChoosing())
      m.runner.advance()
      m.assertTrue(m.runner.isChoosing())
      m.assertInvalid(m.runner.currentLine())
      m.assertEqual(["Sato", "Locked", "Leave, Captain"], m.labels())
      m.assertFalse(m.runner.choices()[1].enabled)
    end function

    @it("ignores choosing a disabled or out-of-range choice")
    function _()
      m.runner.start("hub")
      m.runner.advance()
      m.runner.choose(1)
      m.runner.choose(9)
      m.assertTrue(m.runner.isChoosing())
    end function

    @it("returns from a choice's call to the same choices, without re-running the node's effects, and drops a once choice")
    function _()
      m.runner.start("hub")
      m.runner.advance()
      m.runner.choose(0)
      m.assertEqual("Sato here.", m.runner.currentLine().text)
      m.runner.advance()
      m.assertTrue(m.runner.isChoosing())
      m.assertEqual(["Locked", "Leave, Captain"], m.labels())
      m.assertEqual(1, m.state.flags.getInt("hubReads"))
    end function

    @it("runs a choice's effects and ends when it has no goto or call")
    function _()
      m.runner.start("hub")
      m.runner.advance()
      result = m.runner.choose(2)
      m.assertTrue(result.changed)
      m.assertTrue(m.state.flags.isSet("left"))
      m.assertFalse(m.runner.isActive())
    end function

    @it("follows a choice's goto once its when passes")
    function _()
      m.state.flags.set("key", true)
      m.runner.start("hub")
      m.runner.advance()
      m.assertEqual(["Sato", "Locked", "Hidden", "Leave, Captain"], m.labels())
      m.runner.choose(1)
      m.assertEqual("The vault.", m.runner.currentLine().text)
    end function

    @it("takes the fallback when no labelled choice is enabled")
    function _()
      m.runner.start("onlyFallback")
      m.runner.advance()
      m.assertEqual("The vault.", m.runner.currentLine().text)
    end function

    @it("carries on with the node's goto when nothing is choosable and there's no fallback")
    function _()
      m.runner.start("noneAvailable")
      m.runner.advance()
      m.assertEqual("Sato here.", m.runner.currentLine().text)
    end function

    @it("records lines and chosen labels in the backlog, capped at backlogLimit")
    function _()
      m.runner.backlogLimit = 3
      m.runner.start("hub")
      m.runner.advance()
      m.runner.choose(0)
      m.runner.advance()
      m.assertEqual(3, m.runner.backlog.count())
      m.assertEqual("Who do you talk to?", m.runner.backlog[0].text)
      m.assertTrue(m.runner.backlog[1].isChoice)
      m.assertEqual("Sato", m.runner.backlog[1].text)
      m.assertEqual("Sato here.", m.runner.backlog[2].text)
      m.runner.choose(1)
      m.assertEqual(3, m.runner.backlog.count())
      m.assertEqual("Sato", m.runner.backlog[0].text)
    end function

  end class
end namespace
```

`choose()` takes an index into `choices()`, not into the node's `choices` list: once Sato is used up the views are `["Locked" (disabled), "Leave, Captain"]`, so the backlog test's `choose(1)` is "Leave", pushing a fourth entry and dropping the oldest.

`src/source/story/DialogueRunnerPosition.spec.bs`:

```brighterscript
namespace tests
  @suite("BGE.Story.DialogueRunner saved positions")
  class DialogueRunnerPositionTests extends rooibos.BaseTestSuite

    private story as BGE.Story.StoryData
    private state as BGE.Story.StoryState
    private runner as BGE.Story.DialogueRunner

    protected override function beforeEach()
      m.story = {
        nodes: {
          hub: {lines: ["Hub."], choices: [{label: "Ask", "call": "ask"}, {label: "Bye"}]},
          ask: [{lines: ["First answer.", "Second answer."]}]
        }
      }
      m.state = new BGE.Story.StoryState(m.story)
      m.runner = new BGE.Story.DialogueRunner(m.state, m.story)
    end function

    @it("saves and restores a position inside a call, then returns to the caller's choices")
    function _()
      m.runner.start("hub")
      m.runner.advance()
      m.runner.choose(0)
      m.runner.advance()
      position = m.runner.getPosition()
      other = new BGE.Story.DialogueRunner(m.state, m.story)
      m.assertTrue(other.restore(position))
      m.assertEqual("Second answer.", other.currentLine().text)
      other.advance()
      m.assertTrue(other.isChoosing())
    end function

    @it("survives a round trip through JSON")
    function _()
      m.runner.start("hub")
      m.runner.advance()
      position = ParseJson(FormatJson(m.runner.getPosition()))
      other = new BGE.Story.DialogueRunner(m.state, m.story)
      m.assertTrue(other.restore(position))
      m.assertTrue(other.isChoosing())
    end function

    @it("has no position when inactive or playing a one-off node")
    function _()
      m.assertInvalid(m.runner.getPosition())
      m.runner.startNode({lines: ["note"]})
      m.assertInvalid(m.runner.getPosition())
    end function

    @it("refuses positions that no longer fit the story")
    function _()
      m.assertFalse(m.runner.restore(invalid))
      m.assertFalse(m.runner.restore("junk"))
      m.assertFalse(m.runner.restore({stack: []}))
      m.assertFalse(m.runner.restore({stack: [{key: "gone", line: 0, phase: "lines"}]}))
      m.assertFalse(m.runner.restore({stack: [{key: "hub", line: 5, phase: "lines"}]}))
      m.assertFalse(m.runner.restore({stack: [{key: "ask", line: 0, phase: "lines"}]}))
      m.assertFalse(m.runner.restore({stack: [{key: "hub", line: "0", phase: "lines"}]}))
      m.assertFalse(m.runner.restore({stack: [{key: "hub", line: 0, phase: "lines"}, {key: "ask#0", line: 0, phase: "lines"}]}))
      m.assertFalse(m.runner.isActive())
    end function

  end class
end namespace
```

(`ask` is a candidate group, so its key on its own isn't a node - only `ask#0` is; the last case has a non-waiting phase below the top.)

- [ ] **Step 2: Run** - `npm run test:ci`. Expected: PASS if Task 5's code is right. If `ParseJson` turns `line` into a float under brs-engine, make `restore()` accept `valueKind(saved.line) = "float"` too and convert with `Int()`; keep the test.

- [ ] **Step 3: Fix any failures in `DialogueRunner.bs`, re-run until green.**

- [ ] **Step 4: Commit**

```bash
git add src/source/story
git commit -m "BGE.Story: specs for choices, fallbacks, backlog and saved positions (#298)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Loading and validating stories

**Files:**
- Create: `src/source/story/StoryLoader.bs`, `src/source/story/StoryValidation.bs`
- Test: `src/source/story/StoryLoader.spec.bs`, `src/source/story/StoryValidation.spec.bs`

**Interfaces:**
- Consumes: `StoryState.isKnownCondition/isKnownEffect`, `getCandidates`, `getSelectMode`, `isTrue`, `valueKind`.
- Produces: `BGE.Story.loadStory(path as string) as StoryData` (or invalid), `BGE.Story.validateStory(story as dynamic, state as StoryState) as string[]`.

- [ ] **Step 1: Write the failing specs**

`src/source/story/StoryLoader.spec.bs`:

```brighterscript
namespace tests
  @suite("BGE.Story.loadStory")
  class StoryLoaderTests extends rooibos.BaseTestSuite

    @it("parses a JSON story file")
    function _()
      WriteAsciiFile("tmp:/story-test.json", "{""nodes"": {""start"": {""lines"": [""Hi.""], ""goto"": ""start""}}}")
      story = BGE.Story.loadStory("tmp:/story-test.json")
      m.assertEqual("Hi.", story.nodes.start.lines[0])
      m.assertEqual("start", story.nodes.start["goto"])
    end function

    @it("returns invalid for a missing file, bad JSON, or JSON without nodes")
    function _()
      m.assertInvalid(BGE.Story.loadStory("tmp:/no-such-story.json"))
      WriteAsciiFile("tmp:/story-bad.json", "{nodes: oops")
      m.assertInvalid(BGE.Story.loadStory("tmp:/story-bad.json"))
      WriteAsciiFile("tmp:/story-empty.json", "{""rules"": []}")
      m.assertInvalid(BGE.Story.loadStory("tmp:/story-empty.json"))
    end function

  end class
end namespace
```

`src/source/story/StoryValidation.spec.bs`:

```brighterscript
namespace tests
  @suite("BGE.Story.validateStory")
  class StoryValidationTests extends rooibos.BaseTestSuite

    private state as BGE.Story.StoryState

    protected override function beforeEach()
      m.state = new BGE.Story.StoryState()
    end function

    private function errorsFor(story as dynamic) as string[]
      return BGE.Story.validateStory(story, m.state)
    end function

    @it("accepts a well-formed story")
    function _()
      errors = m.errorsFor({
        nodes: {
          start: {lines: ["a", {text: "b", portrait: "x"}], choices: [{label: "Go", "goto": "chat", when: [{any: [{flag: "x"}, {visited: "chat"}]}]}, {"call": "chat"}]},
          chat: {select: "random", candidates: [{lines: ["c"]}, {lines: ["d"], effects: [{set: "y", value: 1}]}]},
          routes: [{when: [{flag: "z"}], "goto": "start"}, {"end": true}]
        },
        rules: [{event: "storyChanged", when: [{hasItem: "clue"}], effects: [{post: "found"}]}],
        items: {clue: {max: 1, onAcquire: [{add: "clues", amount: 1}]}}
      })
      m.assertEqual(0, errors.count())
    end function

    @it("rejects a story without nodes")
    function _()
      m.assertEqual(1, m.errorsFor(invalid).count())
      m.assertEqual(1, m.errorsFor({}).count())
    end function

    @it("reports unknown goto and call targets")
    function _()
      errors = m.errorsFor({nodes: {start: {lines: ["a"], "goto": "nowhere", choices: [{label: "x", "call": "gone"}]}}})
      m.assertEqual(2, errors.count())
    end function

    @it("reports unknown conditions and effects, nested ones too")
    function _()
      errors = m.errorsFor({nodes: {start: {lines: ["a"], when: [{any: [{coinsGte: 3}]}], effects: [{heal: 2}]}}})
      m.assertEqual(2, errors.count())
    end function

    @it("accepts registered vocabulary")
    function _()
      m.state.registerCondition("coinsGte", function(item as roAssociativeArray, state as object, context as dynamic) as boolean
        return true
      end function)
      m.assertEqual(0, m.errorsFor({nodes: {start: {lines: ["a"], when: [{coinsGte: 3}]}}}).count())
    end function

    @it("reports bad groups, empty nodes, bad lines and bad ids")
    function _()
      errors = m.errorsFor({nodes: {
        badSelect: {select: "loudest", candidates: [{lines: ["a"]}]},
        empty: {candidates: []},
        nothing: {speaker: "x"},
        badLine: {lines: [7]},
        "a#b": {lines: ["a"]},
        notANode: "text"
      }})
      m.assertEqual(6, errors.count())
    end function

    @it("reports malformed lists and items")
    function _()
      errors = m.errorsFor({
        nodes: {start: {lines: ["a"], when: {flag: "x"}, choices: ["not a choice"]}},
        rules: [{effects: []}],
        items: {thing: {name: "no max"}}
      })
      m.assertEqual(4, errors.count())
    end function

  end class
end namespace
```

- [ ] **Step 2: Run to see them fail** - build fails, functions not found.

- [ ] **Step 3: Implement**

`src/source/story/StoryLoader.bs`:

```brighterscript
import "StoryTypes.bs"

namespace BGE.Story

  ' Reads a story from a JSON file. Check it with validateStory() once your game's own conditions
  ' and effects are registered.
  '
  ' @param {string} path - e.g. "pkg:/story/jokes.json"
  ' @return {StoryData} the story, or invalid (with a warning) if it can't be read or has no nodes
  function loadStory(path as string) as StoryData
    text = ReadAsciiFile(path)
    if text = ""
      print "[BGE.Story] warning: couldn't read story file " + path
      return invalid
    end if
    data = ParseJson(text)
    if type(data) <> "roAssociativeArray"
      print "[BGE.Story] warning: " + path + " isn't valid JSON"
      return invalid
    end if
    if type(data.nodes) <> "roAssociativeArray"
      print "[BGE.Story] warning: " + path + " isn't a story (it needs a nodes object)"
      return invalid
    end if
    return data
  end function

end namespace
```

`src/source/story/StoryValidation.bs`:

```brighterscript
import "ValueKinds.bs"
import "StoryTypes.bs"
import "StoryState.bs"
import "Selection.bs"

namespace BGE.Story

  ' Checks a story for mistakes: jumps to nodes that don't exist, conditions and effects nothing
  ' handles, empty or malformed nodes. Run it in a test over your real story data.
  '
  ' @param {dynamic} story
  ' @param {StoryState} state - with your game's conditions and effects registered
  ' @return {string[]} one message per problem; empty when the story is fine
  function validateStory(story as dynamic, state as StoryState) as string[]
    errors = [] as string[]
    if type(story) <> "roAssociativeArray"
      errors.push("the story isn't an object")
      return errors
    end if
    if type(story.nodes) <> "roAssociativeArray"
      errors.push("the story has no nodes object")
      return errors
    end if
    for each id in story.nodes
      where = "node '" + id + "'"
      if Instr(1, id, "#") > 0 or Instr(1, id, "/") > 0
        errors.push(where + ": ids can't contain # or /")
      end if
      entry = story.nodes[id]
      candidates = getCandidates(entry)
      if candidates <> invalid
        mode = getSelectMode(entry)
        if mode <> "first" and mode <> "random"
          errors.push(where + ": unknown select " + FormatJson(entry.select))
        end if
        if candidates.count() = 0
          errors.push(where + " has no candidates")
        end if
        for i = 0 to candidates.count() - 1
          validateStoryNode(where + " candidate " + i.toStr(), candidates[i], story, state, errors)
        end for
      else
        validateStoryNode(where, entry, story, state, errors)
      end if
    end for
    if story.rules <> invalid
      if type(story.rules) <> "roArray"
        errors.push("rules must be a list")
      else
        for i = 0 to story.rules.count() - 1
          rule = story.rules[i]
          ruleWhere = "rule " + i.toStr()
          if type(rule) <> "roAssociativeArray"
            errors.push(ruleWhere + " isn't an object")
          else
            if valueKind(rule.event) <> "string"
              errors.push(ruleWhere + " has no event")
            end if
            validateStoryConditions(ruleWhere, rule.when, state, errors)
            validateStoryEffects(ruleWhere, rule.effects, state, errors)
          end if
        end for
      end if
    end if
    if story.items <> invalid
      if type(story.items) <> "roAssociativeArray"
        errors.push("items must be an object")
      else
        for each itemId in story.items
          definition = story.items[itemId]
          itemWhere = "item '" + itemId + "'"
          if type(definition) <> "roAssociativeArray"
            errors.push(itemWhere + " isn't an object")
          else
            if valueKind(definition.max) <> "integer"
              errors.push(itemWhere + " needs an integer max")
            end if
            validateStoryEffects(itemWhere + " onAcquire", definition.onAcquire, state, errors)
          end if
        end for
      end if
    end if
    return errors
  end function

  sub validateStoryNode(where as string, node as dynamic, story as StoryData, state as StoryState, errors as string[])
    if type(node) <> "roAssociativeArray"
      errors.push(where + " isn't a node, a list of nodes or a {select, candidates} group")
      return
    end if
    hasLines = false
    if node.lines <> invalid
      if type(node.lines) <> "roArray"
        errors.push(where + ": lines must be a list")
      else
        hasLines = node.lines.count() > 0
        for i = 0 to node.lines.count() - 1
          line = node.lines[i]
          if valueKind(line) <> "string"
            lineOk = false
            if type(line) = "roAssociativeArray"
              lineOk = valueKind(line.text) = "string"
            end if
            if not lineOk
              errors.push(where + " line " + i.toStr() + " needs text")
            end if
          end if
        end for
      end if
    end if
    hasChoices = false
    if node.choices <> invalid
      if type(node.choices) <> "roArray"
        errors.push(where + ": choices must be a list")
      else
        hasChoices = node.choices.count() > 0
        for i = 0 to node.choices.count() - 1
          choice = node.choices[i]
          choiceWhere = where + " choice " + i.toStr()
          if type(choice) <> "roAssociativeArray"
            errors.push(choiceWhere + " isn't an object")
          else
            validateStoryConditions(choiceWhere, choice.when, state, errors)
            validateStoryEffects(choiceWhere, choice.effects, state, errors)
            validateStoryTarget(choiceWhere, choice["call"], story, errors)
            validateStoryTarget(choiceWhere, choice["goto"], story, errors)
          end if
        end for
      end if
    end if
    hasJump = valueKind(node["call"]) <> "invalid" or valueKind(node["goto"]) <> "invalid" or isTrue(node["end"])
    if not hasLines and not hasChoices and not hasJump
      errors.push(where + " has nothing to do (no lines, choices, call, goto or end)")
    end if
    validateStoryConditions(where, node.when, state, errors)
    validateStoryEffects(where, node.effects, state, errors)
    validateStoryTarget(where, node["call"], story, errors)
    validateStoryTarget(where, node["goto"], story, errors)
  end sub

  sub validateStoryTarget(where as string, target as dynamic, story as StoryData, errors as string[])
    kind = valueKind(target)
    if kind = "invalid"
      return
    end if
    if kind <> "string"
      errors.push(where + " goes to " + FormatJson(target) + ", which isn't a node id")
    else if not story.nodes.DoesExist(target)
      errors.push(where + " goes to unknown node '" + target + "'")
    end if
  end sub

  sub validateStoryConditions(where as string, conditions as dynamic, state as StoryState, errors as string[])
    if conditions = invalid
      return
    end if
    if type(conditions) <> "roArray"
      errors.push(where + ": when must be a list")
      return
    end if
    for each condition in conditions
      if type(condition) <> "roAssociativeArray"
        errors.push(where + " has a condition that isn't an object")
      else if condition.DoesExist("any")
        validateStoryConditions(where, condition.any, state, errors)
      else if not state.isKnownCondition(condition)
        errors.push(where + " has an unknown condition " + FormatJson(condition))
      end if
    end for
  end sub

  sub validateStoryEffects(where as string, effects as dynamic, state as StoryState, errors as string[])
    if effects = invalid
      return
    end if
    if type(effects) <> "roArray"
      errors.push(where + ": effects must be a list")
      return
    end if
    for each effect in effects
      if type(effect) <> "roAssociativeArray"
        errors.push(where + " has an effect that isn't an object")
      else if not state.isKnownEffect(effect)
        errors.push(where + " has an unknown effect " + FormatJson(effect))
      end if
    end for
  end sub

end namespace
```

Note the expected counts in "reports malformed lists and items": `when` not a list (1), choice not an object (1), rule with no event (1), item without max (1) = 4. In "reports bad groups...": badSelect (1), empty group (1), nothing (1), badLine (1), `a#b` (1), notANode (1) = 6. `conditions = invalid` is safe for these object-or-invalid values; scalar junk (`when: 5`) goes to the `roArray` check - if brs-engine throws on `5 = invalid`, switch those two comparisons to `valueKind(x) = "invalid"`.

- [ ] **Step 4: Run** - `npm run validate && npm run test:ci`, expected PASS. If `WriteAsciiFile` to `tmp:/` isn't supported by brs-engine, use `cachefs:/` instead (the engine's download cache already writes there in tests).

- [ ] **Step 5: Commit**

```bash
git add src/source/story
git commit -m "BGE.Story: loadStory and validateStory (#298)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: `examples/story` - the smallest story

**Files:**
- Create via `npm run create-example -- story "Story"`; then add `examples/story/src/story/jokes.json`, `examples/story/src/source/Scenes/StoryScene.bs`, `examples/story/src/source/UI/ChoiceButton.bs`; replace `examples/story/src/source/main.bs`; delete the scaffold's `MainScene.bs`, `util.bs` (if unused) and `sounds/`.
- Create: `examples/story/bsconfig.test.json`, `examples/story/tests/Jokes.spec.bs`; add a `test` script to `examples/story/package.json`.

**Interfaces:**
- Consumes: the whole `BGE.Story` API.

- [ ] **Step 1: Scaffold**

Run: `npm run create-example -- story "Story"`
Expected: `examples/story/` exists and `.vscode/tasks.json` lists it. Then `cd examples/story && npm install`.

- [ ] **Step 2: Write the story**

`examples/story/src/story/jokes.json` (the brainstorm's knock-knock example, changed so it loops - `laughed` and `groaned` go back to `start`, where "Another one?" appears after the first joke):

```json
{
  "nodes": {
    "start": {
      "speaker": "Husk",
      "lines": ["Captain. I have been studying human humour. May I attempt a joke?"],
      "choices": [
        {"label": "Go on, then.", "goto": "knockKnock"},
        {"label": "Another one?", "when": [{"visited": "knockKnock"}], "goto": "knockKnock"},
        {"label": "Not now, Husk.", "goto": "declined"}
      ]
    },
    "knockKnock": {
      "select": "random",
      "candidates": [
        {"goto": "lettuce"},
        {"goto": "boo"},
        {"goto": "interrupting", "once": true}
      ]
    },
    "lettuce": {"speaker": "Husk", "lines": ["Knock knock."], "choices": [{"label": "Who's there?", "goto": "lettuceWho"}]},
    "lettuceWho": {"speaker": "Husk", "lines": ["Lettuce."], "choices": [{"label": "Lettuce who?", "goto": "lettucePunchline"}]},
    "lettucePunchline": {"speaker": "Husk", "lines": ["Lettuce in, it is cold out here in the vacuum of space."], "goto": "laugh"},
    "boo": {"speaker": "Husk", "lines": ["Knock knock."], "choices": [{"label": "Who's there?", "goto": "booWho"}]},
    "booWho": {"speaker": "Husk", "lines": ["Boo."], "choices": [{"label": "Boo who?", "goto": "booPunchline"}]},
    "booPunchline": {"speaker": "Husk", "lines": ["There is no need to cry, Captain. It is only a joke."], "goto": "laugh"},
    "interrupting": {"speaker": "Husk", "lines": ["Knock knock."], "choices": [{"label": "Who's there?", "goto": "interruptingWho"}]},
    "interruptingWho": {"speaker": "Husk", "lines": ["Interrupting synthetic."], "choices": [{"label": "Interrupting synthetic wh-", "goto": "interruptingPunchline"}]},
    "interruptingPunchline": {"speaker": "Husk", "lines": ["BEEP."], "goto": "laugh"},
    "laugh": {
      "effects": [{"add": "husk.jokes", "amount": 1}],
      "choices": [
        {"label": "(Laugh)", "effects": [{"add": "husk.trust", "amount": 1}], "goto": "laughed"},
        {"label": "(Groan)", "goto": "groaned"}
      ]
    },
    "laughed": [
      {"when": [{"flag": "husk.jokes", "gte": 3}], "speaker": "Husk", "lines": ["That is ${husk.jokes} jokes. I believe I am now officially funny."], "goto": "start"},
      {"speaker": "Husk", "lines": ["Laughter detected. I will log this as a success."], "goto": "start"}
    ],
    "groaned": {"speaker": "Husk", "lines": ["A groan. My research indicates this is also a success."], "goto": "start"},
    "declined": {"speaker": "Husk", "lines": ["Understood. I will save it for a more critical moment."]}
  }
}
```

`husk.jokes` needs no reset: `${husk.jokes}` is only shown once it's at least 3.

- [ ] **Step 3: Write the test config and failing tests**

`examples/story/bsconfig.test.json` (same shape as `examples/rpg/bsconfig.test.json`, files listed explicitly):

```json
{
    "rootDir": "src",
    "outDir": "test-build",
    "retainStagingDir": true,
    "files": [
        "story/jokes.json",
        {"src": "../../../src/source/story/ValueKinds.bs", "dest": "source/story/ValueKinds.bs"},
        {"src": "../../../src/source/story/StoryFlags.bs", "dest": "source/story/StoryFlags.bs"},
        {"src": "../../../src/source/story/Inventory.bs", "dest": "source/story/Inventory.bs"},
        {"src": "../../../src/source/story/Text.bs", "dest": "source/story/Text.bs"},
        {"src": "../../../src/source/story/StoryTypes.bs", "dest": "source/story/StoryTypes.bs"},
        {"src": "../../../src/source/story/Conditions.bs", "dest": "source/story/Conditions.bs"},
        {"src": "../../../src/source/story/Effects.bs", "dest": "source/story/Effects.bs"},
        {"src": "../../../src/source/story/EventRules.bs", "dest": "source/story/EventRules.bs"},
        {"src": "../../../src/source/story/StoryState.bs", "dest": "source/story/StoryState.bs"},
        {"src": "../../../src/source/story/Selection.bs", "dest": "source/story/Selection.bs"},
        {"src": "../../../src/source/story/DialogueRunner.bs", "dest": "source/story/DialogueRunner.bs"},
        {"src": "../../../src/source/story/StoryLoader.bs", "dest": "source/story/StoryLoader.bs"},
        {"src": "../../../src/source/story/StoryValidation.bs", "dest": "source/story/StoryValidation.bs"},
        {"src": "../tests/**/*.spec.bs", "dest": "source/tests"},
        {"src": "../../../test.manifest", "dest": "manifest"}
    ],
    "plugins": ["rooibos-roku"],
    "rooibos": {
        "isRecordingCodeCoverage": false,
        "testsFilePattern": null,
        "tags": ["!integration", "!deprecated", "!fixme"],
        "showOnlyFailures": true,
        "catchCrashes": true,
        "lineWidth": 70,
        "failFast": false,
        "sendHomeOnFinish": false,
        "reporters": ["mocha"]
    }
}
```

`examples/story/package.json` scripts: add `"test": "bsc --project bsconfig.test.json --create-package=false && node ../../scripts/run-tests-ci.js examples/story/test-build"` (match the rpg's devDependencies; `create-example` already sets build/package/clean).

`examples/story/tests/Jokes.spec.bs`:

```brighterscript
namespace tests
  @suite("examples/story jokes")
  class JokesTests extends rooibos.BaseTestSuite

    private story as BGE.Story.StoryData
    private state as BGE.Story.StoryState
    private runner as BGE.Story.DialogueRunner

    protected override function beforeEach()
      m.story = BGE.Story.loadStory("pkg:/story/jokes.json")
      m.state = new BGE.Story.StoryState(m.story)
      m.runner = new BGE.Story.DialogueRunner(m.state, m.story)
    end function

    ' Reads lines until a choice, then takes the one with this label.
    private sub chooseLabel(label as string)
      while m.runner.isActive() and not m.runner.isChoosing()
        m.runner.advance()
      end while
      views = m.runner.choices()
      for i = 0 to views.count() - 1
        if views[i].label = label
          m.runner.choose(i)
          return
        end if
      end for
      m.fail("no choice labelled " + label)
    end sub

    private sub tellJoke(reaction as string)
      m.chooseLabel("Who's there?")
      while not m.runner.isChoosing()
        m.runner.advance()
      end while
      m.runner.choose(0)
      m.chooseLabel(reaction)
    end sub

    @it("loads and validates")
    function _()
      m.assertNotInvalid(m.story)
      m.assertEqual(0, BGE.Story.validateStory(m.story, m.state).count())
    end function

    @it("tells all three jokes before repeating one, then never the interrupting one again")
    function _()
      m.runner.start("start")
      m.chooseLabel("Go on, then.")
      m.tellJoke("(Laugh)")
      m.chooseLabel("Another one?")
      m.tellJoke("(Groan)")
      m.chooseLabel("Another one?")
      m.tellJoke("(Laugh)")
      m.assertEqual(1, m.state.visitCount("knockKnock#0"))
      m.assertEqual(1, m.state.visitCount("knockKnock#1"))
      m.assertEqual(1, m.state.visitCount("knockKnock#2"))
      m.assertEqual(3, m.state.flags.getInt("husk.jokes"))
    end function

    @it("counts the jokes in Husk's line after the third laugh")
    function _()
      m.runner.start("start")
      m.chooseLabel("Go on, then.")
      m.tellJoke("(Laugh)")
      m.chooseLabel("Another one?")
      m.tellJoke("(Laugh)")
      m.chooseLabel("Another one?")
      m.tellJoke("(Laugh)")
      m.assertEqual("That is 3 jokes. I believe I am now officially funny.", m.runner.currentLine().text)
    end function

    @it("ends when you decline")
    function _()
      m.runner.start("start")
      m.chooseLabel("Not now, Husk.")
      m.runner.advance()
      m.assertFalse(m.runner.isActive())
    end function

  end class
end namespace
```

(`tellJoke` takes "Who's there?", reads the joke's name, takes its single "<name> who?" choice, then the reaction.)

Run: `cd examples/story && npm test`
Expected: tests run and pass (the engine is already done) - if `pkg:/story/jokes.json` isn't in the test package, fix the `files` entry.

- [ ] **Step 4: Write the app**

`examples/story/src/source/UI/ChoiceButton.bs`:

```brighterscript
import "pkg:/source/engine/ui/Button.bs"

' A choice button that tells the current scene which choice it is.
class ChoiceButton extends BGE.UI.Button

  choiceIndex as integer = 0

  sub new(game as BGE.Game, choiceIndex as integer)
    super(game)
    m.choiceIndex = choiceIndex
    m.onActivate = sub(clicked as BGE.UI.Button)
      pressed = clicked as ChoiceButton
      scene = pressed.game.getScene() as StoryChooser
      scene.chooseIndex(pressed.choiceIndex)
    end sub
  end sub

end class

' The scene a ChoiceButton reports to.
interface StoryChooser
  sub chooseIndex(index as integer)
end interface
```

`examples/story/src/source/Scenes/StoryScene.bs`:

```brighterscript
import "pkg:/source/engine/GameScene.bs"
import "pkg:/source/engine/ui/Label.bs"
import "pkg:/source/story/StoryState.bs"
import "pkg:/source/story/DialogueRunner.bs"
import "pkg:/source/story/StoryLoader.bs"
import "../UI/ChoiceButton.bs"

' Plays jokes.json as plain text: the speaker and line at the top, choices as buttons below.
' OK reads on, Back quits.
class StoryScene extends BGE.GameScene

  private story as BGE.Story.StoryData = invalid
  private state as BGE.Story.StoryState = invalid
  private runner as BGE.Story.DialogueRunner = invalid
  private speakerLabel as BGE.UI.Label = invalid
  private lineLabel as BGE.UI.Label = invalid
  private buttons as ChoiceButton[] = []
  ' Frames to wait before adding buttons, so the OK press that ended the line can't click one.
  private buttonDelay as integer = -1

  sub new(game as BGE.Game)
    super(game)
    m.name = "StoryScene"
  end sub

  override sub onCreate(args as roAssociativeArray)
    m.story = BGE.Story.loadStory("pkg:/story/jokes.json")
    m.state = new BGE.Story.StoryState(m.story)
    m.runner = new BGE.Story.DialogueRunner(m.state, m.story)
    uiW = m.game.uiCanvas.getWidth()
    uiH = m.game.uiCanvas.getHeight()
    m.speakerLabel = new BGE.UI.Label(m.game)
    m.speakerLabel.customPosition = true
    m.speakerLabel.customX = uiW * 0.1
    m.speakerLabel.customY = uiH * 0.15
    m.speakerLabel.drawableText.textColor = &hFFD966FF
    m.game.gameUi.addChild(m.speakerLabel)
    m.lineLabel = new BGE.UI.Label(m.game)
    m.lineLabel.customPosition = true
    m.lineLabel.customX = uiW * 0.1
    m.lineLabel.customY = uiH * 0.25
    m.lineLabel.wrapWidth = uiW * 0.8
    m.game.gameUi.addChild(m.lineLabel)
    m.runner.start("start")
    m.show()
  end sub

  override sub onInput(input as BGE.GameInput)
    if not input.press
      return
    end if
    if input.isButton("back")
      m.game.End()
    else if input.isButton("ok") and not m.runner.isChoosing()
      m.runner.advance()
      m.show()
    end if
  end sub

  override sub onUpdate(deltaTime as float)
    if m.buttonDelay = 0
      m.buttonDelay = -1
      m.addButtons()
    else if m.buttonDelay > 0
      m.buttonDelay--
    end if
  end sub

  sub chooseIndex(index as integer)
    m.removeButtons()
    m.runner.choose(index)
    m.show()
  end sub

  ' Shows the current line, or the choices, or that the story is over.
  private sub show()
    if not m.runner.isActive()
      m.speakerLabel.setText("")
      m.lineLabel.setText("The end. Press Back to quit.")
    else if m.runner.isChoosing()
      m.buttonDelay = 1
    else
      line = m.runner.currentLine()
      m.speakerLabel.setText(line.speaker)
      m.lineLabel.setText(line.text)
    end if
  end sub

  private sub addButtons()
    uiW = m.game.uiCanvas.getWidth()
    uiH = m.game.uiCanvas.getHeight()
    views = m.runner.choices()
    for i = 0 to views.count() - 1
      button = new ChoiceButton(m.game, i)
      button.setLabel(views[i].label)
      button.customPosition = true
      button.customX = uiW * 0.1
      button.customY = uiH * 0.45 + i * uiH * 0.1
      button.width = uiW * 0.5
      button.height = uiH * 0.08
      m.game.gameUi.addChild(button)
      m.buttons.push(button)
    end for
    if m.buttons.count() > 0
      m.game.focusManager.focusWidget(m.buttons[0])
    end if
  end sub

  private sub removeButtons()
    for each button in m.buttons
      m.game.gameUi.removeChild(button)
    end for
    m.buttons = []
  end sub

end class
```

`examples/story/src/source/main.bs`:

```brighterscript
import "Scenes/StoryScene.bs"

sub Main()
  game = new BGE.Game(1280, 720)
  game.fitCanvasToScreen()
  ' Labels and buttons use game.defaultTheme.font - the system font at 28px.
  scene = new StoryScene(game)
  game.defineScene(scene)
  game.changeScene(scene.name)
  game.play()
end sub
```

`Game.End()` is how `examples/pong` quits on Back; `DrawableText.textColor` is packed RGBA (`&hFFD966FF`). Disabled choices: this minimal example skips `showDisabled` styling - a disabled view is still listed; `chooseIndex` on it does nothing (runner ignores it). jokes.json has none.

- [ ] **Step 5: Validate, then run it on a device**

Run: `cd examples/story && npx bsc --validate --create-package=false` (or `npm run validate-examples` from the root)
Expected: no errors.

Then follow the `rokubot-examples` skill: build/sideload `examples/story`, screenshot the first line, press OK, screenshot the choices, select "Go on, then.", step through a joke to the reaction choices. Expected: Husk's line, three choice buttons with the first focused, a joke plays, and after a reaction the start choices return with "Another one?" visible.

- [ ] **Step 6: Commit**

```bash
git add examples/story .vscode/tasks.json
git commit -m "examples/story: a text-only knock-knock story on BGE.Story (#298)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: The rpg's story data and vocabulary on the engine

Swap the rpg's pure story files over to `BGE.Story` and get `cd examples/rpg && npm test` green. (Task 10 does the entity and UI.)

**Files:**
- Delete: `examples/rpg/src/source/Story/ValueKinds.bs`, `StoryFlags.bs`, `Inventory.bs`, `Text.bs`, `Conditions.bs`, `Effects.bs`, `DialogueData.bs`
- Create: `examples/rpg/src/source/Story/StoryData.bs`, `examples/rpg/src/source/Story/RpgVocabulary.bs`
- Modify: `Story/StoryTypes.bs`, `Story/EventRules.bs`, `Story/Items.bs`, `Story/ShopData.bs`, `Story/QuestData.bs`, `Story/SaveData.bs`, `Story/Checkpoints.bs`, `Maps/LivePlacements.bs` (gains `filterPlacements`), `Maps/MapTypes.bs`, `Maps/Keep.bs`, `Maps/DungeonData.bs`, `World/PickupRules.bs`, `examples/rpg/bsconfig.test.json`
- Tests: delete `examples/rpg/tests/StoryFlags.spec.bs`, `Inventory.spec.bs`, `ValueKinds.spec.bs`; rewrite `Conditions.spec.bs`, `Effects.spec.bs`, `EventRules.spec.bs`, `DialogueData.spec.bs` (→ `StoryData.spec.bs`), `SaveData.spec.bs`, `Shop.spec.bs`, `QuestData.spec.bs`, `LivePlacements.spec.bs`, `TownGate.spec.bs`, `PickupRules.spec.bs`, and any other spec that references the renamed symbols (find them with the grep in Step 1).

**Interfaces:**
- Consumes: `BGE.Story.*`.
- Produces (rpg): `getStoryData() as BGE.Story.StoryData`; `interface RpgVocabularyContext { player as PlayerStats }`; `registerRpgVocabulary(state as BGE.Story.StoryState, vocab as RpgVocabularyContext)`; `newRpgStoryState(vocab as RpgVocabularyContext) as BGE.Story.StoryState`; `filterPlacements(placements as MapPlacement[], state as BGE.Story.StoryState) as MapPlacement[]`; `diffLivePlacements(placements, present, state as BGE.Story.StoryState)`; `canBuy(itemId, price, state, player)`, `buyItem(itemId, price, state, player)`, `canUse(itemId, state, player)`, `useItem(itemId, state, player)`; `buildSaveData(sceneName, spawn, state as BGE.Story.StoryState, playerStats as PlayerStats) as SaveData`; `interface RpgItemDefinition extends BGE.Story.ItemDefinition`; `interface RpgChoice extends BGE.Story.StoryChoice { optional open as string }`.

Symbol mapping (apply everywhere in the rpg, source and tests):

| Old | New |
|---|---|
| `StoryFlags` / `Inventory` / `valueKind` / `interpolateFlags` | `BGE.Story.StoryFlags` / `BGE.Story.Inventory` / `BGE.Story.valueKind` / `BGE.Story.interpolateFlags` |
| `StoryCondition`, `StoryEffect`, `EventRule`, `StoryResult`, `StoryMessage` | `BGE.Story.` + same name |
| `ItemDefinition` | `RpgItemDefinition` (rpg fields) |
| `DialoguePage` | `BGE.Story.StoryNode` |
| `DialogueChoice` | `RpgChoice` |
| `StoryContext` / `ctx` | `BGE.Story.StoryState` / `state` (+ a separate `player as PlayerStats` param where `ctx.player` was read) |
| `ctx.items` | `state.items` |
| `evaluateConditions(x, ctx)` | `state.evaluate(x)` |
| `applyEffects(x, ctx)` | `state.applyEffects(x)` |
| `runEventRules(getEventRules(), name, data, ctx)` | `state.runEvent(name, data)` |
| `settleStory(getEventRules(), ctx)` | `state.settle()` |
| `newStoryContext(flags, inv, player)` | `newRpgStoryState({player: player})` then set flags/inventory on it |
| `import "Story/StoryFlags.bs"` etc. | `import "pkg:/source/story/StoryState.bs"` (or the specific engine file) |

- [ ] **Step 1: Find every use**

Run: `grep -rln "StoryFlags\|Inventory\b\|valueKind\|interpolateFlags\|StoryContext\|newStoryContext\|evaluateConditions\|applyEffects\|runEventRules\|settleStory\|DialoguePage\|DialogueChoice\|ItemDefinition\|selectDialoguePage\|getDialogueData" examples/rpg/src examples/rpg/tests`
Keep the list; every file in it is touched by this task or Task 10 (`Story.bs`, `DialogueBox.bs`, `main.bs`, `AreaScene.bs`, `Pickup.bs`, `ShopPanel.bs`, `InventoryPanel.bs`, `HeartsHud.bs`, `TitleScene.bs` are Task 10).

- [ ] **Step 2: Write `RpgVocabulary.bs`**

```brighterscript
' examples/rpg/src/source/Story/RpgVocabulary.bs
import "pkg:/source/story/StoryState.bs"
import "StoryTypes.bs"
import "StoryData.bs"

' What the rpg's own conditions and effects read and change. The Story entity points player at the
' Player entity before each story operation; tests pass a plain AA.
interface RpgVocabularyContext
  player as PlayerStats
end interface

' A StoryState for the rpg's story, with its own vocabulary registered.
'
' @param {RpgVocabularyContext} vocab
' @return {BGE.Story.StoryState}
function newRpgStoryState(vocab as RpgVocabularyContext) as BGE.Story.StoryState
  state = new BGE.Story.StoryState(getStoryData())
  registerRpgVocabulary(state, vocab)
  return state
end function

' Adds coinsGte, giveCoins, takeCoins, heal and addMaxHealth.
sub registerRpgVocabulary(state as BGE.Story.StoryState, vocab as RpgVocabularyContext)
  state.registerCondition("coinsGte", rpgCoinsGte, vocab)
  state.registerEffect("giveCoins", rpgGiveCoins, vocab)
  state.registerEffect("takeCoins", rpgTakeCoins, vocab)
  state.registerEffect("heal", rpgHeal, vocab)
  state.registerEffect("addMaxHealth", rpgAddMaxHealth, vocab)
end sub

function rpgCoinsGte(condition as roAssociativeArray, state as object, vocab as dynamic) as boolean
  return vocab.player.coins >= condition.coinsGte
end function

function rpgGiveCoins(effect as roAssociativeArray, state as object, vocab as dynamic) as boolean
  vocab.player.coins += effect.giveCoins
  return effect.giveCoins <> 0
end function

function rpgTakeCoins(effect as roAssociativeArray, state as object, vocab as dynamic) as boolean
  stats = vocab.player
  before = stats.coins
  stats.coins -= effect.takeCoins
  if stats.coins < 0
    stats.coins = 0
  end if
  return before <> stats.coins
end function

function rpgHeal(effect as roAssociativeArray, state as object, vocab as dynamic) as boolean
  stats = vocab.player
  before = stats.health
  stats.health += effect.heal
  if stats.health > stats.maxHealth
    stats.health = stats.maxHealth
  end if
  return before <> stats.health
end function

function rpgAddMaxHealth(effect as roAssociativeArray, state as object, vocab as dynamic) as boolean
  vocab.player.maxHealth += effect.addMaxHealth
  return true
end function
```

- [ ] **Step 3: Write `StoryData.bs` from `DialogueData.bs`**

Move `getDialogueData()`'s AA into `getStoryData()`, cached on the global AA as `rpgStory`:

```brighterscript
' examples/rpg/src/source/Story/StoryData.bs
import "pkg:/source/story/StoryTypes.bs"
import "EventRules.bs"
import "Items.bs"

' The rpg's story: each NPC's dialogue (a list of pages - the first whose `when` passes is used),
' the event rules and the items. A page's effects run once its last line is read.
'
' @return {BGE.Story.StoryData}
function getStoryData() as BGE.Story.StoryData
  globals = GetGlobalAA()
  if globals.rpgStory = invalid
    globals.rpgStory = {nodes: getDialogueNodes(), rules: getEventRules(), items: getItemDefinitions()}
  end if
  return globals.rpgStory
end function

' npc id -> pages
function getDialogueNodes() as roAssociativeArray
  return {
    ' ... every entry of today's getDialogueData() AA, unchanged except the edits listed below ...
  }
end function
```

Copy each NPC's page list verbatim from `DialogueData.bs` into `getDialogueNodes()`, then make these edits:

1. Bram's quest-start page (the last, default one) gains a `rats.kills` reset so `${rats.kills}` reads `0`:
   `effects: [{set: "rats.stage", value: 1}, {set: "rats.kills", value: 0}]`
2. Random townsfolk. Replace `wanderPlaza`, `wanderMarket`, `child` and `oldWoman` with first-match routers whose default page jumps to a random group (ids use a `.` - allowed; only `#` and `/` aren't):

```brighterscript
    wanderPlaza: [
      {when: [{flag: "witch.defeated"}], speaker: "Townsman", lines: ["The castle lights are back on! Was that you?"]},
      {when: [{flag: "gate.open"}], speaker: "Townsman", lines: ["They say the knight let someone through the gate!"]},
      {"goto": "wanderPlaza.idle"}
    ],
    "wanderPlaza.idle": {select: "random", candidates: [
      {speaker: "Townsman", lines: ["Mind the rats. One bit my boot clean through."]},
      {speaker: "Townsman", lines: ["Fountain's been running brown since the witch came."]},
      {speaker: "Townsman", lines: ["I'd leave town, if the road weren't crawling with worse."]}
    ]},
    wanderMarket: [
      {when: [{flag: "witch.defeated"}], speaker: "Townswoman", lines: ["Folk are coming back to market. It feels like a feast day."]},
      {when: [{flag: "rats.stage", gte: 3}], speaker: "Townswoman", lines: ["Fewer rats about. Was that your doing?"]},
      {"goto": "wanderMarket.idle"}
    ],
    "wanderMarket.idle": {select: "random", candidates: [
      {speaker: "Townswoman", lines: ["Nobody comes to market any more. Not with the rats."]},
      {speaker: "Townswoman", lines: ["Hilde's prices are robbery. Still, what else is there?"]},
      {speaker: "Townswoman", lines: ["I keep a broom by the door now. For the rats."]}
    ]},
    child: [
      {when: [{flag: "witch.defeated"}], speaker: "Child", lines: ["Mum says the witch is gone. Can I go and see the castle?"]},
      {"goto": "child.idle"}
    ],
    "child.idle": {select: "random", candidates: [
      {speaker: "Child", lines: ["I heard scratching down the tunnel by the wall. Mum says it's the sewer."]},
      {speaker: "Child", lines: ["Are you a knight? You don't look like a knight."]}
    ]},
    oldWoman: [
      {when: [{flag: "witch.defeated"}], speaker: "Old Woman", lines: ["Sixty years by this water, and I've never seen the castle shine like this."]},
      {"goto": "oldWoman.idle"}
    ],
    "oldWoman.idle": {select: "random", candidates: [
      {speaker: "Old Woman", lines: ["I've lived by this water sixty years. Never seen the castle so dark."]},
      {speaker: "Old Woman", lines: ["The old king used to feed the ducks here. Now look at it."]}
    ]}
```

3. Hilde's choices and Bram's credits choice keep their `open` key (now read from `RpgChoice`).

Delete `DialogueData.bs`.

- [ ] **Step 4: Slim `StoryTypes.bs` and rewrite the pure files**

`Story/StoryTypes.bs` keeps only rpg types, now built on the engine's:

```brighterscript
' Shapes of the rpg's own story data. Engine-free apart from BGE.Story's types, so its tests can use them.
import "pkg:/source/story/StoryTypes.bs"
import "pkg:/source/story/StoryFlags.bs"
import "pkg:/source/story/Inventory.bs"

' What a Player entity has that the story reads and changes (tests pass a plain AA).
interface PlayerStats
  health as integer
  maxHealth as integer
  coins as integer
end interface

interface RpgItemDefinition extends BGE.Story.ItemDefinition
  name as string
  icon as string
  ' 16px spin frames (8, in a 64x32 sheet) a Pickup plays on the floor instead of the icon
  optional spinSheet as string
  optional onUse as BGE.Story.StoryEffect[]
end interface

' A dialogue choice: "shop" opens the shop, "credits" rolls the credits, once the dialogue closes.
interface RpgChoice extends BGE.Story.StoryChoice
  optional open as string
end interface
```

...followed by `ShopItem`, `QuestDefinition`, `SaveData` (with `optional visits as roAssociativeArray`), `ActionResult`, `StoryCheckpoint` (flags/inventory typed `BGE.Story.StoryFlags`/`BGE.Story.Inventory`) and `StoryPanel`, unchanged. Delete `StoryContext`, `StoryCondition`, `StoryEffect`, `DialogueChoice`, `DialoguePage`, `EventRule`, `ItemDefinition`, `StoryMessage`, `StoryResult` from it.

`Story/EventRules.bs`: keep only `getEventRules() as BGE.Story.EventRule[]` (same rule list); delete `runEventRules`, `ruleMatches`, `settleStory`, `STORY_SETTLE_MAX_PASSES`.

`Story/Items.bs`: `getItemDefinitions()` unchanged (its AA already has `max`); `swordDamageFor(carried as BGE.Story.Inventory)`; import `pkg:/source/story/Inventory.bs`.

`Story/ShopData.bs`: every function takes `(…, state as BGE.Story.StoryState, player as PlayerStats)`; `ctx.inventory` → `state.inventory`, `ctx.items[id] as ItemDefinition` → `state.items[id] as RpgItemDefinition`, `ctx.player` → `player`, `applyEffects(list, ctx)` → `state.applyEffects(list)`.

`Story/QuestData.bs`: `interpolateFlags` → `BGE.Story.interpolateFlags`; flags param typed `BGE.Story.StoryFlags`.

`Story/SaveData.bs`:

```brighterscript
const SAVE_VERSION = 2

function buildSaveData(sceneName as string, spawn as string, state as BGE.Story.StoryState, playerStats as PlayerStats) as SaveData
  story = state.toSaveData()
  return {
    version: SAVE_VERSION,
    scene: sceneName,
    spawn: spawn,
    flags: story.flags,
    inventory: story.inventory,
    visits: story.visits,
    player: {health: playerStats.health, maxHealth: playerStats.maxHealth, coins: playerStats.coins}
  }
end function
```

and in `validateSaveData`, accept version 1 or 2: replace `if data.version <> SAVE_VERSION` with `if data.version <> 1 and data.version <> SAVE_VERSION`, and add `if data.visits <> invalid and type(data.visits) <> "roAssociativeArray" then return invalid` (as a multi-line `if` - inline if is disallowed by bslint). `valueKind` → `BGE.Story.valueKind`.

`Story/Checkpoints.bs`: `new StoryFlags()` → `new BGE.Story.StoryFlags()`, `new Inventory(getItemDefinitions())` → `new BGE.Story.Inventory(getItemDefinitions())`, and at `n >= 1` also `flags.set("rats.kills", 0)`.

`Maps/LivePlacements.bs`: `diffLivePlacements(…, state as BGE.Story.StoryState)` using `state.evaluate(item.when)`, and move `filterPlacements` here from the deleted `Conditions.bs` with the same body using `state.evaluate(placement.when)`. Imports: drop `../Story/Conditions.bs`, add `pkg:/source/story/StoryState.bs`.

`Maps/MapTypes.bs`, `Maps/Keep.bs`, `Maps/DungeonData.bs`, `World/FloorSwitch.bs`, `World/Pickup.bs` types: `StoryCondition`/`StoryEffect` → `BGE.Story.StoryCondition`/`BGE.Story.StoryEffect` (with the engine import). `World/PickupRules.bs`: `Inventory` → `BGE.Story.Inventory`.

Delete `Story/ValueKinds.bs`, `StoryFlags.bs`, `Inventory.bs`, `Text.bs`, `Conditions.bs`, `Effects.bs`.

- [ ] **Step 5: Point the rpg test build at the engine**

In `examples/rpg/bsconfig.test.json` `files`: remove `source/Story/ValueKinds.bs`, `StoryFlags.bs`, `Inventory.bs`, `Conditions.bs`, `Effects.bs`, `Text.bs`, `DialogueData.bs`; add `source/Story/StoryData.bs`, `source/Story/RpgVocabulary.bs`, and the same 13 `{src: "../../../src/source/story/<File>.bs", dest: "source/story/<File>.bs"}` entries Task 8's config lists (all non-spec engine story files).

- [ ] **Step 6: Rewrite the rpg specs**

Delete `tests/StoryFlags.spec.bs`, `tests/Inventory.spec.bs`, `tests/ValueKinds.spec.bs` (covered by the engine). In every other spec, replace the `ctx` setup with:

```brighterscript
    private vocab as object
    private state as BGE.Story.StoryState

    protected override function beforeEach()
      m.vocab = {player: {health: 6, maxHealth: 6, coins: 5}}
      m.state = newRpgStoryState(m.vocab)
    end function
```

then apply the mapping table (`m.ctx.flags` → `m.state.flags`, `m.ctx.player` → `m.vocab.player`, `evaluateConditions(x, m.ctx)` → `m.state.evaluate(x)`, `runEventRules(getEventRules(), e, d, m.ctx)` → `m.state.runEvent(e, d)`, `settleStory(getEventRules(), m.ctx)` → `m.state.settle()`, shop calls gain `m.vocab.player`). Specific content changes:
- `Conditions.spec.bs`: drop the generic flag/item cases (now in the engine); keep the coins case (`{coinsGte: 5}`) and the `filterPlacements` cases.
- `Effects.spec.bs`: keep only coins/heal/addMaxHealth/giveItem-heartContainer cases (rpg vocabulary + an rpg item's `onAcquire`).
- `DialogueData.spec.bs` → rename to `StoryData.spec.bs`, suite `"rpg story data"`; each "Bram says X at stage Y" case becomes: set flags, `runner = new BGE.Story.DialogueRunner(m.state, getStoryData())`, `runner.start("bram")`, assert `runner.currentLine().text`. Add:

```brighterscript
    @it("validates")
    function _()
      m.assertEqual([], BGE.Story.validateStory(getStoryData(), m.state))
    end function

    @it("plays every idle townsfolk line before repeating one")
    function _()
      story = getStoryData()
      runner = new BGE.Story.DialogueRunner(m.state, story)
      seen = {}
      for i = 1 to 3
        runner.start("wanderPlaza")
        seen[runner.currentLine().text] = true
      end for
      m.assertEqual(3, seen.Count())
    end function

    @it("shows 0 rat kills right after the quest starts")
    function _()
      runner = new BGE.Story.DialogueRunner(m.state, getStoryData())
      runner.start("bram")
      while runner.isActive()
        runner.advance()
      end while
      runner.start("bram")
      m.assertEqual("Still rats about. 0 of 4 so far.", runner.currentLine().text)
    end function
```

(`assertEqual([], …)` prints the errors on failure, which is the point.)
- `SaveData.spec.bs`: build with `buildSaveData(scene, spawn, m.state, m.vocab.player)`; add a case that a version 1 save (no `visits`) still validates, and that `visits` round-trips.

- [ ] **Step 7: Run the rpg tests**

Run: `cd examples/rpg && npm test`
Expected: PASS. Expect type errors from Task 10's files (`Story.bs`, `DialogueBox.bs`, …) only if they're in the test build's `files` list - they aren't, so the test build should compile now. The full app won't compile until Task 10.

- [ ] **Step 8: Commit**

```bash
git add -A examples/rpg
git commit -m "rpg: story data, vocabulary and save data on BGE.Story (#298)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

(`git status` first - only `examples/rpg` should be staged.)

---

### Task 10: The rpg's Story entity and DialogueBox on the runner

**Files:**
- Modify: `examples/rpg/src/source/Story/Story.bs`, `UI/DialogueBox.bs`, `main.bs`, `Scenes/AreaScene.bs`, `World/Pickup.bs`, `UI/ShopPanel.bs`, `UI/InventoryPanel.bs`, `UI/HeartsHud.bs`, `Scenes/TitleScene.bs` (only where they use renamed symbols)

**Interfaces:**
- Consumes: Task 9's rpg functions, `BGE.Story.DialogueRunner`.
- Produces: `Story.storyState() as BGE.Story.StoryState` (replaces `context()`), `Story.dialogueStepped(result as BGE.Story.StoryResult)`, `Story.dialogueChose(result as BGE.Story.StoryResult, open as string)`, `Story.dialogueEnded()`, `Story.cancelDialogue()`; `DialogueBox.new(game as BGE.Game, runner as BGE.Story.DialogueRunner)`.

- [ ] **Step 1: `Story.bs`**

Fields: replace `flags`/`inventory` construction with

```brighterscript
  state as BGE.Story.StoryState = invalid
  runner as BGE.Story.DialogueRunner = invalid
  ' Kept as aliases of the state's, which never replaces them.
  flags as BGE.Story.StoryFlags = invalid
  inventory as BGE.Story.Inventory = invalid
  private vocab as RpgVocabularyContext = invalid
  ' A choice's open ("shop", "credits") to act on when the dialogue closes.
  private pendingOpen as string = ""
```

and in `new()`:

```brighterscript
    m.vocab = {player: invalid}
    m.state = newRpgStoryState(m.vocab)
    m.runner = new BGE.Story.DialogueRunner(m.state, getStoryData())
    m.flags = m.state.flags
    m.inventory = m.state.inventory
```

Replace `context()` with:

```brighterscript
  ' The story state, with the rpg's vocabulary pointed at the current Player. Use this, not m.state,
  ' for anything that evaluates conditions or applies effects.
  function storyState() as BGE.Story.StoryState
    m.vocab.player = m.getPlayer()
    return m.state
  end function
```

Make `getPlayer()` public only if another file needs it (it doesn't). Then:
- `newGame()`: `m.storyState().reset()` instead of clearing flags/inventory.
- `loadSave(save)`: `m.storyState().loadSaveData({flags: save.flags, inventory: save.inventory, visits: save.visits})`.
- `applyCheckpoint(n)`: `m.newGame()`, then `m.flags.loadAA(...)`/`m.inventory.loadAA(...)` as today.
- `save()`: `buildSaveData(m.sceneName, m.spawn, m.state, m.getPlayer())`.
- `onGameEvent`: `m.applyResult(m.storyState().runEvent(eventName, data))`.
- `runEffects`: `m.applyResult(m.storyState().applyEffects(effects))`.
- `tryUnlock`: `m.storyState().evaluate(unlock.when)`.
- `buy`/`use`: `buyItem(itemId, m.priceOf(itemId), m.storyState(), m.getPlayer())`, `useItem(itemId, m.storyState(), m.getPlayer())`.
- `applyResult`: `settled = m.storyState().settle()`; types `BGE.Story.StoryResult`.
- Delete `finishDialogue(page, choice)`; add:

```brighterscript
  ' Called by the DialogueBox after advance(): settles, saves and posts what the step did.
  sub dialogueStepped(result as BGE.Story.StoryResult)
    m.applyResult(result)
  end sub

  ' Called by the DialogueBox after choose(). open is the choice's "open" key ("" for none).
  sub dialogueChose(result as BGE.Story.StoryResult, open as string)
    if open <> ""
      m.pendingOpen = open
    end if
    m.applyResult(result)
  end sub

  ' Called by the DialogueBox once the runner is no longer active.
  sub dialogueEnded()
    m.openPanel = invalid
    opens = m.pendingOpen
    m.pendingOpen = ""
    if opens = "credits"
      m.pendingCredits = true
    end if
    ' Open the shop before releasing the dialogue's modal so the game never resumes in between.
    if opens = "shop"
      m.openShop()
    end if
    m.endTalking()
    m.releaseModalLater()
  end sub
```

- `cancelDialogue()`: add `m.runner.cancel()` and `m.pendingOpen = ""` before the existing body.
- `startDialogue(npcId)`:

```brighterscript
  private sub startDialogue(npcId as string)
    if m.isModalOpen()
      return
    end if
    result = m.runner.start(npcId)
    if not m.runner.isActive()
      m.applyResult(result)
      return
    end if
    ' ... existing talkingNpc lookup and facing, unchanged ...
    m.openDialogue()
    m.applyResult(result)
  end sub
```

- Pending messages in `onUpdate`: replace the `DialoguePage` build with `m.runner.startNode({speaker: message.speaker, lines: [message.text]})` then `m.openDialogue()`.
- `openDialogue()` takes no page: `dialogue = new DialogueBox(m.game, m.runner)`.
- Imports: drop `StoryFlags.bs`, `Inventory.bs`, `Conditions.bs`, `Effects.bs`, `DialogueData.bs`; add `pkg:/source/story/StoryState.bs`, `pkg:/source/story/DialogueRunner.bs`, `StoryData.bs`, `RpgVocabulary.bs`.

- [ ] **Step 2: `DialogueBox.bs`**

Keep the layout, 9-patch, paging, `more` indicator, choice-button row and the one-frame choice delay. Replace the page-driven state with the runner:

```brighterscript
  private runner as BGE.Story.DialogueRunner = invalid
  private speakerLabel as BGE.UI.Label = invalid
  private choiceViews as BGE.Story.ChoiceView[] = []

  ' @param {BGE.Story.DialogueRunner} runner - already started
  sub new(game as BGE.Game, runner as BGE.Story.DialogueRunner)
    super(game)
    m.name = "DialogueBox"
    m.runner = runner
    ' ... the existing size/position/9-patch setup, minus the paging loop ...
  end sub

  ' Pages the current line (each wrapped line group of DIALOGUE_LINES_PER_PAGE is one page).
  private sub loadLine()
    font = m.game.getFont("hud")
    innerWidth = m.width - DIALOGUE_PADDING * 2
    line = m.runner.currentLine()
    m.speakerLabel.setText(line.speaker)
    m.pages = [] as string[]
    wrapped = BGE.UI.wrapText(line.text, font, innerWidth)
    ' ... the existing i/lastIndex/pageLines loop over wrapped, pushing into m.pages ...
    m.showPage(0)
  end sub

  ' After advance() or choose(): show the next line, the choices, or close.
  private sub afterStep()
    m.removeChoiceButtons()
    if not m.runner.isActive()
      m.close()
      storyEntity = m.game.getEntityByName("Story") as Story
      storyEntity.dialogueEnded()
    else if m.runner.isChoosing()
      m.choicesDelay = 1
      m.more.setText("")
    else
      m.loadLine()
    end if
  end sub
```

- `open(parent)`: create `m.speakerLabel` where the old `speaker` label was (no `setText` there), create body/more as today, then `if m.runner.isChoosing() then m.afterStep() else m.loadLine()` (multi-line `if`), then `parent.addChild(m)`.
- `onInput` OK on the last page: `storyEntity.dialogueStepped(m.runner.advance())` then `m.afterStep()` (OK is ignored while choice buttons are shown, as today).
- `onInput` Back: unchanged (`m.close()`, `storyEntity.cancelDialogue()`).
- `showPage(index)`: drop the "last page with choices" branch - choices now come from `afterStep()`; keep `...`/`""` for the more indicator.
- `showChoices()`: `m.choiceViews = m.runner.choices()`; build one button per view with `setLabel(view.label)`; skip disabled views (the rpg has none) - or build them and leave `enabled` unhandled; build only enabled ones.
- `chooseIndex(index)`:

```brighterscript
  sub chooseIndex(index as integer)
    view = m.choiceViews[index]
    choice = view.choice as RpgChoice
    open = ""
    if BGE.Story.valueKind(choice.open) = "string"
      open = choice.open
    end if
    result = m.runner.choose(index)
    storyEntity = m.game.getEntityByName("Story") as Story
    storyEntity.dialogueChose(result, open)
    m.afterStep()
  end sub
```

(`index` here is the button's position in `m.choiceViews`, which must match `runner.choices()` - so build buttons for every view in order; if you skip disabled ones, map button index → view index.)
- `removeChoiceButtons()`: remove each button from `m` and clear `m.choiceButtons` (focus unregisters on removal).
- Delete `finish()` and the `page` field; imports drop `../Story/StoryFlags.bs`, `../Story/Text.bs`, `../Story/StoryTypes.bs` → add `pkg:/source/story/DialogueRunner.bs` and keep `../Story/StoryTypes.bs` for `RpgChoice`.

- [ ] **Step 3: The other consumers**

- `main.bs`: `settleStory(getEventRules(), storyEntity.context())` → `storyEntity.storyState().settle()`; drop `import "Story/EventRules.bs"` if now unused.
- `Scenes/AreaScene.bs`: `storyEntity.context()` → `storyEntity.storyState()` (both calls); drop `import "../Story/Conditions.bs"`, add `import "../Maps/LivePlacements.bs"` if `filterPlacements` isn't already reachable.
- `World/Pickup.bs`: `storyEntity.context().items[m.itemId] as ItemDefinition` → `storyEntity.storyState().items[m.itemId] as RpgItemDefinition`.
- `UI/ShopPanel.bs`, `UI/InventoryPanel.bs`: `as ItemDefinition` → `as RpgItemDefinition`.
- `UI/HeartsHud.bs`, `Scenes/TitleScene.bs`: no change expected (they use `inventory`, `readSave`, `loadSave`, `newGame`); fix any compile error the build reports.

- [ ] **Step 4: Build and validate**

Run: `npm run validate-examples` (root) and `cd examples/rpg && npm test`
Expected: no diagnostics in `examples/rpg` or `examples/story`; rpg tests PASS.

- [ ] **Step 5: On-device check**

Follow the `rokubot-examples` skill for `examples/rpg`. Checks (ask the user to play the real-time parts, per the standing preference - rokubot is for menus/dialogue):
1. `--param scene=TownScene` (saving off): talk to Bram → the quest-start page; talk again → "Still rats about. 0 of 4 so far."
2. Talk to a plaza townsperson three times → three different lines.
3. `--param stage=3`: talk to Hilde → "Browse wares" opens the shop; leaving returns to play.
4. `--param stage=8 --param scene=TownScene`: Bram's final page → "The End" → credits roll.
5. Back out of a dialogue mid-page → game resumes, no effects ran.

- [ ] **Step 6: Commit**

```bash
git add -A examples/rpg
git commit -m "rpg: Story entity and DialogueBox driven by BGE.Story.DialogueRunner (#298)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 11: Docs, CLAUDE.md and the PR

**Files:**
- Create: `docs/story.md`
- Modify: `CLAUDE.md`

- [ ] **Step 1: Write `docs/story.md`**

Frontmatter `title: Stories and Dialogue`, `group: Guides`, `order: 10` (the existing guides use 1-9). Lead with code (the standing "fundamentals over gotchas" preference). Sections, each with a code sample:

1. **A first story** - `jokes.json` (abridged: `start`, `knockKnock`, one joke, `laugh`), then the 20-line core of `StoryScene` (`loadStory`, `new StoryState`, `new DialogueRunner`, `start`, `currentLine`, `advance`, `choices`, `choose`). Link `examples/story`.
2. **Nodes** - lines (string or object, extra keys pass through), `speaker`, effects running after the last line, then choices → `call` → `goto` → `end` → return/finish. Note `goto`/`call`/`end` are quoted in BrighterScript AA literals and read with brackets.
3. **Choices** - `when`, `showDisabled`, `once`, fallback (no label), `call` from a choice returning to the same choices (the hub pattern).
4. **Picking a node** - candidate lists (first match), `{select: "random", candidates}` (least-visited first), `once` nodes, visit counts and `visited`/`notVisited`.
5. **Flags and conditions** - the built-in condition table and `${flag}` (with the type table: string as-is, numbers via toStr, booleans true/false, missing → "").
6. **Effects and event rules** - built-in effects, `runEvent`, `settle()`, posts and messages; when to call `settle()`.
7. **Your own vocabulary** - `registerCondition`/`registerEffect` with a context, e.g. coins (from the rpg).
8. **Items** - `items` with `max`/`onAcquire`, extra fields for your game.
9. **Saving** - `state.toSaveData()`/`loadSaveData()`, `runner.getPosition()`/`restore()`, backlog saved separately, `BGE.registryWrite`.
10. **Checking a story** - `validateStory` in a Rooibos test.

Run `npm run docs` and open the generated page to check it renders and appears under Guides.

- [ ] **Step 2: Update CLAUDE.md**

Add an Architecture bullet (after "Math / Utils" or as its own `### Story (story/)` section):

```markdown
### Story (`story/`)

`BGE.Story` (issue #298, spec `specs/2026-10-11-bge-story-and-visual-novel-design.md`, guide `docs/story.md`) is a UI-free story layer shared by `examples/story` (text-only knock-knock jokes), `examples/rpg` and the visual novel. `StoryState` owns flags (`StoryFlags`), the `Inventory`, visit counts and the condition/effect vocabulary (built-ins plus `registerCondition`/`registerEffect(key, fn, context)` - the handler gets `(item, state, context)` since BrightScript functions can't capture variables). `DialogueRunner` plays a `StoryData` graph: a node id maps to a node, a first-match candidate list, or `{select: "random", candidates}` (least-visited first, injectable `random`); after a node's lines its effects run, then choices (`when`/`showDisabled`/`once`/an unlabelled fallback) → `call` → `goto` → `end` → return to the caller. `goto`/`call`/`end` are reserved words: engine code reads them with brackets and AA literals quote them. Visit keys are `<id>`, `<id>#<index>` for a candidate and `<node>/<choice id or label>` for a choice, so ids can't contain `#` or `/`. Stories load from JSON (`loadStory`) and are checked with `validateStory` in each consumer's tests. Missing flags interpolate as `""`.
```

Edit the rpg bullet: replace "The story layer deliberately stays in the example (see the D2 spec); promoting it is follow-up issue #298." and the earlier "it stays in the example (decided in D2; follow-up #298)" with: "Its generic core is now the engine's `BGE.Story` (#298); the rpg keeps its data (`Story/StoryData.bs`), its vocabulary (`Story/RpgVocabulary.bs` - coins, heal, max health), shop, quests, checkpoints and save data, and its `Story` entity wraps a `StoryState` and `DialogueRunner` (use `storyState()`, which points the vocabulary at the current Player). Townsfolk idle lines are random groups (`wanderPlaza.idle` etc.)." Also update the line listing `examples/` at the top of CLAUDE.md to include `story`.

- [ ] **Step 3: Full gate**

Run: `npm run check:all`, then `cd examples/rpg && npm test`, then `cd examples/story && npm test`
Expected: all pass. Report any failure with its output rather than working around it.

- [ ] **Step 4: Commit and open the PR**

```bash
git add docs/story.md CLAUDE.md
git commit -m "Docs: Stories and Dialogue guide, CLAUDE.md for BGE.Story (#298)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git push -u origin feature/issue-298-bge-story
```

Use the `pr-voice` skill to write the PR description (closes #298; mentions the spec, `examples/story`, the rpg migration, the one behaviour change - page effects run before choices - and the save version bump). End it with the `🤖 Generated with [Claude Code](https://claude.com/claude-code)` line. Open with `gh pr create --base main`.
