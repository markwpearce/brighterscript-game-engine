# External controller input via browser bridge (issue #149)

## Goal

Let a phone/tablet browser act as a virtual gamepad (twin-stick + buttons) for a Roku channel built on this engine, without SceneGraph and without a separate server/computer. Unify controller input and remote input behind one mapping API so game code binds named actions/axes instead of caring which device produced them.

## Non-goals

- Native Roku gamepad support (impossible outside SceneGraph).
- Visual remapping UI/editor — code-level API only.
- QR-code discovery (tracked as a follow-up issue; on-screen IP:port for now).

## Architecture

```
Browser (phone)                    Roku channel
┌─────────────────┐   WebSocket    ┌──────────────────────────┐
│ index.html       │◄──────────────►│ ControllerServer          │
│ nipplejs (CDN)   │   {axes,       │  - roStreamSocket (HTTP + │
│ Gamepad API      │    buttons}    │    WS upgrade)            │
│ numbered buttons │                │  - WebSocketFrameCodec    │
└─────────────────┘                │  - per-connection state   │
                                    │    (internal only)        │
                                    └──────────┬────────────────┘
                                               │ synthesizes
                                               ▼
                                    GameInput (playerIndex added)
                                               │
                                               ▼
                                    ControlMap (game.controls)
                                    bindAction / bindAxis
                                    isActionPressed/Held/Released
                                    getAxis → Vector
                                               ▲
                                    remote GameInput (playerIndex -1)
```

Single new concept for consumers: `ControlMap`, exposed as `game.controls`. `ControllerServer`/`WebSocketFrameCodec`/`ByteUtil`/per-connection controller state are internal.

## A. Transport & protocol

`BGE.ControllerServer` (`src/source/engine/controller/ControllerServer.bs`), ported/trimmed from [roku-gamepad](https://github.com/markwpearce/roku-gamepad)'s `WebServer`:

- Keep: `roStreamSocket` listen/accept loop, HTTP GET static-file serving, RFC 6455 upgrade handshake, `WebSocketFrameCodec`/`ByteUtil` (frame encode/decode, masking, fragmentation, ping/pong) — attribute BrightWebSocket (Rolando Islas, MIT) per upstream.
- Drop: multipart upload, directory listing, POST handling — not needed for a controller bridge.
- Fix required (not present upstream): `connection.send(bytes, 0, count)` and the WebSocket frame send path must loop on `send()`'s return value until fully written — a single non-blocking `roStreamSocket.send()` call is not guaranteed to write the whole buffer, and upstream's file-serving path (and outgoing frames) assume it does.
- Runs on a `roMessagePort` polled once per frame from `Game.Play()`'s event-collection step, same pattern as the existing input/audio/URL ports. No SceneGraph, no threads.
- Protocol: one WebSocket text frame per input change, JSON `{axes: [x, y, x2, y2], buttons: [bool, ...]}` (axes/buttons arrays match the browser Gamepad API's shape/order where available).

## B. Browser client

`src/source/controller-web/index.html`, served by `ControllerServer`. Loads nipple.js from a public CDN (`cdn.jsdelivr.net`) rather than vendoring — keeps the served payload tiny, at the cost of requiring the *phone's* browser to have internet access (the Roku itself needs none; document this as a known limitation). Reads a real Gamepad via the browser Gamepad API when present, otherwise renders nipple.js twin sticks + numbered tap buttons. Sends `{axes, buttons}` over the WebSocket on change.

## C. Engine integration

- `Game.enableControllerInput(options = {})` — opt-in; starts `ControllerServer` (default port 8888) and registers its message port. Never called → zero cost. Mirrors the `enableStandardDebugUi()` pattern.
- Each WebSocket connection is assigned the lowest free player index (0, 1, 2, …) on connect, freed on disconnect.
- A `buttons[i]` transition synthesizes `GameInput` with `playerIndex` set and `button = "p<playerIndex>-controller<i>"`, flowing through the normal `onInput` callback alongside remote input (`playerIndex = -1` for the physical remote).
- Axis data updates internal per-connection state only; not event-based (doesn't fit press/held/release), read continuously through `ControlMap.getAxis`.

## D. Unified mapping API — `BGE.ControlMap` (`game.controls`)

```brighterscript
game.controls.bindAction("jump", "ok", 0)   ' name, remoteButton, controllerButton
game.controls.bindAxis("move", 1)   ' name, stick

if game.controls.isActionPressed("jump") then ...
move = game.controls.getAxis("move")   ' BGE.Math.Vector {x, y}
velocity.x = move.x * speed
velocity.y = move.y * speed
```

- `bindAction(name, remoteButton = invalid, controllerButton = invalid, playerIndex = 0)` — either source fires the action; `playerIndex` optional, defaults to 0 (single-player games never touch it).
- `bindAxis(name, stick = 1, playerIndex = 0)` — `stick` is 1 or 2 (twin-stick). `getAxis(name)` returns the controller stick's value when non-neutral, else falls back to the remote d-pad as a discrete `{-1,0,1}` vector — so `move` works with just a remote connected, no controller required.
- `isActionPressed/isActionHeld/isActionReleased(name, playerIndex = 0) as boolean` mirror `GameInput.press/.held/.release` semantics, resolved through whichever source fired.
- Raw/unmapped access (synthesized `GameInput.button`, `playerIndex`) remains available for anything `ControlMap` doesn't cover, documented as an advanced/escape-hatch path, not the front door.

## E. Discovery

`Game.getControllerConnectionInfo()` returns the LAN URL (`roDeviceInfo.GetIpAddrs()` + port) for a game to display via any `Label`/debug widget. Follow-up GitHub issue: QR-code rendering of this URL.

## F. Testing

Headless Rooibos (`*.spec.bs`, colocated):
- `WebSocketFrameCodec` — frame encode/decode, masking, fragmentation.
- HTTP request parsing.
- `ControlMap` — bindAction/bindAxis/isActionPressed/getAxis against fake `GameInput`/internal-state fixtures.

Device/manual only (brs-cli has no `roStreamSocket`): `ControllerServer`'s actual socket/HTTP/WebSocket path, verified by sideload + a real phone browser via the `rokubot-examples` workflow.

New example: `examples/controller` — shows discovery info, an entity driven by `ControlMap` axes, jump/fire-style action bindings, working from both the remote and a connected phone.

## G. File layout

```
src/source/engine/controller/
  ControllerServer.bs
  WebSocketFrameCodec.bs
  ByteUtil.bs
  ControlMap.bs
  *.spec.bs
src/source/controller-web/
  index.html
examples/controller/
docs/
  controller-input.md   ' new guide, once this lands
```

## Follow-up issues to file

- QR-code discovery (section E).
