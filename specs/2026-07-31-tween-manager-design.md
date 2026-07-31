# TweenManager: game-driven tweens on arbitrary fields

Design doc for issues #60 and #79.

## Problem

`BGE.Tweens` (`src/source/utils/tweens.bs`) is a standalone easing library with no
connection to the game loop. A consumer has to manually tick a tween every frame, copy
`current` back onto the real target fields, and retire it themselves:

```brightscript
' onCreate
m.moveTween = BGE.Tweens.CreateTweenObject({x: 0, y: 0}, {x: 100, y: 50}, 1000, "QuadraticEaseInOut")

' onUpdate - every frame, forever
if m.moveTween <> invalid
  done = BGE.Tweens.HandleTween(m.moveTween)
  m.position.x = m.moveTween.current.x
  m.position.y = m.moveTween.current.y
  if done
    m.moveTween = invalid
  end if
end if
```

Nothing in the engine or examples exercises tweens at all today. #79 wants a worked example
once this exists.

## Design

### 1. `Easing` enum (`src/source/utils/tweens.bs`, namespace `BGE.Tweens`)

A string-backed enum whose values are exactly `GetTweens()`'s existing lookup keys - no
translation layer, `m.tweens[easing]` works directly since the enum value *is* the string
key. Matches the house style (`SpritePlayMode`, `HorizAlignment` are both string-backed
enums compared directly).

```brightscript
enum Easing
  LinearTween = "LinearTween"
  QuadraticTween = "QuadraticTween"
  QuadraticEaseIn = "QuadraticEaseIn"
  QuadraticEaseOut = "QuadraticEaseOut"
  QuadraticEaseInOut = "QuadraticEaseInOut"
  QuadraticEaseOutIn = "QuadraticEaseOutIn"
  SquareTween = "SquareTween"
  SquareEaseIn = "SquareEaseIn"
  SquareEaseOut = "SquareEaseOut"
  SquareEaseInOut = "SquareEaseInOut"
  SquareEaseOutIn = "SquareEaseOutIn"
  CubicTween = "CubicTween"
  CubicEaseIn = "CubicEaseIn"
  CubicEaseOut = "CubicEaseOut"
  CubicEaseInOut = "CubicEaseInOut"
  CubicEaseOutIn = "CubicEaseOutIn"
  QuarticTween = "QuarticTween"
  QuarticEaseIn = "QuarticEaseIn"
  QuarticEaseOut = "QuarticEaseOut"
  QuarticEaseInOut = "QuarticEaseInOut"
  QuarticEaseOutIn = "QuarticEaseOutIn"
  QuinticTween = "QuinticTween"
  QuinticEaseIn = "QuinticEaseIn"
  QuinticEaseOut = "QuinticEaseOut"
  QuinticEaseInOut = "QuinticEaseInOut"
  QuinticEaseOutIn = "QuinticEaseOutIn"
  SinusoidalTween = "SinusoidalTween"
  SinusoidalEaseIn = "SinusoidalEaseIn"
  SinusoidalEaseOut = "SinusoidalEaseOut"
  SinusoidalEaseInOut = "SinusoidalEaseInOut"
  SinusoidalEaseOutIn = "SinusoidalEaseOutIn"
  ExponentialTween = "ExponentialTween"
  ExponentialEaseIn = "ExponentialEaseIn"
  ExponentialEaseOut = "ExponentialEaseOut"
  ExponentialEaseInOut = "ExponentialEaseInOut"
  ExponentialEaseOutIn = "ExponentialEaseOutIn"
  CircularTween = "CircularTween"
  CircularEaseIn = "CircularEaseIn"
  CircularEaseOut = "CircularEaseOut"
  CircularEaseInOut = "CircularEaseInOut"
  CircularEaseOutIn = "CircularEaseOutIn"
  ElasticTween = "ElasticTween"
  ElasticEaseIn = "ElasticEaseIn"
  ElasticEaseOut = "ElasticEaseOut"
  ElasticEaseInOut = "ElasticEaseInOut"
  ElasticEaseOutIn = "ElasticEaseOutIn"
  OvershootTween = "OvershootTween"
  OvershootEaseIn = "OvershootEaseIn"
  OvershootEaseOut = "OvershootEaseOut"
  OvershootEaseInOut = "OvershootEaseInOut"
  OvershootEaseOutIn = "OvershootEaseOutIn"
  BounceTween = "BounceTween"
  BounceEaseIn = "BounceEaseIn"
  BounceEaseOut = "BounceEaseOut"
  BounceEaseInOut = "BounceEaseInOut"
  BounceEaseOutIn = "BounceEaseOutIn"
  SphericalTween = "SphericalTween"
end enum
```

Also add a `TweenLoopMode` enum in the same file:

```brightscript
enum TweenLoopMode
  none = "none"
  restart = "restart"
  pingPong = "pingPong"
end enum
```

### 2. `TweenManager` (new: `src/source/engine/TweenManager.bs`)

Placed alongside `GameTimer.bs` in `engine/`, not `utils/` - it's `Game`-owned and ticks
every frame like a first-class subsystem, the same tier `GameTimer` occupies (as opposed to
`MotionChecker`, a stateless-per-caller dirty-check utility that lives in `utils/`).

```brightscript
class TweenManager
  ' target is the sub-object directly - entity.position, a Drawable, a plain
  ' associative array. No dot-path strings.
  '
  ' @param {object} target
  ' @param {object} destFields - {fieldName: destValue, ...}
  ' @param {integer} duration - milliseconds
  ' @param {BGE.Tweens.Easing} [easing=LinearTween]
  ' @param {roAssociativeArray} [options] - owner, onComplete, loop, delay (see class doc)
  ' @return {integer} a handle for cancel()
  function to(target as object, destFields as object, duration as integer, easing = BGE.Tweens.Easing.LinearTween as BGE.Tweens.Easing, options = {} as roAssociativeArray) as integer

  ' Tweens a packed RGB (0xRRGGBB) color field channel-wise. Lerping the packed int
  ' directly is wrong; this decomposes into R/G/B, tweens each 0-255 channel, and repacks
  ' every tick.
  function toColorRGB(target as object, fieldName as string, destColor as integer, duration as integer, easing = ... as BGE.Tweens.Easing, options = {} as roAssociativeArray) as integer

  ' Same as toColorRGB but for a packed RGBA (0xRRGGBBAA) field.
  function toColorRGBA(target as object, fieldName as string, destColor as integer, duration as integer, easing = ... as BGE.Tweens.Easing, options = {} as roAssociativeArray) as integer

  sub cancel(handle as integer)

  ' Cancels every live tween. Called by Game on room change is NOT needed (see Validity
  ' below) - exposed for a consumer who wants to clear everything by hand.
  sub clear()

  ' Called once per frame by Game, after every entity's onUpdate/movement, before
  ' collisions. Not part of the public API surface consumers call directly.
  sub update()

  ' Called by Game.Resume() with the same paused_time it already computes, so every live
  ' managed tween's timer gets the identical RemoveTime() compensation
  ' AnimatedImage.onResume() already applies to its own timer.
  sub onResume(pausedTimeMs as integer)
end class
```

`options` (all optional):
- `owner as GameEntity` - see Validity below.
- `onComplete as function` - called once, with no args, when the tween retires (finishes
  with `loop = none`, or is `cancel()`led). Not called per-cycle for a looping tween.
- `loop as BGE.Tweens.TweenLoopMode` - default `none`.
- `delay as integer` - milliseconds before the tween starts ticking (target fields are left
  untouched until the delay elapses).

Internally, each managed tween wraps a `BGE.Tweens.CreateTweenObject()` result and reuses
`HandleTween`/`ChangeTweenDest` verbatim - proven primitives with existing Rooibos coverage,
rather than reimplementing interpolation. A managed-tween record also carries `target`,
`applyMode` (`"fields"` for `to()`, `"colorRGB"`/`"colorRGBA"` for the color variants),
`fieldName` (color variants only), `owner`, `onComplete`, `loopMode`, and remaining `delay`.

`update()` each frame, for every live managed tween (skipping ones still in their `delay`
window, just decrementing it):
1. If `owner` is set and `not isValidEntity(owner)`, drop the tween immediately (no
   `onComplete` call - it didn't finish, its owner disappeared).
2. Call `HandleTween(tweenObj)`.
3. Apply the interpolated values onto `target` per `applyMode`:
   - `"fields"`: `target[key] = tweenObj.current[key]` for every key in `destFields`.
   - `"colorRGB"`/`"colorRGBA"`: repack `tweenObj.current`'s channel floats (`cint()`ed,
     clamped 0-255) into a single packed int and assign `target[fieldName] = packedInt`.
4. If finished: apply `loopMode` (`restart` re-runs via a fresh `CreateTweenObject` with the
   same start/dest; `pingPong` re-runs with start/dest swapped) or, for `none`, call
   `onComplete` (if given) and remove the tween.

### 3. Validity & cleanup

If `owner` is given, `update()`'s per-tick `isValidEntity(owner)` check (step 1 above) is the
*only* cleanup mechanism needed - including for the room-change case: `Game.handleRoomChange()`
already destroys every non-persistent entity whose name doesn't match the incoming room
(`Game.bs:1394-1396`, `m.destroyEntity(entity, false)`), which invalidates it
(`entity.id` becomes invalid), so the very next `update()` tick drops the tween on its own.
No room-change-specific hook needed.

Without `owner` (a plain AA, a `Drawable`, a `Camera`, anything that isn't a `GameEntity`),
there is no automatic validity tracking - the caller owns the returned handle and is
responsible for `cancel()`. Document this plainly; it mirrors the general non-entity case
the issue itself calls out.

### 4. Pause

Mirrors `AnimatedImage.onResume(pausedTimeMs)` exactly (`AnimatedImage.bs:77-79`,
`m.animationTimer.RemoveTime(pausedTime)`): `Game.Resume()` already computes `paused_time`
before its existing per-entity/per-drawable `onResume()` loop
(`Game.bs:734-760`). Add one more call there: `m.tweenManager.onResume(paused_time)`, which
calls `RemoveTime(pausedTimeMs)` on every live managed tween's own `GameTimer` (each
`CreateTweenObject()` result already owns one). No dt-accumulation needed - this reuses the
exact wall-clock-plus-compensation approach already proven in this codebase.

### 5. Frame ordering

`Game` owns one `tweenManager as TweenManager` instance, exposed as a public field (not
`getTweenManager()` - matches how `Game.canvas`/`Game.sortedEntities` are already plain
public fields). `processEntitiesPreDraw()` (`Game.bs:389-440`) calls
`m.tweenManager.update()` once, after the full per-entity `onUpdate`/`processEntityMovement`
loop and before `processEntitiesCollisions()` - so:
- Every entity's `onUpdate` this frame has already run, and could have called `cancel()` on
  a tween before it applies this frame.
- Tweened values are settled before collision checks run, so colliders reflect the final
  position.
- **Documented precedence**: a tween writes its target fields *last* each frame. If a
  `GameEntity`'s `velocity` and a tween both drive `position` in the same frame, the tween's
  write wins - it overwrites whatever `processEntityMovement`'s velocity integration
  contributed that frame. Consumers should not combine velocity-driven and tween-driven
  motion on the same field of the same entity.

### 6. Out of scope for v1

- Nested field paths (`"position.x"` strings) - target the sub-object directly instead.
- `GetTweenObjectPercentState()`-style progress querying on a handle - not required by
  either issue; can follow up if wanted.

## Testing

- `TweenManager.spec.bs`: a real `Game` in `beforeEach` (matching `Game.spec.bs`'s existing
  pattern). Cover: `to()` writes interpolated values onto a plain AA target and onto
  `entity.position`; finishing retires the tween (target holds the exact `destFields`
  values); `owner` cleanup (an invalidated entity's tween silently stops updating, no
  crash); `cancel()`; `loop = restart` and `loop = pingPong` continue after finishing;
  `onComplete` fires exactly once; `toColorRGB`/`toColorRGBA` repack correctly at a few
  progress points; `delay` withholds writes until it elapses; `Game.Pause()`/`Resume()`
  doesn't advance a tween's progress across the paused interval (mirroring how
  `AnimatedImage`'s pause test - if one exists - is structured, or `GameTimer.spec.bs`'s own
  `addTime`/`removeTime` coverage).
- Note `assertEqual`'s Integer/Float strictness will bite immediately on tween output
  (`cint()`/plain assignment produce different types) - read the actual/expected types out
  of the failure diff rather than guessing, per this repo's standing gotcha.

## Worked example (`examples/tweens`, issue #79)

Scaffolded via `npm run create-example -- tweens "Tweens Example"`. One room, `BGE.UI.Label`-based
(not a rendererTest-style hand-rolled immediate-mode menu - that pattern exists there
specifically because `rendererTest` has no `Game`/UI available; this example does):

- Up/down cycles the selected `Easing` value (from the full enum list above).
- Left/right cycles which demo aspect is currently shown: a small entity sliding
  left-to-right (`position`), one pulsing in/out (`scale`), one fading between two colors
  (`toColorRGB`).
- OK re-triggers the current aspect's tween using the currently selected easing.
- A `Label` displays the current easing name and aspect.
