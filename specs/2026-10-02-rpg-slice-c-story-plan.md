# rpg Slice C: Story, NPCs, shop, saving — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give `examples/rpg` a story: talkable NPCs, a rats quest that opens the castle gate, a shop, an inventory, a sewer to grind coins in, autosave with Continue/New Game on a title screen. Also add word wrapping to `BGE.UI.Label`.

**Architecture:** The engine gains `BGE.UI.wrapText()`, `Label.wrapWidth`, and two multi-line sizing fixes in `DrawableText`. The example gains an engine-free, data-driven story layer under `src/source/Story/`. It's made of `StoryFlags` and `Inventory` state, `Conditions`/`Effects` over plain AAs, dialogue pages (first match wins), event rules (every match runs, then a `storyChanged` settle loop), a quest log and save data. That layer is all pure functions, unit tested in `examples/rpg/tests/`. A persistent, non-pauseable `Story` entity owns the state and coordinates the UI (dialogue, shop, inventory, save note). NPCs are `GameEntity`s tagged `npc`. Panels are built fresh on open and torn down on close, and they pause the game while open.

**Tech Stack:** BrighterScript (bsc 1.0.0-alpha.56), Rooibos v6, brs-cli for headless tests, rokubot for on-device checks, ImageMagick (`magick`) for asset prep.

**Spec:** `specs/2026-10-02-rpg-slice-c-story-design.md`

## Global Constraints

- One `@suite` class per `*.spec.bs` file (Rooibos v6 corrupts metadata otherwise).
- `bslint`: no single-line `if`, consts are plain literals, `eol-last` off.
- A file that uses another file's symbol `import`s it. Example files import engine files as `pkg:/source/engine/...`.
- Never compare two objects (class instances, `roFont`, `roRegion`, `roBitmap`) with `=`. Compare an id or a scalar proxy.
- A discrete input action is guarded with `input.press and input.isButton(...)`.
- Assign `new X(...)` to a local before passing it to `addEntity`/`addChild`.
- All UI stays ≥10% inside every UI-canvas edge (title-safe).
- Rectangles are `{x, y, w, h}`, bottom-left corner, world +y up. A `RectangleCollider` for a box with bottom `by` relative to the entity uses `offset_y = by + h`.
- `assertEqual` is type-strict (Integer vs Float). Story values are Integers throughout, so compare with integer literals.
- **`then` is a BrightScript reserved word**, so data never uses it as an AA key. The spec's `then:` is written `effects:` everywhere in code, and a rule's `on:` is written `event:`.
- The engine's own tests pass with `npm run check` from the repo root. The example's pure tests pass with `cd examples/rpg && npm test`. The example validates with `cd examples/rpg && npx bsc --create-package=false`.
- Story modules (`src/source/Story/*.bs` except `Story.bs`) import nothing from the engine, so the rpg test build (which only includes `SolidWorld.bs` from the engine) can compile them.
- Comments are terse: 1-3 sentences, the "why" only.

## Review Focus

1. **Comparing a missing flag to a number** (`{flag: "rats.stage", eq: 2}` on a new game). BrightScript can crash on `invalid = 2`. `conditionPasses` must go through `getInt`/`isSet`/string helpers, never `flags.get(k) = v`. Tested in Task 4 ("missing flag compares as 0/false").
2. **The same OK press both closing a dialogue and swinging the sword**, or an OK release re-opening the dialogue. `DialogueBox` acts on `input.press` only and calls `input.consume()`, and the player is paused while it's open. Tested on device in Task 11 (talk, close, check no swing). `talkBox` tests in Task 9 cover the geometry.
3. **A corrupt or old save crashing launch.** `validateSaveData` returns `invalid` for non-AA data, a wrong version, missing keys and wrong types, and clamps health. Tested in Task 7 ("rejects a string/array", "rejects a wrong type for coins").
4. **The gate opening in either order** (sword first, then Bram, or Bram first, then sword) without a loop. The `storyChanged` settle loop plus no-op `set` detection is tested in Task 6 for both orders, and against the depth limit.
5. **Rats spawning on top of the player**, or a sewer/town placement starting inside a solid. `RatSpawner` skips drains within 96px of the player (Task 14 test), and `EnemyPlacements.spec.bs` gains the sewer and every NPC placement (Task 13/14).

---

## File structure

**Engine (`src/source/engine/`)**
- Create `ui/TextWrap.bs`: `BGE.UI.wrapText()`.
- Create `ui/TextWrap.spec.bs`.
- Modify `ui/Label.bs`: `wrapWidth`.
- Modify `ui/Label.spec.bs`: wrapping cases.
- Modify `drawables/DrawableText.bs`: widest-line width, and the bitmap-reuse check.
- Modify `drawables/DrawableText.spec.bs`: multi-line and growth cases.

**Example story layer (`examples/rpg/src/source/Story/`)** (pure, engine-free)
- `StoryFlags.bs`: the blackboard.
- `Items.bs`: item definitions and `swordDamageFor()`.
- `Inventory.bs`: item counts.
- `Conditions.bs`: `evaluateConditions()`, `filterPlacements()`.
- `Effects.bs`: `applyEffects()`, `newStoryContext()`.
- `Text.bs`: `interpolateFlags()`.
- `DialogueData.bs`: every NPC's pages, and `selectDialoguePage()`.
- `EventRules.bs`: the rules, `runEventRules()`, `settleStory()`.
- `QuestData.bs`: the quests, and `currentObjectives()`.
- `ShopData.bs`: the price table, `canBuy()`, `canUse()`.
- `SaveData.bs`: `buildSaveData()`, `validateSaveData()`, `SAVE_VERSION`.
- `Checkpoints.bs`: `checkpointState(n)` for `--param stage=N`.
- `Story.bs`: the persistent coordinator entity. **Not** pure, and not in the test build.

**Example entities, UI, scenes**
- Create:
  - `Entities/NpcSheet.bs` (pure frame table)
  - `Entities/Npc.bs`
  - `Entities/Talk.bs` (pure `talkBox`/`nearestInBox`)
  - `World/RatSpawner.bs`, `World/Spawning.bs` (pure `pickDrain`)
  - `UI/MenuPanel.bs` (shared panel with action buttons)
  - `UI/DialogueBox.bs`, `UI/ShopPanel.bs`, `UI/InventoryPanel.bs`, `UI/SaveIndicator.bs`, `UI/TitleBackground.bs`
  - `Scenes/TitleScene.bs`, `Scenes/SewerScene.bs`
- Modify:
  - `Entities/Enemy.bs` (`hurt(amount)`, `enemyKilled`)
  - `Entities/Player.bs` (talk, `swordDamage`, save/load helpers)
  - `Scenes/AreaScene.bs` (gating, NPCs, inventory button, save on arrive)
  - `Scenes/TownScene.bs` (gate reload)
  - `Maps/MapData.bs` (new town, sewer, NPC/drain placements)
  - `Maps/Atlas.bs` (tunnel, ladder)
  - `UI/HeartsHud.bs` (only checks the player exists; already does)
  - `main.bs`
- Tests (`examples/rpg/tests/`):
  - Create `StoryFlags.spec.bs`, `Inventory.spec.bs`, `Conditions.spec.bs`, `Effects.spec.bs`, `DialogueData.spec.bs`, `EventRules.spec.bs`, `QuestData.spec.bs`, `Shop.spec.bs`, `SaveData.spec.bs`, `Talk.spec.bs`, `Spawning.spec.bs`.
  - Modify `TownGate.spec.bs`, `EnemyPlacements.spec.bs`.
  - `examples/rpg/bsconfig.test.json` gains every pure file.

**Assets**
- `examples/rpg/src/sprites/npcs.png` (prepared)
- `examples/rpg/src/sprites/items/potion.png`, `swordSteel.png`, `swordRusty.png`
- `examples/rpg/src/images/title.jpg`
- `CREDITS.md` entries

---

### Task 1: `BGE.UI.wrapText()`

**Files:**
- Create: `src/source/engine/ui/TextWrap.bs`
- Test: `src/source/engine/ui/TextWrap.spec.bs`

**Interfaces:**
- Produces: `BGE.UI.wrapText(text as string, font as object, maxWidth as float) as string[]`. `font` is an `roFont`, but it's typed `object` so a test can pass a fake with `GetOneLineWidth`. The result has no trailing spaces, and empty input gives `[""]`.

- [ ] **Step 1: Write the failing test**

```brighterscript
' src/source/engine/ui/TextWrap.spec.bs
namespace tests

  @suite("BGE.UI.wrapText")
  class TextWrapTests extends rooibos.BaseTestSuite

    game as BGE.Game
    font as object

    protected override function beforeEach()
      m.game = new BGE.Game(320, 240)
      m.font = m.game.getFont("default")
    end function

    private function widthOf(text as string) as float
      return m.font.GetOneLineWidth(text, 10000)
    end function

    @describe("wrapping")

    @it("returns one line when the text fits")
    function _()
      m.assertEqual(["hello world"], BGE.UI.wrapText("hello world", m.font, m.widthOf("hello world") + 1))
    end function

    @it("breaks at the last space that fits")
    function _()
      lines = BGE.UI.wrapText("hello world again", m.font, m.widthOf("hello world") + 1)
      m.assertEqual(["hello world", "again"], lines)
    end function

    @it("keeps existing newlines")
    function _()
      lines = BGE.UI.wrapText("one" + Chr(10) + "two", m.font, 10000)
      m.assertEqual(["one", "two"], lines)
    end function

    @it("breaks a word wider than maxWidth between characters")
    function _()
      maxWidth = m.widthOf("abcd") + 1
      lines = BGE.UI.wrapText("abcdefghij", m.font, maxWidth)
      m.assertTrue(lines.count() >= 3, "expected the long word split over at least 3 lines")
      m.assertEqual("abcdefghij", lines.join(""))
      for each line in lines
        m.assertTrue(m.widthOf(line) <= maxWidth, "line too wide: " + line)
      end for
    end function

    @it("only splits on newlines when maxWidth is 0 or less")
    function _()
      m.assertEqual(["a long line that would wrap"], BGE.UI.wrapText("a long line that would wrap", m.font, 0))
    end function

    @it("returns one empty line for empty text")
    function _()
      m.assertEqual([""], BGE.UI.wrapText("", m.font, 100))
    end function

    @it("drops the space at a wrap point")
    function _()
      lines = BGE.UI.wrapText("aa bb", m.font, m.widthOf("aa") + 1)
      m.assertEqual(["aa", "bb"], lines)
    end function

  end class

end namespace
```

- [ ] **Step 2: Run the tests to check they fail**

Run: `npm run test:ci`
Expected: a compile failure, `cannot find name 'wrapText'`.

- [ ] **Step 3: Implement**

```brighterscript
' src/source/engine/ui/TextWrap.bs
namespace BGE.UI

  ' Splits text into lines no wider than maxWidth when drawn in font. Existing newlines are kept,
  ' words are split on spaces, and a single word wider than maxWidth is broken between characters.
  '
  ' @param {string} text
  ' @param {roFont} font
  ' @param {float} maxWidth - in pixels. 0 or less means no wrapping (only split on newlines).
  ' @return {string[]} the lines, without trailing spaces
  function wrapText(text as string, font as object, maxWidth as float) as string[]
    result = []
    for each paragraph in text.split(Chr(10))
      if maxWidth <= 0
        result.push(paragraph)
      else
        BGE.UI.wrapParagraph(paragraph, font, maxWidth, result)
      end if
    end for
    if result.count() = 0
      result.push("")
    end if
    return result
  end function

  ' Wraps one newline-free paragraph onto the end of lines.
  sub wrapParagraph(paragraph as string, font as object, maxWidth as float, lines as object)
    line = ""
    for each word in paragraph.split(" ")
      if word = "" and line = ""
        continue for
      end if
      candidate = word
      if line <> ""
        candidate = line + " " + word
      end if
      if font.GetOneLineWidth(candidate, 10000) <= maxWidth
        line = candidate
      else
        if line <> ""
          lines.push(line)
        end if
        ' A word that alone is too wide is broken between characters.
        line = ""
        for i = 0 to word.len() - 1
          ch = word.mid(i, 1)
          if line <> "" and font.GetOneLineWidth(line + ch, 10000) > maxWidth
            lines.push(line)
            line = ""
          end if
          line = line + ch
        end for
      end if
    end for
    lines.push(line)
  end sub

end namespace
```

- [ ] **Step 4: Run the tests to check they pass**

Run: `npm run test:ci`
Expected: PASS. If `continue for` doesn't compile under bsc alpha.56, wrap the loop body in `if not (word = "" and line = "")` instead.

- [ ] **Step 5: Lint, validate, commit**

```bash
npm run lint && npm run validate
git add src/source/engine/ui/TextWrap.bs src/source/engine/ui/TextWrap.spec.bs
git commit -m "Add BGE.UI.wrapText() (#257)"
```

### Task 2: Multi-line `DrawableText` sizing, and `Label.wrapWidth`

**Files:**
- Modify: `src/source/engine/drawables/DrawableText.bs` (`getTextImage()`, around lines 70-80)
- Modify: `src/source/engine/ui/Label.bs`
- Test: `src/source/engine/drawables/DrawableText.spec.bs`, `src/source/engine/ui/Label.spec.bs`
- Docs: `CLAUDE.md` (UI section)

**Interfaces:**
- Consumes: `BGE.UI.wrapText` (Task 1).
- Produces: `BGE.UI.Label.wrapWidth as float = 0`. After `draw()`, `label.width`/`label.height` are the wrapped size.

- [ ] **Step 1: Write the failing DrawableText tests** (add a new `@describe` to the existing suite)

```brighterscript
    @describe("multi-line text")

    @it("is as wide as its widest line, not the whole string")
    function _()
      font = m.game.getFont("default")
      text = m.newText("short" + Chr(10) + "a much longer line")
      text.getTextImage()
      m.assertEqual(font.GetOneLineWidth("a much longer line", 10000), text.width)
      m.assertEqual(font.GetOneLineHeight() * 2, text.height)
    end function

    @it("still draws after the text grows wider than before")
    function _()
      text = m.newText("hi")
      m.assertNotInvalid(text.getTextImage())
      text.text = "a much, much longer piece of text than before"
      region = text.getTextImage()
      m.assertNotInvalid(region)
      m.assertEqual(text.width, region.GetWidth())
    end function
```

`text.width` and `text.height` may be Integer or Float depending on what `GetOneLineWidth` returns. If `assertEqual` fails on type, read the failure's printed types and cast the expected side to match.

- [ ] **Step 2: Run the tests to check they fail**

Run: `npm run test:ci`
Expected: FAIL. Width equals the whole string's width, and the grown text returns `invalid` (or a region narrower than `text.width`).

- [ ] **Step 3: Fix `getTextImage()`**

Replace the width line and the reuse check:

```brighterscript
      m.width = 0
      for each textLine in m.text.split(Chr(10))
        lineWidth = m.font.GetOneLineWidth(textLine, 10000)
        if lineWidth > m.width
          m.width = lineWidth
        end if
      end for
      m.height = m.font.GetOneLineHeight() * BGE.getNumberOfLinesInAString(m.text)

      ' Reuses the bitmap while the text still fits in it.
      if m.tempCanvas = invalid or m.width + 1 > m.tempCanvas.GetWidth() or m.height + 1 > m.tempCanvas.GetHeight()
```

- [ ] **Step 4: Write the failing Label tests** (add to `Label.spec.bs`'s suite)

```brighterscript
    @describe("wrapWidth")

    @it("wraps the text onto several lines when wrapWidth is set")
    function _()
      font = m.label.drawableText.font
      m.label.wrapWidth = font.GetOneLineWidth("hello world", 10000) + 1
      m.label.setText("hello world hello world")
      m.label.draw()
      m.assertEqual("hello world" + Chr(10) + "hello world", m.label.drawableText.text)
      m.assertEqual(font.GetOneLineHeight() * 2, m.label.height)
    end function

    @it("leaves text alone when wrapWidth is 0")
    function _()
      m.label.setText("hello world hello world")
      m.label.draw()
      m.assertEqual("hello world hello world", m.label.drawableText.text)
    end function

    @it("re-wraps the original text when wrapWidth changes")
    function _()
      font = m.label.drawableText.font
      m.label.wrapWidth = font.GetOneLineWidth("hello", 10000) + 1
      m.label.setText("hello world")
      m.label.draw()
      m.label.wrapWidth = 0
      m.label.draw()
      m.assertEqual("hello world", m.label.drawableText.text)
    end function
```

- [ ] **Step 5: Run the tests to check they fail**

Run: `npm run test:ci`
Expected: a compile failure on `wrapWidth`.

- [ ] **Step 6: Implement `wrapWidth`**

```brighterscript
' src/source/engine/ui/Label.bs
import "../drawables/DrawableText.bs"
import "../Game.bs"
import "UiWidget.bs"
import "TextWrap.bs"

namespace BGE.UI

  class Label extends UiWidget

    drawableText as BGE.DrawableText

    ' Width in pixels to wrap the text at. 0 (the default) means no wrapping.
    wrapWidth as float = 0

    private rawText as string = ""
    private wrapped as boolean = false
    private lastWrapWidth as float = -1
    ' roFonts can't be compared with =, so a font change is spotted by its line height.
    private lastWrapFontHeight as integer = -1

    sub new(game as BGE.Game)
      super(game)
      m.drawableText = new BGE.DrawableText(m)
    end sub

    sub setText(text = "" as string)
      m.rawText = text
      m.drawableText.text = text
      m.lastWrapWidth = -1
    end sub

    override sub draw(parent = invalid as UiWidget)
      if invalid <> m.drawableText
        m.applyThemeFont(m.resolveTheme(parent), m.drawableText)
        m.updateWrapping()
        m.drawableText.alignment = m.horizAlign as BGE.UI.HorizAlignment
        textImage = m.drawableText.getTextImage()
        if textImage <> invalid
          m.canvas.renderer.drawTransformedObject(m.position.x, m.position.y, m.scale.x, m.scale.y, m.rotation.y, textImage)
        end if
        size = m.drawableText.getDrawnSize()
        m.width = size.width
        m.height = size.height
      end if
    end sub

    private sub updateWrapping()
      if m.wrapWidth <= 0
        if m.wrapped
          m.drawableText.text = m.rawText
          m.wrapped = false
        end if
        return
      end if
      fontHeight = m.drawableText.font.GetOneLineHeight()
      if m.wrapped and m.lastWrapWidth = m.wrapWidth and m.lastWrapFontHeight = fontHeight
        return
      end if
      m.drawableText.text = BGE.UI.wrapText(m.rawText, m.drawableText.font, m.wrapWidth).join(Chr(10))
      m.wrapped = true
      m.lastWrapWidth = m.wrapWidth
      m.lastWrapFontHeight = fontHeight
    end sub

  end class
end namespace
```

`m.wrapped` only becomes true through `wrapWidth`, so code that writes `drawableText.text` directly with `wrapWidth = 0` (a few widgets do) is unaffected.

- [ ] **Step 7: Run the tests to check they pass**

Run: `npm run check`
Expected: lint, validate and every test pass.

- [ ] **Step 8: Docs**

In `CLAUDE.md`'s `### UI (engine/ui/)` section, add a bullet:

```markdown
- **Word wrapping**: `BGE.UI.Label.wrapWidth` (px, 0 = off) wraps a label's text on spaces, breaking an over-long word between characters. `BGE.UI.wrapText(text, font, maxWidth)` (`ui/TextWrap.bs`) returns the wrapped lines, for paging text yourself (e.g. a dialogue box). `DrawableText` sizes multi-line text by its widest line.
```

Then `grep -rn "Label" docs/*.md`. If a guide documents `Label`'s fields, add one sentence about `wrapWidth` there.

- [ ] **Step 9: Commit**

```bash
git add src/source/engine/drawables/DrawableText.bs src/source/engine/drawables/DrawableText.spec.bs src/source/engine/ui/Label.bs src/source/engine/ui/Label.spec.bs CLAUDE.md docs
git commit -m "Add Label.wrapWidth, fix DrawableText multi-line sizing (#257)"
```

### Task 3: `StoryFlags`, items and `Inventory`

**Files:**
- Create: `examples/rpg/src/source/Story/StoryFlags.bs`, `Story/Items.bs`, `Story/Inventory.bs`
- Test: `examples/rpg/tests/StoryFlags.spec.bs`, `examples/rpg/tests/Inventory.spec.bs`
- Modify: `examples/rpg/bsconfig.test.json` (add `"source/Story/StoryFlags.bs"`, `"source/Story/Items.bs"`, `"source/Story/Inventory.bs"` to `files`)

**Interfaces:**
- Produces:
  - `class StoryFlags`:
    - `get(key) as dynamic`, `getInt(key) as integer`, `isSet(key) as boolean`
    - `set(key, value) as boolean` (true if the value changed)
    - `add(key, amount as integer) as boolean`
    - `toAA() as object`, `loadAA(data as object)`, `clear()`
  - `getItemDefinitions() as object` (id → `{name, icon, max, onAcquire?, onUse?}`) and `swordDamageFor(inventory as Inventory) as integer`.
  - `class Inventory`:
    - `count(id) as integer`, `has(id) as boolean`, `canAdd(id) as boolean`
    - `add(id) as boolean`, `remove(id) as boolean`
    - `toAA() as object`, `loadAA(data as object)`, `clear()`

- [ ] **Step 1: Write the failing tests**

```brighterscript
' examples/rpg/tests/StoryFlags.spec.bs
namespace tests
  @suite("StoryFlags")
  class StoryFlagsTests extends rooibos.BaseTestSuite

    private flags as StoryFlags

    protected override function beforeEach()
      m.flags = new StoryFlags()
    end function

    @describe("reading and writing")

    @it("reads a missing key as invalid, 0 and not set")
    function _()
      m.assertInvalid(m.flags.get("rats.stage"))
      m.assertEqual(0, m.flags.getInt("rats.stage"))
      m.assertFalse(m.flags.isSet("rats.stage"))
    end function

    @it("reports whether set() changed anything")
    function _()
      m.assertTrue(m.flags.set("rats.stage", 1))
      m.assertFalse(m.flags.set("rats.stage", 1))
      m.assertTrue(m.flags.set("rats.stage", 2))
    end function

    @it("adds to a missing key from 0")
    function _()
      m.assertTrue(m.flags.add("rats.kills", 1))
      m.flags.add("rats.kills", 2)
      m.assertEqual(3, m.flags.getInt("rats.kills"))
    end function

    @it("treats true, non-zero and non-empty values as set")
    function _()
      m.flags.set("a", true)
      m.flags.set("b", 0)
      m.flags.set("c", "x")
      m.flags.set("d", false)
      m.assertTrue(m.flags.isSet("a"))
      m.assertFalse(m.flags.isSet("b"))
      m.assertTrue(m.flags.isSet("c"))
      m.assertFalse(m.flags.isSet("d"))
    end function

    @it("is case-sensitive")
    function _()
      m.flags.set("Gate.open", true)
      m.assertFalse(m.flags.isSet("gate.open"))
    end function

    @it("round-trips through toAA and loadAA")
    function _()
      m.flags.set("rats.stage", 2)
      m.flags.set("gate.open", true)
      copy = new StoryFlags()
      copy.loadAA(ParseJson(FormatJson(m.flags.toAA())))
      m.assertEqual(2, copy.getInt("rats.stage"))
      m.assertTrue(copy.isSet("gate.open"))
    end function

  end class
end namespace
```

```brighterscript
' examples/rpg/tests/Inventory.spec.bs
namespace tests
  @suite("Inventory")
  class InventoryTests extends rooibos.BaseTestSuite

    private inventory as Inventory

    protected override function beforeEach()
      m.inventory = new Inventory(getItemDefinitions())
    end function

    @describe("counts")

    @it("starts empty")
    function _()
      m.assertEqual(0, m.inventory.count("potion"))
      m.assertFalse(m.inventory.has("potion"))
    end function

    @it("stops at an item's max")
    function _()
      m.assertTrue(m.inventory.add("potion"))
      m.assertTrue(m.inventory.add("potion"))
      m.assertTrue(m.inventory.add("potion"))
      m.assertFalse(m.inventory.canAdd("potion"))
      m.assertFalse(m.inventory.add("potion"))
      m.assertEqual(3, m.inventory.count("potion"))
    end function

    @it("won't remove what it doesn't have")
    function _()
      m.assertFalse(m.inventory.remove("potion"))
      m.inventory.add("potion")
      m.assertTrue(m.inventory.remove("potion"))
      m.assertEqual(0, m.inventory.count("potion"))
    end function

    @it("refuses an unknown item")
    function _()
      m.assertFalse(m.inventory.add("banana"))
    end function

    @it("round-trips through toAA and loadAA")
    function _()
      m.inventory.add("steelSword")
      copy = new Inventory(getItemDefinitions())
      copy.loadAA(ParseJson(FormatJson(m.inventory.toAA())))
      m.assertTrue(copy.has("steelSword"))
    end function

    @describe("swordDamageFor")

    @it("is 1 with the rusty sword and 2 with the steel sword")
    function _()
      m.assertEqual(1, swordDamageFor(m.inventory))
      m.inventory.add("steelSword")
      m.assertEqual(2, swordDamageFor(m.inventory))
    end function

  end class
end namespace
```

- [ ] **Step 2: Run the tests to check they fail**

Run: `cd examples/rpg && npm test`
Expected: a compile failure (`StoryFlags`/`Inventory` not found).

- [ ] **Step 3: Implement**

```brighterscript
' examples/rpg/src/source/Story/StoryFlags.bs

' The story's blackboard: a flat set of named values (booleans, integers, strings). Quest
' progress, who you've talked to, whether the gate is open - all keys here, set by story data.
class StoryFlags

  private values as object = invalid

  sub new()
    m.clear()
  end sub

  sub clear()
    m.values = {}
    m.values.SetModeCaseSensitive()
  end sub

  function get(key as string) as dynamic
    return m.values[key]
  end function

  ' A missing or non-integer value reads as 0.
  function getInt(key as string) as integer
    value = m.values[key]
    valueType = type(value)
    if valueType = "Integer" or valueType = "roInt" or valueType = "LongInteger"
      return value
    end if
    if valueType = "Float" or valueType = "Double" or valueType = "roFloat"
      return Int(value)
    end if
    return 0
  end function

  ' True for true, a non-zero number, or a non-empty string.
  function isSet(key as string) as boolean
    value = m.values[key]
    valueType = type(value)
    if valueType = "Boolean" or valueType = "roBoolean"
      return value
    end if
    if valueType = "String" or valueType = "roString"
      return value <> ""
    end if
    return m.getInt(key) <> 0
  end function

  ' @return {boolean} true if the stored value changed
  function set(key as string, value as dynamic) as boolean
    if m.values.DoesExist(key) and type(m.values[key]) = type(value)
      if m.values[key] = value
        return false
      end if
    end if
    m.values[key] = value
    return true
  end function

  ' @return {boolean} true if the stored value changed
  function add(key as string, amount as integer) as boolean
    return m.set(key, m.getInt(key) + amount)
  end function

  function toAA() as object
    copy = {}
    copy.SetModeCaseSensitive()
    copy.Append(m.values)
    return copy
  end function

  sub loadAA(data as object)
    m.clear()
    if type(data) = "roAssociativeArray"
      for each key in data
        m.values[key] = data[key]
      end for
    end if
  end sub

end class
```

`type()` returns `"Integer"` vs `"roInt"` depending on boxing. Checking both keeps `getInt` safe for values that came back from `ParseJson`. `Append` keeps keys' case only when the target AA is case-sensitive, which is why `copy` is made case-sensitive first.

```brighterscript
' examples/rpg/src/source/Story/Items.bs

' Everything the player can carry. `max` caps how many; `onAcquire`/`onUse` are effect lists
' (see Effects.bs) run when one is gained or used.
'
' @return {object} item id -> {name, icon, max, onAcquire?, onUse?}
function getItemDefinitions() as object
  globals = GetGlobalAA()
  if globals.rpgItems = invalid
    globals.rpgItems = {
      steelSword: {name: "Steel sword", icon: "swordSteel", max: 1},
      heartContainer: {name: "Heart container", icon: "heartIcon", max: 1, onAcquire: [{addMaxHealth: 2}, {heal: 2}]},
      potion: {name: "Healing potion", icon: "potion", max: 3, onUse: [{heal: 4}]}
    }
  end if
  return globals.rpgItems
end function

' The sword's damage per hit: 2 with the steel sword, otherwise 1.
'
' @param {Inventory} inventory
' @return {integer}
function swordDamageFor(inventory as object) as integer
  if inventory.has("steelSword")
    return 2
  end if
  return 1
end function
```

```brighterscript
' examples/rpg/src/source/Story/Inventory.bs
import "Items.bs"

' What the player is carrying: item id -> count, capped by each item's definition.
class Inventory

  private counts as object = {}
  private definitions as object = invalid

  ' @param {object} definitions - getItemDefinitions()
  sub new(definitions as object)
    m.definitions = definitions
    m.clear()
  end sub

  sub clear()
    m.counts = {}
  end sub

  function count(id as string) as integer
    if m.counts.DoesExist(id)
      return m.counts[id]
    end if
    return 0
  end function

  function has(id as string) as boolean
    return m.count(id) > 0
  end function

  function canAdd(id as string) as boolean
    definition = m.definitions[id]
    return definition <> invalid and m.count(id) < definition.max
  end function

  function add(id as string) as boolean
    if not m.canAdd(id)
      return false
    end if
    m.counts[id] = m.count(id) + 1
    return true
  end function

  function remove(id as string) as boolean
    if not m.has(id)
      return false
    end if
    m.counts[id] = m.count(id) - 1
    return true
  end function

  function toAA() as object
    copy = {}
    copy.Append(m.counts)
    return copy
  end function

  sub loadAA(data as object)
    m.clear()
    if type(data) <> "roAssociativeArray"
      return
    end if
    for each id in data
      if m.definitions[id] <> invalid and (type(data[id]) = "Integer" or type(data[id]) = "roInt")
        m.counts[id] = data[id]
      end if
    end for
  end sub

end class
```

- [ ] **Step 4: Run the tests to check they pass**

Run: `cd examples/rpg && npm test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add examples/rpg/src/source/Story examples/rpg/tests/StoryFlags.spec.bs examples/rpg/tests/Inventory.spec.bs examples/rpg/bsconfig.test.json
git commit -m "rpg: add StoryFlags and Inventory (#257)"
```

### Task 4: Conditions and effects

**Files:**
- Create: `examples/rpg/src/source/Story/Conditions.bs`, `Story/Effects.bs`
- Test: `examples/rpg/tests/Conditions.spec.bs`, `examples/rpg/tests/Effects.spec.bs`
- Modify: `examples/rpg/bsconfig.test.json` (add both files)

**Interfaces:**
- Consumes: `StoryFlags`, `Inventory`, `getItemDefinitions()` (Task 3).
- Produces:
  - `newStoryContext(flags as StoryFlags, inventory as Inventory, player as object) as object`. Returns `{flags, inventory, player, items}`. `player` is anything with `health`, `maxHealth`, `coins` fields (the `Player` entity, or a plain AA in tests).
  - `evaluateConditions(conditions as dynamic, ctx as object) as boolean`. `invalid` or `[]` passes.
  - `filterPlacements(placements as object, ctx as object) as object`. Keeps items whose `when` passes.
  - `applyEffects(effects as dynamic, ctx as object) as object`. Returns `{changed as boolean, posts as object}` (posts is a string array).

- [ ] **Step 1: Write the failing tests**

```brighterscript
' examples/rpg/tests/Conditions.spec.bs
namespace tests
  @suite("story conditions")
  class ConditionsTests extends rooibos.BaseTestSuite

    private ctx as object

    protected override function beforeEach()
      m.ctx = newStoryContext(new StoryFlags(), new Inventory(getItemDefinitions()), {health: 6, maxHealth: 6, coins: 5})
    end function

    @describe("evaluateConditions")

    @it("passes an empty or missing list")
    function _()
      m.assertTrue(evaluateConditions([], m.ctx))
      m.assertTrue(evaluateConditions(invalid, m.ctx))
    end function

    @it("compares a missing flag as 0/false")
    function _()
      m.assertTrue(evaluateConditions([{flag: "rats.stage", eq: 0}], m.ctx))
      m.assertFalse(evaluateConditions([{flag: "rats.stage", eq: 2}], m.ctx))
      m.assertTrue(evaluateConditions([{flag: "gate.open", eq: false}], m.ctx))
      m.assertTrue(evaluateConditions([{flag: "rats.stage", lt: 1}], m.ctx))
    end function

    @it("checks eq, gte and lt on a set flag")
    function _()
      m.ctx.flags.set("rats.kills", 3)
      m.assertTrue(evaluateConditions([{flag: "rats.kills", eq: 3}], m.ctx))
      m.assertTrue(evaluateConditions([{flag: "rats.kills", gte: 3}], m.ctx))
      m.assertFalse(evaluateConditions([{flag: "rats.kills", gte: 4}], m.ctx))
      m.assertFalse(evaluateConditions([{flag: "rats.kills", lt: 3}], m.ctx))
    end function

    @it("checks a flag on its own and notFlag")
    function _()
      m.assertFalse(evaluateConditions([{flag: "bram.vouched"}], m.ctx))
      m.assertTrue(evaluateConditions([{notFlag: "bram.vouched"}], m.ctx))
      m.ctx.flags.set("bram.vouched", true)
      m.assertTrue(evaluateConditions([{flag: "bram.vouched"}], m.ctx))
    end function

    @it("checks items and coins")
    function _()
      m.assertTrue(evaluateConditions([{notItem: "steelSword"}], m.ctx))
      m.ctx.inventory.add("steelSword")
      m.assertTrue(evaluateConditions([{hasItem: "steelSword"}], m.ctx))
      m.assertTrue(evaluateConditions([{coinsGte: 5}], m.ctx))
      m.assertFalse(evaluateConditions([{coinsGte: 6}], m.ctx))
    end function

    @it("needs every condition to pass")
    function _()
      m.ctx.flags.set("bram.vouched", true)
      m.assertFalse(evaluateConditions([{flag: "bram.vouched"}, {hasItem: "steelSword"}], m.ctx))
    end function

    @it("fails an unknown condition")
    function _()
      m.assertFalse(evaluateConditions([{flagg: "rats.stage"}], m.ctx))
    end function

    @describe("filterPlacements")

    @it("drops placements whose when fails, keeps ones with no when")
    function _()
      placements = [{type: "npc", id: "knight", when: [{notFlag: "gate.open"}]}, {type: "spawn", id: "gate"}]
      m.assertEqual(2, filterPlacements(placements, m.ctx).count())
      m.ctx.flags.set("gate.open", true)
      kept = filterPlacements(placements, m.ctx)
      m.assertEqual(1, kept.count())
      m.assertEqual("spawn", kept[0].type)
    end function

  end class
end namespace
```

```brighterscript
' examples/rpg/tests/Effects.spec.bs
namespace tests
  @suite("story effects")
  class EffectsTests extends rooibos.BaseTestSuite

    private ctx as object

    protected override function beforeEach()
      m.ctx = newStoryContext(new StoryFlags(), new Inventory(getItemDefinitions()), {health: 3, maxHealth: 6, coins: 5})
    end function

    @describe("applyEffects")

    @it("sets and adds flags, reporting a change")
    function _()
      result = applyEffects([{set: "rats.stage", value: 1}, {add: "rats.kills", amount: 2}], m.ctx)
      m.assertTrue(result.changed)
      m.assertEqual(1, m.ctx.flags.getInt("rats.stage"))
      m.assertEqual(2, m.ctx.flags.getInt("rats.kills"))
    end function

    @it("reports no change for a set that writes the current value")
    function _()
      m.ctx.flags.set("rats.stage", 1)
      m.assertFalse(applyEffects([{set: "rats.stage", value: 1}], m.ctx).changed)
    end function

    @it("gives coins and never takes below 0")
    function _()
      applyEffects([{giveCoins: 10}], m.ctx)
      m.assertEqual(15, m.ctx.player.coins)
      applyEffects([{takeCoins: 100}], m.ctx)
      m.assertEqual(0, m.ctx.player.coins)
    end function

    @it("heals up to maxHealth")
    function _()
      applyEffects([{heal: 10}], m.ctx)
      m.assertEqual(6, m.ctx.player.health)
    end function

    @it("runs an item's onAcquire when it's given")
    function _()
      result = applyEffects([{giveItem: "heartContainer"}], m.ctx)
      m.assertTrue(result.changed)
      m.assertTrue(m.ctx.inventory.has("heartContainer"))
      m.assertEqual(8, m.ctx.player.maxHealth)
      m.assertEqual(5, m.ctx.player.health)
    end function

    @it("takes an item")
    function _()
      m.ctx.inventory.add("potion")
      applyEffects([{takeItem: "potion"}], m.ctx)
      m.assertEqual(0, m.ctx.inventory.count("potion"))
    end function

    @it("returns posted event names in order")
    function _()
      result = applyEffects([{post: "gateOpened"}, {post: "other"}], m.ctx)
      m.assertEqual(["gateOpened", "other"], result.posts)
    end function

    @it("does nothing with an empty or missing list")
    function _()
      m.assertFalse(applyEffects(invalid, m.ctx).changed)
      m.assertEqual(0, applyEffects([], m.ctx).posts.count())
    end function

  end class
end namespace
```

- [ ] **Step 2: Run the tests to check they fail**

Run: `cd examples/rpg && npm test`
Expected: a compile failure.

- [ ] **Step 3: Implement**

```brighterscript
' examples/rpg/src/source/Story/Conditions.bs
import "StoryFlags.bs"
import "Inventory.bs"

' Story data's "when" lists. Every condition must pass; an empty or missing list passes.
' Conditions: {flag, eq|gte|lt}, {flag}, {notFlag}, {hasItem}, {notItem}, {coinsGte}.
'
' @param {object} conditions - array of condition AAs, or invalid
' @param {object} ctx - newStoryContext()
' @return {boolean}
function evaluateConditions(conditions as dynamic, ctx as object) as boolean
  if conditions = invalid
    return true
  end if
  for each condition in conditions
    if not conditionPasses(condition, ctx)
      return false
    end if
  end for
  return true
end function

' Never compares a stored flag with = directly - a missing one is invalid, and invalid = 2 can crash.
function conditionPasses(condition as object, ctx as object) as boolean
  flags = ctx.flags
  if condition.DoesExist("flag")
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
    return ctx.inventory.has(condition.hasItem)
  else if condition.DoesExist("notItem")
    return not ctx.inventory.has(condition.notItem)
  else if condition.DoesExist("coinsGte")
    return ctx.player.coins >= condition.coinsGte
  end if
  print "[rpg] warning: unknown story condition " + FormatJson(condition)
  return false
end function

function flagEquals(flags as object, key as string, expected as dynamic) as boolean
  expectedType = type(expected)
  if expectedType = "Boolean" or expectedType = "roBoolean"
    return flags.isSet(key) = expected
  end if
  if expectedType = "String" or expectedType = "roString"
    value = flags.get(key)
    valueType = type(value)
    if valueType <> "String" and valueType <> "roString"
      return expected = ""
    end if
    return value = expected
  end if
  return flags.getInt(key) = expected
end function

' The placements whose optional `when` passes - e.g. the gate's knight only while it's shut.
'
' @param {object} placements - map placement AAs
' @param {object} ctx
' @return {object} the kept placements, in order
function filterPlacements(placements as object, ctx as object) as object
  kept = []
  for each item in placements
    if evaluateConditions(item.when, ctx)
      kept.push(item)
    end if
  end for
  return kept
end function
```

```brighterscript
' examples/rpg/src/source/Story/Effects.bs
import "StoryFlags.bs"
import "Inventory.bs"
import "Items.bs"

' Everything story data reads and changes.
'
' @param {StoryFlags} flags
' @param {Inventory} inventory
' @param {object} player - has health, maxHealth and coins (the Player entity, or a plain AA in tests)
' @return {object} {flags, inventory, player, items}
function newStoryContext(flags as object, inventory as object, player as object) as object
  return {flags: flags, inventory: inventory, player: player, items: getItemDefinitions()}
end function

' Applies story data's "effects" lists in order. Effects: {set, value}, {add, amount},
' {giveItem}, {takeItem}, {giveCoins}, {takeCoins}, {heal}, {addMaxHealth}, {post}.
'
' @param {object} effects - array of effect AAs, or invalid
' @param {object} ctx - newStoryContext()
' @return {object} {changed: whether any state changed, posts: event names to post, in order}
function applyEffects(effects as dynamic, ctx as object) as object
  result = {changed: false, posts: []}
  if effects = invalid
    return result
  end if
  for each effect in effects
    if applyEffect(effect, ctx, result)
      result.changed = true
    end if
  end for
  return result
end function

function applyEffect(effect as object, ctx as object, result as object) as boolean
  player = ctx.player
  if effect.DoesExist("set")
    return ctx.flags.set(effect.set, effect.value)
  else if effect.DoesExist("add")
    return ctx.flags.add(effect.add, effect.amount)
  else if effect.DoesExist("giveItem")
    if not ctx.inventory.add(effect.giveItem)
      return false
    end if
    applyEffects(ctx.items[effect.giveItem].onAcquire, ctx)
    return true
  else if effect.DoesExist("takeItem")
    return ctx.inventory.remove(effect.takeItem)
  else if effect.DoesExist("giveCoins")
    player.coins += effect.giveCoins
    return effect.giveCoins <> 0
  else if effect.DoesExist("takeCoins")
    before = player.coins
    player.coins -= effect.takeCoins
    if player.coins < 0
      player.coins = 0
    end if
    return before <> player.coins
  else if effect.DoesExist("heal")
    before = player.health
    player.health += effect.heal
    if player.health > player.maxHealth
      player.health = player.maxHealth
    end if
    return before <> player.health
  else if effect.DoesExist("addMaxHealth")
    player.maxHealth += effect.addMaxHealth
    return true
  else if effect.DoesExist("post")
    result.posts.push(effect.post)
    return false
  end if
  print "[rpg] warning: unknown story effect " + FormatJson(effect)
  return false
end function
```

- [ ] **Step 4: Run the tests to check they pass**

Run: `cd examples/rpg && npm test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add examples/rpg/src/source/Story examples/rpg/tests/Conditions.spec.bs examples/rpg/tests/Effects.spec.bs examples/rpg/bsconfig.test.json
git commit -m "rpg: add story conditions and effects (#257)"
```

### Task 5: Dialogue pages, flag interpolation, quest log

**Files:**
- Create: `examples/rpg/src/source/Story/Text.bs`, `Story/DialogueData.bs`, `Story/QuestData.bs`, `Story/Checkpoints.bs`
- Test: `examples/rpg/tests/DialogueData.spec.bs`, `examples/rpg/tests/QuestData.spec.bs`
- Modify: `examples/rpg/bsconfig.test.json` (add the four files)

**Interfaces:**
- Consumes: `evaluateConditions`, `newStoryContext` (Task 4).
- Produces:
  - `interpolateFlags(text as string, flags as StoryFlags) as string`. Replaces `${key}` with the flag's value (missing → `0`).
  - `getDialogueData() as object`. Maps NPC id → array of pages `{when?, speaker, lines as string[], effects?, choices?}`. A choice is `{label, effects?, open?}`; `open` is `"shop"` or omitted.
  - `selectDialoguePage(pages as object, ctx as object) as dynamic`. Returns the first page whose `when` passes, or `invalid`.
  - `getQuestData() as object`. An array of `{id, title, stageFlag, stages: {"1": text, ...}}`.
  - `currentObjectives(quests as object, flags as StoryFlags) as object`. Returns interpolated objective strings, in quest order.
  - NPC ids used everywhere: `bram`, `knight`, `hilde`, `wanderPlaza`, `wanderMarket`, `child`, `oldWoman`.
  - `checkpointState(n as integer) as object`. Returns `{flags as StoryFlags, inventory as Inventory, coins as integer}` for story checkpoint 0-4.

- [ ] **Step 1: Write the failing tests**

```brighterscript
' examples/rpg/tests/DialogueData.spec.bs
namespace tests
  @suite("dialogue data")
  class DialogueDataTests extends rooibos.BaseTestSuite

    private ctx as object

    protected override function beforeEach()
      m.ctx = newStoryContext(new StoryFlags(), new Inventory(getItemDefinitions()), {health: 6, maxHealth: 6, coins: 0})
    end function

    private function pageFor(npcId as string) as object
      return selectDialoguePage(getDialogueData()[npcId], m.ctx)
    end function

    @describe("Elder Bram")

    @it("gives the quest on a new game")
    function _()
      page = m.pageFor("bram")
      m.assertEqual("Elder Bram", page.speaker)
      applyEffects(page.effects, m.ctx)
      m.assertEqual(1, m.ctx.flags.getInt("rats.stage"))
    end function

    @it("reports progress while hunting")
    function _()
      m.ctx.flags.set("rats.stage", 1)
      m.ctx.flags.set("rats.kills", 2)
      page = m.pageFor("bram")
      m.assertInvalid(page.effects)
      m.assertEqual("Still rats about. 2 of 4 so far.", interpolateFlags(page.lines[0], m.ctx.flags))
    end function

    @it("rewards and vouches when the rats are dealt with")
    function _()
      m.ctx.flags.set("rats.stage", 2)
      page = m.pageFor("bram")
      result = applyEffects(page.effects, m.ctx)
      m.assertTrue(result.changed)
      m.assertEqual(10, m.ctx.player.coins)
      m.assertEqual(3, m.ctx.flags.getInt("rats.stage"))
      m.assertTrue(m.ctx.flags.isSet("bram.vouched"))
    end function

    @it("points at the sewer once the quest is done")
    function _()
      m.ctx.flags.set("rats.stage", 3)
      m.assertTrue(Instr(1, m.pageFor("bram").lines[0], "sewer") > 0)
    end function

    @describe("the gate knight")

    @it("turns you away before Bram vouches")
    function _()
      m.assertTrue(Instr(1, m.pageFor("knight").lines[0], "No one goes in") > 0)
    end function

    @it("wants a better sword once Bram vouches")
    function _()
      m.ctx.flags.set("bram.vouched", true)
      m.assertTrue(Instr(1, m.pageFor("knight").lines[0], "rusty blade") > 0)
    end function

    @describe("Merchant Hilde")

    @it("ends with a shop choice")
    function _()
      page = m.pageFor("hilde")
      m.assertEqual("shop", page.choices[0].open)
      m.assertEqual("Leave", page.choices[1].label)
    end function

    @describe("every NPC")

    @it("has a page for every story checkpoint")
    @params(0)
    @params(1)
    @params(2)
    @params(3)
    @params(4)
    function _(checkpoint)
      state = checkpointState(checkpoint)
      ctx = newStoryContext(state.flags, state.inventory, {health: 6, maxHealth: 6, coins: state.coins})
      data = getDialogueData()
      for each npcId in ["bram", "knight", "hilde", "wanderPlaza", "wanderMarket", "child", "oldWoman"]
        m.assertNotInvalid(selectDialoguePage(data[npcId], ctx), npcId + " has no page at checkpoint " + checkpoint.toStr())
      end for
    end function

    @describe("interpolateFlags")

    @it("replaces several keys and reads a missing one as 0")
    function _()
      flags = new StoryFlags()
      flags.set("a", 3)
      m.assertEqual("3 and 0", interpolateFlags("${a} and ${b}", flags))
    end function

    @it("leaves an unclosed ${ alone")
    function _()
      m.assertEqual("x ${a", interpolateFlags("x ${a", new StoryFlags()))
    end function

  end class
end namespace
```

`checkpointState` comes from `Checkpoints.bs`, which this task creates (Step 3).

```brighterscript
' examples/rpg/tests/QuestData.spec.bs
namespace tests
  @suite("quest log")
  class QuestDataTests extends rooibos.BaseTestSuite

    @describe("currentObjectives")

    @it("has nothing on a new game")
    function _()
      m.assertEqual(0, currentObjectives(getQuestData(), new StoryFlags()).count())
    end function

    @it("shows the rat count while hunting")
    function _()
      flags = new StoryFlags()
      flags.set("rats.stage", 1)
      flags.set("rats.kills", 3)
      m.assertEqual(["Kill rats (3/4)"], currentObjectives(getQuestData(), flags))
    end function

    @it("lists the gate after the rats are done")
    function _()
      flags = new StoryFlags()
      flags.set("rats.stage", 3)
      flags.set("gate.stage", 1)
      m.assertEqual(["Buy a better sword from Hilde"], currentObjectives(getQuestData(), flags))
    end function

  end class
end namespace
```

- [ ] **Step 2: Run the tests to check they fail**

Run: `cd examples/rpg && npm test`
Expected: a compile failure.

- [ ] **Step 3: Implement**

```brighterscript
' examples/rpg/src/source/Story/Text.bs
import "StoryFlags.bs"

' Replaces each ${key} in text with that flag's value (a missing flag reads as 0).
'
' @param {string} text
' @param {StoryFlags} flags
' @return {string}
function interpolateFlags(text as string, flags as object) as string
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
    if value = invalid
      valueText = "0"
    else if type(value) = "String" or type(value) = "roString"
      valueText = value
    else
      valueText = value.toStr()
    end if
    result = result + Left(rest, start - 1) + valueText
    rest = Mid(rest, finish + 1)
  end while
  return result
end function
```

```brighterscript
' examples/rpg/src/source/Story/DialogueData.bs
import "Conditions.bs"

' Who says what. Each NPC has pages in priority order; the first whose `when` passes is the
' one used, so put the most specific first. A page's `effects` run once its last line is read
' (not if the player backs out). `choices` end the page with buttons.
'
' @return {object} npc id -> page array
function getDialogueData() as object
  globals = GetGlobalAA()
  if globals.rpgDialogue <> invalid
    return globals.rpgDialogue
  end if
  globals.rpgDialogue = {
    bram: [
      {when: [{flag: "rats.stage", eq: 2}], speaker: "Elder Bram", lines: ["You did it! The streets are quieter already.", "Take this, and I'll put in a word with the guard at the gate."], effects: [{giveCoins: 10}, {set: "rats.stage", value: 3}, {set: "bram.vouched", value: true}]},
      {when: [{flag: "rats.stage", eq: 1}], speaker: "Elder Bram", lines: ["Still rats about. ${rats.kills} of 4 so far."]},
      {when: [{flag: "rats.stage", gte: 3}], speaker: "Elder Bram", lines: ["Short on coin? The sewers are crawling with the witch's rats. Kill all you like."]},
      {speaker: "Elder Bram", lines: ["A witch has taken the castle. Since she came, rats have been pouring out of the cellars into our streets.", "Clear four of them for me, would you?"], effects: [{set: "rats.stage", value: 1}]}
    ],
    knight: [
      {when: [{flag: "gate.open"}], speaker: "Gate Knight", lines: ["Go on, then. Light preserve you."]},
      {when: [{flag: "bram.vouched"}], speaker: "Gate Knight", lines: ["Bram vouches for you. But with that rusty blade you'll not last a minute in there.", "Hilde at the market sells proper steel."]},
      {speaker: "Gate Knight", lines: ["No one goes in. Witch's orders, or near enough.", "If the elder vouched for you, maybe. Find Bram by the fountain."]}
    ],
    hilde: [
      {speaker: "Merchant Hilde", lines: ["Trade's been terrible since the witch came. Buying anything?"], choices: [{label: "Browse wares", open: "shop"}, {label: "Leave"}]}
    ],
    wanderPlaza: [
      {when: [{flag: "gate.open"}], speaker: "Townsman", lines: ["They say the knight let someone through the gate!"]},
      {speaker: "Townsman", lines: ["Mind the rats. One bit my boot clean through."]}
    ],
    wanderMarket: [
      {when: [{flag: "rats.stage", gte: 3}], speaker: "Townswoman", lines: ["Fewer rats about. Was that your doing?"]},
      {speaker: "Townswoman", lines: ["Nobody comes to market any more. Not with the rats."]}
    ],
    child: [
      {speaker: "Child", lines: ["I heard scratching down the tunnel by the wall. Mum says it's the sewer."]}
    ],
    oldWoman: [
      {speaker: "Old Woman", lines: ["I've lived by this water sixty years. Never seen the castle so dark."]}
    ]
  }
  return globals.rpgDialogue
end function

' @param {object} pages - one NPC's page array
' @param {object} ctx - newStoryContext()
' @return {dynamic} the first page whose `when` passes, or invalid
function selectDialoguePage(pages as dynamic, ctx as object) as dynamic
  if pages = invalid
    return invalid
  end if
  for each page in pages
    if evaluateConditions(page.when, ctx)
      return page
    end if
  end for
  return invalid
end function
```

```brighterscript
' examples/rpg/src/source/Story/QuestData.bs
import "StoryFlags.bs"
import "Text.bs"

' The quest log. A quest's current objective is its stages entry for the stage flag's value;
' with no entry (not started, or finished) it isn't listed.
'
' @return {object} quest array
function getQuestData() as object
  return [
    {id: "rats", title: "Rats in the streets", stageFlag: "rats.stage", stages: {"1": "Kill rats (${rats.kills}/4)", "2": "Return to Elder Bram"}},
    {id: "gate", title: "The castle gate", stageFlag: "gate.stage", stages: {"1": "Buy a better sword from Hilde", "2": "Enter the castle"}}
  ]
end function

' @param {object} quests - getQuestData()
' @param {StoryFlags} flags
' @return {object} objective strings, in quest order
function currentObjectives(quests as object, flags as object) as object
  objectives = []
  for each quest in quests
    key = flags.getInt(quest.stageFlag).toStr()
    if quest.stages.DoesExist(key)
      objectives.push(interpolateFlags(quest.stages[key], flags))
    end if
  end for
  return objectives
end function
```

```brighterscript
' examples/rpg/src/source/Story/Checkpoints.bs
import "StoryFlags.bs"
import "Inventory.bs"
import "Items.bs"

' Story state at a numbered checkpoint, for jumping there with --param stage=N while testing.
' 0 new game, 1 hunting rats, 2 rats done (report to Bram), 3 vouched (no sword), 4 gate open.
'
' @param {integer} n
' @return {object} {flags, inventory, coins}
function checkpointState(n as integer) as object
  flags = new StoryFlags()
  inventory = new Inventory(getItemDefinitions())
  coins = 0
  if n >= 1
    flags.set("rats.stage", 1)
  end if
  if n >= 2
    flags.set("rats.stage", 2)
    flags.set("rats.kills", 4)
  end if
  if n >= 3
    flags.set("rats.stage", 3)
    flags.set("bram.vouched", true)
    flags.set("gate.stage", 1)
    coins = 10
  end if
  if n >= 4
    inventory.add("steelSword")
    flags.set("gate.open", true)
    flags.set("gate.stage", 2)
    coins = 0
  end if
  return {flags: flags, inventory: inventory, coins: coins}
end function
```

- [ ] **Step 4: Run the tests to check they pass**

Run: `cd examples/rpg && npm test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add examples/rpg/src/source/Story examples/rpg/tests/DialogueData.spec.bs examples/rpg/tests/QuestData.spec.bs examples/rpg/bsconfig.test.json
git commit -m "rpg: add dialogue pages, quest log and checkpoints (#257)"
```

### Task 6: Event rules and the settle loop

**Files:**
- Create: `examples/rpg/src/source/Story/EventRules.bs`
- Test: `examples/rpg/tests/EventRules.spec.bs`
- Modify: `examples/rpg/bsconfig.test.json`

**Interfaces:**
- Consumes: `evaluateConditions`, `applyEffects` (Task 4).
- Produces:
  - `getEventRules() as object`. An array of `{event, match?, when?, effects}`.
  - `runEventRules(rules, eventName as string, data as object, ctx) as object`. Every matching rule runs in order, each seeing the previous ones' changes. Returns `{changed, posts}`.
  - `settleStory(rules, ctx) as object`. Runs `storyChanged` until nothing changes (max 4 passes, warns past that). Returns `{changed, posts}`.
  - `const STORY_SETTLE_MAX_PASSES = 4`.

- [ ] **Step 1: Write the failing tests**

```brighterscript
' examples/rpg/tests/EventRules.spec.bs
namespace tests
  @suite("story event rules")
  class EventRulesTests extends rooibos.BaseTestSuite

    private ctx as object

    protected override function beforeEach()
      m.ctx = newStoryContext(new StoryFlags(), new Inventory(getItemDefinitions()), {health: 6, maxHealth: 6, coins: 0})
    end function

    private function killRat() as object
      return runEventRules(getEventRules(), "enemyKilled", {kind: "rat"}, m.ctx)
    end function

    @describe("the rats quest")

    @it("ignores rat kills before the quest starts")
    function _()
      m.assertFalse(m.killRat().changed)
      m.assertEqual(0, m.ctx.flags.getInt("rats.kills"))
    end function

    @it("counts rat kills while hunting, but not bats")
    function _()
      m.ctx.flags.set("rats.stage", 1)
      m.killRat()
      runEventRules(getEventRules(), "enemyKilled", {kind: "bat"}, m.ctx)
      m.assertEqual(1, m.ctx.flags.getInt("rats.kills"))
    end function

    @it("moves to stage 2 on the fourth kill, in the same event")
    function _()
      m.ctx.flags.set("rats.stage", 1)
      m.ctx.flags.set("rats.kills", 3)
      m.killRat()
      m.assertEqual(2, m.ctx.flags.getInt("rats.stage"))
    end function

    @it("stops counting after stage 1")
    function _()
      m.ctx.flags.set("rats.stage", 2)
      m.ctx.flags.set("rats.kills", 4)
      m.killRat()
      m.assertEqual(4, m.ctx.flags.getInt("rats.kills"))
    end function

    @describe("the gate")

    @it("opens when Bram vouches after the sword is bought")
    function _()
      m.ctx.inventory.add("steelSword")
      m.ctx.flags.set("bram.vouched", true)
      result = settleStory(getEventRules(), m.ctx)
      m.assertTrue(m.ctx.flags.isSet("gate.open"))
      m.assertEqual(["gateOpened"], result.posts)
      m.assertEqual(2, m.ctx.flags.getInt("gate.stage"))
    end function

    @it("asks for a sword when vouched without one, then opens when it's bought")
    function _()
      m.ctx.flags.set("bram.vouched", true)
      settleStory(getEventRules(), m.ctx)
      m.assertEqual(1, m.ctx.flags.getInt("gate.stage"))
      m.assertFalse(m.ctx.flags.isSet("gate.open"))
      m.ctx.inventory.add("steelSword")
      settleStory(getEventRules(), m.ctx)
      m.assertTrue(m.ctx.flags.isSet("gate.open"))
    end function

    @it("posts gateOpened only once")
    function _()
      m.ctx.inventory.add("steelSword")
      m.ctx.flags.set("bram.vouched", true)
      settleStory(getEventRules(), m.ctx)
      m.assertEqual(0, settleStory(getEventRules(), m.ctx).posts.count())
    end function

    @describe("settleStory")

    @it("stops after the pass limit when rules keep changing things")
    function _()
      rules = [{event: "storyChanged", effects: [{add: "loop", amount: 1}]}]
      settleStory(rules, m.ctx)
      m.assertEqual(STORY_SETTLE_MAX_PASSES, m.ctx.flags.getInt("loop"))
    end function

    @it("matches on event data")
    function _()
      rules = [{event: "itemBought", match: {itemId: "potion"}, effects: [{set: "boughtPotion", value: true}]}]
      runEventRules(rules, "itemBought", {itemId: "steelSword"}, m.ctx)
      m.assertFalse(m.ctx.flags.isSet("boughtPotion"))
      runEventRules(rules, "itemBought", {itemId: "potion"}, m.ctx)
      m.assertTrue(m.ctx.flags.isSet("boughtPotion"))
    end function

  end class
end namespace
```

- [ ] **Step 2: Run the tests to check they fail**

Run: `cd examples/rpg && npm test`
Expected: a compile failure.

- [ ] **Step 3: Implement**

```brighterscript
' examples/rpg/src/source/Story/EventRules.bs
import "Conditions.bs"
import "Effects.bs"

const STORY_SETTLE_MAX_PASSES = 4

' Story changes that happen without dialogue. Every rule whose event, match and when pass runs,
' in order. "storyChanged" rules run after anything changes (see settleStory), which is how the
' gate opens whichever of Bram's word and the sword comes last.
'
' @return {object} rule array: {event, match?, when?, effects}
function getEventRules() as object
  return [
    {event: "enemyKilled", match: {kind: "rat"}, when: [{flag: "rats.stage", eq: 1}], effects: [{add: "rats.kills", amount: 1}]},
    {event: "enemyKilled", match: {kind: "rat"}, when: [{flag: "rats.stage", eq: 1}, {flag: "rats.kills", gte: 4}], effects: [{set: "rats.stage", value: 2}]},
    {event: "storyChanged", when: [{flag: "bram.vouched"}, {notItem: "steelSword"}], effects: [{set: "gate.stage", value: 1}]},
    {event: "storyChanged", when: [{flag: "bram.vouched"}, {hasItem: "steelSword"}, {notFlag: "gate.open"}], effects: [{set: "gate.open", value: true}, {post: "gateOpened"}]},
    {event: "storyChanged", when: [{flag: "gate.open"}], effects: [{set: "gate.stage", value: 2}]}
  ]
end function

' @param {object} rules
' @param {string} eventName
' @param {object} data - the event's data; a rule's match keys must equal these fields
' @param {object} ctx - newStoryContext()
' @return {object} {changed, posts}
function runEventRules(rules as object, eventName as string, data as object, ctx as object) as object
  total = {changed: false, posts: []}
  for each rule in rules
    if rule.event = eventName and ruleMatches(rule.match, data) and evaluateConditions(rule.when, ctx)
      result = applyEffects(rule.effects, ctx)
      total.changed = total.changed or result.changed
      total.posts.append(result.posts)
    end if
  end for
  return total
end function

function ruleMatches(match as dynamic, data as object) as boolean
  if match = invalid
    return true
  end if
  for each key in match
    if data = invalid or not data.DoesExist(key)
      return false
    end if
    ' Separate checks, so <> never compares a string with an integer.
    if type(data[key]) <> type(match[key])
      return false
    end if
    if data[key] <> match[key]
      return false
    end if
  end for
  return true
end function

' Runs "storyChanged" rules until nothing more changes.
'
' @param {object} rules
' @param {object} ctx
' @return {object} {changed, posts} across every pass
function settleStory(rules as object, ctx as object) as object
  total = {changed: false, posts: []}
  for pass = 1 to STORY_SETTLE_MAX_PASSES
    result = runEventRules(rules, "storyChanged", {}, ctx)
    total.posts.append(result.posts)
    if not result.changed
      return total
    end if
    total.changed = true
  end for
  print "[rpg] warning: story rules still changing after " + STORY_SETTLE_MAX_PASSES.toStr() + " passes"
  return total
end function
```

- [ ] **Step 4: Run the tests to check they pass**

Run: `cd examples/rpg && npm test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add examples/rpg/src/source/Story/EventRules.bs examples/rpg/tests/EventRules.spec.bs examples/rpg/bsconfig.test.json
git commit -m "rpg: add story event rules (#257)"
```

### Task 7: Shop rules and save data

**Files:**
- Create: `examples/rpg/src/source/Story/ShopData.bs`, `Story/SaveData.bs`
- Test: `examples/rpg/tests/Shop.spec.bs`, `examples/rpg/tests/SaveData.spec.bs`
- Modify: `examples/rpg/bsconfig.test.json`

**Interfaces:**
- Consumes: `Inventory`, `StoryFlags`, `newStoryContext`, `applyEffects` (Tasks 3-4).
- Produces:
  - `getShopItems() as object`. Returns `[{itemId, price}]`: steelSword 10, heartContainer 15, potion 4.
  - `canBuy(itemId, price as integer, ctx) as string`. Returns `""`, `"Not enough coins"`, `"Already owned"` (max 1, owned) or `"Can't carry more"`.
  - `buyItem(itemId, price, ctx) as object`. Returns `{ok as boolean, reason as string}`; on success it takes the coins and gives the item through `applyEffects` (so `onAcquire` runs).
  - `canUse(itemId, ctx) as string`. Returns `""`, `"You have none"` or `"Already at full health"` (an `onUse` that heals at full health).
  - `useItem(itemId, ctx) as object`. Returns `{ok, reason}`; removes one and runs `onUse`.
  - `const SAVE_VERSION = 1`, `const SAVE_SECTION = "bge-rpg"`, `const SAVE_KEY = "save"`.
  - `buildSaveData(sceneName, spawn, flags, inventory, player) as object`.
  - `validateSaveData(data as dynamic) as dynamic`. Returns a clean save AA (health clamped to 1..maxHealth), or `invalid`.

- [ ] **Step 1: Write the failing tests**

```brighterscript
' examples/rpg/tests/Shop.spec.bs
namespace tests
  @suite("shop")
  class ShopTests extends rooibos.BaseTestSuite

    private ctx as object

    protected override function beforeEach()
      m.ctx = newStoryContext(new StoryFlags(), new Inventory(getItemDefinitions()), {health: 6, maxHealth: 6, coins: 12})
    end function

    @describe("buying")

    @it("buys the sword when there's enough coin")
    function _()
      result = buyItem("steelSword", 10, m.ctx)
      m.assertTrue(result.ok)
      m.assertEqual(2, m.ctx.player.coins)
      m.assertTrue(m.ctx.inventory.has("steelSword"))
    end function

    @it("refuses without enough coin, changing nothing")
    function _()
      result = buyItem("heartContainer", 15, m.ctx)
      m.assertFalse(result.ok)
      m.assertEqual("Not enough coins", result.reason)
      m.assertEqual(12, m.ctx.player.coins)
    end function

    @it("refuses a one-off item already owned")
    function _()
      m.ctx.inventory.add("steelSword")
      m.assertEqual("Already owned", canBuy("steelSword", 10, m.ctx))
    end function

    @it("refuses potions past the carry limit")
    function _()
      m.ctx.player.coins = 100
      buyItem("potion", 4, m.ctx)
      buyItem("potion", 4, m.ctx)
      buyItem("potion", 4, m.ctx)
      m.assertEqual("Can't carry more", canBuy("potion", 4, m.ctx))
    end function

    @it("runs the heart container's onAcquire")
    function _()
      m.ctx.player.coins = 15
      buyItem("heartContainer", 15, m.ctx)
      m.assertEqual(8, m.ctx.player.maxHealth)
    end function

    @describe("using")

    @it("won't drink a potion at full health")
    function _()
      m.ctx.inventory.add("potion")
      m.assertEqual("Already at full health", canUse("potion", m.ctx))
    end function

    @it("drinks a potion when hurt")
    function _()
      m.ctx.inventory.add("potion")
      m.ctx.player.health = 1
      m.assertTrue(useItem("potion", m.ctx).ok)
      m.assertEqual(5, m.ctx.player.health)
      m.assertEqual(0, m.ctx.inventory.count("potion"))
    end function

    @it("can't use what you don't have")
    function _()
      m.ctx.player.health = 1
      m.assertEqual("You have none", canUse("potion", m.ctx))
    end function

  end class
end namespace
```

```brighterscript
' examples/rpg/tests/SaveData.spec.bs
namespace tests
  @suite("save data")
  class SaveDataTests extends rooibos.BaseTestSuite

    private function sample() as object
      flags = new StoryFlags()
      flags.set("rats.stage", 2)
      inventory = new Inventory(getItemDefinitions())
      inventory.add("potion")
      return buildSaveData("TownScene", "gate", flags, inventory, {health: 4, maxHealth: 6, coins: 7})
    end function

    @describe("validateSaveData")

    @it("round-trips through JSON")
    function _()
      save = validateSaveData(ParseJson(FormatJson(m.sample())))
      m.assertNotInvalid(save)
      m.assertEqual("TownScene", save.scene)
      m.assertEqual("gate", save.spawn)
      m.assertEqual(2, save.flags["rats.stage"])
      m.assertEqual(1, save.inventory.potion)
      m.assertEqual(7, save.player.coins)
    end function

    @it("rejects invalid, a string and an array")
    function _()
      m.assertInvalid(validateSaveData(invalid))
      m.assertInvalid(validateSaveData("save"))
      m.assertInvalid(validateSaveData([1, 2]))
    end function

    @it("rejects a different version")
    function _()
      data = m.sample()
      data.version = 99
      m.assertInvalid(validateSaveData(data))
    end function

    @it("rejects a missing field")
    function _()
      data = m.sample()
      data.Delete("player")
      m.assertInvalid(validateSaveData(data))
    end function

    @it("rejects a wrong type for coins")
    function _()
      data = m.sample()
      data.player.coins = "lots"
      m.assertInvalid(validateSaveData(data))
    end function

    @it("clamps health into 1..maxHealth")
    function _()
      data = m.sample()
      data.player.health = 0
      m.assertEqual(1, validateSaveData(data).player.health)
      data.player.health = 50
      m.assertEqual(6, validateSaveData(data).player.health)
    end function

  end class
end namespace
```

- [ ] **Step 2: Run the tests to check they fail**

Run: `cd examples/rpg && npm test`
Expected: a compile failure.

- [ ] **Step 3: Implement**

```brighterscript
' examples/rpg/src/source/Story/ShopData.bs
import "Effects.bs"

' Hilde's wares, in display order.
'
' @return {object} [{itemId, price}]
function getShopItems() as object
  return [
    {itemId: "steelSword", price: 10},
    {itemId: "heartContainer", price: 15},
    {itemId: "potion", price: 4}
  ]
end function

' @return {string} "" if it can be bought, otherwise why not
function canBuy(itemId as string, price as integer, ctx as object) as string
  if not ctx.inventory.canAdd(itemId)
    if ctx.items[itemId].max = 1
      return "Already owned"
    end if
    return "Can't carry more"
  end if
  if ctx.player.coins < price
    return "Not enough coins"
  end if
  return ""
end function

' @return {object} {ok, reason}
function buyItem(itemId as string, price as integer, ctx as object) as object
  reason = canBuy(itemId, price, ctx)
  if reason <> ""
    return {ok: false, reason: reason}
  end if
  applyEffects([{takeCoins: price}, {giveItem: itemId}], ctx)
  return {ok: true, reason: ""}
end function

' @return {string} "" if it can be used now, otherwise why not
function canUse(itemId as string, ctx as object) as string
  if not ctx.inventory.has(itemId)
    return "You have none"
  end if
  for each effect in ctx.items[itemId].onUse
    if effect.DoesExist("heal") and ctx.player.health >= ctx.player.maxHealth
      return "Already at full health"
    end if
  end for
  return ""
end function

' @return {object} {ok, reason}
function useItem(itemId as string, ctx as object) as object
  reason = canUse(itemId, ctx)
  if reason <> ""
    return {ok: false, reason: reason}
  end if
  ctx.inventory.remove(itemId)
  applyEffects(ctx.items[itemId].onUse, ctx)
  return {ok: true, reason: ""}
end function
```

```brighterscript
' examples/rpg/src/source/Story/SaveData.bs
import "StoryFlags.bs"
import "Inventory.bs"

const SAVE_VERSION = 1
const SAVE_SECTION = "bge-rpg"
const SAVE_KEY = "save"

' @param {string} sceneName - the area to resume in
' @param {string} spawn - the spawn point to resume at
' @param {StoryFlags} flags
' @param {Inventory} inventory
' @param {object} player - health, maxHealth, coins
' @return {object}
function buildSaveData(sceneName as string, spawn as string, flags as object, inventory as object, player as object) as object
  return {
    version: SAVE_VERSION,
    scene: sceneName,
    spawn: spawn,
    flags: flags.toAA(),
    inventory: inventory.toAA(),
    player: {health: player.health, maxHealth: player.maxHealth, coins: player.coins}
  }
end function

' Checks a loaded save. Anything malformed or from another version counts as no save.
'
' @param {dynamic} data - what registryRead() returned
' @return {dynamic} the save with health clamped to 1..maxHealth, or invalid
function validateSaveData(data as dynamic) as dynamic
  if type(data) <> "roAssociativeArray"
    return invalid
  end if
  if not isSaveInt(data.version)
    return invalid
  end if
  if data.version <> SAVE_VERSION
    return invalid
  end if
  if not isSaveString(data.scene) or not isSaveString(data.spawn)
    return invalid
  end if
  if type(data.flags) <> "roAssociativeArray" or type(data.inventory) <> "roAssociativeArray" or type(data.player) <> "roAssociativeArray"
    return invalid
  end if
  player = data.player
  if not isSaveInt(player.health) or not isSaveInt(player.maxHealth) or not isSaveInt(player.coins)
    return invalid
  end if
  ' Only compared once all three are known to be integers.
  if player.maxHealth < 1
    return invalid
  end if
  if player.health < 1
    player.health = 1
  else if player.health > player.maxHealth
    player.health = player.maxHealth
  end if
  return data
end function

function isSaveInt(value as dynamic) as boolean
  valueType = type(value)
  return valueType = "Integer" or valueType = "roInt" or valueType = "LongInteger"
end function

function isSaveString(value as dynamic) as boolean
  valueType = type(value)
  return valueType = "String" or valueType = "roString"
end function
```


- [ ] **Step 4: Run the tests to check they pass**

Run: `cd examples/rpg && npm test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add examples/rpg/src/source/Story examples/rpg/tests/Shop.spec.bs examples/rpg/tests/SaveData.spec.bs examples/rpg/bsconfig.test.json
git commit -m "rpg: add shop rules and save data (#257)"
```

### Task 8: Assets

**Files:**
- Create:
  - `examples/rpg/src/sprites/npcs.png`
  - `examples/rpg/src/sprites/items/potion.png`, `swordSteel.png`, `swordRusty.png`
  - `examples/rpg/src/images/title.jpg`
- Modify: `examples/rpg/src/sprites/CREDITS.md`, `examples/rpg/src/source/main.bs`, `examples/rpg/src/source/Maps/Atlas.bs`

**Interfaces:**
- Produces:
  - Bitmaps `npcs`, `potion`, `swordSteel`, `swordRusty`, `title`.
  - Atlas keys `tunnel` and `ladder` (footprint `invalid`).
  - `npcs.png` layout: **one character per row, 12 frames of 32×48 per row**. Frames 0-8 are the sheet's own (0 stand down, 1 stand up, 2-3 walk down, 4 stand left, 5-6 walk left, 7-8 walk up). Frames 9-11 are mirrored copies of 4-6 (stand right, walk right). Row order: 0 knight, 1 blonde girl, 2 blonde boy, 3 pink girl, 4 brunette boy, 5 teal girl, 6 dark-haired boy, 7 red girl, 8 old man, 9 old woman.

- [ ] **Step 1: Prepare `npcs.png`**

The source's top block is 576×240: 5 rows of 48px, and each row has two characters of 9 frames × 32px (left half, then right half), on a solid `#FF00FF` background.

```bash
SRC=/Users/mpearce/Downloads/rpg/npcs.png
OUT=examples/rpg/src/sprites/npcs.png
S=/private/tmp/claude-502/-Users-mpearce-redspace-roku-brighterscript-game-engine/1d559860-ee6c-402d-b28c-16870ef09742/scratchpad/npcs
mkdir -p $S
magick $SRC -crop 576x240+0+0 +repage -transparent "#FF00FF" $S/top.png
rows=()
for r in 0 1 2 3 4; do
  for half in 0 1; do
    x=$((half * 288)); y=$((r * 48))
    magick $S/top.png -crop 288x48+$x+$y +repage $S/base_${r}_${half}.png
    # Each side frame is flopped on its own, so the frame order stays the same.
    magick $S/top.png -crop 32x48+$((x + 128))+$y +repage -flop $S/r0.png
    magick $S/top.png -crop 32x48+$((x + 160))+$y +repage -flop $S/r1.png
    magick $S/top.png -crop 32x48+$((x + 192))+$y +repage -flop $S/r2.png
    magick $S/base_${r}_${half}.png $S/r0.png $S/r1.png $S/r2.png +append $S/row_${r}_${half}.png
    rows+=($S/row_${r}_${half}.png)
  done
done
magick "${rows[@]}" -background none -append $OUT
magick identify $OUT   # expect 384x480
```

Then check the result visually: `magick $OUT -scale 300% $S/check.png` and Read it. Each row should show one character in order: stand down, stand up, 2 walk-down frames, stand left, 2 walk-left frames, 2 walk-up frames, then stand right and 2 walk-right frames. The feet sit on the bottom row of each cell (measured: every character's lowest pixel is at y = 47).

- [ ] **Step 2: Item icons**

```bash
ICONS=/Users/mpearce/Downloads/rpg/RPGIconsExtra_by_Ails/RPGIconsExtra
mkdir -p examples/rpg/src/sprites/items
cp $ICONS/icon_29.png examples/rpg/src/sprites/items/potion.png
cp /Users/mpearce/Downloads/rpg/broadsword_icon.png examples/rpg/src/sprites/items/swordSteel.png
magick /Users/mpearce/Downloads/rpg/broadsword_icon.png -modulate 85,60,100 -fill "#8B4513" -colorize 35% examples/rpg/src/sprites/items/swordRusty.png
```

Read `swordRusty.png` at 400% next to `swordSteel.png`. The rusty one should read clearly as brown and corroded, and keep its transparency. Tune `-colorize` if it doesn't.

- [ ] **Step 3: Title art**

If the repo owner has supplied the monster-free key art (e.g. `examples/rpg/src/images/title.jpg` or a path in `~/Downloads`), scale and centre-crop it to fill 1280×720:

```bash
magick <source> -resize 1280x720^ -gravity center -extent 1280x720 -quality 90 examples/rpg/src/images/title.jpg
```

If it isn't supplied yet, use `cp examples/rpg/src/images/Splash_HD.png examples/rpg/src/images/title.jpg` as a stand-in, and leave this step unchecked with a note in the PR description.

- [ ] **Step 4: Add the tunnel and ladder to the atlas**

Measured from `Castle2.png` (alpha-trimmed): the dark stone archway is 68×66 at (430, 222), and the ladder is 27×90 at (67, 266). Add to `buildAtlas()`, under a new comment:

```brighterscript
    ' Sewer
    tunnel: {sheet: "castle", x: 430, y: 222, w: 68, h: 66, footprint: invalid},
    ladder: {sheet: "castle", x: 67, y: 266, w: 27, h: 90, footprint: invalid}
```

Crop both at 400% (`magick examples/rpg/src/sprites/Castle2.png -crop 68x66+430+222 +repage -scale 400% <scratchpad>/tunnel.png`) and Read them, to confirm each crop holds the whole piece and nothing from its neighbours.

- [ ] **Step 5: Load everything in `main.bs`**

After the existing `loadBitmap` calls:

```brighterscript
  game.loadBitmap("npcs", "pkg:/sprites/npcs.png")
  game.loadBitmap("potion", "pkg:/sprites/items/potion.png")
  game.loadBitmap("swordSteel", "pkg:/sprites/items/swordSteel.png")
  game.loadBitmap("swordRusty", "pkg:/sprites/items/swordRusty.png")
  game.loadBitmap("title", "pkg:/images/title.jpg")
```

- [ ] **Step 6: Credits**

Append to `examples/rpg/src/sprites/CREDITS.md`:

```markdown
## npcs.png
`npcs.png` from "Fantasy RPG NPCs" by Mandi Paugh. https://opengameart.org/content/fantasy-rpg-npcs
License: CC-BY-SA 3.0. Modified: the magenta background made transparent, the labels removed, one
character per row, and mirrored right-facing frames added.

## items/potion.png, items/swordSteel.png, items/swordRusty.png
From "RPG Icons Extra" by Ails (Henrique Lazarini), https://ails.deviantart.com. License: CC-BY 3.0.
`potion.png` is `icon_29.png`, unmodified. `swordSteel.png` is an icon from the same pack, modified by
the repo owner. `swordRusty.png` is `swordSteel.png` recoloured.

## ../images/title.jpg
The "Broadsword" key art without monsters, generated with Google Gemini (supplied by the repo
owner), scaled to fill and centre-cropped to 1280x720.
```

- [ ] **Step 7: Validate and commit**

Run: `cd examples/rpg && npx bsc --create-package=false`
Expected: no diagnostics.

```bash
git add examples/rpg/src/sprites examples/rpg/src/images/title.jpg examples/rpg/src/source/main.bs examples/rpg/src/source/Maps/Atlas.bs
git commit -m "rpg: add NPC sheet, item icons, title art, tunnel and ladder (#257)"
```

### Task 9: Talking geometry and the `Npc` entity

**Files:**
- Create:
  - `examples/rpg/src/source/Entities/Talk.bs` (pure)
  - `Entities/NpcSheet.bs` (pure)
  - `Entities/Npc.bs`
- Test: `examples/rpg/tests/Talk.spec.bs`
- Modify: `examples/rpg/bsconfig.test.json` (add `Talk.bs`, `NpcSheet.bs`)

**Interfaces:**
- Consumes: `FacingDirection`, `facingFor` (`Facing.bs`). The `npcs` bitmap (Task 8).
- Produces:
  - `talkBox(facing as FacingDirection) as object`. Returns `{x, y, w, h}` relative to the feet; it reaches 32px out and is 40px across.
  - `nearestInBox(box as object, originX, originY, candidates as object) as integer`. Candidates are `[{x, y}]` feet points; it returns the index of the nearest one inside `origin + box` (edges count as inside), or -1.
  - `getNpcCharacters() as object`. Maps character name → sheet row: `knight` 0, `blondeGirl` 1, `blondeBoy` 2, `pinkGirl` 3, `brunetteBoy` 4, `tealGirl` 5, `darkBoy` 6, `redGirl` 7, `oldMan` 8, `oldWoman` 9.
  - `const NPC_FRAME_W = 32`, `NPC_FRAME_H = 48`, `NPC_FRAMES_PER_ROW = 12`, `NPC_FEET_X = 16`, `NPC_FEET_Y = 47`.
  - `class Npc extends BGE.GameEntity`:
    - Fields: `npcId as string`, `facing as FacingDirection`.
    - Methods: `faceToward(x, y)`, `setTalking(talking as boolean)`.
    - Tagged `"npc"`, with `name = "Npc"`.
    - `onCreate` args: `{npcId, character, x, y, facing, wander (px radius, 0 = still), solidWorld}`.

- [ ] **Step 1: Write the failing tests**

```brighterscript
' examples/rpg/tests/Talk.spec.bs
namespace tests
  @suite("talking")
  class TalkTests extends rooibos.BaseTestSuite

    @describe("talkBox")

    @it("reaches in front of the feet for each facing")
    @params("up", 0.0, 20.0)
    @params("down", 0.0, -20.0)
    @params("left", -28.0, 2.0)
    @params("right", 28.0, 2.0)
    function _(facing, px, py)
      box = talkBox(facing)
      m.assertTrue(px >= box.x and px <= box.x + box.w and py >= box.y and py <= box.y + box.h, "point not in the " + facing + " box")
    end function

    @it("doesn't reach behind the player")
    function _()
      box = talkBox(FacingDirection.up)
      m.assertTrue(box.y >= 0, "up box starts below the feet")
    end function

    @describe("nearestInBox")

    @it("finds an NPC standing flush against the player's feet box")
    function _()
      ' A still NPC's 20x12 solid stops the player's 20x12 feet box flush below it.
      m.assertEqual(0, nearestInBox(talkBox(FacingDirection.up), 100, 100, [{x: 100, y: 112}]))
    end function

    @it("picks the nearest of two")
    function _()
      m.assertEqual(1, nearestInBox(talkBox(FacingDirection.right), 0, 0, [{x: 38, y: 0}, {x: 22, y: 0}]))
    end function

    @it("returns -1 when nobody is in range")
    function _()
      m.assertEqual(-1, nearestInBox(talkBox(FacingDirection.right), 0, 0, [{x: -30, y: 0}, {x: 200, y: 0}]))
      m.assertEqual(-1, nearestInBox(talkBox(FacingDirection.right), 0, 0, []))
    end function

    @describe("NPC sheet")

    @it("puts every character on its own row")
    function _()
      characters = getNpcCharacters()
      m.assertEqual(10, characters.count())
      m.assertEqual(8, characters.oldMan)
    end function

  end class
end namespace
```

- [ ] **Step 2: Run the tests to check they fail**

Run: `cd examples/rpg && npm test`
Expected: a compile failure.

- [ ] **Step 3: Implement the pure files**

```brighterscript
' examples/rpg/src/source/Entities/Talk.bs
import "Facing.bs"

' The talk area in front of the feet. A little longer and wider than the sword's reach, so
' you don't have to line up exactly.
const TALK_REACH = 32.0
const TALK_SPAN = 40.0
const TALK_FEET_HALF_W = 10.0
const TALK_FEET_H = 12.0

' @param {FacingDirection} facing
' @return {object} {x, y, w, h} relative to the feet point
function talkBox(facing as FacingDirection) as object
  midY = TALK_FEET_H / 2 - TALK_SPAN / 2
  if facing = FacingDirection.up
    return {x: -TALK_SPAN / 2, y: TALK_FEET_H, w: TALK_SPAN, h: TALK_REACH}
  else if facing = FacingDirection.left
    return {x: -TALK_FEET_HALF_W - TALK_REACH, y: midY, w: TALK_REACH, h: TALK_SPAN}
  else if facing = FacingDirection.right
    return {x: TALK_FEET_HALF_W, y: midY, w: TALK_REACH, h: TALK_SPAN}
  end if
  return {x: -TALK_SPAN / 2, y: -TALK_REACH, w: TALK_SPAN, h: TALK_REACH}
end function

' @param {object} box - talkBox() result
' @param {float} originX - the player's feet
' @param {float} originY
' @param {object} candidates - [{x, y}] feet points
' @return {integer} index of the nearest candidate inside the box, or -1
function nearestInBox(box as object, originX as float, originY as float, candidates as object) as integer
  best = -1
  bestDistance = 0.0
  left = originX + box.x
  bottom = originY + box.y
  for i = 0 to candidates.count() - 1
    c = candidates[i]
    if c.x >= left and c.x <= left + box.w and c.y >= bottom and c.y <= bottom + box.h
      dx = c.x - originX
      dy = c.y - originY
      distance = dx * dx + dy * dy
      if best = -1 or distance < bestDistance
        best = i
        bestDistance = distance
      end if
    end if
  end for
  return best
end function
```

```brighterscript
' examples/rpg/src/source/Entities/NpcSheet.bs

' npcs.png: one character per row, 12 frames of 32x48. Frames: 0 stand down, 1 stand up, 2-3 walk
' down, 4 stand left, 5-6 walk left, 7-8 walk up, 9 stand right, 10-11 walk right.
const NPC_FRAME_W = 32
const NPC_FRAME_H = 48
const NPC_FRAMES_PER_ROW = 12
' Where the feet are within a frame.
const NPC_FEET_X = 16
const NPC_FEET_Y = 47

' @return {object} character name -> sheet row
function getNpcCharacters() as object
  return {knight: 0, blondeGirl: 1, blondeBoy: 2, pinkGirl: 3, brunetteBoy: 4, tealGirl: 5, darkBoy: 6, redGirl: 7, oldMan: 8, oldWoman: 9}
end function
```

- [ ] **Step 4: Run the tests to check they pass**

Run: `cd examples/rpg && npm test`
Expected: PASS.

- [ ] **Step 5: Implement `Npc`**

```brighterscript
' examples/rpg/src/source/Entities/Npc.bs
import "pkg:/source/engine/colliders/SolidWorld.bs"
import "pkg:/source/utils/CountdownTimer.bs"
import "Facing.bs"
import "Shadow.bs"
import "NpcSheet.bs"

const NPC_WALK_SPEED = 40.0
const NPC_BOX_W = 20.0
const NPC_BOX_H = 12.0

' A townsperson you can talk to (OK while facing them). Still NPCs block movement with a small
' solid at their feet; wanderers stroll within `wander` px of where they were placed.
class Npc extends BGE.GameEntity

  npcId as string = ""
  facing as FacingDirection = FacingDirection.down
  private sprite as BGE.Sprite = invalid
  private solidWorld as BGE.SolidWorld = invalid
  private wander as float = 0.0
  private homeX as float = 0.0
  private homeY as float = 0.0
  private targetX as float = 0.0
  private targetY as float = 0.0
  private walking as boolean = false
  private talking as boolean = false
  private idleTimer as BGE.CountdownTimer = new BGE.CountdownTimer()

  sub new(game as BGE.Game)
    super(game)
    m.name = "Npc"
    m.tagsList.add("npc")
  end sub

  ' @param {roAssociativeArray} args - {npcId, character, x, y (feet), facing, wander, solidWorld}
  override sub onCreate(args as roAssociativeArray)
    m.npcId = args.npcId
    m.facing = args.facing
    m.position.x = args.x
    m.position.y = args.y
    m.position.z = -args.y
    m.homeX = args.x
    m.homeY = args.y
    m.wander = args.wander
    m.solidWorld = args.solidWorld
    addGroundShadow(m, 8)
    m.sprite = m.addSprite("body", m.game.getBitmap("npcs"), NPC_FRAME_W, NPC_FRAME_H)
    m.sprite.applyPreTranslation(-NPC_FEET_X, -NPC_FEET_Y)
    first = getNpcCharacters()[args.character] * NPC_FRAMES_PER_ROW
    m.sprite.addAnimation("idle_down", [first], 1, BGE.SpritePlayMode.Loop)
    m.sprite.addAnimation("idle_up", [first + 1], 1, BGE.SpritePlayMode.Loop)
    m.sprite.addAnimation("idle_left", [first + 4], 1, BGE.SpritePlayMode.Loop)
    m.sprite.addAnimation("idle_right", [first + 9], 1, BGE.SpritePlayMode.Loop)
    m.sprite.addAnimation("walk_down", [first + 2, first + 3], 6, BGE.SpritePlayMode.Loop)
    m.sprite.addAnimation("walk_up", [first + 7, first + 8], 6, BGE.SpritePlayMode.Loop)
    m.sprite.addAnimation("walk_left", [first + 4, first + 5, first + 4, first + 6], 8, BGE.SpritePlayMode.Loop)
    m.sprite.addAnimation("walk_right", [first + 9, first + 10, first + 9, first + 11], 8, BGE.SpritePlayMode.Loop)
    m.sprite.playAnimation("idle_" + m.facing)
    if m.wander <= 0
      m.solidWorld.addSolid(m.position.x - NPC_BOX_W / 2, m.position.y, NPC_BOX_W, NPC_BOX_H)
    end if
    m.idleTimer.start(1 + Rnd(0) * 2)
  end sub

  ' Turns to look at a point (the player, when spoken to).
  sub faceToward(x as float, y as float)
    m.facing = facingFor(x - m.position.x, y - m.position.y, m.facing)
    m.sprite.playAnimation("idle_" + m.facing)
  end sub

  ' While talking, a wanderer stands still.
  sub setTalking(talking as boolean)
    m.talking = talking
    if talking
      m.walking = false
      m.sprite.playAnimation("idle_" + m.facing)
    end if
  end sub

  override sub onUpdate(dt as float)
    if m.wander <= 0 or m.talking
      return
    end if
    if dt > 0.1
      dt = 0.1
    end if
    if not m.walking
      m.idleTimer.tick(dt)
      if not m.idleTimer.isActive()
        angle = Rnd(0) * 6.2832
        radius = Rnd(0) * m.wander
        m.targetX = m.homeX + Cos(angle) * radius
        m.targetY = m.homeY + Sin(angle) * radius
        m.walking = true
      end if
      return
    end if
    dx = m.targetX - m.position.x
    dy = m.targetY - m.position.y
    distance = Sqr(dx * dx + dy * dy)
    if distance < 2
      m.stopWalking()
      return
    end if
    stepLength = NPC_WALK_SPEED * dt
    if stepLength > distance
      stepLength = distance
    end if
    feetBox = {x: m.position.x - NPC_BOX_W / 2, y: m.position.y, w: NPC_BOX_W, h: NPC_BOX_H}
    result = m.solidWorld.moveAndSlide(feetBox, dx / distance * stepLength, dy / distance * stepLength, {})
    if result.blockedX and result.blockedY
      m.stopWalking()
      return
    end if
    m.position.x = result.x + NPC_BOX_W / 2
    m.position.y = result.y
    m.position.z = -m.position.y
    m.facing = facingFor(dx, dy, m.facing)
    m.sprite.playAnimation("walk_" + m.facing)
  end sub

  private sub stopWalking()
    m.walking = false
    m.sprite.playAnimation("idle_" + m.facing)
    m.idleTimer.start(1 + Rnd(0) * 2)
  end sub

end class
```

- [ ] **Step 6: Validate and commit**

Run: `cd examples/rpg && npm test && npx bsc --create-package=false`
Expected: PASS, no diagnostics.

```bash
git add examples/rpg/src/source/Entities/Talk.bs examples/rpg/src/source/Entities/NpcSheet.bs examples/rpg/src/source/Entities/Npc.bs examples/rpg/tests/Talk.spec.bs examples/rpg/bsconfig.test.json
git commit -m "rpg: add NPCs and talk geometry (#257)"
```

### Task 10: The `Story` entity, and wiring the player and enemies into it

**Files:**
- Create: `examples/rpg/src/source/Story/Story.bs`
- Modify: `examples/rpg/src/source/Entities/Enemy.bs`, `Entities/Player.bs`, `examples/rpg/src/source/main.bs`

**Interfaces:**
- Consumes: everything in `Story/` (Tasks 3-7), `Npc`, `talkBox`, `nearestInBox` (Task 9), `BGE.registryRead`/`registryWrite` (`pkg:/source/utils/registry.bs`).
- Produces:
  - `class Story extends BGE.GameEntity`, with `name = "Story"`, `persistent = true`, `pauseable = false`.
  - Fields: `flags as StoryFlags`, `inventory as Inventory`, `savingEnabled as boolean = true`.
  - Public methods:
    - `context() as object`
    - `newGame()`, `loadSave(save as object)`, `applyCheckpoint(n as integer)`
    - `readSave() as dynamic` (validated save or invalid), `deleteSave()`
    - `arrivedAt(sceneName as string, spawn as string)` (autosaves)
    - `save()`
    - `finishDialogue(page as object, choice as dynamic)` (UI callback)
    - `buy(itemId as string) as object`, `use(itemId as string) as object`
    - `objectives() as object`
    - `openModal()`, `closeModal()`, `isModalOpen() as boolean`
    - `shopItems() as object`
  - Events it listens to:
    - `enemyKilled {kind}`
    - `talkRequested {npcId}`
    - `inventoryRequested`
  - Events it posts:
    - `gateOpened`
    - `storySaved`, which `SaveIndicator` listens for
  - `Enemy.hurt(fromX, fromY, amount = 1 as integer) as boolean`. `Enemy.die()` posts `enemyKilled {kind: LCase(m.name)}`.
  - `Player.swordDamage as integer = 1`. `Player.resetForNewGame()` and `Player.applySavedStats(stats as object)`.

- [ ] **Step 1: Enemy changes**

In `Enemy.hurt`, add `amount = 1 as integer` as the third param, then use `m.health -= amount` and `amount: amount` in the `DamageNumber` args. In `die()`, after `m.isDying = true`, add:

```brighterscript
    m.game.postGameEvent("enemyKilled", {kind: LCase(m.name)})
```

- [ ] **Step 2: Player changes**

Add `import "Npc.bs"` and `import "Talk.bs"`. Add these fields:

```brighterscript
  ' Damage per sword hit, set by the Story from the inventory (2 with the steel sword).
  swordDamage as integer = 1
```

Replace `onInput`:

```brighterscript
  override sub onInput(input as BGE.GameInput)
    if input.press and input.isButton("ok")
      if not m.tryTalk()
        m.requestSwing()
      end if
    end if
  end sub

  ' Talks to an NPC the player is facing, if any.
  '
  ' @return {boolean} true if someone was spoken to
  private function tryTalk() as boolean
    if m.defeated or m.swinging or m.solidWorld = invalid or m.game.isTransitioning() or m.knockbackTimer.isActive()
      return false
    end if
    npcs = m.game.getEntitiesByTag("npc")
    candidates = []
    for each entity in npcs
      candidates.push({x: entity.position.x, y: entity.position.y})
    end for
    index = nearestInBox(talkBox(m.facing), m.position.x, m.position.y, candidates)
    if index < 0
      return false
    end if
    m.sprite.playAnimation("idle_" + m.facing)
    target = npcs[index] as Npc
    m.game.postGameEvent("talkRequested", {npcId: target.npcId})
    return true
  end function
```

In `onCollision`'s sword branch, pass the damage: `hitEnemy.hurt(m.position.x, m.position.y, m.swordDamage)`.

Add:

```brighterscript
  ' Starting stats for a new game.
  sub resetForNewGame()
    m.maxHealth = PLAYER_MAX_HEALTH
    m.health = PLAYER_MAX_HEALTH
    m.coins = 0
    m.swordDamage = 1
  end sub

  ' @param {object} stats - a validated save's player: {health, maxHealth, coins}
  sub applySavedStats(stats as object)
    m.maxHealth = stats.maxHealth
    m.health = stats.health
    m.coins = stats.coins
  end sub
```

In `placeAt`, the "restore full health after defeat" line stays as is.

- [ ] **Step 3: Write `Story.bs`**

```brighterscript
' examples/rpg/src/source/Story/Story.bs
import "pkg:/source/utils/registry.bs"
import "StoryFlags.bs"
import "Inventory.bs"
import "Items.bs"
import "Conditions.bs"
import "Effects.bs"
import "EventRules.bs"
import "DialogueData.bs"
import "QuestData.bs"
import "ShopData.bs"
import "SaveData.bs"
import "Checkpoints.bs"
import "../Entities/Player.bs"
import "../Entities/Npc.bs"
import "../UI/DialogueBox.bs"
import "../UI/ShopPanel.bs"
import "../UI/InventoryPanel.bs"

' Owns the story state (flags, inventory) and runs it: answers game events with the event rules,
' opens dialogue/shop/inventory panels, and autosaves. Persistent and never paused, so it keeps
' working while a panel has the game paused.
class Story extends BGE.GameEntity

  flags as StoryFlags = invalid
  inventory as Inventory = invalid
  ' Off while a --param deep link is active, so testing never overwrites a real save.
  savingEnabled as boolean = true
  private sceneName as string = ""
  private spawn as string = ""
  private modalCount as integer = 0
  private talkingNpc as Npc = invalid

  sub new(game as BGE.Game)
    super(game)
    m.name = "Story"
    m.persistent = true
    m.pauseable = false
    m.flags = new StoryFlags()
    m.inventory = new Inventory(getItemDefinitions())
  end sub

  function context() as object
    return newStoryContext(m.flags, m.inventory, m.getPlayer())
  end function

  sub newGame()
    m.flags.clear()
    m.inventory.clear()
    m.getPlayer().resetForNewGame()
    m.syncPlayer()
  end sub

  ' @param {object} save - from readSave()
  sub loadSave(save as object)
    m.flags.loadAA(save.flags)
    m.inventory.loadAA(save.inventory)
    m.getPlayer().applySavedStats(save.player)
    m.syncPlayer()
  end sub

  ' Jumps to a numbered story checkpoint (--param stage=N).
  sub applyCheckpoint(n as integer)
    m.newGame()
    state = checkpointState(n)
    m.flags.loadAA(state.flags.toAA())
    m.inventory.loadAA(state.inventory.toAA())
    m.getPlayer().coins = state.coins
    m.syncPlayer()
  end sub

  ' @return {dynamic} the saved game, or invalid if there's none (or it's unreadable)
  function readSave() as dynamic
    return validateSaveData(BGE.registryRead(SAVE_SECTION, SAVE_KEY))
  end function

  sub deleteSave()
    section = CreateObject("roRegistrySection", SAVE_SECTION)
    section.Delete(SAVE_KEY)
    section.Flush()
  end sub

  ' Called by an area once it's built: remembers where to resume, and saves.
  sub arrivedAt(sceneName as string, spawn as string)
    m.sceneName = sceneName
    m.spawn = spawn
    m.save()
  end sub

  sub save()
    if not m.savingEnabled or m.sceneName = ""
      return
    end if
    BGE.registryWrite(SAVE_SECTION, SAVE_KEY, buildSaveData(m.sceneName, m.spawn, m.flags, m.inventory, m.getPlayer()))
    m.game.postGameEvent("storySaved")
  end sub

  override sub onGameEvent(eventName as string, data as roAssociativeArray)
    if eventName = "talkRequested"
      m.startDialogue(data.npcId)
    else if eventName = "inventoryRequested"
      m.openInventory()
    else if eventName = "enemyKilled"
      m.applyResult(runEventRules(getEventRules(), eventName, data, m.context()))
    end if
  end sub

  ' Called by the DialogueBox when the last page is read (choice is invalid without choices).
  sub finishDialogue(page as object, choice as dynamic)
    m.closeModal()
    if m.talkingNpc <> invalid and m.talkingNpc.isValid()
      m.talkingNpc.setTalking(false)
    end if
    m.talkingNpc = invalid
    m.applyResult(applyEffects(page.effects, m.context()))
    if choice <> invalid
      m.applyResult(applyEffects(choice.effects, m.context()))
      if choice.open = "shop"
        m.openShop()
      end if
    end if
  end sub

  ' Called by the DialogueBox when the player backs out: no effects run.
  sub cancelDialogue()
    m.closeModal()
    if m.talkingNpc <> invalid and m.talkingNpc.isValid()
      m.talkingNpc.setTalking(false)
    end if
    m.talkingNpc = invalid
  end sub

  function shopItems() as object
    return getShopItems()
  end function

  function priceOf(itemId as string) as integer
    for each row in getShopItems()
      if row.itemId = itemId
        return row.price
      end if
    end for
    return 0
  end function

  ' @return {object} {ok, reason}
  function buy(itemId as string) as object
    ctx = m.context()
    result = buyItem(itemId, m.priceOf(itemId), ctx)
    if result.ok
      m.game.playSound("coin")
      m.applyResult({changed: true, posts: []})
    end if
    return result
  end function

  ' @return {object} {ok, reason}
  function use(itemId as string) as object
    result = useItem(itemId, m.context())
    if result.ok
      m.applyResult({changed: true, posts: []})
    end if
    return result
  end function

  function objectives() as object
    return currentObjectives(getQuestData(), m.flags)
  end function

  ' Panels call these so the game stays paused while any of them is open.
  sub openModal()
    if m.modalCount = 0
      m.game.Pause()
    end if
    m.modalCount++
  end sub

  sub closeModal()
    if m.modalCount > 0
      m.modalCount--
      if m.modalCount = 0
        m.game.Resume()
      end if
    end if
  end sub

  function isModalOpen() as boolean
    return m.modalCount > 0
  end function

  ' Settles the story after a change, posts what the rules asked for, keeps the player's
  ' sword in step with the inventory, and saves.
  private sub applyResult(result as object)
    if not result.changed and result.posts.count() = 0
      return
    end if
    settled = settleStory(getEventRules(), m.context())
    m.syncPlayer()
    posts = []
    posts.append(result.posts)
    posts.append(settled.posts)
    m.save()
    for each eventName in posts
      m.game.postGameEvent(eventName)
    end for
  end sub

  private sub syncPlayer()
    m.getPlayer().swordDamage = swordDamageFor(m.inventory)
  end sub

  private sub startDialogue(npcId as string)
    if m.isModalOpen()
      return
    end if
    page = selectDialoguePage(getDialogueData()[npcId], m.context())
    if page = invalid
      return
    end if
    for each entity in m.game.getEntitiesByTag("npc")
      npcEntity = entity as Npc
      if npcEntity.npcId = npcId
        m.talkingNpc = npcEntity
      end if
    end for
    playerEntity = m.getPlayer()
    if m.talkingNpc <> invalid
      m.talkingNpc.setTalking(true)
      m.talkingNpc.faceToward(playerEntity.position.x, playerEntity.position.y)
    end if
    m.openModal()
    box = new DialogueBox(m.game, page, m.flags)
    box.open(m.game.gameUi)
  end sub

  private sub openShop()
    m.openModal()
    panel = new ShopPanel(m.game)
    panel.open(m.game.gameUi)
  end sub

  private sub openInventory()
    if m.isModalOpen() or m.game.isTransitioning()
      return
    end if
    m.openModal()
    panel = new InventoryPanel(m.game)
    panel.open(m.game.gameUi)
  end sub

  private function getPlayer() as Player
    return m.game.getEntityByName("Player") as Player
  end function

end class
```

Note that `applyResult` posts `gateOpened` after saving, so a reload triggered by it starts from a save that already has the gate open.

- [ ] **Step 4: Create the `Story` in `main.bs`**

After the HUD is added, add `import "Story/Story.bs"` at the top, and:

```brighterscript
  ' Persistent and never paused - owns the story state and opens the dialogue/shop/inventory panels.
  story = new Story(game)
  game.addEntity(story)
```

`DialogueBox`, `ShopPanel` and `InventoryPanel` don't exist until Tasks 11-12. Create each as a stub in this task so the branch validates: an empty `BGE.UI.UiContainer` subclass with the constructor the Story calls (`DialogueBox(game, page, flags)`, `ShopPanel(game)`, `InventoryPanel(game)`), plus `sub open(parent as BGE.UI.UiContainer)` and `sub onAction(actionId as string)` that do nothing. Tasks 11-12 replace them.

- [ ] **Step 5: Validate**

Run: `cd examples/rpg && npm test && npx bsc --create-package=false`
Expected: PASS, no diagnostics.

- [ ] **Step 6: Commit**

```bash
git add examples/rpg/src/source
git commit -m "rpg: add the Story entity; enemies report kills, the player talks (#257)"
```

### Task 11: `MenuPanel` and `DialogueBox`

**Files:**
- Create: `examples/rpg/src/source/UI/MenuPanel.bs`
- Replace the stub: `examples/rpg/src/source/UI/DialogueBox.bs`

**Interfaces:**
- Consumes: `BGE.UI.wrapText`, `Label.wrapWidth` (Tasks 1-2), `interpolateFlags` (Task 5), `Story.finishDialogue`/`cancelDialogue` (Task 10).
- Produces:
  - `class ActionButton extends BGE.UI.Button`, with `actionId as string`, `listenerName as string` and `notifyListener()`.
  - `class MenuPanel extends BGE.UI.UiContainer`. A positioned panel with an optional title, a wrapped message, an optional icon row hook, and a vertical stack of `ActionButton`s.
    - Constructor: `sub new(game, x, y, w, listenerName as string)`.
    - Methods: `setTitle(text)`, `setMessage(text)`, `addAction(actionId, label)`.
    - Lifecycle: `open(parent)` builds the children, focuses the first button and adds itself; `close(parent)` removes itself.
    - A pressed button calls `onMenuAction(actionId)` on its listener: the entity named `listenerName`, or the current scene if that's its name. Anonymous subs don't close over locals, so the button carries what the handler needs.
  - `class DialogueBox extends BGE.UI.UiContainer`, with `sub new(game, page as object, flags as StoryFlags)` and `sub open(parent)`.
  - `const UI_SAFE = 0.1`: the title-safe fraction, shared by every panel.

- [ ] **Step 1: Write `MenuPanel.bs`**

```brighterscript
' examples/rpg/src/source/UI/MenuPanel.bs
import "pkg:/source/engine/ui/UiContainer.bs"
import "pkg:/source/engine/ui/Label.bs"
import "pkg:/source/engine/ui/Button.bs"

' Every panel stays this fraction in from each edge of the UI canvas.
const UI_SAFE = 0.1
const MENU_PADDING = 20.0
const MENU_BUTTON_H = 52.0
const MENU_BUTTON_GAP = 10.0
const MENU_TEXT_RGBA = &hF5E6C8FF
const MENU_TITLE_RGBA = &hFFD966FF
const MENU_BACKGROUND_RGBA = &h1A120CE6

' A button that knows which action it stands for, and who to tell: an entity by name, or the
' current scene (scenes aren't findable with getEntityByName).
class ActionButton extends BGE.UI.Button
  actionId as string = ""
  listenerName as string = ""

  sub new(game as BGE.Game)
    super(game)
    m.onActivate = sub(clicked as BGE.UI.Button)
      actionButton = clicked as ActionButton
      actionButton.notifyListener()
    end sub
  end sub

  sub notifyListener()
    scene = m.game.getScene()
    listener = invalid
    if scene <> invalid and scene.name = m.listenerName
      listener = scene
    else if m.game.getAllEntities(m.listenerName).count() > 0
      listener = m.game.getEntityByName(m.listenerName)
    end if
    if listener <> invalid
      dynamicListener = listener as dynamic
      dynamicListener.onMenuAction(m.actionId)
    end if
  end sub
end class

' A positioned panel: optional title, wrapped message, then a column of buttons. Build it fresh
' each time it opens and close() it when done - buttons register with the FocusManager the
' moment they're added. Pressing a button calls onMenuAction(panel, actionId) on the entity
' named listenerName.
class MenuPanel extends BGE.UI.UiContainer

  panelId as string = ""
  title as string = ""
  message as string = ""
  listenerName as string = ""
  buttons as object = []
  ' Extra space below the message for content a subclass draws itself (e.g. item icons).
  contentHeight as float = 0
  protected contentTop as float = 0
  private actions as object = []
  private messageLabel as BGE.UI.Label = invalid

  sub new(game as BGE.Game, x as float, y as float, w as float, listenerName as string)
    super(game)
    m.customPosition = true
    m.customX = x
    m.customY = y
    m.width = w
    m.backgroundRGBA = MENU_BACKGROUND_RGBA
    m.listenerName = listenerName
  end sub

  sub addAction(actionId as string, label as string)
    m.actions.push({actionId: actionId, label: label})
  end sub

  ' Updates the message line on an open panel (e.g. "Not enough coins").
  sub setMessage(text as string)
    m.message = text
    if m.messageLabel <> invalid
      m.messageLabel.setText(text)
    end if
  end sub

  sub open(parent as BGE.UI.UiContainer)
    m.clearChildren()
    m.buttons = []
    font = m.game.getFont("hud")
    lineHeight = font.GetOneLineHeight()
    innerWidth = m.width - MENU_PADDING * 2
    nextY = MENU_PADDING
    if m.title <> ""
      titleLabel = new BGE.UI.Label(m.game)
      titleLabel.customPosition = true
      titleLabel.customX = MENU_PADDING
      titleLabel.customY = nextY
      titleLabel.setText(m.title)
      titleLabel.drawableText.textColor = MENU_TITLE_RGBA
      m.addChild(titleLabel)
      nextY += lineHeight + MENU_BUTTON_GAP
    end if
    m.messageLabel = new BGE.UI.Label(m.game)
    m.messageLabel.customPosition = true
    m.messageLabel.customX = MENU_PADDING
    m.messageLabel.customY = nextY
    m.messageLabel.wrapWidth = innerWidth
    m.messageLabel.drawableText.textColor = MENU_TEXT_RGBA
    m.messageLabel.setText(m.message)
    m.addChild(m.messageLabel)
    messageLines = BGE.UI.wrapText(m.message, font, innerWidth).count()
    if m.message = ""
      messageLines = 0
    end if
    nextY += messageLines * lineHeight + MENU_BUTTON_GAP
    m.contentTop = nextY
    nextY += m.contentHeight
    for each action in m.actions
      button = new ActionButton(m.game)
      button.actionId = action.actionId
      button.listenerName = m.listenerName
      button.setLabel(action.label)
      button.customPosition = true
      button.customX = MENU_PADDING
      button.customY = nextY
      button.width = innerWidth
      button.height = MENU_BUTTON_H
      m.addChild(button)
      m.buttons.push(button)
      nextY += MENU_BUTTON_H + MENU_BUTTON_GAP
    end for
    m.height = nextY + MENU_PADDING - MENU_BUTTON_GAP
    parent.addChild(m)
    if m.buttons.count() > 0
      m.game.focusManager.focusWidget(m.buttons[0])
    end if
  end sub

  sub close(parent as BGE.UI.UiContainer)
    parent.removeChild(m)
  end sub

end class
```

The listeners (`Story`, `TitleScene`) implement `sub onMenuAction(actionId as string)`. `ActionButton` sets its own `onActivate` in its constructor, so panels only set `actionId` and `listenerName`.

Inside `DialogueBox` and the panels, `onInput` must handle Back with `input.press and input.isButton("back")` and call `input.consume()` on every event while open, so nothing reaches gameplay.

- [ ] **Step 2: Write `DialogueBox.bs`**

```brighterscript
' examples/rpg/src/source/UI/DialogueBox.bs
import "pkg:/source/engine/ui/UiContainer.bs"
import "pkg:/source/engine/ui/Label.bs"
import "pkg:/source/engine/ui/TextWrap.bs"
import "MenuPanel.bs"
import "../Story/StoryFlags.bs"
import "../Story/Text.bs"

const DIALOGUE_LINES_PER_PAGE = 3

' A conversation along the bottom of the screen: the speaker's name, then the text three lines at
' a time. OK turns the page; on the last page OK finishes (or the choices appear, if any). Back
' leaves without the page's effects. The Story pauses the game while it's open.
class DialogueBox extends BGE.UI.UiContainer

  private page as object = invalid
  private pages as object = []
  private pageIndex as integer = 0
  private body as BGE.UI.Label = invalid
  private more as BGE.UI.Label = invalid
  private choiceButtons as object = []
  ' Frames to wait before adding choice buttons (-1 = none pending). See showPage().
  private choicesDelay as integer = -1
  private parentUi as BGE.UI.UiContainer = invalid

  ' @param {object} page - a dialogue page (DialogueData.bs)
  ' @param {StoryFlags} flags - for ${key} in the lines
  sub new(game as BGE.Game, page as object, flags as object)
    super(game)
    m.name = "DialogueBox"
    m.page = page
    m.customPosition = true
    m.backgroundRGBA = MENU_BACKGROUND_RGBA
    uiW = game.uiCanvas.getWidth()
    uiH = game.uiCanvas.getHeight()
    font = game.getFont("hud")
    lineHeight = font.GetOneLineHeight()
    m.width = uiW * (1 - UI_SAFE * 2)
    m.height = MENU_PADDING * 2 + lineHeight * (DIALOGUE_LINES_PER_PAGE + 1) + MENU_BUTTON_GAP
    m.customX = uiW * UI_SAFE
    m.customY = uiH * (1 - UI_SAFE) - m.height
    ' Each entry in lines starts a new page; long ones spill onto more pages.
    innerWidth = m.width - MENU_PADDING * 2
    m.pages = []
    for each line in page.lines
      wrapped = BGE.UI.wrapText(interpolateFlags(line, flags), font, innerWidth)
      for i = 0 to wrapped.count() - 1 step DIALOGUE_LINES_PER_PAGE
        lastIndex = i + DIALOGUE_LINES_PER_PAGE - 1
        if lastIndex > wrapped.count() - 1
          lastIndex = wrapped.count() - 1
        end if
        pageLines = []
        for j = i to lastIndex
          pageLines.push(wrapped[j])
        end for
        m.pages.push(pageLines.join(Chr(10)))
      end for
    end for
  end sub

  sub open(parent as BGE.UI.UiContainer)
    m.parentUi = parent
    font = m.game.getFont("hud")
    lineHeight = font.GetOneLineHeight()
    speaker = new BGE.UI.Label(m.game)
    speaker.customPosition = true
    speaker.customX = MENU_PADDING
    speaker.customY = MENU_PADDING
    speaker.setText(m.page.speaker)
    speaker.drawableText.textColor = MENU_TITLE_RGBA
    m.addChild(speaker)
    m.body = new BGE.UI.Label(m.game)
    m.body.customPosition = true
    m.body.customX = MENU_PADDING
    m.body.customY = MENU_PADDING + lineHeight + MENU_BUTTON_GAP
    m.body.drawableText.textColor = MENU_TEXT_RGBA
    m.addChild(m.body)
    m.more = new BGE.UI.Label(m.game)
    m.more.customPosition = true
    m.more.customX = m.width - MENU_PADDING - font.GetOneLineWidth("...", 1000)
    m.more.customY = m.height - MENU_PADDING - lineHeight
    m.more.drawableText.textColor = MENU_TITLE_RGBA
    m.addChild(m.more)
    m.showPage(0)
    parent.addChild(m)
  end sub

  override sub onInput(input as BGE.GameInput)
    super.onInput(input)
    input.consume()
    if not input.press
      return
    end if
    if input.isButton("back")
      m.close()
      story = m.game.getEntityByName("Story") as dynamic
      story.cancelDialogue()
    else if input.isButton("ok") and m.choicesDelay < 0 and m.choiceButtons.count() = 0
      if m.pageIndex < m.pages.count() - 1
        m.showPage(m.pageIndex + 1)
      else
        m.finish(invalid)
      end if
    end if
  end sub

  override sub onUpdate(deltaTime as float)
    super.onUpdate(deltaTime)
    if m.choicesDelay = 0
      m.choicesDelay = -1
      m.showChoices()
    else if m.choicesDelay > 0
      m.choicesDelay--
    end if
  end sub

  ' Called by a choice button (through the Story's onMenuAction).
  sub chooseIndex(index as integer)
    m.finish(m.page.choices[index])
  end sub

  private sub showPage(index as integer)
    m.pageIndex = index
    m.body.setText(m.pages[index])
    isLast = index = m.pages.count() - 1
    if isLast and m.page.choices <> invalid
      ' The FocusManager handles this frame's OK press after UI onInput, so a button added
      ' now would be clicked by the press that turned the page. Wait a frame first.
      m.choicesDelay = 1
      m.more.setText("")
    else if not isLast
      m.more.setText("...")
    else
      m.more.setText("")
    end if
  end sub

  ' A row of choice buttons along the bottom of the last page.
  private sub showChoices()
    buttonW = (m.width - MENU_PADDING * 2 - MENU_BUTTON_GAP * (m.page.choices.count() - 1)) / m.page.choices.count()
    for i = 0 to m.page.choices.count() - 1
      button = new ActionButton(m.game)
      button.actionId = "choice" + i.toStr()
      button.listenerName = "Story"
      button.setLabel(m.page.choices[i].label)
      button.customPosition = true
      button.customX = MENU_PADDING + i * (buttonW + MENU_BUTTON_GAP)
      button.customY = m.height - MENU_PADDING - MENU_BUTTON_H
      button.width = buttonW
      button.height = MENU_BUTTON_H
      m.addChild(button)
      m.choiceButtons.push(button)
    end for
    m.game.focusManager.focusWidget(m.choiceButtons[0])
  end sub

  private sub finish(choice as dynamic)
    m.close()
    story = m.game.getEntityByName("Story") as dynamic
    story.finishDialogue(m.page, choice)
  end sub

  private sub close()
    if m.parentUi <> invalid
      m.parentUi.removeChild(m)
      m.parentUi = invalid
    end if
  end sub

end class
```

The choices appear on their own with the last page (no extra OK), one frame after it shows: `Game.processUiInput()` runs `gameUi`'s `onInput`/`onUpdate` before `FocusManager.update()` for the same events, so a button focused during the page-turning press would be clicked by it. A choice's row of buttons sits over the last page's third line. If the text runs into the buttons on device, drop `DIALOGUE_LINES_PER_PAGE` to 2 for a page that has choices. Check this on device in Step 4.

The Down arrow moves focus between choice buttons in `list` mode. Left/Right also step, since list mode treats any direction as next/previous.

- [ ] **Step 3: Route choice buttons and panel buttons through the Story**

Add to `Story.bs`:

```brighterscript
  ' The panel currently open (DialogueBox, ShopPanel or InventoryPanel), so button actions reach it.
  private openPanel as dynamic = invalid

  ' Called by panel buttons (see MenuPanel/ActionButton).
  sub onMenuAction(actionId as string)
    if m.openPanel <> invalid
      m.openPanel.onAction(actionId)
    end if
  end sub
```

Set `m.openPanel = box` in `startDialogue`, `m.openPanel = panel` in `openShop`/`openInventory`, and clear it (`m.openPanel = invalid`) at the start of `finishDialogue`, `cancelDialogue` and a new `panelClosed()` that the shop and inventory call when they close. `DialogueBox` gets:

```brighterscript
  sub onAction(actionId as string)
    if Left(actionId, 6) = "choice"
      m.chooseIndex(Mid(actionId, 7).toInt())
    end if
  end sub
```

- [ ] **Step 4: Check on device**

Use the rokubot-examples skill: build, sideload, then `rokubot launch dev --param scene=TownScene --param stage=0`. That deep link exists after Task 15. Until then, temporarily place an NPC beside the spawn to test. Walk up to Bram (or a temporary NPC), press OK and screenshot. Check:
- The box sits inside the title-safe area, and the speaker's name and wrapped text are readable.
- OK pages through, and closing doesn't swing the sword (watch for no swing sound or animation after the last OK).
- Back closes without effects.
- Rats freeze while the box is open.

- [ ] **Step 5: Commit**

```bash
git add examples/rpg/src/source/UI examples/rpg/src/source/Story/Story.bs
git commit -m "rpg: add the dialogue box and menu panels (#257)"
```

### Task 12: Shop, inventory and the save note

**Files:**
- Replace the stubs: `examples/rpg/src/source/UI/ShopPanel.bs`, `UI/InventoryPanel.bs`
- Create: `examples/rpg/src/source/UI/SaveIndicator.bs`
- Modify: `examples/rpg/src/source/Story/Story.bs` (`panelClosed`), `main.bs` (add the SaveIndicator), `Scenes/AreaScene.bs` (Play/Pause posts `inventoryRequested`)

**Interfaces:**
- Consumes: `MenuPanel`, `ActionButton` (Task 11). `Story.buy`/`use`/`objectives`/`shopItems`/`panelClosed` (Task 10).
- Produces:
  - `ShopPanel extends MenuPanel` and `InventoryPanel extends MenuPanel`. Each has `sub new(game as BGE.Game)`, `sub open(parent)` and `sub onAction(actionId as string)`.
  - `SaveIndicator extends BGE.UI.UiWidget`. It listens for `storySaved` through `onGameEvent`.

- [ ] **Step 1: `ShopPanel`**

```brighterscript
' examples/rpg/src/source/UI/ShopPanel.bs
import "MenuPanel.bs"
import "../Story/Items.bs"

' Hilde's wares: one button per item with its price, then Leave. A refusal (too few coins,
' already owned) shows in the message line.
class ShopPanel extends MenuPanel

  private parentUi as BGE.UI.UiContainer = invalid

  sub new(game as BGE.Game)
    uiW = game.uiCanvas.getWidth()
    uiH = game.uiCanvas.getHeight()
    super(game, uiW * 0.3, uiH * UI_SAFE, uiW * 0.4, "Story")
    m.name = "ShopPanel"
    m.title = "Hilde's Wares"
    m.message = "What'll it be?"
  end sub

  override sub open(parent as BGE.UI.UiContainer)
    m.parentUi = parent
    story = m.game.getEntityByName("Story") as dynamic
    definitions = getItemDefinitions()
    for each row in story.shopItems()
      label = definitions[row.itemId].name + " - " + row.price.toStr()
      if not story.inventory.canAdd(row.itemId)
        if definitions[row.itemId].max = 1
          label = label + " (owned)"
        else
          label = label + " (full)"
        end if
      end if
      m.addAction(row.itemId, label)
    end for
    m.addAction("leave", "Leave")
    super.open(parent)
  end sub

  sub onAction(actionId as string)
    story = m.game.getEntityByName("Story") as dynamic
    if actionId = "leave"
      m.leave()
      return
    end if
    result = story.buy(actionId)
    if result.ok
      ' Rebuilt so the labels show (owned)/(full); the story has already saved.
      m.close(m.parentUi)
      story.panelClosed()
      story.reopenShop()
    else
      m.setMessage(result.reason)
    end if
  end sub

  override sub onInput(input as BGE.GameInput)
    super.onInput(input)
    input.consume()
    if input.press and input.isButton("back")
      m.leave()
    end if
  end sub

  private sub leave()
    m.close(m.parentUi)
    story = m.game.getEntityByName("Story") as dynamic
    story.panelClosed()
  end sub

end class
```

`MenuPanel.open` is a `sub` in the base class, so subclasses mark theirs `override`. Also add these to `Story.bs`:

```brighterscript
  ' Called by a shop/inventory panel once it has removed itself.
  sub panelClosed()
    m.openPanel = invalid
    m.closeModal()
  end sub

  ' Reopens the shop after a purchase, so its labels reflect what's owned.
  sub reopenShop()
    m.openShop()
  end sub
```

Make `openShop` set `m.openPanel = panel`.

The "rebuild after buying" flow closes and reopens the modal, so the game resumes and re-pauses inside one call. That's harmless. If the brief unpause causes a visible stutter, change `panelClosed`/`openShop` so a reopen keeps `modalCount` above 0, by calling `openShop()` before `closeModal()`.

- [ ] **Step 2: `InventoryPanel`**

```brighterscript
' examples/rpg/src/source/UI/InventoryPanel.bs
import "MenuPanel.bs"
import "../Story/Items.bs"
import "../Entities/Player.bs"

const INVENTORY_ICON_GAP = 12.0

' What you're carrying (drawn as icons with counts), your current quest objectives, and buttons
' to drink a potion or close. Play/Pause or Back also closes it.
class InventoryPanel extends MenuPanel

  private parentUi as BGE.UI.UiContainer = invalid

  sub new(game as BGE.Game)
    uiW = game.uiCanvas.getWidth()
    uiH = game.uiCanvas.getHeight()
    super(game, uiW * 0.3, uiH * UI_SAFE, uiW * 0.4, "Story")
    m.name = "InventoryPanel"
    m.title = "Inventory"
    m.contentHeight = 34 * m.iconScale() + INVENTORY_ICON_GAP
  end sub

  override sub open(parent as BGE.UI.UiContainer)
    m.parentUi = parent
    story = m.game.getEntityByName("Story") as dynamic
    objectives = story.objectives()
    if objectives.count() = 0
      m.message = "Quest: none"
    else
      m.message = "Quest: " + objectives.join(". ")
    end if
    if story.inventory.has("potion")
      m.addAction("drink", "Drink potion")
    end if
    m.addAction("close", "Close")
    super.open(parent)
  end sub

  sub onAction(actionId as string)
    if actionId = "close"
      m.leave()
      return
    end if
    story = m.game.getEntityByName("Story") as dynamic
    result = story.use("potion")
    if result.ok
      m.game.playSound("coin")
      m.leave()
    else
      m.setMessage(result.reason)
    end if
  end sub

  override sub onInput(input as BGE.GameInput)
    super.onInput(input)
    input.consume()
    if input.press and (input.isButton("back") or input.isButton("play"))
      m.leave()
    end if
  end sub

  ' Item icons, each with a count: sword (rusty/steel), heart container if owned, potions, coins.
  override sub draw(parent = invalid as BGE.UI.UiWidget)
    super.draw(parent)
    story = m.game.getEntityByName("Story") as dynamic
    playerEntity = m.game.getEntityByName("Player") as Player
    renderer = m.canvas.renderer
    scale = m.iconScale()
    x = m.position.x + MENU_PADDING
    y = m.position.y + m.contentTop
    swordKey = "swordRusty"
    if story.inventory.has("steelSword")
      swordKey = "swordSteel"
    end if
    icons = [{key: swordKey, count: -1}]
    if story.inventory.has("heartContainer")
      icons.push({key: "heartIcon", count: -1})
    end if
    icons.push({key: "potion", count: story.inventory.count("potion")})
    icons.push({key: "coinIcon", count: playerEntity.coins})
    font = m.game.getFont("hud")
    for each icon in icons
      renderer.drawScaledObject(x, y, scale, scale, m.iconBitmap(icon.key))
      x += 34 * scale + 4
      if icon.count >= 0
        countText = "x" + icon.count.toStr()
        renderer.drawText(countText, x, y + 17 * scale, MENU_TEXT_RGBA, font, "left", "center")
        x += font.GetOneLineWidth(countText, 1000)
      end if
      x += INVENTORY_ICON_GAP
    end for
  end sub

  ' Integer scale for the 34px icons: 1x at 720p, 1x at 1080p (2x would crowd the panel).
  private function iconScale() as integer
    return 1
  end function

  ' The heart and coin are 9px, so they're drawn from 4x copies (built in main.bs).
  private function iconBitmap(key as string) as object
    return m.game.getBitmap(key)
  end function

  private sub leave()
    m.close(m.parentUi)
    story = m.game.getEntityByName("Story") as dynamic
    story.panelClosed()
  end sub

end class
```

In `main.bs`, build 4× copies of the 9px heart and coin for the panel icons, next to the existing `coinWorld` copy:

```brighterscript
  ' 4x copies of the 9px heart and coin, close to the 34px item icons in the inventory.
  game.loadBitmap("heartIcon", {width: 36, height: 36, AlphaEnable: true})
  game.getBitmap("heartIcon").DrawScaledObject(0, 0, 4, 4, game.getBitmap("heart"))
  game.loadBitmap("coinIcon", {width: 36, height: 36, AlphaEnable: true})
  game.getBitmap("coinIcon").DrawScaledObject(0, 0, 4, 4, game.getBitmap("coin"))
```

The panel's `contentHeight` reserves one icon row between the message and the buttons, so the icons never overlap text. `iconScale()` is fixed at 1; if 1080p icons look too small on device, return `Int(m.game.uiCanvas.getHeight() / 720)` instead.

- [ ] **Step 3: `SaveIndicator`**

```brighterscript
' examples/rpg/src/source/UI/SaveIndicator.bs
import "pkg:/source/engine/ui/UiWidget.bs"
import "MenuPanel.bs"

const SAVE_NOTE_HOLD = 1.0
const SAVE_NOTE_FADE = 0.5

' "Saving..." in the bottom-right title-safe corner after each autosave, fading out. Lives on
' gameUi for the whole game, like the HUD.
class SaveIndicator extends BGE.UI.UiWidget

  private shownFor as float = -1.0

  override sub onGameEvent(eventName as string, data as roAssociativeArray)
    if eventName = "storySaved"
      m.shownFor = 0.0
    end if
  end sub

  override sub onUpdate(deltaTime as float)
    if m.shownFor >= 0
      m.shownFor += deltaTime
      if m.shownFor > SAVE_NOTE_HOLD + SAVE_NOTE_FADE
        m.shownFor = -1.0
      end if
    end if
  end sub

  override sub draw(parent = invalid as BGE.UI.UiWidget)
    if m.shownFor < 0
      return
    end if
    alpha = 255
    if m.shownFor > SAVE_NOTE_HOLD
      alpha = Int(255 * (1 - (m.shownFor - SAVE_NOTE_HOLD) / SAVE_NOTE_FADE))
    end if
    canvasW = m.canvas.getWidth()
    canvasH = m.canvas.getHeight()
    color = (MENU_TEXT_RGBA and &hFFFFFF00) or alpha
    m.canvas.renderer.drawText("Saving...", Int(canvasW * (1 - UI_SAFE)), Int(canvasH * (1 - UI_SAFE)), color, m.game.getFont("hud"), "right", "bottom")
  end sub

end class
```

`UiWidget` extends `GameEntity`, whose hooks are `onUpdate(deltaTime as float)` and `onGameEvent(eventName as string, data as roAssociativeArray)`. `gameUi` forwards both to its children.

Packed RGBA math: `MENU_TEXT_RGBA and &hFFFFFF00` keeps the colour and clears the alpha byte.

In `main.bs`, after the HUD:

```brighterscript
  saveNote = new SaveIndicator(game)
  game.gameUi.addChild(saveNote)
```

- [ ] **Step 4: Play/Pause opens the inventory**

In `AreaScene.onInput`, add a branch:

```brighterscript
    else if input.press and input.isButton("play")
      m.game.postGameEvent("inventoryRequested")
```

`"play"` is `GameInput`'s name for the Play/Pause button (code 13).

- [ ] **Step 5: Check on device**

Use `--param scene=TownScene --param stage=3` (after Task 15) to start with 10 coins next to Hilde. Talk to her, choose Browse wares, buy the sword (the label then shows "(owned)"), and try the heart container (the message line shows "Not enough coins"). Open the inventory with Play/Pause: the steel sword icon shows, and the objective text reads "Enter the castle". The "Saving..." note appears after the purchase. Screenshot each, and check title-safe placement.

- [ ] **Step 6: Commit**

```bash
git add examples/rpg/src/source
git commit -m "rpg: add the shop, inventory and save note (#257)"
```

### Task 13: The smaller town, placement gating, NPC placements, gate reload

**Files:**
- Modify:
  - `examples/rpg/src/source/Maps/MapData.bs` (`getTownRows`, `getTownPlacements`, a new `npcSpawnPoint`)
  - `Scenes/AreaScene.bs` (filter placements, add NPCs, `arrivedAt`)
  - `Scenes/TownScene.bs` (gate reload)
- Test: `examples/rpg/tests/TownGate.spec.bs`, `examples/rpg/tests/EnemyPlacements.spec.bs`
- Modify: `examples/rpg/bsconfig.test.json` (the test files already need `Story/Conditions.bs` and its imports from Tasks 3-4)

**Interfaces:**
- Consumes: `filterPlacements`, `newStoryContext` (Task 4), `Npc` (Task 9), `Story.arrivedAt` (Task 10).
- Produces:
  - Placement kinds: `{type: "npc", npcId, character, col, row, facing, wander}` and `{type: "drain", col, row}` (Task 14).
  - `npcSpawnPoint(item, numRows) as object`. Returns `{x, y}`: the feet at the cell's horizontal middle (`(col + 0.5) * TILE_SIZE`), 6px above its bottom.
  - Town spawns: `start` (plaza), `gate` (in front of the gate), `sewer` (in front of the tunnel).

- [ ] **Step 1: New town map**

Replace `getTownRows()` with this 32×22 map. The wall runs along the top, broken by the gate (cols 14-16) and the tunnel path (cols 4-5). The plaza is in the centre, the market to the east, water on the west edge, and the dock in the south-west.

```brighterscript
function getTownRows() as string[]
  return [
    "################################",
    "################################",
    "##############ccc###############",
    "####cc########ccc###############",
    "~~..cc........ccc...............",
    "~~..cc........ccc...............",
    "~~..cc........ccc....ttttttt....",
    "~~..cc........ccc....ttttttt....",
    "~~..cccccccccccccccccttttttt....",
    "~~..cccccccccccccccccttttttt....",
    "~~.........ccccccc...ttttttt....",
    "~~.........ccccccc..............",
    "~~cccccccccccccccc..............",
    "~~cccccccccccccccc..............",
    "~~.........ccccccc..............",
    "~~..........ccc.................",
    "~~..........ccc.................",
    "~~~~~~......ccc.................",
    "~~~~~~......ccc.................",
    "~~~~~~......ccc.................",
    "~~~~~~......ccc.................",
    "~~~~~~......ccc................."
  ]
end function
```

Replace `getTownPlacements()`. Every `col`/`row` here follows the legend in MapData's header comment:

```brighterscript
function getTownPlacements() as object
  p = []
  ' Castle wall along the top, broken by two towers flanking the gate and by the sewer tunnel.
  pushWallRun(p, 0, 3, 3)
  pushWallRun(p, 6, 11, 3)
  pushWallRun(p, 19, 31, 3)
  p.push({atlasKey: "tower", col: 12, row: 3})
  p.push({atlasKey: "tower", col: 17, row: 3})
  p.push({atlasKey: "castleGate", col: 14, row: 3})
  ' The stone sides of the gate's arch (see Slice A), leaving the archway open.
  p.push({type: "solid", col: 14, row: 3, w: 0.5, h: 2})
  p.push({type: "solid", col: 16.5, row: 3, w: 0.5, h: 2})
  p.push({type: "door", col: 14.5, row: 3, w: 2, h: 2, target: "CastleScene", spawn: "entrance"})
  ' Until the knight lets you through: a plug across the archway, and the knight himself.
  p.push({type: "solid", col: 14, row: 4, w: 3, h: 2, when: [{notFlag: "gate.open"}]})
  p.push({type: "npc", npcId: "knight", character: "knight", col: 15, row: 6, facing: FacingDirection.down, wander: 0, when: [{notFlag: "gate.open"}]})
  p.push({type: "spawn", id: "gate", col: 15.5, row: 5, facing: FacingDirection.down})
  ' Sewer tunnel through the wall, north-west.
  ' 68px wide, centred over cols 4-5.
  p.push({atlasKey: "tunnel", col: 3.9375, row: 3})
  p.push({type: "door", col: 4, row: 3, w: 2, h: 1, target: "SewerScene", spawn: "entrance"})
  p.push({type: "spawn", id: "sewer", col: 5, row: 5, facing: FacingDirection.down})
  ' Plaza
  p.push({atlasKey: "fountain", col: 13.5, row: 12})
  p.push({atlasKey: "statue", col: 10, row: 12})
  p.push({atlasKey: "statue", col: 18, row: 12})
  p.push({atlasKey: "lampPost", col: 12, row: 10})
  p.push({atlasKey: "lampPost", col: 16, row: 10})
  p.push({atlasKey: "bench", col: 18, row: 16})
  p.push({type: "npc", npcId: "bram", character: "oldMan", col: 12, row: 13, facing: FacingDirection.down, wander: 0})
  p.push({type: "npc", npcId: "wanderPlaza", character: "blondeBoy", col: 16, row: 15, facing: FacingDirection.left, wander: 64})
  p.push({type: "spawn", id: "start", col: 14.5, row: 16, facing: FacingDirection.up})
  ' Market (east)
  p.push({atlasKey: "stallFront", col: 21, row: 6})
  p.push({atlasKey: "stallFront", col: 24, row: 6})
  p.push({atlasKey: "crateStack", col: 27, row: 7})
  p.push({atlasKey: "barrel", col: 27, row: 9})
  p.push({type: "npc", npcId: "hilde", character: "pinkGirl", col: 22, row: 7, facing: FacingDirection.down, wander: 0})
  p.push({type: "npc", npcId: "wanderMarket", character: "tealGirl", col: 25, row: 9, facing: FacingDirection.down, wander: 64})
  ' West: the well and the child
  p.push({atlasKey: "well", col: 6, row: 11})
  p.push({type: "npc", npcId: "child", character: "darkBoy", col: 8, row: 11, facing: FacingDirection.left, wander: 0})
  ' Waterfront (south-west)
  p.push({atlasKey: "dock", col: 1, row: 21})
  p.push({atlasKey: "bench", col: 7, row: 18})
  p.push({type: "npc", npcId: "oldWoman", character: "oldWoman", col: 9, row: 18, facing: FacingDirection.left, wander: 0})
  ' Rats
  p.push({type: "enemy", kind: "rat", col: 25, row: 16})
  p.push({type: "enemy", kind: "rat", col: 28, row: 12})
  p.push({type: "enemy", kind: "rat", col: 20, row: 20})
  p.push({type: "enemy", kind: "rat", col: 8, row: 7})
  return p
end function
```

Add, next to `enemySpawnPoint`:

```brighterscript
' Where an {type: "npc"} placement's feet start: the middle of its cell, a little above its bottom.
'
' @param {object} item - {col, row}
' @param {integer} numRows
' @return {object} {x, y}
function npcSpawnPoint(item as object, numRows as integer) as object
  return {x: (item.col + 0.5) * TILE_SIZE, y: cellBottomY(numRows, item.row) + 6}
end function
```

`col: 3.9375` is `5 - 68 / 2 / 32`, centring the 68px tunnel art over cols 4-5.

- [ ] **Step 2: Update and extend the placement tests**

`TownGate.spec.bs`: build the world from `filterPlacements(getTownPlacements(), ctx)`, where `ctx = newStoryContext(flags, new Inventory(getItemDefinitions()), {health: 6, maxHealth: 6, coins: 0})`.
- The existing lane test runs with `flags.set("gate.open", true)`, and the lanes become the new arch's opening: world x ≈ 464-528 (cols 14.5-16.5). Use `@params(468.0)`, `(480.0)`, `(496.0)`, `(512.0)`, `(524.0)`.
- The start y becomes `cellBottomY(22, 5) + 10`. Update every `32` row count to `22`.
- Add a test that walks straight up the centre lane with the gate shut (no `gate.open` flag): the feet box never overlaps the door zone, and stops below `cellBottomY(22, 4)`.

`EnemyPlacements.spec.bs`: `buildWorld(rows, placements)` already adds ground, placement solids, prop footprints and bounds. Callers pass it `filterPlacements(placements, ctx)` with a new-game context (`ctx = newStoryContext(new StoryFlags(), new Inventory(getItemDefinitions()), {health: 6, maxHealth: 6, coins: 0})`), so the gate plug is included like at runtime. NPC solids aren't in it, which is what the NPC test needs: each NPC is checked against everything except NPCs. Add:

```brighterscript
    @it("puts every town NPC on open ground")
    function _()
      rows = getTownRows()
      ctx = newStoryContext(new StoryFlags(), new Inventory(getItemDefinitions()), {health: 6, maxHealth: 6, coins: 0})
      placements = filterPlacements(getTownPlacements(), ctx)
      world = m.buildWorld(rows, placements)
      checked = 0
      for each item in placements
        if item.type = "npc"
          feet = npcSpawnPoint(item, rows.count())
          m.assertTrue(world.isAreaFree(feet.x - 10, feet.y, 20, 12), item.npcId + " starts inside a solid")
          checked++
        end if
      end for
      m.assertEqual(7, checked)
    end function

    @it("keeps every enemy clear of the still NPCs")
    function _()
      rows = getTownRows()
      numRows = rows.count()
      for each npc in getTownPlacements()
        if npc.type = "npc" and npc.wander = 0
          npcFeet = npcSpawnPoint(npc, numRows)
          for each enemy in getTownPlacements()
            if enemy.type = "enemy"
              feet = enemySpawnPoint(enemy, numRows)
              overlapX = Abs(feet.x - npcFeet.x) < (10 + ENEMY_SPAWN_CLEARANCE / 2)
              overlapY = feet.y < npcFeet.y + 12 and feet.y + ENEMY_SPAWN_CLEARANCE > npcFeet.y
              m.assertFalse(overlapX and overlapY, "rat at col " + enemy.col.toStr() + " spawns on " + npc.npcId)
            end if
          end for
        end if
      end for
    end function
```

The knight sits on the gate plug's row, so the plug must not cover his feet. The plug spans rows 3-4 and he stands in row 6; the first test fails if that drifts.

The existing enemy tests also switch to `filterPlacements(...)` with that new-game context, so a gated placement is built the way the game builds it.

Run: `cd examples/rpg && npm test`. Expected: FAIL until the map coordinates are right. Fix the coordinates (in MapData, not the test) until it passes.

- [ ] **Step 3: AreaScene builds gated placements and NPCs, and saves on arrival**

In `AreaScene.onCreate`, add these imports: `import "../Entities/Npc.bs"`, `import "../Story/Story.bs"`, `import "../Story/Conditions.bs"`. Replace each `m.getPlacements()` with one filtered list:

```brighterscript
    story = m.game.getEntityByName("Story") as Story
    placements = filterPlacements(m.getPlacements(), story.context())
```

Pass `placements` to `addPlacementSolids` and the loop. In the loop, add:

```brighterscript
      else if item.type = "npc"
        feet = npcSpawnPoint(item, numRows)
        newNpc = new Npc(m.game)
        m.game.addEntity(newNpc, {npcId: item.npcId, character: item.character, x: feet.x, y: feet.y, facing: item.facing, wander: item.wander * 1.0, solidWorld: m.solidWorld})
```

At the end of `onCreate`, after `camera.follow(...)`, add `story.arrivedAt(m.name, spawnId)`.

Wrap the `* 1.0` so `wander` arrives as a Float, since `Npc.wander` is typed `float` and the placement literal is an Integer.

`AreaScene.onInput`'s Back-to-exit doesn't run while a panel is open (the scene is paused), so nothing else needs to change there.

- [ ] **Step 4: TownScene reloads when the gate opens**

```brighterscript
  private reloadForGate as boolean = false

  override sub onGameEvent(eventName as string, data as roAssociativeArray)
    if eventName = "gateOpened"
      m.reloadForGate = true
    end if
  end sub

  ' Waits for the shop/dialogue to close, then rebuilds the town without the knight and plug.
  override sub onUpdate(dt as float)
    if m.reloadForGate and not m.game.isTransitioning()
      m.reloadForGate = false
      m.game.changeSceneWithFade("TownScene", {spawn: "gate"})
    end if
  end sub
```

The scene is pauseable, so `onUpdate` only runs once the panels have closed and the game has resumed.

- [ ] **Step 5: Check on device**

- With `--param stage=3`, buy the sword. After the shop closes, the town fades and reloads with the knight gone, and walking up the gate enters the castle.
- With `--param stage=0`, walking into the gate is blocked by the plug.
- Look over the new town layout in a few screenshots: nothing overlaps oddly, the NPCs stand on open ground, and the tunnel art lines up with the wall.

- [ ] **Step 6: Commit**

```bash
git add examples/rpg/src/source examples/rpg/tests
git commit -m "rpg: smaller town with NPCs, a gated castle gate (#257)"
```

### Task 14: The sewer

**Files:**
- Create:
  - `examples/rpg/src/source/Scenes/SewerScene.bs`
  - `World/RatSpawner.bs`
  - `World/Spawning.bs` (pure)
- Modify: `examples/rpg/src/source/Maps/MapData.bs` (`getSewerRows`, `getSewerPlacements`), `Scenes/AreaScene.bs` (collect drains), `main.bs` (define the scene)
- Test: `examples/rpg/tests/Spawning.spec.bs`, `examples/rpg/tests/EnemyPlacements.spec.bs`
- Modify: `examples/rpg/bsconfig.test.json` (add `Spawning.bs`)

**Interfaces:**
- Consumes: `Rat`, `enemySpawnPoint`, `AreaScene`.
- Produces:
  - `pickDrain(drains as object, playerX, playerY, minDistance as float, roll as float) as integer`. Drains are `[{x, y}]` and `roll` is in [0, 1). It returns the index of a drain at least `minDistance` from the player, chosen by `roll` among the eligible ones, or -1.
  - `const SEWER_MAX_RATS = 4`, `SEWER_SPAWN_SECONDS = 6.0`, `SEWER_SPAWN_MIN_DISTANCE = 96.0`.
  - `AreaScene.drains as object`: the feet points of every `drain` placement.

- [ ] **Step 1: Write the failing test**

```brighterscript
' examples/rpg/tests/Spawning.spec.bs
namespace tests
  @suite("rat spawning")
  class SpawningTests extends rooibos.BaseTestSuite

    @describe("pickDrain")

    @it("skips drains too close to the player")
    function _()
      drains = [{x: 10, y: 0}, {x: 500, y: 0}]
      m.assertEqual(1, pickDrain(drains, 0, 0, 96, 0.0))
      m.assertEqual(1, pickDrain(drains, 0, 0, 96, 0.99))
    end function

    @it("chooses among the eligible drains by roll")
    function _()
      drains = [{x: 200, y: 0}, {x: 400, y: 0}]
      m.assertEqual(0, pickDrain(drains, 0, 0, 96, 0.1))
      m.assertEqual(1, pickDrain(drains, 0, 0, 96, 0.9))
    end function

    @it("returns -1 when every drain is too close")
    function _()
      m.assertEqual(-1, pickDrain([{x: 10, y: 10}], 0, 0, 96, 0.5))
      m.assertEqual(-1, pickDrain([], 0, 0, 96, 0.5))
    end function

  end class
end namespace
```

- [ ] **Step 2: Run the test to check it fails**

Run: `cd examples/rpg && npm test`. Expected: a compile failure.

- [ ] **Step 3: Implement `Spawning.bs`**

```brighterscript
' examples/rpg/src/source/World/Spawning.bs

const SEWER_MAX_RATS = 4
const SEWER_SPAWN_SECONDS = 6.0
' A rat never appears closer to the player than this.
const SEWER_SPAWN_MIN_DISTANCE = 96.0

' @param {object} drains - [{x, y}]
' @param {float} playerX
' @param {float} playerY
' @param {float} minDistance
' @param {float} roll - 0 to <1, picks among the drains far enough away
' @return {integer} index into drains, or -1 if none is far enough away
function pickDrain(drains as object, playerX as float, playerY as float, minDistance as float, roll as float) as integer
  eligible = []
  for i = 0 to drains.count() - 1
    dx = drains[i].x - playerX
    dy = drains[i].y - playerY
    if dx * dx + dy * dy >= minDistance * minDistance
      eligible.push(i)
    end if
  end for
  if eligible.count() = 0
    return -1
  end if
  return eligible[Int(roll * eligible.count())]
end function
```

Run: `cd examples/rpg && npm test`. Expected: PASS.

- [ ] **Step 4: Sewer map**

```brighterscript
function getSewerRows() as string[]
  return [
    "bbbbbbbbbbbbbbbbbbbbbbbb",
    "bbbbbbbbbbbbbbbbbbbbbbbb",
    "bbssssssssssssssssssssbb",
    "bbssssssssssssssssssssbb",
    "bbss~~~~ssssssss~~~~ssbb",
    "bbss~~~~ssssssss~~~~ssbb",
    "bbssssssssbbbbssssssssbb",
    "bbssssssssbbbbssssssssbb",
    "bbbbssbbbbbbbbbbbbssbbbb",
    "bbbbssbbbbbbbbbbbbssbbbb",
    "bbssssssssssssssssssssbb",
    "bbss~~~~~~ssss~~~~~~ssbb",
    "bbss~~~~~~ssss~~~~~~ssbb",
    "bbssssssssssssssssssssbb",
    "bbssssssssssssssssssssbb",
    "bbbbbbbbbbbbbbbbbbbbbbbb"
  ]
end function

function getSewerPlacements() as object
  p = []
  ' The ladder back up to town, against the north wall.
  p.push({atlasKey: "ladder", col: 11.5, row: 1})
  p.push({type: "door", col: 11, row: 2, w: 2, h: 1, target: "TownScene", spawn: "sewer"})
  p.push({type: "spawn", id: "entrance", col: 12, row: 4, facing: FacingDirection.down})
  ' Rats, and the drains new ones crawl out of.
  p.push({type: "enemy", kind: "rat", col: 6, row: 3})
  p.push({type: "enemy", kind: "rat", col: 17, row: 3})
  p.push({type: "enemy", kind: "rat", col: 6, row: 13})
  p.push({type: "enemy", kind: "rat", col: 17, row: 13})
  p.push({type: "drain", col: 3, row: 7})
  p.push({type: "drain", col: 20, row: 7})
  p.push({type: "drain", col: 3, row: 14})
  p.push({type: "drain", col: 20, row: 14})
  return p
end function
```

The spawn at row 4 col 12 is open floor: row 4 is `bbss~~~~ssssssss~~~~ssbb`, and col 12 is `s`. The door is at row 2, two rows from the spawn, the same gap the castle uses.

In `EnemyPlacements.spec.bs`, add `@it("puts every sewer enemy on open ground")` (the same as the castle one, with `getSewerRows()`/`getSewerPlacements()`), and one that checks every `drain` placement with `enemySpawnPoint` and `isAreaFree` too.

- [ ] **Step 5: `AreaScene` collects drains, `RatSpawner`, `SewerScene`**

In `AreaScene`, add `drains as object = []`, reset it in `onCreate`, and in the placement loop:

```brighterscript
      else if item.type = "drain"
        m.drains.push(enemySpawnPoint(item, numRows))
```

```brighterscript
' examples/rpg/src/source/World/RatSpawner.bs
import "pkg:/source/utils/CountdownTimer.bs"
import "../Entities/Rat.bs"
import "../Maps/MapData.bs"
import "Spawning.bs"

' Keeps the sewer stocked: every few seconds, if fewer than SEWER_MAX_RATS are alive, a rat
' crawls out of a drain the player isn't standing near.
class RatSpawner extends BGE.GameEntity

  private drains as object = []
  private args as object = invalid
  private timer as BGE.CountdownTimer = new BGE.CountdownTimer()

  sub new(game as BGE.Game)
    super(game)
    m.name = "RatSpawner"
  end sub

  ' @param {roAssociativeArray} args - {drains: [{x, y}], solidWorld, mapWidth, mapHeight}
  override sub onCreate(args as roAssociativeArray)
    m.drains = args.drains
    m.args = args
    m.timer.start(SEWER_SPAWN_SECONDS)
  end sub

  override sub onUpdate(dt as float)
    m.timer.tick(dt)
    if m.timer.isActive()
      return
    end if
    m.timer.start(SEWER_SPAWN_SECONDS)
    alive = 0
    for each entity in m.game.getAllEntities("Rat")
      if not (entity as Enemy).isDying
        alive++
      end if
    end for
    playerEntity = m.game.getEntityByName("Player")
    if alive >= SEWER_MAX_RATS or playerEntity = invalid
      return
    end if
    index = pickDrain(m.drains, playerEntity.position.x, playerEntity.position.y, SEWER_SPAWN_MIN_DISTANCE, Rnd(0))
    if index < 0
      return
    end if
    drain = m.drains[index]
    newRat = new Rat(m.game)
    m.game.addEntity(newRat, {x: drain.x, y: drain.y, solidWorld: m.args.solidWorld, mapWidth: m.args.mapWidth, mapHeight: m.args.mapHeight})
  end sub

end class
```

`Enemy.isDying` is public, so `(entity as Enemy).isDying` type-checks with `import "../Entities/Enemy.bs"` (already reachable through `Rat.bs`, but import it explicitly).

```brighterscript
' examples/rpg/src/source/Scenes/SewerScene.bs
import "AreaScene.bs"
import "../Maps/MapData.bs"
import "../World/RatSpawner.bs"

' Under the town: a small maze where the witch's rats keep coming, for grinding coins.
class SewerScene extends AreaScene

  sub new(game as BGE.Game)
    super(game)
    m.name = "SewerScene"
  end sub

  override function getRows() as string[]
    return getSewerRows()
  end function

  override function getPlacements() as object
    return getSewerPlacements()
  end function

  override sub onCreate(args as roAssociativeArray)
    super.onCreate(args)
    spawner = new RatSpawner(m.game)
    m.game.addEntity(spawner, {drains: m.drains, solidWorld: m.solidWorld, mapWidth: m.mapWidth, mapHeight: m.mapHeight})
  end sub

end class
```

In `main.bs`, add `import "Scenes/SewerScene.bs"` and define the scene next to the others:

```brighterscript
  sewer = new SewerScene(game)
  game.defineScene(sewer)
```

- [ ] **Step 6: Test, then check on device**

Run: `cd examples/rpg && npm test && npx bsc --create-package=false`. Expected: PASS, no diagnostics.

On device, run `rokubot launch dev --param scene=SewerScene`. Screenshot the layout. Leave it about 15s with rats killed, and take a screenshot to see a new rat appear away from the player. Walk to the ladder and check you arrive in town at the tunnel. Ask the repo owner to play a few minutes of grinding and report how the spawn rate feels (real-time, so it's not driven through rokubot).

- [ ] **Step 7: Commit**

```bash
git add examples/rpg/src/source examples/rpg/tests examples/rpg/bsconfig.test.json
git commit -m "rpg: add the sewer, with rats that keep coming (#257)"
```

### Task 15: The title screen, Continue/New Game, deep links

**Files:**
- Create: `examples/rpg/src/source/Scenes/TitleScene.bs`, `UI/TitleBackground.bs`, `World/PlayerSetup.bs`
- Modify: `examples/rpg/src/source/main.bs`, `examples/rpg/src/source/UI/HeartsHud.bs`

**Interfaces:**
- Consumes: `MenuPanel` (Task 11). `Story.readSave`/`loadSave`/`newGame`/`deleteSave`/`applyCheckpoint`/`savingEnabled` (Task 10).
- Produces:
  - `TitleScene extends BGE.GameScene`, with `name = "TitleScene"` and `sub onMenuAction(actionId as string)` (actions `continue`, `newGame`).
  - `ensurePlayer(game)` in `World/PlayerSetup.bs`. The Player is created when a game starts, not at launch, so the HUD is blank on the title screen.

- [ ] **Step 1: `TitleBackground` and `TitleScene`**

```brighterscript
' examples/rpg/src/source/UI/TitleBackground.bs
import "pkg:/source/engine/ui/UiWidget.bs"

' The key art, scaled to fill the UI canvas.
class TitleBackground extends BGE.UI.UiWidget

  override sub draw(parent = invalid as BGE.UI.UiWidget)
    art = m.game.getBitmap("title")
    scaleX = m.canvas.getWidth() / art.GetWidth()
    scaleY = m.canvas.getHeight() / art.GetHeight()
    m.canvas.renderer.drawScaledObject(0, 0, scaleX, scaleY, art)
  end sub

end class
```

```brighterscript
' examples/rpg/src/source/Scenes/TitleScene.bs
import "../UI/MenuPanel.bs"
import "../UI/TitleBackground.bs"
import "../Story/Story.bs"
import "../World/PlayerSetup.bs"

' The first screen: the key art with Continue (when there's a save) and New Game on the left,
' below the logo. Back exits.
class TitleScene extends BGE.GameScene

  private background as TitleBackground = invalid
  private menu as MenuPanel = invalid

  sub new(game as BGE.Game)
    super(game)
    m.name = "TitleScene"
  end sub

  override sub onCreate(args as roAssociativeArray)
    uiW = m.game.uiCanvas.getWidth()
    uiH = m.game.uiCanvas.getHeight()
    m.background = new TitleBackground(m.game)
    m.game.gameUi.addChild(m.background)
    ' Left column, under the logo (which fills roughly the top third of the art).
    m.menu = new MenuPanel(m.game, uiW * UI_SAFE, uiH * 0.42, uiW * 0.24, "TitleScene")
    story = m.game.getEntityByName("Story") as Story
    if story.readSave() <> invalid
      m.menu.addAction("continue", "Continue")
    end if
    m.menu.addAction("newGame", "New Game")
    m.menu.open(m.game.gameUi)
  end sub

  sub onMenuAction(actionId as string)
    story = m.game.getEntityByName("Story") as Story
    m.leaveTitle()
    ensurePlayer(m.game)
    if actionId = "continue"
      save = story.readSave()
      story.loadSave(save)
      m.game.changeSceneWithFade(save.scene, {spawn: save.spawn})
    else
      story.deleteSave()
      story.newGame()
      m.game.changeSceneWithFade("TownScene", {spawn: "start"})
    end if
  end sub

  override sub onInput(input as BGE.GameInput)
    if input.press and input.isButton("back")
      m.game.End()
    end if
  end sub

  override sub onDestroy()
    m.leaveTitle()
  end sub

  private sub leaveTitle()
    if m.menu <> invalid
      m.menu.close(m.game.gameUi)
      m.menu = invalid
    end if
    if m.background <> invalid
      m.game.gameUi.removeChild(m.background)
      m.background = invalid
    end if
  end sub

end class
```

The background is added to `gameUi` before the menu, so the menu draws on top. The HUD and save note were added to `gameUi` in `main.bs` earlier, so they draw underneath the background; that's fine on this screen, since they draw nothing without a Player.

- [ ] **Step 2: `main.bs`: create the Player lazily, title first, deep links**

Create `examples/rpg/src/source/World/PlayerSetup.bs`, imported by both `main.bs` and `TitleScene.bs`:

```brighterscript
' examples/rpg/src/source/World/PlayerSetup.bs
import "../Entities/Player.bs"

' Creates the persistent player the first time a game starts. getAllEntities, not
' getEntityByName, so asking before it exists doesn't log a warning.
'
' @param {BGE.Game} game
sub ensurePlayer(game as BGE.Game)
  if game.getAllEntities("Player").count() = 0
    playerEntity = new Player(game)
    game.addEntity(playerEntity)
  end if
end sub
```

Remove the eager `playerEntity = new Player(game)` / `addEntity` from `main.bs`. Define `TitleScene`. Then replace the start logic:

```brighterscript
  title = new TitleScene(game)
  game.defineScene(title)
  ' (The Story entity is already created above, from Task 10.)

  ' Deep links for checking an area or story point directly; they never touch the real save.
  ' e.g. rokubot launch dev --param scene=TownScene --param stage=3
  if args.scene <> invalid or args.stage <> invalid
    story.savingEnabled = false
    ensurePlayer(game)
    story.newGame()
    if args.stage <> invalid
      story.applyCheckpoint(args.stage.toInt())
    end if
    startScene = "TownScene"
    if args.scene <> invalid
      startScene = args.scene
    end if
    game.changeSceneWithFade(startScene, {spawn: "start"})
  else
    game.changeSceneWithFade("TitleScene", {})
  end if
```

`HeartsHud.draw()` looks the player up every frame with `getEntityByName("Player")`, which logs a warning each time it's missing. On the title screen that would flood the log, so change its first lines to:

```brighterscript
    if m.game.getAllEntities("Player").count() = 0
      return
    end if
    playerEntity = m.game.getEntityByName("Player") as Player
```

`AreaScene` falls back to the first spawn when a spawn id isn't found, so `{spawn: "start"}` works for the castle and sewer too.

`Story.newGame()` calls `getPlayer().resetForNewGame()`, so `ensurePlayer` must run first. It does in both paths above.

- [ ] **Step 3: Check on device**

1. Delete any old save. In BrightScript it's easiest to choose New Game once, or to sideload fresh: a sideload doesn't clear the registry, so use `rokubot` to launch, then choose New Game. The title shows the key art, with New Game alone in the left column inside the title-safe area. Screenshot it.
2. Choose New Game. You arrive in the plaza at `start`, the HUD appears, and "Saving..." shows.
3. Talk to Bram (the quest starts and saves). Then relaunch (`rokubot launch dev`, no params). The title shows Continue, focused, above New Game.
4. Choose Continue. You're back in the town at `start`, and talking to Bram says "Still rats about. 0 of 4 so far."
5. Launch with `--param stage=4 --param scene=TownScene`, then relaunch without params: Continue still resumes the earlier real save, which shows deep links didn't overwrite it.

- [ ] **Step 4: Commit**

```bash
git add examples/rpg/src/source
git commit -m "rpg: add the title screen with Continue/New Game (#257)"
```

### Task 16: Docs, the full check, and the playthrough

**Files:**
- Modify: `CLAUDE.md` (the rpg bullet), `.claude/skills/rokubot-examples/SKILL.md` (rpg gotchas, if that file has an rpg section)

- [ ] **Step 1: CLAUDE.md**

In the `examples/rpg` bullet under "Conventions specific to this codebase", add a sentence block:

```markdown
**Story** (issue #257, `specs/2026-10-02-rpg-slice-c-story-design.md`): a generic, data-driven layer in `src/source/Story/` - `StoryFlags` (a key/value blackboard) and `Inventory`, plus conditions/effects as plain AAs used by dialogue pages (`DialogueData.bs`, first match wins), event rules (`EventRules.bs`, every match runs, then a `storyChanged` settle loop), the quest log, shop rules and save data. All of it is pure and tested in `examples/rpg/tests/`. It stays in the example until Slice D (#289) decides whether to promote it to the engine. Story data never uses `then` as a key (a reserved word) - pages and rules say `effects`, rules say `event`. A persistent, non-pauseable `Story` entity runs it, opens the dialogue box/shop/inventory (each pauses the game), and autosaves to the registry (`bge-rpg`/`save`) on arrival in an area, on story changes and on purchases. OK talks to an NPC (`Entities/Npc.bs`, tagged `npc`) in `talkBox(facing)` before it swings. Map placements may carry `when` conditions (the gate's knight and plug use `notFlag: "gate.open"`); the town reloads itself when the gate opens. Play/Pause opens the inventory. `--param stage=N` (0-4) jumps to a story checkpoint and, like `--param scene=`, turns saving off. The sewer (`SewerScene`) keeps up to 4 rats alive, spawning from drains at least 96px from the player.
```

- [ ] **Step 2: rokubot skill**

If `.claude/skills/rokubot-examples/SKILL.md` has an rpg section, add: "the rpg opens on a title screen. Use `--param scene=TownScene` (optionally with `--param stage=0-4`) to skip it, since deep links disable saving."

- [ ] **Step 3: The full check**

Run, from the repo root:

```bash
npm run check
cd examples/rpg && npm test && npx bsc --create-package=false
cd ../.. && npm run validate-examples
```

Expected: everything passes. If anything fails, follow the systematic-debugging skill before touching code.

- [ ] **Step 4: Full playthrough on device**

New Game → talk to Bram → kill 4 rats (the repo owner plays this part) → Bram rewards and vouches → the knight asks for a sword → buy it from Hilde → the town reloads with the gate open → walk into the castle. Then:
- relaunch and Continue (it resumes in the castle)
- visit the sewer from the town tunnel
- drink a potion from the inventory after taking damage

Screenshot each panel once more, for title safety.

- [ ] **Step 5: Commit, then finish the branch**

```bash
git add CLAUDE.md .claude/skills
git commit -m "Document the rpg story layer (#257)"
```

Then use superpowers:finishing-a-development-branch. The PR body uses the pr-voice skill and links #257, #289 and #290.
