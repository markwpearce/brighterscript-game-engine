---
title: Image
kind: class
longname: BGE.Image
description: Used to draw a bitmap image to the screen
---

# Image

**Extends:&#x20;**[`BGE.Drawable`](/bge#drawable)

Used to draw a bitmap image to the screen

**Properties**

- `regionId` (string) — An optional unique name for the region, used for caching image data. If not provided, the name of the drawable will be used as the region name.
- `region` (roRegion) — ------------Never To Be Manually Changed----------------- ' These values should never need to be manually changed.

---

## Constructor

<Signature
  code="new Image(
	owner: BGE.GameEntity,
	region: roRegion,
	args?: roAssociativeArray,
): Image"
/>

**Parameters**

- `owner` ([BGE.GameEntity](/bge#gameentity))
- `region` (roRegion)
- `args` (roAssociativeArray, optional, default: "{}")

---

## Instance Methods

<MemberHeading id="getpretranslation" depth="3" name="getPretranslation" sig="getPretranslation(): BGE.Math.Vector" />

**Returns**

- `BGE.Math.Vector`

<MemberHeading id="addtoscene" depth="3" name="addToScene" sig="addToScene(rendererObj: Renderer): BGE.SceneObject" />

**Parameters**

- `rendererObj` ([Renderer](/bge#renderer))

**Returns**

- [`BGE.SceneObject`](/bge#sceneobject)

<MemberHeading id="addtoscene" depth="3" name="addToScene" sig="addToScene(rendererObj: Renderer): BGE.SceneObject" />

_Inherited from `BGE.Image#addToScene`_

**Overrides:&#x20;**`BGE.Drawable#addToScene`

Adds the Drawable object to the given render scene.

**Parameters**

- `rendererObj` ([Renderer](/bge#renderer))

**Returns**

- [`BGE.SceneObject`](/bge#sceneobject)

<MemberHeading id="removefromscene" depth="3" name="removeFromScene" sig="removeFromScene(rendererScene: Renderer): void" />

_Inherited from `BGE.Drawable#removeFromScene`_

**Overrides:&#x20;**`BGE.Drawable#removeFromScene`

**Parameters**

- `rendererScene` ([Renderer](/bge#renderer))

**Returns**

- `void`

<MemberHeading id="computetransformationmatrix" depth="3" name="computeTransformationMatrix" sig="computeTransformationMatrix(): void" />

_Inherited from `BGE.Drawable#computeTransformationMatrix`_

**Overrides:&#x20;**`BGE.Drawable#computeTransformationMatrix`

**Returns**

- `void`

<MemberHeading id="movedlastframe" depth="3" name="movedLastFrame" sig="movedLastFrame(includeOwner?: boolean): boolean" />

_Inherited from `BGE.Drawable#movedLastFrame`_

**Overrides:&#x20;**`BGE.Drawable#movedLastFrame`

**Parameters**

- `includeOwner` (boolean, optional, default: false)

**Returns**

- `boolean`

<MemberHeading id="update" depth="3" name="update" sig="update(): void" />

_Inherited from `BGE.Drawable#update`_

**Overrides:&#x20;**`BGE.Drawable#update`

**Returns**

- `void`

<MemberHeading id="onresume" depth="3" name="onResume" sig="onResume(pausedTimeMs: integer): void" />

_Inherited from `BGE.Drawable#onResume`_

**Overrides:&#x20;**`BGE.Drawable#onResume`

**Parameters**

- `pausedTimeMs` (integer)

**Returns**

- `void`

<MemberHeading id="isenabled" depth="3" name="isEnabled" sig="isEnabled(): boolean" />

_Inherited from `BGE.Drawable#isEnabled`_

**Overrides:&#x20;**`BGE.Drawable#isEnabled`

**Returns**

- `boolean`

<MemberHeading id="getsize" depth="3" name="getSize" sig="getSize(): SizeWH" />

_Inherited from `BGE.Drawable#getSize`_

**Overrides:&#x20;**`BGE.Drawable#getSize`

**Returns**

- [`SizeWH`](/bge#sizewh)

<MemberHeading id="getdrawnsize" depth="3" name="getDrawnSize" sig="getDrawnSize(): SizeWH" />

_Inherited from `BGE.Drawable#getDrawnSize`_

**Overrides:&#x20;**`BGE.Drawable#getDrawnSize`

**Returns**

- [`SizeWH`](/bge#sizewh)

<MemberHeading id="getworldposition" depth="3" name="getWorldPosition" sig="getWorldPosition(): BGE.Math.Vector" />

_Inherited from `BGE.Drawable#getWorldPosition`_

**Overrides:&#x20;**`BGE.Drawable#getWorldPosition`

**Returns**

- `BGE.Math.Vector`

<MemberHeading id="getpretranslation" depth="3" name="getPretranslation" sig="getPretranslation(): BGE.Math.Vector" />

_Inherited from `BGE.Image#getPretranslation`_

**Overrides:&#x20;**`BGE.Drawable#getPretranslation`

**Returns**

- `BGE.Math.Vector`

<MemberHeading id="getfillcolorrgba" depth="3" name="getFillColorRGBA" sig="getFillColorRGBA(ignoreColor?: boolean): integer" />

_Inherited from `BGE.Drawable#getFillColorRGBA`_

**Overrides:&#x20;**`BGE.Drawable#getFillColorRGBA`

**Parameters**

- `ignoreColor` (boolean, optional, default: false)

**Returns**

- `integer`

<MemberHeading id="getoutlinecolorrgba" depth="3" name="getOutlineColorRGBA" sig="getOutlineColorRGBA(ignoreColor?: boolean): integer" />

_Inherited from `BGE.Drawable#getOutlineColorRGBA`_

**Overrides:&#x20;**`BGE.Drawable#getOutlineColorRGBA`

**Parameters**

- `ignoreColor` (boolean, optional, default: false)

**Returns**

- `integer`

<MemberHeading id="getsceneobjectname" depth="3" name="getSceneObjectName" sig="getSceneObjectName(extraBit?: string): string" />

<MemberMeta badges="protected" />

_Inherited from `BGE.Drawable#getSceneObjectName`_

**Overrides:&#x20;**`BGE.Drawable#getSceneObjectName`

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

_Inherited from `BGE.Drawable#addSceneObjectToRenderer`_

**Overrides:&#x20;**`BGE.Drawable#addSceneObjectToRenderer`

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

_Inherited from `BGE.Drawable#drawRegionToCanvas`_

**Overrides:&#x20;**`BGE.Drawable#drawRegionToCanvas`

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

_Inherited from `BGE.Drawable#forEachSceneObject`_

**Overrides:&#x20;**`BGE.Drawable#forEachSceneObject`

**Parameters**

- `operation` (function)
- `context` (roAssociativeArray)

**Returns**

- `void`

<MemberHeading id="addtoscene" depth="3" name="addToScene" sig="addToScene(rendererObj: Renderer): BGE.SceneObject" />

_Inherited from `BGE.Image#addToScene`_

**Overrides:&#x20;**`BGE.Drawable#addToScene`

Adds the Drawable object to the given render scene.

**Parameters**

- `rendererObj` ([Renderer](/bge#renderer))

**Returns**

- [`BGE.SceneObject`](/bge#sceneobject)

<MemberHeading id="getpretranslation" depth="3" name="getPretranslation" sig="getPretranslation(): BGE.Math.Vector" />

_Inherited from `BGE.Image#getPretranslation`_

**Overrides:&#x20;**`BGE.Drawable#getPretranslation`

**Returns**

- `BGE.Math.Vector`
