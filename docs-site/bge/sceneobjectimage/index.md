---
title: SceneObjectImage
kind: class
longname: BGE.SceneObjectImage
---

# SceneObjectImage

**Extends:&#x20;**[`SceneObjectBillboard`](/bge#sceneobjectbillboard)

**Properties**

- `drawable` ([Image](/bge#image))
- `frameNumber` (integer)

---

## Constructor

<Signature
  code="new SceneObjectImage(
	name: string,
	drawableObj: Image,
): SceneObjectImage"
/>

**Parameters**

- `name` (string)
- `drawableObj` ([Image](/bge#image))

---

## Instance Methods

<MemberHeading id="getuniqueregionname" depth="3" name="getUniqueRegionName" sig="getUniqueRegionName(): string" />

<MemberMeta badges="protected" />

**Returns**

- `string`

<MemberHeading id="getregionwithidtodraw" depth="3" name="getRegionWithIdToDraw" sig="getRegionWithIdToDraw(): BGE.RendererHelpers.RegionWithId" />

<MemberMeta badges="protected" />

**Returns**

- `BGE.RendererHelpers.RegionWithId`

<MemberHeading id="afterdraw" depth="3" name="afterDraw" sig="afterDraw(): void" />

<MemberMeta badges="protected" />

**Returns**

- `void`

<MemberHeading id="didregiontodrawchange" depth="3" name="didRegionToDrawChange" sig="didRegionToDrawChange(): boolean" />

<MemberMeta badges="protected" />

**Returns**

- `boolean`
