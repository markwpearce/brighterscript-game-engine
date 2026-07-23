---
title: AnimatedImage
kind: class
longname: BGE.AnimatedImage
---

# AnimatedImage

**Extends:&#x20;**[`Image`](/bge#image)

**Properties**

- `index` (integer) — The current index of image - this would not normally be changed manually, but if you wanted to stop on a specific image in the spritesheet this could be set.
- `animationDurationMs` (float) — The time in milliseconds for a single cycle through the animation to play.
- `animationTween` (string) — The name of the tween to use for choosing the next image
- `regions` (dynamic) — ------------Never To Be Manually Changed----------------- ' These values should never need to be manually changed.
- `animationTimer` (dynamic)
- `tweensReference` (dynamic)

---

## Constructor

<Signature
  code="new AnimatedImage(
	owner: GameEntity,
	regions: dynamic,
	args?: roAssociativeArray,
): AnimatedImage"
/>

**Parameters**

- `owner` ([GameEntity](/bge#gameentity))
- `regions` (dynamic)
- `args` (roAssociativeArray, optional, default: "{}")

---

## Instance Methods

<MemberHeading id="update" depth="3" name="update" sig="update(): void" />

**Returns**

- `void`

<MemberHeading id="draw" depth="3" name="draw" sig="draw(additionalRotation?: BGE.Math.Vector): dynamic" />

**Parameters**

- `additionalRotation` (BGE.Math.Vector, optional, default: "invalid")

**Returns**

- `dynamic`

<MemberHeading id="getcelldrawindex" depth="3" name="getCellDrawIndex" sig="getCellDrawIndex(): integer" />

<MemberMeta badges="protected" />

**Returns**

- `integer`

<MemberHeading id="onresume" depth="3" name="onResume" sig="onResume(pausedTime: integer): dynamic" />

**Parameters**

- `pausedTime` (integer)

**Returns**

- `dynamic`

<MemberHeading id="addtoscene" depth="3" name="addToScene" sig="addToScene(renderObj: Renderer): void" />

**Parameters**

- `renderObj` ([Renderer](/bge#renderer))

**Returns**

- `void`
