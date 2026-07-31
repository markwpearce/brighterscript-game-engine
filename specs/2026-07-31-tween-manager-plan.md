# TweenManager Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A `Game`-owned `TweenManager` that ticks every live tween once per frame and writes interpolated values straight onto arbitrary target object fields, plus a worked example.

**Architecture:** `TweenManager` wraps `BGE.Tweens.CreateTweenObject()`/`HandleTween()`/`ChangeTweenDest()` per managed tween (existing, already-tested primitives) rather than reimplementing interpolation. Each managed tween is a plain associative array record kept in an internal AA keyed by an auto-incrementing integer handle. `Game` owns one instance as a public field, ticks it once per frame from `processEntitiesPreDraw()` (after the entity update/movement loop, before collisions), and forwards its own `Resume()`-computed pause duration to it.

**Tech Stack:** BrighterScript compiled with `bsc`; Rooibos v6 (`rooibos-roku`) specs colocated as `*.spec.bs`; `brs-cli` for headless test runs; `rokubot` for on-device verification of the worked example.

**Spec:** `specs/2026-07-31-tween-manager-design.md`
**Issues:** [#60](https://github.com/markwpearce/brighterscript-game-engine/issues/60), [#79](https://github.com/markwpearce/brighterscript-game-engine/issues/79)
**Branch:** `feature/tween-manager` (already created, spec doc already committed)

## Global Constraints

- All engine source lives under `src/source/` inside the `BGE` namespace. Specs live in `namespace tests`.
- `bslint.json` sets `inline-if-style: never` — never write a single-line `if`. Always use a multi-line `if` / `end if`.
- **A `*.spec.bs` file may contain only one `@suite` class.**
- **`assertEqual` is type-strict**: `1` (Integer) vs `1.0` (Float) fail against each other. Tween output is float-heavy (`cint()` in the color-repack path produces Integer) — when a comparison fails unexpectedly, read the actual/expected *types* out of the Rooibos failure diff rather than guessing.
- Never compare whole engine objects with `assertEqual` — compare a distinguishing scalar.
- Public engine methods get JSDoc-style `'` comments with `@param`/`@return`.
- Per-task verification is `npm run test:ci`. The full gate before the PR is `npm run check`.
- `Game`'s "Internal Use, Do Not Manually Alter" field block (`Game.bs:34-82`) is a real convention — new *public* API surface (like `tweenManager`) goes in the public field section below it (`Game.bs:85-111`), matching how `sortedEntities`/`Entities`/`Rooms` etc. are declared.

## File Structure

**Modified:**
- `src/source/utils/tweens.bs` — Task 1. Adds `Easing` and `TweenLoopMode` enums.
- `src/source/utils/tweens.spec.bs` — Task 1.
- `src/source/engine/Game.bs` — Task 5. New public `tweenManager` field, one call in `processEntitiesPreDraw()`, one call in `Resume()`.
- `src/source/engine/Game.spec.bs` — Task 5.
- `docs/game-engine-overview.md` (or `docs/engine-internals.md` — check both, see Task 6) — Task 6.
- `examples/tweens/*` — Task 7 (scaffolded fresh, then edited).

**Created:**
- `src/source/engine/TweenManager.bs` — Tasks 2-4.
- `src/source/engine/TweenManager.spec.bs` — Tasks 2-4.

---

### Task 1: `Easing` and `TweenLoopMode` enums

**Files:**
- Modify: `src/source/utils/tweens.bs` (top of file, inside `namespace BGE.Tweens` — confirm the exact namespace declaration at the top of the file first; the design doc assumes `BGE.Tweens` but verify against the file's actual `namespace` line before adding the enums, since enums must live in the same namespace block)
- Test: `src/source/utils/tweens.spec.bs`

**Interfaces:**
- Consumes: nothing.
- Produces: `BGE.Tweens.Easing` enum (56 string values, each equal to its own name — see full list in the design doc's Section 1, copy it verbatim), `BGE.Tweens.TweenLoopMode` enum (`none`, `restart`, `pingPong`).

- [ ] **Step 1: Check the file's actual namespace**

Run: `head -5 src/source/utils/tweens.bs` — confirm whether it's `namespace BGE.Tweens` or `namespace BGE` with functions merely prefixed by convention. Adjust the enum's namespace placement in Step 3 to match whatever is actually there (if it's plain `namespace BGE`, the enum becomes `BGE.Easing`/`BGE.TweenLoopMode`, and every reference in this plan and the design doc to `BGE.Tweens.Easing` needs the same adjustment throughout the rest of this plan — do that substitution consistently in every later task if so).

- [ ] **Step 2: Write the failing test**

Add to `tweens.spec.bs` (check its existing `@describe` blocks first and place this sensibly relative to them):

```brightscript
    @describe("Easing enum")

    @it("every Easing value is a valid key in GetTweens()")
    function _()
      tweens = BGE.Tweens.GetTweens()
      m.assertNotInvalid(tweens[BGE.Tweens.Easing.LinearTween])
      m.assertNotInvalid(tweens[BGE.Tweens.Easing.QuadraticEaseInOut])
      m.assertNotInvalid(tweens[BGE.Tweens.Easing.SphericalTween])
    end function
```

- [ ] **Step 3: Run to verify it fails**

Run: `npm run build-tests && npm run test:ci`
Expected: FAIL — `Easing` doesn't exist yet.

- [ ] **Step 4: Add the enums**

Add near the top of `tweens.bs`, after the namespace declaration:

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

  ' How a managed BGE.TweenManager tween behaves once it reaches its destination.
  enum TweenLoopMode
    ' Retire the tween once it reaches its destination (the default).
    none = "none"
    ' Jump back to the start value and run the same tween again.
    restart = "restart"
    ' Reverse direction each time it finishes, alternating endpoints indefinitely.
    pingPong = "pingPong"
  end enum
```

Double check every value against the real `GetTweens()` key list in the same file (`GetTweens()`'s object literal) — the list above was transcribed from it, but the source is authoritative if the two ever disagree.

- [ ] **Step 5: Run to verify it passes**

Run: `npm run build-tests && npm run test:ci`
Expected: PASS. All 416 previously-passing tests still pass.

- [ ] **Step 6: Commit**

```bash
git add src/source/utils/tweens.bs src/source/utils/tweens.spec.bs
git commit -m "Add Easing and TweenLoopMode enums

String-backed, matching the house style (SpritePlayMode, HorizAlignment) -
Easing's values are exactly GetTweens()'s existing lookup keys, so there's
no translation layer between the enum and the easing-function table.

Part of #60"
```

---

### Task 2: `TweenManager` core — `to()`, `update()`, `cancel()`, `clear()`, owner validity

**Files:**
- Create: `src/source/engine/TweenManager.bs`
- Create: `src/source/engine/TweenManager.spec.bs`

**Interfaces:**
- Consumes: `BGE.Tweens.Easing` (Task 1), `BGE.Tweens.CreateTweenObject`/`HandleTween` (existing), `BGE.isValidEntity` (existing, `src/source/utils/utils.bs`).
- Produces: `BGE.TweenManager` class with `to()`, `update()`, `cancel()`, `clear()`. `toColorRGB()`/`toColorRGBA()`/`onComplete`/`loop`/`delay` come in Tasks 3-4 — don't implement them yet, but do accept and ignore an `options` AA in `to()`'s signature now so Task 3 doesn't have to change the signature again.

- [ ] **Step 1: Write the failing tests**

Create `src/source/engine/TweenManager.spec.bs`, modeled on `Game.spec.bs`'s real-`Game`-in-`beforeEach` pattern:

```brightscript
namespace tests

  @suite("BGE.TweenManager")
  class TweenManagerTests extends rooibos.BaseTestSuite

    game as BGE.Game
    manager as BGE.TweenManager

    protected override function beforeEach()
      m.game = new BGE.Game(320, 240)
      m.manager = new BGE.TweenManager()
    end function

    @describe("to / update - writing interpolated values onto a target")

    @it("writes the exact start value before any time has passed")
    function _()
      target = {x: 0.0, y: 0.0}
      m.manager.to(target, {x: 100.0, y: 50.0}, 1000, BGE.Tweens.Easing.LinearTween)
      m.manager.update()
      m.assertEqual(0.0, target.x)
      m.assertEqual(0.0, target.y)
    end function

    @it("writes the exact destination values once the duration has elapsed")
    function _()
      target = {x: 0.0, y: 0.0}
      m.manager.to(target, {x: 100.0, y: 50.0}, 0, BGE.Tweens.Easing.LinearTween)
      m.manager.update()
      m.assertEqual(100.0, target.x)
      m.assertEqual(50.0, target.y)
    end function

    @it("only writes the fields named in destFields, leaving others alone")
    function _()
      target = {x: 0.0, untouched: 42}
      m.manager.to(target, {x: 100.0}, 0, BGE.Tweens.Easing.LinearTween)
      m.manager.update()
      m.assertEqual(42, target.untouched)
    end function

    @it("writes onto a GameEntity's position vector")
    function _()
      entity = new BGE.GameEntity(m.game, {name: "TestEntity"})
      m.manager.to(entity.position, {x: 100.0}, 0, BGE.Tweens.Easing.LinearTween)
      m.manager.update()
      m.assertEqual(100.0, entity.position.x)
    end function

    @describe("cancel / clear")

    @it("cancel stops a tween from being updated further")
    function _()
      target = {x: 0.0}
      handle = m.manager.to(target, {x: 100.0}, 1000, BGE.Tweens.Easing.LinearTween)
      m.manager.cancel(handle)
      m.manager.update()
      m.assertEqual(0.0, target.x)
    end function

    @it("clear cancels every live tween")
    function _()
      targetA = {x: 0.0}
      targetB = {x: 0.0}
      m.manager.to(targetA, {x: 100.0}, 1000, BGE.Tweens.Easing.LinearTween)
      m.manager.to(targetB, {x: 100.0}, 1000, BGE.Tweens.Easing.LinearTween)
      m.manager.clear()
      m.manager.update()
      m.assertEqual(0.0, targetA.x)
      m.assertEqual(0.0, targetB.x)
    end function

    @describe("owner validity")

    @it("stops updating once its owner entity is destroyed")
    function _()
      entity = new BGE.GameEntity(m.game, {name: "TestEntity"})
      target = {x: 0.0}
      m.manager.to(target, {x: 100.0}, 1000, BGE.Tweens.Easing.LinearTween, {owner: entity})

      m.game.destroyEntity(entity, false)
      m.manager.update()

      m.assertEqual(0.0, target.x)
    end function

    @it("keeps updating a tween with no owner regardless of anything else")
    function _()
      target = {x: 0.0}
      m.manager.to(target, {x: 100.0}, 0, BGE.Tweens.Easing.LinearTween)
      m.manager.update()
      m.assertEqual(100.0, target.x)
    end function

  end class

end namespace
```

Adjust field-name casing/exact assertions once you see real `assertEqual` type-strictness failures (per the Global Constraints note) — don't guess the Integer/Float split, read it from the actual failure.

- [ ] **Step 2: Run to verify they fail**

Run: `npm run build-tests && npm run test:ci`
Expected: FAIL — `BGE.TweenManager` doesn't exist.

- [ ] **Step 3: Implement `TweenManager.bs`**

```brightscript
namespace BGE

  ' Ticks every live tween once per frame (see Game.tweenManager) and writes interpolated
  ' values straight onto arbitrary target object fields - no manual per-frame HandleTween()
  ' bookkeeping required. Wraps BGE.Tweens.CreateTweenObject()/HandleTween() per managed
  ' tween rather than reimplementing interpolation.
  class TweenManager

    private tweens as object = {}
    private nextId as integer = 0

    ' Tweens one or more fields on target from their current values to destFields' values.
    ' target is the sub-object to write onto directly - e.g. an entity's own `position`
    ' Vector, a Drawable, a plain associative array - not the owning entity itself and not
    ' a dot-path string.
    '
    ' @param {object} target
    ' @param {object} destFields - {fieldName: destValue, ...}
    ' @param {integer} duration - milliseconds
    ' @param {BGE.Tweens.Easing} [easing=LinearTween]
    ' @param {roAssociativeArray} [options] - owner (GameEntity, for automatic cleanup once
    '   it's no longer valid - see class doc), onComplete, loop, delay (Task 3)
    ' @return {integer} a handle for cancel()
    function to(target as object, destFields as object, duration as integer, easing = BGE.Tweens.Easing.LinearTween as BGE.Tweens.Easing, options = {} as roAssociativeArray) as integer
      startFields = {}
      for each key in destFields
        startFields[key] = target[key]
      end for

      id = m.nextId
      m.nextId++

      m.tweens[id.toStr()] = {
        tweenObj: BGE.Tweens.CreateTweenObject(startFields, destFields, duration, easing.toStr()),
        target: target,
        applyMode: "fields",
        fieldName: invalid,
        owner: options.owner
      }
      return id
    end function

    sub cancel(handle as integer)
      m.tweens.Delete(handle.toStr())
    end sub

    sub clear()
      m.tweens = {}
    end sub

    ' Ticks every live tween and applies its current interpolated value. Called once per
    ' frame by Game - not part of the API a consumer calls directly.
    sub update()
      idsToRemove = []
      for each key in m.tweens
        managed = m.tweens[key]
        if invalid <> managed.owner and not BGE.isValidEntity(managed.owner)
          idsToRemove.push(key)
        else
          finished = BGE.Tweens.HandleTween(managed.tweenObj)
          m.applyTween(managed)
          if finished
            idsToRemove.push(key)
          end if
        end if
      end for
      for each key in idsToRemove
        m.tweens.Delete(key)
      end for
    end sub

    private sub applyTween(managed as object)
      if managed.applyMode = "fields"
        for each key in managed.tweenObj.current
          managed.target[key] = managed.tweenObj.current[key]
        end for
      end if
    end sub

  end class

end namespace
```

Note: `easing.toStr()` — an enum member's value is already the string (`Easing.LinearTween = "LinearTween"`), but `CreateTweenObject`'s `tween` parameter is typed `as string`, and passing an enum member directly may or may not satisfy that type-check depending on how strictly `bsc` treats enum-typed values against a `string` parameter. Try passing `easing` directly first (`CreateTweenObject(startFields, destFields, duration, easing)`); only add `.toStr()` if `npm run build-tests` reports a type error there.

- [ ] **Step 4: Run to verify they pass**

Run: `npm run build-tests && npm run test:ci`
Expected: PASS. Watch for `assertEqual` Integer/Float mismatches per the Global Constraints note — fix the test's literal types (not the production code) to match whatever `HandleTween`/the AA field actually produces.

- [ ] **Step 5: Commit**

```bash
git add src/source/engine/TweenManager.bs src/source/engine/TweenManager.spec.bs
git commit -m "Add TweenManager core: to(), update(), cancel(), clear(), owner validity

Wraps BGE.Tweens.CreateTweenObject()/HandleTween() per managed tween.
An optional owner (GameEntity) in options gets checked with
isValidEntity() every tick - once invalid, the tween is dropped
silently, which is also what makes a room-change destroying a
non-persistent owning entity clean itself up for free on the very next
tick, with no room-change-specific hook needed.

Part of #60"
```

---

### Task 3: `onComplete`, `loop` (none/restart/pingPong), `delay`

**Files:**
- Modify: `src/source/engine/TweenManager.bs`
- Modify: `src/source/engine/TweenManager.spec.bs`

**Interfaces:**
- Consumes: `BGE.Tweens.TweenLoopMode` (Task 1), `BGE.Tweens.ChangeTweenDest` (existing).
- Produces: `to()`'s `options.onComplete`/`options.loop`/`options.delay` become live.

- [ ] **Step 1: Write the failing tests**

Add to `TweenManager.spec.bs`:

```brightscript
    @describe("onComplete")

    @it("calls onComplete exactly once when a one-shot tween finishes")
    function _()
      target = {x: 0.0}
      m.completeCount = 0
      m.manager.to(target, {x: 100.0}, 0, BGE.Tweens.Easing.LinearTween, {onComplete: sub()
        m.completeCount++
      end sub})
      m.manager.update()
      m.manager.update()
      m.assertEqual(1, m.completeCount)
    end function

    @it("does not call onComplete when the tween is cancelled")
    function _()
      target = {x: 0.0}
      m.completeCount = 0
      handle = m.manager.to(target, {x: 100.0}, 1000, BGE.Tweens.Easing.LinearTween, {onComplete: sub()
        m.completeCount++
      end sub})
      m.manager.cancel(handle)
      m.manager.update()
      m.assertEqual(0, m.completeCount)
    end function

    @describe("loop")

    @it("restart jumps back to the start value and keeps running")
    function _()
      target = {x: 0.0}
      m.manager.to(target, {x: 100.0}, 0, BGE.Tweens.Easing.LinearTween, {loop: BGE.Tweens.TweenLoopMode.restart})
      m.manager.update()
      m.assertEqual(100.0, target.x)
      m.manager.update()
      m.assertEqual(100.0, target.x)
    end function

    @it("pingPong reverses direction once it reaches the destination")
    function _()
      target = {x: 0.0}
      m.manager.to(target, {x: 100.0}, 0, BGE.Tweens.Easing.LinearTween, {loop: BGE.Tweens.TweenLoopMode.pingPong})
      m.manager.update()
      m.assertEqual(100.0, target.x)
      ' the next tick's duration-0 tween immediately reaches its (reversed) destination too
      m.manager.update()
      m.assertEqual(0.0, target.x)
    end function

    @describe("delay")

    @it("withholds writes until the delay elapses, then behaves like an undelayed tween")
    function _()
      target = {x: 0.0}
      m.manager.to(target, {x: 100.0}, 0, BGE.Tweens.Easing.LinearTween, {delay: 500})
      m.manager.update()
      m.assertEqual(0.0, target.x)
    end function
```

`m.completeCount` on the test suite instance (rather than a local var) is needed because the `sub()` callback closes over `m` at its own definition site inside the test method, which - depending on how BrighterScript closures capture `m` inside anonymous subs declared inside a class method - may or may not see a plain local variable. Confirm this works as written; if `m.completeCount` isn't visible/mutable from inside the anonymous `sub()`, that's a real finding to note in the PR, and the fallback is capturing via a single-element array (`count = [0]` then `count[0]++`) instead.

- [ ] **Step 2: Run to verify they fail**

Run: `npm run build-tests && npm run test:ci`
Expected: FAIL (or a build/type error if the closure-capture concern above bites - resolve that first if so, using the array fallback, before treating this as a normal red-green step).

- [ ] **Step 3: Implement**

Extend the managed-tween record and `to()`:

```brightscript
      m.tweens[id.toStr()] = {
        tweenObj: BGE.Tweens.CreateTweenObject(startFields, destFields, duration, easing),
        target: target,
        applyMode: "fields",
        fieldName: invalid,
        owner: options.owner,
        onComplete: options.onComplete,
        loopMode: BGE.firstNonInvalid([options.loop, BGE.Tweens.TweenLoopMode.none]),
        delayRemainingMs: BGE.firstNonInvalid([options.delay, 0]),
        originalStart: startFields,
        originalDest: destFields,
        pingPongForwardNext: false
      }
```

Check whether `BGE.firstNonInvalid` (a "default if invalid" helper) already exists somewhere in `utils/` before assuming it — run `grep -rn "firstNonInvalid\|function.*Default.*Invalid" src/source/utils/`. If nothing already provides this, write the default inline instead: `loopMode = BGE.Tweens.TweenLoopMode.none : if invalid <> options.loop then loopMode = options.loop`, same pattern for `delayRemainingMs`, and drop the fictitious `firstNonInvalid` call above.

Rewrite `update()`'s per-tween body to handle delay and looping:

```brightscript
    sub update()
      idsToRemove = []
      for each key in m.tweens
        managed = m.tweens[key]
        if invalid <> managed.owner and not BGE.isValidEntity(managed.owner)
          idsToRemove.push(key)
        else if managed.delayRemainingMs > 0
          managed.delayRemainingMs -= BGE.Math.max(1, m.lastTickMs)
        else
          finished = BGE.Tweens.HandleTween(managed.tweenObj)
          m.applyTween(managed)
          if finished
            if managed.loopMode = BGE.Tweens.TweenLoopMode.restart
              managed.tweenObj.timer.Mark()
            else if managed.loopMode = BGE.Tweens.TweenLoopMode.pingPong
              nextDest = managed.originalStart
              if managed.pingPongForwardNext
                nextDest = managed.originalDest
              end if
              managed.pingPongForwardNext = not managed.pingPongForwardNext
              BGE.Tweens.ChangeTweenDest(managed.tweenObj, nextDest)
            else
              if invalid <> managed.onComplete
                managed.onComplete()
              end if
              idsToRemove.push(key)
            end if
          end if
        end if
      end for
      for each key in idsToRemove
        m.tweens.Delete(key)
      end for
    end sub
```

The `delayRemainingMs -= BGE.Math.max(1, m.lastTickMs)` line above is a placeholder for "decrement by however long since the last tick" - **do not implement it that way**. `update()` currently takes no timing info at all, and delay needs *some* elapsed-time source. Two real options, pick one and implement it properly (this is a genuine open design gap the plan's author did not resolve - resolve it now, in code, not with a fake helper call):

- **(a)** Give a delayed tween its own `GameTimer`, marked at creation, and check `delayTimer.TotalMilliseconds() >= delayRemainingMs` each tick instead of decrementing a counter - simplest, and reuses the exact same timer-based pattern already used everywhere else in this file.
- **(b)** Have `Game` pass its own `m.dt` (already computed every frame, in seconds) into `TweenManager.update(dt as float)`, and decrement `delayRemainingMs` by `dt * 1000`.

Prefer **(a)**: it needs no signature change to `update()` (keeps Task 2's `sub update()` call site in `Game.bs` untouched either way, but (a) also avoids threading a `dt` value through a call this plan already wrote elsewhere) and matches this file's existing style of "every timed thing owns a `GameTimer`". Add `delayTimer as BGE.GameTimer = invalid` to the managed-tween record, created and `Mark()`ed in `to()` only when `delayRemainingMs > 0`, and replace the `update()` branch above with:

```brightscript
        else if invalid <> managed.delayTimer and managed.delayTimer.TotalMilliseconds() < managed.delayRemainingMs
          ' still waiting out its delay
```

- [ ] **Step 4: Run to verify they pass**

Run: `npm run build-tests && npm run test:ci`

- [ ] **Step 5: Commit**

```bash
git add src/source/engine/TweenManager.bs src/source/engine/TweenManager.spec.bs
git commit -m "Add onComplete, loop (restart/pingPong), and delay to TweenManager

restart re-marks the same tween's timer (start/dest never change,
so a zero-elapsed re-tick naturally reproduces the start value).
pingPong alternates ChangeTweenDest() between the tween's original
two endpoints every time it finishes, tracked with a simple forward/
backward flag - both reuse existing BGE.Tweens primitives rather than
reimplementing interpolation. delay uses its own GameTimer, mirroring
how every other timed thing in this file already works.

Part of #60"
```

---

### Task 4: `toColorRGB()` / `toColorRGBA()`

**Files:**
- Modify: `src/source/engine/TweenManager.bs`
- Modify: `src/source/engine/TweenManager.spec.bs`

**Interfaces:**
- Consumes: nothing new beyond Task 2/3's internals.
- Produces: `TweenManager.toColorRGB()`, `TweenManager.toColorRGBA()`.

- [ ] **Step 1: Write the failing tests**

```brightscript
    @describe("toColorRGB / toColorRGBA")

    @it("toColorRGB writes the exact destination color once finished")
    function _()
      target = {tint: &h000000}
      m.manager.toColorRGB(target, "tint", &hFF8000, 0, BGE.Tweens.Easing.LinearTween)
      m.manager.update()
      m.assertEqual(&hFF8000, target.tint)
    end function

    @it("toColorRGB writes the exact start color before any time has passed")
    function _()
      target = {tint: &h102030}
      m.manager.toColorRGB(target, "tint", &hFF8000, 1000, BGE.Tweens.Easing.LinearTween)
      m.manager.update()
      m.assertEqual(&h102030, target.tint)
    end function

    @it("toColorRGBA writes the exact destination color (with alpha) once finished")
    function _()
      target = {tint: &h00000000}
      m.manager.toColorRGBA(target, "tint", &hFF8000C0, 0, BGE.Tweens.Easing.LinearTween)
      m.manager.update()
      m.assertEqual(&hFF8000C0, target.tint)
    end function
```

- [ ] **Step 2: Run to verify they fail**

Run: `npm run build-tests && npm run test:ci`
Expected: FAIL — the methods don't exist.

- [ ] **Step 3: Implement**

Refactor `to()`'s body into a shared private helper both `to()` and the color variants call, then add the two new public methods and extend `applyTween()`:

```brightscript
    function toColorRGB(target as object, fieldName as string, destColor as integer, duration as integer, easing = BGE.Tweens.Easing.LinearTween as BGE.Tweens.Easing, options = {} as roAssociativeArray) as integer
      startColor = target[fieldName]
      startFields = {
        r: (startColor >> 16) and &hFF,
        g: (startColor >> 8) and &hFF,
        b: startColor and &hFF
      }
      destFields = {
        r: (destColor >> 16) and &hFF,
        g: (destColor >> 8) and &hFF,
        b: destColor and &hFF
      }
      return m.addManagedTween(target, startFields, destFields, duration, easing, options, "colorRGB", fieldName)
    end function

    function toColorRGBA(target as object, fieldName as string, destColor as integer, duration as integer, easing = BGE.Tweens.Easing.LinearTween as BGE.Tweens.Easing, options = {} as roAssociativeArray) as integer
      startColor = target[fieldName]
      startFields = {
        r: startColor >> 24,
        g: (startColor >> 16) and &hFF,
        b: (startColor >> 8) and &hFF,
        a: startColor and &hFF
      }
      destFields = {
        r: destColor >> 24,
        g: (destColor >> 16) and &hFF,
        b: (destColor >> 8) and &hFF,
        a: destColor and &hFF
      }
      return m.addManagedTween(target, startFields, destFields, duration, easing, options, "colorRGBA", fieldName)
    end function
```

Extract `to()`'s current body (from Task 2/3) into `addManagedTween(target, startFields, destFields, duration, easing, options, applyMode, fieldName)`, returning the handle, and have `to()` call it with `applyMode = "fields"`, `fieldName = invalid`. Then extend `applyTween()`:

```brightscript
    private sub applyTween(managed as object)
      if managed.applyMode = "fields"
        for each key in managed.tweenObj.current
          managed.target[key] = managed.tweenObj.current[key]
        end for
      else if managed.applyMode = "colorRGB"
        c = managed.tweenObj.current
        managed.target[managed.fieldName] = (cint(c.r) << 16) + (cint(c.g) << 8) + cint(c.b)
      else if managed.applyMode = "colorRGBA"
        c = managed.tweenObj.current
        managed.target[managed.fieldName] = (cint(c.r) << 24) + (cint(c.g) << 16) + (cint(c.b) << 8) + cint(c.a)
      end if
    end sub
```

- [ ] **Step 4: Run to verify they pass**

Run: `npm run build-tests && npm run test:ci`

- [ ] **Step 5: Commit**

```bash
git add src/source/engine/TweenManager.bs src/source/engine/TweenManager.spec.bs
git commit -m "Add toColorRGB()/toColorRGBA() for channel-wise packed color tweening

Lerping a packed 0xRRGGBB/0xRRGGBBAA int directly is wrong; these
decompose into channels, run an ordinary 3-or-4-field tween under the
hood via the same addManagedTween() path to()/the fields apply mode
already uses, and repack every tick.

Part of #60"
```

---

### Task 5: Wire into `Game`

**Files:**
- Modify: `src/source/engine/Game.bs` (public field section ~85-111, `processEntitiesPreDraw()` ~389-440, `Resume()` ~734-760)
- Modify: `src/source/engine/Game.spec.bs`

**Interfaces:**
- Consumes: `BGE.TweenManager` (Tasks 2-4).
- Produces: `Game.tweenManager as BGE.TweenManager`, ticked automatically every frame.

- [ ] **Step 1: Write the failing tests**

Add to `Game.spec.bs`:

```brightscript
    @describe("tweenManager")

    @it("is ticked once per frame via processEntitiesPreDraw")
    function _()
      target = {x: 0.0}
      m.game.tweenManager.to(target, {x: 100.0}, 0, BGE.Tweens.Easing.LinearTween)
      m.game.processEntitiesPreDraw([], invalid, invalid, invalid)
      m.assertEqual(100.0, target.x)
    end function

    @it("Resume() compensates every live tween's timer for the paused duration")
    function _()
      target = {x: 0.0}
      m.game.tweenManager.to(target, {x: 100.0}, 1000, BGE.Tweens.Easing.LinearTween)
      m.game.Pause()
      pausedMs = m.game.Resume()
      m.game.processEntitiesPreDraw([], invalid, invalid, invalid)
      ' the tween should report negligible progress - nowhere near halfway - since the
      ' paused interval was compensated out rather than counted as elapsed tween time
      m.assertTrue(target.x < 50.0)
    end function
```

Check `processEntitiesPreDraw`'s exact current parameter types before finalizing this test — it's `private`, so confirm Rooibos can actually call a `private sub` from a spec in a different namespace (some of this codebase's other specs call `sceneObj.update()`/similar without trouble on `protected` members via same-class-hierarchy access, but `private` is stricter — if `bslint`/`bsc` rejects calling a `private` method from the spec, this test needs a different entry point, e.g. driving it through `Game.Play()` isn't practical in a unit test, so instead call `m.game.tweenManager.update()` directly for the first test (dropping the `processEntitiesPreDraw` call entirely) and keep the `Resume()` test focused purely on `tweenManager`/`Pause`/`Resume`, not on `processEntitiesPreDraw`'s wiring. If `private` access does work fine (this codebase's own convention for `private` vs `protected` may be looser than the label suggests — verify rather than assume), keep the test as written since it's a strictly better test of the actual wiring.

- [ ] **Step 2: Run to verify they fail**

Run: `npm run build-tests && npm run test:ci`
Expected: FAIL — `Game.tweenManager` doesn't exist yet.

- [ ] **Step 3: Add the field**

In `Game.bs`, in the public field block (after `Models = {}`, before `gameUi`):

```brightscript
    ' Ticks every live tween once per frame and writes interpolated values onto arbitrary
    ' target fields - see BGE.TweenManager.to().
    tweenManager as BGE.TweenManager = new BGE.TweenManager()

```

- [ ] **Step 4: Tick it in `processEntitiesPreDraw()`**

At the end of `processEntitiesPreDraw()`, right before the trailing `m.processEntitiesCollisions(startedPaused)` call:

```brightscript
      m.tweenManager.update()
      m.processEntitiesCollisions(startedPaused)
```

- [ ] **Step 5: Hook `Resume()`**

In `Resume()`, right after `paused_time = m.pauseTimer.TotalMilliseconds()`:

```brightscript
        paused_time = m.pauseTimer.TotalMilliseconds()
        m.tweenManager.onResume(paused_time)
```

Add `onResume()` to `TweenManager.bs`:

```brightscript
    ' Compensates every live tween's timer for a pause of the given duration, mirroring
    ' AnimatedImage.onResume() - called by Game.Resume() with the same paused_time it
    ' already computes for every entity/drawable's own onResume().
    '
    ' @param {integer} pausedTimeMs
    sub onResume(pausedTimeMs as integer)
      for each key in m.tweens
        m.tweens[key].tweenObj.timer.RemoveTime(pausedTimeMs)
        if invalid <> m.tweens[key].delayTimer
          m.tweens[key].delayTimer.RemoveTime(pausedTimeMs)
        end if
      end for
    end sub
```

- [ ] **Step 6: Run to verify they pass**

Run: `npm run build-tests && npm run test:ci`

- [ ] **Step 7: Full local gate**

Run: `npm run check`

- [ ] **Step 8: Commit**

```bash
git add src/source/engine/Game.bs src/source/engine/Game.spec.bs src/source/engine/TweenManager.bs
git commit -m "Wire TweenManager into Game: tick every frame, compensate on Resume()

Game.tweenManager is ticked once per frame in processEntitiesPreDraw(),
after every entity's onUpdate/movement and before collisions - so an
onUpdate can cancel/redirect a tween before it applies that frame, and
tweened values are settled before collision checks run. A tween's
write wins over the same frame's velocity integration if both target
the same field (documented, not specially handled).

Resume() forwards its already-computed paused_time to
tweenManager.onResume(), which RemoveTime()s it off every live tween's
timer - identical to how AnimatedImage.onResume() already compensates
its own timer.

Part of #60"
```

---

### Task 6: Docs

**Files:**
- Modify: whichever of `docs/game-engine-overview.md` / `docs/engine-internals.md` covers the game loop and per-frame update ordering (check both - `game-engine-overview.md` is likely the consumer-facing guide, `engine-internals.md` the deeper internals one; add a short section to whichever most naturally covers "things that happen every frame", following that guide's existing style - lead with a how-to code example per this repo's own `feedback_docs_fundamentals_over_gotchas` convention, not a gotchas-first writeup)
- Modify: `CLAUDE.md`'s Game loop section (`## Game loop (engine/Game.bs)`) — add one line noting tweens are ticked as part of the per-frame update pass, consistent with how that section already summarizes each phase

**Interfaces:** none (documentation only).

- [ ] **Step 1: Read both docs/ guides' current structure**

Run: `grep -n "^#\|^##" docs/game-engine-overview.md docs/engine-internals.md`

- [ ] **Step 2: Add a "Tweens" section**

Following whichever guide fits (probably `game-engine-overview.md`, as a new `##` section near wherever it already covers per-frame entity behavior), write a short, example-led section:

```markdown
## Tweens

`Game.tweenManager` (`BGE.TweenManager`) ticks every live tween once per frame and writes
interpolated values straight onto whatever field(s) you target - no manual per-frame
bookkeeping needed:

\```brightscript
' in onCreate
m.owner.game.tweenManager.to(m.position, {x: 100, y: 50}, 1000, BGE.Tweens.Easing.QuadraticEaseInOut, {
  owner: m
})
\```

`target` is the object to write onto directly - `m.position` above, or a `Drawable`, or a
plain associative array - not the owning entity itself. Passing `owner: m` (a `GameEntity`)
lets the manager clean the tween up automatically once that entity is no longer valid
(including when a room change destroys it); without an owner, hang onto the returned handle
and call `game.tweenManager.cancel(handle)` yourself when you're done with it.

For a packed color field (`0xRRGGBB`/`0xRRGGBBAA`), use `toColorRGB()`/`toColorRGBA()`
instead of `to()` - lerping the packed integer directly gives the wrong color:

\```brightscript
m.owner.game.tweenManager.toColorRGB(myDrawable, "color", BGE.ColorsRGB.Red, 500)
\```

`options` also accepts `onComplete` (a sub called once when the tween retires),
`loop` (`BGE.Tweens.TweenLoopMode.restart`/`.pingPong`, default `.none`), and `delay`
(milliseconds before the tween starts).
```

Adjust the exact surrounding heading level/frontmatter to match the target file's existing conventions (check its frontmatter `group`/`order` first).

- [ ] **Step 3: Update `CLAUDE.md`**

In the `### Game loop (\`engine/Game.bs\`)` section's numbered list, find the "Update" step (`processEntitiesPreDraw`) and append a short clause noting the tween tick, e.g. after the existing description of what that step does: "...then applies velocity to position (\`processEntityMovement\`); \`Game.tweenManager\` is ticked once per frame at the end of this pass, writing any live tween's interpolated values onto their target fields."

- [ ] **Step 4: Commit**

```bash
git add docs/ CLAUDE.md
git commit -m "docs: describe TweenManager

Part of #60"
```

---

### Task 7: `examples/tweens` worked example + on-device verification

**Files:**
- Create: `examples/tweens/*` (scaffolded)

**Interfaces:**
- Consumes: `Game.tweenManager` (Task 5).
- Produces: nothing consumed elsewhere - terminal, demonstrable deliverable.

- [ ] **Step 1: Scaffold the example**

Run: `npm run create-example -- tweens "Tweens Example"` (from repo root). Read what this generates (`scripts/exampleTemplate`'s output) before editing further, to match its existing conventions (manifest, bsconfig, generated icon/splash, minimal `MainRoom`).

- [ ] **Step 2: Read an existing simple UI-using example first**

Run: `grep -rn "BGE.UI.Label\|addChild" examples/breakout/src/source/*.bs examples/breakout/src/source/**/*.bs 2>/dev/null | head -20` — find a real, working `Label` usage to copy the construction pattern from (constructor args, how it's added to `gameUi`, how its text is updated) rather than guessing the API.

- [ ] **Step 3: Build the room**

Replace the scaffolded `MainRoom` with a room that:
- Creates three small entities, each with one `DrawableRectangle` (or similar - keep it simple, reuse whatever primitive the scaffold's template entity already uses): one that will slide left-to-right (`position`), one that will pulse in/out (`scale`), one that will fade between two colors (via `toColorRGB` on its drawable's `color`).
- Adds a `BGE.UI.Label` (or two) to `m.game.gameUi` showing the currently selected `Easing` name and which of the three aspects is active.
- `onInput`: `up`/`down` cycles the selected `Easing` (index into the full 56-value list - build this list once, e.g. `[BGE.Tweens.Easing.LinearTween, BGE.Tweens.Easing.QuadraticEaseInOut, ...]`, a representative subset is fine here rather than all 56, since the point is demonstrating a handful of visibly distinct curves - pick ~8-10 that look meaningfully different, e.g. one from each family plus a couple of the more dramatic ones like `ElasticEaseOut`/`BounceEaseOut`/`OvershootEaseOut`), `left`/`right` cycles which of the three aspects is currently active (only that one entity re-triggers), `select` (OK) re-triggers the active aspect's tween using the currently selected easing (via `game.tweenManager.to(...)`/`toColorRGB(...)` with `owner` set to that entity).
- Update the `Label`'s text each time the selection changes.

- [ ] **Step 4: Build and validate**

Run: `npm run build` (engine), then from `examples/tweens`: `npm install && npm run build`.

- [ ] **Step 5: Verify on-device via rokubot**

Check `.claude/skills/rokubot-examples/SKILL.md` for the current sideload/launch/act/screenshot workflow rather than guessing the CLI invocation. Package (`npm run package` from `examples/tweens`, or `npm run build-examples` from the repo root), sideload, launch, and confirm: the on-screen label reflects the selected easing/aspect, `up`/`down` actually changes the selection (screenshot before/after), `select` visibly re-triggers the active tween (a screenshot mid-tween should show the entity somewhere between its start and end state, not just at either extreme). If anything doesn't behave as expected, debug it before considering this task done - don't just assert success without looking, per this repo's standing verification convention.

- [ ] **Step 6: Commit**

```bash
git add examples/tweens .vscode/tasks.json
git commit -m "Add examples/tweens: interactive TweenManager showcase

Verified on-device via rokubot - up/down cycles easing, left/right
cycles aspect (position/scale/color), select re-triggers.

Closes #79"
```

(Include `.vscode/tasks.json` only if `create-example` actually registered the example there - check `git status` before committing to see what the scaffold touched.)

---

### Task 8: Full quality gate and PR

**Files:** none (verification only)

- [ ] **Step 1: Run the full local gate**

Run: `npm run check`

- [ ] **Step 2: Validate every example still builds**

Run: `npm run check:all`

- [ ] **Step 3: Push and open the PR**

```bash
git push -u origin feature/tween-manager
gh pr create --repo markwpearce/brighterscript-game-engine \
  --title "Add TweenManager: game-driven tweens on arbitrary fields" \
  --body "Fixes #60. Closes #79. See specs/2026-07-31-tween-manager-design.md and specs/2026-07-31-tween-manager-plan.md for the full design/plan."
```

Fill in the PR body's summary/test-plan sections from what actually happened across Tasks 1-7 rather than copying this plan verbatim - in particular, note the resolution of the delay-timing and closure-capture open questions flagged in Tasks 3, since those were left for the implementer to resolve concretely rather than pre-decided here.
