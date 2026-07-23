---
title: GameInput
kind: class
longname: BGE.GameInput
description: Class that contains all information about the current input during a given frame from the remote
---

# GameInput

Class that contains all information about the current input during a given frame from the remote

**Properties**

- `button` (string) — The name of the button associated with the current input
- `buttonCode` (integer) — The code for the input
- `press` (boolean) — Was the button pressed since the last frame
- `held` (boolean) — Was the button held down since last frame
- `release` (boolean) — Was the button released this frame
- `heldTimeMs` (integer) — How many milliseconds was the current input held for
- `x` (float) — Current horizontal directional input: left -> -1, right -> 1
- `y` (float) — Current vertical directional input, in world space (+y is up, matching ' the engine's world coordinate convention - the renderer flips this when ' projecting to raster/canvas space): up -> 1, down -> -1

**Example**

```js
' -------Button Code Reference--------
' Button  Pressed Released  Held
' ------------------------------
' Back         0      100   1000
' Up           2      102   1002
' Down         3      103   1003
' Left         4      104   1004
' Right        5      105   1005
' OK           6      106   1006
' Replay       7      107   1007
' Rewind       8      108   1008
' FastForward  9      109   1009
' Options     10      110   1010
' Play        13      113   1013
```

---

## Constructor

<Signature
  code="new GameInput(
	buttonCode: integer,
	heldTimeMs: integer,
): GameInput"
/>

Creates a GameInput object based on the buttonCode

**Parameters**

- `buttonCode` (integer) — button to use for the data
- `heldTimeMs` (integer) — how long was this button held for

---

## Instance Methods

<MemberHeading id="isbutton" depth="3" name="isButton" sig="isButton(buttonName: string): boolean" />

Is this input for the given button name?

**Parameters**

- `buttonName` (string) — the button name to check (case insensitive - e.g. "ok" is same as "OK")

**Returns**

- `boolean`

<MemberHeading id="isdirectionalarrow" depth="3" name="isDirectionalArrow" sig="isDirectionalArrow(): boolean" />

Is this input from the directional pad

**Returns**

- `boolean`
