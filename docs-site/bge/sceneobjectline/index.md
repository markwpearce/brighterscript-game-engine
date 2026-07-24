---
title: SceneObjectLine
kind: class
longname: BGE.SceneObjectLine
---

# SceneObjectLine

**Extends:&#x20;**[`SceneObject`](/bge#sceneobject)

**Properties**

- `drawable` ([DrawableLine](/bge#drawableline))

---

## Constructor

<Signature
  code="new SceneObjectLine(
	name: string,
	drawableObj: DrawableLine,
): SceneObjectLine"
/>

**Parameters**

- `name` (string)
- `drawableObj` ([DrawableLine](/bge#drawableline))

---

## Instance Methods

<MemberHeading id="updateworldposition" depth="3" name="updateWorldPosition" sig="updateWorldPosition(drawMode: SceneObjectDrawMode): boolean" />

<MemberMeta badges="protected" />

**Parameters**

- `drawMode` ([SceneObjectDrawMode](/bge#sceneobjectdrawmode))

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
