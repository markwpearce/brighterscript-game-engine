---
title: SceneObjectBillboard
kind: class
longname: BGE.SceneObjectBillboard
---

# SceneObjectBillboard

**Extends:&#x20;**[`SceneObject`](/bge#sceneobject)

**Properties**

- `worldPoints` (BGE.Math.CornerPoints)
- `canvasPoints` (BGE.Math.CornerPoints)
- `useTempBitmapMap` (dynamic)

---

## Constructor

<Signature
  code="new SceneObjectBillboard(
	name: string,
	drawableObj: Drawable,
	objType: SceneObjectType,
): SceneObjectBillboard"
/>

**Parameters**

- `name` (string)
- `drawableObj` ([Drawable](/bge#drawable))
- `objType` ([SceneObjectType](/bge#sceneobjecttype))

---

## Instance Methods

<MemberHeading
  id="performdraw"
  depth="3"
  name="performDraw"
  sig="performDraw(
	rendererObj: BGE.Renderer,
	drawMode: SceneObjectDrawMode,
): boolean"
/>

<MemberMeta badges="protected" />

**Parameters**

- `rendererObj` ([BGE.Renderer](/bge#renderer))
- `drawMode` ([SceneObjectDrawMode](/bge#sceneobjectdrawmode))

**Returns**

- `boolean`

<MemberHeading
  id="isredrawtocanvasrequired"
  depth="3"
  name="isRedrawToCanvasRequired"
  sig="isRedrawToCanvasRequired(
	rendererObj: BGE.Renderer,
	drawMode: SceneObjectDrawMode,
): boolean"
/>

<MemberMeta badges="protected" />

**Parameters**

- `rendererObj` ([BGE.Renderer](/bge#renderer))
- `drawMode` ([SceneObjectDrawMode](/bge#sceneobjectdrawmode))

**Returns**

- `boolean`

<MemberHeading
  id="createtempbitmap"
  depth="3"
  name="createTempBitmap"
  sig="createTempBitmap(
	canvasBounds: dynamic,
	rendererObj: Renderer,
	drawMode: SceneObjectDrawMode,
	allowFastDraw?: boolean,
): roBitmap"
/>

<MemberMeta badges="protected" />

**Parameters**

- `canvasBounds` (dynamic)
- `rendererObj` ([Renderer](/bge#renderer))
- `drawMode` ([SceneObjectDrawMode](/bge#sceneobjectdrawmode))
- `allowFastDraw` (boolean, optional, default: false)

**Returns**

- `roBitmap`

<MemberHeading
  id="drawtocanvas"
  depth="3"
  name="drawToCanvas"
  sig="drawToCanvas(
	rendererObj: BGE.Renderer,
	drawMode: SceneObjectDrawMode,
): boolean"
/>

<MemberMeta badges="protected" />

**Parameters**

- `rendererObj` ([BGE.Renderer](/bge#renderer))
- `drawMode` ([SceneObjectDrawMode](/bge#sceneobjectdrawmode))

**Returns**

- `boolean`

<MemberHeading id="getcanvasbounds" depth="3" name="getCanvasBounds" sig="getCanvasBounds(): dynamic" />

<MemberMeta badges="protected" />

**Returns**

- `dynamic`

<MemberHeading id="getallcanvaspoints" depth="3" name="getAllCanvasPoints" sig="getAllCanvasPoints(): dynamic" />

<MemberMeta badges="protected" />

**Returns**

- `dynamic`

<MemberHeading id="getregionwithidtodraw" depth="3" name="getRegionWithIdToDraw" sig="getRegionWithIdToDraw(): BGE.RendererHelpers.RegionWithId" />

<MemberMeta badges="protected" />

**Returns**

- `BGE.RendererHelpers.RegionWithId`

<MemberHeading
  id="drawtotempbitmap"
  depth="3"
  name="drawToTempBitmap"
  sig="drawToTempBitmap(
	rendererObj: BGE.Renderer,
	tempBitmap: ifDraw2d,
	canvasPointsTopLeftBound: BGE.Math.Vector,
	drawMode: SceneObjectDrawMode,
	allowFastDraw?: boolean,
): TempBitmapDrawResult"
/>

<MemberMeta badges="protected" />

**Parameters**

- `rendererObj` ([BGE.Renderer](/bge#renderer))
- `tempBitmap` (ifDraw2d)
- `canvasPointsTopLeftBound` (BGE.Math.Vector)
- `drawMode` ([SceneObjectDrawMode](/bge#sceneobjectdrawmode))
- `allowFastDraw` (boolean, optional, default: false)

**Returns**

- [`TempBitmapDrawResult`](/bge#tempbitmapdrawresult)

<MemberHeading id="getpinnedcornersoptions" depth="3" name="getPinnedCornersOptions" sig="getPinnedCornersOptions(): DrawPinnedCornersOptions" />

<MemberMeta badges="protected" />

**Returns**

- [`DrawPinnedCornersOptions`](/bge#drawpinnedcornersoptions)

<MemberHeading id="didregiontodrawchange" depth="3" name="didRegionToDrawChange" sig="didRegionToDrawChange(): boolean" />

<MemberMeta badges="protected" />

**Returns**

- `boolean`

<MemberHeading
  id="getdrawcolorrgba"
  depth="3"
  name="getDrawColorRGBA"
  sig="getDrawColorRGBA(
	rendererObj: BGE.Renderer,
	ignoreColor?: boolean,
): integer"
/>

<MemberMeta badges="protected" />

**Parameters**

- `rendererObj` ([BGE.Renderer](/bge#renderer))
- `ignoreColor` (boolean, optional, default: false)

**Returns**

- `integer`

<MemberHeading id="updateworldposition" depth="3" name="updateWorldPosition" sig="updateWorldPosition(drawMode: SceneObjectDrawMode): boolean" />

<MemberMeta badges="protected" />

**Parameters**

- `drawMode` ([SceneObjectDrawMode](/bge#sceneobjectdrawmode))

**Returns**

- `boolean`

<MemberHeading
  id="getpositionforcameradistance"
  depth="3"
  name="getPositionForCameraDistance"
  sig="getPositionForCameraDistance(
	drawMode: SceneObjectDrawMode,
): BGE.Math.Vector"
/>

**Parameters**

- `drawMode` ([SceneObjectDrawMode](/bge#sceneobjectdrawmode))

**Returns**

- `BGE.Math.Vector`

<MemberHeading
  id="getpositionsforfrustumcheck"
  depth="3"
  name="getPositionsForFrustumCheck"
  sig="getPositionsForFrustumCheck(
	drawMode: SceneObjectDrawMode,
): dynamic"
/>

**Parameters**

- `drawMode` ([SceneObjectDrawMode](/bge#sceneobjectdrawmode))

**Returns**

- `dynamic`

<MemberHeading
  id="findcanvasposition"
  depth="3"
  name="findCanvasPosition"
  sig="findCanvasPosition(
	rendererObj: Renderer,
	drawMode: SceneObjectDrawMode,
): boolean"
/>

<MemberMeta badges="protected" />

**Parameters**

- `rendererObj` ([Renderer](/bge#renderer))
- `drawMode` ([SceneObjectDrawMode](/bge#sceneobjectdrawmode))

**Returns**

- `boolean`

<MemberHeading
  id="updatecanvasposition"
  depth="3"
  name="updateCanvasPosition"
  sig="updateCanvasPosition(
	rendererObj: Renderer,
	drawMode: SceneObjectDrawMode,
): boolean"
/>

<MemberMeta badges="protected" />

**Parameters**

- `rendererObj` ([Renderer](/bge#renderer))
- `drawMode` ([SceneObjectDrawMode](/bge#sceneobjectdrawmode))

**Returns**

- `boolean`

<MemberHeading id="computenormaldebuginfo" depth="3" name="computeNormalDebugInfo" sig="computeNormalDebugInfo(rendererObj: Renderer): void" />

<MemberMeta badges="protected" />

**Parameters**

- `rendererObj` ([Renderer](/bge#renderer))

**Returns**

- `void`

<MemberHeading id="getnormaldebugpoint" depth="3" name="getNormalDebugPoint" sig="getNormalDebugPoint(): BGE.Math.Vector" />

<MemberMeta badges="protected" />

**Returns**

- `BGE.Math.Vector`

<MemberHeading
  id="attempttransformtempbitmap"
  depth="3"
  name="attemptTransformTempBitmap"
  sig="attemptTransformTempBitmap(
	renderObj: Renderer,
	drawMode: SceneObjectDrawMode,
): TransformTempBitmapDetails"
/>

<MemberMeta badges="protected" />

Determine if we can just scale and/or rotate the temp bitmap to match the required position

**Parameters**

- `renderObj` ([Renderer](/bge#renderer))
- `drawMode` ([SceneObjectDrawMode](/bge#sceneobjectdrawmode))

**Returns**

- [`TransformTempBitmapDetails`](/bge#transformtempbitmapdetails)

<MemberHeading id="donotdrawbecausebackface" depth="3" name="doNotDrawBecauseBackFace" sig="doNotDrawBecauseBackFace(drawMode: SceneObjectDrawMode): boolean" />

<MemberMeta badges="protected" />

Is this a back and then we should not draw it?

**Parameters**

- `drawMode` ([SceneObjectDrawMode](/bge#sceneobjectdrawmode)) — some drawModes explicitly should draw the backface

**Returns**

- `boolean` — true if we should not draw

<MemberHeading id="gettempbitmapthreshold" depth="3" name="getTempBitmapThreshold" sig="getTempBitmapThreshold(drawMode: SceneObjectDrawMode): integer" />

<MemberMeta badges="protected" />

**Parameters**

- `drawMode` ([SceneObjectDrawMode](/bge#sceneobjectdrawmode))

**Returns**

- `integer`
