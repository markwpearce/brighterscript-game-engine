# rpg Slice D2: Throne room, witch boss, ending — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Finish `examples/rpg`'s story: the throne key opens the great door, a witch boss fights in the throne room, her death clears the keep, Elder Bram closes the story, and a credits scene returns to the title. Dying anywhere in the keep returns the player to the entry hall with story state intact.

**Architecture:** Everything rides on the Slice C/D1 story layer (flags, conditions, effects, event rules, live placements). The witch is an `Enemy` subclass that owns her own cycle (volley → summon → shielded → exhausted, blink on hit) and spawns her own bolts and goblins; the scene only supplies summoning circles and perches through placements. Pure logic (keep-room rules, witch maths, credits data, story data) goes in engine-free files tested by the rpg Rooibos suite; entities are checked on a device by screenshot.

**Tech Stack:** BrighterScript (bsc 1.0.0-alpha), the BGE engine, Rooibos v6 (`cd examples/rpg && npm test`; engine gate `npm run check` from the repo root), rokubot for on-device screenshots.

**Spec:** `specs/2026-10-05-rpg-slice-d2-throne-room-design.md`

## Global Constraints

- One screen per room: 20×11 cells of 32px (`TILE_SIZE = 32`) on the 640×360 game canvas.
- All UI title-safe: ≥10% in from every canvas edge (`UI_SAFE = 0.1`).
- On-device checks are screenshots via deep-link params only. Never drive the player or fight through rokubot; the fight is played by hand.
- Prefer real types over `as object`/`as dynamic`; option bags are `interface ... extends roAssociativeArray` with `optional` fields.
- Every file that uses another file's symbol `import`s it.
- Never compare two class instances or native components with `=`; compare an `id`/`name` string.
- Guard one-shot input with `input.press`.
- Comments terse (the "why" only); doc comments written for a reader of the example.
- Story data never uses `then` as a key.
- New pure files must be added to `examples/rpg/bsconfig.test.json`'s `files` list, in dependency order.
- `assertEqual` is type-strict (Integer vs Float); read the failure diff when unsure.
- Commit after every task on branch `feature/issue-296-rpg-slice-d2-throne-room`, ending each message with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **Dying mid-fight with summons and bolts alive**: the respawn must land in the entry hall with nothing from the throne room carried over, and re-entering must rebuild a full-health witch without replaying the intro. Test: Task 2 (`defeatRespawn` for `ThroneRoomScene`), Task 4 (intro page gated on `throne.introSeen`); device check in Task 10.
2. **Old D1 saves**: a save holding `throneKey` with `dng.throneDoor.tried` set (great door closed) must still be able to open the door. Test: Task 3 ("opens the great door for a D1 save").
3. **Story rules settling at the new checkpoints**: the witch's `keep.stage = 4` must not fight the D1 `keep.stage lt 3` rule. Test: Task 4 (settle at checkpoints 7 and 8).
4. **Two dialogues wanting to open at once** (the witch's death message and a pending pickup message; the intro arriving during the fade): must queue, never stack two boxes. Covered by routing both through Story's existing pending queue in Tasks 1 and 8.
5. **Spawn points blocked** by the throne-room shutter or the dais: every spawn, enemy, drain and perch must sit on open ground with flags off and on. Test: Task 3 (the "open ground" test extended to `ThroneRoomScene` and to `perch`/`drain`).

---

## File map

**rpg, pure (tested)**
- Create `Maps/Keep.bs`: `getKeepScenes()`, `isKeepScene()`, `withKeepEnemiesGone()`, `defeatRespawn()`.
- Create `Entities/WitchLogic.bs`: `boltFan()`, `pickPerch()`, `isShielded()`, `witchIsPhaseTwo()`.
- Create `Story/CreditsData.bs`: `CreditLine`, `getCreditLines()`.
- Modify `Maps/MapTypes.bs` (`SpawnTarget`, placement types `perch`/`summonCircle`), `Maps/DungeonData.bs` (great door, throne room), `Story/StoryTypes.bs` (`StoryMessage`, `StoryEffect.speaker`), `Story/Effects.bs`, `Story/EventRules.bs`, `Story/QuestData.bs`, `Story/DialogueData.bs`, `Story/Checkpoints.bs`.

**rpg, entities/scenes/UI (device-checked)**
- Create `Entities/Witch.bs`, `Entities/WitchBolt.bs`, `World/SummonCircle.bs`, `Scenes/CreditsScene.bs`, `UI/CreditsRoll.bs`.
- Modify `Scenes/AreaScene.bs`, `Scenes/DungeonScenes.bs`, `Scenes/GoblinShowcaseScene.bs`, `Entities/Enemy.bs`, `Entities/Goblin.bs`, `Entities/GoblinKing.bs`, `Entities/Player.bs`, `Entities/DamageNumber.bs`, `UI/BossBar.bs`, `Story/Story.bs`, `main.bs`.

**Assets**: `src/sprites/witch.png` (copied from `~/Downloads/rpg/lpcfemalechainpreview.png`), `src/sprites/CREDITS.md`.

**Tests (`examples/rpg/tests/`)**: new `Keep.spec.bs`, `WitchLogic.spec.bs`, `Credits.spec.bs`; extended `Effects.spec.bs`, `EventRules.spec.bs`, `Dungeon.spec.bs`, `DialogueData.spec.bs`.

---

### Task 1: Speakered `message` effect

**Files:**
- Modify: `examples/rpg/src/source/Story/StoryTypes.bs` (`StoryEffect`, `StoryResult`)
- Modify: `examples/rpg/src/source/Story/Effects.bs:47-52,79-81`
- Modify: `examples/rpg/src/source/Story/Story.bs` (`pendingMessages`, `showMessage`, `onUpdate`, `tryUnlock`)
- Test: `examples/rpg/tests/Effects.spec.bs:83-97`, `examples/rpg/tests/EventRules.spec.bs:116-125`

**Interfaces:**
- Produces: `interface StoryMessage { text as string, speaker as string }`; `StoryResult.messages as StoryMessage[]`; `StoryEffect.speaker` (optional string); `Story.showMessage(text as string, speaker = "" as string)`.

- [ ] **Step 1: Update the failing tests**

In `tests/Effects.spec.bs`, replace the two `messages` tests and add a third:

```brighterscript
    @it("collects a message without counting it as a change")
    function _()
      result = applyEffects([{message: "Click."}], m.ctx)
      m.assertFalse(result.changed)
      m.assertEqual(1, result.messages.count())
      m.assertEqual("Click.", result.messages[0].text)
      m.assertEqual("", result.messages[0].speaker)
    end function

    @it("keeps messages in order alongside other effects")
    function _()
      result = applyEffects([{message: "One"}, {set: "a", value: true}, {message: "Two"}], m.ctx)
      m.assertTrue(result.changed)
      m.assertEqual("One", result.messages[0].text)
      m.assertEqual("Two", result.messages[1].text)
    end function

    @it("carries a message's speaker")
    function _()
      result = applyEffects([{message: "Come in, then.", speaker: "The Witch"}], m.ctx)
      m.assertEqual("The Witch", result.messages[0].speaker)
    end function
```

In `tests/EventRules.spec.bs` (the "passes a rule's messages through" test), change the two assertions to:

```brighterscript
      m.assertEqual("pong", runEventRules(rules, "ping", {}, m.ctx).messages[0].text)
      ...
      m.assertEqual("settled", settleStory(rules, m.ctx).messages[0].text)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd examples/rpg && npm test`
Expected: FAIL — `.text` on a string (type/validation error or assertion failure).

- [ ] **Step 3: Implement**

`StoryTypes.bs`: add `optional speaker as string` to `StoryEffect` (next to `message`, comment: `' message: who's speaking (none by default)`), add above `StoryResult`:

```brighterscript
' A message effect's text, and who says it ("" for none).
interface StoryMessage
  text as string
  speaker as string
end interface
```

and change `StoryResult.messages` to `messages as StoryMessage[]` (comment: `' message effects, in order`). Update the `StoryEffect` doc comment's list to mention `speaker` with `message`.

`Effects.bs`: the `message` branch becomes

```brighterscript
  else if effect.DoesExist("message")
    speaker = ""
    if effect.speaker <> invalid
      speaker = effect.speaker
    end if
    result.messages.push({text: effect.message, speaker: speaker})
    return false
```

and the `acquired.messages` loop pushes `message` (rename loop var `text` → `message`). Update `applyEffects`'s doc comment to `{message, speaker}`.

`Story.bs`:
- `private pendingMessages as StoryMessage[] = []`
- `showMessage`:

```brighterscript
  ' Shows a dialogue box (with no speaker unless one is given) once nothing else is open.
  sub showMessage(text as string, speaker = "" as string)
    m.pendingMessages.push({text: text, speaker: speaker})
  end sub
```

- in `onUpdate`, the message branch becomes:

```brighterscript
      message = m.pendingMessages.Shift()
      page = {speaker: message.speaker, lines: [message.text]} as DialoguePage
      m.openDialogue(page)
```

`EventRules.bs` needs no change (it only appends arrays).

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd examples/rpg && npm test` — Expected: PASS. Then `npx bsc --validate --create-package=false` in `examples/rpg` — Expected: no errors (`DialogueBox.open()` already draws `page.speaker` as a label, so a speakered message needs no UI change).

- [ ] **Step 5: Commit**

```bash
git add examples/rpg/src/source/Story examples/rpg/tests
git commit -m "rpg: message effect can name a speaker (#296)"
```

---

### Task 2: The keep's rooms, defeat respawn, and the keep at peace

**Files:**
- Create: `examples/rpg/src/source/Maps/Keep.bs`
- Modify: `examples/rpg/src/source/Maps/MapTypes.bs` (add `SpawnTarget`)
- Modify: `examples/rpg/src/source/Scenes/AreaScene.bs:76` (`m.placements = ...`)
- Modify: `examples/rpg/src/source/Entities/Player.bs:191-196`
- Modify: `examples/rpg/bsconfig.test.json` (add `source/Maps/Keep.bs` after `source/Maps/DungeonData.bs`)
- Test: `examples/rpg/tests/Keep.spec.bs`

**Interfaces:**
- Produces: `interface SpawnTarget { scene as string, spawn as string }`; `getKeepScenes() as string[]`; `isKeepScene(sceneName as string) as boolean`; `withKeepEnemiesGone(placements as MapPlacement[]) as MapPlacement[]`; `defeatRespawn(sceneName as string, lastSpawn as string) as SpawnTarget`; consts `KEEP_RESPAWN_SCENE = "CastleScene"`, `KEEP_RESPAWN_SPAWN = "entrance"`.

- [ ] **Step 1: Write the failing test** — `tests/Keep.spec.bs`:

```brighterscript
namespace tests
  @suite("the keep")
  class KeepTests extends rooibos.BaseTestSuite

    @describe("defeatRespawn")

    @it("sends a defeat anywhere in the keep back to the entry hall")
    @params("CastleScene")
    @params("GuardroomScene")
    @params("StoreroomScene")
    @params("BarracksScene")
    @params("AntechamberScene")
    @params("KingsHallScene")
    @params("ThroneRoomScene")
    function _(sceneName)
      target = defeatRespawn(sceneName, "fromS")
      m.assertEqual("CastleScene", target.scene)
      m.assertEqual("entrance", target.spawn)
    end function

    @it("reloads the same place outside the keep")
    @params("TownScene", "start")
    @params("SewerScene", "ladder")
    @params("GoblinShowcaseScene", "start")
    function _(sceneName, spawn)
      target = defeatRespawn(sceneName, spawn)
      m.assertEqual(sceneName, target.scene)
      m.assertEqual(spawn, target.spawn)
    end function

    @it("respawns at a spawn the entry hall really has")
    function _()
      found = false
      for each item in getAreaMaps()["CastleScene"].placements
        if item.type = "spawn" and item.id = "entrance"
          found = true
        end if
      end for
      m.assertTrue(found)
    end function

    @describe("withKeepEnemiesGone")

    @it("adds the witch condition to enemies only, keeping their own conditions")
    function _()
      placements = [
        {type: "enemy", kind: "goblin", col: 1, row: 1},
        {type: "enemy", kind: "goblinKing", col: 2, row: 2, when: [{notFlag: "dng.kingDefeated"}]},
        {type: "pot", col: 3, row: 3}
      ]
      result = withKeepEnemiesGone(placements)
      m.assertEqual(3, result.count())
      m.assertEqual("witch.defeated", result[0].when[0].notFlag)
      m.assertEqual(2, result[1].when.count())
      m.assertEqual("dng.kingDefeated", result[1].when[0].notFlag)
      m.assertEqual("witch.defeated", result[1].when[1].notFlag)
      m.assertInvalid(result[2].when)
    end function

    @it("doesn't change the placements it was given")
    function _()
      original = [{type: "enemy", kind: "goblin", col: 1, row: 1}]
      withKeepEnemiesGone(original)
      m.assertInvalid(original[0].when)
    end function

    @it("empties a keep room of enemies once the witch is defeated")
    function _()
      flags = new StoryFlags()
      flags.set("witch.defeated", true)
      ctx = newStoryContext(flags, new Inventory(getItemDefinitions()), {health: 6, maxHealth: 6, coins: 0})
      for each item in filterPlacements(withKeepEnemiesGone(getAreaMaps()["AntechamberScene"].placements), ctx)
        m.assertNotEqual("enemy", item.type)
      end for
    end function

    @it("knows the sewer isn't part of the keep")
    function _()
      m.assertFalse(isKeepScene("SewerScene"))
      m.assertTrue(isKeepScene("ThroneRoomScene"))
    end function

  end class
end namespace
```

(`ThroneRoomScene` doesn't exist in `getAreaMaps()` yet; nothing here reads its map.)

- [ ] **Step 2: Run to verify it fails**

Add `"source/Maps/Keep.bs"` to `bsconfig.test.json` after `"source/Maps/DungeonData.bs"`, then `cd examples/rpg && npm test`. Expected: FAIL — `defeatRespawn` not found (file missing).

- [ ] **Step 3: Implement**

`MapTypes.bs`, after `GateUnlock`:

```brighterscript
' A scene and a spawn point in it.
interface SpawnTarget
  scene as string
  spawn as string
end interface
```

`Maps/Keep.bs`:

```brighterscript
' Which areas are the keep, and the rules that apply to all of them.
import "MapTypes.bs"
import "../Story/StoryTypes.bs"

' Where the player comes back after a defeat anywhere in the keep: just inside the entry hall.
const KEEP_RESPAWN_SCENE = "CastleScene"
const KEEP_RESPAWN_SPAWN = "entrance"

' @return {string[]} scene names of every room in the keep
function getKeepScenes() as string[]
  return ["CastleScene", "GuardroomScene", "StoreroomScene", "BarracksScene", "AntechamberScene", "KingsHallScene", "ThroneRoomScene"]
end function

function isKeepScene(sceneName as string) as boolean
  for each name in getKeepScenes()
    if name = sceneName
      return true
    end if
  end for
  return false
end function

' Copies of placements in which every enemy also needs the witch alive, so the keep is empty
' once she's defeated.
'
' @param {MapPlacement[]} placements
' @return {MapPlacement[]}
function withKeepEnemiesGone(placements as MapPlacement[]) as MapPlacement[]
  result = [] as MapPlacement[]
  for each item in placements
    if item.type = "enemy"
      copy = {} as MapPlacement
      copy.Append(item)
      when = [] as StoryCondition[]
      if item.when <> invalid
        when.append(item.when)
      end if
      when.push({notFlag: "witch.defeated"})
      copy.when = when
      result.push(copy)
    else
      result.push(item)
    end if
  end for
  return result
end function

' Where a defeated player comes back: the entry hall from anywhere in the keep (story state
' is kept), otherwise the spawn they last arrived at.
'
' @param {string} sceneName - the scene the player was defeated in
' @param {string} lastSpawn - the spawn they last arrived at there
' @return {SpawnTarget}
function defeatRespawn(sceneName as string, lastSpawn as string) as SpawnTarget
  if isKeepScene(sceneName)
    return {scene: KEEP_RESPAWN_SCENE, spawn: KEEP_RESPAWN_SPAWN}
  end if
  return {scene: sceneName, spawn: lastSpawn}
end function
```

`AreaScene.bs`: import `"../Maps/Keep.bs"`; replace `m.placements = m.getPlacements()` with:

```brighterscript
    m.placements = m.getPlacements()
    if isKeepScene(m.name)
      m.placements = withKeepEnemiesGone(m.placements)
    end if
```

`Player.bs`: import `"../Maps/Keep.bs"`; in `onUpdate`'s defeated branch replace the `changeSceneWithFade` line with:

```brighterscript
        target = defeatRespawn(m.game.getScene().name, m.lastSpawn)
        m.game.changeSceneWithFade(target.scene, {spawn: target.spawn})
```

and change the `lastSpawn` field comment to `' The spawn point the player last arrived at (where it comes back after a defeat outside the keep).`

- [ ] **Step 4: Run to verify it passes**

Run: `cd examples/rpg && npm test` — Expected: PASS. `npx bsc --validate --create-package=false` in `examples/rpg` — no errors.

- [ ] **Step 5: Commit**

```bash
git add examples/rpg
git commit -m "rpg: a defeat in the keep returns to the entry hall; the keep empties once the witch is gone (#296)"
```

---

### Task 3: The great door opens, and the throne room map

**Files:**
- Modify: `examples/rpg/src/source/Maps/DungeonData.bs:253-291` (king's hall, new throne room, `getAreaMaps`)
- Modify: `examples/rpg/src/source/Maps/MapTypes.bs` (doc for `perch`/`summonCircle` types)
- Modify: `examples/rpg/src/source/Maps/Atlas.bs` (add `throneRug`)
- Modify: `examples/rpg/src/source/Scenes/AreaScene.bs` (`perches`, `perch`/`summonCircle` placements)
- Create: `examples/rpg/src/source/World/SummonCircle.bs`
- Modify: `examples/rpg/src/source/World/Prop.bs` (`floor` props)
- Modify: `examples/rpg/src/source/Scenes/DungeonScenes.bs` (add `ThroneRoomScene`)
- Modify: `examples/rpg/src/source/main.bs` (bitmap `throneRug`, `defineScene`)
- Test: `examples/rpg/tests/Dungeon.spec.bs`

**Interfaces:**
- Consumes: `pushRoomGate`, `pushRoomDoor`, `pushRoomSpawn`, `pushNorthArch`, `buildRoomRows` (existing, `DungeonData.bs`).
- Produces: `MapPlacement.floor` (a prop drawn at floor depth); `getThroneRoomRows() as string[]`, `getThroneRoomPlacements() as MapPlacement[]`; `AreaScene.perches as Point[]`; placement types `"perch"` (records a point) and `"summonCircle"` (records a drain point and draws a ring); class `ThroneRoomScene extends AreaScene` (name `"ThroneRoomScene"`).

- [ ] **Step 1: Write the failing tests** — in `tests/Dungeon.spec.bs`:

1. In `makeContext(allFlags)`, add `"dng.throneDoor.tried", "dng.throneDoor.open", "throne.introSeen", "witch.defeated"` to the flag list.
2. Add `"ThroneRoomScene"` to the room-name arrays in "leads every dungeon door…" and "leaves every spawn…".
3. In "leaves every spawn…", extend the `else if item.type = "enemy" or …` condition to also cover `item.type = "perch" or item.type = "summonCircle"`.
4. Replace "opens every gate except the great door once everything is done" with:

```brighterscript
    @it("opens every gate once everything is done")
    function _()
      maps = getAreaMaps()
      ctx = m.makeContext(true)
      for each name in ["CastleScene", "GuardroomScene", "AntechamberScene", "KingsHallScene", "ThroneRoomScene"]
        for each item in filterPlacements(maps[name].placements, ctx)
          m.assertNotEqual("gate", item.type, name + " still has a " + FormatJson(item.style) + " gate")
        end for
      end for
    end function

    @describe("the great door")

    private function greatDoor() as object
      for each item in getAreaMaps()["KingsHallScene"].placements
        if item.type = "gate" and item.style = "great"
          return item
        end if
      end for
      return invalid
    end function

    @it("opens for a D1 save that already tried the key")
    function _()
      ctx = m.makeContext(false)
      ctx.flags.set("dng.throneDoor.tried", true)
      ctx.inventory.add("throneKey")
      door = m.greatDoor()
      m.assertTrue(door.live)
      m.assertTrue(evaluateConditions(door.when, ctx))
      m.assertTrue(evaluateConditions(door.unlock.when, ctx))
      result = applyEffects(door.unlock.effects, ctx)
      m.assertTrue(ctx.flags.isSet("dng.throneDoor.open"))
      m.assertFalse(evaluateConditions(door.when, ctx))
      m.assertEqual("The Witch", result.messages[0].speaker)
    end function

    @it("stays shut without the throne key")
    function _()
      m.assertFalse(evaluateConditions(m.greatDoor().unlock.when, m.makeContext(false)))
    end function

    @describe("the throne room")

    @it("has four summoning circles, at least three perches, and the witch after them")
    function _()
      placements = getAreaMaps()["ThroneRoomScene"].placements
      circles = 0
      perches = 0
      witchIndex = -1
      lastPointIndex = -1
      for i = 0 to placements.count() - 1
        item = placements[i]
        if item.type = "summonCircle"
          circles++
          lastPointIndex = i
        else if item.type = "perch"
          perches++
          lastPointIndex = i
        else if item.type = "enemy" and item.kind = "witch"
          witchIndex = i
        end if
      end for
      m.assertEqual(4, circles)
      m.assertTrue(perches >= 3)
      ' The witch is handed the circles and perches, so they must be built before her.
      m.assertTrue(witchIndex > lastPointIndex)
    end function
```

- [ ] **Step 2: Run to verify they fail**

Run: `cd examples/rpg && npm test` — Expected: FAIL (`ThroneRoomScene` missing from `getAreaMaps()`; great door not live).

- [ ] **Step 3: Implement the map data**

`DungeonData.bs`, in `getKingsHallPlacements()`, replace the comment + `p.push({type: "gate", style: "great", ...})` block with:

```brighterscript
  pushRoomGate(p, "n", "great", [{notFlag: "dng.throneDoor.open"}], {
    when: [{hasItem: "throneKey"}],
    effects: [
      {set: "dng.throneDoor.tried", value: true},
      {set: "dng.throneDoor.open", value: true},
      {message: "So the little hero wants an audience. Come in, then.", speaker: "The Witch"}
    ],
    lockedMessage: "A great door, sealed by the witch's magic. The keyhole is shaped like a heart."
  })
  ' Behind the great door, so it can't be reached until the door opens.
  pushRoomDoor(p, "n", "ThroneRoomScene")
  pushRoomSpawn(p, "n")
```

Update the function's header comment to `' The goblin king's hall: shutters behind you, the king, and the great door north to the throne room.` Change `getKingsHallRows()` to keep `buildRoomRows("ns")` (unchanged).

Add after the king's hall:

```brighterscript
' The throne room: the witch, her summoning circles, and the perches she blinks between.
function getThroneRoomRows() as string[]
  return buildRoomRows("s")
end function

function getThroneRoomPlacements() as MapPlacement[]
  p = [] as MapPlacement[]
  ' The 128px dais rug (4x4 cells: cols 8-11, rows 3-6), flat on the floor so everyone draws over it.
  p.push({atlasKey: "throneRug", col: 8, row: 6, floor: true})
  p.push({atlasKey: "bannerRed", col: 6, row: 2})
  p.push({atlasKey: "bannerRed", col: 13, row: 2})
  p.push({atlasKey: "statue", col: 3, row: 4})
  p.push({atlasKey: "statue", col: 16, row: 4})
  p.push({type: "summonCircle", col: 3, row: 6})
  p.push({type: "summonCircle", col: 16, row: 6})
  p.push({type: "summonCircle", col: 4, row: 9})
  p.push({type: "summonCircle", col: 15, row: 9})
  p.push({type: "perch", col: 10, row: 4})
  p.push({type: "perch", col: 5, row: 4})
  p.push({type: "perch", col: 14, row: 4})
  p.push({type: "perch", col: 10, row: 7})
  pushRoomGate(p, "s", "shutter", [{notFlag: "witch.defeated"}])
  pushRoomDoor(p, "s", "KingsHallScene")
  pushRoomSpawn(p, "s")
  ' After the circles and perches: AreaScene hands her the points recorded so far.
  p.push({type: "enemy", kind: "witch", col: 10, row: 4, when: [{notFlag: "witch.defeated"}]})
  return p
end function
```

Add `ThroneRoomScene: {rows: getThroneRoomRows(), placements: getThroneRoomPlacements()}` to `getAreaMaps()`. Update the file's top comment to "The keep: seven one-screen rooms (D1 + the D2 throne room)…".

`MapTypes.bs`: add `"perch"` and `"summonCircle"` to `MapPlacement`'s type list comment, `"witch"` to the `kind` comment, and a new field:

```brighterscript
  ' prop: lies flat on the floor (drawn under everything standing on it), e.g. a rug
  optional floor as boolean
```

`Atlas.bs`, next to the banners:

```brighterscript
    ' indoorTiles' red-and-gold rug, pre-rendered at 2x in main.bs (the throne-room dais).
    throneRug: {sheet: "throneRug", x: 0, y: 0, w: 128, h: 128, footprint: invalid},
```

- [ ] **Step 4: Run tests**

Run: `cd examples/rpg && npm test` — Expected: PASS. If "open ground" fails for a perch/circle under a statue footprint or the shutter, move that placement one cell and rerun.

- [ ] **Step 5: Implement the scene side**

`World/Prop.bs`: import `"../Maps/MapData.bs"`; after setting `m.position.z = -args.y`:

```brighterscript
    if args.floor = true
      m.position.z = GROUND_Z + 1
    end if
```

and add `floor` to its args doc. `AreaScene.buildPlacement`'s prop branch passes `floor: item.floor = true` in the `addEntity` args.

`World/SummonCircle.bs`:

```brighterscript
import "../Maps/MapData.bs"

const SUMMON_CIRCLE_RADIUS = 14.0
' Dark violet (packed RGB).
const SUMMON_CIRCLE_RGB = &h301048

' A dark ring on the floor where the witch's goblins appear. Decoration only.
class SummonCircle extends BGE.GameEntity

  sub new(game as BGE.Game)
    super(game)
    m.name = "SummonCircle"
  end sub

  ' @param {roAssociativeArray} args - {x, y: centre on the floor}
  override sub onCreate(args as roAssociativeArray)
    m.position.x = args.x
    m.position.y = args.y
    m.position.z = GROUND_Z + 1
    r = SUMMON_CIRCLE_RADIUS
    m.addCircle("ring", r, {color: SUMMON_CIRCLE_RGB, alpha: 150, offset: BGE.Math.VectorOps.create(-r, r)})
  end sub

end class
```

`AreaScene.bs`: import `"../World/SummonCircle.bs"`; add field `' Feet points {x, y} of every perch placement (where the witch can blink to).` `perches as Point[] = []`; reset `m.perches = [] as Point[]` next to `m.drains` in `onCreate`; in `buildPlacement` after the `drain` branch:

```brighterscript
    else if item.type = "summonCircle"
      point = enemySpawnPoint(item, numRows)
      m.drains.push(point)
      newCircle = new SummonCircle(m.game)
      m.game.addEntity(newCircle, {x: point.x, y: point.y})
      return newCircle
    else if item.type = "perch"
      m.perches.push(enemySpawnPoint(item, numRows))
```

`DungeonScenes.bs`: append

```brighterscript
class ThroneRoomScene extends AreaScene
  sub new(game as BGE.Game)
    super(game)
    m.name = "ThroneRoomScene"
  end sub
  override function getRows() as string[]
    return getThroneRoomRows()
  end function
  override function getPlacements() as MapPlacement[]
    return getThroneRoomPlacements()
  end function
end class
```

`main.bs`: after the `floorSwitch` bitmap:

```brighterscript
  ' The indoor sheet's red-and-gold rug at 2x, for the throne-room dais.
  game.loadBitmap("throneRug", {width: 128, height: 128, AlphaEnable: true})
  game.getBitmap("throneRug").DrawScaledObject(0, 0, 2, 2, CreateObject("roRegion", game.getBitmap("indoor"), 112, 96, 64, 64))
```

and after `kingsHall`: `throneRoom = new ThroneRoomScene(game)` / `game.defineScene(throneRoom)`.

The witch placement builds a `Rat` until Task 7 adds the `witch` kind (AreaScene's `addEnemy` default); that's fine for this task's screenshots, which use `peaceful=1`.

- [ ] **Step 6: Validate and screenshot**

Run: `cd examples/rpg && npx bsc --validate --create-package=false` — no errors. Then, following the `rokubot-examples` skill (build + sideload `examples/rpg`):
- `rokubot launch dev --param stage=6 --param scene=ThroneRoomScene --param peaceful=1 --param spawn=fromS` → screenshot: rug centred under the north wall, banners, statues, four dark circles, shutter closed at the south.
- `rokubot launch dev --param stage=6 --param scene=KingsHallScene --param flags=dng.throneDoor.open --param spawn=fromN` → screenshot: great door gone, player under the north arch.

If the rug region is off (cropped or bleeding), fix the `roRegion` in `main.bs` (the rug spans roughly x 112-175, y 97-160 of `indoorTiles.png`).

- [ ] **Step 7: Commit**

```bash
git add examples/rpg
git commit -m "rpg: the throne key opens the great door into the throne room (#296)"
```

---

### Task 4: Story data — witch's defeat, quests, dialogue, checkpoints

**Files:**
- Modify: `examples/rpg/src/source/Story/EventRules.bs` (witch rule)
- Modify: `examples/rpg/src/source/Story/QuestData.bs` (keep stages)
- Modify: `examples/rpg/src/source/Story/DialogueData.bs` (witch intro, victory pages, Bram's ending)
- Modify: `examples/rpg/src/source/Story/StoryTypes.bs` (`DialogueChoice.open` comment)
- Modify: `examples/rpg/src/source/Story/Checkpoints.bs` (7, 8)
- Test: `examples/rpg/tests/EventRules.spec.bs`, `examples/rpg/tests/DialogueData.spec.bs`

**Interfaces:**
- Produces: flags `witch.defeated`, `throne.introSeen`, `game.complete`; dialogue id `"witch"` (intro only, no fallback page); `DialogueChoice.open = "credits"`; `checkpointState(7|8)`, `checkpointScene(7) = "ThroneRoomScene"`, `checkpointScene(8) = "TownScene"`.

- [ ] **Step 1: Write the failing tests**

`tests/EventRules.spec.bs`, in "the keep" describe:

```brighterscript
    @it("ends the witch and sends the player back to Bram")
    function _()
      m.ctx.flags.set("keep.stage", 3)
      result = runEventRules(getEventRules(), "enemyKilled", {kind: "witch"}, m.ctx)
      m.assertTrue(m.ctx.flags.isSet("witch.defeated"))
      m.assertEqual(4, m.ctx.flags.getInt("keep.stage"))
      m.assertEqual(1, result.messages.count())
      m.assertEqual(["Return to Elder Bram"], currentObjectives(getQuestData(), m.ctx.flags))
    end function

    @it("drops the keep quest from the log once Bram has spoken")
    function _()
      m.ctx.flags.set("keep.stage", 5)
      m.assertEqual(0, currentObjectives(getQuestData(), m.ctx.flags).count())
    end function
```

Add `@params(7)` and `@params(8)` to "settles to no further change at every checkpoint". Replace "starts checkpoints 5 and 6 inside the keep" with:

```brighterscript
    @it("starts each late checkpoint in the right place")
    function _()
      m.assertEqual("TownScene", checkpointScene(4))
      m.assertEqual("CastleScene", checkpointScene(5))
      m.assertEqual("KingsHallScene", checkpointScene(6))
      m.assertEqual("ThroneRoomScene", checkpointScene(7))
      m.assertEqual("TownScene", checkpointScene(8))
      m.assertEqual(["Enter the throne room"], currentObjectives(getQuestData(), checkpointState(6).flags))
      m.assertEqual(["Return to Elder Bram"], currentObjectives(getQuestData(), checkpointState(8).flags))
    end function
```

`tests/DialogueData.spec.bs`: add `@params(7)` and `@params(8)` to "has a page for every story checkpoint", and add:

```brighterscript
    @describe("the ending")

    private function ctxAt(checkpoint as integer) as object
      state = checkpointState(checkpoint)
      return newStoryContext(state.flags, state.inventory, {health: 6, maxHealth: 6, coins: state.coins})
    end function

    @it("has the witch speak once, on first entering the throne room")
    function _()
      ctx = m.ctxAt(7)
      page = selectDialoguePage(getDialogueData()["witch"], ctx)
      m.assertEqual("The Witch", page.speaker)
      applyEffects(page.effects, ctx)
      m.assertInvalid(selectDialoguePage(getDialogueData()["witch"], ctx))
    end function

    @it("gives Bram the closing page, which completes the game and rolls the credits")
    function _()
      ctx = m.ctxAt(8)
      page = selectDialoguePage(getDialogueData()["bram"], ctx)
      m.assertEqual("credits", page.choices[0].open)
      applyEffects(page.effects, ctx)
      m.assertTrue(ctx.flags.isSet("game.complete"))
      m.assertEqual(5, ctx.flags.getInt("keep.stage"))
      after = selectDialoguePage(getDialogueData()["bram"], ctx)
      m.assertInvalid(after.choices)
    end function

    @it("has Mara send the player to Bram after the witch")
    function _()
      page = selectDialoguePage(getDialogueData()["servant"], m.ctxAt(8))
      m.assertTrue(Instr(1, page.lines[0], "Bram") > 0 or Instr(1, page.lines[page.lines.count() - 1], "Bram") > 0)
    end function
```

- [ ] **Step 2: Run to verify they fail**

Run: `cd examples/rpg && npm test` — Expected: FAIL (no witch rule, no checkpoint 7/8 behaviour, no `witch` dialogue).

- [ ] **Step 3: Implement**

`EventRules.bs`, after the king's rule:

```brighterscript
    {event: "enemyKilled", match: {kind: "witch"}, effects: [{set: "witch.defeated", value: true}, {set: "keep.stage", value: 4}, {message: "The witch crumbles to dust. Across the keep, the goblins vanish like smoke."}]},
```

`QuestData.bs`, the keep stages become:

```brighterscript
stages: {"1": "Find a way through the keep", "2": "Defeat the goblin king", "3": "Enter the throne room", "4": "Return to Elder Bram"}
```

`DialogueData.bs` — insert at the **top** of each list (most specific first):

```brighterscript
    bram: [
      {when: [{flag: "game.complete"}], speaker: "Elder Bram", lines: ["The town owes you everything. Rest a while - you've earned it."]},
      {when: [{flag: "keep.stage", eq: 4}], speaker: "Elder Bram", lines: ["The castle lights are burning again. Then it's true - the witch is gone.", "No more rats in the streets, no more goblins on the walls. You've given this town its life back.", "Whatever you do next, there will always be a seat by my fire for you."], effects: [{set: "keep.stage", value: 5}, {set: "game.complete", value: true}], choices: [{label: "The End", open: "credits"}]},
      ...existing pages...
```

```brighterscript
    servant: [
      {when: [{flag: "witch.defeated"}], speaker: "Mara", lines: ["It's over? The keep feels... lighter already.", "Go and tell Elder Bram. He'll want to hear it from you."]},
      ...
```

```brighterscript
    knight: [
      {when: [{flag: "witch.defeated"}], speaker: "Gate Knight", lines: ["You did it. I'll be telling my grandchildren about you."]},
      ...
    wanderPlaza: [
      {when: [{flag: "witch.defeated"}], speaker: "Townsman", lines: ["The castle lights are back on! Was that you?"]},
      ...
    wanderMarket: [
      {when: [{flag: "witch.defeated"}], speaker: "Townswoman", lines: ["Folk are coming back to market. It feels like a feast day."]},
      ...
    child: [
      {when: [{flag: "witch.defeated"}], speaker: "Child", lines: ["Mum says the witch is gone. Can I go and see the castle?"]},
      ...
    oldWoman: [
      {when: [{flag: "witch.defeated"}], speaker: "Old Woman", lines: ["Sixty years by this water, and I've never seen the castle shine like this."]},
      ...
```

and a new entry:

```brighterscript
    ' Played by the throne room on the first visit (Story.startScripted), not by talking.
    witch: [
      {when: [{notFlag: "throne.introSeen"}], speaker: "The Witch", lines: ["Goblins, rats, a little lock and key... and still you came.", "This keep is mine. Its king was my dog, and its walls are my bones.", "Kneel, little hero, or be ground into the stone with the rest."], effects: [{set: "throne.introSeen", value: true}]}
    ],
```

`StoryTypes.bs`, `DialogueChoice.open` comment: `' "shop" opens the shop, "credits" rolls the credits, once the dialogue closes.`

`Checkpoints.bs`: header comment adds `7 throne room door open, 8 witch defeated (report to Bram)`. After the `n >= 6` block:

```brighterscript
  if n >= 7
    flags.set("dng.throneDoor.tried", true)
    flags.set("dng.throneDoor.open", true)
  end if
  if n >= 8
    flags.set("throne.introSeen", true)
    flags.set("witch.defeated", true)
    flags.set("keep.stage", 4)
  end if
```

and `checkpointScene` becomes:

```brighterscript
  if n >= 8
    return "TownScene"
  else if n >= 7
    return "ThroneRoomScene"
  else if n >= 6
    return "KingsHallScene"
  else if n >= 5
    return "CastleScene"
  end if
  return "TownScene"
```

Also update the comment in `main.bs` describing `stage=N` if it lists the range, and the `CLAUDE.md` range is updated in Task 10.

- [ ] **Step 4: Run to verify they pass**

Run: `cd examples/rpg && npm test` — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add examples/rpg
git commit -m "rpg: witch defeat, ending dialogue, quest stages and checkpoints 7-8 (#296)"
```

---

### Task 5: Witch maths (pure)

**Files:**
- Create: `examples/rpg/src/source/Entities/WitchLogic.bs`
- Modify: `examples/rpg/bsconfig.test.json` (add `source/Entities/WitchLogic.bs` after `source/Entities/Loot.bs`)
- Test: `examples/rpg/tests/WitchLogic.spec.bs`

**Interfaces:**
- Produces: `boltFan(dirX as float, dirY as float, count as integer, spreadDegrees as float) as Point[]`; `pickPerch(perches as Point[], playerX as float, playerY as float, currentIndex as integer) as integer`; `isShielded(summonsAlive as integer) as boolean`; `witchIsPhaseTwo(health as integer, maxHealth as integer) as boolean`.

- [ ] **Step 1: Write the failing test** — `tests/WitchLogic.spec.bs`:

```brighterscript
namespace tests
  @suite("witch logic")
  class WitchLogicTests extends rooibos.BaseTestSuite

    @describe("boltFan")

    @it("aims a single bolt straight at the target")
    function _()
      fan = boltFan(1, 0, 1, 30)
      m.assertEqual(1, fan.count())
      m.assertTrue(Abs(fan[0].x - 1) < 0.001)
      m.assertTrue(Abs(fan[0].y) < 0.001)
    end function

    @it("spreads an odd fan evenly either side of the aim, as unit vectors")
    function _()
      fan = boltFan(0, 1, 3, 30)
      m.assertEqual(3, fan.count())
      ' The middle bolt is the aim; the outer two mirror each other.
      m.assertTrue(Abs(fan[1].x) < 0.001)
      m.assertTrue(Abs(fan[0].x + fan[2].x) < 0.001)
      m.assertTrue(Abs(fan[0].y - fan[2].y) < 0.001)
      for each d in fan
        m.assertTrue(Abs(d.x * d.x + d.y * d.y - 1) < 0.001)
      end for
      ' 15 degrees off the aim at each end.
      m.assertTrue(Abs(fan[2].y - Cos(15 * 3.14159265 / 180)) < 0.001)
    end function

    @describe("pickPerch")

    @it("picks the perch farthest from the player")
    function _()
      perches = [{x: 0, y: 0}, {x: 100, y: 0}, {x: 300, y: 0}]
      m.assertEqual(2, pickPerch(perches, 0, 0, -1))
    end function

    @it("never picks the perch she's on")
    function _()
      perches = [{x: 0, y: 0}, {x: 100, y: 0}, {x: 300, y: 0}]
      m.assertEqual(1, pickPerch(perches, 0, 0, 2))
    end function

    @it("returns -1 with nowhere else to go")
    function _()
      m.assertEqual(-1, pickPerch([], 0, 0, -1))
      m.assertEqual(-1, pickPerch([{x: 5, y: 5}], 0, 0, 0))
    end function

    @describe("shield and phases")

    @it("is shielded while any summon lives")
    function _()
      m.assertFalse(isShielded(0))
      m.assertTrue(isShielded(1))
      m.assertTrue(isShielded(3))
    end function

    @it("enters phase two at half health")
    function _()
      m.assertFalse(witchIsPhaseTwo(9, 16))
      m.assertTrue(witchIsPhaseTwo(8, 16))
      m.assertTrue(witchIsPhaseTwo(1, 16))
    end function

  end class
end namespace
```

- [ ] **Step 2: Run to verify it fails** — add the file to `bsconfig.test.json`, `cd examples/rpg && npm test`. Expected: FAIL (file/functions missing).

- [ ] **Step 3: Implement** — `Entities/WitchLogic.bs`:

```brighterscript
' The witch's maths, kept engine-free so it can be tested.
import "Shapes.bs"

' Unit directions for a fan of bolts centred on an aim.
'
' @param {float} dirX - the aim (a unit vector)
' @param {float} dirY
' @param {integer} count - bolts in the fan
' @param {float} spreadDegrees - angle from the first bolt to the last
' @return {Point[]}
function boltFan(dirX as float, dirY as float, count as integer, spreadDegrees as float) as Point[]
  fan = [] as Point[]
  ' Atn() alone can't tell left from right, and dirX = 0 would divide by zero.
  aim = 0.0
  if dirX = 0
    aim = 1.5707963
    if dirY < 0
      aim = -1.5707963
    end if
  else
    aim = Atn(dirY / dirX)
    if dirX < 0
      aim += 3.14159265
    end if
  end if
  stepRadians = 0.0
  if count > 1
    stepRadians = spreadDegrees * 3.14159265 / 180 / (count - 1)
  end if
  first = aim - stepRadians * (count - 1) / 2
  for i = 0 to count - 1
    angle = first + stepRadians * i
    fan.push({x: Cos(angle), y: Sin(angle)})
  end for
  return fan
end function
```

```brighterscript

```brighterscript
' The perch farthest from the player, other than the one she's on.
'
' @param {Point[]} perches
' @param {float} playerX
' @param {float} playerY
' @param {integer} currentIndex - her perch now, or -1
' @return {integer} index into perches, or -1 if there's nowhere else
function pickPerch(perches as Point[], playerX as float, playerY as float, currentIndex as integer) as integer
  best = -1
  bestDistance = -1.0
  for i = 0 to perches.count() - 1
    if i <> currentIndex
      dx = perches[i].x - playerX
      dy = perches[i].y - playerY
      distance = dx * dx + dy * dy
      if distance > bestDistance
        best = i
        bestDistance = distance
      end if
    end if
  end for
  return best
end function

' @param {integer} summonsAlive - goblins she summoned that are still alive
' @return {boolean} true while sword hits should bounce off her
function isShielded(summonsAlive as integer) as boolean
  return summonsAlive > 0
end function

' @return {boolean} true at or below half health
function witchIsPhaseTwo(health as integer, maxHealth as integer) as boolean
  return health * 2 <= maxHealth
end function
```

- [ ] **Step 4: Run to verify it passes** — `cd examples/rpg && npm test`. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add examples/rpg
git commit -m "rpg: witch bolt fans, perch choice and shield rules (#296)"
```

---

### Task 6: Bolts, boss bar, and the hooks the witch needs

**Files:**
- Create: `examples/rpg/src/source/Entities/WitchBolt.bs`
- Modify: `examples/rpg/src/source/Entities/Enemy.bs` (`displayName`, `maxHealth`, `vanish()`)
- Modify: `examples/rpg/src/source/Entities/GoblinKing.bs` (boss tag, name, max health)
- Modify: `examples/rpg/src/source/Entities/Goblin.bs` (`summoned` arg)
- Modify: `examples/rpg/src/source/Entities/Player.bs` (sword skips projectiles; `pushBack()`)
- Modify: `examples/rpg/src/source/Entities/DamageNumber.bs` (optional `text`)
- Modify: `examples/rpg/src/source/UI/BossBar.bs` (any `boss`-tagged enemy)

**Interfaces:**
- Produces: `Enemy.displayName as string`, `Enemy.maxHealth as integer`, `Enemy.vanish()` (fades out with no `enemyKilled`, no loot); `WitchBolt` (args `{x, y, dirX, dirY, speed, solidWorld, mapWidth, mapHeight}`, tags `enemy` + `projectile`); `Goblin` args `summoned: true` → tag `summon`, no loot; `Player.pushBack(fromX as float, fromY as float)`; `DamageNumber` args `text` (shown instead of `"-" + amount`); tag `"boss"` read by `BossBar`.

- [ ] **Step 1: Enemy hooks** — in `Enemy.bs`:

Fields (after `health`):

```brighterscript
  ' Full health, for the boss bar. Subclasses set it alongside health.
  maxHealth as integer = 1
  ' Shown on the boss bar for an enemy tagged "boss".
  displayName as string = ""
  ' Set by vanish(): fading out without counting as a kill.
  private vanishing as boolean = false
```

A public method after `recoil`:

```brighterscript
  ' Fades this enemy out without a kill: no enemyKilled event and no loot (the witch's
  ' goblins when she dies).
  sub vanish()
    if m.isDying
      return
    end if
    m.isDying = true
    m.vanishing = true
    for each colliderName in m.colliders
      m.colliders[colliderName].enabled = false
    end for
    m.beginFade()
  end sub
```

In `onUpdate`'s fade end, change `m.dropLoot()` to:

```brighterscript
        if not m.vanishing
          m.dropLoot()
        end if
```

`GoblinKing.onCreate`: after `m.health = KING_HEALTH` add `m.maxHealth = KING_HEALTH`, `m.displayName = "Goblin King"`, `m.tagsList.add("boss")`.

`Goblin.bs`: field `' Summoned by the witch: drops nothing.` `protected summoned as boolean = false`; in `onCreate` after `m.health = 3`:

```brighterscript
    m.maxHealth = 3
    if args.summoned = true
      m.summoned = true
      m.tagsList.add("summon")
    end if
```

`lootTable()` becomes:

```brighterscript
    if m.summoned
      return []
    end if
    return [{drop: "coin", chance: 0.3}, {drop: "potion", chance: 0.1}]
```

Update `Enemy.onCreate`'s `@param` doc to mention `summoned` is read by `Goblin`.

- [ ] **Step 2: Boss bar** — `BossBar.bs`: replace the `GoblinKing` import with `import "../Entities/Enemy.bs"`, update the class comment to "The current boss's health (any enemy tagged `boss`) across the top…", and replace the top of `draw()` (through `if king.isDying … end if`) with:

```brighterscript
    boss = invalid
    for each entity in m.game.getEntitiesByTag("boss")
      candidate = entity as Enemy
      if not candidate.isDying
        boss = candidate
      end if
    end for
    if boss = invalid
      return
    end if
```

then use `boss.displayName` for the label and `fillW = Int(barW * boss.health / boss.maxHealth)`.

- [ ] **Step 3: Player and DamageNumber** — `DamageNumber.onCreate`: compute the label text first:

```brighterscript
    text = "-" + args.amount.toStr()
    if args.text <> invalid
      text = args.text
    end if
```

and pass `text` to `BGE.DrawableText`. Update the args doc: `text: shown instead of "-amount" (optional)`.

`Player.onCollision`, right after the `isDying` check:

```brighterscript
    ' The sword passes through the witch's bolts; only touching one hurts.
    if myCollider.name = "sword" and otherEntity.tagsList.contains("projectile")
      return
    end if
```

and a public method after `isDefeated()`:

```brighterscript
  ' Shoves the player back without hurting it (a sword strike bouncing off a shield).
  '
  ' @param {float} fromX - where the push comes from
  ' @param {float} fromY
  sub pushBack(fromX as float, fromY as float)
    if m.defeated or m.knockbackTimer.isActive()
      return
    end if
    push = knockbackVector(fromX, fromY, m.position.x, m.position.y, PLAYER_KNOCKBACK_DISTANCE / 2)
    m.knockback = {x: push.x / PLAYER_KNOCKBACK_SECONDS, y: push.y / PLAYER_KNOCKBACK_SECONDS}
    m.knockbackTimer.start(PLAYER_KNOCKBACK_SECONDS)
  end sub
```

- [ ] **Step 4: `WitchBolt`** — `Entities/WitchBolt.bs`:

```brighterscript
import "Enemy.bs"
import "pkg:/source/utils/CountdownTimer.bs"

const BOLT_RADIUS = 5.0
const BOLT_GLOW_RADIUS = 9.0
' Height of the orb above its ground point.
const BOLT_HEIGHT = 18.0
const BOLT_LIFE_SECONDS = 4.0
' Violet core and glow (packed RGB).
const BOLT_RGB = &hE0B0FF
const BOLT_GLOW_RGB = &h8040FF

' A glowing bolt the witch casts. Flies straight; gone when it touches the player, a wall, or
' after a few seconds. An Enemy (tagged projectile) so the player's contact damage applies,
' but the sword ignores it.
class WitchBolt extends Enemy

  private dirX as float = 0.0
  private dirY as float = 0.0
  private speed as float = 0.0
  private life as BGE.CountdownTimer = new BGE.CountdownTimer()

  sub new(game as BGE.Game)
    super(game)
    m.name = "WitchBolt"
    m.tagsList.add("projectile")
  end sub

  ' @param {roAssociativeArray} args - {x, y (ground point), dirX, dirY (unit), speed, solidWorld, mapWidth, mapHeight}
  override sub onCreate(args as roAssociativeArray)
    super.onCreate(args)
    m.dirX = args.dirX
    m.dirY = args.dirY
    m.speed = args.speed
    m.boxW = 8
    m.boxH = 8
    ' Above anything whose feet are near, so it draws in front of the witch who cast it.
    m.position.z = -args.y + 20
    m.addCircle("glow", BOLT_GLOW_RADIUS, {color: BOLT_GLOW_RGB, alpha: 90, offset: BGE.Math.VectorOps.create(-BOLT_GLOW_RADIUS, BOLT_HEIGHT + BOLT_GLOW_RADIUS)})
    m.addCircle("core", BOLT_RADIUS, {color: BOLT_RGB, alpha: 255, offset: BGE.Math.VectorOps.create(-BOLT_RADIUS, BOLT_HEIGHT + BOLT_RADIUS)})
    ' At ground level, where the player's feet collider is.
    m.addRectangleCollider("body", 10, 10, -5, 10)
    m.life.start(BOLT_LIFE_SECONDS)
  end sub

  ' Replaces Enemy's update: a bolt has no sprite, knockback or death fade.
  override sub onUpdate(dt as float)
    if m.solidWorld = invalid
      return
    end if
    if dt > 0.1
      dt = 0.1
    end if
    m.life.tick(dt)
    nextX = m.position.x + m.dirX * m.speed * dt
    nextY = m.position.y + m.dirY * m.speed * dt
    if not m.life.isActive() or not m.solidWorld.isAreaFree(nextX - m.boxW / 2, nextY, m.boxW, m.boxH)
      m.invalidate()
      return
    end if
    m.position.x = nextX
    m.position.y = nextY
    m.position.z = -nextY + 20
  end sub

  override function hurt(fromX as float, fromY as float, amount = 1 as integer) as boolean
    return false
  end function

  ' It just hit the player.
  override sub recoil(fromX as float, fromY as float)
    m.invalidate()
  end sub

  override sub vanish()
    m.invalidate()
  end sub

end class
```

If bsc rejects overriding `vanish` (not declared `sub` in a way that allows override), keep it — `Enemy.vanish` is a plain public `sub`, which BrighterScript allows overriding.

- [ ] **Step 5: Validate**

Run: `cd examples/rpg && npx bsc --validate --create-package=false` and `npm test` — Expected: no errors, PASS. Sideload with `--param stage=6 --param scene=KingsHallScene` and screenshot: the boss bar reads "Goblin King" exactly as before (this task's only visible change).

- [ ] **Step 6: Commit**

```bash
git add examples/rpg
git commit -m "rpg: witch bolts, a boss bar for any boss, vanish and push-back hooks (#296)"
```

---

### Task 7: The witch

**Files:**
- Create: `examples/rpg/src/sprites/witch.png` (copy of `~/Downloads/rpg/lpcfemalechainpreview.png`)
- Modify: `examples/rpg/src/sprites/CREDITS.md`
- Create: `examples/rpg/src/source/Entities/Witch.bs`
- Modify: `examples/rpg/src/source/Scenes/AreaScene.bs` (`addEnemy` kind `"witch"`)
- Modify: `examples/rpg/src/source/main.bs` (`loadBitmap("witch", …)`)

**Interfaces:**
- Consumes: `boltFan`, `pickPerch`, `isShielded`, `witchIsPhaseTwo` (Task 5); `WitchBolt`, `Enemy.vanish()`, `Enemy.maxHealth`/`displayName`, `Goblin` `summoned` arg, `Player.pushBack`, `DamageNumber` `text` (Task 6); `pickDrain` (`World/Spawning.bs`); `AreaScene.drains`/`perches` (Task 3).
- Produces: `class Witch extends Enemy` (name `"Witch"`, so `enemyKilled {kind: "witch"}`), args adds `drains as Point[]`, `perches as Point[]`; `Witch.freezePose(pose as string)` for `"cast"`, `"shielded"`, `"exhausted"`, `"blink"`, `"dying"`.

- [ ] **Step 1: Asset and credit**

```bash
cp ~/Downloads/rpg/lpcfemalechainpreview.png examples/rpg/src/sprites/witch.png
```

Append to `sprites/CREDITS.md`:

```markdown
## witch.png
`lpcfemalechainpreview.png` from "LPC Combat Armor for women" by Matthew Krohn (makrohn), adapted
from art by Johannes Sjölund. https://opengameart.org/content/lpc-combat-armor-for-women
License: CC-BY-SA 3.0 (also GPL 3.0 / OGA-BY 3.0). Unmodified (tinted in code).
```

`main.bs`: `game.loadBitmap("witch", "pkg:/sprites/witch.png")` after `goblin`.

- [ ] **Step 2: Write `Entities/Witch.bs`**

```brighterscript
import "Enemy.bs"
import "Goblin.bs"
import "WitchBolt.bs"
import "WitchLogic.bs"
import "Player.bs"
import "Facing.bs"
import "Shadow.bs"
import "Loot.bs"
import "DamageNumber.bs"
import "Shapes.bs"
import "../World/Spawning.bs"

const WITCH_HEALTH = 16
' Dark violet (packed RGB), so the plain LPC sheet reads as the witch.
const WITCH_TINT = &hB890FF
const WITCH_FRAMES_PER_ROW = 13
const WITCH_FLEE_RANGE = 96.0
const WITCH_FLEE_SPEED = 50.0
const WITCH_VOLLEY_GAP = 0.8
const WITCH_CAST_SECONDS = 0.6
const WITCH_SUMMON_TELL = 0.8
' How often she casts while her goblins shield her.
const WITCH_SHIELDED_VOLLEY_GAP = 1.6
const WITCH_EXHAUSTED_SECONDS = 2.0
const WITCH_BLINK_SECONDS = 0.2
const WITCH_BOLT_SPEED = 140.0
const WITCH_PHASE2_BOLT_SCALE = 1.3
const WITCH_FAN_SPREAD = 40.0
const WITCH_SUMMON_MIN_DISTANCE = 96.0
' Where her hands are, above her feet: bolts start here.
const WITCH_HAND_HEIGHT = 30.0
const WITCH_SHIELD_RADIUS = 24.0
' Packed RGB.
const WITCH_SHIELD_RGB = &h9060FF
const WITCH_SHIELD_ALPHA = 80

' The witch: never chases. She casts fans of bolts, summons goblins from the circles and hides
' behind a shield while any of them live, then slumps, exhausted - the time to hit her. Each
' hit makes her blink to the perch farthest from the player. Below half health her fans are
' wider and faster and her waves bigger.
'
' witch.png (LPC): 64x64 cells, 13 per row. Rows 0-3 spellcast (up/left/down/right, 7 frames),
' rows 8-11 walk (9 frames, the first a standing pose), row 20 hurt/death (6 frames).
class Witch extends Enemy

  ' "volley", "summon", "shielded", "exhausted", "blinkOut" or "blinkIn"
  private state as string = "volley"
  private stateTimer as BGE.CountdownTimer = new BGE.CountdownTimer()
  ' Between bolt fans.
  private castTimer as BGE.CountdownTimer = new BGE.CountdownTimer()
  ' Holds the spellcast pose after a cast.
  private castLock as BGE.CountdownTimer = new BGE.CountdownTimer()
  private volleysLeft as integer = 0
  private facing as FacingDirection = FacingDirection.down
  private drains as Point[] = []
  private perches as Point[] = []
  private perchIndex as integer = -1
  private shield as BGE.DrawableCircle = invalid
  private frozen as boolean = false

  sub new(game as BGE.Game)
    super(game)
    m.name = "Witch"
    m.tagsList.add("boss")
  end sub

  ' @param {roAssociativeArray} args - Enemy's, plus {drains, perches: Point[]}
  override sub onCreate(args as roAssociativeArray)
    super.onCreate(args)
    m.health = WITCH_HEALTH
    m.maxHealth = WITCH_HEALTH
    m.displayName = "The Witch"
    m.boxW = 18
    m.boxH = 10
    m.headHeight = 56
    m.knockbackScale = 0
    m.deathHoldSeconds = 0.6
    m.baseColor = WITCH_TINT
    if args.drains <> invalid
      m.drains = args.drains
    end if
    if args.perches <> invalid
      m.perches = args.perches
    end if
    addGroundShadow(m, 9)
    r = WITCH_SHIELD_RADIUS
    m.shield = m.addCircle("shield", r, {color: WITCH_SHIELD_RGB, alpha: 0, offset: BGE.Math.VectorOps.create(-r, r + WITCH_HAND_HEIGHT)})
    m.sprite = m.addSprite("body", m.game.getBitmap("witch"), 64, 64)
    ' Pins her feet (32, 62 within each cell) onto the entity's position.
    m.sprite.applyPreTranslation(-32, -62)
    m.sprite.color = WITCH_TINT
    rowFacings = [FacingDirection.up, FacingDirection.left, FacingDirection.down, FacingDirection.right]
    for i = 0 to 3
      cast = i * WITCH_FRAMES_PER_ROW
      walk = (8 + i) * WITCH_FRAMES_PER_ROW
      m.sprite.addAnimation("cast_" + rowFacings[i], [cast, cast + 1, cast + 2, cast + 3, cast + 4, cast + 5, cast + 6], 12, BGE.SpritePlayMode.Forward)
      m.sprite.addAnimation("walk_" + rowFacings[i], [walk + 1, walk + 2, walk + 3, walk + 4, walk + 5, walk + 6, walk + 7, walk + 8], 10, BGE.SpritePlayMode.Loop)
      m.sprite.addAnimation("idle_" + rowFacings[i], [walk], 1, BGE.SpritePlayMode.Loop)
    end for
    hurtRow = 20 * WITCH_FRAMES_PER_ROW
    m.sprite.addAnimation("slump", [hurtRow, hurtRow + 1, hurtRow + 2], 8, BGE.SpritePlayMode.Forward)
    m.sprite.addAnimation("death", [hurtRow, hurtRow + 1, hurtRow + 2, hurtRow + 3, hurtRow + 4, hurtRow + 5], 10, BGE.SpritePlayMode.Forward)
    m.sprite.playAnimation("idle_down")
    m.addRectangleCollider("body", 20, 40, -10, 40)
    m.startVolleys()
  end sub

  ' Holds one pose for a screenshot: "cast", "shielded", "exhausted", "blink" or "dying".
  '
  ' @param {string} pose
  sub freezePose(pose as string)
    m.frozen = true
    if pose = "cast"
      m.playFacing("cast_")
    else if pose = "shielded"
      m.shield.alpha = WITCH_SHIELD_ALPHA
      m.playFacing("cast_")
    else if pose = "exhausted"
      m.sprite.playAnimation("slump")
    else if pose = "blink"
      m.sprite.alpha = 110
    else if pose = "dying"
      m.sprite.playAnimation("death")
    end if
  end sub

  override function hurt(fromX as float, fromY as float, amount = 1 as integer) as boolean
    if m.isDying or m.state = "blinkOut" or m.state = "blinkIn"
      return false
    end if
    if isShielded(m.summonsAlive())
      clink = new DamageNumber(m.game)
      m.game.addEntity(clink, {x: m.position.x, y: m.position.y + m.headHeight, amount: 0, text: "clink", color: WITCH_SHIELD_RGB})
      m.game.playSound("enemyHit")
      playerEntity = m.getPlayer()
      if playerEntity <> invalid
        (playerEntity as Player).pushBack(m.position.x, m.position.y)
      end if
      return false
    end if
    defeated = super.hurt(fromX, fromY, amount)
    if not defeated
      m.startBlink()
    end if
    return defeated
  end function

  ' A boss doesn't back off after hurting the player.
  override sub recoil(fromX as float, fromY as float)
  end sub

  protected override function lootTable() as LootEntry[]
    return []
  end function

  protected override sub onDying()
    m.shield.alpha = 0
    m.sprite.playAnimation("death")
    for each entity in m.game.getEntitiesByTag("summon")
      (entity as Enemy).vanish()
    end for
    for each entity in m.game.getEntitiesByTag("projectile")
      entity.invalidate()
    end for
  end sub

  protected override function currentTint() as integer
    return WITCH_TINT
  end function

  protected override sub moveEnemy(dt as float)
    ' Still while frozen for a screenshot, and while the room fades in (before her speech).
    if m.frozen or m.game.isTransitioning()
      return
    end if
    m.stateTimer.tick(dt)
    m.castTimer.tick(dt)
    m.castLock.tick(dt)
    shielded = isShielded(m.summonsAlive())
    if shielded
      m.shield.alpha = WITCH_SHIELD_ALPHA
    else
      m.shield.alpha = 0
    end if

    if m.state = "blinkOut"
      m.sprite.alpha = 255 * m.stateTimer.remaining() / WITCH_BLINK_SECONDS
      if not m.stateTimer.isActive()
        m.moveToNextPerch()
        m.state = "blinkIn"
        m.stateTimer.start(WITCH_BLINK_SECONDS)
      end if
      return
    else if m.state = "blinkIn"
      m.sprite.alpha = 255 * (1 - m.stateTimer.remaining() / WITCH_BLINK_SECONDS)
      if not m.stateTimer.isActive()
        m.sprite.alpha = 255
        m.colliders["body"].enabled = true
        m.startVolleys()
      end if
      return
    else if m.state = "exhausted"
      if not m.stateTimer.isActive()
        m.startVolleys()
      end if
      return
    else if m.state = "summon"
      if not m.stateTimer.isActive()
        m.summonWave()
      end if
      return
    else if m.state = "shielded"
      if not shielded
        m.state = "exhausted"
        m.stateTimer.start(WITCH_EXHAUSTED_SECONDS)
        m.sprite.playAnimation("slump")
        return
      end if
      if not m.castTimer.isActive()
        m.castFan()
        m.castTimer.start(WITCH_SHIELDED_VOLLEY_GAP)
      end if
    else if m.state = "volley"
      if not m.castTimer.isActive()
        if m.volleysLeft <= 0
          m.state = "summon"
          m.stateTimer.start(WITCH_SUMMON_TELL)
          m.facePlayer()
          m.playFacing("cast_")
          return
        end if
        m.castFan()
        m.volleysLeft--
        m.castTimer.start(WITCH_VOLLEY_GAP)
      end if
    end if
    m.keepDistance(dt)
  end sub

  private sub startVolleys()
    m.state = "volley"
    m.volleysLeft = 2
    if m.isPhaseTwo()
      m.volleysLeft = 3
    end if
    m.castTimer.start(WITCH_VOLLEY_GAP)
  end sub

  private sub startBlink()
    m.state = "blinkOut"
    m.stateTimer.start(WITCH_BLINK_SECONDS)
    m.colliders["body"].enabled = false
  end sub

  private sub moveToNextPerch()
    playerEntity = m.getPlayer()
    if playerEntity = invalid
      return
    end if
    index = pickPerch(m.perches, playerEntity.position.x, playerEntity.position.y, m.perchIndex)
    if index < 0
      return
    end if
    m.perchIndex = index
    m.position.x = m.perches[index].x
    m.position.y = m.perches[index].y
    m.position.z = -m.position.y
  end sub

  private sub castFan()
    playerEntity = m.getPlayer()
    if playerEntity = invalid
      return
    end if
    startY = m.position.y + 1
    dx = playerEntity.position.x - m.position.x
    dy = playerEntity.position.y - startY
    distance = Sqr(dx * dx + dy * dy)
    if distance < 1
      return
    end if
    m.facePlayer()
    m.playFacing("cast_")
    m.castLock.start(WITCH_CAST_SECONDS)
    count = 3
    speed = WITCH_BOLT_SPEED
    if m.isPhaseTwo()
      count = 5
      speed = speed * WITCH_PHASE2_BOLT_SCALE
    end if
    for each dir in boltFan(dx / distance, dy / distance, count, WITCH_FAN_SPREAD)
      bolt = new WitchBolt(m.game)
      m.game.addEntity(bolt, {x: m.position.x, y: startY, dirX: dir.x, dirY: dir.y, speed: speed, solidWorld: m.solidWorld, mapWidth: m.mapWidth, mapHeight: m.mapHeight})
    end for
  end sub

  private sub summonWave()
    playerEntity = m.getPlayer()
    count = 2
    if m.isPhaseTwo()
      count = 3
    end if
    spawned = 0
    if playerEntity <> invalid
      for i = 1 to count
        index = pickDrain(m.drains, playerEntity.position.x, playerEntity.position.y, WITCH_SUMMON_MIN_DISTANCE, Rnd(0))
        if index >= 0
          summon = new Goblin(m.game)
          m.game.addEntity(summon, {x: m.drains[index].x, y: m.drains[index].y, solidWorld: m.solidWorld, mapWidth: m.mapWidth, mapHeight: m.mapHeight, summoned: true})
          spawned++
        end if
      end for
    end if
    if spawned = 0
      ' Nowhere to summon (or no player): skip straight to the opening.
      m.state = "exhausted"
      m.stateTimer.start(WITCH_EXHAUSTED_SECONDS)
      m.sprite.playAnimation("slump")
      return
    end if
    m.state = "shielded"
    m.castTimer.start(WITCH_SHIELDED_VOLLEY_GAP)
  end sub

  ' Drifts away when the player is close; otherwise stands (or holds the cast pose).
  private sub keepDistance(dt as float)
    playerEntity = m.getPlayer()
    if playerEntity = invalid
      return
    end if
    dx = m.position.x - playerEntity.position.x
    dy = m.position.y - playerEntity.position.y
    distance = Sqr(dx * dx + dy * dy)
    if distance < WITCH_FLEE_RANGE and distance > 1
      m.applyMove(dx / distance * WITCH_FLEE_SPEED * dt, dy / distance * WITCH_FLEE_SPEED * dt, {})
      if not m.castLock.isActive()
        m.facing = facingFor(dx, dy, m.facing)
        m.playFacing("walk_")
      end if
    else if not m.castLock.isActive()
      m.facePlayer()
      m.playFacing("idle_")
    end if
  end sub

  private function summonsAlive() as integer
    alive = 0
    for each entity in m.game.getEntitiesByTag("summon")
      if not (entity as Enemy).isDying
        alive++
      end if
    end for
    return alive
  end function

  private function isPhaseTwo() as boolean
    return witchIsPhaseTwo(m.health, m.maxHealth)
  end function

  private sub facePlayer()
    playerEntity = m.getPlayer()
    if playerEntity <> invalid
      m.facing = facingFor(playerEntity.position.x - m.position.x, playerEntity.position.y - m.position.y, m.facing)
    end if
  end sub

  private sub playFacing(prefix as string)
    m.sprite.playAnimation(prefix + m.facing)
  end sub

end class
```

Notes for the implementer:
- `Enemy.onUpdate` sets `m.sprite.color = m.currentTint()` each frame, which keeps the tint; the blink writes `m.sprite.alpha`, which nothing else touches except the death fade (after which she's gone).
- `freezePose("blink")` intentionally doesn't change `state`, so `hurt()` still works in the showcase; the showcase never fights anyway.
- If `m.colliders["body"]` doesn't type-check, use `m.getCollider("body")` (check `GameEntity.bs` for the accessor name).

- [ ] **Step 3: Build her from placements** — `AreaScene.addEnemy`: import `"../Entities/Witch.bs"`, and add before the `goblinKing` branch:

```brighterscript
    else if item.kind = "witch"
      args.drains = m.drains
      args.perches = m.perches
      newWitch = new Witch(m.game)
      m.game.addEntity(newWitch, args)
      return newWitch
```

(`args` is built as a plain AA literal; adding keys to it is fine.)

- [ ] **Step 4: Validate and screenshot**

Run: `cd examples/rpg && npx bsc --validate --create-package=false` and `npm test`. Then sideload and run `rokubot launch dev --param stage=7 --param flags=throne.introSeen --param spawn=fromS` (stage 7 starts in `ThroneRoomScene`; `throne.introSeen` keeps the command valid once Task 8 adds her speech). Take one screenshot within ~2s of the fade: the witch on the dais, tinted violet, facing the player, drawn in front of the rug, boss bar reading "The Witch". Don't try to play the fight here.

- [ ] **Step 5: Commit**

```bash
git add examples/rpg
git commit -m "rpg: the witch - bolt volleys, goblin waves behind a shield, blinking between perches (#296)"
```

---

### Task 8: The witch's entrance, and the showcase

**Files:**
- Modify: `examples/rpg/src/source/Story/Story.bs` (`startScripted`, pending id in `onUpdate`)
- Modify: `examples/rpg/src/source/Scenes/DungeonScenes.bs` (`ThroneRoomScene.onCreate`)
- Modify: `examples/rpg/src/source/Scenes/GoblinShowcaseScene.bs` (witch poses, a bolt fan)

**Interfaces:**
- Consumes: dialogue id `"witch"` (Task 4); `Witch.freezePose` (Task 7); `boltFan` (Task 5); `WitchBolt` (Task 6).
- Produces: `Story.startScripted(npcId as string)` — opens that id's first passing page once nothing is open and no fade is running; does nothing if no page passes.

- [ ] **Step 1: `Story.startScripted`** — field `' A scripted conversation waiting for every panel to close (see startScripted).` `private pendingScripted as string = ""`, and:

```brighterscript
  ' Starts a conversation without the player talking to anyone (a scene's cutscene line),
  ' once nothing else is open and the area has faded in. Nothing happens if no page passes.
  '
  ' @param {string} npcId - a getDialogueData() id
  sub startScripted(npcId as string)
    m.pendingScripted = npcId
  end sub
```

In `onUpdate`, add a branch between the message branch and the `openOnArrival` branch:

```brighterscript
    else if canOpen and m.pendingScripted <> ""
      npcId = m.pendingScripted
      m.pendingScripted = ""
      m.startDialogue(npcId)
```

- [ ] **Step 2: `ThroneRoomScene.onCreate`** — in `DungeonScenes.bs`, import `"../Story/Story.bs"` and add to `ThroneRoomScene`:

```brighterscript
  override sub onCreate(args as roAssociativeArray)
    super.onCreate(args)
    ' Her speech, the first time only (the page is gated on throne.introSeen).
    storyEntity = m.game.getEntityByName("Story") as Story
    storyEntity.startScripted("witch")
  end sub
```

- [ ] **Step 3: Showcase** — in `GoblinShowcaseScene.onCreate`, import `"../Entities/Witch.bs"`, `"../Entities/WitchBolt.bs"`, `"../Entities/WitchLogic.bs"`, and after the kings:

```brighterscript
    ' The witch's poses along the top row, and a frozen five-bolt fan under them.
    x = 2 * TILE_SIZE
    for each pose in ["cast", "shielded", "exhausted", "blink", "dying"]
      newWitch = new Witch(m.game)
      m.game.addEntity(newWitch, {x: x, y: cellBottomY(numRows, 3.5), solidWorld: m.solidWorld, mapWidth: m.mapWidth, mapHeight: m.mapHeight, drains: [], perches: []})
      newWitch.freezePose(pose)
      x += 4 * TILE_SIZE
    end for
    for each dir in boltFan(0, -1, 5, 40)
      bolt = new WitchBolt(m.game)
      m.game.addEntity(bolt, {x: 17 * TILE_SIZE + dir.x * 30, y: cellBottomY(numRows, 6) + dir.y * 30, dirX: dir.x, dirY: dir.y, speed: 0, solidWorld: m.solidWorld, mapWidth: m.mapWidth, mapHeight: m.mapHeight})
    end for
```

(`speed: 0` keeps the bolts still; they still expire after 4s, so screenshot promptly.) If row 3.5 overlaps the goblins at row 5, move the goblins' row or the witches' row so nothing overlaps; the room is 20×11.

Update the class comment: "goblins, the king and the witch frozen in each pose…".

- [ ] **Step 4: Validate and screenshot**

`npx bsc --validate --create-package=false`, `npm test`. Then:
- `rokubot launch dev --param scene=GoblinShowcaseScene` → screenshot: five witch poses (shield ring visible on the second, slump on the third, faded on the fourth, death frame on the fifth), feet on the floor (not floating/sunk), bolt fan visible. Adjust `applyPreTranslation` (feet pin) or `WITCH_TINT` if she floats or reads badly.
- `rokubot launch dev --param stage=7` → screenshot after the fade: the witch's speech box with speaker "The Witch".

- [ ] **Step 5: Commit**

```bash
git add examples/rpg
git commit -m "rpg: the witch's opening speech, and her poses in the showcase (#296)"
```

---

### Task 9: Credits

**Files:**
- Create: `examples/rpg/src/source/Story/CreditsData.bs`
- Create: `examples/rpg/src/source/UI/CreditsRoll.bs`
- Create: `examples/rpg/src/source/Scenes/CreditsScene.bs`
- Modify: `examples/rpg/src/source/Story/Story.bs` (`open: "credits"`)
- Modify: `examples/rpg/src/source/Entities/Player.bs` (`leaveArea()`)
- Modify: `examples/rpg/src/source/main.bs` (`defineScene`)
- Modify: `examples/rpg/src/sprites/CREDITS.md` (top note)
- Modify: `examples/rpg/bsconfig.test.json` (add `source/Story/CreditsData.bs`)
- Test: `examples/rpg/tests/Credits.spec.bs`

**Interfaces:**
- Produces: `interface CreditLine { text as string, style as string }` (`style` is `"title"`, `"heading"` or `"body"`); `getCreditLines() as CreditLine[]`; `Player.leaveArea()`; `class CreditsScene extends BGE.GameScene` (name `"CreditsScene"`); `CreditsRoll` widget (`isFinished() as boolean`, `skip()`, `setFast(fast as boolean)`).

- [ ] **Step 1: Write the failing test** — `tests/Credits.spec.bs`:

```brighterscript
namespace tests
  @suite("credits")
  class CreditsTests extends rooibos.BaseTestSuite

    @it("opens with the title and The End")
    function _()
      lines = getCreditLines()
      m.assertEqual("title", lines[0].style)
      m.assertEqual("The End", lines[1].text)
    end function

    @it("credits every art file the game ships")
    function _()
      text = ""
      for each line in getCreditLines()
        text += line.text + Chr(10)
      end for
      for each name in ["PathAndObjects.png", "Castle2.png", "adventurer.png", "rat.png", "bat.png", "npcs.png", "goblin.png", "witch.png", "indoorTiles.png", "castleWalls.png", "locks.png", "box.9.png", "heart.png", "potion.png", "Quill and Antler"]
        m.assertTrue(Instr(1, text, name) > 0, name + " is missing from the credits")
      end for
    end function

    @it("uses only known styles")
    function _()
      for each line in getCreditLines()
        m.assertTrue(line.style = "title" or line.style = "heading" or line.style = "body", line.text)
      end for
    end function

  end class
end namespace
```

The font's credit comes from `examples/rpg/src/fonts/license.txt`: "Quill and Antler Expanded" by MagicBear, SIL Open Font License 1.1.

- [ ] **Step 2: Run to verify it fails** — add `"source/Story/CreditsData.bs"` to `bsconfig.test.json` (after `source/Story/DebugParams.bs`); `npm test`. Expected: FAIL.

- [ ] **Step 3: `Story/CreditsData.bs`** — one heading per asset, its body lines condensed from `sprites/CREDITS.md` (title, author, licence; no URLs — they're unreadable on a TV):

```brighterscript
' The credits roll, kept in step with sprites/CREDITS.md by hand.

' One line of the credits.
interface CreditLine
  text as string
  ' "title", "heading" or "body"
  style as string
end interface

' @return {CreditLine[]} in order, top to bottom
function getCreditLines() as CreditLine[]
  lines = [] as CreditLine[]
  lines.push({text: "The Witch of the Keep", style: "title"})
  lines.push({text: "The End", style: "heading"})
  lines.push({text: "Thanks for playing", style: "body"})
  lines.push({text: "", style: "body"})
  lines.push({text: "Made with the BrighterScript Game Engine", style: "body"})
  lines.push({text: "", style: "body"})
  lines.push({text: "Art", style: "title"})
  addCredit(lines, "PathAndObjects.png", "\"RPG Tiles: Cobble Stone Paths & Town Objects\" by Zabin, Daneeklu, Jetrel, Hyptosis, Redshrike and Bertram. CC-BY-SA 3.0")
  addCredit(lines, "Castle2.png, castleWalls.png", "\"Castle Tiles for RPGs\" by Zabin, Hyptosis and Daniel Cook. CC-BY 3.0")
  addCredit(lines, "adventurer.png", "\"FREE Adventurer 2D Pixel Art\" by Mattz Art")
  addCredit(lines, "rat.png", "\"Rodents (Rat Rework)\" by Tuomo Untinen (Reemax) and Jordan Irwin (AntumDeluge). CC-BY 3.0")
  addCredit(lines, "bat.png", "\"Bat (Rework)\" by bagzie. CC-BY 3.0")
  addCredit(lines, "heart.png, coin.png", "\"RetroPixel Icons V1\" by Anton Revin. CC0")
  addCredit(lines, "npcs.png", "\"Fantasy RPG NPCs\" by Mandi Paugh. CC-BY-SA 3.0")
  addCredit(lines, "potion.png, swords", "\"RPG Icons Extra\" by Ails (Henrique Lazarini). CC-BY 3.0")
  addCredit(lines, "box.9.png", "\"RPG GUI Block Element\" by Bart. CC-BY 3.0")
  addCredit(lines, "button.9.png, frame.9.png", "\"Buttons and Frame\". CC0")
  addCredit(lines, "goblin.png", "\"[LPC] Goblin\" by Stephen \"Redshrike\" Challener and William.Thompsonj. CC-BY 3.0")
  addCredit(lines, "locks.png, keys", "\"Locks and Keys\" by Kelvin Shadewing. CC-BY-SA 4.0")
  addCredit(lines, "indoorTiles.png", "\"RPG Indoor Tileset: Expansion 1\" by Stephen Challener (Redshrike) and Jetrel. CC-BY 3.0")
  addCredit(lines, "witch.png", "\"LPC Combat Armor for women\" by Matthew Krohn (makrohn), from art by Johannes Sjölund. CC-BY-SA 3.0")
  addCredit(lines, "Key art", "\"Broadsword\", generated with Google Gemini")
  lines.push({text: "", style: "body"})
  lines.push({text: "Font", style: "title"})
  addCredit(lines, "Quill and Antler Expanded", "by MagicBear. SIL Open Font License 1.1")
  return lines
end function

sub addCredit(lines as CreditLine[], heading as string, body as string)
  lines.push({text: heading, style: "heading"})
  lines.push({text: body, style: "body"})
  lines.push({text: "", style: "body"})
end sub
```

Add a line at the top of `sprites/CREDITS.md`: `In-game credits (Story/CreditsData.bs) are kept in step with this file by hand.`

Run `npm test` — Expected: PASS.

- [ ] **Step 4: `Player.leaveArea()`** — after `placeAt`:

```brighterscript
  ' Takes the player out of play (the credits): it stops moving and ignores input until the
  ' next placeAt().
  sub leaveArea()
    m.solidWorld = invalid
    m.endSwing()
  end sub
```

(`onUpdate`, `tryTalk` and `requestSwing` already return early without a `solidWorld`.)

- [ ] **Step 5: `UI/CreditsRoll.bs`**

```brighterscript
import "pkg:/source/engine/ui/UiWidget.bs"
import "pkg:/source/engine/ui/TextWrap.bs"
import "MenuPanel.bs"
import "../Story/CreditsData.bs"

const CREDITS_SPEED = 40.0
const CREDITS_FAST_SCALE = 4.0
const CREDITS_TITLE_RGBA = &hFFD966FF
const CREDITS_HEADING_RGBA = &hF5E6C8FF
const CREDITS_BODY_RGBA = &hC8B8A0FF
' Over the dimmed key art (packed RGBA).
const CREDITS_DIM_RGBA = &h000000C8

' The credits, scrolling up over the dimmed key art. Covers the whole UI canvas (and so the HUD
' and the world). Lines only draw inside the title-safe area: they appear at its bottom edge and
' disappear at its top.
class CreditsRoll extends BGE.UI.UiWidget

  ' Wrapped lines: {text, rgba, height}.
  private rows as object[] = []
  private totalHeight as float = 0
  ' How far the roll has moved up, in px.
  private scroll as float = 0
  private fast as boolean = false

  sub new(game as BGE.Game)
    super(game)
    font = game.getFont("hud")
    maxWidth = game.uiCanvas.getWidth() * (1 - UI_SAFE * 2)
    lineHeight = font.GetOneLineHeight()
    for each line in getCreditLines()
      rgba = CREDITS_BODY_RGBA
      if line.style = "title"
        rgba = CREDITS_TITLE_RGBA
      else if line.style = "heading"
        rgba = CREDITS_HEADING_RGBA
      end if
      if line.text = ""
        m.rows.push({text: "", rgba: rgba, height: lineHeight / 2})
      else
        for each wrapped in BGE.UI.wrapText(line.text, font, maxWidth)
          m.rows.push({text: wrapped, rgba: rgba, height: lineHeight})
        end for
      end if
    end for
    for each row in m.rows
      m.totalHeight += row.height
    end for
  end sub

  sub setFast(fast as boolean)
    m.fast = fast
  end sub

  sub skip()
    m.scroll = m.endScroll()
  end sub

  ' @return {boolean} true once the last line has scrolled off the top of the safe area
  function isFinished() as boolean
    return m.scroll >= m.endScroll()
  end function

  override sub onUpdate(dt as float)
    speed = CREDITS_SPEED
    if m.fast
      speed = speed * CREDITS_FAST_SCALE
    end if
    m.scroll += speed * dt
    if m.scroll > m.endScroll()
      m.scroll = m.endScroll()
    end if
  end sub

  override sub draw(parent = invalid as BGE.UI.UiWidget)
    renderer = m.canvas.renderer
    canvasW = m.canvas.getWidth()
    canvasH = m.canvas.getHeight()
    art = m.game.getBitmap("title")
    renderer.drawScaledObject(0, 0, canvasW / art.GetWidth(), canvasH / art.GetHeight(), art)
    renderer.drawRectangle(0, 0, canvasW, canvasH, CREDITS_DIM_RGBA)
    font = m.game.getFont("hud")
    safeTop = canvasH * UI_SAFE
    safeBottom = canvasH * (1 - UI_SAFE)
    y = safeBottom - m.scroll
    for each row in m.rows
      if row.text <> "" and y >= safeTop and y + row.height <= safeBottom
        renderer.drawText(row.text, canvasW / 2, y, row.rgba, font, "center", "top")
      end if
      y += row.height
    end for
  end sub

  ' The roll starts with its first line at the safe area's bottom and ends when its last line
  ' has passed the top.
  private function endScroll() as float
    return m.totalHeight + m.canvas.getHeight() * (1 - UI_SAFE * 2)
  end function

end class
```

Check `UiWidget` for the per-frame hook name before relying on `onUpdate` — `CLAUDE.md` says `gameUi` gets `onUpdate` dispatch; if `UiWidget` has no `onUpdate`, drive `scroll` from `CreditsScene.onUpdate` via a public `advance(dt)` instead. `m.canvas` is set when the widget is added to `gameUi` (as for `HeartsHud`); `endScroll()` is only called after that.

- [ ] **Step 6: `Scenes/CreditsScene.bs`**

```brighterscript
import "../UI/CreditsRoll.bs"
import "../Entities/Player.bs"

' The end: the credits roll over the key art, then the title screen. OK or Back skips to the
' end; Down speeds it up while held.
class CreditsScene extends BGE.GameScene

  private roll as CreditsRoll = invalid
  private leaving as boolean = false

  sub new(game as BGE.Game)
    super(game)
    m.name = "CreditsScene"
  end sub

  override sub onCreate(args as roAssociativeArray)
    m.leaving = false
    if m.game.getAllEntities("Player").count() > 0
      (m.game.getEntityByName("Player") as Player).leaveArea()
    end if
    m.roll = new CreditsRoll(m.game)
    ' Added last, so it draws over the HUD.
    m.game.gameUi.addChild(m.roll)
  end sub

  override sub onUpdate(dt as float)
    if not m.leaving and m.roll.isFinished() and not m.game.isTransitioning()
      m.leaving = true
      m.game.changeSceneWithFade("TitleScene", {})
    end if
  end sub

  override sub onInput(input as BGE.GameInput)
    if m.leaving or m.game.isTransitioning()
      return
    end if
    if input.isButton("down")
      m.roll.setFast(not input.release)
    else if input.press and (input.isButton("ok") or input.isButton("back"))
      m.roll.skip()
    end if
  end sub

  override sub onChangeScene(newScene as BGE.GameScene)
    m.removeRoll()
  end sub

  override sub onDestroy()
    m.removeRoll()
  end sub

  private sub removeRoll()
    if m.roll <> invalid
      m.game.gameUi.removeChild(m.roll)
      m.roll = invalid
    end if
  end sub

end class
```

Check how `TitleScene` keeps the background drawn during its fade-out (it removes it in `onChangeScene`); do the same here so the roll stays visible while fading to the title.

`main.bs`: import `"Scenes/CreditsScene.bs"`, then `credits = new CreditsScene(game)` / `game.defineScene(credits)` before the title.

- [ ] **Step 7: `open: "credits"`** — in `Story.bs`, field `private pendingCredits as boolean = false`; in `finishDialogue`, next to `opensShop`:

```brighterscript
      opensCredits = choice.open <> invalid and choice.open = "credits"
```

(declare `opensCredits = false` beside `opensShop = false`), and after `m.applyResult(...)` (which has already saved):

```brighterscript
    if opensCredits
      m.pendingCredits = true
    end if
```

In `onUpdate`, as the first `canOpen` branch:

```brighterscript
    if canOpen and m.pendingCredits
      m.pendingCredits = false
      m.game.changeSceneWithFade("CreditsScene", {})
    else if canOpen and m.pendingMessages.count() > 0
```

- [ ] **Step 8: Validate and screenshot**

`npx bsc --validate --create-package=false`, `npm test`. Then:
- `rokubot launch dev --param scene=CreditsScene` → screenshots at ~1s and ~10s: dimmed key art, centred lines only inside the safe band, no HUD visible.
- `rokubot launch dev --param stage=8` → walk-free check: screenshot the town (no scripted check of Bram's talk; talking to Bram needs walking, which is a hand check in Task 10).

- [ ] **Step 9: Commit**

```bash
git add examples/rpg
git commit -m "rpg: Bram's closing words roll the credits, then the title (#296)"
```

---

### Task 10: Docs, follow-up issue, full gate, and hand checks

**Files:**
- Modify: `CLAUDE.md` (the `examples/rpg` bullet)
- Modify: `.claude/skills/rokubot-examples/SKILL.md` (rpg notes)
- Modify: `specs/2026-10-05-rpg-slice-d2-throne-room-design.md` only if implementation diverged

- [ ] **Step 1: CLAUDE.md** — in the `examples/rpg` bullet, after the **Dungeon** sentence block, add a **Throne room and ending** sentence group (issue #296, `specs/2026-10-05-rpg-slice-d2-throne-room-design.md`): the throne key opens the great door (live gate on `dng.throneDoor.open`, with a speakered `message` - `{message, speaker}`); `ThroneRoomScene` (rug dais, `summonCircle` placements that double as drains, `perch` placements); `Witch` (`Entities/Witch.bs`, pure maths in `WitchLogic.bs`) cycles volley/summon/shielded/exhausted and blinks to the farthest perch on a hit, `WitchBolt` is an `Enemy` tagged `projectile` that the sword ignores; `BossBar` shows any `boss`-tagged enemy; `Story.startScripted()` plays her intro once (`throne.introSeen`); her death sets `witch.defeated`, which `Maps/Keep.bs`'s `withKeepEnemiesGone()` uses to empty every keep room; `defeatRespawn()` sends a defeat anywhere in the keep to `CastleScene`/`entrance` with story state kept; Bram's closing page (`open: "credits"`) goes to `CreditsScene` then `TitleScene`. Change "checkpoints run 0-6" to "0-8" (7 throne room, 8 witch defeated) and mention `scene=CreditsScene`. Add the story-layer decision: it stays in the example (see the D2 spec), follow-up issue #<n from Step 3>.

- [ ] **Step 2: rokubot skill** — in the rpg notes, add `stage=7` (throne room, intro plays), `stage=8` (town, witch defeated), `scene=CreditsScene`, and that `GoblinShowcaseScene` now includes the witch.

- [ ] **Step 3: File the story-layer follow-up issue**

```bash
gh issue create --title "Story layer: promote a generic BGE.Story when a second consumer needs it" --label enhancement --body "$(cat <<'EOF'
Decided in #296 (see specs/2026-10-05-rpg-slice-d2-throne-room-design.md, "Story layer: stays in the example"): examples/rpg's Story/ layer stays in the example for now.

Generic core worth promoting: StoryFlags, conditions (flag/eq/gte/lt/notFlag), event rules with match, the storyChanged settle loop, and the live-placement diff.
Game-specific vocabulary that stays with each game: effects like giveCoins/heal/addMaxHealth, PlayerStats, items, quests, shop rules, save data, and the Story entity's UI.

Sketch: BGE.Story with flags + conditions + event rules + settle, and registerEffect(name, handler)/registerCondition(name, handler) for a game's own vocabulary.

Pick this up when a second example (or a user) needs it, so the API isn't shaped by one game alone.
EOF
)"
```

Put the issue number into the CLAUDE.md sentence from Step 1.

- [ ] **Step 4: Full gate**

Run from the repo root: `npm run check` (engine lint/validate/tests — the engine is untouched, so this should be unchanged) and `cd examples/rpg && npm test && npx bsc --validate --create-package=false`. Expected: all PASS, no diagnostics. Run `npm run lint` and fix any bslint findings in the new files.

- [ ] **Step 5: Device screenshots (title-safe pass)**

Using the `rokubot-examples` skill, screenshot and check every edge stays ≥10% in:
- `--param stage=7` (intro box), `--param stage=7 --param flags=throne.introSeen --param spawn=fromS` (boss bar + witch), `--param scene=GoblinShowcaseScene`, `--param scene=CreditsScene`, `--param stage=6 --param scene=KingsHallScene --param flags=dng.throneDoor.open --param spawn=fromN`.

- [ ] **Step 6: Hand-check list for the user** (do not attempt via rokubot — real-time play): ask the user to play from `--param stage=6` and report:
1. Turning the key at the great door shows the witch's line and the door fades open.
2. The intro plays once; the fight starts when it closes.
3. Bolts hurt; the sword passes through them.
4. Hits bounce ("clink") while goblins live; she slumps once they're dead; a hit makes her blink to a far perch.
5. Phase two (half health) has wider/faster fans and three goblins.
6. Dying mid-fight returns to the entry hall, keys/doors intact; going back, she's at full health and doesn't repeat her speech.
7. Her death clears her goblins, opens the shutter, and the keep's rooms are empty afterwards.
8. Bram's closing page → credits → title; Continue lands in town.

- [ ] **Step 7: Commit**

```bash
git add CLAUDE.md .claude/skills specs
git commit -m "docs: rpg throne room, witch and ending in CLAUDE.md and the rokubot skill (#296)"
```

Then hand off via `superpowers:finishing-a-development-branch` (push the branch with an explicit refspec and open a PR; never push to main).
