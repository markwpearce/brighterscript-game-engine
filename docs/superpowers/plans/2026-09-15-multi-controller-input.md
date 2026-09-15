# Unified Multi-Controller Input Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Roku remotes (including multiple simultaneous ones), brs-engine simulator gamepads (`multi_controllers=1`), and browser/websocket controllers (issue #149) all flow through one shared `playerIndex` space and one `GameInput`/`ControlMap` code path.

**Architecture:** `roUniversalControlEvent.GetRemoteID()` (pre-existing, works on real hardware) identifies which physical remote/gamepad fired an event. `BGE.Controller.ControllerRegistry` gains a lazy remote-ID → `playerIndex` assignment sharing the same pool it already hands out to browser controllers, plus per-player caching of the last-seen event (for simulator-only analog `GetValue()` reads) and a per-player d-pad fallback. `Game.bs`'s ~10 duplicated `GameInput`-construction call sites collapse to two small helpers; its single global "held button" tracking becomes per-player. `ControlMap`'s remote-vs-controller matching becomes one code path keyed on `playerIndex` instead of a hardcoded `-1` sentinel.

**Tech Stack:** BrighterScript, Rooibos (`rooibos-roku`) for headless unit tests via `brs-cli` (now `brs-node@2.6.0`, bumped this session — includes brs-engine PR #1226).

**Spec:** `specs/2026-09-15-multi-controller-input-design.md`

## Global Constraints

- `playerIndex = -1` no longer means "the physical remote" anywhere in the engine. Every remote/gamepad/browser-controller-sourced `GameInput` gets a real `0+` index from the same shared pool. `-1` remains only the constructor's own "unset" default for a manually-built `GameInput` that isn't tied to any input source.
- `GetValue(axis)` (analog stick/trigger) is simulator-only — always gate it behind `roRemoteInfo.HasFeature("multi_controllers", 0)`, cached once, never called unconditionally. Real hardware must see zero behavior change.
- `ControllerRegistry`/`ControlMap` are documented as "not part of the public API a game touches directly except via `game.controls`" — an internal signature change there (e.g. `setRemoteDpad`) is not a public breaking change, but update every call site and spec test that uses it.
- Follow existing doc-comment conventions: JSDoc-style `'` comments for public API methods (pulled into `npm run docs`), plain `'` comments for internal rationale.
- Run `npm run validate` after any engine change (per CLAUDE.md, always run after changing engine code) and `npm run check` before considering a task done.
- `msg.GetValue(axis)` is a brs-engine-only extension with no type entry in `brighterscript`'s roku-types data — calling it directly on a typed `roUniversalControlEvent` will fail `bsc`'s type checker. Cast the cached event reference through `as object` before calling `.GetValue(...)` on it (confirmed necessary; `GetRemoteID()` IS typed and needs no cast).

---

### Task 1: `ControllerRegistry` — remote-ID player-index assignment

**Files:**
- Modify: `src/source/engine/controller/ControllerRegistry.bs`
- Test: `src/source/engine/controller/ControllerRegistry.spec.bs`

**Interfaces:**
- Consumes: nothing new (existing `assignPlayerIndex()`/`connections` map).
- Produces: `assignPlayerIndexForRemoteId(remoteId as string) as integer` — used by Task 4 (`Game.bs`).

- [ ] **Step 1: Write the failing tests**

Add to `ControllerRegistry.spec.bs`, after the existing `@describe("assignPlayerIndex / releasePlayerIndex")` block:

```brighterscript
    @describe("assignPlayerIndexForRemoteId")

    @it("assigns the same index for the same remote id on repeated calls")
    function _()
      registry = new BGE.Controller.ControllerRegistry()
      first = registry.assignPlayerIndexForRemoteId("30:1")
      second = registry.assignPlayerIndexForRemoteId("30:1")
      m.assertEqual(first, second)
    end function

    @it("assigns increasing indexes for distinct remote ids")
    function _()
      registry = new BGE.Controller.ControllerRegistry()
      first = registry.assignPlayerIndexForRemoteId("30:1")
      second = registry.assignPlayerIndexForRemoteId("30:2")
      m.assertEqual(0, first)
      m.assertEqual(1, second)
    end function

    @it("shares one index pool with browser-controller assignPlayerIndex()")
    function _()
      registry = new BGE.Controller.ControllerRegistry()
      remoteIndex = registry.assignPlayerIndexForRemoteId("30:1")
      controllerIndex = registry.assignPlayerIndex()
      m.assertEqual(0, remoteIndex)
      m.assertEqual(1, controllerIndex)
    end function
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `npm run build-tests && npm run test:ci`
Expected: FAIL — `assignPlayerIndexForRemoteId` is not a member of `ControllerRegistry`.

- [ ] **Step 3: Implement**

In `ControllerRegistry.bs`, add a new private field alongside `private connections = {}`:

```brighterscript
    private remoteIdToPlayerIndex = {} ' remoteId (GetRemoteID() string) -> playerIndex
```

Refactor the existing `assignPlayerIndex()` to share one "lowest free index" scan with the new method:

```brighterscript
    ' Assigns the lowest player index not currently in use, across both
    ' browser-controller connections and physical-remote assignments (see
    ' assignPlayerIndexForRemoteId) - one shared pool, so a game's
    ' playerIndex-keyed bindings work the same regardless of source.
    function assignPlayerIndex() as integer
      index = m.lowestFreeIndex()
      m.connections[index.ToStr()] = new BGE.Controller.ControllerConnectionState()
      return index
    end function

    ' Looks up (or lazily assigns) a stable playerIndex for one physical
    ' remote/gamepad, identified by roUniversalControlEvent.GetRemoteID()
    ' (e.g. "30:1"). Never released - a physical remote has no disconnect
    ' signal to key a release off, unlike a browser controller's WebSocket
    ' close.
    '
    ' @param {string} remoteId - the string from roUniversalControlEvent.GetRemoteID()
    ' @return {integer} - this remote's playerIndex, stable for the run
    function assignPlayerIndexForRemoteId(remoteId as string) as integer
      existing = m.remoteIdToPlayerIndex[remoteId]
      if existing <> invalid
        return existing
      end if
      index = m.lowestFreeIndex()
      m.remoteIdToPlayerIndex[remoteId] = index
      return index
    end function

    private function lowestFreeIndex() as integer
      index = 0
      while m.connections.DoesExist(index.ToStr()) or m.isRemoteIndex(index)
        index++
      end while
      return index
    end function

    private function isRemoteIndex(index as integer) as boolean
      for each remoteId in m.remoteIdToPlayerIndex
        if m.remoteIdToPlayerIndex[remoteId] = index
          return true
        end if
      end for
      return false
    end function
```

Remove the old inline `while m.connections.DoesExist(...)` loop body from `assignPlayerIndex()` (replaced by `lowestFreeIndex()` above).

- [ ] **Step 4: Run tests to verify they pass**

Run: `npm run build-tests && npm run test:ci`
Expected: PASS, including the pre-existing `assignPlayerIndex / releasePlayerIndex` tests (unchanged behavior).

- [ ] **Step 5: Validate and commit**

Run: `npm run validate`
Expected: no new errors.

```bash
git add src/source/engine/controller/ControllerRegistry.bs src/source/engine/controller/ControllerRegistry.spec.bs
git commit -m "controller: assign a shared playerIndex per physical remote/gamepad"
```

---

### Task 2: `ControllerRegistry` — per-player analog stick + per-player d-pad fallback

**Files:**
- Modify: `src/source/engine/controller/ControllerRegistry.bs`
- Test: `src/source/engine/controller/ControllerRegistry.spec.bs`

**Interfaces:**
- Consumes: `BGE.Math.VectorOps.create(x, y)` (existing).
- Produces: `setRemoteEvent(playerIndex, event)`, `getRemoteAnalogStick(playerIndex) as BGE.Math.Vector`, `setRemoteDpad(playerIndex, x, y)` (signature change, was `setRemoteDpad(x, y)`), `getRemoteDpad(playerIndex) as BGE.Math.Vector` (signature change, was `getRemoteDpad()`) — all consumed by Task 3 (`ControlMap`) and Task 4 (`Game.bs`).

**Note:** this changes `setRemoteDpad`/`getRemoteDpad`'s existing signature from global (no `playerIndex`) to per-player. This is necessary once remotes can be plural — the old global-single-remote-dpad behavior would silently mix two different remotes' d-pad state together. `ControllerRegistry` is documented as internal (a game uses `ControlMap`), so this isn't a public API break, but every existing call site/test must be updated in this task.

- [ ] **Step 1: Write the failing tests**

Replace the existing `@describe("remote d-pad fallback state")` block in `ControllerRegistry.spec.bs` with:

```brighterscript
    @describe("remote d-pad fallback state (per player)")

    @it("stores and returns the remote d-pad vector for a given player")
    function _()
      registry = new BGE.Controller.ControllerRegistry()
      registry.setRemoteDpad(0, 1, 0)
      dpad = registry.getRemoteDpad(0)
      m.assertEqual(1.0, dpad.x)
      m.assertEqual(0.0, dpad.y)
    end function

    @it("keeps two players' d-pad state independent")
    function _()
      registry = new BGE.Controller.ControllerRegistry()
      registry.setRemoteDpad(0, 1, 0)
      registry.setRemoteDpad(1, 0, -1)
      m.assertEqual(1.0, registry.getRemoteDpad(0).x)
      m.assertEqual(0.0, registry.getRemoteDpad(0).y)
      m.assertEqual(0.0, registry.getRemoteDpad(1).x)
      m.assertEqual(-1.0, registry.getRemoteDpad(1).y)
    end function

    @it("returns a neutral vector for a player never set")
    function _()
      registry = new BGE.Controller.ControllerRegistry()
      dpad = registry.getRemoteDpad(0)
      m.assertEqual(0.0, dpad.x)
      m.assertEqual(0.0, dpad.y)
    end function

    @describe("getRemoteAnalogStick")

    @it("returns a neutral vector when no event has been cached for this player")
    function _()
      registry = new BGE.Controller.ControllerRegistry()
      stick = registry.getRemoteAnalogStick(0)
      m.assertEqual(0.0, stick.x)
      m.assertEqual(0.0, stick.y)
    end function

    @it("reads GetValue(leftX/leftY) off the cached event when multi_controllers is supported")
    function _()
      registry = new BGE.Controller.ControllerRegistry()
      fakeEvent = {
        GetValue: function(axis as integer) as float
          if axis = BGE.Controller.ANALOG_AXIS_LEFT_X then return 0.75
          if axis = BGE.Controller.ANALOG_AXIS_LEFT_Y then return -0.25
          return 0.0
        end function
      }
      registry.setRemoteEvent(0, fakeEvent)
      stick = registry.getRemoteAnalogStick(0)
      ' roRemoteInfo.HasFeature("multi_controllers", 0) is true under brs-node 2.6.0
      m.assertEqual(0.75, stick.x)
      m.assertEqual(-0.25, stick.y)
    end function

    @it("is neutral for a different player index than the one an event was cached for")
    function _()
      registry = new BGE.Controller.ControllerRegistry()
      fakeEvent = {
        GetValue: function(axis as integer) as float
          return 0.5
        end function
      }
      registry.setRemoteEvent(0, fakeEvent)
      stick = registry.getRemoteAnalogStick(1)
      m.assertEqual(0.0, stick.x)
      m.assertEqual(0.0, stick.y)
    end function
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `npm run build-tests && npm run test:ci`
Expected: FAIL — `setRemoteDpad`/`getRemoteDpad` called with the wrong arg count, `getRemoteAnalogStick`/`setRemoteEvent`/`BGE.Controller.ANALOG_AXIS_LEFT_X` don't exist yet.

- [ ] **Step 3: Implement**

At the top of the `namespace BGE.Controller` block in `ControllerRegistry.bs` (near the existing `CONTROLLER_BUTTON_CODE_*`-style consts in `GameInput.bs` — these ones live here since only this file's `getRemoteAnalogStick` uses them):

```brighterscript
  ' Axis indexes for roUniversalControlEvent.GetValue(axis) - brs-engine's
  ' AnalogAxis enum (simulator-only extension, PR lvcabral/brs-engine#1226).
  const ANALOG_AXIS_LEFT_X = 0
  const ANALOG_AXIS_LEFT_Y = 1
```

Replace the existing single-value fields/methods:

```brighterscript
    private remoteDpad as BGE.Math.Vector = BGE.Math.VectorOps.create()
```
```brighterscript
    sub setRemoteDpad(x as float, y as float)
      m.remoteDpad = BGE.Math.VectorOps.create(x, y)
    end sub

    function getRemoteDpad() as BGE.Math.Vector
      return m.remoteDpad
    end function
```

with:

```brighterscript
    private remoteDpad = {} ' playerIndex.ToStr() -> BGE.Math.Vector
    private remoteEvents = {} ' playerIndex.ToStr() -> last-seen roUniversalControlEvent (dynamic)
    private multiControllersSupported as dynamic = invalid ' cached HasFeature() check, invalid = not yet checked

    ' Records one physical remote/gamepad's current d-pad-derived {x, y},
    ' used by BGE.Controller.ControlMap.getAxis() when no controller stick
    ' is bound (or it's neutral) for this player.
    '
    ' @param {integer} playerIndex
    ' @param {float} x - -1..1
    ' @param {float} y - -1..1
    sub setRemoteDpad(playerIndex as integer, x as float, y as float)
      m.remoteDpad[playerIndex.ToStr()] = BGE.Math.VectorOps.create(x, y)
    end sub

    ' @param {integer} playerIndex
    ' @return {BGE.Math.Vector} - this player's remote d-pad {x, y}, neutral if never set
    function getRemoteDpad(playerIndex as integer) as BGE.Math.Vector
      return m.remoteDpad[playerIndex.ToStr()] ?? BGE.Math.VectorOps.create()
    end function

    ' Caches the last roUniversalControlEvent seen for this player, so
    ' getRemoteAnalogStick() can keep reading its live GetValue() every
    ' frame even on a frame with no new event for this remote (a stick
    ' held at a nonzero deflection produces no new roUniversalControlEvent
    ' - see specs/2026-09-15-multi-controller-input-design.md).
    '
    ' @param {integer} playerIndex
    ' @param {dynamic} event - the roUniversalControlEvent, passed as dynamic
    '   since GetValue() isn't part of its typed interface
    sub setRemoteEvent(playerIndex as integer, event as dynamic)
      m.remoteEvents[playerIndex.ToStr()] = event
    end sub

    ' @param {integer} playerIndex
    ' @return {BGE.Math.Vector} - this player's left analog stick, {0,0} if
    '   no event cached yet or the running engine doesn't support
    '   multi_controllers (always {0,0} on real Roku hardware)
    function getRemoteAnalogStick(playerIndex as integer) as BGE.Math.Vector
      if not m.isMultiControllersSupported()
        return BGE.Math.VectorOps.create()
      end if
      event = m.remoteEvents[playerIndex.ToStr()]
      if event = invalid
        return BGE.Math.VectorOps.create()
      end if
      x = (event as object).GetValue(BGE.Controller.ANALOG_AXIS_LEFT_X)
      y = (event as object).GetValue(BGE.Controller.ANALOG_AXIS_LEFT_Y)
      return BGE.Math.VectorOps.create(x, y)
    end function

    private function isMultiControllersSupported() as boolean
      if m.multiControllersSupported = invalid
        remoteInfo = CreateObject("roRemoteInfo")
        m.multiControllersSupported = remoteInfo.HasFeature("multi_controllers", 0)
      end if
      return m.multiControllersSupported
    end function
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `npm run build-tests && npm run test:ci`
Expected: PASS.

- [ ] **Step 5: Validate and commit**

Run: `npm run validate`

```bash
git add src/source/engine/controller/ControllerRegistry.bs src/source/engine/controller/ControllerRegistry.spec.bs
git commit -m "controller: per-player remote analog stick + d-pad fallback"
```

---

### Task 3: `ControlMap` — unify remote/controller matching, extend `getAxis()`

**Files:**
- Modify: `src/source/engine/controller/ControlMap.bs`
- Test: `src/source/engine/controller/ControlMap.spec.bs`

**Interfaces:**
- Consumes: `ControllerRegistry.getRemoteDpad(playerIndex)`, `getRemoteAnalogStick(playerIndex)` (Task 2), `GameInput.playerIndex` (real index for remotes, from Task 4 in `Game.bs` — but this task's own tests construct `GameInput` directly, so it doesn't need Task 4 to land first).
- Produces: no signature changes to `ControlMap`'s own public methods.

- [ ] **Step 1: Update existing tests for the new playerIndex semantics**

In `ControlMap.spec.bs`, every `new BGE.GameInput(code, heldMs)` that represents a remote press/release/held event must now pass an explicit `playerIndex` (remotes no longer default to `-1`). Update these specific constructions:

```brighterscript
      controls.onInput(new BGE.GameInput(6, 0)) ' OK, pressed
```
→
```brighterscript
      controls.onInput(new BGE.GameInput(6, 0, 0)) ' OK, pressed, player 0
```

Apply the same `, 0)` addition to every remaining bare `new BGE.GameInput(<code>, <ms>)` call in this file that isn't already a controller-button construction (those already pass `playerIndex`/`buttonName` and are unaffected): the `4, 0`, `1006, 50` / `1006, 100`, `106, 0` cases across the "bindAction/isActionPressed via remote button", "either the remote or the controller binding fires the same action", "frame semantics", and "getActionHeldTimeMs" describe blocks.

Update the two `getAxis`-related tests that call the old `ControllerRegistry.setRemoteDpad`/no-arg signature:

```brighterscript
    @it("falls back to the remote d-pad when the controller stick is neutral")
    function _()
      registry = new BGE.Controller.ControllerRegistry()
      registry.setRemoteDpad(0, 0, 1) ' player 0
      controls = new BGE.Controller.ControlMap(registry)
      controls.bindAxis("move")
      result = controls.getAxis("move")
      m.assertEqual(0.0, result.x)
      m.assertEqual(1.0, result.y)
    end function
```

Add one new test proving the unified match now requires the player index to line up:

```brighterscript
    @it("does not fire a remote-bound action for a different player's remote")
    function _()
      controls = new BGE.Controller.ControlMap(new BGE.Controller.ControllerRegistry())
      controls.bindAction("p1jump", "ok", invalid, 1) ' player 1's remote
      controls.onInput(new BGE.GameInput(6, 0, 0)) ' player 0's remote presses OK
      m.assertFalse(controls.isActionPressed("p1jump"))
    end function
```

And one proving the analog-stick fallback link in `getAxis`'s chain (fake `ControllerRegistry` isn't needed - `getRemoteAnalogStick` already returns neutral without a cached event, which is the common/no-simulator-analog case, so this test documents that neutral case explicitly):

```brighterscript
    @it("falls back through remote analog stick to remote d-pad when neither controller nor analog stick has data")
    function _()
      registry = new BGE.Controller.ControllerRegistry()
      registry.setRemoteDpad(0, -1, 0)
      controls = new BGE.Controller.ControlMap(registry)
      controls.bindAxis("move") ' player 0, no controller stick, no analog event cached
      result = controls.getAxis("move")
      m.assertEqual(-1.0, result.x)
      m.assertEqual(0.0, result.y)
    end function
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `npm run build-tests && npm run test:ci`
Expected: FAIL — `p1jump`/new player-mismatch test fails because `onInput` still matches any remote input regardless of `playerIndex`; `setRemoteDpad(0, 0, 1)` fails to compile/run against the old 2-arg signature until Task 2 lands (do this task after Task 2).

- [ ] **Step 3: Implement**

In `ControlMap.bs`, replace `onInput()`'s matching logic:

```brighterscript
        matchesRemote = binding.remoteButton <> invalid and input.playerIndex = -1 and input.isButton(binding.remoteButton)
        matchesController = binding.controllerButton <> invalid and input.playerIndex = binding.playerIndex and input.button = binding.controllerButton
```

with:

```brighterscript
        matchesRemote = binding.remoteButton <> invalid and input.playerIndex = binding.playerIndex and input.isButton(binding.remoteButton)
        matchesController = binding.controllerButton <> invalid and input.playerIndex = binding.playerIndex and input.button = binding.controllerButton
```

Update `getAxis()`'s fallback chain to add the remote analog stick before the remote d-pad:

```brighterscript
    function getAxis(name as string) as BGE.Math.Vector
      binding = m.axisBindings[name] as AxisBinding
      if binding = invalid
        return BGE.Math.VectorOps.create()
      end if
      stickVector = m.registry.getStick(binding.playerIndex, binding.stick)
      if stickVector.x <> 0 or stickVector.y <> 0
        return stickVector
      end if
      analogVector = m.registry.getRemoteAnalogStick(binding.playerIndex)
      if analogVector.x <> 0 or analogVector.y <> 0
        return analogVector
      end if
      return m.registry.getRemoteDpad(binding.playerIndex)
    end function
```

Update the doc comment above `bindAction`/`onInput` and `getAxis` to describe the new unified matching (see Step 5 of Task 5 for the fuller docs pass; a short inline comment here is enough):

```brighterscript
    ' Feeds one GameInput event (remote, simulator gamepad, or browser
    ' controller - all three carry a real playerIndex, see
    ' BGE.Controller.ControllerRegistry.assignPlayerIndexForRemoteId)
    ' through every action binding, updating whichever actions it matches.
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `npm run build-tests && npm run test:ci`
Expected: PASS.

- [ ] **Step 5: Validate and commit**

Run: `npm run validate`

```bash
git add src/source/engine/controller/ControlMap.bs src/source/engine/controller/ControlMap.spec.bs
git commit -m "controller: unify remote/controller matching on playerIndex, add analog fallback"
```

---

### Task 4: `Game.bs` — per-remote held tracking + one `GameInput` construction path

**Files:**
- Modify: `src/source/engine/Game.bs`

**Interfaces:**
- Consumes: `ControllerRegistry.assignPlayerIndexForRemoteId(remoteId)`, `setRemoteEvent(playerIndex, event)`, `setRemoteDpad(playerIndex, x, y)` (Tasks 1-2). `roUniversalControlEvent.GetRemoteID()` (typed, no cast needed).
- Produces: no new public `Game` methods — this is an internal refactor. Behavior for existing single-remote games is unchanged (first remote seen this run always gets `playerIndex = 0`, matching every default `bindAction(..., playerIndex=0)`/`onInput` check that assumed the old `-1` sentinel).

This task has no new Rooibos spec of its own (no headless `roUniversalControlEvent` fixture is possible — confirmed `CreateObject("roUniversalControlEvent")` fails at runtime, it's only ever delivered via the message port). Verification is: (a) `npm run validate` + `npm run check` (existing `Game.spec.bs`/`GameEntity.spec.bs` construct a real `Game` and must keep passing unchanged), (b) manual on-device/simulator verification in Task 6.

- [ ] **Step 1: Replace the single-remote held-button fields**

In `Game.bs`, remove:

```brighterscript
    private buttonHeld = -1
    private buttonHeldTimeMs = 0
```
```brighterscript
    private buttonHeldTimer as roTimespan = CreateObject("roTimespan")
```

Add in their place:

```brighterscript
    ' Per-remote-id held-button tracking (playerIndex.ToStr() -> {buttonCode, timer}),
    ' replacing a single global that could only track one remote's held button at
    ' a time - two remotes each holding a different button now both repeat
    ' correctly instead of one clobbering the other's state.
    private remoteHeldButtons = {}
```

- [ ] **Step 2: Add the two shared helpers**

Add these private methods near `drainControllerInput()`:

```brighterscript
    ' The one place a remote-sourced press/release GameInput gets built -
    ' resolves this remote's shared playerIndex and caches the raw event
    ' for later analog-stick reads (see ControllerRegistry.getRemoteAnalogStick).
    '
    ' @param {roUniversalControlEvent} msg
    ' @return {GameInput}
    private function gameInputForRemoteMsg(msg as roUniversalControlEvent) as GameInput
      remoteId = msg.GetRemoteID()
      m.controllerRegistry.setRemoteEvent(m.controllerRegistry.assignPlayerIndexForRemoteId(remoteId), msg)
      playerIndex = m.controllerRegistry.assignPlayerIndexForRemoteId(remoteId)
      return new GameInput(msg.GetInt(), 0, playerIndex)
    end function

    ' One synthesized held/repeat GameInput per remote currently holding a
    ' button down, replacing the old single m.buttonHeld-driven check at
    ' every call site that needs it.
    '
    ' @return {GameInput[]}
    private function remoteHeldGameInputs() as GameInput[]
      inputs = [] as GameInput[]
      for each remoteId in m.remoteHeldButtons
        entry = m.remoteHeldButtons[remoteId]
        playerIndex = m.controllerRegistry.assignPlayerIndexForRemoteId(remoteId)
        heldTimeMs = entry.timer.TotalMilliseconds()
        inputs.Push(new GameInput(1000 + entry.buttonCode, heldTimeMs, playerIndex))
      end for
      return inputs
    end function
```

(`setRemoteEvent`/`assignPlayerIndexForRemoteId` called twice in `gameInputForRemoteMsg` is redundant - simplify to one call, storing the result once. Fix in Step 2 above before committing: compute `playerIndex` first, then use it for both `setRemoteEvent` and the returned `GameInput`.)

```brighterscript
    private function gameInputForRemoteMsg(msg as roUniversalControlEvent) as GameInput
      playerIndex = m.controllerRegistry.assignPlayerIndexForRemoteId(msg.GetRemoteID())
      m.controllerRegistry.setRemoteEvent(playerIndex, msg)
      return new GameInput(msg.GetInt(), 0, playerIndex)
    end function
```

- [ ] **Step 3: Update the message-draining loop (main `Play()` loop)**

Replace:

```brighterscript
        while screenMsg <> invalid
          if type(screenMsg) = "roUniversalControlEvent" and screenMsg.GetInt() <> 11
            universalControlEvents.Push(screenMsg as roUniversalControlEvent)
            if screenMsg.GetInt() < 100
              m.buttonHeld = screenMsg.GetInt()
              m.buttonHeldTimer.Mark()
            else
              m.buttonHeld = -1
              if m.enableAudioGuideSuppression
                if screenMsg.GetInt() = 110
                  audio_guide_suppression_ticker++
                  if audio_guide_suppression_ticker = 3
                    audio_guide_suppression_roURLTransfer.AsyncPostFromString("")
                    audio_guide_suppression_ticker = 0
                  end if
                else
                  audio_guide_suppression_ticker = 0
                end if
              end if
            end if
          end if
          screenMsg = m.screen_port.GetMessage()
        end while
        m.buttonHeldTimeMs = m.buttonHeldTimer.TotalMilliseconds()
```

with:

```brighterscript
        while screenMsg <> invalid
          if type(screenMsg) = "roUniversalControlEvent" and screenMsg.GetInt() <> 11
            universalControlEvents.Push(screenMsg as roUniversalControlEvent)
            remoteId = (screenMsg as roUniversalControlEvent).GetRemoteID()
            if screenMsg.GetInt() < 100
              timer = CreateObject("roTimespan")
              timer.Mark()
              m.remoteHeldButtons[remoteId] = {buttonCode: screenMsg.GetInt(), timer: timer}
            else
              m.remoteHeldButtons.Delete(remoteId)
              if m.enableAudioGuideSuppression
                if screenMsg.GetInt() = 110
                  audio_guide_suppression_ticker++
                  if audio_guide_suppression_ticker = 3
                    audio_guide_suppression_roURLTransfer.AsyncPostFromString("")
                    audio_guide_suppression_ticker = 0
                  end if
                else
                  audio_guide_suppression_ticker = 0
                end if
              end if
            end if
          end if
          screenMsg = m.screen_port.GetMessage()
        end while
```

(The `m.buttonHeldTimeMs = ...` line is deleted outright - each `remoteHeldGameInputs()` call computes its own per-remote `heldTimeMs` from that remote's own timer.)

- [ ] **Step 4: Update the `ControlMap` feed + remote d-pad computation**

Replace:

```brighterscript
        if m.controls.hasBindings()
          m.controls.beginFrame()
          for each msg in universalControlEvents
            m.controls.onInput(new GameInput(msg.GetInt(), 0))
          end for
          if m.buttonHeld <> -1
            m.controls.onInput(new GameInput(1000 + m.buttonHeld, m.buttonHeldTimeMs))
          end if
          for each input in controllerInputs
            m.controls.onInput(input)
          end for

          remoteDpadX = 0
          remoteDpadY = 0
          for each msg in universalControlEvents
            directionInput = new GameInput(msg.GetInt(), 0)
            if directionInput.press or directionInput.held
              if directionInput.x <> 0
                remoteDpadX = directionInput.x
              end if
              if directionInput.y <> 0
                remoteDpadY = directionInput.y
              end if
            else if directionInput.release
              if directionInput.isButton("left") or directionInput.isButton("right")
                remoteDpadX = 0
              end if
              if directionInput.isButton("up") or directionInput.isButton("down")
                remoteDpadY = 0
              end if
            end if
          end for
          if m.buttonHeld <> -1
            heldDirectionInput = new GameInput(1000 + m.buttonHeld, m.buttonHeldTimeMs)
            if heldDirectionInput.x <> 0
              remoteDpadX = heldDirectionInput.x
            end if
            if heldDirectionInput.y <> 0
              remoteDpadY = heldDirectionInput.y
            end if
          end if
          m.controllerRegistry.setRemoteDpad(remoteDpadX, remoteDpadY)
        end if
```

with:

```brighterscript
        if m.controls.hasBindings()
          m.controls.beginFrame()
          for each msg in universalControlEvents
            m.controls.onInput(m.gameInputForRemoteMsg(msg))
          end for
          for each heldInput in m.remoteHeldGameInputs()
            m.controls.onInput(heldInput)
          end for
          for each input in controllerInputs
            m.controls.onInput(input)
          end for

          remoteDpad = {} ' playerIndex.ToStr() -> {x, y}
          for each msg in universalControlEvents
            directionInput = m.gameInputForRemoteMsg(msg)
            key = directionInput.playerIndex.ToStr()
            entry = remoteDpad[key] ?? {x: 0.0, y: 0.0}
            if directionInput.press or directionInput.held
              if directionInput.x <> 0
                entry.x = directionInput.x
              end if
              if directionInput.y <> 0
                entry.y = directionInput.y
              end if
            else if directionInput.release
              if directionInput.isButton("left") or directionInput.isButton("right")
                entry.x = 0.0
              end if
              if directionInput.isButton("up") or directionInput.isButton("down")
                entry.y = 0.0
              end if
            end if
            remoteDpad[key] = entry
          end for
          for each heldInput in m.remoteHeldGameInputs()
            key = heldInput.playerIndex.ToStr()
            entry = remoteDpad[key] ?? {x: 0.0, y: 0.0}
            if heldInput.x <> 0
              entry.x = heldInput.x
            end if
            if heldInput.y <> 0
              entry.y = heldInput.y
            end if
            remoteDpad[key] = entry
          end for
          for each key in remoteDpad
            entry = remoteDpad[key]
            m.controllerRegistry.setRemoteDpad(key.ToInt(), entry.x, entry.y)
          end for
        end if
```

- [ ] **Step 5: Update the three remaining call sites**

`processEntityOnInput` (~line 874): replace

```brighterscript
      for each msg in universalControlEvents
        if not m.dispatchOnInput(entity, new GameInput(msg.GetInt(), 0))
          return false
        end if

        if entity.onECPKeyboard <> invalid and msg.GetChar() <> 0 and msg.GetChar() = msg.GetInt()
          entity.onECPKeyboard(msg.GetChar())
          if not m.isValidEntity(entity)
            return false
          end if
        end if
      end for
      if m.buttonHeld <> -1
        ' Button release codes are 100 plus the button press code
        ' This shows a button held code as 1000 plus the button press code
        if not m.dispatchOnInput(entity, new GameInput(1000 + m.buttonHeld, m.buttonHeldTimeMs))
          return false
        end if
      end if
      return true
```

with

```brighterscript
      for each msg in universalControlEvents
        if not m.dispatchOnInput(entity, m.gameInputForRemoteMsg(msg))
          return false
        end if

        if entity.onECPKeyboard <> invalid and msg.GetChar() <> 0 and msg.GetChar() = msg.GetInt()
          entity.onECPKeyboard(msg.GetChar())
          if not m.isValidEntity(entity)
            return false
          end if
        end if
      end for
      for each heldInput in m.remoteHeldGameInputs()
        if not m.dispatchOnInput(entity, heldInput)
          return false
        end if
      end for
      return true
```

`processFocusManagerInput` (~line 1267): replace

```brighterscript
      for each msg in universalControlEvents
        m.focusManager.update(new GameInput(msg.GetInt(), 0))
      end for
      if m.buttonHeld <> -1
        m.focusManager.update(new GameInput(1000 + m.buttonHeld, m.buttonHeldTimeMs))
      end if
```

with

```brighterscript
      for each msg in universalControlEvents
        m.focusManager.update(m.gameInputForRemoteMsg(msg))
      end for
      for each heldInput in m.remoteHeldGameInputs()
        m.focusManager.update(heldInput)
      end for
```

- [ ] **Step 6: Update `GameInput.bs`'s doc comment**

In `src/source/engine/GameInput.bs`, update the `playerIndex` field comment and constructor param comment:

```brighterscript
    ' Which remote/gamepad/controller this input came from. Every physical
    ' remote, brs-engine simulator gamepad, and connected browser controller
    ' gets its own real 0+ index from a shared pool (see
    ' BGE.Controller.ControllerRegistry.assignPlayerIndexForRemoteId /
    ' assignPlayerIndex) - -1 only means "not assigned", the constructor's
    ' own default for a GameInput built without an explicit playerIndex.
    playerIndex as integer = -1
```

and

```brighterscript
    ' @param {integer} [playerIndex=-1] - the assigned player index for this
    '   input's source (remote, simulator gamepad, or browser controller);
    '   -1 only if none was resolved
```

- [ ] **Step 7: Run the full check and manually sanity-test**

Run: `npm run check`
Expected: PASS (lint, validate, headless tests).

There's no headless test for the actual `roUniversalControlEvent` message-loop path (see this task's header note) - do a smoke pass with the existing `examples/controller` example before committing, per CLAUDE.md's rule that example runtime behavior is only proven by an actual run:

```bash
npm run build && cd examples/controller && npm run build
```

Then sideload/run it via the `rokubot-examples` skill and confirm: pressing the remote's OK button still fires `"jump"` (the example's existing single-remote binding), and held/repeat behavior on the remote looks unchanged from before this change.

- [ ] **Step 8: Commit**

```bash
git add src/source/engine/Game.bs src/source/engine/GameInput.bs
git commit -m "engine: per-remote held tracking, one GameInput construction path for remote events"
```

---

### Task 5: Docs — `controller-input.md` multi-remote/analog section

**Files:**
- Modify: `docs/controller-input.md`

- [ ] **Step 1: Update the "Multiple controllers" section**

Replace the opening two sentences of that section:

```markdown
## Multiple controllers

Each connected browser is assigned its own `playerIndex` (0, 1, 2, ...)
in the order it connects. Pass `playerIndex` to `bindAction`/`bindAxis`
to say which controller a binding listens to; a single-player game can
ignore it entirely (it defaults to 0).
```

with:

```markdown
## Multiple controllers

`playerIndex` (0, 1, 2, ...) is shared across every input source - a
physical Roku remote, a brs-engine simulator gamepad, and a connected
browser all draw from the same pool, assigned in the order each first
sends input. A single-player game can ignore `playerIndex` entirely (it
defaults to 0, which the first remote/controller used always gets).
Pass `playerIndex` to `bindAction`/`bindAxis` to say which player's
input a binding listens to:
```

(the existing code sample and the rest of the section - "Reading an action or axis never takes a `playerIndex`..." - stays as-is).

Add a new subsection right after it, before "## Labels and the raw custom payload":

```markdown
## Simulator analog sticks

The brs-engine simulator (not real Roku hardware) can report a connected
game controller's analog stick, if the consuming app's own manifest sets
`multi_controllers=1`:

```
#Channel Options
multi_controllers=1
```

With that flag set, `bindAxis`'s `getAxis()` picks up a bound player's
analog stick automatically - no code change needed beyond the manifest
flag - falling back to the remote d-pad exactly as before when no analog
data is available (real hardware, or the flag left unset). This is an
**experimental**, simulator-only capability with no real-Roku equivalent;
a real device always uses the digital d-pad path.
```

- [ ] **Step 2: Commit**

```bash
git add docs/controller-input.md
git commit -m "docs: multi-remote playerIndex sharing + simulator analog stick support"
```

---

### Task 6: Example manifests — opt in to `multi_controllers=1`

**Files:**
- Modify: `examples/*/src/manifest` (all 18: `3d`, `asteroids`, `audio`, `breakout`, `canvas`, `controller`, `depthsort`, `http`, `hybrid`, `parallax`, `particles`, `pixels`, `platformer`, `pong`, `quickstart`, `rendererTest`, `scenegraph`, `snake`, `terrain`, `tweens`, `ui`)
- Modify: `scripts/exampleTemplate/manifest` (so `npm run create-example` scaffolds new examples with this already set)

- [ ] **Step 1: Add the flag to every example manifest**

For each `examples/<name>/src/manifest` (and `scripts/exampleTemplate/manifest`), add `multi_controllers=1` under the existing `#Channel Options` section, e.g. in `examples/controller/src/manifest`:

```
#Channel Options
confirm_partner_button=1
game=1
run_as_process=1
ui_resolutions=HD
multi_controllers=1
```

This can be scripted rather than hand-edited 19 times - a one-off Node script (not committed, run once from the repo root):

```javascript
const fs = require('fs');
const path = require('path');
const targets = fs.readdirSync('examples').map(name => path.join('examples', name, 'src', 'manifest'))
  .concat([path.join('scripts', 'exampleTemplate', 'manifest')])
  .filter(p => fs.existsSync(p));
for (const p of targets) {
  const content = fs.readFileSync(p, 'utf8');
  if (!content.includes('multi_controllers')) {
    fs.writeFileSync(p, content.trimEnd() + '\nmulti_controllers=1\n');
  }
}
console.log(targets.length, 'manifests updated');
```

Run it with `node -e "<script above>"` from the repo root, then delete/discard the script (it's not part of the codebase).

- [ ] **Step 2: Verify every manifest parses correctly**

Run: `npm run validate-examples`
Expected: PASS for every example (manifest syntax is a flat `key=value` file; an unrecognized key doesn't fail validation, but confirm no example's build broke).

- [ ] **Step 3: Commit**

```bash
git add examples/*/src/manifest scripts/exampleTemplate/manifest
git commit -m "examples: opt in to multi_controllers=1 (brs-engine PR #1226)"
```

---

### Task 7: `examples/controller` — demonstrate a second physical remote/gamepad

**Files:**
- Modify: `examples/controller/src/source/main.bs` (or wherever it currently binds actions/axes - read the file first; per the existing doc comment at the top: "Player 1 (playerIndex 0): remote OK or controller button "ok" fires... Player 2 (playerIndex 1): a second connected browser")

**Interfaces:**
- Consumes: everything from Tasks 1-4 (playerIndex now shared across all sources).

- [ ] **Step 1: Read the current example**

Read `examples/controller/src/source/main.bs` in full to see its exact existing `bindAction`/`bindAxis` calls and on-screen labels before changing anything.

- [ ] **Step 2: Add a binding demonstrating a second physical remote**

Add one clearly-labeled action bound to `playerIndex = 1` with only a `remoteButton` (no `controllerButton`), so a second physical remote or simulator gamepad pressing that button is distinguishable on-screen from player 0's remote and from a browser controller. Update the on-screen instructions/label text to mention "a second paired remote or simulator gamepad" as an alternative to "a second browser."

- [ ] **Step 3: Build**

Run: `npm run build && cd examples/controller && npm run build`
Expected: builds cleanly.

- [ ] **Step 4: Manual on-device/simulator verification**

Using the `rokubot-examples` skill, sideload and run `examples/controller`. Verify:
- The existing single-remote/single-browser flow still works exactly as before (regression check).
- If a second remote or a simulator gamepad is available, confirm it drives the new `playerIndex = 1` binding independently of player 0's remote.

This is manual/on-device only per CLAUDE.md ("Automated Rooibos tests do not exercise example apps' own entity/room code at all") - do not skip it even if `npm run check`/`npm run validate-examples` pass cleanly.

- [ ] **Step 5: Commit**

```bash
git add examples/controller/src/source/main.bs
git commit -m "examples/controller: demonstrate a second physical remote/gamepad"
```

---

## Self-Review Notes

- **Spec coverage:** Section A → Task 1. Section B (GameInput construction path, per-remote held tracking) → Task 4. Section C (ControlMap matching) → Task 3. Section D (analog axis) → Tasks 2-3. Section E (manifest/capability) → Task 6. Testing section → each task's own spec updates plus Task 7's manual pass. File-level summary → matches Tasks 1-7's file lists exactly.
- **Placeholder scan:** no TBD/TODO; every step has literal code, not a description of code.
- **Type consistency:** `assignPlayerIndexForRemoteId`, `setRemoteEvent`, `getRemoteAnalogStick`, `setRemoteDpad(playerIndex, x, y)`, `getRemoteDpad(playerIndex)`, `gameInputForRemoteMsg`, `remoteHeldGameInputs` are spelled identically everywhere they're introduced and consumed across Tasks 1-4.
- **Task ordering:** Tasks 1-2 (ControllerRegistry) must land before Task 3 (ControlMap, whose tests call the new registry methods) and Task 4 (Game.bs, which calls both). Task 4 must land before Task 7 (the example depends on the new per-remote behavior existing). Task 6 (manifests) is independent and can happen anytime, but Task 7's manual verification is more meaningful once Task 6 has enabled `multi_controllers` for that example.
