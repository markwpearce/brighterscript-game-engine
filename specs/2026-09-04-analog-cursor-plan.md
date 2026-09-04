# Analog-Stick Cursor Movement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a connected controller's analog stick drive `BGE.UI`'s pointer-mode virtual cursor continuously, alongside the existing d-pad press/held stepping.

**Architecture:** `FocusManager` gains an opt-in `analogAxisName`/`cursorAnalogSpeed` pair and a new `updateAnalogCursor(controls, dt)` method, called once per frame (not per input event, unlike `update()`) from `Game.processUiInput()`. Zero behavior/perf change unless a game explicitly sets `analogAxisName` and has bound that axis via `Game.controls.bindAxis()`. Also scaffolds `examples/ui`, the shared demo example for this and the three sibling plans.

**Tech Stack:** BrighterScript, Rooibos (`rooibos-roku`), `BGE.Controller.ControlMap` (issue #149, already shipped).

**Spec:** `specs/2026-09-04-ui-followups-design.md` (section 1) — read it before starting; it also documents why this touches `FocusManager`/`Game.bs` at all, and the prior-art files (`FocusManager.bs`, `ControlMap.bs`) this plan builds on.

## Global Constraints

- One `@suite` class per `*.spec.bs` file (Rooibos v6 corrupts multi-suite files — CLAUDE.md).
- `assertEqual` is type-strict (Integer vs Float) — check actual/expected types in a failing diff rather than guessing.
- Every file that references another file's class/const/function must `import` it explicitly, even within `source` scope (CLAUDE.md's SceneGraph-scope-visibility gotcha).
- Run `npm run validate` after any engine change; `npm run check` before considering a task done.
- New/changed public methods get JSDoc-style `'` doc comments (`@param`/`@return`), written for the widget-consuming game developer, not the engine maintainer.

---

### Task 1: Scaffold `examples/ui`

**Files:**
- Create: `examples/ui/` (via `create-example` script, then hand-edit)
- Modify: `.vscode/tasks.json` (auto-registered by the script)

**Interfaces:**
- Produces: `examples/ui/src/source/Rooms/MainRoom.bs` — a `BGE.Room` subclass this and the other three plans each add a demo Room alongside, and `examples/ui/src/source/main.bs` wiring `game.defineRoom()`/`game.changeRoom()` for each.

- [ ] **Step 1: Scaffold the example**

Run: `npm run create-example -- ui "UI Widgets"`

This generates `examples/ui/` from `scripts/exampleTemplate` (manifest, `bsconfig.json`, icon/splash images, a minimal `MainRoom`) and registers it in the root `.vscode/tasks.json` example picker.

- [ ] **Step 2: Wire `Game.enableStandardDebugUi()` and a room-switcher pattern**

Edit `examples/ui/src/source/main.bs` so `MainRoom` is the entry point and shows a short on-screen hint ("Press OK on a room name to view that demo") — the actual per-feature rooms (`AnalogCursorRoom`, `NinePatchRoom`, `PopupSelectRoom`, `TextInputRoom`) are added by this and the three sibling plans, one per plan, each registered via `game.defineRoom("<name>", function(g) as BGE.Room ... end function)` and reachable from `MainRoom` (a `BGE.UI.Select` or list of `Button`s, one per demo room, is the natural fit — build it with plain `Button`s for now since `NinePatchRoom`'s reusable backgrounds don't exist yet).

Keep `MainRoom` itself minimal in this task — just enough structure (a `BGE.UI.UiContainer` with one `Button` per known room name) for later plans to append their own entry without restructuring it.

- [ ] **Step 3: Sideload and confirm it launches**

Follow the `rokubot-examples` skill: sideload `examples/ui`, launch it, screenshot `MainRoom`. Confirm no crash and the hint text/buttons render. (Per CLAUDE.md, Rooibos doesn't cover example-level runtime behavior — this on-device check is mandatory, not optional.)

- [ ] **Step 4: Commit**

```bash
git add examples/ui .vscode/tasks.json
git commit -m "chore: scaffold examples/ui demo example"
```

---

### Task 2: `FocusManager.updateAnalogCursor()` — no movement yet, just wiring + deadzone

**Files:**
- Modify: `src/source/engine/ui/FocusManager.bs`
- Modify: `src/source/engine/Game.bs` (`processUiInput`, around `Game.bs:1166-1169`)
- Test: `src/source/engine/ui/FocusManager.spec.bs`

**Interfaces:**
- Consumes: `BGE.Controller.ControlMap.hasBindings() as boolean`, `BGE.Controller.ControlMap.getAxis(name as string) as BGE.Math.Vector` (both already exist, `src/source/engine/controller/ControlMap.bs`), `Game.getDeltaTime() as float` (already exists), `FocusManager.navigationMode` (already exists).
- Produces: `FocusManager.analogAxisName as string = invalid`, `FocusManager.cursorAnalogSpeed as float = 400.0`, `FocusManager.updateAnalogCursor(controls as BGE.Controller.ControlMap, dt as float) as void` — used by Task 3 (actual movement) and by `Game.processUiInput()`.

- [ ] **Step 1: Write the failing test — no-op when unconfigured**

Add to `src/source/engine/ui/FocusManager.spec.bs` (existing suite class — check the file first and add methods to it, do NOT create a second `@suite` class in this file):

```brightscript
@it("updateAnalogCursor does nothing when analogAxisName is unset")
function _()
  fm = new BGE.UI.FocusManager(m.game)
  fm.navigationMode = BGE.UI.FocusNavigationMode.pointer
  startX = fm.cursorPosition.x
  controls = new BGE.Controller.ControlMap(new BGE.Controller.ControllerRegistry())
  fm.updateAnalogCursor(controls, 1.0)
  m.assertEqual(startX, fm.cursorPosition.x)
end function
```

(Add the matching `import` for `BGE.Controller.ControlMap`/`ControllerRegistry` at the top of the spec file if not already present.)

- [ ] **Step 2: Run test to verify it fails**

Run: `npm run build-tests && npm run test:ci`
Expected: FAIL — `updateAnalogCursor` is not a member of roAssociativeArray (method doesn't exist yet).

- [ ] **Step 3: Implement the method (no-op branch only)**

In `src/source/engine/ui/FocusManager.bs`, add fields near `cursorStep`:

```brightscript
' Opt-in: name of a BGE.Controller.ControlMap axis (bound via
' ControlMap.bindAxis()) that continuously drives cursorPosition in pointer
' mode, alongside the existing d-pad press/held stepping. invalid (the
' default) means no analog input drives the cursor at all - zero behavior
' change. See updateAnalogCursor().
analogAxisName as string = invalid
' Pixels/second the cursor moves at full stick deflection (magnitude 1.0).
cursorAnalogSpeed as float = 400.0
```

And the method, after `navigatePointer`:

```brightscript
' Continuously moves cursorPosition from a bound analog stick axis, then
' re-runs hit-testing - unlike update(), called every frame regardless of
' whether a d-pad event fired this frame (see Game.processUiInput()), since
' analog movement can't wait for a discrete input event. No-op unless
' navigationMode is pointer, analogAxisName is set, and controls has at
' least one binding - zero cost for a game that doesn't use this.
'
' @param {BGE.Controller.ControlMap} controls - Game.controls
' @param {float} dt - Game.getDeltaTime()
' @return {void}
sub updateAnalogCursor(controls as BGE.Controller.ControlMap, dt as float)
  if m.navigationMode <> BGE.UI.FocusNavigationMode.pointer or m.analogAxisName = invalid or not controls.hasBindings()
    return
  end if
  ' movement logic added in Task 3
end sub
```

Add `import "../controller/ControlMap.bs"` to `FocusManager.bs`'s imports.

- [ ] **Step 4: Run test to verify it passes**

Run: `npm run build-tests && npm run test:ci`
Expected: PASS

- [ ] **Step 5: Wire the per-frame call into Game.bs**

In `src/source/engine/Game.bs`, `processUiInput` (around line 1166):

```brightscript
private sub processUiInput(universalControlEvents as roUniversalControlEvent[], musicMsg as roAudioPlayerEvent, ecpMsg as roInputEvent, urlMsg as roUrlEvent)
  m.processUiUpdate(m.gameUi, universalControlEvents, musicMsg, ecpMsg, urlMsg)
  m.processFocusManagerInput(universalControlEvents)
  m.focusManager.updateAnalogCursor(m.controls, m.dt)
end sub
```

- [ ] **Step 6: Validate and run the full test suite**

Run: `npm run validate && npm run test:ci`
Expected: both PASS (no other spec touches `processUiInput` directly, so this should be a clean addition)

- [ ] **Step 7: Commit**

```bash
git add src/source/engine/ui/FocusManager.bs src/source/engine/ui/FocusManager.spec.bs src/source/engine/Game.bs
git commit -m "feat: wire FocusManager.updateAnalogCursor() into the per-frame UI input pass"
```

---

### Task 3: Actual analog movement + deadzone

**Files:**
- Modify: `src/source/engine/ui/FocusManager.bs`
- Test: `src/source/engine/ui/FocusManager.spec.bs`

**Interfaces:**
- Consumes: `BGE.Math.Vector` (`.x`/`.y` fields), `BGE.Math.VectorOps` (check `src/source/math/vector.bs` for an existing magnitude/length helper before writing a new one — reuse it if present).
- Produces: working `updateAnalogCursor()` — moves `cursorPosition` and re-hit-tests via the existing private `updateHoverAndFocus()`.

- [ ] **Step 1: Check for an existing vector-magnitude helper**

Run: `grep -n "function.*[Ll]ength\|function.*[Mm]agnitude" src/source/math/vector.bs`

Use whatever's found (e.g. `BGE.Math.VectorOps.length(v)`); if nothing exists, compute magnitude inline (`Sqr(axis.x^2 + axis.y^2)`) rather than adding a new shared helper for one caller.

- [ ] **Step 2: Write the failing test — moves proportionally to axis and dt**

```brightscript
@it("updateAnalogCursor moves cursorPosition proportionally to axis magnitude and dt")
function _()
  registry = new BGE.Controller.ControllerRegistry()
  controls = new BGE.Controller.ControlMap(registry)
  controls.bindAxis("cursor", "1", 0)
  registry.assignPlayerIndex() ' player 0
  registry.updateFromMessage(0, {}, {"1": {x: 1.0, y: 0.0}}, {})

  fm = new BGE.UI.FocusManager(m.game)
  fm.navigationMode = BGE.UI.FocusNavigationMode.pointer
  fm.analogAxisName = "cursor"
  fm.cursorAnalogSpeed = 100.0
  startX = fm.cursorPosition.x

  fm.updateAnalogCursor(controls, 0.5) ' half a second

  m.assertEqual(startX + 50.0, fm.cursorPosition.x) ' 100px/s * 0.5s
end function

@it("updateAnalogCursor ignores axis input below the deadzone")
function _()
  registry = new BGE.Controller.ControllerRegistry()
  controls = new BGE.Controller.ControlMap(registry)
  controls.bindAxis("cursor", "1", 0)
  registry.assignPlayerIndex()
  registry.updateFromMessage(0, {}, {"1": {x: 0.05, y: 0.0}}, {}) ' below 0.15 deadzone

  fm = new BGE.UI.FocusManager(m.game)
  fm.navigationMode = BGE.UI.FocusNavigationMode.pointer
  fm.analogAxisName = "cursor"
  startX = fm.cursorPosition.x

  fm.updateAnalogCursor(controls, 1.0)

  m.assertEqual(startX, fm.cursorPosition.x)
end function
```

Check `ControllerRegistry.updateFromMessage`'s exact signature/stick-payload shape first (`src/source/engine/controller/ControllerRegistry.bs:51` and its own spec) and adjust the test's `sticks` argument shape to match exactly — do not guess the field names.

- [ ] **Step 3: Run tests to verify they fail**

Run: `npm run build-tests && npm run test:ci`
Expected: FAIL (no movement implemented yet)

- [ ] **Step 4: Implement movement**

```brightscript
sub updateAnalogCursor(controls as BGE.Controller.ControlMap, dt as float)
  if m.navigationMode <> BGE.UI.FocusNavigationMode.pointer or m.analogAxisName = invalid or not controls.hasBindings()
    return
  end if

  axis = controls.getAxis(m.analogAxisName)
  magnitude = Sqr(axis.x * axis.x + axis.y * axis.y)
  if magnitude < 0.15 ' deadzone - see design doc section 1
    return
  end if

  m.cursorPosition.x += axis.x * m.cursorAnalogSpeed * dt
  m.cursorPosition.y -= axis.y * m.cursorAnalogSpeed * dt ' axis.y is world-space (+up); cursor space is screen-space (+down), matching navigatePointer()
  m.updateHoverAndFocus()
end sub
```

If `updateHoverAndFocus` is `private`, change it to `protected` (or drop `private` entirely, matching the file's existing mix) only if this call site needs wider visibility than `private` allows within the same class — it doesn't, since this is a same-class call; leave its visibility unchanged.

- [ ] **Step 5: Run tests to verify they pass**

Run: `npm run build-tests && npm run test:ci`
Expected: PASS

- [ ] **Step 6: Validate**

Run: `npm run validate`

- [ ] **Step 7: Commit**

```bash
git add src/source/engine/ui/FocusManager.bs src/source/engine/ui/FocusManager.spec.bs
git commit -m "feat: analog stick continuously drives the pointer-mode UI cursor"
```

---

### Task 4: `examples/ui` demo room + on-device verification

**Files:**
- Create: `examples/ui/src/source/Rooms/AnalogCursorRoom.bs` (via `npm run create-room -- ui AnalogCursorRoom`)
- Modify: `examples/ui/src/source/main.bs` (register the room, add a `Button` to `MainRoom` linking to it)

**Interfaces:**
- Consumes: `Game.focusManager.navigationMode`, `.analogAxisName`, `.cursorAnalogSpeed`; `Game.enableControllerInput()`, `Game.controls.bindAxis()`.

- [ ] **Step 1: Scaffold the room**

Run: `npm run create-room -- ui AnalogCursorRoom`

- [ ] **Step 2: Build the demo**

In `AnalogCursorRoom.bs`'s `onCreate()`: call `m.game.enableControllerInput()`, `m.game.controls.bindAxis("cursor", "1", 0)`, set `m.game.focusManager.navigationMode = BGE.UI.FocusNavigationMode.pointer`, `m.game.focusManager.analogAxisName = "cursor"`. Add 3-4 `BGE.UI.Button`s to `m.game.gameUi` spread around the screen (title-safe, per the 10%-in-from-edge convention) so the cursor's movement/hit-testing is visually obvious. Add on-screen hint text ("Connect a controller at examples/controller's QR code / this room's own instructions") and a Back-button `onInput` handler (guarded with `input.press`, per CLAUDE.md's press/held double-fire gotcha) returning to `MainRoom`.

- [ ] **Step 3: Register in main.bs**

Add `game.defineRoom("AnalogCursorRoom", function(g) as BGE.Room return new AnalogCursorRoom(g) end function)` and a `Button` in `MainRoom` that calls `game.changeRoom("AnalogCursorRoom")`.

- [ ] **Step 4: Sideload and verify with a real/simulated controller connection**

Per the `rokubot-examples` skill: sideload, launch, navigate to `AnalogCursorRoom`. Since `rokubot` can't drive a physical analog stick, verify d-pad cursor movement still works unchanged (regression check) and confirm the room doesn't crash with `enableControllerInput()`/`bindAxis()` active with no controller connected (the zero-controller-connected path must be silent, not an error). If a real controller/browser client is available, manually confirm analog movement — otherwise note in the PR description that analog-input-specific verification is manual/pending a connected client, per the `feedback_no_realtime_game_play` convention (ask the user to test and report back rather than trying to simulate real-time stick input via rokubot).

- [ ] **Step 5: Commit**

```bash
git add examples/ui
git commit -m "feat: add AnalogCursorRoom demo to examples/ui"
```

---

### Task 5: Docs + issue close-out

**Files:**
- Modify: `docs/engine-internals.md` (confirm this is where `BGE.UI`/`FocusManager` internals are documented; if it's `docs/game-engine-overview.md` instead, edit that file)
- Modify: `CLAUDE.md`'s UI section (one sentence noting `updateAnalogCursor()`'s per-frame-not-per-event call pattern, alongside the existing `FocusManager.update()` description)

- [ ] **Step 1: Add a short doc section**

Cover: `analogAxisName`/`cursorAnalogSpeed` fields, that it composes with `Game.controls.bindAxis()`, and the deadzone constant (0.15) with a note that it's local to `FocusManager`, not `ControlMap` (per design doc section 1 — other axis consumers aren't deadzoned by this).

- [ ] **Step 2: Update CLAUDE.md**

Add one sentence to the `FocusNavigationMode`/`pointer` paragraph in CLAUDE.md's UI section (find it via `grep -n "navigationMode" CLAUDE.md`) noting `updateAnalogCursor()` exists and runs every frame via `Game.processUiInput()`, unlike `update()`'s per-event cadence.

- [ ] **Step 3: Run npm run docs to confirm it builds cleanly**

Run: `npm run docs`
Expected: no errors; skim `docs-site/` locally if unsure (do not commit `docs-site/` — gitignored).

- [ ] **Step 4: Final full check**

Run: `npm run check`
Expected: PASS (lint + validate + headless tests)

- [ ] **Step 5: Commit and open the PR**

```bash
git add docs/ CLAUDE.md
git commit -m "docs: document analog-stick UI cursor movement"
```

Push the branch and open a PR closing #182 (`gh pr create --body "Closes #182"`, following the `feedback_no_direct_main_push` convention — never push directly to `main`).
