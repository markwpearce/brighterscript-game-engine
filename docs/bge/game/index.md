---
title: Game
kind: class
longname: BGE.Game
description: "Main Game Engine class which runs everything The main game loop is as follows: Update - For each GameEntity: Process Input from roku remote Process Audio Events (https://developer.roku.com/en-ca/docs/references/brightscript/events/roaudioplayerevent.md) Process ECP input (https://developer.roku.com/en-ca/docs/developer-program/debugging/external-control-api.md) Process URL events (https://developer.roku.com/en-ca/docs/references/brightscript/events/rourlevent.md) Runs the Entity's onUpdate() function Moves Entity based on velocity Collisions - For each GameEntity: Run Entity's onPreCollision() function For any collisions, runs Entity's onCollision() function Runs entity's onPostCollision() function (At any time, the Entity in question may Delete() itself. Before every entity interaction, the entity is checked to make sure it is still valid in case it was deleted in the last interaction) Draw - For each GameEntity, sorted by zIndex Runs the Entity onDrawBegin() function For each drawable in the Entity, run the draw() function Run the Entity onDrawEnd() function Draw all debug items in game space (e.g. colliders, screen safe zones, etc). UI - For the tree of widgets in the UI Container Run onUpdate() Run draw() Debug UI - Draw all debug windows in the tree of the Debug UI"
---

# Game

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

---

## Constructor

<Signature
  code="new Game(
	canvasWidth: integer,
	canvasHeight: integer,
	uiWidth?: integer,
	uiHeight?: integer,
): Game"
/>

Constructor for GameEngine

**Parameters**

- `canvasWidth` (integer) — Width of the canvas the game is drawn to
- `canvasHeight` (integer) — Height of the canvas the game is drawn to
- `uiWidth` (integer, optional, default: 0) — Width of the UI canvas - if 0, will be same as screen
- `uiHeight` (integer, optional, default: 0) — Height of the UI canvas - if 0, will be same as screen

---

## Instance Methods

<MemberHeading id="setcamera" depth="3" name="setCamera" sig="setCamera(cam: Camera): void" />

**Parameters**

- `cam` ([Camera](/bge#camera))

**Returns**

- `void`

<MemberHeading id="setupui" depth="3" name="setupUi" sig="setupUi(uiWidth: integer, uiHeight: integer): void" />

Sets up the Ui layer

**Parameters**

- `uiWidth` (integer)
- `uiHeight` (integer)

**Returns**

- `void`

<MemberHeading id="scalecanvastofillscreen" depth="3" name="scaleCanvasToFillScreen" sig="scaleCanvasToFillScreen(): void" />

**Returns**

- `void`

<MemberHeading id="getnextgameentityid" depth="3" name="getNextGameEntityId" sig="getNextGameEntityId(): string" />

Gets the next valid id for a GameEntity

**Returns**

- `string`

<MemberHeading id="play" depth="3" name="Play" sig="Play(): void" />

Starts the game engine. Run this function after setting up the game.

**Returns**

- `void`

<MemberHeading id="end" depth="3" name="End" sig="End(): void" />

Ends the Game

**Returns**

- `void`

<MemberHeading id="pause" depth="3" name="Pause" sig="Pause(): void" />

Pauses the game Only entities marked as pausable = false will be processed in game loop For each entity, the onPause() function will be called

**Returns**

- `void`

<MemberHeading id="resume" depth="3" name="Resume" sig="Resume(): integer" />

Resumes / unpauses the game For each entity, the onResume() function will be called, and any image in the entity will have its onResume() called

**Returns**

- `integer`

<MemberHeading id="ispaused" depth="3" name="isPaused" sig="isPaused(): boolean" />

Is the game paused?

**Returns**

- `boolean`

<MemberHeading id="setbackgroundcolor" depth="3" name="setBackgroundColor" sig="setBackgroundColor(color: integer): void" />

Sets the default background color for the game Before any entities are drawn, the screen is cleared to this color

**Parameters**

- `color` (integer)

**Returns**

- `void`

<MemberHeading id="getdeltatime" depth="3" name="getDeltaTime" sig="getDeltaTime(): float" />

What's the time in seconds since last frame?

**Returns**

- `float`

<MemberHeading id="gettotaltime" depth="3" name="getTotalTime" sig="getTotalTime(): float" />

What's the total time in seconds since ths start

**Returns**

- `float`

<MemberHeading id="getroom" depth="3" name="getRoom" sig="getRoom(): Room" />

Gets the current Room/Level the game is using

**Returns**

- [`Room`](/bge#room)

<MemberHeading id="getcanvas" depth="3" name="getCanvas" sig="getCanvas(): ifDraw2D" />

Gets the bitmap the game is currently drawing to

**Returns**

- `ifDraw2D`

<MemberHeading id="getscreen" depth="3" name="getScreen" sig="getScreen(): roScreen" />

Gets the screen object

**Returns**

- `roScreen`

<MemberHeading id="getscreensize" depth="3" name="getScreenSize" sig="getScreenSize(): BGE.Math.Vector" />

**Returns**

- `BGE.Math.Vector`

<MemberHeading id="getscreencenter" depth="3" name="getScreenCenter" sig="getScreenCenter(): BGE.Math.Vector" />

**Returns**

- `BGE.Math.Vector`

<MemberHeading id="resetscreen" depth="3" name="resetScreen" sig="resetScreen(): void" />

Resets the screen Note: _Important_ This function is here because of a bug with the Roku. If you ever try to use a component that displays something on the screen aside from roScreen, such as roKeyboardScreen, roMessageDialog, etc. the screen will flicker after you return to your game You should always call this method after using a screen that's outside of roScreen in order to prevent this bug.

**Returns**

- `void`

<MemberHeading id="getemptybitmap" depth="3" name="getEmptyBitmap" sig="getEmptyBitmap(): roBitmap" />

Gets a 1x1 bitmap image (used for collider compositing)

**Returns**

- `roBitmap`

<MemberHeading id="getui" depth="3" name="getUI" sig="getUI(): BGE.Ui.UiContainer" />

Gets the UI Container to add new UI elements (which get drawn on top off Game Entities)

**Returns**

- `BGE.Ui.UiContainer`

<MemberHeading id="getdebugui" depth="3" name="getDebugUI" sig="getDebugUI(): BGE.UI.UiContainer" />

Gets the main debug window to add other debug widgets to

**Returns**

- `BGE.UI.UiContainer`

<MemberHeading id="debugdrawcolliders" depth="3" name="debugDrawColliders" sig="debugDrawColliders(enabled: boolean): void" />

Set if colliders should be drawn

**Parameters**

- `enabled` (boolean)

**Returns**

- `void`

<MemberHeading id="debugdrawsafezones" depth="3" name="debugDrawSafeZones" sig="debugDrawSafeZones(enabled: boolean): void" />

Set if Safe Zone should be drawn

**Parameters**

- `enabled` (boolean)

**Returns**

- `void`

<MemberHeading id="debugdrawentitydetails" depth="3" name="debugDrawEntityDetails" sig="debugDrawEntityDetails(enabled: boolean): void" />

Set GameEntity and SceneObject debug view on or off

**Parameters**

- `enabled` (boolean)

**Returns**

- `void`

<MemberHeading id="debugshowui" depth="3" name="debugShowUi" sig="debugShowUi(enabled: boolean, drawToScreen?: boolean): void" />

Set if Debug UI/Windows should be drawn

**Parameters**

- `enabled` (boolean)
- `drawToScreen` (boolean, optional, default: true) — Draw the debug UI to the screen instead of the canvas

**Returns**

- `void`

<MemberHeading id="isdebuguienabled" depth="3" name="isDebugUiEnabled" sig="isDebugUiEnabled(): boolean" />

**Returns**

- `boolean`

<MemberHeading id="getdebugvalue" depth="3" name="getDebugValue" sig="getDebugValue(debugKey: string): dynamic" />

**Parameters**

- `debugKey` (string)

**Returns**

- `dynamic`

<MemberHeading id="debugsetcolors" depth="3" name="debugSetColors" sig="debugSetColors(colors: DebugColors): void" />

Sets the colors for the debug items to be drawn colors = {colliders: integer, safe\_action\_zone: integer, safe\_title\_zone: integer}

**Parameters**

- `colors` ([DebugColors](/bge#debugcolors))

**Returns**

- `void`

<MemberHeading id="debuglimitframerate" depth="3" name="debugLimitFrameRate" sig="debugLimitFrameRate(limit_frame_rate: integer): void" />

Limit the frame rate to the given number of frames per second

**Parameters**

- `limit_frame_rate` (integer)

**Returns**

- `void`

<MemberHeading id="getgarbagecollectionstats" depth="3" name="getGarbageCollectionStats" sig="getGarbageCollectionStats(): GarbageCollectionInfo" />

Gets the latest stats from automatic garbage collection https\://developer.roku.com/en-ca/docs/references/brightscript/language/global-utility-functions.md#rungarbagecollector-as-object

**Returns**

- [`GarbageCollectionInfo`](/bge#garbagecollectioninfo) — Stats of garbage collection. Properties: count, orphaned, root

<MemberHeading
  id="raycastvector"
  depth="3"
  name="raycastVector"
  sig="raycastVector(
	sourceX: float,
	sourceY: float,
	vectorX: float,
	vectorY: float,
): object"
/>

Performs a raycast from a certain location along a vector to find any colliders on that line

**Parameters**

- `sourceX` (float) — x position of ray start
- `sourceY` (float) — y position of ray start
- `vectorX` (float) — x value of vector
- `vectorY` (float) — y value of vector

**Returns**

- `object` — {collider: collider, entity: entity} of first collider along the vector, or invalid if no collisions

<MemberHeading
  id="raycastangle"
  depth="3"
  name="raycastAngle"
  sig="raycastAngle(
	sourceX: float,
	sourceY: float,
	angle: float,
): object"
/>

Performs a raycast from a certain location along a n angle to find any colliders on that line

**Parameters**

- `sourceX` (float) — x position of ray start
- `sourceY` (float) — y position of ray start
- `angle` (float) — angle of ray

**Returns**

- `object` — {collider: collider, entity: entity} of first collider along the angle, or invalid if no collisions

<MemberHeading
  id="defineinterface"
  depth="3"
  name="defineInterface"
  sig="defineInterface(
	interfaceName: string,
	interfaceCreationFunction: function,
): void"
/>

TODO: work on interfaces

**Parameters**

- `interfaceName` (string)
- `interfaceCreationFunction` (function)

**Returns**

- `void`

<MemberHeading
  id="addentity"
  depth="3"
  name="addEntity"
  sig="addEntity(
	entity: GameEntity,
	args?: roAssociativeArray,
): GameEntity"
/>

Adds a game entity to be processed by the game engine Only entities that have been added will be part of the game Calls the entity's onCreate() function with the args provided

**Parameters**

- `entity` ([GameEntity](/bge#gameentity)) — the entity to be added
- `args` (roAssociativeArray, optional, default: "{}") — arguments to the entity's onCreate() method

**Returns**

- [`GameEntity`](/bge#gameentity) — the entity that was added

<MemberHeading id="getentitybyid" depth="3" name="getEntityByID" sig="getEntityByID(entityId: string | dynamic): GameEntity" />

Gets an entity by its unique id

**Parameters**

- `entityId` (string | dynamic)

**Returns**

- [`GameEntity`](/bge#gameentity) — the entity with the given id, if found, otherwise invalid

<MemberHeading id="getentitybyname" depth="3" name="getEntityByName" sig="getEntityByName(objectName: string): GameEntity" />

Gets the first entity with the given name

**Parameters**

- `objectName` (string)

**Returns**

- [`GameEntity`](/bge#gameentity) — the entity with the given name, if found, otherwise invalid

<MemberHeading id="getallentities" depth="3" name="getAllEntities" sig="getAllEntities(objectName: string): dynamic" />

Gets all the entities that match the given name

**Parameters**

- `objectName` (string)

**Returns**

- `dynamic` — an array with entities with the given name

<MemberHeading id="getallentitieswithinterface" depth="3" name="getAllEntitiesWithInterface" sig="getAllEntitiesWithInterface(interfaceName: string): dynamic" />

TODO: work on interfaces

**Parameters**

- `interfaceName` (string)

**Returns**

- `dynamic`

<MemberHeading id="destroyentity" depth="3" name="destroyEntity" sig="destroyEntity(entity: GameEntity, callOnDestroy?: boolean): void" />

Destroys an entity and all its colliders Clears its properties, so images, etc. won't get drawn anymore

**Parameters**

- `entity` ([GameEntity](/bge#gameentity)) — the entity to destroy
- `callOnDestroy` (boolean, optional, default: true)

**Returns**

- `void`

<MemberHeading
  id="destroyallentities"
  depth="3"
  name="destroyAllEntities"
  sig="destroyAllEntities(
	objectName: string,
	callOnDestroy?: boolean,
): void"
/>

Destroys all entities with a given name

**Parameters**

- `objectName` (string)
- `callOnDestroy` (boolean, optional, default: true)

**Returns**

- `void`

<MemberHeading id="entitycount" depth="3" name="entityCount" sig="entityCount(objectName: string): integer" />

Gets the number of entities of a given name

**Parameters**

- `objectName` (string)

**Returns**

- `integer`

<MemberHeading id="defineroom" depth="3" name="defineRoom" sig="defineRoom(room: Room, newRoom: Room): void" />

Defines a room (like a level) in the game TODO: work on rooms

**Parameters**

- `room` ([Room](/bge#room))
- `newRoom` ([Room](/bge#room))

**Returns**

- `void`

<MemberHeading id="isroomchanging" depth="3" name="isRoomChanging" sig="isRoomChanging(): boolean" />

**Returns**

- `boolean`

<MemberHeading id="changeroom" depth="3" name="changeRoom" sig="changeRoom(roomName: string, args?: roAssociativeArray): boolean" />

Changes the active room to the one with the given name Calls the room's onCreate() method with the args given TODO: work on rooms

**Parameters**

- `roomName` (string)
- `args` (roAssociativeArray, optional, default: "{}")

**Returns**

- `boolean` — true if room change was successful

<MemberHeading id="resetroom" depth="3" name="resetRoom" sig="resetRoom(): void" />

Resets the current room to its state at when it was first created

**Returns**

- `void`

<MemberHeading id="loadbitmap" depth="3" name="loadBitmap" sig="loadBitmap(bitmapName: string, path: dynamic): boolean" />

Loads an image file (png/jpg) to be used as an image in the game

**Parameters**

- `bitmapName` (string) — the name this bitmap will be referenced by later
- `path` (dynamic) — The path to the bitmap, or an associative array {width: integer, height: integer, alphaEnable:boolean}

**Returns**

- `boolean` — true if image was loaded

<MemberHeading id="getbitmap" depth="3" name="getBitmap" sig="getBitmap(bitmapName: string): roBitmap" />

Gets a bitmap image (roBitmap) by the name given to it when loadBitmap() was called

**Parameters**

- `bitmapName` (string)

**Returns**

- `roBitmap`

<MemberHeading id="unloadbitmap" depth="3" name="unloadBitmap" sig="unloadBitmap(bitmapName: string): void" />

Invalidates a bitmap name, so it can't be loaded again

**Parameters**

- `bitmapName` (string)

**Returns**

- `void`

<MemberHeading
  id="load3dmodel"
  depth="3"
  name="load3dModel"
  sig="load3dModel(
	bitmapName: string,
	path: dynamic,
	modelName: string,
	modelPath: string,
): boolean"
/>

Loads an image file (png/jpg) to be used as an image in the game

**Parameters**

- `bitmapName` (string) — the name this bitmap will be referenced by later
- `path` (dynamic) — The path to the bitmap, or an associative array {width: integer, height: integer, alphaEnable:boolean}
- `modelName` (string)
- `modelPath` (string)

**Returns**

- `boolean` — true if image was loaded

<MemberHeading id="get3dmodel" depth="3" name="get3dModel" sig="get3dModel(modelName: string): Model3d" />

Gets a 3d Model (Model3d) by the name given to it when load3dModel() was called

**Parameters**

- `modelName` (string)

**Returns**

- [`Model3d`](/bge#model3d)

<MemberHeading id="unload3dmodel" depth="3" name="unload3dModel" sig="unload3dModel(modelName: string): void" />

Invalidates a 3d Model name, so it can't be loaded again

**Parameters**

- `modelName` (string)

**Returns**

- `void`

<MemberHeading id="registerfont" depth="3" name="registerFont" sig="registerFont(path: string): boolean" />

Registers a font by its path

**Parameters**

- `path` (string)

**Returns**

- `boolean` — true if font was registered

<MemberHeading
  id="loadfont"
  depth="3"
  name="loadFont"
  sig="loadFont(
	fontName: string,
	font: string,
	size: integer,
	italic: boolean,
	bold: boolean,
): void"
/>

Loads a font from the registry, and assigns it the given name

**Parameters**

- `fontName` (string) — the lookup name to assign to this font
- `font` (string) — the font to load
- `size` (integer)
- `italic` (boolean)
- `bold` (boolean)

**Returns**

- `void`

<MemberHeading id="unloadfont" depth="3" name="unloadFont" sig="unloadFont(fontName: string): void" />

Unloads a font so it can't be used again

**Parameters**

- `fontName` (string)

**Returns**

- `void`

<MemberHeading id="getfont" depth="3" name="getFont" sig="getFont(fontName: string): roFont" />

Gets a font object, to be used for writing text to the screen For example, in BGE.DrawText()

**Parameters**

- `fontName` (string)

**Returns**

- `roFont`

<MemberHeading id="fitcanvastoscreen" depth="3" name="fitCanvasToScreen" sig="fitCanvasToScreen(): void" />

Scales and positions the current canvas to fit the screen

**Returns**

- `void`

<MemberHeading id="centercanvastoscreen" depth="3" name="centerCanvasToScreen" sig="centerCanvasToScreen(): void" />

Centers the canvas on the screen

**Returns**

- `void`

<MemberHeading id="musicplay" depth="3" name="musicPlay" sig="musicPlay(path: string, loop?: boolean): boolean" />

Plays an audio file at the given path This is designed for music, where only one file can play at a time.

**Parameters**

- `path` (string) — the path of the music file
- `loop` (boolean, optional, default: false)

**Returns**

- `boolean`

<MemberHeading id="musicstop" depth="3" name="musicStop" sig="musicStop(): void" />

Stops the currently playing music file

**Returns**

- `void`

<MemberHeading id="musicpause" depth="3" name="musicPause" sig="musicPause(): void" />

Pauses the currently playing music

**Returns**

- `void`

<MemberHeading id="musicresume" depth="3" name="musicResume" sig="musicResume(): void" />

Resumes / unpauses the current music

**Returns**

- `void`

<MemberHeading id="loadsound" depth="3" name="loadSound" sig="loadSound(soundName: string, path: string): void" />

Loads a sound file from the given path to be played later

**Parameters**

- `soundName` (string) — the name to assign this sound to, to be referenced later
- `path` (string) — the path to load

**Returns**

- `void`

<MemberHeading id="playsound" depth="3" name="playSound" sig="playSound(soundName: string, volume?: integer): boolean" />

Plays the given sound

**Parameters**

- `soundName` (string) — the name of the sound to play
- `volume` (integer, optional, default: 100) — volume (0-100) to play the sound at

**Returns**

- `boolean`

<MemberHeading id="newasyncurltransfer" depth="3" name="newAsyncUrlTransfer" sig="newAsyncUrlTransfer(): roUrlTransfer" />

Creates a new URL Async Transfer object, which is handled by the game loop Events from this URL transfer will be set to entities via the onUrlEvent() method

**Returns**

- `roUrlTransfer`

<MemberHeading id="setinputentity" depth="3" name="setInputEntity" sig="setInputEntity(entity: GameEntity): void" />

Set only one entity to receive onInput() calls Useful for when a menu/pause screen should handle all input

**Parameters**

- `entity` ([GameEntity](/bge#gameentity))

**Returns**

- `void`

<MemberHeading id="unsetinputentity" depth="3" name="unsetInputEntity" sig="unsetInputEntity(): void" />

Unset that only one entity will receive onInputCalls()

**Returns**

- `void`

<MemberHeading
  id="postgameevent"
  depth="3"
  name="postGameEvent"
  sig="postGameEvent(
	eventName: string,
	data?: roAssociativeArray,
): void"
/>

General purpose event dispatch method Game entities can listen for events via the onGameEvent() method

**Parameters**

- `eventName` (string) — identifier for the event, eg. "hit", "win", etc.
- `data` (roAssociativeArray, optional, default: "{}") — any data that needs to be be passed with the event

**Returns**

- `void`
