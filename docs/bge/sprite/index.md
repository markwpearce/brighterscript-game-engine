---
title: Sprite
kind: class
longname: BGE.Sprite
---

# Sprite

**Extends:&#x20;**[`AnimatedImage`](/bge#animatedimage)

**Properties**

- `spriteSheet` (ifDraw2d) — roBitmap to pick cells from
- `cellWidth` (integer) — Width of each animation cell in the sprite image in pixels
- `cellHeight` (integer) — Height of each animation cell in the sprite image in pixels
- `animations` (roAssociativeArray) — Lookup map of animation name -> SpriteAnimation object
- `activeAnimation` ([SpriteAnimation](/bge#spriteanimation)) — The current animation being played

---

## Constructor

<Signature
  code="new Sprite(
	owner: GameEntity,
	spriteSheet: ifDraw2d,
	cellWidth: integer,
	cellHeight: integer,
	args?: roAssociativeArray,
): Sprite"
/>

**Parameters**

- `owner` ([GameEntity](/bge#gameentity))
- `spriteSheet` (ifDraw2d)
- `cellWidth` (integer)
- `cellHeight` (integer)
- `args` (roAssociativeArray, optional, default: "{}")

---

## Instance Methods

<MemberHeading id="applypretranslation" depth="3" name="applyPreTranslation" sig="applyPreTranslation(x: float, y: float): void" />

Apply a pre-translation to set the pivot point for the sprite cell

**Parameters**

- `x` (float)
- `y` (float)

**Returns**

- `void`

<MemberHeading
  id="addanimation"
  depth="3"
  name="addAnimation"
  sig="addAnimation(
	name: string,
	frameList: dynamic,
	frameRate: integer,
	playMode?: SpritePlayMode,
): BGE.SpriteAnimation"
/>

**Parameters**

- `name` (string)
- `frameList` (dynamic)
- `frameRate` (integer)
- `playMode` ([SpritePlayMode](/bge#spriteplaymode), optional, default: "SpritePlayMode.Loop")

**Returns**

- [`BGE.SpriteAnimation`](/bge#spriteanimation)

<MemberHeading id="playanimation" depth="3" name="playAnimation" sig="playAnimation(animationName: string): void" />

Play an animation from the set of animations in this SpriteSheet

**Parameters**

- `animationName` (string)

**Returns**

- `void`

<MemberHeading id="getcelldrawindex" depth="3" name="getCellDrawIndex" sig="getCellDrawIndex(): integer" />

<MemberMeta badges="protected" />

**Returns**

- `integer`
