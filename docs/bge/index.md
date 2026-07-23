---
title: BGE
kind: namespace
longname: BGE
---

# BGE

---

## Static Methods

<MemberHeading
  id="getnewmemoryscratchregion"
  depth="3"
  name="getNewMemoryScratchRegion"
  sig="getNewMemoryScratchRegion(
	width: float,
	height: float,
): ScratchRegion"
/>

<MemberMeta badges="static" />

**Parameters**

- `width` (float)
- `height` (float)

**Returns**

- [`ScratchRegion`](/bge#scratchregion)

<MemberHeading id="isbackfacedrawmode" depth="3" name="isBackFaceDrawMode" sig="isBackFaceDrawMode(drawMode: SceneObjectDrawMode): boolean" />

<MemberMeta badges="static" />

**Parameters**

- `drawMode` ([SceneObjectDrawMode](/bge#sceneobjectdrawmode))

**Returns**

- `boolean`

<MemberHeading id="isdirectdrawmode" depth="3" name="isDirectDrawMode" sig="isDirectDrawMode(drawMode: SceneObjectDrawMode): boolean" />

<MemberMeta badges="static" />

**Parameters**

- `drawMode` ([SceneObjectDrawMode](/bge#sceneobjectdrawmode))

**Returns**

- `boolean`

<MemberHeading id="isorienteddrawmode" depth="3" name="isOrientedDrawMode" sig="isOrientedDrawMode(drawMode: SceneObjectDrawMode): boolean" />

<MemberMeta badges="static" />

**Parameters**

- `drawMode` ([SceneObjectDrawMode](/bge#sceneobjectdrawmode))

**Returns**

- `boolean`

<MemberHeading id="iswireframedrawmode" depth="3" name="isWireFrameDrawMode" sig="isWireFrameDrawMode(drawMode: SceneObjectDrawMode): boolean" />

<MemberMeta badges="static" />

**Parameters**

- `drawMode` ([SceneObjectDrawMode](/bge#sceneobjectdrawmode))

**Returns**

- `boolean`

<MemberHeading id="issoliddrawmode" depth="3" name="isSolidDrawMode" sig="isSolidDrawMode(drawMode: SceneObjectDrawMode): boolean" />

<MemberMeta badges="static" />

**Parameters**

- `drawMode` ([SceneObjectDrawMode](/bge#sceneobjectdrawmode))

**Returns**

- `boolean`

<MemberHeading id="isfulldrawmode" depth="3" name="isFullDrawMode" sig="isFullDrawMode(drawMode: SceneObjectDrawMode): boolean" />

<MemberMeta badges="static" />

**Parameters**

- `drawMode` ([SceneObjectDrawMode](/bge#sceneobjectdrawmode))

**Returns**

- `boolean`

<MemberHeading id="getdrawmodebooleanlookuparray" depth="3" name="getDrawModeBooleanLookupArray" sig="getDrawModeBooleanLookupArray(defaultValue?: boolean): dynamic" />

<MemberMeta badges="static" />

**Parameters**

- `defaultValue` (boolean, optional, default: false)

**Returns**

- `dynamic`

<MemberHeading
  id="getdotproductfromsurfacetocamera"
  depth="3"
  name="getDotProductFromSurfaceToCamera"
  sig="getDotProductFromSurfaceToCamera(
	rendererObj: BGE.Renderer,
	facePoint: BGE.Math.Vector,
	faceNormal: BGE.Math.Vector,
): float"
/>

<MemberMeta badges="static" />

**Parameters**

- `rendererObj` ([BGE.Renderer](/bge#renderer))
- `facePoint` (BGE.Math.Vector)
- `faceNormal` (BGE.Math.Vector)

**Returns**

- `float`

<MemberHeading
  id="isnormalfacingcamera"
  depth="3"
  name="isNormalFacingCamera"
  sig="isNormalFacingCamera(
	rendererObj: BGE.Renderer,
	facePoint: BGE.Math.Vector,
	faceNormal: BGE.Math.Vector,
): boolean"
/>

<MemberMeta badges="static" />

**Parameters**

- `rendererObj` ([BGE.Renderer](/bge#renderer))
- `facePoint` (BGE.Math.Vector)
- `faceNormal` (BGE.Math.Vector)

**Returns**

- `boolean`

<MemberHeading
  id="hsvtorgba"
  depth="3"
  name="HSVtoRGBA"
  sig="HSVtoRGBA(
	hPercent: float,
	sPercent: float,
	vPercent: float,
	a?: integer,
): integer"
/>

<MemberMeta badges="static" />

**Parameters**

- `hPercent` (float)
- `sPercent` (float)
- `vPercent` (float)
- `a` (integer, optional, default: -1)

**Returns**

- `integer`

<MemberHeading
  id="rgbatorgba"
  depth="3"
  name="RGBAtoRGBA"
  sig="RGBAtoRGBA(
	red: integer,
	green: integer,
	blue: integer,
	alpha?: float,
): integer"
/>

<MemberMeta badges="static" />

**Parameters**

- `red` (integer)
- `green` (integer)
- `blue` (integer)
- `alpha` (float, optional, default: 1)

**Returns**

- `integer`

<MemberHeading id="getcolor" depth="3" name="GetColor" sig="GetColor(name: string): integer" />

<MemberMeta badges="static" />

Looks up a BGE.Colors value by name (case-insensitive). Falls back to White for a name that isn't a known color.

**Parameters**

- `name` (string)

**Returns**

- `integer`

<MemberHeading id="getcolorrgb" depth="3" name="GetColorRGB" sig="GetColorRGB(name: string): integer" />

<MemberMeta badges="static" />

Looks up a BGE.ColorsRGB value by name (case-insensitive). Falls back to White for a name that isn't a known color.

**Parameters**

- `name` (string)

**Returns**

- `integer`

<MemberHeading
  id="getrandomcolorrgb"
  depth="3"
  name="getRandomColorRGB"
  sig="getRandomColorRGB(
	r?: integer,
	g?: integer,
	b?: integer,
): integer"
/>

<MemberMeta badges="static" />

**Parameters**

- `r` (integer, optional, default: 255)
- `g` (integer, optional, default: 255)
- `b` (integer, optional, default: 255)

**Returns**

- `integer`

<MemberHeading
  id="getrandomcolorrgba"
  depth="3"
  name="getRandomColorRGBA"
  sig="getRandomColorRGBA(
	r?: integer,
	g?: integer,
	b?: integer,
	a?: integer,
): integer"
/>

<MemberMeta badges="static" />

**Parameters**

- `r` (integer, optional, default: 255)
- `g` (integer, optional, default: 255)
- `b` (integer, optional, default: 255)
- `a` (integer, optional, default: 255)

**Returns**

- `integer`

<MemberHeading id="colorbrightness" depth="3" name="colorBrightness" sig="colorBrightness(rgba: integer, brightness: float): integer" />

<MemberMeta badges="static" />

**Parameters**

- `rgba` (integer)
- `brightness` (float)

**Returns**

- `integer`

<MemberHeading
  id="registrywrite"
  depth="3"
  name="registryWrite"
  sig="registryWrite(
	registry_section: string,
	key: string,
	value: dynamic,
): void"
/>

<MemberMeta badges="static" />

**Parameters**

- `registry_section` (string)
- `key` (string)
- `value` (dynamic)

**Returns**

- `void`

<MemberHeading
  id="registryread"
  depth="3"
  name="registryRead"
  sig="registryRead(
	registry_section: string,
	key: string,
	default_value?: dynamic,
): dynamic"
/>

<MemberMeta badges="static" />

**Parameters**

- `registry_section` (string)
- `key` (string)
- `default_value` (dynamic, optional, default: "invalid")

**Returns**

- `dynamic`

<MemberHeading id="getnumberoflinesinastring" depth="3" name="getNumberOfLinesInAString" sig="getNumberOfLinesInAString(text: string): integer" />

<MemberMeta badges="static" />

Gets the number of lines in a string by counting the newlines

**Parameters**

- `text` (string)

**Returns**

- `integer`

<MemberHeading id="lastinstr" depth="3" name="lastInStr" sig="lastInStr(text: string, substring: string): integer" />

<MemberMeta badges="static" />

Finds the index of the last time a substring appears in a string

**Parameters**

- `text` (string)
- `substring` (string)

**Returns**

- `integer`

<MemberHeading id="numbertofixed" depth="3" name="numberToFixed" sig="numberToFixed(num: float, precision: integer): string" />

<MemberMeta badges="static" />

Given a float number, returns the number with a fixed numbers of decimals as a string

**Parameters**

- `num` (float)
- `precision` (integer)

**Returns**

- `string`

<MemberHeading id="arraytostr" depth="3" name="arrayToStr" sig="arrayToStr(things: dynamic): string" />

<MemberMeta badges="static" />

**Parameters**

- `things` (dynamic)

**Returns**

- `string`

<MemberHeading id="stringtofloat" depth="3" name="stringToFloat" sig="stringToFloat(input: string): float" />

<MemberMeta badges="static" />

**Parameters**

- `input` (string)

**Returns**

- `float`

<MemberHeading
  id="texturepackergetregions"
  depth="3"
  name="TexturePacker_GetRegions"
  sig="TexturePacker_GetRegions(
	atlas: dynamic,
	bitmap: ifDraw2d,
): roAssociativeArray"
/>

<MemberMeta badges="static" />

TODO: figure this out... is useful for sprites with different size frames

**Parameters**

- `atlas` (dynamic)
- `bitmap` (ifDraw2d)

**Returns**

- `roAssociativeArray`

<MemberHeading
  id="arrayinsert"
  depth="3"
  name="ArrayInsert"
  sig="ArrayInsert(
	array: dynamic,
	index: integer,
	value: dynamic,
): dynamic"
/>

<MemberMeta badges="static" />

**Parameters**

- `array` (dynamic)
- `index` (integer)
- `value` (dynamic)

**Returns**

- `dynamic`

<MemberHeading
  id="drawcircleoutline"
  depth="3"
  name="DrawCircleOutline"
  sig="DrawCircleOutline(
	draw2d: ifDraw2d,
	line_count: integer,
	x: float,
	y: float,
	radius: float,
	rgba: integer,
): void"
/>

<MemberMeta badges="static" />

**Parameters**

- `draw2d` (ifDraw2d)
- `line_count` (integer)
- `x` (float)
- `y` (float)
- `radius` (float)
- `rgba` (integer)

**Returns**

- `void`

<MemberHeading
  id="drawrectangleoutline"
  depth="3"
  name="DrawRectangleOutline"
  sig="DrawRectangleOutline(
	draw2d: ifDraw2d,
	x: float,
	y: float,
	width: float,
	height: float,
	rgba: integer,
): void"
/>

<MemberMeta badges="static" />

**Parameters**

- `draw2d` (ifDraw2d)
- `x` (float)
- `y` (float)
- `width` (float)
- `height` (float)
- `rgba` (integer)

**Returns**

- `void`

<MemberHeading id="isvalidentity" depth="3" name="isValidEntity" sig="isValidEntity(entity: EntityWithId): boolean" />

<MemberMeta badges="static" />

**Parameters**

- `entity` ([EntityWithId](/bge#entitywithid))

**Returns**

- `boolean`

<MemberHeading id="buttonnamefromcode" depth="3" name="buttonNameFromCode" sig="buttonNameFromCode(buttonCode: integer): string" />

<MemberMeta badges="static" />

**Parameters**

- `buttonCode` (integer)

**Returns**

- `string`

<MemberHeading id="clonearray" depth="3" name="cloneArray" sig="cloneArray(original?: Array.<dynamic>): dynamic" />

<MemberMeta badges="static" />

Clone an array (shallow)

**Parameters**

- `original` (Array.\<dynamic>, optional, default: "\[]") — the original array to be clones

**Returns**

- `dynamic` — A shallow copy of the original array

<MemberHeading id="pointarraysequal" depth="3" name="pointArraysEqual" sig="pointArraysEqual(a?: dynamic, b?: dynamic): boolean" />

<MemberMeta badges="static" />

Check if two arrays of points are teh same - that is, if each point, in order has same x and y values

**Parameters**

- `a` (dynamic, optional, default: "\[]") — the first array
- `b` (dynamic, optional, default: "\[]") — the second array

**Returns**

- `boolean` — true if both arrays have same number of points and x and y values are the same for each point

<MemberHeading id="istrue" depth="3" name="isTrue" sig="isTrue(value: dynamic): boolean" />

<MemberMeta badges="static" />

**Parameters**

- `value` (dynamic)

**Returns**

- `boolean`

<MemberHeading
  id="bytestointeger"
  depth="3"
  name="bytesToInteger"
  sig="bytesToInteger(
	bytes: dynamic,
	offset?: integer,
	isLittleEndian?: boolean,
): integer"
/>

<MemberMeta badges="static" />

**Parameters**

- `bytes` (dynamic)
- `offset` (integer, optional, default: 0)
- `isLittleEndian` (boolean, optional, default: true)

**Returns**

- `integer`

<MemberHeading
  id="bytestofloat"
  depth="3"
  name="bytesToFloat"
  sig="bytesToFloat(
	bytes: dynamic,
	offset?: integer,
	isLittleEndian?: boolean,
): float"
/>

<MemberMeta badges="static" />

**Parameters**

- `bytes` (dynamic)
- `offset` (integer, optional, default: 0)
- `isLittleEndian` (boolean, optional, default: true)

**Returns**

- `float`

<MemberHeading
  id="subarray"
  depth="3"
  name="subArray"
  sig="subArray(
	array: ifArray,
	startIndex: integer,
	length: integer,
): roArray"
/>

<MemberMeta badges="static" />

**Parameters**

- `array` (ifArray)
- `startIndex` (integer)
- `length` (integer)

**Returns**

- `roArray`

<MemberHeading id="dectohex" depth="3" name="decToHex" sig="decToHex(dec: integer): string" />

<MemberMeta badges="static" />

**Parameters**

- `dec` (integer)

**Returns**

- `string`

## Enums

<MemberHeading id="spriteplaymode" depth="3" name=".SpritePlayMode" sig=".SpritePlayMode" />

<MemberMeta badges="readonly,enum" />

**Properties**

- `Loop` (default: "loop")
- `Forward` (default: "forward")
- `Reverse` (default: "reverse")
- `PingPong` (default: "pingpong")

<MemberHeading id="camerafrustumside" depth="3" name=".CameraFrustumSide" sig=".CameraFrustumSide" />

<MemberMeta badges="readonly,enum" />

**Properties**

- `top` (default: "top")
- `bottom` (default: "bottom")
- `left` (default: "left")
- `right` (default: "right")
- `near` (default: "near")

<MemberHeading id="sceneobjecttype" depth="3" name=".SceneObjectType" sig=".SceneObjectType" />

<MemberMeta badges="readonly,enum" />

**Properties**

- `Line` (default: "Line")
- `Rectangle` (default: "Rectangle")
- `Text` (default: "Text")
- `Bitmap` (default: "Bitmap")
- `Polygon` (default: "Polygon")
- `Billboard` (default: "Billboard")
- `Model` (default: "Model")

<MemberHeading id="sceneobjectdrawmode" depth="3" name=".SceneObjectDrawMode" sig=".SceneObjectDrawMode" />

<MemberMeta badges="readonly,enum" />

**Properties**

- `matchCamera` (default: 0) — Rotations are ignored
- `directToCamera` (default: 1) — Do not orient in 3d space
- `directScaled` (default: 2) — Do not orient in 3d space, but scale in relation to distance from camera
- `oriented` (default: 3) — Orient in 3d space
- `orientedDrawBackFace` (default: 4) — Orient the object, and draw any back faces
- `wireFrame` (default: 5) — Just draw a wire frame
- `wireFrameDrawBackFace` (default: 6) — Just draw a wire frame, including back faces
- `solid` (default: 7) — Draw a solid polygon
- `solidDrawBackFace` (default: 8) — Draw a solid polygon, including back faces

<MemberHeading id="colors" depth="3" name=".Colors" sig=".Colors" />

<MemberMeta badges="readonly,enum" />

Named colors as packed RGBA integers (0xRRGGBBAA), fully opaque. Values match `RGBAtoRGBA(r, g, b)` for the same named color.

**Properties**

- `Black` (default: 255)
- `White` (default: 4294967295)
- `Red` (default: 4278190335)
- `Lime` (default: 16711935)
- `Blue` (default: 65535)
- `Yellow` (default: 4294902015)
- `Cyan` (default: 16777215)
- `Aqua` (default: 16777215)
- `Magenta` (default: 4278255615)
- `Pink` (default: 4278255615)
- `Fuchsia` (default: 4278255615)
- `Silver` (default: 3233857791)
- `Gray` (default: 2155905279)
- `Grey` (default: 2155905279)
- `Maroon` (default: 2147483903)
- `Olive` (default: 2155872511)
- `Green` (default: 8388863)
- `Purple` (default: 2147516671)
- `Teal` (default: 8421631)
- `Navy` (default: 33023)

<MemberHeading id="colorsrgb" depth="3" name=".ColorsRGB" sig=".ColorsRGB" />

<MemberMeta badges="readonly,enum" />

Named colors as packed RGB integers (0xRRGGBB, no alpha byte) - the same values as BGE.Colors, right-shifted by 8.

**Properties**

- `Black` (default: 0)
- `White` (default: 16777215)
- `Red` (default: 16711680)
- `Lime` (default: 65280)
- `Blue` (default: 255)
- `Yellow` (default: 16776960)
- `Cyan` (default: 65535)
- `Aqua` (default: 65535)
- `Magenta` (default: 16711935)
- `Pink` (default: 16711935)
- `Fuchsia` (default: 16711935)
- `Silver` (default: 12632256)
- `Gray` (default: 8421504)
- `Grey` (default: 8421504)
- `Maroon` (default: 8388608)
- `Olive` (default: 8421376)
- `Green` (default: 32768)
- `Purple` (default: 8388736)
- `Teal` (default: 32896)
- `Navy` (default: 128)

## Other

<MemberHeading id="canvas" depth="3" name="Canvas" sig="Canvas" />

<MemberMeta badges="static" />

Contains a roku roBitmap which all game objects get drawn to.

**Parameters**

- `gameEngine` ([Game](/bge#game))
- `canvasWidth` (integer) — width of canvas
- `canvasHeight` (integer) — height of canvas
- `options` ([RendererOptions](/bge#rendereroptions), optional, default: "{useBitmapPooling: true}")

**Properties**

- `bitmap` (ifDraw2D) — bitmap GameEntity images get drawn to
- `offset` (BGE.Math.Vector) — Position offset from screen coordinates (z value ignored)
- `scale` (BGE.Math.Vector) — Scale (z value ignored)
- `renderer` ([Renderer](/bge#renderer)) — Renderer for this canvas
- `rendererOptions` ([RendererOptions](/bge#rendereroptions))

**Returns**

- [`BGE.Canvas`](/bge#canvas)

<MemberHeading id="game" depth="3" name="Game" sig="Game" />

<MemberMeta badges="static" />

Main Game Engine class which runs everything The main game loop is as follows:

1. Update - For each GameEntity:

- Process Input from roku remote
- Process Audio Events (https\://developer.roku.com/en-ca/docs/references/brightscript/events/roaudioplayerevent.md)
- Process ECP input (https\://developer.roku.com/en-ca/docs/developer-program/debugging/external-control-api.md)
- Process URL events (https\://developer.roku.com/en-ca/docs/references/brightscript/events/rourlevent.md)
- Runs the Entity's onUpdate() function
- Moves Entity based on velocity

2. Collisions - For each GameEntity:

- Run Entity's onPreCollision() function
- For any collisions, runs Entity's onCollision() function
- Runs entity's onPostCollision() function (At any time, the Entity in question may Delete() itself. Before every entity interaction, the entity is checked to make sure it is still valid in case it was deleted in the last interaction)

3. Draw - For each GameEntity, sorted by zIndex

- Runs the Entity onDrawBegin() function
- For each drawable in the Entity, run the draw() function
- Run the Entity onDrawEnd() function

4. Draw all debug items in game space (e.g. colliders, screen safe zones, etc).

4. UI - For the tree of widgets in the UI Container

- Run onUpdate()
- Run draw()

6. Debug UI - Draw all debug windows in the tree of the Debug UI

**Parameters**

- `canvasWidth` (integer) — Width of the canvas the game is drawn to
- `canvasHeight` (integer) — Height of the canvas the game is drawn to
- `uiWidth` (integer, optional, default: 0) — Width of the UI canvas - if 0, will be same as screen
- `uiHeight` (integer, optional, default: 0) — Height of the UI canvas - if 0, will be same as screen

**Properties**

- `sortedEntities` (dynamic)
- `compositor` (roCompositor)
- `screen` (roScreen)
- `canvas` ([BGE.Canvas](/bge#canvas))
- `uiCanvas` ([BGE.Canvas](/bge#canvas))
- `dummyScreen` (roScreen)
- `currentRoom` ([Room](/bge#room)) — Reference to the current room in play
- `currentRoomArgs` (dynamic) — Any special arguments for the current room
- `Entities` (dynamic) — All of the GameEntities by room => => GameEntity
- `Statics` (dynamic) — All static variables for a given object type
- `Rooms` (dynamic) — The room definitions by name (the room creation functions)
- `Interfaces` (dynamic) — The interface definitions by name
- `Bitmaps` (dynamic) — The loaded bitmaps by name
- `Sounds` (dynamic) — The loaded sounds by name
- `Fonts` (dynamic) — The loaded fonts by name
- `Models` (dynamic) — The loaded Models by name
- `gameUi` (BGE.UI.UiContainer) — Container for all UI
- `debugUi` (BGE.UI.UiContainer) — Container for Debug UI

**Returns**

- [`BGE.Game`](/bge#game)

<MemberHeading id="gameentity" depth="3" name="GameEntity" sig="GameEntity" />

<MemberMeta badges="static" />

Every thing (character, player, object, etc) in the game should extend this class. This class has a number of empty methods that are designed to be overridden in subclasses. For example, override `onInput()` to handle input event, and `onUpdate()` to handle updating each frame

**Parameters**

- `game` ([Game](/bge#game)) — The game engine that this entity is going to be assigned to
- `gameEngine` ([Game](/bge#game))
- `args` (roAssociativeArray, optional, default: "{}") — Any extra properties to be added to this entity

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

**Returns**

- [`BGE.GameEntity`](/bge#gameentity)

<MemberHeading id="gameinput" depth="3" name="GameInput" sig="GameInput" />

<MemberMeta badges="static" />

Class that contains all information about the current input during a given frame from the remote

**Parameters**

- `buttonCode` (integer) — button to use for the data
- `heldTimeMs` (integer) — how long was this button held for

**Properties**

- `button` (string) — The name of the button associated with the current input
- `buttonCode` (integer) — The code for the input
- `press` (boolean) — Was the button pressed since the last frame
- `held` (boolean) — Was the button held down since last frame
- `release` (boolean) — Was the button released this frame
- `heldTimeMs` (integer) — How many milliseconds was the current input held for
- `x` (float) — Current horizontal directional input: left -> -1, right -> 1
- `y` (float) — Current vertical directional input, in world space (+y is up, matching ' the engine's world coordinate convention - the renderer flips this when ' projecting to raster/canvas space): up -> 1, down -> -1

**Returns**

- [`BGE.GameInput`](/bge#gameinput)

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

<MemberHeading id="gametimer" depth="3" name="GameTimer" sig="GameTimer" />

<MemberMeta badges="static" />

Wrapper for Roku's roTimeSpan that allows time adjustment

**Returns**

- [`BGE.GameTimer`](/bge#gametimer)

<MemberHeading id="room" depth="3" name="Room" sig="Room" />

<MemberMeta badges="static" />

**Extends:&#x20;**`GameEntity`

**Parameters**

- `gameEngine` ([Game](/bge#game))
- `args` (roAssociativeArray, optional, default: "{}")

**Returns**

- [`BGE.Room`](/bge#room)

<MemberHeading id="circlecollider" depth="3" name="CircleCollider" sig="CircleCollider" />

<MemberMeta badges="static" />

**Extends:&#x20;**`Collider`

Collider with the shape of a circle centered at (offset.x, offset.y), with given radius

**Parameters**

- `colliderName` (string) — name of this collider
- `args` (roAssociativeArray, optional, default: "{}") — additional properties (e.g {radius: 10})

**Properties**

- `radius` (integer) — Radius of the collider

**Returns**

- [`BGE.CircleCollider`](/bge#circlecollider)

<MemberHeading id="collider" depth="3" name="Collider" sig="Collider" />

<MemberMeta badges="static" />

Colliders are attached to GameEntities and when two colliders intersect, it triggers the onCollision() method in the GameEntity

**Parameters**

- `colliderName` (string) — the name this collider will be identified by
- `args` (roAssociativeArray, optional, default: "{}") — additional properties to be added to this collider

**Properties**

- `colliderType` (string) — The type of this collider - should be defined in sub classes (eg. "circle", "rectangle")
- `name` (string) — Name this collider will be identified by
- `enabled` (boolean) — Does this collider trigger onCollision() ?
- `offset` (BGE.Math.Vector) — Offset from the GameEntity it is attached to
- `memberFlags` (integer) — Bitflag for collision detection: this collider is in this group - https\://developer.roku.com/en-ca/docs/references/brightscript/interfaces/ifsprite.md#setmemberflagsflags-as-integer-as-void
- `collidableFlags` (integer) — Bitflag for collision detection: this collider will only collider with colliders in this group - https\://developer.roku.com/en-ca/docs/references/brightscript/interfaces/ifsprite.md#setcollidableflagsflags-as-integer-as-void
- `compositorObject` (roSprite) — Used internal to Game - should not be modified manually
- `tagsList` (dynamic) — Colliders can be tagged with any number of tags so they can be easily identified (e.g. "enemy", "wall", etc.)

**Returns**

- [`BGE.Collider`](/bge#collider)

<MemberHeading id="rectanglecollider" depth="3" name="RectangleCollider" sig="RectangleCollider" />

<MemberMeta badges="static" />

**Extends:&#x20;**`Collider`

Collider with the shape of a rectangle with bottom left at (offset.x, offset.y) - i.e. top left is at (offset.x, offset.y - height) - with given width and height

**Parameters**

- `colliderName` (string) — name of this collider
- `args` (roAssociativeArray, optional, default: "{}") — additional properties (e.g {width: 10, height: 20})

**Properties**

- `width` (float)
- `height` (float)

**Returns**

- [`BGE.RectangleCollider`](/bge#rectanglecollider)

<MemberHeading id="animatedimage" depth="3" name="AnimatedImage" sig="AnimatedImage" />

<MemberMeta badges="static" />

**Extends:&#x20;**`Image`

**Parameters**

- `owner` ([GameEntity](/bge#gameentity))
- `regions` (dynamic)
- `args` (roAssociativeArray, optional, default: "{}")

**Properties**

- `index` (integer) — The current index of image - this would not normally be changed manually, but if you wanted to stop on a specific image in the spritesheet this could be set.
- `animationDurationMs` (float) — The time in milliseconds for a single cycle through the animation to play.
- `animationTween` (string) — The name of the tween to use for choosing the next image
- `regions` (dynamic) — ------------Never To Be Manually Changed----------------- ' These values should never need to be manually changed.
- `animationTimer` (dynamic)
- `tweensReference` (dynamic)

**Returns**

- [`BGE.AnimatedImage`](/bge#animatedimage)

<MemberHeading id="drawable" depth="3" name="Drawable" sig="Drawable" />

<MemberMeta badges="static" />

Abstract drawable class - all drawables extend from this

**Parameters**

- `owner` ([GameEntity](/bge#gameentity))
- `args` (roAssociativeArray, optional, default: "{}")

**Properties**

- `name` (string) — -------------Values That Can Be Changed------------
- `offset` (dynamic) — The offset of the image from the owner's position
- `scale` (dynamic) — The image scale
- `rotation` (dynamic) — Rotation of the image
- `color` (integer) — This can be used to tint the image with the provided color if desired. White makes no change to the original image.
- `outlineRGBA` (integer) — RGBA color for outline stroke
- `alpha` (float) — Change the image alpha (transparency).
- `enabled` (boolean) — Whether or not the image will be drawn.
- `transformationMatrix` (dynamic)
- `motionChecker` ([MotionChecker](/bge#motionchecker))
- `shouldRedraw` (boolean)
- `owner` ([GameEntity](/bge#gameentity)) — owner GameEntity
- `width` (float)
- `height` (float)
- `sceneObjects` (dynamic)
- `drawMode` ([SceneObjectDrawMode](/bge#sceneobjectdrawmode))
- `isShaded` (boolean)

**Returns**

- [`BGE.Drawable`](/bge#drawable)

<MemberHeading id="drawableline" depth="3" name="DrawableLine" sig="DrawableLine" />

<MemberMeta badges="static" />

**Extends:&#x20;**`Drawable`

**Parameters**

- `owner` ([GameEntity](/bge#gameentity))
- `startPos` (BGE.Math.Vector)
- `endPos` (BGE.Math.Vector)
- `args` (roAssociativeArray, optional, default: "{}")

**Properties**

- `startPosition` (BGE.Math.Vector)
- `endPosition` (BGE.Math.Vector)

**Returns**

- [`BGE.DrawableLine`](/bge#drawableline)

<MemberHeading id="drawablepolygon" depth="3" name="DrawablePolygon" sig="DrawablePolygon" />

<MemberMeta badges="static" />

**Extends:&#x20;**`Drawable`

**Parameters**

- `owner` ([GameEntity](/bge#gameentity))
- `points` (dynamic, optional, default: "\[]")
- `args` (roAssociativeArray, optional, default: "{}")

**Properties**

- `points` (dynamic) — the set of points defining a convex polygon

**Returns**

- [`BGE.DrawablePolygon`](/bge#drawablepolygon)

<MemberHeading id="drawablerectangle" depth="3" name="DrawableRectangle" sig="DrawableRectangle" />

<MemberMeta badges="static" />

**Extends:&#x20;**`Drawable`

**Parameters**

- `owner` ([GameEntity](/bge#gameentity))
- `width` (float)
- `height` (float)
- `args` (roAssociativeArray, optional, default: "{}")

**Properties**

- `tempCanvas` (ifDraw2d)
- `lastWidth` (float)
- `lastHeight` (float)

**Returns**

- [`BGE.DrawableRectangle`](/bge#drawablerectangle)

<MemberHeading id="mintextregionsize" depth="3" name="MIN_TEXT_REGION_SIZE" sig="MIN_TEXT_REGION_SIZE" />

<MemberMeta badges="static,readonly" />

**Default:** `256`

<MemberHeading id="drawabletext" depth="3" name="DrawableText" sig="DrawableText" />

<MemberMeta badges="static" />

**Extends:&#x20;**`Drawable`

Class to draw text

**Parameters**

- `owner` ([GameEntity](/bge#gameentity))
- `text` (string, optional, default: "\\"\\"")
- `font` (roFont, optional, default: "invalid")
- `args` (roAssociativeArray, optional, default: "{}")

**Properties**

- `text` (string) — The text to write on the screen
- `font` (roFont) — The Font object to use ( get this from the font registry)
- `alignment` (BGE.UI.HorizAlignment) — The Horizontal alignment for the text
- `lastTextValue` (string)
- `tempCanvas` (roBitmap)
- `tempRegion` (roRegion)

**Returns**

- [`BGE.DrawableText`](/bge#drawabletext)

<MemberHeading id="image" depth="3" name="Image" sig="Image" />

<MemberMeta badges="static" />

**Extends:&#x20;**`BGE.Drawable`

Used to draw a bitmap image to the screen

**Parameters**

- `owner` ([BGE.GameEntity](/bge#gameentity))
- `region` (roRegion)
- `args` (roAssociativeArray, optional, default: "{}")

**Properties**

- `regionId` (string) — An optional unique name for the region, used for caching image data. If not provided, the name of the drawable will be used as the region name.
- `region` (roRegion) — ------------Never To Be Manually Changed----------------- ' These values should never need to be manually changed.

**Returns**

- [`BGE.Image`](/bge#image)

<MemberHeading id="model3dtexture" depth="3" name="Model3dTexture" sig="Model3dTexture" />

<MemberMeta badges="static" />

**Parameters**

- `srcImage` (ifRegion)
- `points` (dynamic)

**Properties**

- `srcImage` (ifRegion)
- `points` (dynamic)

**Returns**

- [`BGE.Model3dTexture`](/bge#model3dtexture)

<MemberHeading id="model3dface" depth="3" name="Model3dFace" sig="Model3dFace" />

<MemberMeta badges="static" />

**Properties**

- `vertices` (dynamic)
- `normal` (BGE.Math.Vector)
- `Texture` ([Model3dTexture](/bge#model3dtexture))
- `brightness` (float)
- `priority` (float)
- `color` (integer)

<MemberHeading id="model3d" depth="3" name="Model3d" sig="Model3d" />

<MemberMeta badges="static" />

**Parameters**

- `faces` (dynamic)

**Properties**

- `faces` (dynamic)
- `name` (string)

**Returns**

- [`BGE.Model3d`](/bge#model3d)

<MemberHeading id="drawablemodel" depth="3" name="DrawableModel" sig="DrawableModel" />

<MemberMeta badges="static" />

**Extends:&#x20;**`Drawable`

**Parameters**

- `owner` ([BGE.GameEntity](/bge#gameentity))
- `model` ([Model3d](/bge#model3d))
- `args` (roAssociativeArray, optional, default: "{}")

**Properties**

- `model` ([Model3d](/bge#model3d))

**Returns**

- [`BGE.DrawableModel`](/bge#drawablemodel)

<MemberHeading id="animationframedescription" depth="3" name="AnimationFrameDescription" sig="AnimationFrameDescription" />

<MemberMeta badges="static" />

**Properties**

- `startFrame` (integer)
- `frameCount` (integer)

<MemberHeading id="spriteanimation" depth="3" name="SpriteAnimation" sig="SpriteAnimation" />

<MemberMeta badges="static" />

CReate a new SpriteAnimation

**Parameters**

- `name` (string) — Name of the animation
- `frameList` (dynamic) — Wither an array of cell indexes, or an object {startFrame, frameCount}
- `frameRate` (integer) — Frames per second the animation should play at
- `playMode` ([SpritePlayMode](/bge#spriteplaymode), optional, default: "SpritePlayMode.Loop") — Play mode for the sprite: loop, forward, reverse, pingpong

**Properties**

- `name` (string) — Name of the animation
- `frameRate` (integer) — Frames per second the animation should play at
- `frameList` (dynamic) — Array of the regions of the each cell of this animation
- `playMode` ([SpritePlayMode](/bge#spriteplaymode)) — Play mode for the sprite: loop, forward, reverse, pingpong

**Returns**

- [`BGE.SpriteAnimation`](/bge#spriteanimation)

<MemberHeading id="sprite" depth="3" name="Sprite" sig="Sprite" />

<MemberMeta badges="static" />

**Extends:&#x20;**`AnimatedImage`

**Parameters**

- `owner` ([GameEntity](/bge#gameentity))
- `spriteSheet` (ifDraw2d)
- `cellWidth` (integer)
- `cellHeight` (integer)
- `args` (roAssociativeArray, optional, default: "{}")

**Properties**

- `spriteSheet` (ifDraw2d) — roBitmap to pick cells from
- `cellWidth` (integer) — Width of each animation cell in the sprite image in pixels
- `cellHeight` (integer) — Height of each animation cell in the sprite image in pixels
- `animations` (roAssociativeArray) — Lookup map of animation name -> SpriteAnimation object
- `activeAnimation` ([SpriteAnimation](/bge#spriteanimation)) — The current animation being played

**Returns**

- [`BGE.Sprite`](/bge#sprite)

<MemberHeading id="roomchangeinfo" depth="3" name="RoomChangeInfo" sig="RoomChangeInfo" />

<MemberMeta badges="static" />

**Properties**

- `room` ([Room](/bge#room))
- `args` (roAssociativeArray)

<MemberHeading id="garbagecollectioninfo" depth="3" name="GarbageCollectionInfo" sig="GarbageCollectionInfo" />

<MemberMeta badges="static" />

**Properties**

- `count` (integer)
- `orphaned` (integer)
- `root` (integer)

<MemberHeading id="debugcolors" depth="3" name="DebugColors" sig="DebugColors" />

<MemberMeta badges="static" />

**Properties**

- `colliders` (integer)
- `safe_action_zone` (integer)
- `safe_title_zone` (integer)

<MemberHeading id="entitywithid" depth="3" name="EntityWithId" sig="EntityWithId" />

<MemberMeta badges="static" />

**Properties**

- `id` (dynamic)

<MemberHeading id="positionxy" depth="3" name="PositionXY" sig="PositionXY" />

<MemberMeta badges="static" />

**Properties**

- `x` (float)
- `y` (float)

<MemberHeading id="sizewh" depth="3" name="SizeWH" sig="SizeWH" />

<MemberMeta badges="static" />

**Properties**

- `width` (float)
- `height` (float)

<MemberHeading id="rendererresourcesize" depth="3" name="RendererResourceSize" sig="RendererResourceSize" />

<MemberMeta badges="static,readonly" />

**Default:** `400`

<MemberHeading id="triangledrawthreshold" depth="3" name="TriangleDrawThreshold" sig="TriangleDrawThreshold" />

<MemberMeta badges="static,readonly" />

**Default:** `4`

<MemberHeading id="trianglequickdrawthreshold" depth="3" name="TriangleQuickDrawThreshold" sig="TriangleQuickDrawThreshold" />

<MemberMeta badges="static,readonly" />

**Default:** `64`

<MemberHeading id="trianglequickdrawthresholdforsimulator" depth="3" name="TriangleQuickDrawThresholdForSimulator" sig="TriangleQuickDrawThresholdForSimulator" />

<MemberMeta badges="static,readonly" />

**Default:** `32`

<MemberHeading id="levelofdetailoptions" depth="3" name="LevelOfDetailOptions" sig="LevelOfDetailOptions" />

<MemberMeta badges="static" />

**Properties**

- `levelOffset` (integer)
- `levelOfDetail` (integer)

<MemberHeading id="rendereroptions" depth="3" name="RendererOptions" sig="RendererOptions" />

<MemberMeta badges="static" />

**Properties**

- `useBitmapPooling` (boolean)

<MemberHeading id="renderer" depth="3" name="Renderer" sig="Renderer" />

<MemberMeta badges="static" />

Wrapper for Draw2D calls, so that we can keep track of how much is being drawn per frame

**Parameters**

- `draw2d` (ifDraw2d)
- `mainGame` ([BGE.Game](/bge#game), optional, default: "invalid")
- `cam` ([BGE.Camera](/bge#camera), optional, default: "invalid")
- `options` ([RendererOptions](/bge#rendereroptions), optional, default: "{useBitmapPooling: true}")

**Properties**

- `nextSceneObjectId` (integer)
- `minimumFrameRateTarget` (integer) — Frame rate target - the game will reduce quality if this target is not met
- `onlyDrawWhenInFrame` (boolean)
- `drawDebugCells` (boolean)
- `drawDebugTrianglePoints` (boolean)
- `camera` ([Camera](/bge#camera))
- `triangleCache` (dynamic)
- `frameCount` (integer)
- `bmpPool` ([BGE.ScratchBitmapPool](/bge#scratchbitmappool))
- `game` ([BGE.Game](/bge#game))
- `name` (string)
- `statsString` (string)
- `resources` (dynamic)
- `dummyScreen` (roScreen)

**Returns**

- [`BGE.Renderer`](/bge#renderer)

<MemberHeading id="drawpinnedcornersoptions" depth="3" name="DrawPinnedCornersOptions" sig="DrawPinnedCornersOptions" />

<MemberMeta badges="static" />

**Properties**

- `splitIntoFour` (boolean)
- `alwaysUseTLtoBR` (boolean)

<MemberHeading id="scratchbitmap" depth="3" name="ScratchBitmap" sig="ScratchBitmap" />

<MemberMeta badges="static" />

**Parameters**

- `id` (string)
- `w` (integer)
- `h` (integer)

**Properties**

- `bitmap` (roBitmap)
- `id` (string)

**Returns**

- [`BGE.ScratchBitmap`](/bge#scratchbitmap)

<MemberHeading id="scratchregion" depth="3" name="ScratchRegion" sig="ScratchRegion" />

<MemberMeta badges="static" />

**Parameters**

- `region` (roRegion)
- `scratchBmp` ([ScratchBitmap](/bge#scratchbitmap))

**Properties**

- `region` (roRegion)
- `scratchBmp` ([ScratchBitmap](/bge#scratchbitmap))
- `scale` (dynamic)

**Returns**

- [`BGE.ScratchRegion`](/bge#scratchregion)

<MemberHeading id="scratchbitmappool" depth="3" name="ScratchBitmapPool" sig="ScratchBitmapPool" />

<MemberMeta badges="static" />

**Parameters**

- `doPooling` (boolean, optional, default: true)
- `initialCount` (integer, optional, default: 10)

**Returns**

- [`BGE.ScratchBitmapPool`](/bge#scratchbitmappool)

<MemberHeading id="trianglecacheentry" depth="3" name="TriangleCacheEntry" sig="TriangleCacheEntry" />

<MemberMeta badges="static" />

**Parameters**

- `triangle` (BGE.RendererHelpers.TriangleBitmap)

**Properties**

- `triangle` (BGE.RendererHelpers.TriangleBitmap)
- `timeLastUsed` (integer)

**Returns**

- [`BGE.TriangleCacheEntry`](/bge#trianglecacheentry)

<MemberHeading id="trianglecache" depth="3" name="TriangleCache" sig="TriangleCache" />

<MemberMeta badges="static" />

**Parameters**

- `cacheKeepSeconds` (integer, optional, default: 60)

**Returns**

- [`BGE.TriangleCache`](/bge#trianglecache)

<MemberHeading id="camera" depth="3" name="Camera" sig="Camera" />

<MemberMeta badges="static" />

**Properties**

- `orientation` (dynamic)
- `position` (BGE.Math.Vector)
- `motionChecker` ([MotionChecker](/bge#motionchecker))
- `frameSize` (BGE.Math.Vector)
- `zoom` (float) — TODO: do something with zoom!
- `worldToCamera` (dynamic)
- `name` (string)

**Returns**

- [`BGE.Camera`](/bge#camera)

<MemberHeading id="camera2d" depth="3" name="Camera2d" sig="Camera2d" />

<MemberMeta badges="static" />

**Extends:&#x20;**`Camera`

**Properties**

- `top` (float)
- `bottom` (float)
- `right` (float)
- `left` (float)
- `near` (float)
- `far` (float)
- `name` (string)

<MemberHeading id="camerafrustumnormals" depth="3" name="CameraFrustumNormals" sig="CameraFrustumNormals" />

<MemberMeta badges="static" />

**Properties**

- `top` (BGE.Math.Vector)
- `bottom` (BGE.Math.Vector)
- `left` (BGE.Math.Vector)
- `right` (BGE.Math.Vector)
- `near` (BGE.Math.Vector)

<MemberHeading id="camera3d" depth="3" name="Camera3d" sig="Camera3d" />

<MemberMeta badges="static" />

**Extends:&#x20;**`Camera`

**Properties**

- `fieldOfViewDegrees` (float)
- `frustumNormals` ([CameraFrustumNormals](/bge#camerafrustumnormals))
- `frustrumConvergence` (BGE.Math.Vector)
- `name` (string)

<MemberHeading id="maxdrawmode" depth="3" name="MAX_DRAW_MODE" sig="MAX_DRAW_MODE" />

<MemberMeta badges="static,readonly" />

**Default:** `8`

<MemberHeading id="sceneobject" depth="3" name="SceneObject" sig="SceneObject" />

<MemberMeta badges="static" />

**Parameters**

- `name` (string)
- `drawableObj` ([Drawable](/bge#drawable))
- `objType` ([SceneObjectType](/bge#sceneobjecttype))

**Properties**

- `name` (string)
- `id` (string) — Unique Id
- `drawable` ([Drawable](/bge#drawable))
- `type` ([SceneObjectType](/bge#sceneobjecttype))
- `negDistanceFromCamera` (float)
- `worldPosition` (dynamic)
- `transformationMatrix` (dynamic) — The Current Transformation Matrix
- `framesSinceDrawn` (integer)
- `hasValidWorldPosition` (boolean)
- `hasValidCanvasPosition` (boolean)
- `wasEnabledLastFrame` (boolean)
- `isFirstFrameSinceEnabled` (boolean)
- `isLowEndDevice` (boolean)

**Returns**

- [`BGE.SceneObject`](/bge#sceneobject)

<MemberHeading id="transformtempbitmapdetails" depth="3" name="TransformTempBitmapDetails" sig="TransformTempBitmapDetails" />

<MemberMeta badges="static" />

**Properties**

- `origin` (BGE.Math.Vector)
- `rotation` (float)
- `scaleX` (float)
- `scaleY` (float)

<MemberHeading id="tempbitmapdrawresult" depth="3" name="TempBitmapDrawResult" sig="TempBitmapDrawResult" />

<MemberMeta badges="static" />

**Properties**

- `worked` (boolean)
- `didFastDraw` (boolean)

<MemberHeading id="sceneobjectbillboard" depth="3" name="SceneObjectBillboard" sig="SceneObjectBillboard" />

<MemberMeta badges="static" />

**Extends:&#x20;**`SceneObject`

**Parameters**

- `name` (string)
- `drawableObj` ([Drawable](/bge#drawable))
- `objType` ([SceneObjectType](/bge#sceneobjecttype))

**Properties**

- `worldPoints` (BGE.Math.CornerPoints)
- `canvasPoints` (BGE.Math.CornerPoints)
- `useTempBitmapMap` (dynamic)

**Returns**

- [`BGE.SceneObjectBillboard`](/bge#sceneobjectbillboard)

<MemberHeading id="sceneobjectimage" depth="3" name="SceneObjectImage" sig="SceneObjectImage" />

<MemberMeta badges="static" />

**Extends:&#x20;**`SceneObjectBillboard`

**Parameters**

- `name` (string)
- `drawableObj` ([Image](/bge#image))

**Properties**

- `drawable` ([Image](/bge#image))
- `frameNumber` (integer)

**Returns**

- [`BGE.SceneObjectImage`](/bge#sceneobjectimage)

<MemberHeading id="sceneobjectline" depth="3" name="SceneObjectLine" sig="SceneObjectLine" />

<MemberMeta badges="static" />

**Extends:&#x20;**`SceneObject`

**Parameters**

- `name` (string)
- `drawableObj` ([DrawableLine](/bge#drawableline))

**Properties**

- `drawable` ([DrawableLine](/bge#drawableline))

**Returns**

- [`BGE.SceneObjectLine`](/bge#sceneobjectline)

<MemberHeading id="sceneobjectmodel" depth="3" name="SceneObjectModel" sig="SceneObjectModel" />

<MemberMeta badges="static" />

**Extends:&#x20;**`SceneObjectBillboard`

**Parameters**

- `name` (string)
- `drawableObj` ([DrawableModel](/bge#drawablemodel))

**Properties**

- `drawable` ([DrawableModel](/bge#drawablemodel))

**Returns**

- [`BGE.SceneObjectModel`](/bge#sceneobjectmodel)

<MemberHeading id="sceneobjectpolygon" depth="3" name="SceneObjectPolygon" sig="SceneObjectPolygon" />

<MemberMeta badges="static" />

**Extends:&#x20;**`SceneObjectBillboard`

**Parameters**

- `name` (string)
- `drawableObj` ([DrawablePolygon](/bge#drawablepolygon))

**Properties**

- `drawable` ([DrawablePolygon](/bge#drawablepolygon))

**Returns**

- [`BGE.SceneObjectPolygon`](/bge#sceneobjectpolygon)

<MemberHeading id="sceneobjecttext" depth="3" name="SceneObjectText" sig="SceneObjectText" />

<MemberMeta badges="static" />

**Extends:&#x20;**`SceneObjectBillboard`

**Parameters**

- `name` (string)
- `drawableObj` ([DrawableText](/bge#drawabletext))

**Properties**

- `drawable` ([DrawableText](/bge#drawabletext))

**Returns**

- [`BGE.SceneObjectText`](/bge#sceneobjecttext)

<MemberHeading id="motionchecker" depth="3" name="MotionChecker" sig="MotionChecker" />

<MemberMeta badges="static" />

**Properties**

- `previousTransform` (dynamic)
- `movedLastFrame` (boolean)

<MemberHeading id="someconst" depth="3" name="SomeConst" sig="SomeConst" />

<MemberMeta badges="static,readonly" />

**Default:** `23`

<MemberHeading id="taglist" depth="3" name="TagList" sig="TagList" />

<MemberMeta badges="static" />

**Returns**

- [`BGE.TagList`](/bge#taglist)
