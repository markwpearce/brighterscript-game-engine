# Unified multi-controller input (issue #216)

## Goal

Roku remotes, brs-engine simulator gamepads, and browser/websocket controllers
(issue #149) currently reach game code through different code paths with
different identity conventions. Unify all three behind the identity/mapping
layer that already exists for browser controllers (`GameInput.playerIndex`,
`BGE.Controller.ControlMap`/`ControllerRegistry`), so a game written against
`ControlMap` (or raw `onInput`) works the same regardless of how many of each
input source are connected.

Concretely, per the issue: "we use the exact same code in the Game,
controlMap, etc." for (1) Roku remotes, (2) websocket/browser controllers,
(3) simulator game controllers (brs-engine's `multi_controllers` manifest
flag, [PR #1226](https://github.com/lvcabral/brs-engine/pull/1226)).

## Non-goals

- A new `onControl`/`onControls`-style entity lifecycle hook. `onInput`
  already delivers `GameInput`; `onControls(controlMap)` (action-based) already
  exists (`GameEntity.onControls`). Neither needs to change shape — only
  `GameInput.playerIndex`'s correctness for remote-sourced events changes.
- Any change to real-Roku hardware capability. `GetValue()` (analog axis
  read) is simulator-only; real hardware silently gets brs-engine's own
  digital 1.0/0.0 fallback through the same call, so no hardware-vs-simulator
  branching is needed in engine code.
- Visual controller-remapping UI, QR discovery — unrelated, already tracked
  elsewhere.

## Background: the two APIs this unifies against

- `roUniversalControlEvent.GetRemoteID() as String` (pre-existing, not new in
  #1226) returns `"<RemoteType>:<RemoteIndex>"` (e.g. `"30:1"`) and already
  distinguishes multiple physical remotes/gamepads, on real hardware and in
  the simulator alike.
- `roUniversalControlEvent.GetValue(axis as Integer) as Float` (new in #1226,
  simulator-only) returns a live analog value read off a continuously-updated
  shared-array slot at *call time* — not something delivered by a new
  message-port event. A stick held at a nonzero deflection with no digital
  button change produces **no** new `roUniversalControlEvent`, so reading it
  every frame requires holding onto the *last-received* event object for that
  remote and re-calling `GetValue()` on it each frame. Gate any call behind
  `roRemoteInfo.HasFeature("multi_controllers", index)` (unconditional
  capability flag) and the consuming app's own `multi_controllers=1` manifest
  entry.

## A. Unified player-index assignment

`BGE.Controller.ControllerRegistry` gains remote-ID-based assignment,
sharing the same lowest-free-index pool `assignPlayerIndex()` already hands
out to browser/websocket connections — one number space for every source:

```
assignPlayerIndexForRemoteId(remoteId as string) as integer
```

Looks up a previously-assigned index for this `remoteId` (kept in a new
`remoteId -> playerIndex` map, lazily populated, never released — physical
remotes have no disconnect signal to key off), or assigns+records the next
free index the same way `assignPlayerIndex()` does today. First remote/gamepad
seen this run gets index 0 (matching today's single-remote games that default
`bindAction(..., playerIndex=0)` with no code changes), a second physical
remote gets 1, and so on; a browser controller connecting after that gets
whatever the next free index is — same shared pool, source-agnostic.

`GameInput.playerIndex`'s doc comment and default change: **the `-1` sentinel
for "the physical remote" goes away.** Every remote-sourced `GameInput` now
carries a real assigned index like a browser controller. This is a breaking
change to `playerIndex`'s meaning; grepping `examples/` confirms no existing
example branches on `-1`, so the actual blast radius is contained to
`ControlMap.onInput()`'s internal matching logic (below) and this doc.

## B. One GameInput construction path for remote events

Today `Game.bs` has ~8 separate call sites doing
`new GameInput(msg.GetInt(), heldTimeMs)` for remote press/release events,
plus a second, textually-duplicated pattern of `new GameInput(1000 +
m.buttonHeld, m.buttonHeldTimeMs)` for synthesizing a held/repeat event off a
**single global** `m.buttonHeld`/`m.buttonHeldTimer` pair — which only ever
tracks one remote's held button at a time, silently wrong the moment two
remotes are held simultaneously.

Replace both with:

- A single private helper, e.g. `gameInputForRemoteEvent(msg as
  roUniversalControlEvent) as GameInput`, that resolves `playerIndex` via
  `m.controllerRegistry.assignPlayerIndexForRemoteId(msg.GetRemoteID())` and
  constructs the `GameInput` — the one place remote-event GameInputs get
  built, used at every call site instead of each duplicating the resolution.
- Per-remote held-button tracking, replacing the single `m.buttonHeld`/
  `m.buttonHeldTimer`/`m.buttonHeldTimeMs` fields with a small
  `remoteId -> {buttonCode, timer, heldTimeMs}` map on `Game` (mirroring the
  per-player `heldTimers` pattern `ControllerRegistry` already uses for
  browser controllers), and a second helper that synthesizes the held
  `GameInput` per tracked remote. Two remotes each holding a different button
  now both repeat correctly instead of one clobbering the other's state.
- Each per-frame call site that currently loops `universalControlEvents` and
  separately checks `m.buttonHeld <> -1` (the main loop's `ControlMap`
  feed, `processEntityOnInput`, `processFocusManagerInput`) switches to
  looping these two helpers' output instead — no behavioral branching left
  that assumes a single remote.
- `processEntityOnInput`'s `onECPKeyboard` dispatch still needs the raw
  `msg.GetChar()`/`msg.GetInt()` off the original event — this stays keyed
  off the original `universalControlEvents` loop (unchanged), only the
  `GameInput` construction inside that same loop is deduplicated through the
  new helper.

## C. `ControlMap` matching, unified

`ControlMap.onInput()`'s current special case —

```brighterscript
matchesRemote = binding.remoteButton <> invalid and input.playerIndex = -1 and input.isButton(binding.remoteButton)
matchesController = binding.controllerButton <> invalid and input.playerIndex = binding.playerIndex and input.button = binding.controllerButton
```

— hardcodes `-1` for "this is a remote." Once remotes carry real indices,
this becomes one shape: match `binding.remoteButton` when
`input.playerIndex = binding.playerIndex and input.isButton(binding.remoteButton)`,
i.e. structurally identical to the controller-button branch, just checked
against a button name with alias resolution (`isButton`) instead of an exact
string. `bindAction`'s existing default `playerIndex = 0` keeps today's
single-player games working unchanged (index 0 is still whichever
remote/controller connects first).

## D. Analog axis, folded into `getAxis()`

`ControllerRegistry` gains a cached last-seen `roUniversalControlEvent` per
remote ID (updated whenever `Game` receives one for that remote — see B),
plus:

```
getRemoteAnalogStick(remoteId as string) as BGE.Math.Vector
```

Reads `GetValue(axisX)`/`GetValue(axisY)` off the cached event for that
remote, returning `{0,0}` if no event cached yet or the engine build doesn't
report `multi_controllers` support (checked once via `roRemoteInfo.HasFeature`,
cached on `Game` at startup — avoids a native call every frame).

`ControlMap.getAxis()` extends its existing fallback chain — browser
controller stick, else remote d-pad — to check the bound player's remote
analog stick in between: browser-controller stick (if bound and non-neutral)
→ remote analog stick (if this player index is a remote and multi_controllers
data is available and non-neutral) → digital remote d-pad. Same
richest-input-wins pattern already in place, one more link in the chain.

## E. Manifest / capability

No engine-side manifest changes — `multi_controllers=1` is a *consuming app's*
manifest flag (like `multi_key_events`), documented, not forced. The engine
calls `roRemoteInfo.HasFeature` and no-ops gracefully when it's absent,
including on real hardware and in a simulator run without the flag set. The
`examples/controller` example (already demonstrates multi-player
`bindAction`) gets this flag added to its manifest plus a short
`docs/controller-input.md` note (existing guide, if present, else add one)
covering: multiple physical remotes now assign distinct player indices
automatically, and analog stick support requires `multi_controllers=1`.

## Testing

- `ControllerRegistry.spec.bs`: new coverage for
  `assignPlayerIndexForRemoteId` (same ID reuses its index, different IDs get
  distinct indices, shared pool with `assignPlayerIndex()`), and
  `getRemoteAnalogStick` against a fake event double.
- `ControlMap.spec.bs`: update the remote-matching tests to use a real
  assigned index instead of the `-1` sentinel; add a two-remote scenario
  (two distinct `playerIndex`es both bound to `bindAction(..., playerIndex=N)`
  fire independently).
- Manual/device: extend `examples/controller` to sanity-check with two
  physical remotes or one remote + one simulator gamepad via the
  `rokubot-examples` workflow (per CLAUDE.md, automated tests don't exercise
  example runtime behavior) — held/repeat on two simultaneously-held buttons
  is the case most likely to regress silently.

## File-level summary of changes

```
src/source/engine/GameInput.bs             ' playerIndex doc comment update only
src/source/engine/Game.bs                  ' per-remote held tracking, one GameInput-construction helper,
                                            ' replaces m.buttonHeld/m.buttonHeldTimer/m.buttonHeldTimeMs
src/source/engine/controller/ControllerRegistry.bs  ' assignPlayerIndexForRemoteId, cached last-event-per-remote,
                                                     ' getRemoteAnalogStick
src/source/engine/controller/ControlMap.bs          ' onInput() matching unified, getAxis() analog fallback
examples/controller/                        ' manifest multi_controllers=1, doc update
docs/controller-input.md                    ' note on multi-remote + analog (new or amended)
```
