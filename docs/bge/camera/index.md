---
title: Camera
kind: class
longname: BGE.Camera
---

# Camera

**Properties**

- `orientation` (dynamic)
- `position` (BGE.Math.Vector)
- `motionChecker` ([MotionChecker](/bge#motionchecker))
- `frameSize` (BGE.Math.Vector)
- `zoom` (float) — TODO: do something with zoom!
- `worldToCamera` (dynamic)
- `name` (string)

---

## Constructor

<Signature code="new Camera(): Camera" />

---

## Instance Methods

<MemberHeading id="setframesize" depth="3" name="setFrameSize" sig="setFrameSize(width: integer, height: integer): void" />

**Parameters**

- `width` (integer)
- `height` (integer)

**Returns**

- `void`

<MemberHeading id="settarget" depth="3" name="setTarget" sig="setTarget(targetPos: BGE.Math.Vector): void" />

**Parameters**

- `targetPos` (BGE.Math.Vector)

**Returns**

- `void`

<MemberHeading id="usedefaultcameratarget" depth="3" name="useDefaultCameraTarget" sig="useDefaultCameraTarget(): void" />

**Returns**

- `void`

<MemberHeading id="rotate" depth="3" name="rotate" sig="rotate(rotation: BGE.Math.Vector): void" />

**Parameters**

- `rotation` (BGE.Math.Vector)

**Returns**

- `void`

<MemberHeading id="checkmovement" depth="3" name="checkMovement" sig="checkMovement(): void" />

**Returns**

- `void`

<MemberHeading id="oncameramovement" depth="3" name="onCameraMovement" sig="onCameraMovement(): void" />

**Returns**

- `void`

<MemberHeading id="movedlastframe" depth="3" name="movedLastFrame" sig="movedLastFrame(): boolean" />

**Returns**

- `boolean`

<MemberHeading id="distancefromcamerafront" depth="3" name="distanceFromCameraFront" sig="distanceFromCameraFront(point: BGE.Math.Vector): float" />

**Parameters**

- `point` (BGE.Math.Vector)

**Returns**

- `float`

<MemberHeading id="isinview" depth="3" name="isInView" sig="isInView(point: BGE.Math.Vector): boolean" />

**Parameters**

- `point` (BGE.Math.Vector)

**Returns**

- `boolean`

<MemberHeading id="computeworldtocameramatrix" depth="3" name="computeWorldToCameraMatrix" sig="computeWorldToCameraMatrix(): void" />

**Returns**

- `void`

<MemberHeading id="getdrawmode" depth="3" name="getDrawMode" sig="getDrawMode(): BGE.SceneObjectDrawMode" />

**Returns**

- [`BGE.SceneObjectDrawMode`](/bge#sceneobjectdrawmode)

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
