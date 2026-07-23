---
title: Camera3d
kind: class
longname: BGE.Camera3d
---

# Camera3d

**Extends:&#x20;**[`Camera`](/bge#camera)

**Properties**

- `fieldOfViewDegrees` (float)
- `frustumNormals` ([CameraFrustumNormals](/bge#camerafrustumnormals))
- `frustrumConvergence` (BGE.Math.Vector)
- `name` (string)

---

## Constructor

<Signature code="new Camera3d(): Camera3d" />

---

## Instance Methods

<MemberHeading id="settarget" depth="3" name="setTarget" sig="setTarget(targetPos: BGE.Math.Vector): void" />

**Parameters**

- `targetPos` (BGE.Math.Vector)

**Returns**

- `void`

<MemberHeading id="rotate" depth="3" name="rotate" sig="rotate(rotation: BGE.Math.Vector): void" />

**Parameters**

- `rotation` (BGE.Math.Vector)

**Returns**

- `void`

<MemberHeading id="oncameramovement" depth="3" name="onCameraMovement" sig="onCameraMovement(): void" />

**Returns**

- `void`

<MemberHeading id="distancefromcamerafront" depth="3" name="distanceFromCameraFront" sig="distanceFromCameraFront(point: BGE.Math.Vector): float" />

**Parameters**

- `point` (BGE.Math.Vector)

**Returns**

- `float`

<MemberHeading
  id="distancefromfrustumside"
  depth="3"
  name="distanceFromFrustumSide"
  sig="distanceFromFrustumSide(
	frustumSide: string,
	point: BGE.Math.Vector,
): float"
/>

**Parameters**

- `frustumSide` (string)
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

<MemberHeading id="togglewireframe" depth="3" name="toggleWireFrame" sig="toggleWireFrame(): void" />

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

<MemberHeading id="usedefaultcameratarget" depth="3" name="useDefaultCameraTarget" sig="useDefaultCameraTarget(): void" />

**Returns**

- `void`
