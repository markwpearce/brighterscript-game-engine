# rpg Slice D1: The keep dungeon — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn `examples/rpg`'s castle into a six-room Zelda-style dungeon (small keys, locked doors, floor switches, shutters, pots, goblins, a goblin king who drops the throne key), with the throne-room door left sealed for D2.

**Architecture:** Every lock, switch and shutter is driven by the existing Slice C story layer: a new `live: true` map placement is re-evaluated whenever the story changes (a `storyUpdated` game event), so a gate is just a placement whose `when` stops passing. One engine change: `BGE.SolidWorld.removeSolid()`, so gates and pots can stop blocking. Rooms are separate `AreaScene`s joined by the existing `Door` + fade.

**Tech Stack:** BrighterScript (bsc 1.0.0-alpha), the BGE engine, Rooibos v6 (engine suite via `npm run test:ci`, rpg suite via `cd examples/rpg && npm test`), rokubot for on-device screenshots.

**Spec:** `specs/2026-10-04-rpg-slice-d1-dungeon-design.md`

## Global Constraints

- One screen per room: 20×11 cells of 32px (`TILE_SIZE = 32`) on the 640×360 game canvas.
- All UI title-safe: ≥10% in from every canvas edge (`UI_SAFE`, or `canvasW * 0.1` as `HeartsHud` does).
- On-device checks are screenshots via deep-link params only. Never drive the player or fight through rokubot.
- Prefer real types over `as object`/`as dynamic` (CLAUDE.md); options bags are `interface ... extends roAssociativeArray`.
- Every file that uses another file's symbol `import`s it.
- Never compare two class instances or native components with `=`; compare an `id`/`name` string.
- Guard one-shot input with `input.press`.
- Comments terse (the "why" only); doc comments for consumers.
- Story data never uses `then` as a key.
- Commit after every task, on branch `feature/issue-289-rpg-slice-d1-dungeon`, ending each message with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Pure logic lives in engine-free files listed in `examples/rpg/bsconfig.test.json`; entity code is checked on device.

## Review Focus

1. **Re-entering a room after its state changed**: a cleared guardroom, opened door, or taken key must stay that way on re-entry and after Continue (flags are saved). Tests: Task 4 (diff with flags set builds nothing), Task 13 (rooms with all flags set have open exits).
2. **Story rules settling forever**: the new `gate.stage`/`keep.stage` rules must not fight the old `gate.open → gate.stage 2` rule. Test: Task 14 ("settles to no further change at every checkpoint").
3. **A message arriving while a panel is open** (a switch effect while a dialogue is up, two messages from one change): must queue, not be dropped or open two boxes. Covered by the queue in Task 3; checked on device in Task 16.
4. **Picking up an item at its cap** (a 4th small key, a potion when holding 3): the pickup stays on the floor and nothing is consumed. Test: Task 5 (`canCollectPickup`).
5. **Spawning into a closed shutter or gate**: every spawn point must be clear of gate solids with flags off *and* on. Test: Task 13.

---

## File map

**Engine**
- Modify `src/source/engine/colliders/SolidWorld.bs`: `addSolid` returns an id; new `removeSolid(id)`.
- Modify `src/source/engine/colliders/SolidWorld.spec.bs`.

**rpg, pure (tested)**
- Create `Maps/LivePlacements.bs`: `diffLivePlacements()`, `nonLivePlacements()`.
- Create `Maps/DungeonData.bs`: `buildRoomRows()`, the six rooms' rows/placements, `getAreaMaps()`.
- Create `Entities/Loot.bs`: `LootEntry`, `pickLoot()`.
- Create `Story/DebugParams.bs`: `parseFlagList()`, `parseItemList()`.
- Create `World/PickupRules.bs`: `canCollectPickup()`.
- Modify `Maps/MapTypes.bs`, `Maps/MapData.bs` (castle becomes the entry hall), `Maps/Atlas.bs`.
- Modify `Story/StoryTypes.bs`, `Story/Effects.bs`, `Story/EventRules.bs`, `Story/Items.bs`, `Story/QuestData.bs`, `Story/DialogueData.bs`, `Story/Checkpoints.bs`.

**rpg, entities/scenes/UI (device-checked)**
- Create `World/Gate.bs`, `World/FloorSwitch.bs`, `World/Pickup.bs`, `World/LootDrop.bs`, `World/Pot.bs`, `World/PotShard.bs`.
- Create `Entities/Goblin.bs`, `Entities/GoblinKing.bs`.
- Create `UI/BossBar.bs`.
- Create `Scenes/DungeonScenes.bs` (Guardroom/Storeroom/Barracks/Antechamber/KingsHall) and `Scenes/GoblinShowcaseScene.bs`.
- Modify `Scenes/AreaScene.bs`, `Entities/Enemy.bs`, `Entities/Player.bs`, `Story/Story.bs`, `UI/HeartsHud.bs`, `UI/InventoryPanel.bs`, `main.bs`.

**Tests (`examples/rpg/tests/`)**: new `LivePlacements.spec.bs`, `Loot.spec.bs`, `Dungeon.spec.bs`, `DebugParams.spec.bs`, `PickupRules.spec.bs`; extended `Effects.spec.bs`, `EventRules.spec.bs`, `DialogueData.spec.bs`.

**Assets**: `src/sprites/goblin.png`, `src/sprites/items/keys.png`, `src/sprites/indoorTiles.png`, `src/sprites/CREDITS.md`.

All rpg paths below are relative to `examples/rpg/src/source/` unless they start with `examples/` or `src/`.

---

### Task 1: `SolidWorld.removeSolid` (engine)

**Files:**
- Modify: `src/source/engine/colliders/SolidWorld.bs:57-89` (fields, `addSolid`)
- Test: `src/source/engine/colliders/SolidWorld.spec.bs`

**Interfaces:**
- Produces: `function addSolid(x as float, y as float, w as float, h as float) as string` (returns the solid's id); `function removeSolid(id as string) as boolean`.

- [ ] **Step 1: Write the failing tests.** Add a new `@describe("removing solids")` block at the end of the suite class in `SolidWorld.spec.bs` (before `end class`):

```brighterscript
    @describe("removing solids")

    @it("lets a mover pass where a removed solid was")
    function _()
      world = new BGE.SolidWorld()
      id = world.addSolid(40, 0, 20, 20)
      m.assertTrue(world.removeSolid(id))
      result = world.moveAndSlide({x: 0, y: 0, w: 10, h: 10}, 100, 0)
      m.assertEqual(100.0, result.x)
      m.assertFalse(result.blockedX)
    end function

    @it("returns false for an unknown or already removed id")
    function _()
      world = new BGE.SolidWorld()
      id = world.addSolid(0, 0, 10, 10)
      m.assertFalse(world.removeSolid("nope"))
      m.assertTrue(world.removeSolid(id))
      m.assertFalse(world.removeSolid(id))
    end function

    @it("keeps ids unique after a removal")
    function _()
      world = new BGE.SolidWorld()
      first = world.addSolid(0, 0, 10, 10)
      second = world.addSolid(20, 0, 10, 10)
      world.removeSolid(first)
      third = world.addSolid(40, 0, 10, 10)
      m.assertNotEqual(second, third)
      m.assertEqual(2, world.getSolidCount())
      m.assertEqual(2, world.getSolids().count())
    end function

    @it("removes a solid from every bucket it spans")
    function _()
      world = new BGE.SolidWorld(32)
      id = world.addSolid(0, 0, 200, 10)
      world.removeSolid(id)
      m.assertTrue(world.isAreaFree(180, 0, 10, 10))
      m.assertTrue(world.isAreaFree(0, 0, 10, 10))
    end function
```

- [ ] **Step 2: Run to verify they fail.** Run: `npm run test:ci` (repo root). Expected: FAIL (validation error, `removeSolid` doesn't exist, or the first assertion on `id`).

- [ ] **Step 3: Implement.** In `SolidWorld.bs`, add a field after `solids`:

```brighterscript
    private nextId as integer = 0
```

Replace `addSolid` with:

```brighterscript
    ' Adds a solid rectangle.
    '
    ' @param {float} x - bottom-left x
    ' @param {float} y - bottom-left y
    ' @param {float} w
    ' @param {float} h
    ' @return {string} the solid's id, for `removeSolid()`
    function addSolid(x as float, y as float, w as float, h as float) as string
      solid = {x: x, y: y, w: w, h: h, id: m.nextId.toStr()} as BGE.SolidWorldSolid
      m.nextId++
      m.solids.push(solid)
      for bx = m.bucketIndex(x) to m.bucketIndex(x + w)
        for by = m.bucketIndex(y) to m.bucketIndex(y + h)
          key = bx.toStr() + "," + by.toStr()
          if m.buckets[key] = invalid
            m.buckets[key] = []
          end if
          m.buckets[key].push(solid)
        end for
      end for
      return solid.id
    end function

    ' Removes a solid, e.g. a door that has opened. Movers can pass through it from then on.
    '
    ' @param {string} id - from `addSolid()`
    ' @return {boolean} true if a solid was removed, false if no solid has that id
    function removeSolid(id as string) as boolean
      index = -1
      for i = 0 to m.solids.count() - 1
        if m.solids[i].id = id
          index = i
          exit for
        end if
      end for
      if index < 0
        return false
      end if
      solid = m.solids[index]
      m.solids.Delete(index)
      for bx = m.bucketIndex(solid.x) to m.bucketIndex(solid.x + solid.w)
        for by = m.bucketIndex(solid.y) to m.bucketIndex(solid.y + solid.h)
          bucket = m.buckets[bx.toStr() + "," + by.toStr()]
          if bucket <> invalid
            for j = bucket.count() - 1 to 0 step -1
              if bucket[j].id = id
                bucket.Delete(j)
              end if
            end for
          end if
        end for
      end for
      return true
    end function
```

Update the `getSolidCount()` doc comment to "how many solids there are now".

- [ ] **Step 4: Run tests.** `npm run test:ci` → PASS. Then `npm run check` (lint + validate + tests) → PASS.

- [ ] **Step 5: Update CLAUDE.md.** In the `BGE.SolidWorld` bullet, change `` `addSolid()`/`addBounds()`/`isAreaFree()` `` to `` `addSolid()` (returns an id)/`removeSolid(id)`/`addBounds()`/`isAreaFree()` ``.

- [ ] **Step 6: Commit.**

```bash
git add src/source/engine/colliders/SolidWorld.bs src/source/engine/colliders/SolidWorld.spec.bs CLAUDE.md
git commit -m "SolidWorld: addSolid returns an id, add removeSolid (#289)"
```

---

### Task 2: Art, credits, bitmaps and atlas entries

**Files:**
- Create: `examples/rpg/src/sprites/goblin.png`, `examples/rpg/src/sprites/items/keys.png`, `examples/rpg/src/sprites/indoorTiles.png`
- Modify: `examples/rpg/src/sprites/CREDITS.md`, `main.bs:15-34`, `Maps/Atlas.bs` (castle interior section)

**Interfaces:**
- Produces bitmaps: `"goblin"` (704×320, 64×64 cells), `"smallKey"` and `"throneKey"` (32×32 icons), `"floorSwitch"` (32×32).
- Produces atlas keys: `archBars` (closed portcullis arch), `archOpen` (raised portcullis arch), both 84×82 from the `castle` sheet. `vase` already exists (pots).

- [ ] **Step 1: Copy the art.**

```bash
cp /Users/mpearce/Downloads/rpg/goblinsword.png examples/rpg/src/sprites/goblin.png
cp /Users/mpearce/Downloads/rpg/KeyIcons.png examples/rpg/src/sprites/items/keys.png
cp "/Users/mpearce/Downloads/rpg/rpg indoor tileset expansion 1 trans.png" examples/rpg/src/sprites/indoorTiles.png
```

- [ ] **Step 2: Credits.** Append to `examples/rpg/src/sprites/CREDITS.md`:

```markdown
## goblin.png
`goblinsword.png` from "[LPC] Goblin" by Stephen "Redshrike" Challener (graphic artist) and
William.Thompsonj (contributor). https://opengameart.org/content/lpc-goblin
License: CC-BY 3.0 (also CC-BY 4.0 / OGA-BY 3.0 / GPL 2.0 / GPL 3.0). Unmodified.

## items/keys.png
`KeyIcons.png` from "Key Icons" by BizmasterStudios. https://opengameart.org/content/key-icons
License: CC-BY 4.0. Unmodified.

## indoorTiles.png
"RPG Indoor Tileset: Expansion 1" by Stephen Challener (Redshrike) and Jetrel, hosted by
OpenGameArt.org. https://opengameart.org/content/rpg-indoor-tileset-expansion-1
License: CC-BY 3.0 (also OGA-BY 3.0 / GPL 2.0 / GPL 3.0). Unmodified; only a floor tile is used
(the floor switches).
```

- [ ] **Step 3: Load the bitmaps.** In `main.bs`, after the `swordRusty` line:

```brighterscript
  game.loadBitmap("goblin", "pkg:/sprites/goblin.png")
  game.loadBitmap("keys", "pkg:/sprites/items/keys.png")
  game.loadBitmap("indoor", "pkg:/sprites/indoorTiles.png")
```

and after the `coinIcon` lines:

```brighterscript
  ' 32px icons cut from the key strip: the iron key and the gold heart key.
  game.loadBitmap("smallKey", {width: 32, height: 32, AlphaEnable: true})
  game.getBitmap("smallKey").DrawObject(0, 0, CreateObject("roRegion", game.getBitmap("keys"), 0, 0, 32, 32))
  game.loadBitmap("throneKey", {width: 32, height: 32, AlphaEnable: true})
  game.getBitmap("throneKey").DrawObject(0, 0, CreateObject("roRegion", game.getBitmap("keys"), 64, 0, 32, 32))
  ' The indoor sheet's 16px teal floor tile at 2x, for floor switches.
  game.loadBitmap("floorSwitch", {width: 32, height: 32, AlphaEnable: true})
  game.getBitmap("floorSwitch").DrawScaledObject(0, 0, 2, 2, CreateObject("roRegion", game.getBitmap("indoor"), 80, 96, 16, 16))
```

- [ ] **Step 4: Atlas.** In `Maps/Atlas.bs`, inside the "Castle interior props" section, add:

```brighterscript
    ' Portcullis arches: closed (Gate) and raised (doorway decoration), 84x82.
    archBars: {sheet: "castle", x: 326, y: 112, w: 84, h: 82, footprint: invalid},
    archOpen: {sheet: "castle", x: 424, y: 112, w: 84, h: 82, footprint: invalid},
```

These coordinates were measured from a 3× crop and are checked on device in Task 16 (the arch must show no neighbouring brick seams). If the edges are off, adjust here only.

- [ ] **Step 5: Build.** Run: `cd examples/rpg && npx bsc --create-package=false`. Expected: no errors.

- [ ] **Step 6: Commit.**

```bash
git add examples/rpg/src/sprites examples/rpg/src/source/main.bs examples/rpg/src/source/Maps/Atlas.bs
git commit -m "rpg: goblin, key and floor-switch art, portcullis atlas entries (#289)"
```

---

### Task 3: Story vocabulary — keys, `message`, `storyUpdated`, new events

**Files:**
- Modify: `Story/StoryTypes.bs` (`StoryEffect`, `StoryResult`), `Story/Effects.bs`, `Story/EventRules.bs`, `Story/Items.bs`, `Story/Story.bs`, every other `StoryResult` literal (find with grep, Step 3)
- Test: `examples/rpg/tests/Effects.spec.bs`, `examples/rpg/tests/EventRules.spec.bs`

**Interfaces:**
- Produces: `StoryEffect.message as string`; `StoryResult.messages as string[]`; items `smallKey` (max 3, icon `"smallKey"`) and `throneKey` (max 1, icon `"throneKey"`).
- Produces on `Story`: `sub runEffects(effects as StoryEffect[])`, `sub showMessage(text as string)`, `sub tryUnlock(unlock as GateUnlock)` (added in Task 7, declared there), field `peaceful as boolean = false`, field `openOnArrival as string = ""`.
- Produces game events: `storyUpdated` (posted by `Story` after any applied change), and `Story.onGameEvent` routes `roomCleared` and `switchPressed` to the event rules.

- [ ] **Step 1: Write the failing tests.** In `Effects.spec.bs`, add before `end class`:

```brighterscript
    @describe("messages")

    @it("collects a message without counting it as a change")
    function _()
      result = applyEffects([{message: "Click."}], m.ctx)
      m.assertFalse(result.changed)
      m.assertEqual(["Click."], result.messages)
    end function

    @it("keeps messages in order alongside other effects")
    function _()
      result = applyEffects([{message: "One"}, {set: "a", value: true}, {message: "Two"}], m.ctx)
      m.assertTrue(result.changed)
      m.assertEqual(["One", "Two"], result.messages)
    end function

    @describe("keys")

    @it("carries up to three small keys and one throne key")
    function _()
      for i = 1 to 4
        applyEffects([{giveItem: "smallKey"}], m.ctx)
      end for
      applyEffects([{giveItem: "throneKey"}, {giveItem: "throneKey"}], m.ctx)
      m.assertEqual(3, m.ctx.inventory.count("smallKey"))
      m.assertEqual(1, m.ctx.inventory.count("throneKey"))
    end function
```

In `EventRules.spec.bs`, add before `end class`:

```brighterscript
    @describe("messages from rules")

    @it("passes a rule's messages through runEventRules and settleStory")
    function _()
      rules = [
        {event: "ping", effects: [{message: "pong"}]},
        {event: "storyChanged", when: [{flag: "x"}, {notFlag: "y"}], effects: [{set: "y", value: true}, {message: "settled"}]}
      ]
      m.assertEqual(["pong"], runEventRules(rules, "ping", {}, m.ctx).messages)
      m.ctx.flags.set("x", true)
      m.assertEqual(["settled"], settleStory(rules, m.ctx).messages)
    end function
```

- [ ] **Step 2: Run to verify they fail.** `cd examples/rpg && npm test` → FAIL (`messages` undefined).

- [ ] **Step 3: Types.** In `StoryTypes.bs`, add to `StoryEffect` (and append `message` to its "Exactly one of" comment):

```brighterscript
  ' Shown in a speaker-less dialogue box once nothing else is open.
  optional message as string
```

and to `StoryResult`:

```brighterscript
  ' message effects' text, in order
  messages as string[]
```

Then find every `StoryResult` literal and add `messages: []`:

```bash
grep -rn "posts: \[\]" examples/rpg/src examples/rpg/tests
```

Each `{changed: ..., posts: []}` becomes `{changed: ..., posts: [], messages: []}` (in `Effects.bs`, `EventRules.bs` ×2, `Story.bs` `buy`/`use`, and any test).

- [ ] **Step 4: Effects.** In `Effects.bs`, update the doc comment's effect list to include `{message}`, and in `applyEffect`, before the final `print`:

```brighterscript
  else if effect.DoesExist("message")
    result.messages.push(effect.message)
    return false
```

In the `giveItem` branch, after copying `acquired.posts`, also copy messages:

```brighterscript
    for each text in acquired.messages
      result.messages.push(text)
    end for
```

- [ ] **Step 5: Event rules.** In `EventRules.bs`, in `runEventRules` after `total.posts.append(result.posts)` add `total.messages.append(result.messages)`; in `settleStory` after `total.posts.append(result.posts)` add `total.messages.append(result.messages)`.

- [ ] **Step 6: Items.** In `Items.bs`'s `globals.rpgItems`:

```brighterscript
      smallKey: {name: "Small key", icon: "smallKey", max: 3},
      throneKey: {name: "Throne-room key", icon: "throneKey", max: 1}
```

- [ ] **Step 7: Run tests.** `cd examples/rpg && npm test` → PASS.

- [ ] **Step 8: Story entity.** In `Story.bs`:

Add fields:

```brighterscript
  ' Deep-link testing: skip enemy placements (--param peaceful=1).
  peaceful as boolean = false
  ' Deep-link testing: a panel to open once the first area has faded in ("inventory").
  openOnArrival as string = ""
  ' message effects waiting for every panel to close
  private pendingMessages as string[] = []
```

Route the new events in `onGameEvent`:

```brighterscript
    else if eventName = "enemyKilled" or eventName = "roomCleared" or eventName = "switchPressed"
      m.applyResult(runEventRules(getEventRules(), eventName, data, m.context()))
    end if
```

Add public methods:

```brighterscript
  ' Runs story effects for something in the world (a pickup, a switch, a door).
  sub runEffects(effects as StoryEffect[])
    m.applyResult(applyEffects(effects, m.context()))
  end sub

  ' Shows a speaker-less dialogue box once nothing else is open.
  sub showMessage(text as string)
    m.pendingMessages.push(text)
  end sub
```

Replace `applyResult` so messages queue and a `storyUpdated` event follows any change:

```brighterscript
  private sub applyResult(result as StoryResult)
    if not result.changed and result.posts.count() = 0 and result.messages.count() = 0
      return
    end if
    settled = settleStory(getEventRules(), m.context())
    m.syncPlayer()
    posts = [] as string[]
    posts.append(result.posts)
    posts.append(settled.posts)
    m.pendingMessages.append(result.messages)
    m.pendingMessages.append(settled.messages)
    if result.changed or settled.changed
      m.save()
    end if
    for each eventName in posts
      m.game.postGameEvent(eventName)
    end for
    if result.changed or settled.changed
      ' Live map placements (gates, keys) re-check their conditions on this.
      m.game.postGameEvent("storyUpdated")
    end if
  end sub
```

(`buy`/`use` pass `{changed: true, posts: [], messages: []}`, so they still save.)

Split `startDialogue` so a message can reuse the box. Replace the part from `m.openModal()` to the end of `startDialogue` with a call `m.openDialogue(page)` and add:

```brighterscript
  private sub openDialogue(page as DialoguePage)
    m.openModal()
    dialogue = new DialogueBox(m.game, page, m.flags)
    m.openPanel = dialogue
    dialogue.open(m.game.gameUi)
  end sub
```

At the end of `onUpdate`, show queued messages and the deep-link panel:

```brighterscript
    canOpen = not m.isModalOpen() and m.pendingReleases = 0 and not m.game.isTransitioning()
    if canOpen and m.pendingMessages.count() > 0
      text = m.pendingMessages.Shift()
      m.openDialogue({speaker: "", lines: [text]})
    else if canOpen and m.openOnArrival = "inventory" and m.sceneName <> ""
      m.openOnArrival = ""
      m.openInventory()
    end if
```

`finishDialogue` already handles a page with no effects and no NPC (`endTalking` checks `talkingNpc <> invalid`).

- [ ] **Step 9: Build and test.** `cd examples/rpg && npx bsc --create-package=false && npm test` → no errors, PASS.

- [ ] **Step 10: Commit.**

```bash
git add examples/rpg
git commit -m "rpg story: message effect, storyUpdated event, small and throne keys (#289)"
```

---

### Task 4: Live placements (pure) and new placement fields

**Files:**
- Modify: `Maps/MapTypes.bs`
- Create: `Maps/LivePlacements.bs`
- Modify: `examples/rpg/bsconfig.test.json` (add `"source/Maps/LivePlacements.bs"` after `MapData.bs`)
- Test: `examples/rpg/tests/LivePlacements.spec.bs`

**Interfaces:**
- Produces in `MapTypes.bs`: `interface GateUnlock` and new `MapPlacement` fields (below).
- Produces: `function diffLivePlacements(placements as MapPlacement[], present as roAssociativeArray, ctx as StoryContext) as LivePlacementDiff`, `interface LivePlacementDiff {add as integer[], remove as integer[]}`, `function nonLivePlacements(placements as MapPlacement[]) as MapPlacement[]`, `function isLivePlacement(item as MapPlacement) as boolean`. `present` is keyed by placement index as a string (`i.toStr()`).

- [ ] **Step 1: Types.** In `MapTypes.bs`, update `MapPlacement`'s comment to list the new types (`"gate"`, `"switch"`, `"pickup"`, `"pot"`) and add fields:

```brighterscript
  ' Re-checked whenever the story changes, not only when the area loads (see LivePlacements.bs).
  optional live as boolean
  ' gate: "bars", "shutter", "locked" or "great"
  optional style as string
  ' gate: the wall it's in - "n", "e", "w" or "s"
  optional side as string
  ' gate: what walking into it does
  optional unlock as GateUnlock
  ' switch: set to true once it's pressed
  optional flag as string
  ' pickup: the inventory item it represents (stays put while that item is at its cap)
  optional item as string
  ' pickup: bitmap name, when it isn't an inventory item's icon
  optional icon as string
  ' switch and pickup: run when stepped on
  optional effects as StoryEffect[]
```

and change `kind`'s comment to `' enemy: "rat", "bat", "goblin" or "goblinKing"` and `id`'s to `' spawn and switch`.

Add after `MapPlacement`:

```brighterscript
' What walking into a gate does: runs effects if `when` passes, otherwise shows lockedMessage.
interface GateUnlock extends roAssociativeArray
  optional when as StoryCondition[]
  effects as StoryEffect[]
  lockedMessage as string
end interface
```

- [ ] **Step 2: Write the failing tests.** Create `examples/rpg/tests/LivePlacements.spec.bs`:

```brighterscript
namespace tests
  @suite("live placements")
  class LivePlacementsTests extends rooibos.BaseTestSuite

    private ctx as object
    private placements as object

    protected override function beforeEach()
      m.ctx = newStoryContext(new StoryFlags(), new Inventory(getItemDefinitions()), {health: 6, maxHealth: 6, coins: 0})
      m.placements = [
        {atlasKey: "statue", col: 1, row: 1},
        {type: "gate", style: "bars", side: "n", live: true, col: 9, row: 2, w: 2, h: 1, when: [{notFlag: "open"}]},
        {type: "pickup", item: "smallKey", live: true, col: 5, row: 5, when: [{flag: "cleared"}, {notFlag: "taken"}]},
        {type: "enemy", kind: "rat", col: 3, row: 3, when: [{notFlag: "open"}]}
      ]
    end function

    @it("builds live placements whose conditions pass, ignoring non-live ones")
    function _()
      diff = diffLivePlacements(m.placements, {}, m.ctx)
      m.assertEqual([1], diff.add)
      m.assertEqual([], diff.remove)
    end function

    @it("removes a present gate once its flag is set, and adds the key once cleared")
    function _()
      m.ctx.flags.set("open", true)
      m.ctx.flags.set("cleared", true)
      diff = diffLivePlacements(m.placements, {"1": true}, m.ctx)
      m.assertEqual([2], diff.add)
      m.assertEqual([1], diff.remove)
    end function

    @it("changes nothing when what's present already matches")
    function _()
      diff = diffLivePlacements(m.placements, {"1": true}, m.ctx)
      m.assertEqual([], diff.add)
      m.assertEqual([], diff.remove)
    end function

    @it("builds nothing on re-entry once everything is done")
    function _()
      m.ctx.flags.set("open", true)
      m.ctx.flags.set("cleared", true)
      m.ctx.flags.set("taken", true)
      diff = diffLivePlacements(m.placements, {}, m.ctx)
      m.assertEqual([], diff.add)
    end function

    @it("leaves only non-live placements for the one-off build")
    function _()
      rest = nonLivePlacements(m.placements)
      m.assertEqual(2, rest.count())
      m.assertEqual("statue", rest[0].atlasKey)
      m.assertEqual("enemy", rest[1].type)
    end function

  end class
end namespace
```

- [ ] **Step 3: Run to verify it fails.** Add `"source/Maps/LivePlacements.bs"` to `bsconfig.test.json`'s `files` (after `"source/Maps/MapData.bs"`), then `cd examples/rpg && npm test` → FAIL (file missing).

- [ ] **Step 4: Implement.** Create `Maps/LivePlacements.bs`:

```brighterscript
' Placements with `live: true` are kept in step with the story while an area is open: a gate
' whose `when` stops passing is removed, a key whose `when` starts passing appears.
import "MapTypes.bs"
import "../Story/Conditions.bs"
import "../Story/StoryTypes.bs"

interface LivePlacementDiff
  ' indexes into the placements to build now
  add as integer[]
  ' indexes into the placements to take away now
  remove as integer[]
end interface

function isLivePlacement(item as MapPlacement) as boolean
  return item.live <> invalid and item.live
end function

' @param {MapPlacement[]} placements - every placement in the area
' @param {roAssociativeArray} present - index (as a string) -> anything, for each live placement built
' @param {StoryContext} ctx
' @return {LivePlacementDiff}
function diffLivePlacements(placements as MapPlacement[], present as roAssociativeArray, ctx as StoryContext) as LivePlacementDiff
  diff = {add: [], remove: []} as LivePlacementDiff
  for i = 0 to placements.count() - 1
    item = placements[i]
    if isLivePlacement(item)
      wanted = evaluateConditions(item.when, ctx)
      isPresent = present.DoesExist(i.toStr())
      if wanted and not isPresent
        diff.add.push(i)
      else if not wanted and isPresent
        diff.remove.push(i)
      end if
    end if
  end for
  return diff
end function

' @param {MapPlacement[]} placements
' @return {MapPlacement[]} the placements built once when the area loads
function nonLivePlacements(placements as MapPlacement[]) as MapPlacement[]
  rest = [] as MapPlacement[]
  for each item in placements
    if not isLivePlacement(item)
      rest.push(item)
    end if
  end for
  return rest
end function
```

- [ ] **Step 5: Run tests.** `cd examples/rpg && npm test` → PASS.

- [ ] **Step 6: Commit.**

```bash
git add examples/rpg
git commit -m "rpg map: live placements re-checked on story changes (#289)"
```

---

### Task 5: `Pickup` entity and its collect rule

**Files:**
- Create: `World/PickupRules.bs` (pure), `World/Pickup.bs`
- Modify: `examples/rpg/bsconfig.test.json` (add `"source/World/PickupRules.bs"`)
- Test: `examples/rpg/tests/PickupRules.spec.bs`

**Interfaces:**
- Consumes: `Story.runEffects()` (Task 3).
- Produces: `function canCollectPickup(itemId as dynamic, carried as Inventory) as boolean` (`itemId` is a string or `invalid`); `class Pickup extends BGE.GameEntity` with `onCreate(args)` taking `{x, y (feet), item?, icon?, effects}`.

- [ ] **Step 1: Write the failing test.** Create `examples/rpg/tests/PickupRules.spec.bs`:

```brighterscript
namespace tests
  @suite("pickup rules")
  class PickupRulesTests extends rooibos.BaseTestSuite

    @it("collects a non-item pickup any time")
    function _()
      m.assertTrue(canCollectPickup(invalid, new Inventory(getItemDefinitions())))
    end function

    @it("leaves an item on the floor while it's at its cap")
    function _()
      carried = new Inventory(getItemDefinitions())
      for i = 1 to 3
        carried.add("smallKey")
        carried.add("potion")
      end for
      m.assertFalse(canCollectPickup("smallKey", carried))
      m.assertFalse(canCollectPickup("potion", carried))
      carried.remove("potion")
      m.assertTrue(canCollectPickup("potion", carried))
    end function

  end class
end namespace
```

- [ ] **Step 2: Run to verify it fails.** Add `"source/World/PickupRules.bs"` to `bsconfig.test.json` after `"source/World/Spawning.bs"`; `cd examples/rpg && npm test` → FAIL.

- [ ] **Step 3: Implement the rule.** Create `World/PickupRules.bs`:

```brighterscript
import "../Story/Inventory.bs"

' Whether walking over a pickup collects it. A pickup for an item already at its cap stays put.
'
' @param {dynamic} itemId - the pickup's item, or invalid for one that isn't an inventory item
' @param {Inventory} carried
' @return {boolean}
function canCollectPickup(itemId as dynamic, carried as Inventory) as boolean
  if itemId = invalid
    return true
  end if
  return carried.canAdd(itemId)
end function
```

- [ ] **Step 4: Run tests.** `cd examples/rpg && npm test` → PASS.

- [ ] **Step 5: The entity.** Create `World/Pickup.bs` (modelled on `Entities/Coin.bs`):

```brighterscript
import "PickupRules.bs"
import "../Story/Story.bs"
import "../Story/StoryTypes.bs"

' How big a pickup's icon is drawn in the world (icons are 32-36px).
const PICKUP_SIZE = 20.0
const PICKUP_BOB_HEIGHT = 2.0

' Something on the floor that runs story effects when the player walks over it: a key, a potion,
' a heart container.
class Pickup extends BGE.GameEntity

  private itemId as dynamic = invalid
  private effects as StoryEffect[] = []
  private time as float = 0.0
  private image as BGE.Image = invalid

  sub new(game as BGE.Game)
    super(game)
    m.name = "Pickup"
  end sub

  ' @param {roAssociativeArray} args - {x, y (bottom-centre), effects, item (optional), icon (optional)}
  override sub onCreate(args as roAssociativeArray)
    m.position.x = args.x
    m.position.y = args.y
    m.position.z = -args.y
    m.itemId = args.item
    m.effects = args.effects
    iconName = args.icon
    if iconName = invalid
      storyEntity = m.game.getEntityByName("Story") as Story
      iconName = storyEntity.context().items[m.itemId].icon
    end if
    bitmap = m.game.getBitmap(iconName)
    scale = PICKUP_SIZE / bitmap.GetWidth()
    m.image = m.addImage("icon", CreateObject("roRegion", bitmap, 0, 0, bitmap.GetWidth(), bitmap.GetHeight()), {
      offset: BGE.Math.VectorOps.create(-PICKUP_SIZE / 2, PICKUP_SIZE),
      scale: BGE.Math.VectorOps.create(scale, scale, 1),
      drawMode: BGE.SceneObjectDrawMode.matchCamera
    })
    m.addRectangleCollider("pickup", PICKUP_SIZE - 4, PICKUP_SIZE - 4, -(PICKUP_SIZE - 4) / 2, PICKUP_SIZE - 4)
  end sub

  override sub onUpdate(dt as float)
    m.time += dt
    m.image.offset.y = PICKUP_SIZE + PICKUP_BOB_HEIGHT + Sin(m.time * 5) * PICKUP_BOB_HEIGHT
  end sub

  override sub onCollisionEnter(myCollider as BGE.Collider, otherCollider as BGE.Collider, otherEntity as BGE.GameEntity)
    if otherEntity.name <> "Player" or otherCollider.name <> "feet" or not m.isValid()
      return
    end if
    storyEntity = m.game.getEntityByName("Story") as Story
    if not canCollectPickup(m.itemId, storyEntity.inventory)
      return
    end if
    m.game.playSound("coin")
    m.invalidate()
    storyEntity.runEffects(m.effects)
  end sub

end class
```

Note: `invalidate()` comes before `runEffects`, so the `storyUpdated` diff (Task 7) sees this pickup already gone.

- [ ] **Step 6: Build.** `cd examples/rpg && npx bsc --create-package=false` → no errors.

- [ ] **Step 7: Commit.**

```bash
git add examples/rpg
git commit -m "rpg: Pickup entity for keys, potions and hearts (#289)"
```

---

### Task 6: Loot tables

**Files:**
- Create: `Entities/Loot.bs` (pure), `World/LootDrop.bs`
- Modify: `Entities/Enemy.bs` (replace `dropCoin`), `examples/rpg/bsconfig.test.json` (add `"source/Entities/Loot.bs"`)
- Test: `examples/rpg/tests/Loot.spec.bs`

**Interfaces:**
- Consumes: `Pickup` (Task 5).
- Produces: `interface LootEntry {drop as string, chance as float}`; `function pickLoot(table as LootEntry[], roll as float) as string` (`"coin"`, `"potion"` or `""`); `sub spawnLoot(game as BGE.Game, drop as string, x as float, y as float)`; on `Enemy`: `protected function lootTable() as LootEntry[]` (default 50% coin).

- [ ] **Step 1: Write the failing test.** Create `examples/rpg/tests/Loot.spec.bs`:

```brighterscript
namespace tests
  @suite("loot")
  class LootTests extends rooibos.BaseTestSuite

    @it("picks entries by their share of the roll, in order")
    @params(0.0, "potion")
    @params(0.24, "potion")
    @params(0.25, "coin")
    @params(0.49, "coin")
    @params(0.5, "")
    @params(0.99, "")
    function _(roll, expected)
      table = [{drop: "potion", chance: 0.25}, {drop: "coin", chance: 0.25}]
      m.assertEqual(expected, pickLoot(table, roll))
    end function

    @it("drops nothing from an empty table")
    function _()
      m.assertEqual("", pickLoot([], 0.1))
    end function

  end class
end namespace
```

- [ ] **Step 2: Run to verify it fails.** Add `"source/Entities/Loot.bs"` to `bsconfig.test.json` after `"source/Entities/Combat.bs"`; `cd examples/rpg && npm test` → FAIL.

- [ ] **Step 3: Implement.** Create `Entities/Loot.bs`:

```brighterscript
' What might drop when an enemy dies or a pot breaks.
interface LootEntry
  ' "coin" or "potion"
  drop as string
  ' 0-1
  chance as float
end interface

' Entries are tried in order, each taking its chance's share of the 0-1 roll.
'
' @param {LootEntry[]} table
' @param {float} roll - 0 to <1
' @return {string} the drop, or "" for nothing
function pickLoot(table as LootEntry[], roll as float) as string
  cumulative = 0.0
  for each entry in table
    cumulative += entry.chance
    if roll < cumulative
      return entry.drop
    end if
  end for
  return ""
end function
```

- [ ] **Step 4: Run tests.** `cd examples/rpg && npm test` → PASS.

- [ ] **Step 5: Spawning a drop.** Create `World/LootDrop.bs`:

```brighterscript
import "../Entities/Coin.bs"
import "Pickup.bs"

' Puts a loot drop on the floor at a point (bottom-centre).
'
' @param {BGE.Game} game
' @param {string} drop - from pickLoot(): "coin", "potion" or ""
' @param {float} x
' @param {float} y
sub spawnLoot(game as BGE.Game, drop as string, x as float, y as float)
  if drop = "coin"
    newCoin = new Coin(game)
    game.addEntity(newCoin, {x: x, y: y})
  else if drop = "potion"
    newPickup = new Pickup(game)
    game.addEntity(newPickup, {x: x, y: y, item: "potion", effects: [{giveItem: "potion"}]})
  end if
end sub
```

- [ ] **Step 6: Enemy uses it.** In `Entities/Enemy.bs`: import `"Loot.bs"` and `"../World/LootDrop.bs"` (drop the `Coin.bs` import); in `onUpdate` replace `m.dropCoin()` with `m.dropLoot()`; replace `dropCoin` with:

```brighterscript
  ' What this enemy might drop. Overridden by enemy types with different loot.
  '
  ' @return {LootEntry[]}
  protected function lootTable() as LootEntry[]
    return [{drop: "coin", chance: ENEMY_COIN_CHANCE}]
  end function

  private sub dropLoot()
    drop = pickLoot(m.lootTable(), Rnd(0))
    if drop = ""
      return
    end if
    ' A bat can die over water or a wall, where a drop couldn't be reached. Checks the feet
    ' box, which a walker is always clear of even when flush against a wall.
    if not m.solidWorld.isAreaFree(m.position.x - m.boxW / 2, m.position.y, m.boxW, m.boxH)
      return
    end if
    spawnLoot(m.game, drop, m.position.x, m.position.y)
  end sub
```

- [ ] **Step 7: Build and test.** `cd examples/rpg && npx bsc --create-package=false && npm test` → no errors, PASS.

- [ ] **Step 8: Commit.**

```bash
git add examples/rpg
git commit -m "rpg: loot tables replace the hardcoded coin drop (#289)"
```

---

### Task 7: `Gate` entity and live placements in `AreaScene`

**Files:**
- Create: `World/Gate.bs`
- Modify: `Scenes/AreaScene.bs`, `Scenes/TownScene.bs` (call `super.onGameEvent`), `Story/Story.bs` (add `tryUnlock`)

**Interfaces:**
- Consumes: `SolidWorld.addSolid/removeSolid` (Task 1), `diffLivePlacements`/`nonLivePlacements` (Task 4), `Pickup` (Task 5), `Story.runEffects/showMessage` (Task 3).
- Produces: `class Gate extends BGE.GameEntity` with `onCreate({x, y, w, h, style, side, unlock, solidWorld})` (px, bottom-left of the opening) and `sub open()`. On `Story`: `sub tryUnlock(unlock as GateUnlock)`. On `AreaScene`: `protected function buildPlacement(item as MapPlacement, numRows as integer) as BGE.GameEntity` (returns the entity or `invalid`), `placements as MapPlacement[]`, `liveEntities as roAssociativeArray`.

- [ ] **Step 1: `Story.tryUnlock`.** In `Story.bs` add (import `"../Maps/MapTypes.bs"` for `GateUnlock`):

```brighterscript
  ' Called when the player walks into a gate: runs its effects if its conditions pass, or says
  ' why it won't open.
  sub tryUnlock(unlock as GateUnlock)
    if m.isModalOpen()
      return
    end if
    if evaluateConditions(unlock.when, m.context())
      m.runEffects(unlock.effects)
    else
      m.showMessage(unlock.lockedMessage)
    end if
  end sub
```

- [ ] **Step 2: Gate.** Create `World/Gate.bs`:

```brighterscript
import "pkg:/source/engine/colliders/SolidWorld.bs"
import "pkg:/source/utils/CountdownTimer.bs"
import "../Maps/Atlas.bs"
import "../Maps/MapTypes.bs"
import "AtlasRegion.bs"
import "../Story/Story.bs"

const GATE_FADE_SECONDS = 0.3
' Iron bars across a side or bottom opening (packed RGB).
const GATE_IRON_RGB = &h2E2E36
const GATE_BAR_RGB = &h6A6A78
' How far past the solid the player's feet are noticed walking into it.
const GATE_TRIGGER_MARGIN = 4.0

' Blocks a doorway: a solid in the area's SolidWorld plus its art. North-wall gates draw the
' closed portcullis arch; side and bottom gates draw iron bars. A locked or great gate also
' shows a key, and walking into it asks the Story to unlock it. When its live placement is
' removed it fades out (see open()).
class Gate extends BGE.GameEntity

  private solidWorld as BGE.SolidWorld = invalid
  private solidId as string = ""
  private unlock as GateUnlock = invalid
  private isOpening as boolean = false
  private fadeTimer as BGE.CountdownTimer = new BGE.CountdownTimer()

  sub new(game as BGE.Game)
    super(game)
    m.name = "Gate"
  end sub

  ' @param {roAssociativeArray} args - {x, y (bottom-left, px), w, h (px), style, side, unlock, solidWorld}
  override sub onCreate(args as roAssociativeArray)
    m.position.x = args.x
    m.position.y = args.y
    m.position.z = -args.y
    m.solidWorld = args.solidWorld
    m.unlock = args.unlock
    m.solidId = m.solidWorld.addSolid(args.x, args.y, args.w, args.h)
    if args.side = "n"
      entry = getAtlas()["archBars"] as AtlasEntry
      m.addImage("bars", atlasRegion(m.game, entry), {
        offset: BGE.Math.VectorOps.create((args.w - entry.w) / 2, entry.h),
        drawMode: BGE.SceneObjectDrawMode.matchCamera
      })
    else
      m.addIronBars(args.w, args.h, args.side)
    end if
    keyIcon = ""
    if args.style = "locked"
      keyIcon = "smallKey"
    else if args.style = "great"
      keyIcon = "throneKey"
    end if
    if keyIcon <> ""
      bitmap = m.game.getBitmap(keyIcon)
      m.addImage("key", CreateObject("roRegion", bitmap, 0, 0, 32, 32), {
        offset: BGE.Math.VectorOps.create((args.w - 32) / 2, args.h + 32),
        drawMode: BGE.SceneObjectDrawMode.matchCamera
      })
    end if
    margin = GATE_TRIGGER_MARGIN
    m.addRectangleCollider("trigger", args.w + margin * 2, args.h + margin * 2, -margin, args.h + margin)
  end sub

  ' Fades out and stops blocking. The solid goes at once, so the player can walk on.
  sub open()
    if m.isOpening
      return
    end if
    m.isOpening = true
    m.solidWorld.removeSolid(m.solidId)
    m.colliders["trigger"].enabled = false
    m.fadeTimer.start(GATE_FADE_SECONDS)
  end sub

  override sub onUpdate(dt as float)
    if not m.isOpening
      return
    end if
    m.fadeTimer.tick(dt)
    for each drawableObj in m.drawables
      drawableObj.alpha = 255 * m.fadeTimer.remaining() / GATE_FADE_SECONDS
    end for
    if not m.fadeTimer.isActive()
      m.invalidate()
    end if
  end sub

  override sub onCollisionEnter(myCollider as BGE.Collider, otherCollider as BGE.Collider, otherEntity as BGE.GameEntity)
    if m.unlock = invalid or m.isOpening or otherEntity.name <> "Player" or otherCollider.name <> "feet"
      return
    end if
    storyEntity = m.game.getEntityByName("Story") as Story
    storyEntity.tryUnlock(m.unlock)
  end sub

  ' A dark frame with lighter bars running across the opening.
  private sub addIronBars(w as float, h as float, side as string)
    m.addRectangle("frame", w, h, {color: GATE_IRON_RGB, offset: BGE.Math.VectorOps.create(0, h)})
    for i = 1 to 3
      if side = "s"
        barX = w * i / 4 - 2
        m.addRectangle("bar" + i.toStr(), 4, h, {color: GATE_BAR_RGB, offset: BGE.Math.VectorOps.create(barX, h)})
      else
        barY = h * i / 4 + 2
        m.addRectangle("bar" + i.toStr(), w, 4, {color: GATE_BAR_RGB, offset: BGE.Math.VectorOps.create(0, barY)})
      end if
    end for
  end sub

end class
```

`Drawable.alpha` is 0-255 (see `Enemy`'s fade, which multiplies a stored alpha). If the arch's bottom sits inside the wall rather than on the floor line, adjust the `offset` y here after the Task 16 screenshot.

- [ ] **Step 3: AreaScene builds placements by type, including live ones.** In `Scenes/AreaScene.bs`:

Imports: add `"../Maps/LivePlacements.bs"`, `"../World/Gate.bs"`, `"../World/Pickup.bs"`.

Fields:

```brighterscript
  ' Every placement, so live ones can be built later by index.
  placements as MapPlacement[] = []
  ' Placement index (as a string) -> the entity built for each live placement present now.
  liveEntities as roAssociativeArray = {}
  private numRows as integer = 0
```

Replace the body of `onCreate` from `tileMap = new TileMapEntity(...)` up to (not including) `spawnId = args.spawn` with:

```brighterscript
    m.numRows = numRows
    tileMap = new TileMapEntity(m.game)
    m.game.addEntity(tileMap, {rows: rows, solidWorld: m.solidWorld})
    storyEntity = m.game.getEntityByName("Story") as Story
    m.placements = m.getPlacements()
    built = filterPlacements(nonLivePlacements(m.placements), storyEntity.context())
    addPlacementSolids(m.solidWorld, built, numRows)
    for each item in built
      m.buildPlacement(item, numRows)
    end for
    m.liveEntities = {}
    m.refreshLivePlacements()
```

Add `buildPlacement` (moving the old loop body into it) and the refresh:

```brighterscript
  ' Builds one placement's entity (or records its spawn/drain point).
  '
  ' @return {BGE.GameEntity} the entity added, or invalid
  protected function buildPlacement(item as MapPlacement, numRows as integer) as BGE.GameEntity
    storyEntity = m.game.getEntityByName("Story") as Story
    x = item.col * TILE_SIZE
    y = cellBottomY(numRows, item.row)
    if item.atlasKey <> invalid
      newProp = new Prop(m.game)
      m.game.addEntity(newProp, {atlasKey: item.atlasKey, x: x, y: y, solidWorld: m.solidWorld})
      return newProp
    else if item.type = "door"
      newDoor = new Door(m.game)
      m.game.addEntity(newDoor, {x: x, y: y, w: item.w * TILE_SIZE, h: item.h * TILE_SIZE, target: item.target, spawn: item.spawn})
      return newDoor
    else if item.type = "enemy"
      if storyEntity.peaceful
        return invalid
      end if
      return m.addEnemy(item, numRows)
    else if item.type = "drain"
      m.drains.push(enemySpawnPoint(item, numRows))
    else if item.type = "npc"
      feet = npcSpawnPoint(item, numRows)
      newNpc = new Npc(m.game)
      m.game.addEntity(newNpc, {npcId: item.npcId, character: item.character, x: feet.x, y: feet.y, facing: item.facing, wander: item.wander * 1.0, solidWorld: m.solidWorld})
      return newNpc
    else if item.type = "spawn"
      ' Feet a little above the cell's bottom edge, so the 12px-tall feet box sits inside the cell.
      m.spawns[item.id] = {x: x, y: y + 10, facing: item.facing}
    else if item.type = "gate"
      newGate = new Gate(m.game)
      m.game.addEntity(newGate, {x: x, y: y, w: item.w * TILE_SIZE, h: item.h * TILE_SIZE, style: item.style, side: item.side, unlock: item.unlock, solidWorld: m.solidWorld})
      return newGate
    else if item.type = "pickup"
      feet = enemySpawnPoint(item, numRows)
      newPickup = new Pickup(m.game)
      m.game.addEntity(newPickup, {x: feet.x, y: feet.y, item: item.item, icon: item.icon, effects: item.effects})
      return newPickup
    end if
    return invalid
  end function

  ' Brings live placements in line with the story: builds the ones whose `when` now passes and
  ' removes (opens, for a gate) the ones whose `when` no longer does.
  private sub refreshLivePlacements()
    storyEntity = m.game.getEntityByName("Story") as Story
    diff = diffLivePlacements(m.placements, m.liveEntities, storyEntity.context())
    for each index in diff.remove
      key = index.toStr()
      entity = m.liveEntities[key] as BGE.GameEntity
      m.liveEntities.Delete(key)
      if entity.isValid()
        if entity.name = "Gate"
          (entity as Gate).open()
        else
          entity.invalidate()
        end if
      end if
    end for
    for each index in diff.add
      m.liveEntities[index.toStr()] = m.buildPlacement(m.placements[index], m.numRows)
    end for
  end sub

  override sub onGameEvent(eventName as string, data as roAssociativeArray)
    if eventName = "storyUpdated"
      m.refreshLivePlacements()
    end if
  end sub
```

`TownScene` already overrides `onGameEvent` (for `gateOpened`); add `super.onGameEvent(eventName, data)` as the first line of its override so the town keeps refreshing live placements too.

Change `addEnemy` to a function returning the enemy (`as BGE.GameEntity`), returning `newBat`/`newRat`. A live placement whose entity is `invalid` (e.g. a spawn) would be rebuilt every refresh — live placements are only ever gates, pickups and (Task 8) switches, all of which return an entity.

- [ ] **Step 4: Build and test.** `cd examples/rpg && npx bsc --create-package=false && npm test` → no errors, PASS. The town gate still works through `filterPlacements` (its plug/knight aren't live).

- [ ] **Step 5: Commit.**

```bash
git add examples/rpg
git commit -m "rpg: Gate entity and live placements in AreaScene (#289)"
```

---

### Task 8: `FloorSwitch`

**Files:**
- Create: `World/FloorSwitch.bs`
- Modify: `Scenes/AreaScene.bs` (`buildPlacement`: `"switch"` type)

**Interfaces:**
- Consumes: `Story.runEffects` (Task 3), bitmap `"floorSwitch"` (Task 2), `GROUND_Z` (`Maps/MapData.bs`).
- Produces: `class FloorSwitch extends BGE.GameEntity`, `onCreate({x, y (cell bottom-left), id, flag, effects})`; posts `switchPressed {id}`.

- [ ] **Step 1: The entity.** Create `World/FloorSwitch.bs`:

```brighterscript
import "../Maps/MapData.bs"
import "../Story/Story.bs"
import "../Story/StoryTypes.bs"

' Sprite tint once pressed (packed RGB).
const SWITCH_PRESSED_RGB = &h707070
const SWITCH_SIZE = 32.0

' A floor plate that stays down once the player steps on it: sets its flag, runs its effects
' and posts "switchPressed". Reads its flag when built, so it's still down after a reload.
class FloorSwitch extends BGE.GameEntity

  private switchId as string = ""
  private flag as string = ""
  private effects as StoryEffect[] = []
  private pressed as boolean = false
  private image as BGE.Image = invalid

  sub new(game as BGE.Game)
    super(game)
    m.name = "FloorSwitch"
  end sub

  ' @param {roAssociativeArray} args - {x, y (cell bottom-left), id, flag, effects}
  override sub onCreate(args as roAssociativeArray)
    m.position.x = args.x
    m.position.y = args.y
    ' Just above the ground tiles, under everything standing on it.
    m.position.z = GROUND_Z + 1
    m.switchId = args.id
    m.flag = args.flag
    if args.effects <> invalid
      m.effects = args.effects
    end if
    bitmap = m.game.getBitmap("floorSwitch")
    m.image = m.addImage("plate", CreateObject("roRegion", bitmap, 0, 0, SWITCH_SIZE, SWITCH_SIZE), {
      offset: BGE.Math.VectorOps.create(0, SWITCH_SIZE),
      drawMode: BGE.SceneObjectDrawMode.matchCamera
    })
    storyEntity = m.game.getEntityByName("Story") as Story
    if storyEntity.flags.isSet(m.flag)
      m.showPressed()
    end if
    m.addRectangleCollider("plate", SWITCH_SIZE - 8, SWITCH_SIZE - 8, 4, SWITCH_SIZE - 4)
  end sub

  override sub onCollisionEnter(myCollider as BGE.Collider, otherCollider as BGE.Collider, otherEntity as BGE.GameEntity)
    if m.pressed or otherEntity.name <> "Player" or otherCollider.name <> "feet"
      return
    end if
    m.showPressed()
    m.game.playSound("enemyHit")
    effects = [{set: m.flag, value: true}] as StoryEffect[]
    effects.append(m.effects)
    storyEntity = m.game.getEntityByName("Story") as Story
    storyEntity.runEffects(effects)
    m.game.postGameEvent("switchPressed", {id: m.switchId})
  end sub

  private sub showPressed()
    m.pressed = true
    m.image.color = SWITCH_PRESSED_RGB
  end sub

end class
```

- [ ] **Step 2: Build it from placements.** In `AreaScene.buildPlacement`, before the final `return invalid`, add (and import `"../World/FloorSwitch.bs"`):

```brighterscript
    else if item.type = "switch"
      newSwitch = new FloorSwitch(m.game)
      m.game.addEntity(newSwitch, {x: x, y: y, id: item.id, flag: item.flag, effects: item.effects})
      return newSwitch
```

(put it as another `else if` branch of the chain).

- [ ] **Step 3: Build.** `cd examples/rpg && npx bsc --create-package=false` → no errors.

- [ ] **Step 4: Commit.**

```bash
git add examples/rpg
git commit -m "rpg: FloorSwitch (#289)"
```

---

### Task 9: Pots and room clears

**Files:**
- Create: `World/Pot.bs`, `World/PotShard.bs`
- Modify: `Entities/Player.bs:209-229` (`onCollision`), `Scenes/AreaScene.bs` (`"pot"` type, room-clear tracking)

**Interfaces:**
- Consumes: `pickLoot`/`LootEntry` (Task 6), `spawnLoot` (Task 6), `removeSolid` (Task 1), atlas `vase`.
- Produces: `class Pot` (tag `"breakable"`, collider `"body"`, `sub smash()`); `AreaScene` posts `roomCleared {room: m.name}` once all the room's enemies are dead.

- [ ] **Step 1: Shards.** Create `World/PotShard.bs`:

```brighterscript
import "pkg:/source/utils/CountdownTimer.bs"

const SHARD_SECONDS = 0.4
const SHARD_RGB = &hB0643C

' A fragment of a broken pot that flies out and fades.
class PotShard extends BGE.GameEntity

  private timer as BGE.CountdownTimer = new BGE.CountdownTimer()
  private piece as BGE.DrawableRectangle = invalid

  sub new(game as BGE.Game)
    super(game)
    m.name = "PotShard"
  end sub

  ' @param {roAssociativeArray} args - {x, y, vx, vy (px/sec)}
  override sub onCreate(args as roAssociativeArray)
    m.position.x = args.x
    m.position.y = args.y
    m.position.z = -args.y
    m.velocity.x = args.vx
    m.velocity.y = args.vy
    m.piece = m.addRectangle("piece", 4, 4, {color: SHARD_RGB, offset: BGE.Math.VectorOps.create(-2, 6)})
    m.timer.start(SHARD_SECONDS)
  end sub

  override sub onUpdate(dt as float)
    m.timer.tick(dt)
    m.piece.alpha = 255 * m.timer.remaining() / SHARD_SECONDS
    if not m.timer.isActive()
      m.invalidate()
    end if
  end sub

end class
```

- [ ] **Step 2: Pot.** Create `World/Pot.bs`:

```brighterscript
import "pkg:/source/engine/colliders/SolidWorld.bs"
import "../Maps/Atlas.bs"
import "../Entities/Loot.bs"
import "AtlasRegion.bs"
import "LootDrop.bs"
import "PotShard.bs"

' A clay pot the sword breaks in one hit, maybe leaving a potion or a coin. Pots come back every
' time the room loads.
class Pot extends BGE.GameEntity

  private solidWorld as BGE.SolidWorld = invalid
  private solidId as string = ""
  private isBroken as boolean = false

  sub new(game as BGE.Game)
    super(game)
    m.name = "Pot"
    m.tagsList.add("breakable")
  end sub

  ' @param {roAssociativeArray} args - {x, y (bottom-centre), solidWorld}
  override sub onCreate(args as roAssociativeArray)
    entry = getAtlas()["vase"] as AtlasEntry
    m.position.x = args.x
    m.position.y = args.y
    m.position.z = -args.y
    m.solidWorld = args.solidWorld
    left = args.x - entry.w / 2
    m.addImage("art", atlasRegion(m.game, entry), {
      offset: BGE.Math.VectorOps.create(-entry.w / 2, entry.h),
      drawMode: BGE.SceneObjectDrawMode.matchCamera
    })
    fp = entry.footprint
    m.solidId = m.solidWorld.addSolid(left + fp.x, args.y + fp.y, fp.w, fp.h)
    m.addRectangleCollider("body", entry.w - 4, 24, -(entry.w - 4) / 2, 24)
  end sub

  ' Called when the sword hits it.
  sub smash()
    if m.isBroken
      return
    end if
    m.isBroken = true
    m.solidWorld.removeSolid(m.solidId)
    m.game.playSound("enemyHit")
    for each push in [[-60, 40], [60, 40], [-40, -30], [40, -30]]
      shard = new PotShard(m.game)
      m.game.addEntity(shard, {x: m.position.x, y: m.position.y + 8, vx: push[0], vy: push[1]})
    end for
    spawnLoot(m.game, pickLoot([{drop: "potion", chance: 0.25}, {drop: "coin", chance: 0.25}], Rnd(0)), m.position.x, m.position.y)
    m.invalidate()
  end sub

end class
```

- [ ] **Step 3: The sword breaks pots.** In `Entities/Player.bs` add `import "../World/Pot.bs"`, and at the top of `onCollision`, replace the first `if` with:

```brighterscript
    if m.defeated
      return
    end if
    if myCollider.name = "sword" and otherCollider.name = "body" and otherEntity.tagsList.contains("breakable")
      (otherEntity as Pot).smash()
      return
    end if
    if otherCollider.name <> "body" or not otherEntity.tagsList.contains("enemy")
      return
    end if
```

- [ ] **Step 4: Pots from placements, and room clears.** In `AreaScene.bs` (import `"../World/Pot.bs"` and `"../Entities/Enemy.bs"`):

Add a `buildPlacement` branch:

```brighterscript
    else if item.type = "pot"
      feet = enemySpawnPoint(item, numRows)
      newPot = new Pot(m.game)
      m.game.addEntity(newPot, {x: feet.x, y: feet.y, solidWorld: m.solidWorld})
      return newPot
```

Add a field `private enemiesPlaced as integer = 0`; reset it to 0 at the start of `onCreate`; in the `"enemy"` branch increment it when an enemy is built (`m.enemiesPlaced++` before `return m.addEnemy(...)`).

Extend `onGameEvent`:

```brighterscript
    else if eventName = "enemyKilled" and m.enemiesPlaced > 0
      ' The dying enemy is still an entity this frame, so count only the ones not dying.
      for each entity in m.game.getEntitiesByTag("enemy")
        if not (entity as Enemy).isDying
          return
        end if
      end for
      m.enemiesPlaced = 0
      m.game.postGameEvent("roomCleared", {room: m.name})
    end if
```

- [ ] **Step 5: Build and test.** `cd examples/rpg && npx bsc --create-package=false && npm test` → no errors, PASS.

- [ ] **Step 6: Commit.**

```bash
git add examples/rpg
git commit -m "rpg: breakable pots and roomCleared (#289)"
```

---

### Task 10: `Goblin`

**Files:**
- Create: `Entities/Goblin.bs`
- Modify: `Entities/Enemy.bs` (`baseColor`, `knockbackScale`, `onDying()` hook, `hurt` made overridable), `Scenes/AreaScene.bs` (`addEnemy` kinds)

**Interfaces:**
- Consumes: `Enemy`, `LootEntry` (Task 6), bitmap `"goblin"` (Task 2).
- Produces: on `Enemy`: `protected baseColor as integer = &hFFFFFF`, `protected knockbackScale as float = 1.0`, `protected sub onDying()`. `class Goblin extends Enemy` with `sub freezePose(pose as string)` (`"walk"`, `"tell"`, `"lunge"`, `"dying"`); protected `facing`, `state`, `stateTimer`, `frozen`, `playFacing(prefix)`.

- [ ] **Step 1: Enemy hooks.** In `Entities/Enemy.bs`:
  - Add fields `protected baseColor as integer = &hFFFFFF` and `protected knockbackScale as float = 1.0`.
  - In `onUpdate`, change `m.sprite.color = &hFFFFFF` to `m.sprite.color = m.baseColor`.
  - In `startKnockback`, multiply: `push = knockbackVector(fromX, fromY, m.position.x, m.position.y, distance * m.knockbackScale)`.
  - Add `protected sub onDying()` (empty, doc: "Called once as the enemy starts dying, e.g. to play a death animation."), and call `m.onDying()` at the end of `die()`.

- [ ] **Step 2: Goblin.** Create `Entities/Goblin.bs`:

```brighterscript
import "Enemy.bs"
import "Facing.bs"
import "Shadow.bs"
import "Loot.bs"

const GOBLIN_SPEED = 60.0
const GOBLIN_CHASE_RANGE = 160.0
const GOBLIN_ATTACK_RANGE = 48.0
const GOBLIN_TELL_SECONDS = 0.4
const GOBLIN_LUNGE_SECONDS = 0.25
const GOBLIN_LUNGE_SPEED = 180.0
const GOBLIN_BOX_W = 18.0
const GOBLIN_BOX_H = 10.0
const GOBLIN_FRAMES_PER_ROW = 11

' A goblin with a short sword: chases the player, plants its feet (the tell), then lunges. A hit
' during the tell cancels the lunge. Takes three hits.
'
' goblin.png: 64x64 cells, 11 per row. Rows 0-3 face down/right/up/left: frames 0-7 walk, 8-10
' swing. Row 4 is the death animation (frames 44-48).
class Goblin extends Enemy

  protected facing as FacingDirection = FacingDirection.down
  ' "walk", "tell" or "lunge" (GoblinKing adds its own)
  protected state as string = "walk"
  protected stateTimer as BGE.CountdownTimer = new BGE.CountdownTimer()
  ' Set by freezePose(): stands still in one pose (the showcase room).
  protected frozen as boolean = false
  protected lungeX as float = 0.0
  protected lungeY as float = 0.0

  sub new(game as BGE.Game)
    super(game)
    m.name = "Goblin"
  end sub

  override sub onCreate(args as roAssociativeArray)
    super.onCreate(args)
    m.health = 3
    m.boxW = GOBLIN_BOX_W
    m.boxH = GOBLIN_BOX_H
    m.headHeight = 44
    addGroundShadow(m, 9)
    m.sprite = m.addSprite("body", m.game.getBitmap("goblin"), 64, 64)
    ' Pins the goblin's feet (32, 60 within each cell) onto the entity's position.
    m.sprite.applyPreTranslation(-32, -60)
    rowFacings = [FacingDirection.down, FacingDirection.right, FacingDirection.up, FacingDirection.left]
    for i = 0 to 3
      first = i * GOBLIN_FRAMES_PER_ROW
      m.sprite.addAnimation("walk_" + rowFacings[i], [first, first + 1, first + 2, first + 3, first + 4, first + 5, first + 6, first + 7], 12, BGE.SpritePlayMode.Loop)
      m.sprite.addAnimation("idle_" + rowFacings[i], [first], 1, BGE.SpritePlayMode.Loop)
      m.sprite.addAnimation("swing_" + rowFacings[i], [first + 8, first + 9, first + 10], 12, BGE.SpritePlayMode.Forward)
    end for
    death = 4 * GOBLIN_FRAMES_PER_ROW
    m.sprite.addAnimation("death", [death, death + 1, death + 2, death + 3, death + 4], 10, BGE.SpritePlayMode.Forward)
    m.sprite.playAnimation("idle_down")
    m.addRectangleCollider("body", 20, 32, -10, 32)
  end sub

  ' Holds one pose for a screenshot: "walk", "tell", "lunge" or "dying".
  sub freezePose(pose as string)
    m.frozen = true
    if pose = "walk"
      m.playFacing("walk_")
    else if pose = "tell" or pose = "lunge"
      m.playFacing("swing_")
    else if pose = "dying"
      m.sprite.playAnimation("death")
    end if
  end sub

  override function hurt(fromX as float, fromY as float, amount = 1 as integer) as boolean
    ' A hit during the tell spoils the lunge.
    if m.state = "tell"
      m.state = "walk"
    end if
    return super.hurt(fromX, fromY, amount)
  end function

  protected override function lootTable() as LootEntry[]
    return [{drop: "coin", chance: 0.3}, {drop: "potion", chance: 0.1}]
  end function

  protected override sub onDying()
    m.sprite.playAnimation("death")
  end sub

  protected override sub moveEnemy(dt as float)
    if m.frozen
      return
    end if
    m.stateTimer.tick(dt)
    target = m.getPlayer()
    if m.state = "tell"
      if not m.stateTimer.isActive()
        m.state = "lunge"
        m.stateTimer.start(GOBLIN_LUNGE_SECONDS)
      end if
      return
    else if m.state = "lunge"
      m.applyMove(m.lungeX * GOBLIN_LUNGE_SPEED * dt, m.lungeY * GOBLIN_LUNGE_SPEED * dt, {cornerNudge: 0})
      if not m.stateTimer.isActive()
        m.state = "walk"
      end if
      return
    end if

    if target = invalid
      m.playFacing("idle_")
      return
    end if
    dx = target.position.x - m.position.x
    dy = target.position.y - m.position.y
    distance = Sqr(dx * dx + dy * dy)
    if distance > GOBLIN_CHASE_RANGE or distance < 1
      m.playFacing("idle_")
      return
    end if
    dirX = dx / distance
    dirY = dy / distance
    if m.isRetreating()
      m.walk(-dirX * GOBLIN_SPEED * dt, -dirY * GOBLIN_SPEED * dt)
    else if distance < GOBLIN_ATTACK_RANGE
      m.lungeX = dirX
      m.lungeY = dirY
      m.facing = facingFor(dx, dy, m.facing)
      m.state = "tell"
      m.stateTimer.start(GOBLIN_TELL_SECONDS)
      m.playFacing("swing_")
    else
      m.walk(dirX * GOBLIN_SPEED * dt, dirY * GOBLIN_SPEED * dt)
    end if
  end sub

  protected sub walk(dx as float, dy as float)
    m.applyMove(dx, dy, {})
    m.facing = facingFor(dx, dy, m.facing)
    m.playFacing("walk_")
  end sub

  protected sub playFacing(prefix as string)
    m.sprite.playAnimation(prefix + m.facing)
  end sub

end class
```

If `Enemy.hurt` can't be overridden as written (it's a plain `function`, which BrighterScript allows overriding), keep the signature identical to `Enemy.hurt`.

- [ ] **Step 3: AreaScene spawns goblins.** In `AreaScene.addEnemy` (import `"../Entities/Goblin.bs"`), add a branch before the rat fallback:

```brighterscript
    else if item.kind = "goblin"
      newGoblin = new Goblin(m.game)
      m.game.addEntity(newGoblin, args)
      return newGoblin
```

- [ ] **Step 4: Build and test.** `cd examples/rpg && npx bsc --create-package=false && npm test` → no errors, PASS.

- [ ] **Step 5: Commit.**

```bash
git add examples/rpg
git commit -m "rpg: Goblin enemy with a telegraphed lunge (#289)"
```

---

### Task 11: `GoblinKing` and the boss bar

**Files:**
- Create: `Entities/GoblinKing.bs`, `UI/BossBar.bs`
- Modify: `Scenes/AreaScene.bs` (`addEnemy`: `"goblinKing"`), `main.bs` (add the bar to `gameUi`)

**Interfaces:**
- Consumes: `Goblin` (Task 10).
- Produces: `class GoblinKing extends Goblin` (name `"GoblinKing"`, so its kill event is `enemyKilled {kind: "goblinking"}`), constants `KING_HEALTH = 12`; `freezePose` also accepts `"stunned"` and `"tell"` (flashing). `class BossBar extends BGE.UI.UiWidget`.

- [ ] **Step 1: GoblinKing.** Create `Entities/GoblinKing.bs`:

```brighterscript
import "Goblin.bs"

const KING_HEALTH = 12
const KING_SCALE = 1.5
' Gold tint (packed RGB).
const KING_TINT = &hFFD070
const KING_SPEED = 40.0
const KING_CHARGE_EVERY = 3.0
const KING_TELL_SECONDS = 0.6
const KING_QUICK_TELL_SECONDS = 0.3
const KING_CHARGE_SPEED = 220.0
const KING_PHASE2_SPEED_SCALE = 1.3
const KING_STUN_SECONDS = 1.2
' Flash tint during the tell (packed RGB).
const KING_TELL_RGB = &hFF8040

' The goblin king: chases slowly, then plants and flashes (the tell) and charges in a straight
' line until he hits a wall, which stuns him - the safe time to hit him. Below half health he
' charges faster, twice in a row.
class GoblinKing extends Goblin

  private chargeTimer as BGE.CountdownTimer = new BGE.CountdownTimer()
  private chargesLeft as integer = 0

  sub new(game as BGE.Game)
    super(game)
    m.name = "GoblinKing"
  end sub

  override sub onCreate(args as roAssociativeArray)
    super.onCreate(args)
    m.health = KING_HEALTH
    m.boxW = 28
    m.boxH = 14
    m.headHeight = 66
    m.knockbackScale = 0.25
    m.baseColor = KING_TINT
    m.sprite.color = KING_TINT
    m.sprite.scale = BGE.Math.VectorOps.create(KING_SCALE, KING_SCALE, 1)
    m.colliders["body"].width = 30
    m.colliders["body"].height = 48
    m.colliders["body"].offset.x = -15
    m.colliders["body"].offset.y = 48
    m.chargeTimer.start(KING_CHARGE_EVERY)
  end sub

  override sub freezePose(pose as string)
    if pose = "stunned"
      m.frozen = true
      m.playFacing("idle_")
      m.sprite.color = &h9090FF
    else if pose = "tell"
      m.frozen = true
      m.playFacing("swing_")
      m.sprite.color = KING_TELL_RGB
    else
      super.freezePose(pose)
    end if
  end sub

  ' A boss doesn't back off after hurting the player.
  override sub recoil(fromX as float, fromY as float)
  end sub

  protected override function lootTable() as LootEntry[]
    return []
  end function

  function isPhaseTwo() as boolean
    return m.health <= KING_HEALTH / 2
  end function

  protected override sub moveEnemy(dt as float)
    if m.frozen
      return
    end if
    m.stateTimer.tick(dt)
    target = m.getPlayer()
    if m.state = "stunned"
      if not m.stateTimer.isActive()
        m.state = "walk"
        m.chargeTimer.start(KING_CHARGE_EVERY)
      end if
      return
    else if m.state = "tell"
      if not m.stateTimer.isActive()
        m.sprite.color = m.baseColor
        m.state = "lunge"
      end if
      return
    else if m.state = "lunge"
      m.charge(dt)
      return
    end if

    if target = invalid
      return
    end if
    dx = target.position.x - m.position.x
    dy = target.position.y - m.position.y
    distance = Sqr(dx * dx + dy * dy)
    m.chargeTimer.tick(dt)
    if not m.chargeTimer.isActive() and distance > 1
      m.chargesLeft = 1
      if m.isPhaseTwo()
        m.chargesLeft = 2
      end if
      m.startTell(dx / distance, dy / distance, KING_TELL_SECONDS)
    else if distance > 1
      m.walk(dx / distance * KING_SPEED * dt, dy / distance * KING_SPEED * dt)
    end if
  end sub

  private sub startTell(dirX as float, dirY as float, seconds as float)
    m.lungeX = dirX
    m.lungeY = dirY
    m.facing = facingFor(dirX, dirY, m.facing)
    m.state = "tell"
    m.stateTimer.start(seconds)
    m.sprite.color = KING_TELL_RGB
    m.playFacing("swing_")
  end sub

  ' Runs straight on until something stops him.
  private sub charge(dt as float)
    speed = KING_CHARGE_SPEED
    if m.isPhaseTwo()
      speed = speed * KING_PHASE2_SPEED_SCALE
    end if
    beforeX = m.position.x
    beforeY = m.position.y
    stepX = m.lungeX * speed * dt
    stepY = m.lungeY * speed * dt
    m.applyMove(stepX, stepY, {cornerNudge: 0})
    moved = Abs(m.position.x - beforeX) + Abs(m.position.y - beforeY)
    if moved >= (Abs(stepX) + Abs(stepY)) * 0.5
      return
    end if
    ' Hit a wall.
    m.chargesLeft--
    target = m.getPlayer()
    if m.chargesLeft > 0 and target <> invalid
      dx = target.position.x - m.position.x
      dy = target.position.y - m.position.y
      distance = Sqr(dx * dx + dy * dy)
      if distance > 1
        m.startTell(dx / distance, dy / distance, KING_QUICK_TELL_SECONDS)
        return
      end if
    end if
    m.game.playSound("enemyHit")
    m.state = "stunned"
    m.stateTimer.start(KING_STUN_SECONDS)
    m.playFacing("idle_")
  end sub

end class
```

Notes for the implementer: `Goblin.walk`/`playFacing`/`facing`/`state`/`stateTimer`/`frozen`/`lungeX`/`lungeY` are `protected` (Task 10). `Enemy.recoil` is a public `sub`, so overriding it is fine. If `colliders["body"]` can't be resized by assigning `width`/`height` (check `RectangleCollider`), remove and re-add it: `m.removeCollider("body")` then `m.addRectangleCollider("body", 30, 48, -15, 48)`.

- [ ] **Step 2: Spawn him.** In `AreaScene.addEnemy` (import `"../Entities/GoblinKing.bs"`), before the `"goblin"` branch:

```brighterscript
    else if item.kind = "goblinKing"
      newKing = new GoblinKing(m.game)
      m.game.addEntity(newKing, args)
      return newKing
```

- [ ] **Step 3: Boss bar.** Create `UI/BossBar.bs`:

```brighterscript
import "pkg:/source/engine/ui/UiWidget.bs"
import "../Entities/GoblinKing.bs"

const BOSS_BAR_BACK_RGBA = &h202020C0
const BOSS_BAR_FILL_RGBA = &hD03020FF
const BOSS_BAR_TEXT_RGBA = &hF5E6C8FF

' The goblin king's health across the top of the screen while he's alive. Title-safe: centred,
' 40% of the width, 10% down from the top.
class BossBar extends BGE.UI.UiWidget

  sub new(game as BGE.Game)
    super(game)
  end sub

  override sub draw(parent = invalid as BGE.UI.UiWidget)
    if m.game.getAllEntities("GoblinKing").count() = 0
      return
    end if
    king = m.game.getEntityByName("GoblinKing") as GoblinKing
    if king.isDying
      return
    end if
    renderer = m.canvas.renderer
    canvasW = m.canvas.getWidth()
    canvasH = m.canvas.getHeight()
    font = m.game.getFont("hud")
    barW = Int(canvasW * 0.4)
    barH = Int(canvasH * 0.02)
    left = Int((canvasW - barW) / 2)
    top = Int(canvasH * 0.1) + font.GetOneLineHeight()
    renderer.drawText("Goblin King", canvasW / 2, top - 4, BOSS_BAR_TEXT_RGBA, font, "center", "bottom")
    renderer.drawRectangle(left, top, barW, barH, BOSS_BAR_BACK_RGBA)
    fillW = Int(barW * king.health / KING_HEALTH)
    if fillW > 0
      renderer.drawRectangle(left, top, fillW, barH, BOSS_BAR_FILL_RGBA)
    end if
  end sub

end class
```

Check `Renderer.drawText`'s alignment args against `HeartsHud` (`"left", "center"`); use the same parameter order.

- [ ] **Step 4: Add it to the UI.** In `main.bs` (import `"UI/BossBar.bs"`), after `game.gameUi.addChild(hud)`:

```brighterscript
  bossBar = new BossBar(game)
  game.gameUi.addChild(bossBar)
```

- [ ] **Step 5: Build.** `cd examples/rpg && npx bsc --create-package=false` → no errors.

- [ ] **Step 6: Commit.**

```bash
git add examples/rpg
git commit -m "rpg: GoblinKing mini-boss and boss health bar (#289)"
```

---

### Task 12: Keys in the HUD and the inventory

**Files:**
- Modify: `UI/HeartsHud.bs` (`draw`), `UI/InventoryPanel.bs:70-90`

**Interfaces:**
- Consumes: bitmaps `"smallKey"`, `"throneKey"` (Task 2); `Story.inventory`.

- [ ] **Step 1: HUD.** In `HeartsHud.bs` import `"../Story/Story.bs"` and `"pkg:/source/engine/math/..."` only if needed (no). At the end of `draw`, after the coin line:

```brighterscript
    storyEntity = m.game.getEntityByName("Story") as Story
    keyCount = storyEntity.inventory.count("smallKey")
    if keyCount > 0
      keyTop = coinTop + iconSize + gap * 2
      keyScale = iconSize / 32.0
      renderer.drawScaledObject(left, keyTop, keyScale, keyScale, m.game.getBitmap("smallKey"))
      renderer.drawText(keyCount.toStr(), left + iconSize + gap * 2, keyTop + iconSize / 2, HUD_TEXT_RGBA, m.game.getFont("hud"), "left", "center")
    end if
```

Update the class doc comment: "hearts, coin count and small keys".

- [ ] **Step 2: Inventory.** In `InventoryPanel.draw`, after the potion icon push:

```brighterscript
    if storyEntity.inventory.has("smallKey")
      icons.push({key: "smallKey", count: storyEntity.inventory.count("smallKey")})
    end if
    if storyEntity.inventory.has("throneKey")
      icons.push({key: "throneKey", count: -1})
    end if
```

and update the comment above `draw` to list the keys.

- [ ] **Step 3: Build.** `cd examples/rpg && npx bsc --create-package=false` → no errors.

- [ ] **Step 4: Commit.**

```bash
git add examples/rpg
git commit -m "rpg: small keys in the HUD, keys in the inventory (#289)"
```

---

### Task 13: The six rooms

**Files:**
- Create: `Maps/DungeonData.bs` (pure), `Scenes/DungeonScenes.bs`
- Modify: `Maps/MapData.bs` (replace `getCastleRows`/`getCastlePlacements`), `main.bs` (define scenes), `examples/rpg/bsconfig.test.json` (add `"source/Maps/DungeonData.bs"`)
- Test: `examples/rpg/tests/Dungeon.spec.bs`; `examples/rpg/tests/EnemyPlacements.spec.bs` keeps passing

**Interfaces:**
- Consumes: placement types from Tasks 4-11.
- Produces: `function buildRoomRows(exits as string) as string[]` (exits: any of `"n" "e" "s" "w"`); `getGuardroomRows/Placements`, `getStoreroomRows/Placements`, `getBarracksRows/Placements`, `getAntechamberRows/Placements`, `getKingsHallRows/Placements`; `function getAreaMaps() as roAssociativeArray` (scene name → `{rows, placements}`, covering Town, Sewer, Castle and the five new rooms). Scenes: `GuardroomScene`, `StoreroomScene`, `BarracksScene`, `AntechamberScene`, `KingsHallScene`.

**Room geometry** (20 cols × 11 rows; rows 0-2 brick wall, 3-9 floor, 10 void; cols 0 and 19 void):

| Exit | Opening | Door trigger | Gate | Arriving spawn id / cell |
|---|---|---|---|---|
| n | cols 9-10, rows 0-2 | col 9, row 0, w 2, h 1 | col 9, row 2, w 2, h 1 | `fromN`: col 10, row 4, facing down |
| s | cols 9-10, row 10 | col 9, row 10, w 2, h 1 | col 9, row 10, w 2, h 1 | `fromS`: col 10, row 8, facing up |
| w | col 0, rows 6-7 | col 0, row 7, w 1, h 2 | col 0, row 7, w 1, h 2 | `fromW`: col 2.5, row 7, facing right |
| e | col 19, rows 6-7 | col 19, row 7, w 1, h 2 | col 19, row 7, w 1, h 2 | `fromE`: col 17.5, row 7, facing left |

A spawn's `col` is its feet x / 32, so col 10 is the middle of the 9-10 opening. A door's `spawn` names the spawn in the *target* room for the side you arrive on: going through your north door you arrive at the target's `fromS`.

- [ ] **Step 1: Write the failing tests.** Create `examples/rpg/tests/Dungeon.spec.bs`:

```brighterscript
namespace tests
  @suite("keep dungeon")
  class DungeonTests extends rooibos.BaseTestSuite

    private function context(allFlags as boolean) as object
      flags = new StoryFlags()
      carried = new Inventory(getItemDefinitions())
      if allFlags
        for each key in ["gate.open", "dng.guard.cleared", "dng.guard.keyTaken", "dng.L1.open", "dng.portcullis", "dng.ante.a", "dng.ante.b", "dng.ante.solved", "dng.ante.keyTaken", "dng.L2.open", "dng.kingDefeated", "dng.heartTaken"]
          flags.set(key, true)
        end for
        carried.add("throneKey")
      end if
      return newStoryContext(flags, carried, {health: 6, maxHealth: 6, coins: 0})
    end function

    ' Solid ground, placement solids, prop footprints, bounds, and every gate that's present.
    private function buildWorld(rows as string[], placements as object, ctx as object) as BGE.SolidWorld
      numRows = rows.count()
      world = new BGE.SolidWorld()
      for r = 0 to numRows - 1
        for c = 0 to rows[r].len() - 1
          if isSolidGroundChar(rows[r].mid(c, 1))
            world.addSolid(c * TILE_SIZE, cellBottomY(numRows, r), TILE_SIZE, TILE_SIZE)
          end if
        end for
      end for
      present = filterPlacements(placements, ctx)
      addPlacementSolids(world, present, numRows)
      for each item in present
        if item.atlasKey <> invalid
          fp = getAtlas()[item.atlasKey].footprint
          if fp <> invalid
            world.addSolid(item.col * TILE_SIZE + fp.x, cellBottomY(numRows, item.row) + fp.y, fp.w, fp.h)
          end if
        else if item.type = "gate"
          world.addSolid(item.col * TILE_SIZE, cellBottomY(numRows, item.row), item.w * TILE_SIZE, item.h * TILE_SIZE)
        end if
      end for
      world.addBounds(0, 0, rows[0].len() * TILE_SIZE, numRows * TILE_SIZE)
      return world
    end function

    @describe("room rows")

    @it("builds a 20x11 room with only the asked-for openings")
    function _()
      rows = buildRoomRows("ne")
      m.assertEqual(11, rows.count())
      for each row in rows
        m.assertEqual(20, row.len())
      end for
      m.assertEqual("s", rows[0].mid(9, 1))
      m.assertEqual("s", rows[2].mid(10, 1))
      m.assertEqual("s", rows[6].mid(19, 1))
      m.assertEqual("x", rows[6].mid(0, 1))
      m.assertEqual("x", rows[10].mid(9, 1))
      m.assertEqual("b", rows[1].mid(4, 1))
      m.assertEqual("s", rows[5].mid(4, 1))
    end function

    @describe("doors")

    @it("leads every dungeon door to a spawn that exists in its target room")
    function _()
      maps = getAreaMaps()
      for each name in ["CastleScene", "GuardroomScene", "StoreroomScene", "BarracksScene", "AntechamberScene", "KingsHallScene"]
        for each item in maps[name].placements
          if item.type = "door"
            m.assertTrue(maps.DoesExist(item.target), name + " door leads to unknown " + item.target)
            found = false
            for each other in maps[item.target].placements
              if other.type = "spawn" and other.id = item.spawn
                found = true
              end if
            end for
            m.assertTrue(found, name + " door to " + item.target + " names missing spawn " + item.spawn)
          end if
        end for
      end for
    end function

    @describe("open ground")

    @it("leaves every spawn, enemy, pot, pickup and switch on open ground, before and after")
    function _()
      maps = getAreaMaps()
      for each allFlags in [false, true]
        ctx = m.context(allFlags)
        for each name in ["CastleScene", "GuardroomScene", "StoreroomScene", "BarracksScene", "AntechamberScene", "KingsHallScene"]
          area = maps[name]
          numRows = area.rows.count()
          world = m.buildWorld(area.rows, area.placements, ctx)
          for each item in filterPlacements(area.placements, ctx)
            label = name + " " + FormatJson(item) + " (all flags: " + allFlags.toStr() + ")"
            if item.type = "spawn"
              m.assertTrue(world.isAreaFree(item.col * TILE_SIZE - 10, cellBottomY(numRows, item.row) + 10, 20, 12), label + " is blocked")
            else if item.type = "enemy" or item.type = "pot" or item.type = "pickup"
              feet = enemySpawnPoint(item, numRows)
              m.assertTrue(world.isAreaFree(feet.x - ENEMY_SPAWN_CLEARANCE / 2, feet.y, ENEMY_SPAWN_CLEARANCE, ENEMY_SPAWN_CLEARANCE), label + " starts inside a solid")
            else if item.type = "switch"
              m.assertTrue(world.isAreaFree(item.col * TILE_SIZE + 4, cellBottomY(numRows, item.row) + 4, 24, 24), label + " is under a solid")
            end if
          end for
        end for
      end for
    end function

    @it("opens every gate except the great door once everything is done")
    function _()
      maps = getAreaMaps()
      ctx = m.context(true)
      for each name in ["CastleScene", "GuardroomScene", "AntechamberScene", "KingsHallScene"]
        for each item in filterPlacements(maps[name].placements, ctx)
          if item.type = "gate"
            m.assertEqual("great", item.style, name + " still has a " + item.style + " gate")
          end if
        end for
      end for
    end function

  end class
end namespace
```

- [ ] **Step 2: Run to verify it fails.** Add `"source/Maps/DungeonData.bs"` to `bsconfig.test.json` after `LivePlacements.bs`; `cd examples/rpg && npm test` → FAIL.

- [ ] **Step 3: Implement `Maps/DungeonData.bs`.**

```brighterscript
' The keep: six one-screen rooms (see specs/2026-10-04-rpg-slice-d1-dungeon-design.md).
import "MapData.bs"
import "MapTypes.bs"
import "../Entities/Facing.bs"

const ROOM_COLS = 20
const ROOM_ROWS = 11

' A room's ground: brick wall rows 0-2, floor rows 3-9, void row 10 and side columns, with a
' two-cell opening on each side named in exits.
'
' @param {string} exits - any of "n", "e", "s", "w"
' @return {string[]}
function buildRoomRows(exits as string) as string[]
  rows = [] as string[]
  for r = 0 to ROOM_ROWS - 1
    row = ""
    for c = 0 to ROOM_COLS - 1
      ch = "s"
      if r = ROOM_ROWS - 1 or c = 0 or c = ROOM_COLS - 1
        ch = "x"
      else if r <= 2
        ch = "b"
      end if
      if (c = 9 or c = 10) and r <= 2 and Instr(1, exits, "n") > 0
        ch = "s"
      else if (c = 9 or c = 10) and r = ROOM_ROWS - 1 and Instr(1, exits, "s") > 0
        ch = "s"
      else if (r = 6 or r = 7) and c = 0 and Instr(1, exits, "w") > 0
        ch = "s"
      else if (r = 6 or r = 7) and c = ROOM_COLS - 1 and Instr(1, exits, "e") > 0
        ch = "s"
      end if
      row += ch
    end for
    rows.push(row)
  end for
  return rows
end function

' A door through one side's opening, arriving at the target's spawn for the opposite side.
sub pushRoomDoor(p as MapPlacement[], side as string, target as string)
  arrive = {n: "fromS", s: "fromN", e: "fromW", w: "fromE"}
  door = roomOpening(side)
  ' A north door sits at the top of the opening, beyond its gate (row 2).
  if side = "n"
    door.row = 0
  end if
  p.push({type: "door", col: door.col, row: door.row, w: door.w, h: door.h, target: target, spawn: arrive[side]})
end sub

' The spawn a player arrives at through one side's opening.
sub pushRoomSpawn(p as MapPlacement[], side as string)
  if side = "n"
    p.push({type: "spawn", id: "fromN", col: 10, row: 4, facing: FacingDirection.down})
  else if side = "s"
    p.push({type: "spawn", id: "fromS", col: 10, row: 8, facing: FacingDirection.up})
  else if side = "w"
    p.push({type: "spawn", id: "fromW", col: 2.5, row: 7, facing: FacingDirection.right})
  else
    p.push({type: "spawn", id: "fromE", col: 17.5, row: 7, facing: FacingDirection.left})
  end if
end sub

' A gate across one side's opening. Pass live: true with a when for anything that opens.
sub pushRoomGate(p as MapPlacement[], side as string, style as string, when as StoryCondition[], unlock = invalid as GateUnlock)
  g = roomOpening(side)
  gate = {type: "gate", style: style, side: side, live: true, when: when, col: g.col, row: g.row, w: g.w, h: g.h} as MapPlacement
  if unlock <> invalid
    gate.unlock = unlock
  end if
  p.push(gate)
end sub

' The raised-portcullis arch over a north opening (decoration; a Gate draws its bars on top).
sub pushNorthArch(p as MapPlacement[])
  p.push({atlasKey: "archOpen", col: 9 - (84 - 64) / 2 / TILE_SIZE, row: 2})
end sub

' The cells an opening on one side covers: {col, row (bottom), w, h}.
function roomOpening(side as string) as roAssociativeArray
  if side = "n"
    return {col: 9, row: 2, w: 2, h: 1}
  else if side = "s"
    return {col: 9, row: 10, w: 2, h: 1}
  else if side = "w"
    return {col: 0, row: 7, w: 1, h: 2}
  end if
  return {col: 19, row: 7, w: 1, h: 2}
end function

function smallKeyDoor(openFlag as string) as GateUnlock
  return {when: [{hasItem: "smallKey"}], effects: [{takeItem: "smallKey"}, {set: openFlag, value: true}], lockedMessage: "Locked. A small key would fit."}
end function
```

With `n`, the gate's solid (row 2) sits between the floor and the door trigger (row 0), so a shut north gate keeps the player away from the door.

Now the rooms. `getCastleRows`/`getCastlePlacements` move out of `MapData.bs` (delete them there) into `DungeonData.bs`:

```brighterscript
' The entry hall (CastleScene): the wounded servant, bats, a barred way north and a locked door
' east.
function getCastleRows() as string[]
  return buildRoomRows("nsew")
end function

function getCastlePlacements() as MapPlacement[]
  p = [] as MapPlacement[]
  p.push({atlasKey: "bannerRed", col: 4, row: 2})
  p.push({atlasKey: "bannerBlue", col: 14, row: 2})
  p.push({atlasKey: "statue", col: 6, row: 4})
  p.push({atlasKey: "statue", col: 13, row: 4})
  pushNorthArch(p)
  pushRoomGate(p, "n", "bars", [{notFlag: "dng.portcullis"}])
  pushRoomGate(p, "e", "locked", [{notFlag: "dng.L1.open"}], smallKeyDoor("dng.L1.open"))
  pushRoomDoor(p, "n", "AntechamberScene")
  pushRoomDoor(p, "w", "GuardroomScene")
  pushRoomDoor(p, "e", "BarracksScene")
  p.push({type: "door", col: 9, row: 10, w: 2, h: 1, target: "TownScene", spawn: "gate"})
  ' The town's castle door arrives at "entrance".
  p.push({type: "spawn", id: "entrance", col: 10, row: 8, facing: FacingDirection.up})
  pushRoomSpawn(p, "n")
  pushRoomSpawn(p, "w")
  pushRoomSpawn(p, "e")
  p.push({type: "npc", npcId: "servant", character: "redGirl", col: 4, row: 8, facing: FacingDirection.right, wander: 0})
  p.push({type: "enemy", kind: "bat", col: 5, row: 5})
  p.push({type: "enemy", kind: "bat", col: 14, row: 6})
  return p
end function

' West of the hall: shutters until three goblins fall, then a small key.
function getGuardroomRows() as string[]
  return buildRoomRows("ne")
end function

function getGuardroomPlacements() as MapPlacement[]
  p = [] as MapPlacement[]
  p.push({atlasKey: "weaponRack", col: 2, row: 4})
  p.push({atlasKey: "oreBins", col: 14, row: 4})
  pushNorthArch(p)
  shut = [{notFlag: "dng.guard.cleared"}] as StoryCondition[]
  pushRoomGate(p, "n", "shutter", shut)
  pushRoomGate(p, "e", "shutter", shut)
  pushRoomDoor(p, "n", "StoreroomScene")
  pushRoomDoor(p, "e", "CastleScene")
  pushRoomSpawn(p, "n")
  pushRoomSpawn(p, "e")
  p.push({type: "enemy", kind: "goblin", col: 6, row: 5})
  p.push({type: "enemy", kind: "goblin", col: 9, row: 4})
  p.push({type: "enemy", kind: "goblin", col: 13, row: 7})
  p.push({type: "pickup", item: "smallKey", live: true, col: 9, row: 6, when: [{flag: "dng.guard.cleared"}, {notFlag: "dng.guard.keyTaken"}], effects: [{giveItem: "smallKey"}, {set: "dng.guard.keyTaken", value: true}]})
  return p
end function

' North of the guardroom: pots and the second heart container.
function getStoreroomRows() as string[]
  return buildRoomRows("s")
end function

function getStoreroomPlacements() as MapPlacement[]
  p = [] as MapPlacement[]
  p.push({atlasKey: "dresser", col: 2, row: 4})
  p.push({atlasKey: "drawers", col: 16, row: 4})
  p.push({atlasKey: "crateStack", col: 17, row: 9})
  p.push({atlasKey: "barrel", col: 2, row: 9})
  for each cell in [[5, 5], [6, 5], [13, 5], [14, 5], [5, 8], [14, 8]]
    p.push({type: "pot", col: cell[0], row: cell[1]})
  end for
  p.push({type: "pickup", icon: "heartIcon", live: true, col: 9, row: 5, when: [{notFlag: "dng.heartTaken"}], effects: [{addMaxHealth: 2}, {heal: 2}, {set: "dng.heartTaken", value: true}]})
  pushRoomDoor(p, "s", "GuardroomScene")
  pushRoomSpawn(p, "s")
  return p
end function

' East of the hall, behind the first locked door: the switch that raises the hall's portcullis.
function getBarracksRows() as string[]
  return buildRoomRows("w")
end function

function getBarracksPlacements() as MapPlacement[]
  p = [] as MapPlacement[]
  p.push({atlasKey: "bench", col: 3, row: 4})
  p.push({atlasKey: "weaponRack", col: 14, row: 4})
  p.push({atlasKey: "anvilBig", col: 3, row: 8})
  p.push({type: "pot", col: 16, row: 8})
  p.push({type: "pot", col: 17, row: 8})
  p.push({type: "switch", id: "barracks", flag: "dng.portcullis", col: 15, row: 6, effects: [{message: "Somewhere nearby, a gate grinds open."}]})
  p.push({type: "enemy", kind: "goblin", col: 8, row: 5})
  p.push({type: "enemy", kind: "goblin", col: 13, row: 7})
  pushRoomDoor(p, "w", "CastleScene")
  pushRoomSpawn(p, "w")
  return p
end function

' North of the hall: two floor switches drop the second key; the king's door is locked.
function getAntechamberRows() as string[]
  return buildRoomRows("ns")
end function

function getAntechamberPlacements() as MapPlacement[]
  p = [] as MapPlacement[]
  p.push({atlasKey: "bannerRed", col: 4, row: 2})
  p.push({atlasKey: "bannerBlue", col: 14, row: 2})
  p.push({type: "pot", col: 2, row: 4})
  p.push({type: "pot", col: 17, row: 4})
  p.push({type: "pot", col: 2, row: 9})
  p.push({type: "switch", id: "anteA", flag: "dng.ante.a", col: 4, row: 7})
  p.push({type: "switch", id: "anteB", flag: "dng.ante.b", col: 15, row: 7})
  p.push({type: "pickup", item: "smallKey", live: true, col: 9, row: 7, when: [{flag: "dng.ante.solved"}, {notFlag: "dng.ante.keyTaken"}], effects: [{giveItem: "smallKey"}, {set: "dng.ante.keyTaken", value: true}]})
  p.push({type: "enemy", kind: "goblin", col: 7, row: 5})
  p.push({type: "enemy", kind: "goblin", col: 12, row: 5})
  p.push({type: "enemy", kind: "bat", col: 10, row: 6})
  pushNorthArch(p)
  pushRoomGate(p, "n", "locked", [{notFlag: "dng.L2.open"}], smallKeyDoor("dng.L2.open"))
  pushRoomDoor(p, "n", "KingsHallScene")
  pushRoomDoor(p, "s", "CastleScene")
  pushRoomSpawn(p, "n")
  pushRoomSpawn(p, "s")
  return p
end function

' The goblin king's hall: shutters behind you, the king, and the sealed great door north.
function getKingsHallRows() as string[]
  return buildRoomRows("ns")
end function

function getKingsHallPlacements() as MapPlacement[]
  p = [] as MapPlacement[]
  p.push({atlasKey: "statue", col: 3, row: 4})
  p.push({atlasKey: "statue", col: 16, row: 4})
  pushNorthArch(p)
  ' The great door is always there in D1 (D2 opens it), so it isn't live.
  p.push({type: "gate", style: "great", side: "n", col: 9, row: 2, w: 2, h: 1, unlock: {
    when: [{hasItem: "throneKey"}],
    effects: [{set: "dng.throneDoor.tried", value: true}, {message: "The key turns, but dark magic holds the door shut."}],
    lockedMessage: "A great door, sealed by the witch's magic. The keyhole is shaped like a heart."
  }})
  pushRoomGate(p, "s", "shutter", [{notFlag: "dng.kingDefeated"}])
  pushRoomDoor(p, "s", "AntechamberScene")
  pushRoomSpawn(p, "s")
  p.push({type: "enemy", kind: "goblinKing", col: 9, row: 5, when: [{notFlag: "dng.kingDefeated"}]})
  p.push({type: "pickup", item: "throneKey", live: true, col: 9, row: 6, when: [{flag: "dng.kingDefeated"}, {notItem: "throneKey"}], effects: [{giveItem: "throneKey"}]})
  return p
end function

' Every area's map by scene name (tests use this to check doors lead somewhere real).
'
' @return {roAssociativeArray} scene name -> {rows, placements}
function getAreaMaps() as roAssociativeArray
  return {
    TownScene: {rows: getTownRows(), placements: getTownPlacements()},
    SewerScene: {rows: getSewerRows(), placements: getSewerPlacements()},
    CastleScene: {rows: getCastleRows(), placements: getCastlePlacements()},
    GuardroomScene: {rows: getGuardroomRows(), placements: getGuardroomPlacements()},
    StoreroomScene: {rows: getStoreroomRows(), placements: getStoreroomPlacements()},
    BarracksScene: {rows: getBarracksRows(), placements: getBarracksPlacements()},
    AntechamberScene: {rows: getAntechamberRows(), placements: getAntechamberPlacements()},
    KingsHallScene: {rows: getKingsHallRows(), placements: getKingsHallPlacements()}
  }
end function
```

The great door is not `live`, so `nonLivePlacements` keeps it and `buildPlacement` builds it once; it's never removed in D1. `Gate` gets `side: "n"`, so it draws the barred arch plus the heart key.

`addPlacementSolids` only handles `type: "solid"`; gates add their own solid in `Gate.onCreate`.

- [ ] **Step 4: Fix `MapData.bs` imports.** `MapData.bs` no longer defines the castle; anything importing it for `getCastleRows` (e.g. `Scenes/CastleScene.bs`, `tests`) must import `DungeonData.bs`. Update `Scenes/CastleScene.bs`'s import to `"../Maps/DungeonData.bs"`. `EnemyPlacements.spec.bs` still calls `getCastleRows()`/`getCastlePlacements()` — the rpg test build compiles every listed file into one scope, so it keeps working once `DungeonData.bs` is in `bsconfig.test.json`.

- [ ] **Step 5: Run tests.** `cd examples/rpg && npm test` → PASS (Dungeon + the existing EnemyPlacements). If a placement lands on a solid (a prop footprint over a spawn, say), move the prop by a column and rerun — the failure message names the placement.

- [ ] **Step 6: Scenes.** Create `Scenes/DungeonScenes.bs`:

```brighterscript
import "AreaScene.bs"
import "../Maps/DungeonData.bs"

class GuardroomScene extends AreaScene
  sub new(game as BGE.Game)
    super(game)
    m.name = "GuardroomScene"
  end sub
  override function getRows() as string[]
    return getGuardroomRows()
  end function
  override function getPlacements() as MapPlacement[]
    return getGuardroomPlacements()
  end function
end class

class StoreroomScene extends AreaScene
  sub new(game as BGE.Game)
    super(game)
    m.name = "StoreroomScene"
  end sub
  override function getRows() as string[]
    return getStoreroomRows()
  end function
  override function getPlacements() as MapPlacement[]
    return getStoreroomPlacements()
  end function
end class

class BarracksScene extends AreaScene
  sub new(game as BGE.Game)
    super(game)
    m.name = "BarracksScene"
  end sub
  override function getRows() as string[]
    return getBarracksRows()
  end function
  override function getPlacements() as MapPlacement[]
    return getBarracksPlacements()
  end function
end class

class AntechamberScene extends AreaScene
  sub new(game as BGE.Game)
    super(game)
    m.name = "AntechamberScene"
  end sub
  override function getRows() as string[]
    return getAntechamberRows()
  end function
  override function getPlacements() as MapPlacement[]
    return getAntechamberPlacements()
  end function
end class

class KingsHallScene extends AreaScene
  sub new(game as BGE.Game)
    super(game)
    m.name = "KingsHallScene"
  end sub
  override function getRows() as string[]
    return getKingsHallRows()
  end function
  override function getPlacements() as MapPlacement[]
    return getKingsHallPlacements()
  end function
end class
```

- [ ] **Step 7: Define them.** In `main.bs`, import `"Scenes/DungeonScenes.bs"` and after `game.defineScene(sewer)`:

```brighterscript
  guardroom = new GuardroomScene(game)
  game.defineScene(guardroom)
  storeroom = new StoreroomScene(game)
  game.defineScene(storeroom)
  barracks = new BarracksScene(game)
  game.defineScene(barracks)
  antechamber = new AntechamberScene(game)
  game.defineScene(antechamber)
  kingsHall = new KingsHallScene(game)
  game.defineScene(kingsHall)
```

- [ ] **Step 8: Build and test.** `cd examples/rpg && npx bsc --create-package=false && npm test` → no errors, PASS.

- [ ] **Step 9: Commit.**

```bash
git add examples/rpg
git commit -m "rpg: the keep - six one-screen dungeon rooms (#289)"
```

---

### Task 14: Story content — servant, quest, rules, checkpoints

**Files:**
- Modify: `Story/DialogueData.bs`, `Story/QuestData.bs`, `Story/EventRules.bs`, `Story/Checkpoints.bs`, `main.bs:80-95`
- Test: `examples/rpg/tests/EventRules.spec.bs`, `examples/rpg/tests/DialogueData.spec.bs` (checkpoint loop)

**Interfaces:**
- Produces: `function checkpointScene(n as integer) as string`; checkpoints 5 and 6; quest `keep`; npc id `servant`.

- [ ] **Step 1: Write the failing tests.** In `EventRules.spec.bs` add before `end class`:

```brighterscript
    @describe("the keep")

    @it("clears the guardroom on roomCleared")
    function _()
      runEventRules(getEventRules(), "roomCleared", {room: "GuardroomScene"}, m.ctx)
      m.assertTrue(m.ctx.flags.isSet("dng.guard.cleared"))
    end function

    @it("marks the king defeated when he dies")
    function _()
      runEventRules(getEventRules(), "enemyKilled", {kind: "goblinking"}, m.ctx)
      m.assertTrue(m.ctx.flags.isSet("dng.kingDefeated"))
    end function

    @it("solves the antechamber only once both switches are down")
    function _()
      m.ctx.flags.set("dng.ante.a", true)
      settleStory(getEventRules(), m.ctx)
      m.assertFalse(m.ctx.flags.isSet("dng.ante.solved"))
      m.ctx.flags.set("dng.ante.b", true)
      result = settleStory(getEventRules(), m.ctx)
      m.assertTrue(m.ctx.flags.isSet("dng.ante.solved"))
      m.assertEqual(1, result.messages.count())
    end function

    @it("moves the keep quest on as doors open and the key is found")
    function _()
      m.ctx.flags.set("keep.stage", 1)
      m.ctx.flags.set("dng.L2.open", true)
      settleStory(getEventRules(), m.ctx)
      m.assertEqual(2, m.ctx.flags.getInt("keep.stage"))
      m.ctx.inventory.add("throneKey")
      settleStory(getEventRules(), m.ctx)
      m.assertEqual(3, m.ctx.flags.getInt("keep.stage"))
    end function

    @it("retires the gate quest once the keep quest starts")
    function _()
      m.ctx.flags.set("gate.open", true)
      m.ctx.flags.set("keep.stage", 1)
      settleStory(getEventRules(), m.ctx)
      m.assertEqual(["Find a way through the keep"], currentObjectives(getQuestData(), m.ctx.flags))
    end function

    @it("settles to no further change at every checkpoint")
    @params(0)
    @params(1)
    @params(2)
    @params(3)
    @params(4)
    @params(5)
    @params(6)
    function _(checkpoint)
      state = checkpointState(checkpoint)
      ctx = newStoryContext(state.flags, state.inventory, {health: 6, maxHealth: 6, coins: state.coins})
      settleStory(getEventRules(), ctx)
      m.assertFalse(settleStory(getEventRules(), ctx).changed)
    end function

    @it("starts checkpoints 5 and 6 inside the keep")
    function _()
      m.assertEqual("TownScene", checkpointScene(4))
      m.assertEqual("CastleScene", checkpointScene(5))
      m.assertEqual("KingsHallScene", checkpointScene(6))
      m.assertEqual(["The throne room is sealed by dark magic"], currentObjectives(getQuestData(), checkpointState(6).flags))
    end function
```

In `DialogueData.spec.bs`, in `"has a page for every story checkpoint"`, add `@params(5)` and `@params(6)` after `@params(4)`, and add `"servant"` to its `npcId` list.

- [ ] **Step 2: Run to verify they fail.** `cd examples/rpg && npm test` → FAIL.

- [ ] **Step 3: Event rules.** In `EventRules.bs`, change the last existing rule to

```brighterscript
    {event: "storyChanged", when: [{flag: "gate.open"}, {flag: "gate.stage", lt: 2}], effects: [{set: "gate.stage", value: 2}]},
```

(so it no longer fights the new stage 3), and append:

```brighterscript
    {event: "storyChanged", when: [{flag: "keep.stage", gte: 1}, {flag: "gate.stage", lt: 3}], effects: [{set: "gate.stage", value: 3}]},
    {event: "roomCleared", match: {room: "GuardroomScene"}, effects: [{set: "dng.guard.cleared", value: true}]},
    {event: "enemyKilled", match: {kind: "goblinking"}, effects: [{set: "dng.kingDefeated", value: true}]},
    {event: "storyChanged", when: [{flag: "dng.ante.a"}, {flag: "dng.ante.b"}, {notFlag: "dng.ante.solved"}], effects: [{set: "dng.ante.solved", value: true}, {message: "Click. Something drops onto the floor."}]},
    {event: "storyChanged", when: [{flag: "dng.L2.open"}, {flag: "keep.stage", lt: 2}], effects: [{set: "keep.stage", value: 2}]},
    {event: "storyChanged", when: [{hasItem: "throneKey"}, {flag: "keep.stage", lt: 3}], effects: [{set: "keep.stage", value: 3}]}
```

- [ ] **Step 4: Quest.** In `QuestData.bs` add:

```brighterscript
    {id: "keep", title: "The witch's keep", stageFlag: "keep.stage", stages: {"1": "Find a way through the keep", "2": "Defeat the goblin king", "3": "The throne room is sealed by dark magic"}}
```

- [ ] **Step 5: Dialogue.** In `DialogueData.bs`, add to `bram` before the `{when: [{flag: "rats.stage", gte: 3}] ...}` page:

```brighterscript
      {when: [{flag: "gate.open"}, {flag: "keep.stage", lt: 1}], speaker: "Elder Bram", lines: ["The gate's open? Then go carefully. Look for old Mara inside - she served in the keep for years."]},
```

and a new `servant` entry:

```brighterscript
    servant: [
      {when: [{flag: "keep.stage", gte: 3}], speaker: "Mara", lines: ["The king's key! Then only her magic stands between you and the witch.", "Whatever you do in there - be careful."]},
      {when: [{flag: "keep.stage", eq: 2}], speaker: "Mara", lines: ["The goblin king holds court past the antechamber. Bring that brute down."]},
      {when: [{flag: "keep.stage", eq: 1}], speaker: "Mara", lines: ["They've locked every way through. Find their keys, and look for switches in the floor."]},
      {speaker: "Mara", lines: ["You came through the gate? Thank the light...", "Goblins took the keep. Their king carries the key to the throne room, where the witch has shut herself in.", "They've barred and locked every way through. Look for keys, and for switches in the floor."], effects: [{set: "keep.stage", value: 1}]}
    ],
```

- [ ] **Step 6: Checkpoints.** In `Checkpoints.bs`, update the header comment ("... 4 gate open, 5 met Mara in the keep, 6 goblin king beaten") and append:

```brighterscript
  if n >= 5
    flags.set("keep.stage", 1)
    flags.set("gate.stage", 3)
  end if
  if n >= 6
    for each key in ["dng.guard.cleared", "dng.guard.keyTaken", "dng.L1.open", "dng.portcullis", "dng.ante.a", "dng.ante.b", "dng.ante.solved", "dng.ante.keyTaken", "dng.L2.open", "dng.kingDefeated"]
      flags.set(key, true)
    end for
    flags.set("keep.stage", 3)
    carried.add("throneKey")
  end if
```

and add:

```brighterscript
' Where a checkpoint starts when no scene is given.
'
' @param {integer} n
' @return {string} scene name
function checkpointScene(n as integer) as string
  if n >= 6
    return "KingsHallScene"
  else if n >= 5
    return "CastleScene"
  end if
  return "TownScene"
end function
```

In `main.bs`'s deep-link block, replace `startScene = "TownScene"` with:

```brighterscript
    startScene = "TownScene"
    if args.stage <> invalid
      startScene = checkpointScene(args.stage.toInt())
    end if
```

(import `"Story/Checkpoints.bs"` if `main.bs` doesn't reach it through `Story.bs` already — it does, but add it explicitly per the import rule).

- [ ] **Step 7: Run tests.** `cd examples/rpg && npm test` → PASS.

- [ ] **Step 8: Commit.**

```bash
git add examples/rpg
git commit -m "rpg story: Mara, the keep quest, dungeon rules, checkpoints 5-6 (#289)"
```

---

### Task 15: Debug launch params and the goblin showcase

**Files:**
- Create: `Story/DebugParams.bs` (pure), `Scenes/GoblinShowcaseScene.bs`
- Modify: `main.bs` (deep-link block), `examples/rpg/bsconfig.test.json` (add `"source/Story/DebugParams.bs"`)
- Test: `examples/rpg/tests/DebugParams.spec.bs`

**Interfaces:**
- Consumes: `Story.peaceful`/`openOnArrival` (Task 3), `Goblin.freezePose`/`GoblinKing.freezePose` (Tasks 10-11).
- Produces: `function parseFlagList(text as dynamic) as string[]`, `function parseItemList(text as dynamic) as roAssociativeArray` (id → count). Params: `spawn`, `flags`, `items`, `peaceful`, `open`.

- [ ] **Step 1: Write the failing test.** Create `examples/rpg/tests/DebugParams.spec.bs`:

```brighterscript
namespace tests
  @suite("debug params")
  class DebugParamsTests extends rooibos.BaseTestSuite

    @it("splits a flag list, skipping blanks")
    function _()
      m.assertEqual(["dng.portcullis", "dng.guard.cleared"], parseFlagList("dng.portcullis,,dng.guard.cleared"))
      m.assertEqual([], parseFlagList(invalid))
    end function

    @it("reads item counts, defaulting to 1")
    function _()
      items = parseItemList("smallKey:2,throneKey")
      m.assertEqual(2, items.smallKey)
      m.assertEqual(1, items.throneKey)
      m.assertEqual(0, parseItemList(invalid).count())
    end function

  end class
end namespace
```

- [ ] **Step 2: Run to verify it fails.** Add `"source/Story/DebugParams.bs"` to `bsconfig.test.json` after `SaveData.bs`; `cd examples/rpg && npm test` → FAIL.

- [ ] **Step 3: Implement.** Create `Story/DebugParams.bs`:

```brighterscript
' Parsing for the deep-link testing params (main.bs): --param flags=a,b and --param items=id:n,id.

' @param {dynamic} text - "a,b,c", or invalid
' @return {string[]}
function parseFlagList(text as dynamic) as string[]
  names = [] as string[]
  if text = invalid
    return names
  end if
  for each part in (text as string).Split(",")
    if part.Trim() <> ""
      names.push(part.Trim())
    end if
  end for
  return names
end function

' @param {dynamic} text - "smallKey:2,throneKey", or invalid
' @return {roAssociativeArray} item id -> count
function parseItemList(text as dynamic) as roAssociativeArray
  counts = {}
  for each part in parseFlagList(text)
    pieces = part.Split(":")
    count = 1
    if pieces.count() > 1
      count = pieces[1].toInt()
    end if
    counts[pieces[0]] = count
  end for
  return counts
end function
```

- [ ] **Step 4: Run tests.** `cd examples/rpg && npm test` → PASS.

- [ ] **Step 5: Showcase scene.** Create `Scenes/GoblinShowcaseScene.bs`:

```brighterscript
import "AreaScene.bs"
import "../Maps/DungeonData.bs"
import "../Entities/Goblin.bs"
import "../Entities/GoblinKing.bs"

' Deep link only (--param scene=GoblinShowcaseScene): goblins and the king frozen in each pose,
' for checking their sprites in a screenshot.
class GoblinShowcaseScene extends AreaScene

  sub new(game as BGE.Game)
    super(game)
    m.name = "GoblinShowcaseScene"
  end sub

  override function getRows() as string[]
    return buildRoomRows("")
  end function

  override function getPlacements() as MapPlacement[]
    return [{type: "spawn", id: "start", col: 10, row: 9, facing: FacingDirection.up}]
  end function

  override sub onCreate(args as roAssociativeArray)
    super.onCreate(args)
    numRows = ROOM_ROWS
    x = 3 * TILE_SIZE
    for each pose in ["walk", "tell", "lunge", "dying"]
      newGoblin = new Goblin(m.game)
      m.game.addEntity(newGoblin, {x: x, y: cellBottomY(numRows, 5), solidWorld: m.solidWorld, mapWidth: m.mapWidth, mapHeight: m.mapHeight})
      newGoblin.freezePose(pose)
      x += 3 * TILE_SIZE
    end for
    x = 5 * TILE_SIZE
    for each pose in ["walk", "tell", "stunned"]
      newKing = new GoblinKing(m.game)
      m.game.addEntity(newKing, {x: x, y: cellBottomY(numRows, 8), solidWorld: m.solidWorld, mapWidth: m.mapWidth, mapHeight: m.mapHeight})
      newKing.freezePose(pose)
      x += 5 * TILE_SIZE
    end for
  end sub

end class
```

(The spawn at row 9 sits below the kings at row 8; if the player overlaps a king's body collider it takes contact damage, which a screenshot doesn't care about. Launch with `peaceful=1` anyway is not required here.)

Define it in `main.bs` (import `"Scenes/GoblinShowcaseScene.bs"`):

```brighterscript
  showcase = new GoblinShowcaseScene(game)
  game.defineScene(showcase)
```

- [ ] **Step 6: Wire the params.** In `main.bs` (import `"Story/DebugParams.bs"`), make the deep-link block:

```brighterscript
  ' Deep links for checking an area or story point directly; they never touch the real save.
  ' e.g. rokubot launch dev --param scene=GuardroomScene --param stage=5 --param flags=dng.guard.cleared
  ' Also: spawn=<id>, items=smallKey:2,throneKey, peaceful=1 (no enemies), open=inventory.
  if args.scene <> invalid or args.stage <> invalid
    storyEntity.savingEnabled = false
    ensurePlayer(game)
    storyEntity.newGame()
    startScene = "TownScene"
    if args.stage <> invalid
      storyEntity.applyCheckpoint(args.stage.toInt())
      startScene = checkpointScene(args.stage.toInt())
    end if
    if args.scene <> invalid
      startScene = args.scene
    end if
    for each flagName in parseFlagList(args.flags)
      storyEntity.flags.set(flagName, true)
    end for
    items = parseItemList(args.items)
    for each itemId in items
      for i = 1 to items[itemId]
        storyEntity.inventory.add(itemId)
      end for
    end for
    storyEntity.peaceful = args.peaceful = "1"
    if args.open <> invalid
      storyEntity.openOnArrival = args.open
    end if
    spawn = "start"
    if args.spawn <> invalid
      spawn = args.spawn
    end if
    game.changeSceneWithFade(startScene, {spawn: spawn})
  else
```

(`args.peaceful = "1"` compares a string to a string, or `invalid` to a string: guard it as `storyEntity.peaceful = args.peaceful <> invalid and args.peaceful = "1"`.)

Items given this way skip `onAcquire` — fine for keys (the only use).

- [ ] **Step 7: Build and test.** `cd examples/rpg && npx bsc --create-package=false && npm test` → no errors, PASS.

- [ ] **Step 8: Commit.**

```bash
git add examples/rpg
git commit -m "rpg: debug launch params and a goblin showcase room (#289)"
```

---

### Task 16: On-device screenshots, docs, D2 issue, final checks

**Files:**
- Modify: `CLAUDE.md` (rpg bullet), `.claude/skills/rokubot-examples/SKILL.md` (rpg row), `specs/2026-10-04-rpg-slice-d1-dungeon-design.md` (only if something changed during build)

- [ ] **Step 1: Full checks.** From the repo root: `npm run check` → PASS; `cd examples/rpg && npm test` → PASS; `npm run validate-examples` → no rpg errors.

- [ ] **Step 2: Package and sideload.** Follow the `rokubot-examples` skill: `cd examples/rpg && npm run package`, sideload with `--deleteDevChannel`. **Screenshots only — never press direction keys to walk, never fight.** For each launch below, take one screenshot after the fade (retry a black frame once; see the skill):

| Check | Launch params |
|---|---|
| Entry hall, servant, barred north gate, locked east door with key icon, bats | `scene=CastleScene stage=5 peaceful=1` |
| Entry hall with gates open | `scene=CastleScene stage=5 flags=dng.portcullis,dng.L1.open peaceful=1` |
| Guardroom shutters closed + goblins | `scene=GuardroomScene stage=5` |
| Guardroom cleared, key pickup visible | `scene=GuardroomScene stage=5 flags=dng.guard.cleared peaceful=1` |
| Storeroom pots + heart pickup | `scene=StoreroomScene stage=5 peaceful=1` |
| Barracks switch (up) | `scene=BarracksScene stage=5 peaceful=1` |
| Barracks switch (pressed tint) | `scene=BarracksScene stage=5 flags=dng.portcullis peaceful=1` |
| Antechamber switches, locked north door | `scene=AntechamberScene stage=5 peaceful=1` |
| King's hall with boss bar | `scene=KingsHallScene stage=5` |
| King's hall after the fight: great door, throne key gone (held) | `stage=6 peaceful=1` |
| HUD with 2 small keys | `scene=CastleScene stage=5 items=smallKey:2 peaceful=1` |
| Inventory panel with both keys + keep objective | `scene=CastleScene stage=5 items=smallKey:2,throneKey open=inventory peaceful=1` |
| Goblin and king poses, scale, tint, feet on shadows | `scene=GoblinShowcaseScene` |

For each screenshot confirm: everything title-safe (HUD, boss bar, panels ≥10% in); the arch art sits cleanly in the wall (fix `archBars`/`archOpen` atlas coordinates or the Gate image offset if not); goblin rows face the way they walk (if a row is mirrored, fix `rowFacings` in `Goblin.bs`); the king's feet sit on his shadow at 1.5×. Fix anything wrong, rebuild, re-screenshot that row.

- [ ] **Step 3: Hand real-time play to the user.** Ask them to play from `stage=5` through the guardroom, barracks switch, antechamber, and the king fight, and report: goblin lunge feel, king charge/stun timing, shutters opening on clear, messages queuing, keys consumed by doors, pots dropping loot.

- [ ] **Step 4: Docs.** In `CLAUDE.md`'s `examples/rpg` bullet, add a **Dungeon** sentence (issue #289, `specs/2026-10-04-rpg-slice-d1-dungeon-design.md`): six one-screen rooms (`Scenes/DungeonScenes.bs`, `Maps/DungeonData.bs`'s `buildRoomRows()`); locks, switches and shutters are `live: true` placements re-checked on the Story's `storyUpdated` event (`Maps/LivePlacements.bs`), built as `Gate`/`FloorSwitch`/`Pickup` entities; the `{message}` effect queues a speaker-less dialogue; `Goblin`/`GoblinKing` (telegraphed lunge; charge-into-wall stun); pots; small keys in the HUD; new deep-link params `spawn`/`flags`/`items`/`peaceful`/`open` and `GoblinShowcaseScene`; checkpoints 5-6. Update the skill's rpg row: scene list adds the five rooms and `GoblinShowcaseScene`, stage range `0-6`, and the new params.

- [ ] **Step 5: File D2.**

```bash
gh issue create --title "examples/rpg Slice D2: throne room, witch boss, ending" --label enhancement --body "Follow-up to #289 (D1: the keep dungeon, specs/2026-10-04-rpg-slice-d1-dungeon-design.md).

- **Throne room** behind the great door in KingsHallScene (D1 leaves it sealed; the throne key is already in the player's hands and \`dng.throneDoor.tried\` records the attempt).
- **Witch boss fight**: keeps her distance, casts bolts, summons goblin waves (reuse \`Goblin\` and \`pickDrain\`). Defeating her makes every castle monster vanish. Sprite: \`/Users/mpearce/Downloads/rpg/lpcfemalechainpreview.png\` - a full 832x1344 LPC sheet (spellcast rows 0-3, walk 8-11, shoot 16-19, hurt 20), sliceable despite #289's note.
- **Ending**: Elder Bram's closing dialogue, quest complete.
- **Decide whether to promote the story layer** (\`examples/rpg/src/source/Story/\`) to the engine. D1 evidence: locks/switches/shutters/keys needed only \`live\` placements, one new effect (\`message\`) and two routed events.
- All UI title-safe."
```

Then add a comment on #289 linking the new issue.

- [ ] **Step 6: Commit.**

```bash
git add CLAUDE.md .claude/skills/rokubot-examples/SKILL.md specs
git commit -m "docs: rpg dungeon (Slice D1) in CLAUDE.md and the rokubot skill (#289)"
```

- [ ] **Step 7: Finish.** Use superpowers:finishing-a-development-branch (PR, written with the pr-voice skill, `Closes` nothing — #289 stays open for D2; reference it with "Part of #289").
