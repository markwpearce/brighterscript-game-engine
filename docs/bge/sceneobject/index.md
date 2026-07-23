---
title: SceneObject
kind: class
longname: BGE.SceneObject
---

# SceneObject

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

---

## Constructor

<Signature
  code="new SceneObject(
	name: string,
	drawableObj: Drawable,
	objType: SceneObjectType,
): SceneObject"
/>

**Parameters**

- `name` (string)
- `drawableObj` ([Drawable](/bge#drawable))
- `objType` ([SceneObjectType](/bge#sceneobjecttype))

---

## Instance Methods

<MemberHeading id="setid" depth="3" name="setId" sig="setId(id: string): void" />

**Parameters**

- `id` (string)

**Returns**

- `void`

<MemberHeading id="update" depth="3" name="update" sig="update(cameraObj: Camera): void" />

**Parameters**

- `cameraObj` ([Camera](/bge#camera))

**Returns**

- `void`

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

<MemberHeading id="isenabled" depth="3" name="isEnabled" sig="isEnabled(): boolean" />

**Returns**

- `boolean`

<MemberHeading id="updateworldposition" depth="3" name="updateWorldPosition" sig="updateWorldPosition(drawMode: SceneObjectDrawMode): boolean" />

<MemberMeta badges="protected" />

**Parameters**

- `drawMode` ([SceneObjectDrawMode](/bge#sceneobjectdrawmode))

**Returns**

- `boolean`

<MemberHeading id="draw" depth="3" name="draw" sig="draw(rendererObj: Renderer): void" />

**Parameters**

- `rendererObj` ([Renderer](/bge#renderer))

**Returns**

- `void`

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
  id="performdraw"
  depth="3"
  name="performDraw"
  sig="performDraw(
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

<MemberHeading id="afterdraw" depth="3" name="afterDraw" sig="afterDraw(): void" />

<MemberMeta badges="protected" />

**Returns**

- `void`

<MemberHeading id="resetframesincedrawn" depth="3" name="resetFrameSinceDrawn" sig="resetFrameSinceDrawn(): void" />

<MemberMeta badges="protected" />

**Returns**

- `void`

<MemberHeading id="objmovedinrelationtocamera" depth="3" name="objMovedInRelationToCamera" sig="objMovedInRelationToCamera(cameraObj: Camera): boolean" />

<MemberMeta badges="protected" />

**Parameters**

- `cameraObj` ([Camera](/bge#camera))

**Returns**

- `boolean`

<MemberHeading id="ispotentiallyonscreen" depth="3" name="isPotentiallyOnScreen" sig="isPotentiallyOnScreen(cameraObj: Camera): boolean" />

<MemberMeta badges="protected" />

**Parameters**

- `cameraObj` ([Camera](/bge#camera))

**Returns**

- `boolean`

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
