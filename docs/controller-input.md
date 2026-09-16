---
title: Controller Input
group: Guides
order: 6
---

# Controller Input

A phone or tablet's browser can act as a twin-stick controller for your
channel - no app install, no SceneGraph, no second computer. The Roku
itself hosts a small web page; a player opens it in their browser over the
local network.

## Enabling it

```brighterscript
game.enableControllerInput()   ' starts the server on port 8888
```

Show the connection URL somewhere in your UI so a player knows what to
open:

```brighterscript
label.setText(game.getControllerConnectionInfo())
```

## Mapping input

`game.controls` (a `BGE.Controller.ControlMap`) is the only concept you
need: bind a logical action/axis name once, then read it every frame -
your game code never has to know whether the remote or a connected
controller produced the input.

```brighterscript
game.controls.bindAction("jump", "ok", "ok")   ' name, remoteButton, controllerButton
game.controls.bindAxis("move")                 ' defaults to the controller's stick "1"
```

`controllerButton`/the stick name are whatever the browser page sends - the built-in
page's two on-screen buttons send `"ok"`/`"b"` (not their on-screen "A"/"B" labels) and
its two sticks send `"1"`/`"2"`, but a custom page can send any name it likes (e.g.
`"reload"`) and bind to it with no engine change. A real gamepad plugged into the
built-in page is a separate case - see "Simulator/physical gamepad buttons" below.

The recommended way to read bound state each frame is `onControls()`, a
`GameEntity` lifecycle hook called once per frame with the game's
`ControlMap` (the same object as `m.game.controls`):

```brighterscript
override sub onControls(controls as BGE.Controller.ControlMap)
  if controls.isActionPressed("jump") then ...
  move = controls.getAxis("move")   ' a BGE.Math.Vector
  m.velocity.x = move.x * speed
  m.velocity.y = move.y * speed
end sub
```

`onControls()` is only called on a frame where the game has bound at least
one action/axis (`ControlMap.hasBindings()`) - a game that never calls
`bindAction`/`bindAxis` never gets this callback at all, keeping the
zero-cost-when-unused guarantee. `isActionPressed`/`isActionReleased` read
true only on the frame the bound button was pressed/released, and
`isActionHeld` every frame in between.

You can still read `m.game.controls` directly from `onUpdate()` (or
anywhere else) instead, if you want different per-frame ordering or would
rather keep controller reads alongside your other update logic - the two
approaches read the exact same state, `onControls()` just saves the
`m.game.controls` boilerplate and guarantees the read happens before
`onUpdate()` runs:

```brighterscript
sub onUpdate(deltaTime as float)
  if m.game.controls.isActionPressed("jump") then ...
end sub
```

`bindAxis`'s axis falls back to the remote d-pad whenever the bound
controller stick reads neutral, so binding once supports both input
sources automatically.

## Multiple controllers

`playerIndex` (0, 1, 2, ...) is shared across every input source - a
physical Roku remote, a brs-engine simulator gamepad, and a connected
browser all draw from the same pool. By default (`shareFirstControllerWithRemote`,
see `enableControllerInput()`), the very first browser to connect *shares*
index 0 with the first physical remote/gamepad, whichever of the two shows
up first - so a single-player game can ignore `playerIndex` entirely (it
defaults to 0) and its bindings respond to the remote and a connected phone
interchangeably, with no code caring which one the player actually used.
Only a second browser (or second remote/gamepad) gets its own index,
starting from 1, in the order each one connects.

For a genuinely multiplayer game where every input source should always get
its own distinct index - including the very first browser, which would
otherwise share player 0 with the remote - pass `false`:

```brighterscript
game.enableControllerInput(8888, false)   ' port, shareFirstControllerWithRemote
```

Pass `playerIndex` to `bindAction`/`bindAxis` to say which player's input a
binding listens to:

```brighterscript
game.controls.bindAction("p2fire", invalid, "a", 1)   ' player 1's button "a"
game.controls.bindAxis("p2move", "1", 1)              ' player 1's stick "1"

if game.controls.isActionPressed("p2fire") then ...
```

Reading an action or axis never takes a `playerIndex` - each name is bound
to one player at bind time, so `isActionPressed("p2fire")`/`getAxis("p2move")`
already know which controller they refer to. Give each player's actions
their own names.

## Simulator/physical gamepad buttons

A brs-engine simulator gamepad, or a real controller paired to a Roku that
supports `multi_controllers`, arrives through the same remote-event path as
the Roku remote (not the browser-controller path above) - its face/shoulder
buttons report as `"a"`, `"b"`, `"x"`, `"y"`, `"l1"`, `"r1"`, `"l2"`, `"r2"`
(see `BGE.buttonNameFromCode`). `"a"`/`"b"` are aliased to `"ok"`/`"back"`
(the conventional gamepad meaning - A confirms, B cancels), so no extra
code is needed for a gamepad's A/B to drive menus (`BGE.UI.FocusManager`'s
click handling) or any `isButton("back")` check a room already has - and a
`bindAction("jump", "ok", ...)` binding fires for a gamepad's A press too,
with no changes.

`bindAction`'s `remoteButton`/`controllerButton` also accept an array of
names instead of one, if you want a gamepad button that has *no* built-in
alias (e.g. `"x"`) to trigger the same action as a remote button:

```brighterscript
game.controls.bindAction("jump", ["ok", "x"], "a")
```

A real gamepad plugged into the *browser* controller page is a separate,
unrelated case: it sends its raw Gamepad API button index (`"0"`, `"1"`, ...)
plus, for its two primary face buttons only, `"a"`/`"b"` (matching the names
above). Since `controllerButton` matching is exact-string, not aliased, list
`"a"`/`"b"` explicitly alongside `"ok"`/`"back"` for a gameplay `bindAction` to
respond to it - menu navigation doesn't need this, since it goes through the
aliased `isButton()` check either way.

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

## Labels and the raw custom payload

`bindAction`/`bindAxis` take an optional trailing `label` - once a browser
connects, the server sends it `{playerIndex, labels}` (its assigned player
number plus a name -> label map for every labeled binding), so a custom
controller page can render meaningful text instead of raw names:

```brighterscript
game.controls.bindAction("jump", "ok", "a", 0, "Jump")
```

A custom on-screen control that isn't button/stick shaped (a slider, a
color picker, etc.) can send an arbitrary `custom` payload in its message;
read the latest one with `getCustomPayload()`:

```brighterscript
payload = game.controls.getCustomPayload()   ' the raw object, {} if none sent yet
```

## Advanced: raw controller input

Every controller button press also flows through the normal `onInput`
callback as a `BGE.GameInput`, with `playerIndex` set and `button` equal to
the raw name the browser sent. Most games won't need this - `ControlMap`
above is the intended way to consume controller input.

## Limitations

- The controller page loads a small library from a public CDN - the
  *player's phone* needs internet access for the on-screen sticks to
  render (the Roku itself needs none).
- Discovery is a plain LAN URL - draw it as a QR code with [`BGE.QrCode`](/qr-codes) instead of/alongside text so a player can scan rather than type it:

  ![A QR code drawn next to the controller connection URL text](images/qr-code-controller-connect.jpg)

See `examples/controller` for a full runnable demo.
