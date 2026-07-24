---
title: Renderer
kind: class
longname: BGE.Renderer
description: Wrapper for Draw2D calls, so that we can keep track of how much is being drawn per frame
---

# Renderer

Wrapper for Draw2D calls, so that we can keep track of how much is being drawn per frame

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

---

## Constructor

<Signature
  code="new Renderer(
	draw2d: ifDraw2d,
	mainGame?: BGE.Game,
	cam?: BGE.Camera,
	options?: RendererOptions,
): Renderer"
/>

**Parameters**

- `draw2d` (ifDraw2d)
- `mainGame` ([BGE.Game](/bge#game), optional, default: "invalid")
- `cam` ([BGE.Camera](/bge#camera), optional, default: "invalid")
- `options` ([RendererOptions](/bge#rendereroptions), optional, default: "{useBitmapPooling: true}")

---

## Instance Methods

<MemberHeading id="setdraw2d" depth="3" name="setDraw2d" sig="setDraw2d(draw2d: ifDraw2d): void" />

**Parameters**

- `draw2d` (ifDraw2d)

**Returns**

- `void`

<MemberHeading id="setcamera" depth="3" name="setCamera" sig="setCamera(camera: Camera): void" />

**Parameters**

- `camera` ([Camera](/bge#camera))

**Returns**

- `void`

<MemberHeading id="resetdrawcallcounter" depth="3" name="resetDrawCallCounter" sig="resetDrawCallCounter(): void" />

**Returns**

- `void`

<MemberHeading id="addsceneobject" depth="3" name="addSceneObject" sig="addSceneObject(sceneObj: SceneObject): void" />

**Parameters**

- `sceneObj` ([SceneObject](/bge#sceneobject))

**Returns**

- `void`

<MemberHeading id="removesceneobject" depth="3" name="removeSceneObject" sig="removeSceneObject(sceneObjToRemove: SceneObject): void" />

**Parameters**

- `sceneObjToRemove` ([SceneObject](/bge#sceneobject))

**Returns**

- `void`

<MemberHeading id="setupcameraforframe" depth="3" name="setupCameraForFrame" sig="setupCameraForFrame(): void" />

**Returns**

- `void`

<MemberHeading id="drawscene" depth="3" name="drawScene" sig="drawScene(): void" />

**Returns**

- `void`

<MemberHeading id="onswapbuffers" depth="3" name="onSwapBuffers" sig="onSwapBuffers(): void" />

**Returns**

- `void`

<MemberHeading
  id="worldpointtocanvaspoint"
  depth="3"
  name="worldPointToCanvasPoint"
  sig="worldPointToCanvasPoint(
	pWorld: BGE.Math.Vector,
): BGE.Math.Vector"
/>

**Parameters**

- `pWorld` (BGE.Math.Vector)

**Returns**

- `BGE.Math.Vector`

<MemberHeading
  id="getrayfromcameratoworldpoint"
  depth="3"
  name="getRayFromCameraToWorldPoint"
  sig="getRayFromCameraToWorldPoint(
	pWorld: BGE.Math.Vector,
): BGE.Math.Vector"
/>

**Parameters**

- `pWorld` (BGE.Math.Vector)

**Returns**

- `BGE.Math.Vector`

<MemberHeading
  id="drawline"
  depth="3"
  name="drawLine"
  sig="drawLine(
	x: float,
	y: float,
	endX: float,
	endY: float,
	rgba: integer,
): boolean"
/>

**Parameters**

- `x` (float)
- `y` (float)
- `endX` (float)
- `endY` (float)
- `rgba` (integer)

**Returns**

- `boolean`

<MemberHeading
  id="drawlineto"
  depth="3"
  name="drawLineTo"
  sig="drawLineTo(
	draw2d: ifDraw2d,
	x: float,
	y: float,
	endX: float,
	endY: float,
	rgba: integer,
): boolean"
/>

**Parameters**

- `draw2d` (ifDraw2d)
- `x` (float)
- `y` (float)
- `endX` (float)
- `endY` (float)
- `rgba` (integer)

**Returns**

- `boolean`

<MemberHeading
  id="drawsquare"
  depth="3"
  name="drawSquare"
  sig="drawSquare(
	x: float,
	y: float,
	sideLength: float,
	rgba: integer,
): boolean"
/>

**Parameters**

- `x` (float)
- `y` (float)
- `sideLength` (float)
- `rgba` (integer)

**Returns**

- `boolean`

<MemberHeading
  id="drawsquareto"
  depth="3"
  name="drawSquareTo"
  sig="drawSquareTo(
	draw2d: ifDraw2d,
	x: float,
	y: float,
	sideLength: float,
	rgba: integer,
): boolean"
/>

**Parameters**

- `draw2d` (ifDraw2d)
- `x` (float)
- `y` (float)
- `sideLength` (float)
- `rgba` (integer)

**Returns**

- `boolean`

<MemberHeading
  id="drawrectangle"
  depth="3"
  name="drawRectangle"
  sig="drawRectangle(
	x: float,
	y: float,
	width: float,
	height: float,
	rgba: integer,
): boolean"
/>

**Parameters**

- `x` (float)
- `y` (float)
- `width` (float)
- `height` (float)
- `rgba` (integer)

**Returns**

- `boolean`

<MemberHeading
  id="drawrectangleto"
  depth="3"
  name="drawRectangleTo"
  sig="drawRectangleTo(
	draw2d: ifDraw2d,
	x: float,
	y: float,
	width: float,
	height: float,
	rgba: integer,
): boolean"
/>

**Parameters**

- `draw2d` (ifDraw2d)
- `x` (float)
- `y` (float)
- `width` (float)
- `height` (float)
- `rgba` (integer)

**Returns**

- `boolean`

<MemberHeading
  id="drawtext"
  depth="3"
  name="drawText"
  sig="drawText(
	text: string,
	x: integer,
	y: integer,
	color?: integer,
	font?: roFont,
	horizAlign?: string,
	vertAlign?: string,
): boolean"
/>

Draws text to the screen

**Parameters**

- `text` (string) — the test to display
- `x` (integer)
- `y` (integer)
- `color` (integer, optional, default: -1) — RGBA color to use
- `font` (roFont, optional, default: "invalid") — Font object to use (uses default font if none provided)
- `horizAlign` (string, optional, default: "\\"left\\"") — Horizontal Alignment - "left", "right" or "center"
- `vertAlign` (string, optional, default: "\\"top\\"") — Vertical Alignment - "top", "bottom" or "center"

**Returns**

- `boolean`

<MemberHeading
  id="drawtextto"
  depth="3"
  name="drawTextTo"
  sig="drawTextTo(
	draw2d: ifDraw2d,
	text: string,
	x: integer,
	y: integer,
	color?: integer,
	font?: roFont,
	horizAlign?: string,
	vertAlign?: string,
	lineSpace?: integer,
): boolean"
/>

Draws text to a canvas

**Parameters**

- `draw2d` (ifDraw2d)
- `text` (string) — the test to display
- `x` (integer)
- `y` (integer)
- `color` (integer, optional, default: -1) — RGBA color to use
- `font` (roFont, optional, default: "invalid") — Font object to use (uses default font if none provided)
- `horizAlign` (string, optional, default: "\\"left\\"") — Horizontal Alignment - "left", "right" or "center"
- `vertAlign` (string, optional, default: "\\"top\\"") — Vertical Alignment - "top", "bottom" or "center"
- `lineSpace` (integer, optional, default: 0) — Additional space between lines

**Returns**

- `boolean`

<MemberHeading
  id="drawtransformedobject"
  depth="3"
  name="drawTransformedObject"
  sig="drawTransformedObject(
	x: float,
	y: float,
	scaleX: float,
	scaleY: float,
	theta: float,
	region: ifDraw2d,
	rgba?: integer,
): boolean"
/>

NOTE: This function is unsafe! It creates an roBitmap of the required size to be able to both scale and rotate the drawing, this action requires free video memory of the appropriate amount.

**Parameters**

- `x` (float)
- `y` (float)
- `scaleX` (float)
- `scaleY` (float)
- `theta` (float)
- `region` (ifDraw2d)
- `rgba` (integer, optional, default: -1)

**Returns**

- `boolean`

<MemberHeading
  id="drawtransformedobjectto"
  depth="3"
  name="drawTransformedObjectTo"
  sig="drawTransformedObjectTo(
	draw2d: ifDraw2d,
	x: float,
	y: float,
	scale_x: float,
	scale_y: float,
	theta: float,
	region: ifDraw2d,
	rgba?: integer,
): boolean"
/>

**Parameters**

- `draw2d` (ifDraw2d)
- `x` (float)
- `y` (float)
- `scale_x` (float)
- `scale_y` (float)
- `theta` (float)
- `region` (ifDraw2d)
- `rgba` (integer, optional, default: -1)

**Returns**

- `boolean`

<MemberHeading
  id="drawpinnedcorners"
  depth="3"
  name="drawPinnedCorners"
  sig="drawPinnedCorners(
	cornerPoints: BGE.Math.CornerPoints,
	drawableRegion: BGE.RendererHelpers.RegionWithId,
	options?: DrawPinnedCornersOptions,
	color?: integer,
): boolean"
/>

**Parameters**

- `cornerPoints` (BGE.Math.CornerPoints)
- `drawableRegion` (BGE.RendererHelpers.RegionWithId)
- `options` ([DrawPinnedCornersOptions](/bge#drawpinnedcornersoptions), optional, default: "{}")
- `color` (integer, optional, default: -1)

**Returns**

- `boolean`

<MemberHeading
  id="drawrotatedimagewithcenterto"
  depth="3"
  name="drawRotatedImageWithCenterTo"
  sig="drawRotatedImageWithCenterTo(
	draw2d: ifDraw2d,
	srcRegion: ifDraw2d,
	center: BGE.Math.Vector,
	theta: float,
	translation?: BGE.Math.Vector,
	drawScale?: BGE.Math.Vector,
): boolean"
/>

**Parameters**

- `draw2d` (ifDraw2d)
- `srcRegion` (ifDraw2d)
- `center` (BGE.Math.Vector)
- `theta` (float)
- `translation` (BGE.Math.Vector, optional, default: "BGE.Math.VectorOps.create()")
- `drawScale` (BGE.Math.Vector, optional, default: "BGE.Math.createScaleVector(1)")

**Returns**

- `boolean`

<MemberHeading
  id="makeintotriangle"
  depth="3"
  name="makeIntoTriangle"
  sig="makeIntoTriangle(
	srcRegionWithId: BGE.RendererHelpers.RegionWithId,
	points: dynamic,
	makeAcute?: boolean,
	useCache?: boolean,
): BGE.RendererHelpers.TriangleBitmap"
/>

**Parameters**

- `srcRegionWithId` (BGE.RendererHelpers.RegionWithId)
- `points` (dynamic)
- `makeAcute` (boolean, optional, default: false)
- `useCache` (boolean, optional, default: false)

**Returns**

- `BGE.RendererHelpers.TriangleBitmap`

<MemberHeading
  id="drawbitmaptriangle"
  depth="3"
  name="drawBitmapTriangle"
  sig="drawBitmapTriangle(
	srcRegionWithId: BGE.RendererHelpers.RegionWithId,
	srcPoints: dynamic,
	destPoints: dynamic,
	rgba?: integer,
): boolean"
/>

Draws a bitmap warped from srcPoints onto destPoints, directly to this renderer's own canvas. See drawBitmapTriangleTo() for the note about staged scratch bitmaps.

**Parameters**

- `srcRegionWithId` (BGE.RendererHelpers.RegionWithId) — the region to draw from
- `srcPoints` (dynamic)
- `destPoints` (dynamic)
- `rgba` (integer, optional, default: -1)

**Returns**

- `boolean` — true if it worked

<MemberHeading
  id="drawbitmaptriangleto"
  depth="3"
  name="drawBitmapTriangleTo"
  sig="drawBitmapTriangleTo(
	draw2d: ifDraw2d,
	srcRegionWithId: BGE.RendererHelpers.RegionWithId,
	srcPoints: dynamic,
	destPoints: dynamic,
	rgba?: integer,
): boolean"
/>

NOTE: This method uses temporary bitmaps. In order not to re-use them for subsequent calls they are staged for return to the bitmap pool. You need to manually call bmpPool.returnStagedRegions() to return them after you're sure all the drawing to the surface is done

**Parameters**

- `draw2d` (ifDraw2d)
- `srcRegionWithId` (BGE.RendererHelpers.RegionWithId) — the region to draw from
- `srcPoints` (dynamic)
- `destPoints` (dynamic)
- `rgba` (integer, optional, default: -1)

**Returns**

- `boolean` — true if it worked

<MemberHeading
  id="drawpinnedcornersto"
  depth="3"
  name="drawPinnedCornersTo"
  sig="drawPinnedCornersTo(
	draw2d: ifDraw2d,
	cornerPoints: BGE.Math.CornerPoints,
	drawableRegion: BGE.RendererHelpers.RegionWithId,
	options?: DrawPinnedCornersOptions,
	color?: integer,
): boolean"
/>

**Parameters**

- `draw2d` (ifDraw2d)
- `cornerPoints` (BGE.Math.CornerPoints)
- `drawableRegion` (BGE.RendererHelpers.RegionWithId)
- `options` ([DrawPinnedCornersOptions](/bge#drawpinnedcornersoptions), optional, default: "{}")
- `color` (integer, optional, default: -1)

**Returns**

- `boolean`

<MemberHeading
  id="drawcircleoutline"
  depth="3"
  name="drawCircleOutline"
  sig="drawCircleOutline(
	line_count: integer,
	x: float,
	y: float,
	radius: float,
	rgba: integer,
): boolean"
/>

**Parameters**

- `line_count` (integer)
- `x` (float)
- `y` (float)
- `radius` (float)
- `rgba` (integer)

**Returns**

- `boolean`

<MemberHeading
  id="drawrectangleoutline"
  depth="3"
  name="drawRectangleOutline"
  sig="drawRectangleOutline(
	x: float,
	y: float,
	width: float,
	height: float,
	rgba: integer,
): boolean"
/>

**Parameters**

- `x` (float)
- `y` (float)
- `width` (float)
- `height` (float)
- `rgba` (integer)

**Returns**

- `boolean`

<MemberHeading
  id="drawpolygonoutline"
  depth="3"
  name="drawPolygonOutline"
  sig="drawPolygonOutline(
	pointsArray: dynamic,
	colorRgba: integer,
): boolean"
/>

**Parameters**

- `pointsArray` (dynamic)
- `colorRgba` (integer)

**Returns**

- `boolean`

<MemberHeading
  id="drawpolygonoutlineto"
  depth="3"
  name="drawPolygonOutlineTo"
  sig="drawPolygonOutlineTo(
	draw2d: ifDraw2d,
	pointsArray: dynamic,
	colorRgba: integer,
): boolean"
/>

**Parameters**

- `draw2d` (ifDraw2d)
- `pointsArray` (dynamic)
- `colorRgba` (integer)

**Returns**

- `boolean`

<MemberHeading
  id="drawobject"
  depth="3"
  name="drawObject"
  sig="drawObject(
	x: integer,
	y: integer,
	src: ifDraw2d,
	rgba?: integer,
): boolean"
/>

**Parameters**

- `x` (integer)
- `y` (integer)
- `src` (ifDraw2d)
- `rgba` (integer, optional, default: -1)

**Returns**

- `boolean`

<MemberHeading
  id="drawobjectto"
  depth="3"
  name="drawObjectTo"
  sig="drawObjectTo(
	draw2d: ifDraw2d,
	x: integer,
	y: integer,
	src: ifDraw2d,
	rgba?: integer,
): boolean"
/>

**Parameters**

- `draw2d` (ifDraw2d)
- `x` (integer)
- `y` (integer)
- `src` (ifDraw2d)
- `rgba` (integer, optional, default: -1)

**Returns**

- `boolean`

<MemberHeading
  id="drawscaledobject"
  depth="3"
  name="drawScaledObject"
  sig="drawScaledObject(
	x: integer,
	y: integer,
	scaleX: float,
	scaleY: float,
	src: ifDraw2d,
	rgba?: integer,
): boolean"
/>

**Parameters**

- `x` (integer)
- `y` (integer)
- `scaleX` (float)
- `scaleY` (float)
- `src` (ifDraw2d)
- `rgba` (integer, optional, default: -1)

**Returns**

- `boolean`

<MemberHeading
  id="drawscaledobjectto"
  depth="3"
  name="drawScaledObjectTo"
  sig="drawScaledObjectTo(
	draw2d: ifDraw2d,
	x: integer,
	y: integer,
	scaleX: float,
	scaleY: float,
	src: ifDraw2d,
	rgba?: integer,
): boolean"
/>

**Parameters**

- `draw2d` (ifDraw2d)
- `x` (integer)
- `y` (integer)
- `scaleX` (float)
- `scaleY` (float)
- `src` (ifDraw2d)
- `rgba` (integer, optional, default: -1)

**Returns**

- `boolean`

<MemberHeading
  id="drawrotatedobject"
  depth="3"
  name="drawRotatedObject"
  sig="drawRotatedObject(
	x: integer,
	y: integer,
	theta: float,
	src: ifDraw2d,
	rgba?: integer,
): boolean"
/>

**Parameters**

- `x` (integer)
- `y` (integer)
- `theta` (float)
- `src` (ifDraw2d)
- `rgba` (integer, optional, default: -1)

**Returns**

- `boolean`

<MemberHeading
  id="drawrotatedobjectto"
  depth="3"
  name="drawRotatedObjectTo"
  sig="drawRotatedObjectTo(
	draw2d: ifDraw2d,
	x: integer,
	y: integer,
	theta: float,
	src: ifDraw2d,
	rgba?: integer,
): boolean"
/>

**Parameters**

- `draw2d` (ifDraw2d)
- `x` (integer)
- `y` (integer)
- `theta` (float)
- `src` (ifDraw2d)
- `rgba` (integer, optional, default: -1)

**Returns**

- `boolean`

<MemberHeading
  id="drawregion"
  depth="3"
  name="drawRegion"
  sig="drawRegion(
	regionToDraw: ifDraw2d,
	x: float,
	y: float,
	scaleX?: float,
	scaleY?: float,
	rotation?: float,
	rgba?: integer,
): boolean"
/>

**Parameters**

- `regionToDraw` (ifDraw2d)
- `x` (float)
- `y` (float)
- `scaleX` (float, optional, default: 1)
- `scaleY` (float, optional, default: 1)
- `rotation` (float, optional, default: 0)
- `rgba` (integer, optional, default: -1)

**Returns**

- `boolean`

<MemberHeading
  id="drawregionto"
  depth="3"
  name="drawRegionTo"
  sig="drawRegionTo(
	canvasDrawTo: ifDraw2d,
	regionToDraw: ifDraw2d,
	x: float,
	y: float,
	scaleX?: float,
	scaleY?: float,
	rotation?: float,
	rgba?: integer,
): boolean"
/>

**Parameters**

- `canvasDrawTo` (ifDraw2d)
- `regionToDraw` (ifDraw2d)
- `x` (float)
- `y` (float)
- `scaleX` (float, optional, default: 1)
- `scaleY` (float, optional, default: 1)
- `rotation` (float, optional, default: 0)
- `rgba` (integer, optional, default: -1)

**Returns**

- `boolean`

<MemberHeading
  id="drawtriangle"
  depth="3"
  name="drawTriangle"
  sig="drawTriangle(
	points: dynamic,
	x: float,
	y: float,
	rgba: integer,
	allowQuickDraw?: boolean,
): boolean"
/>

**Parameters**

- `points` (dynamic)
- `x` (float)
- `y` (float)
- `rgba` (integer)
- `allowQuickDraw` (boolean, optional, default: false)

**Returns**

- `boolean`

<MemberHeading
  id="drawtriangleto"
  depth="3"
  name="drawTriangleTo"
  sig="drawTriangleTo(
	canvasDrawTo: ifDraw2d,
	points: dynamic,
	x: float,
	y: float,
	rgba: integer,
	allowQuickDraw?: boolean,
): boolean"
/>

**Parameters**

- `canvasDrawTo` (ifDraw2d)
- `points` (dynamic)
- `x` (float)
- `y` (float)
- `rgba` (integer)
- `allowQuickDraw` (boolean, optional, default: false)

**Returns**

- `boolean`

<MemberHeading
  id="drawpolygon"
  depth="3"
  name="drawPolygon"
  sig="drawPolygon(
	points: dynamic,
	x: float,
	y: float,
	rgba: integer,
	allowQuickDraw?: boolean,
): boolean"
/>

**Parameters**

- `points` (dynamic)
- `x` (float)
- `y` (float)
- `rgba` (integer)
- `allowQuickDraw` (boolean, optional, default: false)

**Returns**

- `boolean`

<MemberHeading
  id="drawpolygonto"
  depth="3"
  name="drawPolygonTo"
  sig="drawPolygonTo(
	canvasDrawTo: ifDraw2d,
	points: dynamic,
	x: float,
	y: float,
	rgba: integer,
	allowQuickDraw?: boolean,
): boolean"
/>

**Parameters**

- `canvasDrawTo` (ifDraw2d)
- `points` (dynamic)
- `x` (float)
- `y` (float)
- `rgba` (integer)
- `allowQuickDraw` (boolean, optional, default: false)

**Returns**

- `boolean`

<MemberHeading
  id="drawpolygonasrectangles"
  depth="3"
  name="drawPolygonAsRectangles"
  sig="drawPolygonAsRectangles(
	canvasDrawTo: ifDraw2d,
	points: dynamic,
	x: float,
	y: float,
	rgba: integer,
	options?: LevelOfDetailOptions,
): boolean"
/>

**Parameters**

- `canvasDrawTo` (ifDraw2d)
- `points` (dynamic)
- `x` (float)
- `y` (float)
- `rgba` (integer)
- `options` ([LevelOfDetailOptions](/bge#levelofdetailoptions), optional, default: "{levelOffset: 0, levelOfDetail: 2}")

**Returns**

- `boolean`

<MemberHeading
  id="drawpolygonasrectanglesto"
  depth="3"
  name="drawPolygonAsRectanglesTo"
  sig="drawPolygonAsRectanglesTo(
	canvasDrawTo: ifDraw2d,
	points: dynamic,
	x: float,
	y: float,
	rgba: integer,
	options?: LevelOfDetailOptions,
): boolean"
/>

Draw a filled convex polygon with rectangles

**Parameters**

- `canvasDrawTo` (ifDraw2d)
- `points` (dynamic)
- `x` (float)
- `y` (float)
- `rgba` (integer)
- `options` ([LevelOfDetailOptions](/bge#levelofdetailoptions), optional, default: "{levelOffset: 0, levelOfDetail: 2}")

**Returns**

- `boolean`

<MemberHeading
  id="drawtriangleasraysto"
  depth="3"
  name="drawTriangleAsRaysTo"
  sig="drawTriangleAsRaysTo(
	canvasDrawTo: ifDraw2d,
	points: dynamic,
	x: float,
	y: float,
	rgba: integer,
	options?: LevelOfDetailOptions,
): boolean"
/>

**Parameters**

- `canvasDrawTo` (ifDraw2d)
- `points` (dynamic)
- `x` (float)
- `y` (float)
- `rgba` (integer)
- `options` ([LevelOfDetailOptions](/bge#levelofdetailoptions), optional, default: "{levelOffset: 0, levelOfDetail: 2}")

**Returns**

- `boolean`

<MemberHeading id="getcanvassize" depth="3" name="getCanvasSize" sig="getCanvasSize(): BGE.Math.Vector" />

**Returns**

- `BGE.Math.Vector`

<MemberHeading id="getcanvascenter" depth="3" name="getCanvasCenter" sig="getCanvasCenter(): BGE.Math.Vector" />

**Returns**

- `BGE.Math.Vector`

<MemberHeading
  id="isinsidecanvas"
  depth="3"
  name="isInsideCanvas"
  sig="isInsideCanvas(
	draw2d: object,
	x: float,
	y: float,
	width: float,
	height: float,
	rotation?: float,
): boolean"
/>

Checks to see if a rectangle will be in a Draw2d Canvas

**Parameters**

- `draw2d` (object)
- `x` (float)
- `y` (float)
- `width` (float)
- `height` (float)
- `rotation` (float, optional, default: 0)

**Returns**

- `boolean` — true if this rectangle overlaps with the canvas

<MemberHeading
  id="drawtrianglepoints"
  depth="3"
  name="drawTrianglePoints"
  sig="drawTrianglePoints(
	points: dynamic,
	size?: integer,
	offset?: PositionXY,
	drawRegardlessOfDebugValue?: boolean,
): boolean"
/>

**Parameters**

- `points` (dynamic)
- `size` (integer, optional, default: 5)
- `offset` ([PositionXY](/bge#positionxy), optional, default: "{x: 0, y: 0}")
- `drawRegardlessOfDebugValue` (boolean, optional, default: false)

**Returns**

- `boolean`

<MemberHeading
  id="drawtrianglepointsto"
  depth="3"
  name="drawTrianglePointsTo"
  sig="drawTrianglePointsTo(
	draw2dRegion: ifDraw2d,
	points: dynamic,
	size?: integer,
	offset?: PositionXY,
	drawRegardlessOfDebugValue?: boolean,
): boolean"
/>

**Parameters**

- `draw2dRegion` (ifDraw2d)
- `points` (dynamic)
- `size` (integer, optional, default: 5)
- `offset` ([PositionXY](/bge#positionxy), optional, default: "{x: 0, y: 0}")
- `drawRegardlessOfDebugValue` (boolean, optional, default: false)

**Returns**

- `boolean`

<MemberHeading
  id="drawtriangleoutline"
  depth="3"
  name="drawTriangleOutline"
  sig="drawTriangleOutline(
	pointsArray: dynamic,
	colorRgba: integer,
	offset?: PositionXY,
): boolean"
/>

**Parameters**

- `pointsArray` (dynamic)
- `colorRgba` (integer)
- `offset` ([PositionXY](/bge#positionxy), optional, default: "{x: 0, y: 0}")

**Returns**

- `boolean`

<MemberHeading
  id="drawtriangleoutlineto"
  depth="3"
  name="drawTriangleOutlineTo"
  sig="drawTriangleOutlineTo(
	draw2d: ifDraw2d,
	pointsArray: dynamic,
	colorRgba: integer,
	offset?: PositionXY,
): boolean"
/>

**Parameters**

- `draw2d` (ifDraw2d)
- `pointsArray` (dynamic)
- `colorRgba` (integer)
- `offset` ([PositionXY](/bge#positionxy), optional, default: "{x: 0, y: 0}")

**Returns**

- `boolean`

<MemberHeading id="adddebugcell" depth="3" name="addDebugCell" sig="addDebugCell(region: ifDraw2d, text?: string): void" />

**Parameters**

- `region` (ifDraw2d)
- `text` (string, optional, default: "\\"\\"")

**Returns**

- `void`

<MemberHeading id="forcedraw" depth="3" name="forceDraw" sig="forceDraw(drawSurface: ifDraw2d): void" />

**Parameters**

- `drawSurface` (ifDraw2d)

**Returns**

- `void`
