# Controller Input Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a browser (phone/tablet) act as a virtual twin-stick gamepad for a Roku channel built on this engine, streamed over a self-hosted WebSocket server, unified with remote input through one `ControlMap` mapping API.

**Architecture:** A trimmed, ported `ControllerServer` (HTTP + RFC 6455 WebSocket, adapted from [roku-gamepad](https://github.com/markwpearce/roku-gamepad)) runs on a `roMessagePort` polled once per frame in `Game.Play()`, same as the existing input/audio/URL ports — no SceneGraph. Controller button transitions synthesize `GameInput` (extended with `playerIndex`); axes are read continuously. `BGE.Controller.ControlMap` (`game.controls`) is the only new concept a game touches: `bindAction`/`bindAxis` once, `isActionPressed`/`getAxis` per frame.

**Tech Stack:** BrighterScript, `roStreamSocket`, RFC 6455 WebSocket framing, Rooibos (headless specs), nipple.js via CDN + browser Gamepad API (client page).

**Spec:** `specs/2026-08-28-controller-input-design.md`

## Global Constraints

- No SceneGraph APIs anywhere in this feature (engine's whole premise is `roScreen`).
- `game.enableControllerInput()` never called → zero added cost (no socket created, no extra per-frame work).
- `playerIndex` optional everywhere in `ControlMap`, defaulting to `0` — single-player code never touches it.
- `ControllerServer`/`WebSocketFrameCodec`/`ControllerRegistry`/per-connection state are internal; `ControlMap` (`game.controls`) is the only public surface a game is expected to learn.
- `roStreamSocket.send()` must be looped on its return value until fully written — never assume one call flushes the whole buffer.
- `WebSocketFrameCodec` carries an MIT attribution comment for BrightWebSocket (Rolando Islas), per upstream.
- After every task: `npm run validate` and `npm run lint` must pass. After tasks producing `*.spec.bs` files: `npm run test:ci` must pass.
- Follow existing repo conventions: JSDoc-style `'` comments on public methods, `bslint.json` rules (no single-line `if`), Rooibos `@suite`/`@describe`/`@it` spec style (see `src/source/engine/GameInput.spec.bs`).

---

## File Structure

```
src/source/engine/controller/
  WebSocketFrameCodec.bs        ' RFC 6455 framing (Task 1)
  WebSocketFrameCodec.spec.bs
  ControllerRegistry.bs         ' internal per-connection axis/button state (Task 3)
  ControllerRegistry.spec.bs
  ControlMap.bs                 ' public mapping API, game.controls (Task 4)
  ControlMap.spec.bs
  ControllerServer.bs           ' HTTP + WebSocket server (Task 5)
src/source/controller-web/
  index.html                    ' browser controller page (Task 7)
src/source/engine/GameInput.bs  ' modified: + playerIndex, explicit button name (Task 2)
src/source/engine/Game.bs       ' modified: enableControllerInput, wiring (Task 6)
src/source/utils/utils.bs       ' modified: + BGE.hexStringToByteArray, generic (Task 1)
examples/controller/            ' new example (Task 8)
docs/controller-input.md        ' new guide (Task 9)
```

---

### Task 1: WebSocketFrameCodec

**Files:**
- Modify: `src/source/utils/utils.bs` (add a generic hex-decoding helper - not controller-specific, belongs alongside the existing `bytesToInteger`/`bytesToFloat`)
- Test: `src/source/utils/utils.spec.bs` (append)
- Create: `src/source/engine/controller/WebSocketFrameCodec.bs`
- Test: `src/source/engine/controller/WebSocketFrameCodec.spec.bs`

**Interfaces:**
- Produces: `BGE.hexStringToByteArray(hex as string) as roByteArray` (generic; used here, but reusable anywhere a hex string needs decoding - hashes, checksums, etc.). `BGE.Controller.WebSocketFrameCodec.computeAcceptKey(secWebSocketKey as string) as string`, `.encodeTextFrame(message as string) as roByteArray`, `.decodeFrames(buffer as roByteArray, bufferSize as integer) as BGE.Controller.WebSocketFrameCodec.DecodeResult` (`{frames: DecodedFrame[], bytesConsumed: integer}`, `DecodedFrame = {opcode: integer, final: boolean, payload: roByteArray}`), `BGE.Controller.WebSocketFrameCodec.OpCode` enum (`continuation=0, text=1, binary=2, close=8, ping=9, pong=10`).

- [ ] **Step 0: Write a failing test for the generic hex helper, then implement it**

Append to `src/source/utils/utils.spec.bs`:

```brighterscript
    @describe("hexStringToByteArray")

    @it("decodes a hex string into the matching bytes")
    function _()
      result = BGE.hexStringToByteArray("48656c6c6f")
      m.assertEqual("Hello", result.ToAsciiString())
    end function

    @it("decodes an empty string to an empty byte array")
    function _()
      result = BGE.hexStringToByteArray("")
      m.assertEqual(0, result.Count())
    end function
```

Run `npm run build-tests && npm run test:ci` to confirm it fails, then add to `src/source/utils/utils.bs` (namespace `BGE`, alongside `bytesToInteger`):

```brighterscript
  ' Decodes a hex-encoded string (e.g. from roEVPDigest.Process()) into its
  ' raw bytes. Two hex characters per byte; an odd-length input's trailing
  ' character is ignored.
  '
  ' @param {string} hex
  ' @return {roByteArray}
  function hexStringToByteArray(hex as string) as roByteArray
    bytes = CreateObject("roByteArray")
    charIndex = 0
    while charIndex < Len(hex)
      bytes.Push(Int(Val(Mid(hex, charIndex + 1, 2), 16)))
      charIndex += 2
    end while
    return bytes
  end function
```

Run `npm run build-tests && npm run test:ci` to confirm it passes, then commit:

```bash
git add src/source/utils/utils.bs src/source/utils/utils.spec.bs
git commit -m "feat: add BGE.hexStringToByteArray generic utility (#149)"
```

- [ ] **Step 1: Write failing tests for `computeAcceptKey`**

```brighterscript
namespace tests
  @suite("BGE.Controller.WebSocketFrameCodec")
  class WebSocketFrameCodecTests extends rooibos.BaseTestSuite

    @describe("computeAcceptKey")

    @it("computes the RFC 6455 example accept key")
    function _()
      ' Example from RFC 6455 section 1.3
      result = BGE.Controller.WebSocketFrameCodec.computeAcceptKey("dGhlIHNhbXBsZSBub25jZQ==")
      m.assertEqual("s3pPLMBiTxaQ9kYGzzhZRbK+xOo=", result)
    end function

  end class
end namespace
```

- [ ] **Step 2: Run to verify it fails**

Run: `npm run build-tests && npm run test:ci`
Expected: FAIL — `BGE.Controller.WebSocketFrameCodec` not found.

- [ ] **Step 3: Implement `WebSocketFrameCodec.bs`**

```brighterscript
namespace BGE.Controller.WebSocketFrameCodec
  ' Server-side RFC 6455 websocket framing. Client -> server frames are
  ' always masked; server -> client frames are always sent unmasked
  ' (RFC 6455 section 5.1). Adapted from BrightWebSocket
  ' (https://github.com/SuitestAutomation/BrightWebSocket), (c) Rolando
  ' Islas, MIT license, via https://github.com/markwpearce/roku-gamepad.

  const ACCEPT_GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

  enum OpCode
    continuation = 0
    text = 1
    binary = 2
    close = 8
    ping = 9
    pong = 10
  end enum

  interface DecodedFrame
    opcode as integer
    final as boolean
    payload as roByteArray
  end interface

  interface DecodeResult
    frames as BGE.Controller.WebSocketFrameCodec.DecodedFrame[]
    ' bytes at the start of the input consumed by `frames` - anything after
    ' this is an incomplete trailing frame, keep it for the next call
    bytesConsumed as integer
  end interface

  ' Computes the Sec-WebSocket-Accept header value for a given
  ' Sec-WebSocket-Key request header (RFC 6455 section 4.2.2).
  function computeAcceptKey(secWebSocketKey as string) as string
    combined = CreateObject("roByteArray")
    combined.FromAsciiString(secWebSocketKey + ACCEPT_GUID)
    digest = CreateObject("roEVPDigest")
    digest.Setup("sha1")
    hexDigest = digest.Process(combined) as string
    ' roEVPDigest.Process returns hex; Sec-WebSocket-Accept needs raw bytes.
    return BGE.hexStringToByteArray(hexDigest).ToBase64String()
  end function

  function encodeTextFrame(message as string) as roByteArray
    payload = CreateObject("roByteArray")
    payload.FromAsciiString(message)
    return encodeFrame(BGE.Controller.WebSocketFrameCodec.OpCode.text, payload)
  end function

  function encodeFrame(opcode as integer, payload as roByteArray) as roByteArray
    frame = CreateObject("roByteArray")
    frame.Push(&h80 or opcode) ' FIN=1, RSV1-3=0
    payloadLength = payload.Count()
    if payloadLength > &hffff
      frame.Push(127)
      frame.Append(longToBytes(payloadLength))
    else if payloadLength > 125
      frame.Push(126)
      frame.Append(shortToBytes(payloadLength))
    else
      frame.Push(payloadLength)
    end if
    frame.Append(payload)
    return frame
  end function

  ' Decodes as many complete frames as are present in the first
  ' `bufferSize` bytes of `buffer`. A trailing partial frame is left
  ' undecoded - the caller keeps bytes from `bytesConsumed` onward.
  function decodeFrames(buffer as roByteArray, bufferSize as integer) as BGE.Controller.WebSocketFrameCodec.DecodeResult
    frames = [] as BGE.Controller.WebSocketFrameCodec.DecodedFrame[]
    offset = 0
    while true
      decoded = decodeFrameAt(buffer, offset, bufferSize)
      if decoded = invalid
        exit while
      end if
      frames.Push({opcode: decoded.opcode, final: decoded.final, payload: decoded.payload})
      offset = decoded.nextOffset
    end while
    return {frames: frames, bytesConsumed: offset}
  end function

  ' Returns invalid if fewer than a full frame's worth of bytes are
  ' available yet (caller should wait for more data).
  function decodeFrameAt(buffer as roByteArray, offset as integer, bufferSize as integer) as object
    available = bufferSize - offset
    if available < 2
      return invalid
    end if
    byte0 = buffer[offset]
    byte1 = buffer[offset + 1]
    final = (byte0 >> 7) = 1
    opcode = byte0 and &hf
    masked = (byte1 >> 7) = 1
    payloadLength7 = byte1 and &h7f
    headerLength = 2
    payloadLength = payloadLength7
    if payloadLength7 = 126
      if available < 4
        return invalid
      end if
      payloadLength = bytesToShort(buffer[offset + 2], buffer[offset + 3])
      headerLength += 2
    else if payloadLength7 = 127
      if available < 10
        return invalid
      end if
      payloadLength = bytesToLong(buffer, offset + 2)
      headerLength += 8
    end if
    maskLength = 0
    if masked
      maskLength = 4
      if available < headerLength + maskLength
        return invalid
      end if
    end if
    frameLength = headerLength + maskLength + payloadLength
    if available < frameLength
      return invalid
    end if
    payloadStart = offset + headerLength + maskLength
    payload = CreateObject("roByteArray")
    if masked
      maskBytes = [buffer[offset + headerLength], buffer[offset + headerLength + 1], buffer[offset + headerLength + 2], buffer[offset + headerLength + 3]]
      for payloadIndex = 0 to payloadLength - 1
        payload.Push(buffer[payloadStart + payloadIndex] xor maskBytes[payloadIndex mod 4])
      end for
    else
      for payloadIndex = 0 to payloadLength - 1
        payload.Push(buffer[payloadStart + payloadIndex])
      end for
    end if
    return {opcode: opcode, final: final, payload: payload, nextOffset: offset + frameLength}
  end function

  function bytesToShort(b1 as integer, b2 as integer) as integer
    return ((b1 and &hff) << 8) or (b2 and &hff)
  end function

  function bytesToLong(buffer as roByteArray, offset as integer) as longinteger
    result = 0
    for i = 0 to 7
      result = (result << 8) or (buffer[offset + i] and &hff)
    end for
    return result
  end function

  function shortToBytes(number as integer) as roByteArray
    ba = CreateObject("roByteArray")
    ba.Push((number >> 8) and &hff)
    ba.Push(number and &hff)
    return ba
  end function

  function longToBytes(number as longinteger) as roByteArray
    ba = CreateObject("roByteArray")
    for bit = 56 to 0 step -8
      ba.Push((number >> bit) and &hff)
    end for
    return ba
  end function

end namespace
```

- [ ] **Step 4: Run to verify Step 1 passes**

Run: `npm run build-tests && npm run test:ci`
Expected: PASS.

- [ ] **Step 5: Add encode/decode round-trip + fragmentation-boundary tests**

```brighterscript
    @describe("encodeTextFrame / decodeFrames round trip")

    @it("round trips a short unmasked text frame")
    function _()
      frame = BGE.Controller.WebSocketFrameCodec.encodeTextFrame("hello")
      result = BGE.Controller.WebSocketFrameCodec.decodeFrames(frame, frame.Count())
      m.assertEqual(1, result.frames.Count())
      m.assertEqual(BGE.Controller.WebSocketFrameCodec.OpCode.text, result.frames[0].opcode)
      m.assertTrue(result.frames[0].final)
      m.assertEqual("hello", result.frames[0].payload.ToAsciiString())
      m.assertEqual(frame.Count(), result.bytesConsumed)
    end function

    @it("round trips a payload over 125 bytes (16-bit length prefix)")
    function _()
      longMessage = String(200, "x")
      frame = BGE.Controller.WebSocketFrameCodec.encodeTextFrame(longMessage)
      result = BGE.Controller.WebSocketFrameCodec.decodeFrames(frame, frame.Count())
      m.assertEqual(longMessage, result.frames[0].payload.ToAsciiString())
    end function

    @describe("decodeFrameAt with a masked client frame")

    @it("unmasks a masked text frame payload")
    function _()
      ' A masked "hi" text frame: FIN+text, masked+len=2, mask key, masked payload
      payload = CreateObject("roByteArray")
      payload.FromAsciiString("hi")
      maskKey = [1, 2, 3, 4]
      masked = CreateObject("roByteArray")
      masked.Push(&h81) ' FIN=1, opcode=text
      masked.Push(&h80 or 2) ' masked=1, len=2
      for each b in maskKey
        masked.Push(b)
      end for
      for i = 0 to payload.Count() - 1
        masked.Push(payload[i] xor maskKey[i mod 4])
      end for
      result = BGE.Controller.WebSocketFrameCodec.decodeFrames(masked, masked.Count())
      m.assertEqual("hi", result.frames[0].payload.ToAsciiString())
    end function

    @it("returns no frames and zero bytesConsumed for an incomplete frame")
    function _()
      partial = CreateObject("roByteArray")
      partial.Push(&h81) ' only the first header byte
      result = BGE.Controller.WebSocketFrameCodec.decodeFrames(partial, partial.Count())
      m.assertEqual(0, result.frames.Count())
      m.assertEqual(0, result.bytesConsumed)
    end function
```

- [ ] **Step 6: Run tests, verify all pass**

Run: `npm run build-tests && npm run test:ci`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add src/source/engine/controller/WebSocketFrameCodec.bs src/source/engine/controller/WebSocketFrameCodec.spec.bs
git commit -m "feat: add WebSocketFrameCodec (RFC 6455 framing) for controller input (#149)"
```

---

### Task 2: Extend GameInput for controller-originated events

**Files:**
- Modify: `src/source/engine/GameInput.bs`
- Test: `src/source/engine/GameInput.spec.bs` (append)

**Interfaces:**
- Produces: `BGE.GameInput.playerIndex as integer` (`-1` for the physical remote); constructor `new(buttonCode as integer, heldTimeMs as integer, playerIndex = -1 as integer, explicitButtonName = invalid as string)`. When `explicitButtonName` is given, `button` is set to it directly (bypassing `BGE.buttonNameFromCode`) while `press`/`held`/`release` still derive from `buttonCode`'s existing 0/100/1000 offset convention. Controller buttons use `button = "controller" + buttonIndex.ToStr()`.

- [ ] **Step 1: Write failing tests**

```brighterscript
    @describe("controller-originated input")

    @it("defaults playerIndex to -1 for remote input")
    function _()
      input = new BGE.GameInput(2, 0)
      m.assertEqual(-1, input.playerIndex)
    end function

    @it("uses explicitButtonName instead of buttonNameFromCode when given")
    function _()
      input = new BGE.GameInput(0, 0, 0, "controller0")
      m.assertEqual("controller0", input.button)
      m.assertEqual(0, input.playerIndex)
      m.assertTrue(input.press)
    end function

    @it("still derives press/held/release from buttonCode with an explicit name")
    function _()
      pressed = new BGE.GameInput(3, 0, 1, "controller3")
      released = new BGE.GameInput(103, 0, 1, "controller3")
      held = new BGE.GameInput(1003, 40, 1, "controller3")
      m.assertTrue(pressed.press)
      m.assertTrue(released.release)
      m.assertTrue(held.held)
      m.assertEqual(40, held.heldTimeMs)
    end function

    @it("isButton matches an explicit controller button name")
    function _()
      input = new BGE.GameInput(1, 0, 0, "controller1")
      m.assertTrue(input.isButton("controller1"))
      m.assertFalse(input.isButton("controller0"))
    end function
```

- [ ] **Step 2: Run to verify it fails**

Run: `npm run build-tests && npm run test:ci`
Expected: FAIL — constructor arity mismatch / `playerIndex` not found.

- [ ] **Step 3: Modify `GameInput.bs`**

Add the field just below `heldTimeMs`:

```brighterscript
    ' Which controller this input came from - -1 for the physical remote,
    ' 0+ for a connected browser controller (see BGE.Controller.ControlMap).
    playerIndex as integer = -1
```

Replace the constructor:

```brighterscript
    ' Creates a GameInput object based on the buttonCode.
    ' A controller-originated event passes playerIndex/explicitButtonName -
    ' see BGE.Controller.ControlMap, which is the normal way to consume
    ' controller input rather than constructing this directly.
    '
    ' @param {integer} buttonCode - button to use for the data
    ' @param {integer} heldTimeMs - how long was this button held for
    ' @param {integer} [playerIndex=-1] - -1 for the remote, 0+ for a controller
    ' @param {string} [explicitButtonName=invalid] - overrides buttonNameFromCode, used for controller buttons
    sub new(buttonCode as integer, heldTimeMs as integer, playerIndex = -1 as integer, explicitButtonName = invalid as string)
      m.buttonCode = buttonCode
      m.playerIndex = playerIndex
      if explicitButtonName <> invalid
        m.button = explicitButtonName
      else
        m.button = BGE.buttonNameFromCode(buttonCode)
      end if
      m.press = buttonCode < 100
      m.held = buttonCode >= 1000
      m.release = buttonCode >= 100 and buttonCode < 1000
      m.heldTimeMs = heldTimeMs
      m.x = 0
      m.y = 0
      if not m.release
        if m.isButton("right")
          m.x = 1
        else if m.isButton("left")
          m.x = -1
        else if m.isButton("down")
          m.y = -1
        else if m.isButton("up")
          m.y = 1
        end if
      end if
    end sub
```

- [ ] **Step 4: Run tests, verify all pass**

Run: `npm run build-tests && npm run test:ci`
Expected: PASS.

- [ ] **Step 5: Run `npm run validate` to confirm no existing call site broke**

Run: `npm run validate`
Expected: PASS (existing `new GameInput(code, ms)` two-arg call sites still type-check against the new optional params).

- [ ] **Step 6: Commit**

```bash
git add src/source/engine/GameInput.bs src/source/engine/GameInput.spec.bs
git commit -m "feat: add playerIndex + explicit button name to GameInput for controller input (#149)"
```

---

### Task 3: ControllerRegistry (internal per-connection state)

**Files:**
- Create: `src/source/engine/controller/ControllerRegistry.bs`
- Test: `src/source/engine/controller/ControllerRegistry.spec.bs`

**Interfaces:**
- Consumes: `BGE.Math.VectorOps.create(x, y) as BGE.Math.Vector` (existing).
- Produces (internal - not part of the public docs, used by `ControlMap` and `Game`): `BGE.Controller.ControllerRegistry` with `assignPlayerIndex() as integer`, `releasePlayerIndex(playerIndex as integer)`, `updateFromMessage(playerIndex as integer, axes as float[], buttons as boolean[]) as integer[]` (returns changed button indexes), `isButtonHeld(playerIndex, buttonIndex) as boolean`, `getHeldTimeMs(playerIndex, buttonIndex) as integer`, `getStick(playerIndex, stick as integer) as BGE.Math.Vector`, `setRemoteDpad(x as float, y as float)`, `getRemoteDpad() as BGE.Math.Vector`.

- [ ] **Step 1: Write failing tests**

```brighterscript
namespace tests
  @suite("BGE.Controller.ControllerRegistry")
  class ControllerRegistryTests extends rooibos.BaseTestSuite

    @describe("assignPlayerIndex / releasePlayerIndex")

    @it("assigns increasing indexes, then reuses a freed one")
    function _()
      registry = new BGE.Controller.ControllerRegistry()
      first = registry.assignPlayerIndex()
      second = registry.assignPlayerIndex()
      m.assertEqual(0, first)
      m.assertEqual(1, second)
      registry.releasePlayerIndex(0)
      third = registry.assignPlayerIndex()
      m.assertEqual(0, third)
    end function

    @describe("updateFromMessage")

    @it("returns the indexes of buttons that changed since last update")
    function _()
      registry = new BGE.Controller.ControllerRegistry()
      playerIndex = registry.assignPlayerIndex()
      changed = registry.updateFromMessage(playerIndex, [0.0, 0.0], [true, false, false])
      m.assertEqual(1, changed.Count())
      m.assertEqual(0, changed[0])
    end function

    @it("reports no change when the same buttons are sent again")
    function _()
      registry = new BGE.Controller.ControllerRegistry()
      playerIndex = registry.assignPlayerIndex()
      registry.updateFromMessage(playerIndex, [0.0, 0.0], [true, false])
      changed = registry.updateFromMessage(playerIndex, [0.0, 0.0], [true, false])
      m.assertEqual(0, changed.Count())
    end function

    @it("isButtonHeld reflects the latest message")
    function _()
      registry = new BGE.Controller.ControllerRegistry()
      playerIndex = registry.assignPlayerIndex()
      registry.updateFromMessage(playerIndex, [], [false, true])
      m.assertTrue(registry.isButtonHeld(playerIndex, 1))
      m.assertFalse(registry.isButtonHeld(playerIndex, 0))
    end function

    @describe("stick axes")

    @it("stores stick1 from axes[0:1] and stick2 from axes[2:3]")
    function _()
      registry = new BGE.Controller.ControllerRegistry()
      playerIndex = registry.assignPlayerIndex()
      registry.updateFromMessage(playerIndex, [0.5, -0.5, 1.0, -1.0], [])
      stick1 = registry.getStick(playerIndex, 1)
      stick2 = registry.getStick(playerIndex, 2)
      m.assertEqual(0.5, stick1.x)
      m.assertEqual(-0.5, stick1.y)
      m.assertEqual(1.0, stick2.x)
      m.assertEqual(-1.0, stick2.y)
    end function

    @describe("remote d-pad fallback state")

    @it("stores and returns the remote d-pad vector")
    function _()
      registry = new BGE.Controller.ControllerRegistry()
      registry.setRemoteDpad(1, 0)
      dpad = registry.getRemoteDpad()
      m.assertEqual(1.0, dpad.x)
      m.assertEqual(0.0, dpad.y)
    end function

  end class
end namespace
```

- [ ] **Step 2: Run to verify it fails**

Run: `npm run build-tests && npm run test:ci`
Expected: FAIL — `BGE.Controller.ControllerRegistry` not found.

- [ ] **Step 3: Implement `ControllerRegistry.bs`**

```brighterscript
namespace BGE.Controller

  ' Internal per-connection controller state (buttons/axes/held-timers) plus
  ' the remote's own d-pad fallback state. Not part of the public API - a
  ' game uses BGE.Controller.ControlMap (game.controls) instead.
  class ControllerConnectionState
    buttons as boolean[] = []
    heldTimers = {} ' buttonIndex.ToStr() -> roTimespan, present only while held
    stick1 as BGE.Math.Vector = BGE.Math.VectorOps.create()
    stick2 as BGE.Math.Vector = BGE.Math.VectorOps.create()
  end class

  class ControllerRegistry
    private connections = {} ' playerIndex.ToStr() -> ControllerConnectionState
    private remoteDpad as BGE.Math.Vector = BGE.Math.VectorOps.create()

    ' Assigns the lowest player index not currently in use.
    function assignPlayerIndex() as integer
      index = 0
      while m.connections.DoesExist(index.ToStr())
        index++
      end while
      m.connections[index.ToStr()] = new BGE.Controller.ControllerConnectionState()
      return index
    end function

    sub releasePlayerIndex(playerIndex as integer)
      m.connections.Delete(playerIndex.ToStr())
    end sub

    ' Updates one connection's raw state from a decoded {axes, buttons}
    ' message. Returns the button indexes whose boolean flipped since the
    ' last update, for Game to synthesize press/release GameInput events.
    function updateFromMessage(playerIndex as integer, axes as float[], buttons as boolean[]) as integer[]
      state = m.connections[playerIndex.ToStr()]
      if state = invalid
        return []
      end if
      changed = []
      for i = 0 to buttons.Count() - 1
        previous = (i < state.buttons.Count()) ? state.buttons[i] : false
        if previous <> buttons[i]
          changed.Push(i)
          if buttons[i]
            timer = CreateObject("roTimespan")
            timer.Mark()
            state.heldTimers[i.ToStr()] = timer
          else
            state.heldTimers.Delete(i.ToStr())
          end if
        end if
      end for
      state.buttons = buttons
      if axes.Count() >= 2
        state.stick1 = BGE.Math.VectorOps.create(axes[0], axes[1])
      end if
      if axes.Count() >= 4
        state.stick2 = BGE.Math.VectorOps.create(axes[2], axes[3])
      end if
      return changed
    end function

    function isButtonHeld(playerIndex as integer, buttonIndex as integer) as boolean
      state = m.connections[playerIndex.ToStr()]
      if state = invalid or buttonIndex >= state.buttons.Count()
        return false
      end if
      return state.buttons[buttonIndex]
    end function

    function getHeldTimeMs(playerIndex as integer, buttonIndex as integer) as integer
      state = m.connections[playerIndex.ToStr()]
      if state = invalid
        return 0
      end if
      timer = state.heldTimers[buttonIndex.ToStr()]
      if timer = invalid
        return 0
      end if
      return timer.TotalMilliseconds()
    end function

    function getStick(playerIndex as integer, stick as integer) as BGE.Math.Vector
      state = m.connections[playerIndex.ToStr()]
      if state = invalid
        return BGE.Math.VectorOps.create()
      end if
      if stick = 2
        return state.stick2
      end if
      return state.stick1
    end function

    sub setRemoteDpad(x as float, y as float)
      m.remoteDpad = BGE.Math.VectorOps.create(x, y)
    end sub

    function getRemoteDpad() as BGE.Math.Vector
      return m.remoteDpad
    end function

  end class

end namespace
```

- [ ] **Step 4: Run tests, verify all pass**

Run: `npm run build-tests && npm run test:ci`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/source/engine/controller/ControllerRegistry.bs src/source/engine/controller/ControllerRegistry.spec.bs
git commit -m "feat: add ControllerRegistry for per-connection controller state (#149)"
```

---

### Task 4: ControlMap (public mapping API)

**Files:**
- Create: `src/source/engine/controller/ControlMap.bs`
- Test: `src/source/engine/controller/ControlMap.spec.bs`

**Interfaces:**
- Consumes: `BGE.GameInput` (Task 2: `.playerIndex`, `.button`, `.press/.held/.release`, `.isButton`), `BGE.Controller.ControllerRegistry` (Task 3: `.getStick`, `.getRemoteDpad`).
- Produces: `BGE.Controller.ControlMap` with `new(registry as BGE.Controller.ControllerRegistry)`, `bindAction(name as string, remoteButton = invalid as string, controllerButton = invalid as dynamic, playerIndex = 0 as integer)`, `bindAxis(name as string, stick = 1 as integer, playerIndex = 0 as integer)`, `onInput(input as BGE.GameInput)`, `isActionPressed(name as string, playerIndex = 0 as integer) as boolean`, `isActionHeld(...) as boolean`, `isActionReleased(...) as boolean`, `getAxis(name as string) as BGE.Math.Vector`.

- [ ] **Step 1: Write failing tests**

```brighterscript
namespace tests
  @suite("BGE.Controller.ControlMap")
  class ControlMapTests extends rooibos.BaseTestSuite

    @describe("bindAction / isActionPressed via remote button")

    @it("fires when the bound remote button is pressed")
    function _()
      controls = new BGE.Controller.ControlMap(new BGE.Controller.ControllerRegistry())
      controls.bindAction("jump", "ok")
      controls.onInput(new BGE.GameInput(6, 0)) ' OK, pressed
      m.assertTrue(controls.isActionPressed("jump"))
      m.assertFalse(controls.isActionHeld("jump"))
    end function

    @it("does not fire for an unbound button")
    function _()
      controls = new BGE.Controller.ControlMap(new BGE.Controller.ControllerRegistry())
      controls.bindAction("jump", "ok")
      controls.onInput(new BGE.GameInput(4, 0)) ' left, pressed
      m.assertFalse(controls.isActionPressed("jump"))
    end function

    @describe("bindAction via controller button")

    @it("fires when the bound player's controller button is pressed")
    function _()
      controls = new BGE.Controller.ControlMap(new BGE.Controller.ControllerRegistry())
      controls.bindAction("jump", invalid, 0, 0) ' controller button 0, player 0
      controls.onInput(new BGE.GameInput(0, 0, 0, "controller0"))
      m.assertTrue(controls.isActionPressed("jump", 0))
    end function

    @it("does not fire for a different player's same controller button")
    function _()
      controls = new BGE.Controller.ControlMap(new BGE.Controller.ControllerRegistry())
      controls.bindAction("jump", invalid, 0, 0)
      controls.onInput(new BGE.GameInput(0, 0, 1, "controller0")) ' player 1
      m.assertFalse(controls.isActionPressed("jump", 0))
      m.assertFalse(controls.isActionPressed("jump", 1)) ' player 1 has no "jump" binding
    end function

    @it("either the remote or the controller binding fires the same action")
    function _()
      controls = new BGE.Controller.ControlMap(new BGE.Controller.ControllerRegistry())
      controls.bindAction("jump", "ok", 0, 0)
      controls.onInput(new BGE.GameInput(0, 0, 0, "controller0"))
      m.assertTrue(controls.isActionPressed("jump"))
    end function

    @describe("bindAxis / getAxis")

    @it("returns the bound controller stick when non-neutral")
    function _()
      registry = new BGE.Controller.ControllerRegistry()
      playerIndex = registry.assignPlayerIndex()
      registry.updateFromMessage(playerIndex, [0.5, -0.5], [])
      controls = new BGE.Controller.ControlMap(registry)
      controls.bindAxis("move", 1, playerIndex)
      result = controls.getAxis("move")
      m.assertEqual(0.5, result.x)
      m.assertEqual(-0.5, result.y)
    end function

    @it("falls back to the remote d-pad when the controller stick is neutral")
    function _()
      registry = new BGE.Controller.ControllerRegistry()
      registry.setRemoteDpad(0, 1)
      controls = new BGE.Controller.ControlMap(registry)
      controls.bindAxis("move")
      result = controls.getAxis("move")
      m.assertEqual(0.0, result.x)
      m.assertEqual(1.0, result.y)
    end function

    @it("returns a zero vector for an unbound axis name")
    function _()
      controls = new BGE.Controller.ControlMap(new BGE.Controller.ControllerRegistry())
      result = controls.getAxis("nope")
      m.assertEqual(0.0, result.x)
      m.assertEqual(0.0, result.y)
    end function

  end class
end namespace
```

- [ ] **Step 2: Run to verify it fails**

Run: `npm run build-tests && npm run test:ci`
Expected: FAIL — `BGE.Controller.ControlMap` not found.

- [ ] **Step 3: Implement `ControlMap.bs`**

```brighterscript
namespace BGE.Controller

  ' Unified mapping from remote-button and controller input to named
  ' actions/axes - the one class a game needs to learn to support both
  ' input sources. Exposed as Game.controls; see Game.enableControllerInput().
  class ControlMap
    private registry as BGE.Controller.ControllerRegistry
    private actionBindings = {} ' name -> {remoteButton, controllerButton, playerIndex}
    private axisBindings = {} ' name -> {stick, playerIndex}
    private actionState = {} ' "<name>:<playerIndex>" -> {press, held, release}

    sub new(registry as BGE.Controller.ControllerRegistry)
      m.registry = registry
    end sub

    ' Binds a logical action name to a remote button and/or a specific
    ' player's numbered controller button - either source fires the action.
    '
    ' @param {string} name - the logical action name, e.g. "jump"
    ' @param {string} [remoteButton=invalid] - a remote button name (see BGE.GameInput.isButton)
    ' @param {integer} [controllerButton=invalid] - a controller button index (Gamepad API buttons[] order)
    ' @param {integer} [playerIndex=0] - which controller's button this binds to
    ' @return {void}
    sub bindAction(name as string, remoteButton = invalid as string, controllerButton = invalid as dynamic, playerIndex = 0 as integer)
      m.actionBindings[name] = {remoteButton: remoteButton, controllerButton: controllerButton, playerIndex: playerIndex}
    end sub

    ' Binds a logical axis name to a player's controller stick. getAxis()
    ' falls back to the remote d-pad whenever that stick reads neutral, so
    ' a game written against this axis works with just a remote connected.
    '
    ' @param {string} name - the logical axis name, e.g. "move"
    ' @param {integer} [stick=1] - 1 or 2 (twin-stick)
    ' @param {integer} [playerIndex=0] - which controller's stick this binds to
    ' @return {void}
    sub bindAxis(name as string, stick = 1 as integer, playerIndex = 0 as integer)
      m.axisBindings[name] = {stick: stick, playerIndex: playerIndex}
    end sub

    ' Feeds one GameInput event (remote or controller-originated) through
    ' every action binding, updating whichever actions it matches. Called
    ' once per input event by Game - a game does not call this directly.
    '
    ' @param {BGE.GameInput} input
    ' @return {void}
    sub onInput(input as BGE.GameInput)
      for each name in m.actionBindings
        binding = m.actionBindings[name]
        matchesRemote = binding.remoteButton <> invalid and input.playerIndex = -1 and input.isButton(binding.remoteButton)
        matchesController = binding.controllerButton <> invalid and input.playerIndex = binding.playerIndex and input.button = "controller" + binding.controllerButton.ToStr()
        if matchesRemote or matchesController
          key = name + ":" + binding.playerIndex.ToStr()
          m.actionState[key] = {press: input.press, held: input.held, release: input.release}
        end if
      end for
    end sub

    ' @param {string} name
    ' @param {integer} [playerIndex=0]
    ' @return {boolean} - true the frame the bound button was pressed
    function isActionPressed(name as string, playerIndex = 0 as integer) as boolean
      return m.stateFor(name, playerIndex).press
    end function

    ' @param {string} name
    ' @param {integer} [playerIndex=0]
    ' @return {boolean} - true every frame the bound button remains held
    function isActionHeld(name as string, playerIndex = 0 as integer) as boolean
      return m.stateFor(name, playerIndex).held
    end function

    ' @param {string} name
    ' @param {integer} [playerIndex=0]
    ' @return {boolean} - true the frame the bound button was released
    function isActionReleased(name as string, playerIndex = 0 as integer) as boolean
      return m.stateFor(name, playerIndex).release
    end function

    private function stateFor(name as string, playerIndex as integer) as object
      key = name + ":" + playerIndex.ToStr()
      return m.actionState[key] ?? {press: false, held: false, release: false}
    end function

    ' @param {string} name - a name previously passed to bindAxis()
    ' @return {BGE.Math.Vector} - the bound controller stick, or the remote d-pad if that stick is neutral
    function getAxis(name as string) as BGE.Math.Vector
      binding = m.axisBindings[name]
      if binding = invalid
        return BGE.Math.VectorOps.create()
      end if
      stickVector = m.registry.getStick(binding.playerIndex, binding.stick)
      if stickVector.x <> 0 or stickVector.y <> 0
        return stickVector
      end if
      return m.registry.getRemoteDpad()
    end function

  end class

end namespace
```

- [ ] **Step 4: Run tests, verify all pass**

Run: `npm run build-tests && npm run test:ci`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/source/engine/controller/ControlMap.bs src/source/engine/controller/ControlMap.spec.bs
git commit -m "feat: add ControlMap unified input-mapping API (#149)"
```

---

### Task 5: ControllerServer (HTTP + WebSocket server)

**Files:**
- Create: `src/source/engine/controller/ControllerServer.bs`

**Interfaces:**
- Consumes: `BGE.Controller.WebSocketFrameCodec` (Task 1).
- Produces: `BGE.Controller.ControllerServer` with `new(port as integer)`, `.port as integer`, `.listen(messagePort as roMessagePort)`, `.onSocketEvent(event as roSocketEvent)`, `.drainEvents() as BGE.Controller.ControllerServerEvent[]` (`{type: string, connectionId: string, message: string}`, `type` is `"onOpen"|"onMessage"|"onClose"`), `.closeConnection(id as string)`.

No automated test for this task — `roStreamSocket` is not available under `brs-cli` (see spec's Testing section). Verified in Task 6/8 by sideloading and connecting a real browser, per the `rokubot-examples` skill.

- [ ] **Step 1: Implement `ControllerServer.bs`**

```brighterscript
namespace BGE.Controller

  const CONTROLLER_HTTP_BUFFER_SIZE = 10240
  const CONTROLLER_WS_READ_SIZE = 10240

  enum ConnectionMode
    http = "http"
    websocket = "websocket"
  end enum

  class ControllerConnection
    socket as roStreamSocket
    mode as string = BGE.Controller.ConnectionMode.http
    wsBuffer as roByteArray = CreateObject("roByteArray")
  end class

  enum ControllerServerEventType
    onOpen = "onOpen"
    onMessage = "onMessage"
    onClose = "onClose"
  end enum

  interface ControllerServerEvent
    type as string ' BGE.Controller.ControllerServerEventType
    connectionId as string
    message as string ' only set for onMessage
  end interface

  ' Minimal HTTP + WebSocket (RFC 6455) server for streaming controller
  ' input from a browser page, without SceneGraph. Adapted and trimmed from
  ' https://github.com/markwpearce/roku-gamepad - serves GET only (static
  ' files under pkg:/source/controller-web), no upload/directory listing.
  class ControllerServer
    port as integer
    private tcpListen as roStreamSocket = CreateObject("roStreamSocket")
    private messagePort as roMessagePort
    private connections = {} ' socket id string -> ControllerConnection
    private events as BGE.Controller.ControllerServerEvent[] = []
    private buffer as roByteArray = CreateObject("roByteArray")

    sub new(port as integer)
      m.port = port
      m.buffer[CONTROLLER_HTTP_BUFFER_SIZE] = 0
    end sub

    sub listen(messagePort as roMessagePort)
      m.messagePort = messagePort
      addr = CreateObject("roSocketAddress")
      addr.setPort(m.port)
      m.tcpListen.setMessagePort(messagePort)
      m.tcpListen.setAddress(addr)
      m.tcpListen.notifyReadable(true)
      m.tcpListen.listen(4)
    end sub

    ' Returns and clears the queue of connection lifecycle/message events
    ' collected since the last call.
    function drainEvents() as BGE.Controller.ControllerServerEvent[]
      drained = m.events
      m.events = []
      return drained
    end function

    sub onSocketEvent(event as roSocketEvent)
      changedId = event.getSocketID()
      if changedId = m.tcpListen.getID() and m.tcpListen.isReadable()
        m.acceptConnection()
        return
      end if
      id = changedId.ToStr()
      connection = m.connections[id]
      if connection = invalid
        return
      end if
      if connection.mode = BGE.Controller.ConnectionMode.websocket
        m.onWebSocketReadable(id, connection)
      else
        m.onHttpReadable(id, connection)
      end if
    end sub

    sub closeConnection(id as string)
      connection = m.connections[id]
      if connection = invalid
        return
      end if
      wasWebSocket = connection.mode = BGE.Controller.ConnectionMode.websocket
      connection.socket.close()
      m.connections.Delete(id)
      if wasWebSocket
        m.events.Push({type: BGE.Controller.ControllerServerEventType.onClose, connectionId: id, message: ""})
      end if
    end sub

    private sub acceptConnection()
      newSocket = m.tcpListen.accept() as roStreamSocket
      if newSocket = invalid
        return
      end if
      newSocket.notifyReadable(true)
      newSocket.setMessagePort(m.messagePort)
      connection = new BGE.Controller.ControllerConnection()
      connection.socket = newSocket
      m.connections[newSocket.getID().ToStr()] = connection
    end sub

    private sub onHttpReadable(id as string, connection as BGE.Controller.ControllerConnection)
      socket = connection.socket
      if not socket.isReadable()
        return
      end if
      numReceivedBytes = socket.receive(m.buffer, 0, CONTROLLER_HTTP_BUFFER_SIZE)
      if numReceivedBytes <= 0
        m.closeConnection(id)
        return
      end if
      request = m.parseHttpRequest(m.buffer, numReceivedBytes)
      if request.command <> "GET"
        m.sendHttpResponse(socket, request.protocol, 405, "Method Not Allowed")
        m.closeConnection(id)
      else if m.isWebSocketUpgradeRequest(request)
        m.upgradeToWebSocket(id, connection, request)
      else
        m.serveStaticFile(socket, request)
        m.closeConnection(id)
      end if
    end sub

    private function parseHttpRequest(buffer as roByteArray, bufferSize as integer) as object
      if bufferSize > CONTROLLER_HTTP_BUFFER_SIZE
        bufferSize = CONTROLLER_HTTP_BUFFER_SIZE
      end if
      buffer[bufferSize] = 0
      lines = buffer.ToAsciiString().Tokenize(chr(13) + chr(10))
      commandLine = lines[0].Tokenize(" ")
      headers = {}
      for lineIndex = 1 to lines.Count() - 1
        line = lines[lineIndex]
        if line = ""
          exit for
        end if
        headerParts = line.Tokenize(":")
        key = headerParts[0].Trim()
        headerParts.Shift()
        headers[key] = headerParts.ToArray().Join(":").Trim()
      end for
      return {command: commandLine[0], path: commandLine[1], protocol: commandLine[2], headers: headers}
    end function

    private function isWebSocketUpgradeRequest(request as object) as boolean
      upgrade = LCase(request.headers["Upgrade"] ?? "")
      connectionHeader = LCase(request.headers["Connection"] ?? "")
      return upgrade = "websocket" and Instr(1, connectionHeader, "upgrade") > 0 and request.headers["Sec-WebSocket-Key"] <> invalid
    end function

    ' Completes the RFC 6455 handshake (section 4.2.2) and flips this
    ' connection into websocket framing mode.
    private sub upgradeToWebSocket(id as string, connection as BGE.Controller.ControllerConnection, request as object)
      acceptKey = BGE.Controller.WebSocketFrameCodec.computeAcceptKey(request.headers["Sec-WebSocket-Key"])
      response = "HTTP/1.1 101 Switching Protocols" + chr(13) + chr(10)
      response += "Upgrade: websocket" + chr(13) + chr(10)
      response += "Connection: Upgrade" + chr(13) + chr(10)
      response += "Sec-WebSocket-Accept: " + acceptKey + chr(13) + chr(10) + chr(13) + chr(10)
      m.sendAll(connection.socket, m.stringToBytes(response))
      connection.mode = BGE.Controller.ConnectionMode.websocket
      m.events.Push({type: BGE.Controller.ControllerServerEventType.onOpen, connectionId: id, message: ""})
    end sub

    private sub onWebSocketReadable(id as string, connection as BGE.Controller.ControllerConnection)
      socket = connection.socket
      if not socket.isReadable()
        return
      end if
      chunk = CreateObject("roByteArray")
      chunk[CONTROLLER_WS_READ_SIZE] = 0
      numReceivedBytes = socket.receive(chunk, 0, CONTROLLER_WS_READ_SIZE)
      if numReceivedBytes <= 0
        m.closeConnection(id)
        return
      end if
      connection.wsBuffer.Append(chunk.Slice(0, numReceivedBytes))
      decodeResult = BGE.Controller.WebSocketFrameCodec.decodeFrames(connection.wsBuffer, connection.wsBuffer.Count())
      shouldClose = false
      for each frame in decodeResult.frames
        if frame.opcode = BGE.Controller.WebSocketFrameCodec.OpCode.close
          shouldClose = true
        else if frame.opcode = BGE.Controller.WebSocketFrameCodec.OpCode.text
          m.events.Push({type: BGE.Controller.ControllerServerEventType.onMessage, connectionId: id, message: frame.payload.ToAsciiString()})
        end if
        ' ping/pong/binary/fragmentation intentionally unsupported - the
        ' browser client only ever sends small, unfragmented text frames
      end for
      if decodeResult.bytesConsumed > 0
        remaining = connection.wsBuffer.Slice(decodeResult.bytesConsumed)
        connection.wsBuffer = CreateObject("roByteArray")
        connection.wsBuffer.Append(remaining)
      end if
      if shouldClose
        m.closeConnection(id)
      end if
    end sub

    private sub serveStaticFile(socket as roStreamSocket, request as object)
      path = "pkg:/source/controller-web" + request.path
      if request.path = "/"
        path += "index.html"
      end if
      contents = CreateObject("roByteArray")
      if not contents.ReadFile(path)
        m.sendHttpResponse(socket, request.protocol, 404, "Not Found")
        return
      end if
      header = request.protocol + " 200 OK" + chr(13) + chr(10) + "Content-Type: " + m.contentTypeFor(path) + chr(13) + chr(10) + "Content-Length: " + contents.Count().ToStr() + chr(13) + chr(10) + chr(13) + chr(10)
      m.sendAll(socket, m.stringToBytes(header))
      m.sendAll(socket, contents)
    end sub

    private function contentTypeFor(path as string) as string
      if path.EndsWith(".html")
        return "text/html"
      else if path.EndsWith(".js")
        return "text/javascript"
      else if path.EndsWith(".css")
        return "text/css"
      end if
      return "application/octet-stream"
    end function

    private sub sendHttpResponse(socket as roStreamSocket, protocol as string, code as integer, body as string)
      statusTexts = {"404": "Not Found", "405": "Method Not Allowed"}
      statusText = statusTexts[code.ToStr()] ?? "Error"
      response = protocol + " " + code.ToStr() + " " + statusText + chr(13) + chr(10) + "Content-Type: text/plain" + chr(13) + chr(10) + chr(13) + chr(10) + body
      m.sendAll(socket, m.stringToBytes(response))
    end sub

    private function stringToBytes(s as string) as roByteArray
      bytes = CreateObject("roByteArray")
      bytes.FromAsciiString(s)
      return bytes
    end function

    ' roStreamSocket.send() is non-blocking and may write fewer bytes than
    ' requested in one call - loop on its return value until fully flushed.
    private sub sendAll(socket as roStreamSocket, bytes as roByteArray)
      totalSent = 0
      total = bytes.Count()
      while totalSent < total
        sent = socket.send(bytes, totalSent, total - totalSent)
        if sent <= 0
          exit while
        end if
        totalSent += sent
      end while
    end sub

  end class

end namespace
```

- [ ] **Step 2: Run `npm run validate` and `npm run lint`**

Run: `npm run validate && npm run lint`
Expected: PASS (type-checks cleanly; no automated behavioral test exists for this file per the spec's testing split — device verification happens in Task 8).

- [ ] **Step 3: Commit**

```bash
git add src/source/engine/controller/ControllerServer.bs
git commit -m "feat: add ControllerServer (HTTP + WebSocket) for controller input (#149)"
```

---

### Task 6: Game integration

**Files:**
- Modify: `src/source/engine/Game.bs`

**Interfaces:**
- Consumes: `BGE.Controller.ControllerServer` (Task 5), `BGE.Controller.ControllerRegistry` (Task 3), `BGE.Controller.ControlMap` (Task 4), `BGE.GameInput` (Task 2).
- Produces: `Game.controls as BGE.Controller.ControlMap` (public field), `Game.enableControllerInput(port = 8888 as integer)`, `Game.getControllerConnectionInfo() as string`.

- [ ] **Step 1: Add fields**

In the `' ****BEGIN - For Internal Use...` block, near `private urlPort`:

```brighterscript
    private controllerPort as roMessagePort = CreateObject("roMessagePort")
    private controllerServer as BGE.Controller.ControllerServer = invalid
    private controllerRegistry as BGE.Controller.ControllerRegistry = new BGE.Controller.ControllerRegistry()
    private controllerConnectionPlayers = {} ' connectionId -> playerIndex
```

Near `gameUi`/`debugUi` (public fields):

```brighterscript
    ' Unified remote+controller input mapping - see enableControllerInput()
    ' and BGE.Controller.ControlMap.
    controls as BGE.Controller.ControlMap = invalid
```

- [ ] **Step 2: Initialize `controls` in `sub new`**

Add right after `m.ecpInput.SetMessagePort(m.ecpInputPort)`:

```brighterscript
      m.controls = new BGE.Controller.ControlMap(m.controllerRegistry)
```

- [ ] **Step 3: Add `enableControllerInput` and `getControllerConnectionInfo`**

Add near `enableStandardDebugUi`:

```brighterscript
    ' Starts a local HTTP + WebSocket server so a browser (phone/tablet) can
    ' connect as a virtual twin-stick controller - see BGE.Controller.ControlMap
    ' (game.controls) to map its input to named actions/axes. Never calling
    ' this adds no cost; no socket is created and no extra per-frame work runs.
    '
    ' @param {integer} [port=8888] - TCP port to listen on
    ' @return {void}
    sub enableControllerInput(port = 8888 as integer)
      m.controllerServer = new BGE.Controller.ControllerServer(port)
      m.controllerServer.listen(m.controllerPort)
    end sub

    ' The LAN URL to open on a phone/tablet to connect as a controller, or
    ' "" if enableControllerInput() hasn't been called.
    '
    ' @return {string}
    function getControllerConnectionInfo() as string
      if m.controllerServer = invalid
        return ""
      end if
      ipAddrs = m.device.GetIpAddrs()
      ip = ""
      for each key in ipAddrs
        ip = ipAddrs[key]
        exit for
      end for
      return `http://${ip}:${m.controllerServer.port}`
    end function
```

- [ ] **Step 4: Add a per-entity controller-input dispatch method**

Add near `processEntityOnInput`:

```brighterscript
    ' Dispatches this frame's controller-originated GameInput events to one
    ' entity's onInput(), mirroring processEntityOnInput's remote-input path.
    private function processEntityOnControllerInput(entity as GameEntity, controllerInputs as GameInput[]) as boolean
      if not m.isValidEntity(entity)
        return false
      end if
      for each input in controllerInputs
        if entity.onInput <> invalid and (m.currentInputEntityId = invalid or m.currentInputEntityId = entity.id)
          entity.onInput(input)
          if not m.isValidEntity(entity)
            return false
          end if
        end if
      end for
      return true
    end function
```

- [ ] **Step 5: Build this frame's controller inputs and feed `Play()`**

Add a new private method:

```brighterscript
    ' Drains ControllerServer socket events, updates ControllerRegistry, and
    ' returns the list of GameInput events (press/release for changed
    ' buttons, held for currently-held ones) synthesized this frame.
    private function drainControllerInput() as GameInput[]
      controllerInputs = [] as GameInput[]
      if m.controllerServer = invalid
        return controllerInputs
      end if

      controllerMsg = m.controllerPort.GetMessage()
      while controllerMsg <> invalid
        m.controllerServer.onSocketEvent(controllerMsg)
        controllerMsg = m.controllerPort.GetMessage()
      end while

      for each event in m.controllerServer.drainEvents()
        if event.type = BGE.Controller.ControllerServerEventType.onOpen
          m.controllerConnectionPlayers[event.connectionId] = m.controllerRegistry.assignPlayerIndex()
        else if event.type = BGE.Controller.ControllerServerEventType.onClose
          playerIndex = m.controllerConnectionPlayers[event.connectionId]
          if playerIndex <> invalid
            m.controllerRegistry.releasePlayerIndex(playerIndex)
            m.controllerConnectionPlayers.Delete(event.connectionId)
          end if
        else if event.type = BGE.Controller.ControllerServerEventType.onMessage
          playerIndex = m.controllerConnectionPlayers[event.connectionId]
          if playerIndex <> invalid
            payload = ParseJson(event.message)
            if payload <> invalid
              axes = payload.axes ?? []
              buttons = payload.buttons ?? []
              changed = m.controllerRegistry.updateFromMessage(playerIndex, axes, buttons)
              for each buttonIndex in changed
                code = buttons[buttonIndex] ? buttonIndex : (100 + buttonIndex)
                controllerInputs.Push(new GameInput(code, 0, playerIndex, "controller" + buttonIndex.ToStr()))
              end for
            end if
          end if
        end if
      end for

      for each key in m.controllerConnectionPlayers
        playerIndex = m.controllerConnectionPlayers[key]
        for buttonIndex = 0 to 15
          if m.controllerRegistry.isButtonHeld(playerIndex, buttonIndex)
            heldTimeMs = m.controllerRegistry.getHeldTimeMs(playerIndex, buttonIndex)
            controllerInputs.Push(new GameInput(1000 + buttonIndex, heldTimeMs, playerIndex, "controller" + buttonIndex.ToStr()))
          end if
        end for
      end for

      return controllerInputs
    end function
```

- [ ] **Step 6: Wire it into `Play()`**

Right after the existing `musicMsg = m.musicPort.GetMessage() as roAudioPlayerEvent` line, add:

```brighterscript
        controllerInputs = m.drainControllerInput()

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
            if directionInput.x <> 0 then remoteDpadX = directionInput.x
            if directionInput.y <> 0 then remoteDpadY = directionInput.y
          else if directionInput.release
            if directionInput.isButton("left") or directionInput.isButton("right") then remoteDpadX = 0
            if directionInput.isButton("up") or directionInput.isButton("down") then remoteDpadY = 0
          end if
        end for
        if m.buttonHeld <> -1
          heldDirectionInput = new GameInput(1000 + m.buttonHeld, m.buttonHeldTimeMs)
          if heldDirectionInput.x <> 0 then remoteDpadX = heldDirectionInput.x
          if heldDirectionInput.y <> 0 then remoteDpadY = heldDirectionInput.y
        end if
        m.controllerRegistry.setRemoteDpad(remoteDpadX, remoteDpadY)
```

Then change the `processEntitiesPreDraw` call to also pass `controllerInputs`:

```brighterscript
        m.processEntitiesPreDraw(universalControlEvents, controllerInputs, musicMsg, ecpMsg, urlMsg)
```

- [ ] **Step 7: Thread `controllerInputs` through `processEntitiesPreDraw`**

Change its signature and add the dispatch call:

```brighterscript
    private sub processEntitiesPreDraw(universalControlEvents as roUniversalControlEvent[], controllerInputs as GameInput[], musicMsg as roAudioPlayerEvent, ecpMsg as roInputEvent, urlMsg as roUrlEvent)
```

Right after the existing `m.processEntityOnInput(entity, universalControlEvents)` call:

```brighterscript
          if m.isValidEntity(entity)
            m.processEntityOnControllerInput(entity, controllerInputs)
          end if
```

- [ ] **Step 8: Run `npm run validate` and `npm run lint`**

Run: `npm run validate && npm run lint`
Expected: PASS.

- [ ] **Step 9: Run the full headless suite to confirm no regression**

Run: `npm run build-tests && npm run test:ci`
Expected: PASS (existing `Game.spec.bs`/`GameEntity.spec.bs` construct a real `Game` in `beforeEach` - confirms `enableControllerInput` never being called keeps everything else working unchanged).

- [ ] **Step 10: Commit**

```bash
git add src/source/engine/Game.bs
git commit -m "feat: wire ControllerServer/ControlMap into Game (enableControllerInput) (#149)"
```

---

### Task 7: Browser controller page

**Files:**
- Create: `src/source/controller-web/index.html`

- [ ] **Step 1: Write the page**

```html
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, user-scalable=no">
  <title>Controller</title>
  <script src="https://cdn.jsdelivr.net/npm/nipplejs@0.10.2/dist/nipplejs.min.js"></script>
  <style>
    html, body { margin: 0; height: 100%; background: #111; color: #eee; font-family: sans-serif; touch-action: none; overscroll-behavior: none; }
    #status { position: absolute; top: 8px; left: 8px; font-size: 14px; }
    .stick { position: absolute; bottom: 60px; width: 140px; height: 140px; }
    #stick1 { left: 30px; }
    #stick2 { right: 30px; }
    .btn { position: absolute; width: 64px; height: 64px; border-radius: 50%; background: #333; color: #eee; border: 2px solid #555; font-size: 14px; }
    #btn0 { bottom: 220px; right: 40px; }
    #btn1 { bottom: 300px; right: 110px; }
  </style>
</head>
<body>
  <div id="status">connecting...</div>
  <div id="stick1" class="stick"></div>
  <div id="stick2" class="stick"></div>
  <button id="btn0" class="btn">A</button>
  <button id="btn1" class="btn">B</button>
  <script>
    var axes = [0, 0, 0, 0];
    var buttons = [false, false];
    var ws = new WebSocket("ws://" + location.host + "/ws");
    var status = document.getElementById("status");
    ws.onopen = function () { status.textContent = "connected"; };
    ws.onclose = function () { status.textContent = "disconnected"; };

    function send() {
      if (ws.readyState === WebSocket.OPEN) {
        ws.send(JSON.stringify({ axes: axes, buttons: buttons }));
      }
    }

    function bindStick(elementId, axisOffset) {
      var manager = nipplejs.create({ zone: document.getElementById(elementId), mode: "static", position: { left: "50%", top: "50%" }, color: "white" });
      manager.on("move", function (evt, data) {
        var rad = data.angle.radian;
        var force = Math.min(data.force, 1);
        axes[axisOffset] = Math.cos(rad) * force;
        axes[axisOffset + 1] = Math.sin(rad) * force;
        send();
      });
      manager.on("end", function () {
        axes[axisOffset] = 0;
        axes[axisOffset + 1] = 0;
        send();
      });
    }
    bindStick("stick1", 0);
    bindStick("stick2", 2);

    function bindButton(elementId, buttonIndex) {
      var el = document.getElementById(elementId);
      var setPressed = function (pressed) {
        buttons[buttonIndex] = pressed;
        send();
      };
      el.addEventListener("touchstart", function (e) { e.preventDefault(); setPressed(true); });
      el.addEventListener("touchend", function (e) { e.preventDefault(); setPressed(false); });
      el.addEventListener("mousedown", function () { setPressed(true); });
      el.addEventListener("mouseup", function () { setPressed(false); });
    }
    bindButton("btn0", 0);
    bindButton("btn1", 1);

    // Real Gamepad, if one is connected, overrides the on-screen controls.
    window.addEventListener("gamepadconnected", function () {
      status.textContent = "connected (gamepad)";
      setInterval(function () {
        var pads = navigator.getGamepads();
        var pad = pads[0];
        if (!pad) return;
        axes = [pad.axes[0] || 0, pad.axes[1] || 0, pad.axes[2] || 0, pad.axes[3] || 0];
        buttons = pad.buttons.map(function (b) { return b.pressed; });
        send();
      }, 50);
    });
  </script>
</body>
</html>
```

- [ ] **Step 2: Register the file to be packaged**

Confirm `bsconfig.json`'s `files` glob already includes everything under `src/` (check `src/source/controller-web/index.html` is not `.bs`/`.brs`, so it needs an explicit static-file entry like other non-code assets — check how `src/images/` or similar assets are listed in `bsconfig.json` and add a matching entry for `src/source/controller-web/**/*` if one isn't already broad enough).

Run: `npm run build` then check `build/source/controller-web/index.html` exists.
Expected: file present in `build/`.

- [ ] **Step 3: Commit**

```bash
git add src/source/controller-web/index.html
git commit -m "feat: add browser controller client page (#149)"
```

---

### Task 8: New example app + on-device verification

**Files:**
- Create: `examples/controller/` (via `npm run create-example -- controller "Controller Demo"`)
- Create: `examples/controller/src/source/Entities/ControlledShip.bs` (via `npm run create-entity -- controller ControlledShip`)

- [ ] **Step 1: Scaffold the example**

Run: `npm run create-example -- controller "Controller Demo"`

- [ ] **Step 2: Scaffold the entity**

Run: `npm run create-entity -- controller ControlledShip`

- [ ] **Step 3: Wire up `main.bs`**

Edit `examples/controller/src/source/main.bs`:

```brighterscript
sub Main()
  game = new BGE.Game(1280, 720)
  game.fitCanvasToScreen()
  game.enableControllerInput()

  game.controls.bindAction("fire", remoteButton: "ok", controllerButton: 0)
  game.controls.bindAxis("move")

  firstRoom = new MainRoom(game)
  game.defineRoom(firstRoom)
  game.changeRoom(firstRoom.name)

  game.enableStandardDebugUi({memory: false, garbageCollector: false})

  game.play()
end sub
```

- [ ] **Step 4: Implement `ControlledShip.bs`**

```brighterscript
namespace BGE.Examples.Controller

  class ControlledShip extends BGE.GameEntity

    override sub onCreate()
      m.speed = 300
      rect = new BGE.DrawableRectangle(40, 40, BGE.ColorsRGB.White)
      m.addDrawable(rect)
    end sub

    override sub onUpdate(dt as float)
      move = m.game.controls.getAxis("move")
      m.velocity.x = move.x * m.speed
      m.velocity.y = move.y * m.speed
    end sub

    override sub onInput(input as BGE.GameInput)
      if input.press and m.game.controls.isActionPressed("fire")
        print "fire!"
      end if
    end sub

  end class

end namespace
```

(Check the generated `Entities/ControlledShip.bs` from Task 8 Step 2 for the exact scaffolded base - e.g. `m.game` field name, `override` keyword usage, and constructor args expected by `MainRoom` - and align this to match, since the template may differ slightly.)

- [ ] **Step 5: Add discovery text to `MainRoom.bs`**

In the generated `examples/controller/src/source/Rooms/MainRoom.bs`'s `onCreate`, add a `BGE.DrawableText`-based entity or `BGE.UI.Label` on `game.gameUi` showing `game.getControllerConnectionInfo()`.

- [ ] **Step 6: Build and validate**

Run: `cd examples/controller && npm install && npm run build`
Expected: builds cleanly.

- [ ] **Step 7: On-device verification (mandatory, not optional)**

Follow the `rokubot-examples` skill: sideload `examples/controller`, launch it, read the on-screen connection URL, open it from a phone/laptop browser on the same network, and confirm:
- The page loads and shows "connected".
- Moving the left stick moves the ship on screen.
- Tapping button A logs "fire!" (visible via `rokubot`'s log/telnet output).
- The remote's own OK button and d-pad still work (unified `ControlMap` binding).

- [ ] **Step 8: Commit**

```bash
git add examples/controller .vscode/tasks.json
git commit -m "feat: add examples/controller demonstrating controller input (#149)"
```

---

### Task 9: Docs guide + follow-up issue + final checks

**Files:**
- Create: `docs/controller-input.md`

- [ ] **Step 1: Write the guide**

```markdown
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

\`\`\`brighterscript
game.enableControllerInput()   ' starts the server on port 8888
\`\`\`

Show the connection URL somewhere in your UI so a player knows what to
open:

\`\`\`brighterscript
label.setText(game.getControllerConnectionInfo())
\`\`\`

## Mapping input

\`game.controls\` (a \`BGE.Controller.ControlMap\`) is the only concept you
need: bind a logical action/axis name once, then read it every frame -
your game code never has to know whether the remote or a connected
controller produced the input.

\`\`\`brighterscript
game.controls.bindAction("jump", remoteButton: "ok", controllerButton: 0)
game.controls.bindAxis("move")

' per frame, e.g. in onUpdate/onInput:
if game.controls.isActionPressed("jump") then ...
move = game.controls.getAxis("move")   ' a BGE.Math.Vector
velocity.x = move.x * speed
velocity.y = move.y * speed
\`\`\`

\`bindAxis\`'s axis falls back to the remote d-pad whenever the bound
controller stick reads neutral, so binding once supports both input
sources automatically.

## Multiple controllers

Each connected browser is assigned its own \`playerIndex\` (0, 1, 2, ...)
in the order it connects. Pass \`playerIndex\` to \`bindAction\`/\`bindAxis\`
and to the \`isAction*\`/\`getAxis\` calls that read them for local
multiplayer; a single-player game can ignore it entirely (it defaults to 0).

## Advanced: raw controller input

Every controller button press also flows through the normal \`onInput\`
callback as a \`BGE.GameInput\`, with \`playerIndex\` set and
\`button = "controller" + <index>\` (matching the browser Gamepad API's
\`buttons[]\` order). Most games won't need this - \`ControlMap\` above is
the intended way to consume controller input.

## Limitations

- The controller page loads a small library from a public CDN - the
  *player's phone* needs internet access for the on-screen sticks to
  render (the Roku itself needs none).
- Discovery is a plain LAN URL for now; a QR code is tracked separately.

See \`examples/controller\` for a full runnable demo.
```

- [ ] **Step 2: File the QR-code follow-up issue**

Run:
```bash
gh issue create --title "QR-code discovery for controller input" \
  --body "Follow-up to #149: render the controller connection URL (Game.getControllerConnectionInfo()) as an on-screen QR code so a player can scan instead of typing it. Needs a roScreen-compatible QR renderer (see reference_scenegraph_bitmap_to_poster memory for prior QR/roBitmap art, though that's SceneGraph-specific)."
```

- [ ] **Step 3: Run the full quality gate**

Run: `npm run check`
Expected: PASS (lint + validate + headless tests).

Run: `npm run validate-examples`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add docs/controller-input.md
git commit -m "docs: add controller input guide (#149)"
```

---

## Self-Review Notes

- **Spec coverage:** A (Task 1, 5), B (Task 7), C (Task 2, 3, 6), D (Task 4), E (Task 6 `getControllerConnectionInfo`, Task 9 QR follow-up issue), F (Tasks 1/2/3/4 headless specs, Task 5/8 device verification split, Task 8 example), G (file layout matches Task 1-7 `Create:` paths). All spec sections have a task.
- **Generic utility placement:** `hexStringToByteArray` is added to `src/source/utils/utils.bs` (alongside the existing `bytesToInteger`/`bytesToFloat`) rather than kept private to `WebSocketFrameCodec`, since hex-decoding is generic and not WebSocket-specific. `bytesToShort`/`bytesToLong`/`shortToBytes`/`longToBytes` stay local to `WebSocketFrameCodec.bs` - they encode/decode WebSocket's specific big-endian 16-/64-bit length-prefix fields, not a general-purpose byte operation, so promoting them would be speculative generalization with no second caller.
- **Naming refinement vs spec:** the spec's illustrative `button = "p<playerIndex>-controller<i>"` is simplified to `button = "controller<i>"` with the already-separate `GameInput.playerIndex` field carrying the player - avoids encoding the same fact twice, per the "make it simple" pass. Documented here since it's a naming detail, not a scope change.
- **Type consistency check:** `GameInput` constructor signature (Task 2) matches every call site added in Task 6 and used in Task 4's tests. `ControllerRegistry`'s method names (`getStick`, `getRemoteDpad`, `isButtonHeld`, `getHeldTimeMs`) match exactly between Task 3's implementation and Task 4/6's consumers. `ControllerServerEventType` values (`onOpen`/`onMessage`/`onClose`) match between Task 5's producer and Task 6's consumer.
