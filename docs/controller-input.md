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

`bindAxis`'s axis falls back to the remote d-pad whenever the bound
controller stick reads neutral, so binding once supports both input
sources automatically.

## Multiple controllers

Each connected browser is assigned its own `playerIndex` (0, 1, 2, ...)
in the order it connects. Pass `playerIndex` to `bindAction`/`bindAxis`
and to the `isAction*`/`getAxis` calls that read them for local
multiplayer; a single-player game can ignore it entirely (it defaults to 0).

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
