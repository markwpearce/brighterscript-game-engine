---
title: UiWidget
kind: class
longname: BGE/UI.UiWidget
description: Base Abstract class for all UI Elements
---

# UiWidget

**Extends:&#x20;**[`BGE.GameEntity`](/bge#gameentity)

Base Abstract class for all UI Elements

**Properties**

- `customPosition` (boolean) — If position = "custom", then m.customX is horizontal position of this element from the parent position ' and m.customY is the vertical position of this element from the parent position (positive is down)
- `customX` (float)
- `customY` (float)
- `horizAlign` (string) — If customPosition is false, this dictates where horizontally in the container this element should go. Can be: "left", "center" or "right"
- `vertAlign` (string) — If customPosition is false, this dictates where vertically in the container this element should go. Can be: "top", "center" or "bottom"
- `width` (integer) — Width of the element
- `height` (integer) — Height of the element
- `canvas` ([BGE.Canvas](/bge#canvas))
- `padding` ([OffsetSize](/bge-ui#offsetsize))
- `margin` ([OffsetSize](/bge-ui#offsetsize))

---

## Constructor

<Signature code="new UiWidget(game: BGE.Game): UiWidget" />

**Parameters**

- `game` ([BGE.Game](/bge#game))

---

## Instance Methods

<MemberHeading id="getvalue" depth="3" name="getValue" sig="getValue(): dynamic" />

Function to get the value of the UI element

**Returns**

- `dynamic`

<MemberHeading id="draw" depth="3" name="draw" sig="draw(parent?: UiWidget): void" />

Method called each frame to draw any images of this entity

**Parameters**

- `parent` ([UiWidget](/bge-ui#uiwidget), optional, default: "invalid") — the parent of this Ui Element - will be an object with {x, y, width, height}

**Returns**

- `void`

<MemberHeading id="setcanvas" depth="3" name="setCanvas" sig="setCanvas(canvas?: BGE.Canvas): void" />

Set the canvas this UIWidgetDraws to

**Parameters**

- `canvas` ([BGE.Canvas](/bge#canvas), optional, default: "invalid") — The canvas this should draw to - if invalid, then will draw to the game canvas

**Returns**

- `void`

<MemberHeading id="repositionbasedonparent" depth="3" name="repositionBasedOnParent" sig="repositionBasedOnParent(parent?: UiWidget): void" />

Method called each frame to reposition

**Parameters**

- `parent` ([UiWidget](/bge-ui#uiwidget), optional, default: "invalid") — the parent of this Ui Element - will be an object with {x, y, width, height}

**Returns**

- `void`

<MemberHeading id="getworldposition" depth="3" name="getWorldPosition" sig="getWorldPosition(parent?: UiWidget): BGE.Math.Vector" />

<MemberMeta badges="protected" />

Method called each frame to draw any images of this entity

**Parameters**

- `parent` ([UiWidget](/bge-ui#uiwidget), optional, default: "invalid") — the parent of this Ui Element

**Returns**

- `BGE.Math.Vector`

<MemberHeading id="isvalid" depth="3" name="isValid" sig="isValid(): boolean" />

_Inherited from `BGE.GameEntity#isValid`_

**Overrides:&#x20;**`BGE.GameEntity#isValid`

Is this still a valid entity?

**Returns**

- `boolean`

<MemberHeading id="invalidate" depth="3" name="invalidate" sig="invalidate(): void" />

_Inherited from `BGE.GameEntity#invalidate`_

**Overrides:&#x20;**`BGE.GameEntity#invalidate`

Marks this entity as invalid, so it will be cleared/destroyed at the end of the frame

**Returns**

- `void`

<MemberHeading id="oncreate" depth="3" name="onCreate" sig="onCreate(args: roAssociativeArray): void" />

_Inherited from `BGE.GameEntity#onCreate`_

**Overrides:&#x20;**`BGE.GameEntity#onCreate`

Method to be called when this entity is added to a Game. Override in subclass

**Parameters**

- `args` (roAssociativeArray)

**Returns**

- `void`

<MemberHeading id="onupdate" depth="3" name="onUpdate" sig="onUpdate(deltaTime: float): void" />

_Inherited from `BGE.GameEntity#onUpdate`_

**Overrides:&#x20;**`BGE.GameEntity#onUpdate`

Method for handling any updates based on time since previous frame

**Parameters**

- `deltaTime` (float) — milliseconds since last frame

**Returns**

- `void`

<MemberHeading
  id="oncollision"
  depth="3"
  name="onCollision"
  sig="onCollision(
	myCollider: Collider,
	otherCollider: Collider,
	otherEntity: GameEntity,
): void"
/>

_Inherited from `BGE.GameEntity#onCollision`_

**Overrides:&#x20;**`BGE.GameEntity#onCollision`

Method for processing all collisions

**Parameters**

- `myCollider` ([Collider](/bge#collider)) — the collider of this entity that collided
- `otherCollider` ([Collider](/bge#collider)) — the collider of the other entity in the collision
- `otherEntity` ([GameEntity](/bge#gameentity)) — the entity that owns the other collider

**Returns**

- `void`

<MemberHeading
  id="ondrawbegin"
  depth="3"
  name="onDrawBegin"
  sig="onDrawBegin(
	Renderer: renderer,
	gameRenderer: Renderer,
	uiRenderer: Renderer,
): void"
/>

_Inherited from `BGE.GameEntity#onDrawBegin`_

**Overrides:&#x20;**`BGE.GameEntity#onDrawBegin`

Method called each frame before drawing any images of this entity

**Parameters**

- `Renderer` (renderer) — the Renderer images will be drawn to
- `gameRenderer` ([Renderer](/bge#renderer))
- `uiRenderer` ([Renderer](/bge#renderer))

**Returns**

- `void`

<MemberHeading
  id="ondrawend"
  depth="3"
  name="onDrawEnd"
  sig="onDrawEnd(
	canvas: Renderer,
	gameRenderer: Renderer,
	uiRenderer: Renderer,
): void"
/>

_Inherited from `BGE.GameEntity#onDrawEnd`_

**Overrides:&#x20;**`BGE.GameEntity#onDrawEnd`

Method called each frame after drawing all images of this entity

**Parameters**

- `canvas` ([Renderer](/bge#renderer)) — the Renderer images were drawn to
- `gameRenderer` ([Renderer](/bge#renderer))
- `uiRenderer` ([Renderer](/bge#renderer))

**Returns**

- `void`

<MemberHeading id="oninput" depth="3" name="onInput" sig="onInput(input: GameInput): void" />

_Inherited from `BGE.GameEntity#onInput`_

**Overrides:&#x20;**`BGE.GameEntity#onInput`

Method to process input per frame

**Parameters**

- `input` ([GameInput](/bge#gameinput)) — GameInput object for the last frame

**Returns**

- `void`

<MemberHeading id="onecpkeyboard" depth="3" name="onECPKeyboard" sig="onECPKeyboard(char: integer): void" />

_Inherited from `BGE.GameEntity#onECPKeyboard`_

**Overrides:&#x20;**`BGE.GameEntity#onECPKeyboard`

Method to process an ECP keyboard event

**Parameters**

- `char` (integer)

**Returns**

- `void`

* **See:**
  - [https://developer.roku.com/en-ca/docs/developer-program/debugging/external-control-api.md](https://developer.roku.com/en-ca/docs/developer-program/debugging/external-control-api.md)

<MemberHeading id="onecpinput" depth="3" name="onECPInput" sig="onECPInput(data: roInputEvent): void" />

_Inherited from `BGE.GameEntity#onECPInput`_

**Overrides:&#x20;**`BGE.GameEntity#onECPInput`

Method to process an External Control Protocol event

**Parameters**

- `data` (roInputEvent)

**Returns**

- `void`

* **See:**
  - [https://developer.roku.com/en-ca/docs/references/brightscript/events/roinputevent.md](https://developer.roku.com/en-ca/docs/references/brightscript/events/roinputevent.md)

<MemberHeading id="onaudioevent" depth="3" name="onAudioEvent" sig="onAudioEvent(msg: roAudioPlayerEvent): void" />

_Inherited from `BGE.GameEntity#onAudioEvent`_

**Overrides:&#x20;**`BGE.GameEntity#onAudioEvent`

Method to handle audio events

**Parameters**

- `msg` (roAudioPlayerEvent) — roAudioPlayerEvent

**Returns**

- `void`

* **See:**
  - [https://developer.roku.com/en-ca/docs/references/brightscript/events/roaudioplayerevent.md](https://developer.roku.com/en-ca/docs/references/brightscript/events/roaudioplayerevent.md)

<MemberHeading id="onpause" depth="3" name="onPause" sig="onPause(): void" />

_Inherited from `BGE.GameEntity#onPause`_

**Overrides:&#x20;**`BGE.GameEntity#onPause`

Called when the game pauses

**Returns**

- `void`

<MemberHeading id="onresume" depth="3" name="onResume" sig="onResume(pauseTimeMs: integer): void" />

_Inherited from `BGE.GameEntity#onResume`_

**Overrides:&#x20;**`BGE.GameEntity#onResume`

Called when the game unpauses

**Parameters**

- `pauseTimeMs` (integer) — The number of milliseconds the game was paused

**Returns**

- `void`

<MemberHeading id="onurlevent" depth="3" name="onUrlEvent" sig="onUrlEvent(msg: roUrlEvent): void" />

_Inherited from `BGE.GameEntity#onUrlEvent`_

**Overrides:&#x20;**`BGE.GameEntity#onUrlEvent`

Called on url event

**Parameters**

- `msg` (roUrlEvent) — roUrlEvent

**Returns**

- `void`

* **See:**
  - [https://developer.roku.com/en-ca/docs/references/brightscript/events/rourlevent.md](https://developer.roku.com/en-ca/docs/references/brightscript/events/rourlevent.md)

<MemberHeading id="ongameevent" depth="3" name="onGameEvent" sig="onGameEvent(eventName: string, data: roAssociativeArray): void" />

_Inherited from `BGE.GameEntity#onGameEvent`_

**Overrides:&#x20;**`BGE.GameEntity#onGameEvent`

General purpose event handler for in-game events.

**Parameters**

- `eventName` (string) — Event name that describes the event type
- `data` (roAssociativeArray) — Any extra data to go along with the event

**Returns**

- `void`

<MemberHeading id="onchangeroom" depth="3" name="onChangeRoom" sig="onChangeRoom(newRoom: Room): void" />

_Inherited from `BGE.GameEntity#onChangeRoom`_

**Overrides:&#x20;**`BGE.GameEntity#onChangeRoom`

Method called when the current room changes. This method is only called when the entity is marked as `persistant`, otherwise entities are destroyed on room changes.

**Parameters**

- `newRoom` ([Room](/bge#room)) — The next room

**Returns**

- `void`

<MemberHeading id="ondestroy" depth="3" name="onDestroy" sig="onDestroy(): void" />

_Inherited from `BGE.GameEntity#onDestroy`_

**Overrides:&#x20;**`BGE.GameEntity#onDestroy`

Method called when this entity is destroyed

**Returns**

- `void`

<MemberHeading
  id="addcirclecollider"
  depth="3"
  name="addCircleCollider"
  sig="addCircleCollider(
	colliderName: string,
	radius: float,
	offset_x?: float,
	offset_y?: float,
	enabled?: boolean,
): CircleCollider"
/>

_Inherited from `BGE.GameEntity#addCircleCollider`_

**Overrides:&#x20;**`BGE.GameEntity#addCircleCollider`

Adds a circle collider to this entity

**Parameters**

- `colliderName` (string) — Name of the collider (only one collider with the same name can be added)
- `radius` (float) — radius of the circle
- `offset_x` (float, optional, default: 0) — horizontal offset from entity position of centre of the circle
- `offset_y` (float, optional, default: 0) — vertical offset from entity position of centre of the circle
- `enabled` (boolean, optional, default: true) — is this collider enabled?

**Returns**

- [`CircleCollider`](/bge#circlecollider)

<MemberHeading
  id="addrectanglecollider"
  depth="3"
  name="addRectangleCollider"
  sig="addRectangleCollider(
	colliderName: string,
	width: float,
	height: float,
	offset_x?: float,
	offset_y?: float,
	enabled?: boolean,
): RectangleCollider"
/>

_Inherited from `BGE.GameEntity#addRectangleCollider`_

**Overrides:&#x20;**`BGE.GameEntity#addRectangleCollider`

Adds a rectangle collider to this entity

**Parameters**

- `colliderName` (string) — Name of the collider (only one collider with the same name can be added)
- `width` (float) — Width of rectangle
- `height` (float) — Height of rectangle
- `offset_x` (float, optional, default: 0) — horizontal offset from entity position of left edge of rectangle
- `offset_y` (float, optional, default: 0) — vertical offset from entity position of bottom edge of rectangle (top edge is at offset\_y - height)
- `enabled` (boolean, optional, default: true) — is this collider enabled?

**Returns**

- [`RectangleCollider`](/bge#rectanglecollider)

<MemberHeading id="addcollider" depth="3" name="addCollider" sig="addCollider(colliderToAdd: Collider): Collider" />

_Inherited from `BGE.GameEntity#addCollider`_

**Overrides:&#x20;**`BGE.GameEntity#addCollider`

Adds a collider that has already been constructed

**Parameters**

- `colliderToAdd` ([Collider](/bge#collider)) — the collider to add (only one collider with the same name can be added)

**Returns**

- [`Collider`](/bge#collider)

<MemberHeading id="getcollider" depth="3" name="getCollider" sig="getCollider(colliderName: string): Collider" />

_Inherited from `BGE.GameEntity#getCollider`_

**Overrides:&#x20;**`BGE.GameEntity#getCollider`

Gets a collider based on its name

**Parameters**

- `colliderName` (string) — The name of the collider to find

**Returns**

- [`Collider`](/bge#collider)

<MemberHeading id="removecollider" depth="3" name="removeCollider" sig="removeCollider(colliderName: string): void" />

_Inherited from `BGE.GameEntity#removeCollider`_

**Overrides:&#x20;**`BGE.GameEntity#removeCollider`

Removes a collider by its name

**Parameters**

- `colliderName` (string) — the name of the collider to remove

**Returns**

- `void`

<MemberHeading id="clearallcolliders" depth="3" name="clearAllColliders" sig="clearAllColliders(): void" />

_Inherited from `BGE.GameEntity#clearAllColliders`_

**Overrides:&#x20;**`BGE.GameEntity#clearAllColliders`

Remove all colliders from this entity

**Returns**

- `void`

<MemberHeading
  id="addimage"
  depth="3"
  name="addImage"
  sig="addImage(
	regionName?: string,
	imageName: string,
	region: roRegion,
	args?: roAssociativeArray,
	insertPosition?: integer,
): Image"
/>

_Inherited from `BGE.GameEntity#addImage`_

**Overrides:&#x20;**`BGE.GameEntity#addImage`

Adds a basic image (non-animated) to be drawn for this entity

**Parameters**

- `regionName` (string, optional, default: "\\"\\"") — an optional unique name for the region, used for caching image data
- `imageName` (string) — Name of the image
- `region` (roRegion) — an `roRegion` of a bitmap to draw
- `args` (roAssociativeArray, optional, default: "{}") — any extra properties to set (e.g. offset\_x, offset\_y, rotation, scale\_x, scale\_y, etc.)
- `insertPosition` (integer, optional, default: -1) — the position/order in the images array where the image should be added (defaults to being added at the end)

**Returns**

- [`Image`](/bge#image)

<MemberHeading
  id="addanimatedimage"
  depth="3"
  name="addAnimatedImage"
  sig="addAnimatedImage(
	imageName: string,
	regions: Array.<roRegion>,
	args?: roAssociativeArray,
	insertPosition?: integer,
): AnimatedImage"
/>

_Inherited from `BGE.GameEntity#addAnimatedImage`_

**Overrides:&#x20;**`BGE.GameEntity#addAnimatedImage`

Adds a animated image to be drawn for this entity. Animated images cycle through regions of a bitmap (e.g. spritesheet)

**Parameters**

- `imageName` (string) — Name of the image
- `regions` (Array.\<roRegion>) — an array of `roRegion` of a bitmap to draw
- `args` (roAssociativeArray, optional, default: "{}") — any extra properties to set (e.g. offset\_x, offset\_y, rotation, scale\_x, scale\_y, etc.)
- `insertPosition` (integer, optional, default: -1) — the position/order in the images array where the image should be added (defaults to being added at the end)

**Returns**

- [`AnimatedImage`](/bge#animatedimage)

<MemberHeading
  id="addsprite"
  depth="3"
  name="addSprite"
  sig="addSprite(
	bitmap: roBitmap,
	imageName: string,
	spriteSheet: roBitmap,
	cellWidth: integer,
	cellHeight: integer,
	args?: roAssociativeArray,
	insertPosition?: integer,
): Sprite"
/>

_Inherited from `BGE.GameEntity#addSprite`_

**Overrides:&#x20;**`BGE.GameEntity#addSprite`

Adds a Sprite to be drawn for this entity. Sprites can have specific animations configured buy choosing series of cells from a sprite sheet

**Parameters**

- `bitmap` (roBitmap) — the bitmap object to use for teh SpriteSheet (e.g response from game.getBitmap("bitmap\_name"))
- `imageName` (string) — Name of the image
- `spriteSheet` (roBitmap)
- `cellWidth` (integer) — the height in pixels of a dingle cell in the sprite
- `cellHeight` (integer) — the height in pixels of a dingle cell in the sprite
- `args` (roAssociativeArray, optional, default: "{}") — any extra properties to set (e.g. offset\_x, offset\_y, rotation, scale\_x, scale\_y, etc.)
- `insertPosition` (integer, optional, default: -1) — the position/order in the images array where the image should be added (defaults to being added at the end)

**Returns**

- [`Sprite`](/bge#sprite)

<MemberHeading
  id="adddrawable"
  depth="3"
  name="addDrawable"
  sig="addDrawable(
	imageName: string,
	drawableObject: Drawable,
	insertPosition?: integer,
): Drawable"
/>

_Inherited from `BGE.GameEntity#addDrawable`_

**Overrides:&#x20;**`BGE.GameEntity#addDrawable`

Adds any Drawable/Image object to this entity

**Parameters**

- `imageName` (string) — Name of the image
- `drawableObject` ([Drawable](/bge#drawable)) — The image to be added
- `insertPosition` (integer, optional, default: -1) — the position/order in the images array where the image should be added (defaults to being added at the end)

**Returns**

- [`Drawable`](/bge#drawable)

<MemberHeading id="getdrawable" depth="3" name="getDrawable" sig="getDrawable(imageName: string, drawableName: string): Drawable" />

_Inherited from `BGE.GameEntity#getDrawable`_

**Overrides:&#x20;**`BGE.GameEntity#getDrawable`

Gets a drawable by its name from the lookup table

**Parameters**

- `imageName` (string) — Name of drawable to get
- `drawableName` (string)

**Returns**

- [`Drawable`](/bge#drawable)

<MemberHeading id="removedrawable" depth="3" name="removeDrawable" sig="removeDrawable(drawableName: string): void" />

_Inherited from `BGE.GameEntity#removeDrawable`_

**Overrides:&#x20;**`BGE.GameEntity#removeDrawable`

Removes a drawable from the entity

**Parameters**

- `drawableName` (string) — Name of drawable to remove

**Returns**

- `void`

<MemberHeading id="updatetransformationmatrix" depth="3" name="updateTransformationMatrix" sig="updateTransformationMatrix(): void" />

_Inherited from `BGE.GameEntity#updateTransformationMatrix`_

**Overrides:&#x20;**`BGE.GameEntity#updateTransformationMatrix`

**Returns**

- `void`

<MemberHeading id="movedlastframe" depth="3" name="movedLastFrame" sig="movedLastFrame(): boolean" />

_Inherited from `BGE.GameEntity#movedLastFrame`_

**Overrides:&#x20;**`BGE.GameEntity#movedLastFrame`

**Returns**

- `boolean`

<MemberHeading id="getstaticvariable" depth="3" name="getStaticVariable" sig="getStaticVariable(staticVariableName: string): dynamic" />

_Inherited from `BGE.GameEntity#getStaticVariable`_

**Overrides:&#x20;**`BGE.GameEntity#getStaticVariable`

TODO: work on statics

**Parameters**

- `staticVariableName` (string)

**Returns**

- `dynamic`

<MemberHeading
  id="setstaticvariable"
  depth="3"
  name="setStaticVariable"
  sig="setStaticVariable(
	staticVariableName: string,
	staticVariableValue: dynamic,
): void"
/>

_Inherited from `BGE.GameEntity#setStaticVariable`_

**Overrides:&#x20;**`BGE.GameEntity#setStaticVariable`

TODO: work on statics

**Parameters**

- `staticVariableName` (string)
- `staticVariableValue` (dynamic)

**Returns**

- `void`

<MemberHeading id="addinterface" depth="3" name="addInterface" sig="addInterface(interfaceName: string): void" />

_Inherited from `BGE.GameEntity#addInterface`_

**Overrides:&#x20;**`BGE.GameEntity#addInterface`

TODO: work on Interfaces

**Parameters**

- `interfaceName` (string)

**Returns**

- `void`

<MemberHeading id="hasinterface" depth="3" name="hasInterface" sig="hasInterface(interfaceName: string): boolean" />

_Inherited from `BGE.GameEntity#hasInterface`_

**Overrides:&#x20;**`BGE.GameEntity#hasInterface`

TODO: work on Interfaces

**Parameters**

- `interfaceName` (string)

**Returns**

- `boolean`

<MemberHeading
  id="debugdraw"
  depth="3"
  name="debugDraw"
  sig="debugDraw(
	renderObj: Renderer,
	drawAxes?: boolean,
	drawName?: boolean,
): void"
/>

_Inherited from `BGE.GameEntity#debugDraw`_

**Overrides:&#x20;**`BGE.GameEntity#debugDraw`

Draws the entity's axes and/or its name

**Parameters**

- `renderObj` ([Renderer](/bge#renderer))
- `drawAxes` (boolean, optional, default: false)
- `drawName` (boolean, optional, default: false)

**Returns**

- `void`
