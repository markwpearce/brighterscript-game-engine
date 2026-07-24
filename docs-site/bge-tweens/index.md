---
title: BGE/Tweens
kind: namespace
longname: BGE/Tweens
---

# BGE/Tweens

**Alias:** `BGE.Tweens`

---

## Static Methods

<MemberHeading
  id="createtweenobject"
  depth="3"
  name="CreateTweenObject"
  sig="CreateTweenObject(
	start_data: object,
	dest_data: object,
	duration: integer,
	tween: string,
): object"
/>

<MemberMeta badges="static" />

Copyright Steven Kean 2010-2015 All Rights Reserved.

**Parameters**

- `start_data` (object)
- `dest_data` (object)
- `duration` (integer)
- `tween` (string)

**Returns**

- `object`

<MemberHeading id="gettweenobjectpercentstate" depth="3" name="GetTweenObjectPercentState" sig="GetTweenObjectPercentState(tween_object: object): float" />

<MemberMeta badges="static" />

**Parameters**

- `tween_object` (object)

**Returns**

- `float`

<MemberHeading id="handletween" depth="3" name="HandleTween" sig="HandleTween(tween_data: object): boolean" />

<MemberMeta badges="static" />

**Parameters**

- `tween_data` (object)

**Returns**

- `boolean`

<MemberHeading id="changetweendest" depth="3" name="ChangeTweenDest" sig="ChangeTweenDest(tween_data: object, dest_data: object): dynamic" />

<MemberMeta badges="static" />

**Parameters**

- `tween_data` (object)
- `dest_data` (object)

**Returns**

- `dynamic`

<MemberHeading id="gettweens" depth="3" name="GetTweens" sig="GetTweens(): object" />

<MemberMeta badges="static" />

**Returns**

- `object`

<MemberHeading
  id="lineartween"
  depth="3"
  name="LinearTween"
  sig="LinearTween(
	start: float,
	finish: float,
	currentTime: float,
	duration: float,
): float"
/>

<MemberMeta badges="static" />

**Parameters**

- `start` (float)
- `finish` (float)
- `currentTime` (float)
- `duration` (float)

**Returns**

- `float`

<MemberHeading
  id="quadratictween"
  depth="3"
  name="QuadraticTween"
  sig="QuadraticTween(
	start: float,
	finish: float,
	currentTime: float,
	duration: float,
): float"
/>

<MemberMeta badges="static" />

Quadratic

**Parameters**

- `start` (float)
- `finish` (float)
- `currentTime` (float)
- `duration` (float)

**Returns**

- `float`

<MemberHeading
  id="quadraticeasein"
  depth="3"
  name="QuadraticEaseIn"
  sig="QuadraticEaseIn(
	start: float,
	finish: float,
	currentTime: float,
	duration: float,
): float"
/>

<MemberMeta badges="static" />

**Parameters**

- `start` (float)
- `finish` (float)
- `currentTime` (float)
- `duration` (float)

**Returns**

- `float`

<MemberHeading
  id="quadraticeaseout"
  depth="3"
  name="QuadraticEaseOut"
  sig="QuadraticEaseOut(
	start: float,
	finish: float,
	currentTime: float,
	duration: float,
): float"
/>

<MemberMeta badges="static" />

**Parameters**

- `start` (float)
- `finish` (float)
- `currentTime` (float)
- `duration` (float)

**Returns**

- `float`

<MemberHeading
  id="quadraticeaseinout"
  depth="3"
  name="QuadraticEaseInOut"
  sig="QuadraticEaseInOut(
	start: float,
	finish: float,
	currentTime: float,
	duration: float,
): float"
/>

<MemberMeta badges="static" />

**Parameters**

- `start` (float)
- `finish` (float)
- `currentTime` (float)
- `duration` (float)

**Returns**

- `float`

<MemberHeading
  id="quadraticeaseoutin"
  depth="3"
  name="QuadraticEaseOutIn"
  sig="QuadraticEaseOutIn(
	start: float,
	finish: float,
	currentTime: float,
	duration: float,
): float"
/>

<MemberMeta badges="static" />

**Parameters**

- `start` (float)
- `finish` (float)
- `currentTime` (float)
- `duration` (float)

**Returns**

- `float`

<MemberHeading
  id="squaretween"
  depth="3"
  name="SquareTween"
  sig="SquareTween(
	start: float,
	finish: float,
	currentTime: float,
	duration: float,
): float"
/>

<MemberMeta badges="static" />

Square

**Parameters**

- `start` (float)
- `finish` (float)
- `currentTime` (float)
- `duration` (float)

**Returns**

- `float`

<MemberHeading
  id="squareeasein"
  depth="3"
  name="SquareEaseIn"
  sig="SquareEaseIn(
	start: float,
	finish: float,
	currentTime: float,
	duration: float,
): float"
/>

<MemberMeta badges="static" />

**Parameters**

- `start` (float)
- `finish` (float)
- `currentTime` (float)
- `duration` (float)

**Returns**

- `float`

<MemberHeading
  id="squareeaseout"
  depth="3"
  name="SquareEaseOut"
  sig="SquareEaseOut(
	start: float,
	finish: float,
	currentTime: float,
	duration: float,
): float"
/>

<MemberMeta badges="static" />

**Parameters**

- `start` (float)
- `finish` (float)
- `currentTime` (float)
- `duration` (float)

**Returns**

- `float`

<MemberHeading
  id="squareeaseinout"
  depth="3"
  name="SquareEaseInOut"
  sig="SquareEaseInOut(
	start: float,
	finish: float,
	currentTime: float,
	duration: float,
): float"
/>

<MemberMeta badges="static" />

**Parameters**

- `start` (float)
- `finish` (float)
- `currentTime` (float)
- `duration` (float)

**Returns**

- `float`

<MemberHeading
  id="squareeaseoutin"
  depth="3"
  name="SquareEaseOutIn"
  sig="SquareEaseOutIn(
	start: float,
	finish: float,
	currentTime: float,
	duration: float,
): float"
/>

<MemberMeta badges="static" />

**Parameters**

- `start` (float)
- `finish` (float)
- `currentTime` (float)
- `duration` (float)

**Returns**

- `float`

<MemberHeading
  id="cubictween"
  depth="3"
  name="CubicTween"
  sig="CubicTween(
	start: float,
	finish: float,
	currentTime: float,
	duration: float,
): float"
/>

<MemberMeta badges="static" />

Cubic

**Parameters**

- `start` (float)
- `finish` (float)
- `currentTime` (float)
- `duration` (float)

**Returns**

- `float`

<MemberHeading
  id="cubiceasein"
  depth="3"
  name="CubicEaseIn"
  sig="CubicEaseIn(
	start: float,
	finish: float,
	currentTime: float,
	duration: float,
): float"
/>

<MemberMeta badges="static" />

**Parameters**

- `start` (float)
- `finish` (float)
- `currentTime` (float)
- `duration` (float)

**Returns**

- `float`

<MemberHeading
  id="cubiceaseout"
  depth="3"
  name="CubicEaseOut"
  sig="CubicEaseOut(
	start: float,
	finish: float,
	currentTime: float,
	duration: float,
): float"
/>

<MemberMeta badges="static" />

**Parameters**

- `start` (float)
- `finish` (float)
- `currentTime` (float)
- `duration` (float)

**Returns**

- `float`

<MemberHeading
  id="cubiceaseinout"
  depth="3"
  name="CubicEaseInOut"
  sig="CubicEaseInOut(
	start: float,
	finish: float,
	currentTime: float,
	duration: float,
): float"
/>

<MemberMeta badges="static" />

**Parameters**

- `start` (float)
- `finish` (float)
- `currentTime` (float)
- `duration` (float)

**Returns**

- `float`

<MemberHeading
  id="cubiceaseoutin"
  depth="3"
  name="CubicEaseOutIn"
  sig="CubicEaseOutIn(
	start: float,
	finish: float,
	currentTime: float,
	duration: float,
): float"
/>

<MemberMeta badges="static" />

**Parameters**

- `start` (float)
- `finish` (float)
- `currentTime` (float)
- `duration` (float)

**Returns**

- `float`

<MemberHeading
  id="quartictween"
  depth="3"
  name="QuarticTween"
  sig="QuarticTween(
	start: float,
	finish: float,
	currentTime: float,
	duration: float,
): float"
/>

<MemberMeta badges="static" />

Quartic

**Parameters**

- `start` (float)
- `finish` (float)
- `currentTime` (float)
- `duration` (float)

**Returns**

- `float`

<MemberHeading
  id="quarticeasein"
  depth="3"
  name="QuarticEaseIn"
  sig="QuarticEaseIn(
	start: float,
	finish: float,
	currentTime: float,
	duration: float,
): float"
/>

<MemberMeta badges="static" />

**Parameters**

- `start` (float)
- `finish` (float)
- `currentTime` (float)
- `duration` (float)

**Returns**

- `float`

<MemberHeading
  id="quarticeaseout"
  depth="3"
  name="QuarticEaseOut"
  sig="QuarticEaseOut(
	start: float,
	finish: float,
	currentTime: float,
	duration: float,
): float"
/>

<MemberMeta badges="static" />

**Parameters**

- `start` (float)
- `finish` (float)
- `currentTime` (float)
- `duration` (float)

**Returns**

- `float`

<MemberHeading
  id="quarticeaseinout"
  depth="3"
  name="QuarticEaseInOut"
  sig="QuarticEaseInOut(
	start: float,
	finish: float,
	currentTime: float,
	duration: float,
): float"
/>

<MemberMeta badges="static" />

**Parameters**

- `start` (float)
- `finish` (float)
- `currentTime` (float)
- `duration` (float)

**Returns**

- `float`

<MemberHeading
  id="quarticeaseoutin"
  depth="3"
  name="QuarticEaseOutIn"
  sig="QuarticEaseOutIn(
	start: float,
	finish: float,
	currentTime: float,
	duration: float,
): float"
/>

<MemberMeta badges="static" />

**Parameters**

- `start` (float)
- `finish` (float)
- `currentTime` (float)
- `duration` (float)

**Returns**

- `float`

<MemberHeading
  id="quintictween"
  depth="3"
  name="QuinticTween"
  sig="QuinticTween(
	start: float,
	finish: float,
	currentTime: float,
	duration: float,
): float"
/>

<MemberMeta badges="static" />

Quintic

**Parameters**

- `start` (float)
- `finish` (float)
- `currentTime` (float)
- `duration` (float)

**Returns**

- `float`

<MemberHeading
  id="quinticeasein"
  depth="3"
  name="QuinticEaseIn"
  sig="QuinticEaseIn(
	start: float,
	finish: float,
	currentTime: float,
	duration: float,
): float"
/>

<MemberMeta badges="static" />

**Parameters**

- `start` (float)
- `finish` (float)
- `currentTime` (float)
- `duration` (float)

**Returns**

- `float`

<MemberHeading
  id="quinticeaseout"
  depth="3"
  name="QuinticEaseOut"
  sig="QuinticEaseOut(
	start: float,
	finish: float,
	currentTime: float,
	duration: float,
): float"
/>

<MemberMeta badges="static" />

**Parameters**

- `start` (float)
- `finish` (float)
- `currentTime` (float)
- `duration` (float)

**Returns**

- `float`

<MemberHeading
  id="quinticeaseinout"
  depth="3"
  name="QuinticEaseInOut"
  sig="QuinticEaseInOut(
	start: float,
	finish: float,
	currentTime: float,
	duration: float,
): float"
/>

<MemberMeta badges="static" />

**Parameters**

- `start` (float)
- `finish` (float)
- `currentTime` (float)
- `duration` (float)

**Returns**

- `float`

<MemberHeading
  id="quinticeaseoutin"
  depth="3"
  name="QuinticEaseOutIn"
  sig="QuinticEaseOutIn(
	start: float,
	finish: float,
	currentTime: float,
	duration: float,
): float"
/>

<MemberMeta badges="static" />

**Parameters**

- `start` (float)
- `finish` (float)
- `currentTime` (float)
- `duration` (float)

**Returns**

- `float`

<MemberHeading
  id="sinusoidaltween"
  depth="3"
  name="SinusoidalTween"
  sig="SinusoidalTween(
	start: float,
	finish: float,
	currentTime: float,
	duration: float,
): float"
/>

<MemberMeta badges="static" />

Sinusoidal

**Parameters**

- `start` (float)
- `finish` (float)
- `currentTime` (float)
- `duration` (float)

**Returns**

- `float`

<MemberHeading
  id="sinusoidaleasein"
  depth="3"
  name="SinusoidalEaseIn"
  sig="SinusoidalEaseIn(
	start: float,
	finish: float,
	currentTime: float,
	duration: float,
): float"
/>

<MemberMeta badges="static" />

**Parameters**

- `start` (float)
- `finish` (float)
- `currentTime` (float)
- `duration` (float)

**Returns**

- `float`

<MemberHeading
  id="sinusoidaleaseout"
  depth="3"
  name="SinusoidalEaseOut"
  sig="SinusoidalEaseOut(
	start: float,
	finish: float,
	currentTime: float,
	duration: float,
): float"
/>

<MemberMeta badges="static" />

**Parameters**

- `start` (float)
- `finish` (float)
- `currentTime` (float)
- `duration` (float)

**Returns**

- `float`

<MemberHeading
  id="sinusoidaleaseinout"
  depth="3"
  name="SinusoidalEaseInOut"
  sig="SinusoidalEaseInOut(
	start: float,
	finish: float,
	currentTime: float,
	duration: float,
): float"
/>

<MemberMeta badges="static" />

**Parameters**

- `start` (float)
- `finish` (float)
- `currentTime` (float)
- `duration` (float)

**Returns**

- `float`

<MemberHeading
  id="sinusoidaleaseoutin"
  depth="3"
  name="SinusoidalEaseOutIn"
  sig="SinusoidalEaseOutIn(
	start: float,
	finish: float,
	currentTime: float,
	duration: float,
): float"
/>

<MemberMeta badges="static" />

**Parameters**

- `start` (float)
- `finish` (float)
- `currentTime` (float)
- `duration` (float)

**Returns**

- `float`

<MemberHeading
  id="exponentialtween"
  depth="3"
  name="ExponentialTween"
  sig="ExponentialTween(
	start: float,
	finish: float,
	currentTime: float,
	duration: float,
): float"
/>

<MemberMeta badges="static" />

Exponential

**Parameters**

- `start` (float)
- `finish` (float)
- `currentTime` (float)
- `duration` (float)

**Returns**

- `float`

<MemberHeading
  id="exponentialeasein"
  depth="3"
  name="ExponentialEaseIn"
  sig="ExponentialEaseIn(
	start: float,
	finish: float,
	currentTime: float,
	duration: float,
): float"
/>

<MemberMeta badges="static" />

**Parameters**

- `start` (float)
- `finish` (float)
- `currentTime` (float)
- `duration` (float)

**Returns**

- `float`

<MemberHeading
  id="exponentialeaseout"
  depth="3"
  name="ExponentialEaseOut"
  sig="ExponentialEaseOut(
	start: float,
	finish: float,
	currentTime: float,
	duration: float,
): float"
/>

<MemberMeta badges="static" />

**Parameters**

- `start` (float)
- `finish` (float)
- `currentTime` (float)
- `duration` (float)

**Returns**

- `float`

<MemberHeading
  id="exponentialeaseinout"
  depth="3"
  name="ExponentialEaseInOut"
  sig="ExponentialEaseInOut(
	start: float,
	finish: float,
	currentTime: float,
	duration: float,
): float"
/>

<MemberMeta badges="static" />

**Parameters**

- `start` (float)
- `finish` (float)
- `currentTime` (float)
- `duration` (float)

**Returns**

- `float`

<MemberHeading
  id="exponentialeaseoutin"
  depth="3"
  name="ExponentialEaseOutIn"
  sig="ExponentialEaseOutIn(
	start: float,
	finish: float,
	currentTime: float,
	duration: float,
): float"
/>

<MemberMeta badges="static" />

**Parameters**

- `start` (float)
- `finish` (float)
- `currentTime` (float)
- `duration` (float)

**Returns**

- `float`

<MemberHeading
  id="circulartween"
  depth="3"
  name="CircularTween"
  sig="CircularTween(
	start: float,
	finish: float,
	currentTime: float,
	duration: float,
): float"
/>

<MemberMeta badges="static" />

Circular

**Parameters**

- `start` (float)
- `finish` (float)
- `currentTime` (float)
- `duration` (float)

**Returns**

- `float`

<MemberHeading
  id="circulareasein"
  depth="3"
  name="CircularEaseIn"
  sig="CircularEaseIn(
	start: float,
	finish: float,
	currentTime: float,
	duration: float,
): float"
/>

<MemberMeta badges="static" />

**Parameters**

- `start` (float)
- `finish` (float)
- `currentTime` (float)
- `duration` (float)

**Returns**

- `float`

<MemberHeading
  id="circulareaseout"
  depth="3"
  name="CircularEaseOut"
  sig="CircularEaseOut(
	start: float,
	finish: float,
	currentTime: float,
	duration: float,
): float"
/>

<MemberMeta badges="static" />

**Parameters**

- `start` (float)
- `finish` (float)
- `currentTime` (float)
- `duration` (float)

**Returns**

- `float`

<MemberHeading
  id="circulareaseinout"
  depth="3"
  name="CircularEaseInOut"
  sig="CircularEaseInOut(
	start: float,
	finish: float,
	currentTime: float,
	duration: float,
): float"
/>

<MemberMeta badges="static" />

**Parameters**

- `start` (float)
- `finish` (float)
- `currentTime` (float)
- `duration` (float)

**Returns**

- `float`

<MemberHeading
  id="circulareaseoutin"
  depth="3"
  name="CircularEaseOutIn"
  sig="CircularEaseOutIn(
	start: float,
	finish: float,
	currentTime: float,
	duration: float,
): float"
/>

<MemberMeta badges="static" />

**Parameters**

- `start` (float)
- `finish` (float)
- `currentTime` (float)
- `duration` (float)

**Returns**

- `float`

<MemberHeading
  id="elastictween"
  depth="3"
  name="ElasticTween"
  sig="ElasticTween(
	start: float,
	finish: float,
	currentTime: float,
	duration: float,
): float"
/>

<MemberMeta badges="static" />

Elastic

**Parameters**

- `start` (float)
- `finish` (float)
- `currentTime` (float)
- `duration` (float)

**Returns**

- `float`

<MemberHeading
  id="elasticeasein"
  depth="3"
  name="ElasticEaseIn"
  sig="ElasticEaseIn(
	start: float,
	finish: float,
	currentTime: float,
	duration: float,
	amplitude?: dynamic,
	period?: dynamic,
): float"
/>

<MemberMeta badges="static" />

**Parameters**

- `start` (float)
- `finish` (float)
- `currentTime` (float)
- `duration` (float)
- `amplitude` (dynamic, optional, default: "invalid")
- `period` (dynamic, optional, default: "invalid")

**Returns**

- `float`

<MemberHeading
  id="elasticeaseout"
  depth="3"
  name="ElasticEaseOut"
  sig="ElasticEaseOut(
	start: float,
	finish: float,
	currentTime: float,
	duration: float,
	amplitude?: dynamic,
	period?: dynamic,
): float"
/>

<MemberMeta badges="static" />

**Parameters**

- `start` (float)
- `finish` (float)
- `currentTime` (float)
- `duration` (float)
- `amplitude` (dynamic, optional, default: "invalid")
- `period` (dynamic, optional, default: "invalid")

**Returns**

- `float`

<MemberHeading
  id="elasticeaseinout"
  depth="3"
  name="ElasticEaseInOut"
  sig="ElasticEaseInOut(
	start: float,
	finish: float,
	currentTime: float,
	duration: float,
	amplitude?: dynamic,
	period?: dynamic,
): float"
/>

<MemberMeta badges="static" />

**Parameters**

- `start` (float)
- `finish` (float)
- `currentTime` (float)
- `duration` (float)
- `amplitude` (dynamic, optional, default: "invalid")
- `period` (dynamic, optional, default: "invalid")

**Returns**

- `float`

<MemberHeading
  id="elasticeaseoutin"
  depth="3"
  name="ElasticEaseOutIn"
  sig="ElasticEaseOutIn(
	start: float,
	finish: float,
	currentTime: float,
	duration: float,
	amplitude?: dynamic,
	period?: dynamic,
): float"
/>

<MemberMeta badges="static" />

**Parameters**

- `start` (float)
- `finish` (float)
- `currentTime` (float)
- `duration` (float)
- `amplitude` (dynamic, optional, default: "invalid")
- `period` (dynamic, optional, default: "invalid")

**Returns**

- `float`

<MemberHeading
  id="overshoottween"
  depth="3"
  name="OvershootTween"
  sig="OvershootTween(
	start: float,
	finish: float,
	currentTime: float,
	duration: float,
): float"
/>

<MemberMeta badges="static" />

Overshoot

**Parameters**

- `start` (float)
- `finish` (float)
- `currentTime` (float)
- `duration` (float)

**Returns**

- `float`

<MemberHeading
  id="overshooteasein"
  depth="3"
  name="OvershootEaseIn"
  sig="OvershootEaseIn(
	start: float,
	finish: float,
	currentTime: float,
	duration: float,
	overshoot?: float,
): float"
/>

<MemberMeta badges="static" />

**Parameters**

- `start` (float)
- `finish` (float)
- `currentTime` (float)
- `duration` (float)
- `overshoot` (float, optional, default: 1.70158)

**Returns**

- `float`

<MemberHeading
  id="overshooteaseout"
  depth="3"
  name="OvershootEaseOut"
  sig="OvershootEaseOut(
	start: float,
	finish: float,
	currentTime: float,
	duration: float,
	overshoot?: float,
): float"
/>

<MemberMeta badges="static" />

**Parameters**

- `start` (float)
- `finish` (float)
- `currentTime` (float)
- `duration` (float)
- `overshoot` (float, optional, default: 1.70158)

**Returns**

- `float`

<MemberHeading
  id="overshooteaseinout"
  depth="3"
  name="OvershootEaseInOut"
  sig="OvershootEaseInOut(
	start: float,
	finish: float,
	currentTime: float,
	duration: float,
	overshoot?: float,
): float"
/>

<MemberMeta badges="static" />

**Parameters**

- `start` (float)
- `finish` (float)
- `currentTime` (float)
- `duration` (float)
- `overshoot` (float, optional, default: 1.70158)

**Returns**

- `float`

<MemberHeading
  id="overshooteaseoutin"
  depth="3"
  name="OvershootEaseOutIn"
  sig="OvershootEaseOutIn(
	start: float,
	finish: float,
	currentTime: float,
	duration: float,
	overshoot?: float,
): float"
/>

<MemberMeta badges="static" />

**Parameters**

- `start` (float)
- `finish` (float)
- `currentTime` (float)
- `duration` (float)
- `overshoot` (float, optional, default: 1.70158)

**Returns**

- `float`

<MemberHeading
  id="bouncetween"
  depth="3"
  name="BounceTween"
  sig="BounceTween(
	start: float,
	finish: float,
	currentTime: float,
	duration: float,
): float"
/>

<MemberMeta badges="static" />

Bounce

**Parameters**

- `start` (float)
- `finish` (float)
- `currentTime` (float)
- `duration` (float)

**Returns**

- `float`

<MemberHeading
  id="bounceeasein"
  depth="3"
  name="BounceEaseIn"
  sig="BounceEaseIn(
	start: float,
	finish: float,
	currentTime: float,
	duration: float,
): float"
/>

<MemberMeta badges="static" />

**Parameters**

- `start` (float)
- `finish` (float)
- `currentTime` (float)
- `duration` (float)

**Returns**

- `float`

<MemberHeading
  id="bounceeaseout"
  depth="3"
  name="BounceEaseOut"
  sig="BounceEaseOut(
	start: float,
	finish: float,
	currentTime: float,
	duration: float,
): float"
/>

<MemberMeta badges="static" />

**Parameters**

- `start` (float)
- `finish` (float)
- `currentTime` (float)
- `duration` (float)

**Returns**

- `float`

<MemberHeading
  id="bounceeaseinout"
  depth="3"
  name="BounceEaseInOut"
  sig="BounceEaseInOut(
	start: float,
	finish: float,
	currentTime: float,
	duration: float,
): float"
/>

<MemberMeta badges="static" />

**Parameters**

- `start` (float)
- `finish` (float)
- `currentTime` (float)
- `duration` (float)

**Returns**

- `float`

<MemberHeading
  id="bounceeaseoutin"
  depth="3"
  name="BounceEaseOutIn"
  sig="BounceEaseOutIn(
	start: float,
	finish: float,
	currentTime: float,
	duration: float,
): float"
/>

<MemberMeta badges="static" />

**Parameters**

- `start` (float)
- `finish` (float)
- `currentTime` (float)
- `duration` (float)

**Returns**

- `float`
