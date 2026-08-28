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
game.controls.bindAction("jump", "ok", 0)   ' name, remoteButton, controllerButton
game.controls.bindAxis("move")

' per frame, e.g. in onUpdate/onInput:
if game.controls.isActionPressed("jump") then ...
move = game.controls.getAxis("move")   ' a BGE.Math.Vector
velocity.x = move.x * speed
velocity.y = move.y * speed
```

`isActionPressed`/`isActionReleased` read true only on the frame the bound
button was pressed/released, and `isActionHeld` every frame in between, so
they are best read once per frame from `onUpdate` rather than from `onInput`
(which fires once per input event).

`bindAxis`'s axis falls back to the remote d-pad whenever the bound
controller stick reads neutral, so binding once supports both input
sources automatically.

## Multiple controllers

Each connected browser is assigned its own `playerIndex` (0, 1, 2, ...)
in the order it connects. Pass `playerIndex` to `bindAction`/`bindAxis`
to say which controller a binding listens to; a single-player game can
ignore it entirely (it defaults to 0).

```brighterscript
game.controls.bindAction("p2fire", invalid, 0, 1)   ' player 1's button 0
game.controls.bindAxis("p2move", 1, 1)              ' player 1's stick 1

if game.controls.isActionPressed("p2fire") then ...
```

Reading an action or axis never takes a `playerIndex` - each name is bound
to one player at bind time, so `isActionPressed("p2fire")`/`getAxis("p2move")`
already know which controller they refer to. Give each player's actions
their own names.

## Advanced: raw controller input

Every controller button press also flows through the normal `onInput`
callback as a `BGE.GameInput`, with `playerIndex` set and
`button = "controller" + <index>` (matching the browser Gamepad API's
`buttons[]` order). Most games won't need this - `ControlMap` above is
the intended way to consume controller input.

## Limitations

- The controller page loads a small library from a public CDN - the
  *player's phone* needs internet access for the on-screen sticks to
  render (the Roku itself needs none).
- Discovery is a plain LAN URL for now; a QR code is tracked separately.

See `examples/controller` for a full runnable demo.
