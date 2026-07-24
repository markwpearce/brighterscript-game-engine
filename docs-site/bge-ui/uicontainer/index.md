---
title: UiContainer
kind: class
longname: BGE/UI.UiContainer
---

# UiContainer

**Extends:&#x20;**`BGE.UI.UiWidget`

**Properties**

- `backgroundRGBA` (integer) — RGBA value for the background of the window/container
- `showBackground` (boolean) — RGBA value for the background of the window/container
- `children` (dynamic)

---

## Constructor

<Signature code="new UiContainer(game: BGE.Game): UiContainer" />

**Parameters**

- `game` ([BGE.Game](/bge#game))

---

## Instance Methods

<MemberHeading id="onremove" depth="3" name="onRemove" sig="onRemove(): void" />

Method for handling any actions needed when this is removed from view Clears all children

**Returns**

- `void`

<MemberHeading id="addchild" depth="3" name="addChild" sig="addChild(element: UiWidget): void" />

**Parameters**

- `element` ([UiWidget](/bge-ui#uiwidget))

**Returns**

- `void`

<MemberHeading id="removechild" depth="3" name="removeChild" sig="removeChild(element: UiWidget): void" />

**Parameters**

- `element` ([UiWidget](/bge-ui#uiwidget))

**Returns**

- `void`

<MemberHeading id="clearchildren" depth="3" name="clearChildren" sig="clearChildren(): void" />

**Returns**

- `void`

<MemberHeading id="onupdate" depth="3" name="onUpdate" sig="onUpdate(deltaTime: float): void" />

Method for handling any updates based on time since previous frame Calls same method in all children

**Parameters**

- `deltaTime` (float) — milliseconds since last frame

**Returns**

- `void`

<MemberHeading id="setcanvas" depth="3" name="setCanvas" sig="setCanvas(canvas?: BGE.Canvas): void" />

Set the canvas this UIWidget Draws to Sets the canvas on all children

**Parameters**

- `canvas` ([BGE.Canvas](/bge#canvas), optional, default: "invalid") — The canvas this should draw to - if invalid, then will draw to the game canvas

**Returns**

- `void`

<MemberHeading id="draw" depth="3" name="draw" sig="draw(): void" />

Method called each frame to draw any images of this entity

**Returns**

- `void`

<MemberHeading id="getvalue" depth="3" name="getValue" sig="getValue(): void" />

Function to get the value of the UIContainer, which will be an object of all the values of the children

**Returns**

- `void`

<MemberHeading id="oninput" depth="3" name="onInput" sig="onInput(input: BGE.GameInput): void" />

Method to process input per frame Calls same method in all children

**Parameters**

- `input` ([BGE.GameInput](/bge#gameinput)) — GameInput object for the last frame

**Returns**

- `void`

<MemberHeading id="onecpkeyboard" depth="3" name="onECPKeyboard" sig="onECPKeyboard(char: integer): void" />

Method to process an ECP keyboard event

**Parameters**

- `char` (integer)

**Returns**

- `void`

* **See:**
  - [https://developer.roku.com/en-ca/docs/developer-program/debugging/external-control-api.md
    Calls same method in all children](<https://developer.roku.com/en-ca/docs/developer-program/debugging/external-control-api.md&#xA;Calls same method in all children>)

<MemberHeading id="onecpinput" depth="3" name="onECPInput" sig="onECPInput(data: roInputEvent): void" />

Method to process an External Control Protocol event

**Parameters**

- `data` (roInputEvent)

**Returns**

- `void`

* **See:**
  - [https://developer.roku.com/en-ca/docs/references/brightscript/events/roinputevent.md
    Calls same method in all children](<https://developer.roku.com/en-ca/docs/references/brightscript/events/roinputevent.md&#xA;Calls same method in all children>)

<MemberHeading id="onaudioevent" depth="3" name="onAudioEvent" sig="onAudioEvent(msg: roAudioPlayerEvent): void" />

Method to handle audio events

**Parameters**

- `msg` (roAudioPlayerEvent) — roAudioPlayerEvent

**Returns**

- `void`

* **See:**
  - [https://developer.roku.com/en-ca/docs/references/brightscript/events/roaudioplayerevent.md
    Calls same method in all children](<https://developer.roku.com/en-ca/docs/references/brightscript/events/roaudioplayerevent.md&#xA;Calls same method in all children>)

<MemberHeading id="onpause" depth="3" name="onPause" sig="onPause(): void" />

Called when the game pauses Calls same method in all children

**Returns**

- `void`

<MemberHeading id="onresume" depth="3" name="onResume" sig="onResume(pauseTimeMs: integer): void" />

Called when the game unpauses Calls same method in all children

**Parameters**

- `pauseTimeMs` (integer) — The number of milliseconds the game was paused

**Returns**

- `void`

<MemberHeading id="onurlevent" depth="3" name="onUrlEvent" sig="onUrlEvent(msg: roUrlEvent): void" />

Called on url event

**Parameters**

- `msg` (roUrlEvent) — roUrlEvent

**Returns**

- `void`

* **See:**
  - [https://developer.roku.com/en-ca/docs/references/brightscript/events/rourlevent.md
    Calls same method in all children](<https://developer.roku.com/en-ca/docs/references/brightscript/events/rourlevent.md&#xA;Calls same method in all children>)

<MemberHeading id="ongameevent" depth="3" name="onGameEvent" sig="onGameEvent(eventName: string, data: roAssociativeArray): void" />

General purpose event handler for in-game events. Calls same method in all children

**Parameters**

- `eventName` (string) — Event name that describes the event type
- `data` (roAssociativeArray) — Any extra data to go along with the event

**Returns**

- `void`

<MemberHeading id="onchangeroom" depth="3" name="onChangeRoom" sig="onChangeRoom(newRoom: Room): void" />

Method called when the current room changes. This method is only called when the entity is marked as `persistant`, otherwise entities are destroyed on room changes. Calls same method in all children

**Parameters**

- `newRoom` ([Room](/bge#room)) — The next room

**Returns**

- `void`

<MemberHeading id="ondestroy" depth="3" name="onDestroy" sig="onDestroy(): void" />

Method called when this entity is destroyed

**Returns**

- `void`
