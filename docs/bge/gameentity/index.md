---
title: GameEntity
kind: class
longname: BGE.GameEntity
description: Every thing (character, player, object, etc) in the game should extend this class. This class has a number of empty methods that are designed to be overridden in subclasses. For example, override onInput() to handle input event, and onUpdate() to handle updating each frame
---

# GameEntity

Every thing (character, player, object, etc) in the game should extend this class. This class has a number of empty methods that are designed to be overridden in subclasses. For example, override `onInput()` to handle input event, and `onUpdate()` to handle updating each frame

**Properties**

- `name` (string) — Constant - name of this Entity
- `id` (dynamic) — Constant - Unique Id
- `game` ([Game](/bge#game))
- `enabled` (boolean) — Is this GameEntity enabled
- `persistent` (boolean) — Does this entity persist across room changes?
- `pauseable` (boolean) — When the game is paused, does this entity pause too?
- `position` (dynamic) — position of where this entity is in game world
- `velocity` (dynamic) — Speed of this entity, in units/second (not units/frame) - added to position each frame scaled by elapsed time
- `rotation` (dynamic) — Rotation of entity - applies to all images
- `scale` (dynamic) — Scale of entity - applies to all images
- `colliders` (roAssociativeArray) — The colliders for this entity by name
- `drawables` (dynamic) — The array of drawables to draw for this entity
- `drawablesByName` (roAssociativeArray) — Associative array of drawables by name
- `tagsList` (dynamic) — Game Entities can be tagged with any number of tags so they can be easily identified (e.g. "enemy", "wall", etc.)
- `transformationMatrix` (dynamic) — The Current Transformation Matrix
- `motionChecker` ([MotionChecker](/bge#motionchecker))

---

## Constructor

<Signature
  code="new GameEntity(
	game: Game,
	gameEngine: Game,
	args?: roAssociativeArray,
): GameEntity"
/>

Creates a new GameEntity

**Parameters**

- `game` ([Game](/bge#game)) — The game engine that this entity is going to be assigned to
- `gameEngine` ([Game](/bge#game))
- `args` (roAssociativeArray, optional, default: "{}") — Any extra properties to be added to this entity

---

## Instance Methods

<MemberHeading id="isvalid" depth="3" name="isValid" sig="isValid(): boolean" />

Is this still a valid entity?

**Returns**

- `boolean`

<MemberHeading id="invalidate" depth="3" name="invalidate" sig="invalidate(): void" />

Marks this entity as invalid, so it will be cleared/destroyed at the end of the frame

**Returns**

- `void`

<MemberHeading id="oncreate" depth="3" name="onCreate" sig="onCreate(args: roAssociativeArray): void" />

Method to be called when this entity is added to a Game. Override in subclass

**Parameters**

- `args` (roAssociativeArray)

**Returns**

- `void`

<MemberHeading id="onupdate" depth="3" name="onUpdate" sig="onUpdate(deltaTime: float): void" />

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

Method called each frame after drawing all images of this entity

**Parameters**

- `canvas` ([Renderer](/bge#renderer)) — the Renderer images were drawn to
- `gameRenderer` ([Renderer](/bge#renderer))
- `uiRenderer` ([Renderer](/bge#renderer))

**Returns**

- `void`

<MemberHeading id="oninput" depth="3" name="onInput" sig="onInput(input: GameInput): void" />

Method to process input per frame

**Parameters**

- `input` ([GameInput](/bge#gameinput)) — GameInput object for the last frame

**Returns**

- `void`

<MemberHeading id="onecpkeyboard" depth="3" name="onECPKeyboard" sig="onECPKeyboard(char: integer): void" />

Method to process an ECP keyboard event

**Parameters**

- `char` (integer)

**Returns**

- `void`

* **See:**
  - [https://developer.roku.com/en-ca/docs/developer-program/debugging/external-control-api.md](https://developer.roku.com/en-ca/docs/developer-program/debugging/external-control-api.md)

<MemberHeading id="onecpinput" depth="3" name="onECPInput" sig="onECPInput(data: roInputEvent): void" />

Method to process an External Control Protocol event

**Parameters**

- `data` (roInputEvent)

**Returns**

- `void`

* **See:**
  - [https://developer.roku.com/en-ca/docs/references/brightscript/events/roinputevent.md](https://developer.roku.com/en-ca/docs/references/brightscript/events/roinputevent.md)

<MemberHeading id="onaudioevent" depth="3" name="onAudioEvent" sig="onAudioEvent(msg: roAudioPlayerEvent): void" />

Method to handle audio events

**Parameters**

- `msg` (roAudioPlayerEvent) — roAudioPlayerEvent

**Returns**

- `void`

* **See:**
  - [https://developer.roku.com/en-ca/docs/references/brightscript/events/roaudioplayerevent.md](https://developer.roku.com/en-ca/docs/references/brightscript/events/roaudioplayerevent.md)

<MemberHeading id="onpause" depth="3" name="onPause" sig="onPause(): void" />

Called when the game pauses

**Returns**

- `void`

<MemberHeading id="onresume" depth="3" name="onResume" sig="onResume(pauseTimeMs: integer): void" />

Called when the game unpauses

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
  - [https://developer.roku.com/en-ca/docs/references/brightscript/events/rourlevent.md](https://developer.roku.com/en-ca/docs/references/brightscript/events/rourlevent.md)

<MemberHeading id="ongameevent" depth="3" name="onGameEvent" sig="onGameEvent(eventName: string, data: roAssociativeArray): void" />

General purpose event handler for in-game events.

**Parameters**

- `eventName` (string) — Event name that describes the event type
- `data` (roAssociativeArray) — Any extra data to go along with the event

**Returns**

- `void`

<MemberHeading id="onchangeroom" depth="3" name="onChangeRoom" sig="onChangeRoom(newRoom: Room): void" />

Method called when the current room changes. This method is only called when the entity is marked as `persistant`, otherwise entities are destroyed on room changes.

**Parameters**

- `newRoom` ([Room](/bge#room)) — The next room

**Returns**

- `void`

<MemberHeading id="ondestroy" depth="3" name="onDestroy" sig="onDestroy(): void" />

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

Adds a collider that has already been constructed

**Parameters**

- `colliderToAdd` ([Collider](/bge#collider)) — the collider to add (only one collider with the same name can be added)

**Returns**

- [`Collider`](/bge#collider)

<MemberHeading id="getcollider" depth="3" name="getCollider" sig="getCollider(colliderName: string): Collider" />

Gets a collider based on its name

**Parameters**

- `colliderName` (string) — The name of the collider to find

**Returns**

- [`Collider`](/bge#collider)

<MemberHeading id="removecollider" depth="3" name="removeCollider" sig="removeCollider(colliderName: string): void" />

Removes a collider by its name

**Parameters**

- `colliderName` (string) — the name of the collider to remove

**Returns**

- `void`

<MemberHeading id="clearallcolliders" depth="3" name="clearAllColliders" sig="clearAllColliders(): void" />

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

Adds any Drawable/Image object to this entity

**Parameters**

- `imageName` (string) — Name of the image
- `drawableObject` ([Drawable](/bge#drawable)) — The image to be added
- `insertPosition` (integer, optional, default: -1) — the position/order in the images array where the image should be added (defaults to being added at the end)

**Returns**

- [`Drawable`](/bge#drawable)

<MemberHeading id="getdrawable" depth="3" name="getDrawable" sig="getDrawable(imageName: string, drawableName: string): Drawable" />

Gets a drawable by its name from the lookup table

**Parameters**

- `imageName` (string) — Name of drawable to get
- `drawableName` (string)

**Returns**

- [`Drawable`](/bge#drawable)

<MemberHeading id="removedrawable" depth="3" name="removeDrawable" sig="removeDrawable(drawableName: string): void" />

Removes a drawable from the entity

**Parameters**

- `drawableName` (string) — Name of drawable to remove

**Returns**

- `void`

<MemberHeading id="updatetransformationmatrix" depth="3" name="updateTransformationMatrix" sig="updateTransformationMatrix(): void" />

**Returns**

- `void`

<MemberHeading id="movedlastframe" depth="3" name="movedLastFrame" sig="movedLastFrame(): boolean" />

**Returns**

- `boolean`

<MemberHeading id="getstaticvariable" depth="3" name="getStaticVariable" sig="getStaticVariable(staticVariableName: string): dynamic" />

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

TODO: work on statics

**Parameters**

- `staticVariableName` (string)
- `staticVariableValue` (dynamic)

**Returns**

- `void`

<MemberHeading id="addinterface" depth="3" name="addInterface" sig="addInterface(interfaceName: string): void" />

TODO: work on Interfaces

**Parameters**

- `interfaceName` (string)

**Returns**

- `void`

<MemberHeading id="hasinterface" depth="3" name="hasInterface" sig="hasInterface(interfaceName: string): boolean" />

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

Draws the entity's axes and/or its name

**Parameters**

- `renderObj` ([Renderer](/bge#renderer))
- `drawAxes` (boolean, optional, default: false)
- `drawName` (boolean, optional, default: false)

**Returns**

- `void`
