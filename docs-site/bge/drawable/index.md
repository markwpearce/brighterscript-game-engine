---
title: Drawable
kind: class
longname: BGE.Drawable
description: Abstract drawable class - all drawables extend from this
---

# Drawable

Abstract drawable class - all drawables extend from this

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

---

## Constructor

<Signature
  code="new Drawable(
	owner: GameEntity,
	args?: roAssociativeArray,
): Drawable"
/>

**Parameters**

- `owner` ([GameEntity](/bge#gameentity))
- `args` (roAssociativeArray, optional, default: "{}")

---

## Instance Methods

<MemberHeading id="addtoscene" depth="3" name="addToScene" sig="addToScene(rendererScene: Renderer): BGE.SceneObject" />

Adds the Drawable object to the given render scene.

**Parameters**

- `rendererScene` ([Renderer](/bge#renderer))

**Returns**

- [`BGE.SceneObject`](/bge#sceneobject) — The SceneObject that represents this Drawable in the scene, if applicable

<MemberHeading id="removefromscene" depth="3" name="removeFromScene" sig="removeFromScene(rendererScene: Renderer): void" />

**Parameters**

- `rendererScene` ([Renderer](/bge#renderer))

**Returns**

- `void`

<MemberHeading id="computetransformationmatrix" depth="3" name="computeTransformationMatrix" sig="computeTransformationMatrix(): void" />

**Returns**

- `void`

<MemberHeading id="movedlastframe" depth="3" name="movedLastFrame" sig="movedLastFrame(includeOwner?: boolean): boolean" />

**Parameters**

- `includeOwner` (boolean, optional, default: false)

**Returns**

- `boolean`

<MemberHeading id="update" depth="3" name="update" sig="update(): void" />

**Returns**

- `void`

<MemberHeading id="onresume" depth="3" name="onResume" sig="onResume(pausedTimeMs: integer): void" />

**Parameters**

- `pausedTimeMs` (integer)

**Returns**

- `void`

<MemberHeading id="isenabled" depth="3" name="isEnabled" sig="isEnabled(): boolean" />

**Returns**

- `boolean`

<MemberHeading id="getsize" depth="3" name="getSize" sig="getSize(): SizeWH" />

**Returns**

- [`SizeWH`](/bge#sizewh)

<MemberHeading id="getdrawnsize" depth="3" name="getDrawnSize" sig="getDrawnSize(): SizeWH" />

**Returns**

- [`SizeWH`](/bge#sizewh)

<MemberHeading id="getworldposition" depth="3" name="getWorldPosition" sig="getWorldPosition(): BGE.Math.Vector" />

**Returns**

- `BGE.Math.Vector`

<MemberHeading id="getpretranslation" depth="3" name="getPretranslation" sig="getPretranslation(): BGE.Math.Vector" />

**Returns**

- `BGE.Math.Vector`

<MemberHeading id="getfillcolorrgba" depth="3" name="getFillColorRGBA" sig="getFillColorRGBA(ignoreColor?: boolean): integer" />

**Parameters**

- `ignoreColor` (boolean, optional, default: false)

**Returns**

- `integer`

<MemberHeading id="getoutlinecolorrgba" depth="3" name="getOutlineColorRGBA" sig="getOutlineColorRGBA(ignoreColor?: boolean): integer" />

**Parameters**

- `ignoreColor` (boolean, optional, default: false)

**Returns**

- `integer`

<MemberHeading id="getsceneobjectname" depth="3" name="getSceneObjectName" sig="getSceneObjectName(extraBit?: string): string" />

<MemberMeta badges="protected" />

**Parameters**

- `extraBit` (string, optional, default: "\\"\\"")

**Returns**

- `string`

<MemberHeading
  id="addsceneobjecttorenderer"
  depth="3"
  name="addSceneObjectToRenderer"
  sig="addSceneObjectToRenderer(
	sceneObj: SceneObject,
	renderScene: Renderer,
): SceneObject"
/>

<MemberMeta badges="protected" />

**Parameters**

- `sceneObj` ([SceneObject](/bge#sceneobject))
- `renderScene` ([Renderer](/bge#renderer))

**Returns**

- [`SceneObject`](/bge#sceneobject)

<MemberHeading
  id="drawregiontocanvas"
  depth="3"
  name="drawRegionToCanvas"
  sig="drawRegionToCanvas(
	region: ifDraw2d,
	additionalRotation?: BGE.Math.Vector,
	ignoreColor?: boolean,
	drawTo?: ifDraw2D,
): void"
/>

<MemberMeta badges="protected" />

**Parameters**

- `region` (ifDraw2d)
- `additionalRotation` (BGE.Math.Vector, optional, default: "invalid")
- `ignoreColor` (boolean, optional, default: false)
- `drawTo` (ifDraw2D, optional, default: "invalid")

**Returns**

- `void`

<MemberHeading
  id="foreachsceneobject"
  depth="3"
  name="forEachSceneObject"
  sig="forEachSceneObject(
	operation: function,
	context: roAssociativeArray,
): void"
/>

**Parameters**

- `operation` (function)
- `context` (roAssociativeArray)

**Returns**

- `void`
