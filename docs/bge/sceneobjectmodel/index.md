---
title: SceneObjectModel
kind: class
longname: BGE.SceneObjectModel
---

# SceneObjectModel

**Extends:&#x20;**[`SceneObjectBillboard`](/bge#sceneobjectbillboard)

**Properties**

- `drawable` ([DrawableModel](/bge#drawablemodel))

---

## Constructor

<Signature
  code="new SceneObjectModel(
	name: string,
	drawableObj: DrawableModel,
): SceneObjectModel"
/>

**Parameters**

- `name` (string)
- `drawableObj` ([DrawableModel](/bge#drawablemodel))

---

## Instance Methods

<MemberHeading id="didregiontodrawchange" depth="3" name="didRegionToDrawChange" sig="didRegionToDrawChange(): boolean" />

<MemberMeta badges="protected" />

**Returns**

- `boolean`

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

<MemberHeading id="getallcanvaspoints" depth="3" name="getAllCanvasPoints" sig="getAllCanvasPoints(): dynamic" />

<MemberMeta badges="protected" />

**Returns**

- `dynamic`

<MemberHeading id="getcanvasbounds" depth="3" name="getCanvasBounds" sig="getCanvasBounds(): dynamic" />

<MemberMeta badges="protected" />

**Returns**

- `dynamic`

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

<MemberHeading id="gettempbitmapthreshold" depth="3" name="getTempBitmapThreshold" sig="getTempBitmapThreshold(drawMode: SceneObjectDrawMode): integer" />

<MemberMeta badges="protected" />

**Parameters**

- `drawMode` ([SceneObjectDrawMode](/bge#sceneobjectdrawmode))

**Returns**

- `integer`
