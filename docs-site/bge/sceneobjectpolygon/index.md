---
title: SceneObjectPolygon
kind: class
longname: BGE.SceneObjectPolygon
---

# SceneObjectPolygon

**Extends:&#x20;**[`SceneObjectBillboard`](/bge#sceneobjectbillboard)

**Properties**

- `drawable` ([DrawablePolygon](/bge#drawablepolygon))

---

## Constructor

<Signature
  code="new SceneObjectPolygon(
	name: string,
	drawableObj: DrawablePolygon,
): SceneObjectPolygon"
/>

**Parameters**

- `name` (string)
- `drawableObj` ([DrawablePolygon](/bge#drawablepolygon))

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

<MemberHeading id="getallcanvaspoints" depth="3" name="getAllCanvasPoints" sig="getAllCanvasPoints(): dynamic" />

<MemberMeta badges="protected" />

**Returns**

- `dynamic`

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

<MemberHeading id="afterdraw" depth="3" name="afterDraw" sig="afterDraw(): void" />

<MemberMeta badges="protected" />

**Returns**

- `void`

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
