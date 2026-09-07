# Platformer Reuse (issues #202-#205) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Promote four patterns duplicated/hand-rolled in `examples/platformer` (and, for one of them, `examples/parallax`/`examples/breakout`) into reusable engine features: a dt-driven countdown timer, an AABB-vs-tile collision resolver, a full-height parallax-layer builder, and a `BGE.UI` modal panel widget - then update the consuming examples to use them.

**Architecture:** Four independent additions under `src/source/`, each with its own Rooibos spec, added in dependency-safe order so no two tasks touch the same example file at the same time. Each engine addition is followed immediately by the example refactor(s) that consume it, so the branch stays bisectable and every task leaves the repo in a working state.

**Tech Stack:** BrighterScript, Rooibos (`rooibos-roku`) test suites, `brs-cli` headless test runner, `rokubot` for on-device verification of the example changes (Rooibos doesn't exercise example code - see CLAUDE.md).

**Spec:** GitHub issues [#202](https://github.com/markwpearce/brighterscript-game-engine/issues/202), [#203](https://github.com/markwpearce/brighterscript-game-engine/issues/203), [#204](https://github.com/markwpearce/brighterscript-game-engine/issues/204), [#205](https://github.com/markwpearce/brighterscript-game-engine/issues/205) - each issue's "Suggested direction"/"Where" sections are the spec this plan implements; read the issue itself for the full duplication evidence behind each task.

## Global Constraints

- Every new engine file must be reachable via explicit `import` from anything that uses it (source-scope ambient visibility is not enough for SceneGraph component scopes - see CLAUDE.md's "Conventions specific to this codebase").
- Public API surface gets JSDoc-style `'` doc comments (`@param`/`@return`) written for the *consumer*, not the maintainer - per CLAUDE.md.
- Never compare two custom-class instances (or two native `ifDraw2D` objects) with `=` - compare a scalar/id field instead.
- `assertEqual` is type-strict (Integer vs Float) - match the literal type the code under test actually produces, not just the field's declared type.
- One `@suite` class per `*.spec.bs` file (Rooibos v6 corrupts multi-suite files).
- `npm run validate` after every engine change; `npm run validate-examples` (or that example's own `npm run build`/`validate`) after every example change.
- Automated tests do not exercise example app code - each example-facing task's "test" step is a build/validate, with on-device verification consolidated into the last task (per CLAUDE.md, confirmed with the user's own `rokubot-examples` skill).
- Branch first (never edit on `main` directly); commit after each task.

---

## Task 1: `BGE.CountdownTimer` utility

**Files:**
- Create: `src/source/utils/CountdownTimer.bs`
- Test: `src/source/utils/CountdownTimer.spec.bs`

**Interfaces:**
- Produces: `BGE.CountdownTimer` with `start(seconds as float)`, `tick(dt as float)`, `isActive() as boolean`, `remaining() as float`, `stop()`.

- [ ] **Step 1: Write the failing test**

```brightscript
' src/source/utils/CountdownTimer.spec.bs
import "pkg:/source/utils/CountdownTimer.bs"

namespace Tests
  @suite("CountdownTimer")
  class CountdownTimerTest extends rooibos.BaseTestSuite

    @it("is not active before start() is called")
    sub _()
      timer = new BGE.CountdownTimer()
      m.assertFalse(timer.isActive())
      m.assertEqual(timer.remaining(), 0.0)
    end sub

    @it("is active immediately after start() and reports the remaining time")
    sub _()
      timer = new BGE.CountdownTimer()
      timer.start(0.5)
      m.assertTrue(timer.isActive())
      m.assertEqual(timer.remaining(), 0.5)
    end sub

    @it("counts down via tick() and becomes inactive at zero")
    sub _()
      timer = new BGE.CountdownTimer()
      timer.start(0.3)
      timer.tick(0.1)
      m.assertTrue(timer.isActive())
      m.assertEqual(timer.remaining(), 0.2)
      timer.tick(0.2)
      m.assertFalse(timer.isActive())
      m.assertEqual(timer.remaining(), 0.0)
    end sub

    @it("clamps at zero instead of going negative when ticked past expiry")
    sub _()
      timer = new BGE.CountdownTimer()
      timer.start(0.1)
      timer.tick(0.5)
      m.assertEqual(timer.remaining(), 0.0)
      m.assertFalse(timer.isActive())
    end sub

    @it("tick() is a no-op once already expired (no negative drift)")
    sub _()
      timer = new BGE.CountdownTimer()
      timer.start(0.1)
      timer.tick(0.5)
      timer.tick(1.0)
      m.assertEqual(timer.remaining(), 0.0)
    end sub

    @it("stop() ends the timer immediately")
    sub _()
      timer = new BGE.CountdownTimer()
      timer.start(1.0)
      timer.stop()
      m.assertFalse(timer.isActive())
      m.assertEqual(timer.remaining(), 0.0)
    end sub

    @it("start() can restart an already-running timer with a new duration")
    sub _()
      timer = new BGE.CountdownTimer()
      timer.start(1.0)
      timer.tick(0.9)
      timer.start(0.2)
      m.assertEqual(timer.remaining(), 0.2)
    end sub
  end class
end namespace
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm run build-tests && npm run test:ci`
Expected: FAIL - `BGE.CountdownTimer` does not exist yet (build error building the test suite).

- [ ] **Step 3: Write minimal implementation**

```brightscript
' src/source/utils/CountdownTimer.bs
namespace BGE

  ' A simple dt-driven countdown: start it with a duration, tick() it once per frame
  ' (typically from GameEntity.onUpdate()'s own dt), and check isActive() to see if time
  ' remains. Replaces a hand-rolled "duration constant + live timer field + manual
  ' decrement-and-clamp block" pattern - the same shape used for coyote time, jump/input
  ' buffering, invulnerability windows, hit-flash timers, cooldowns, etc.
  '
  ' This is not the same as BGE.GameTimer, which wraps a wall-clock roTimespan
  ' (mark()/totalMilliseconds()) for measuring real elapsed time - CountdownTimer is
  ' purely dt-driven and has no idea what real time it is.
  class CountdownTimer

    private secondsRemaining as float = 0.0

    sub new()
    end sub

    ' Starts (or restarts, from any state) the timer for the given duration, in seconds.
    '
    ' @param {float} seconds
    sub start(seconds as float)
      m.secondsRemaining = seconds
    end sub

    ' Advances the timer by dt seconds. Clamps at 0 - never goes negative, and is a
    ' no-op once already expired.
    '
    ' @param {float} dt
    sub tick(dt as float)
      if m.secondsRemaining > 0.0
        m.secondsRemaining -= dt
        if m.secondsRemaining < 0.0
          m.secondsRemaining = 0.0
        end if
      end if
    end sub

    ' Whether time remains on this timer.
    '
    ' @return {boolean}
    function isActive() as boolean
      return m.secondsRemaining > 0.0
    end function

    ' Seconds remaining (never negative).
    '
    ' @return {float}
    function remaining() as float
      return m.secondsRemaining
    end function

    ' Stops the timer immediately - isActive() becomes false right away.
    sub stop()
      m.secondsRemaining = 0.0
    end sub

  end class

end namespace
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npm run build-tests && npm run test:ci`
Expected: PASS - all 7 `CountdownTimer` specs green.

- [ ] **Step 5: Commit**

```bash
git add src/source/utils/CountdownTimer.bs src/source/utils/CountdownTimer.spec.bs
git commit -m "feat: add BGE.CountdownTimer, a dt-driven countdown utility"
```

---

## Task 2: Refactor `examples/platformer` Player.bs to use `BGE.CountdownTimer`

**Files:**
- Modify: `examples/platformer/src/source/Entities/Player.bs`

**Interfaces:**
- Consumes: `BGE.CountdownTimer` from Task 1 (`start`, `tick`, `isActive`, `remaining`, `stop`).

Replace the 5 duration-constant + timer-field + manual-decrement pairs with `BGE.CountdownTimer` fields. The duration constants (`coyoteTime`, `jumpBufferTime`, `directionBufferTime`, `invulnerableTime`, `slideAnimTime`) stay as-is (they're configuration, not timer state).

- [ ] **Step 1: Replace the timer fields**

In `examples/platformer/src/source/Entities/Player.bs`, replace:

```brightscript
  grounded = false
  invulnerableTimer = 0.0
  coyoteTimer = 0.0
  jumpBufferTimer = 0.0
  directionBufferTimer = 0.0
  bufferedDirectionX = 1.0
  jumpHeldLastFrame = false
```

with:

```brightscript
  grounded = false
  invulnerableTimer = new BGE.CountdownTimer()
  coyoteTimer = new BGE.CountdownTimer()
  jumpBufferTimer = new BGE.CountdownTimer()
  directionBufferTimer = new BGE.CountdownTimer()
  bufferedDirectionX = 1.0
  jumpHeldLastFrame = false
```

and replace:

```brightscript
  slideTimer = 0.0
  slideAnimTime = 5.0 / 16.0
```

with:

```brightscript
  slideTimer = new BGE.CountdownTimer()
  slideAnimTime = 5.0 / 16.0
```

- [ ] **Step 2: Update every read/write site in `onUpdate()`/`takeDamage()`/`respawn()`/`onCollision()`**

Replace each of the following (all in `onUpdate()` unless noted):

```brightscript
    if m.invulnerableTimer > 0.0
      m.invulnerableTimer = m.invulnerableTimer - clampedDt
    end if
```
→
```brightscript
    m.invulnerableTimer.tick(clampedDt)
```

```brightscript
      if m.invulnerableTimer <= 0.0
        m.isDead = false
        m.respawn()
        m.invulnerableTimer = m.invulnerableTime
      end if
```
→
```brightscript
      if not m.invulnerableTimer.isActive()
        m.isDead = false
        m.respawn()
        m.invulnerableTimer.start(m.invulnerableTime)
      end if
```

```brightscript
    if m.slideTimer > 0.0
      m.slideTimer = m.slideTimer - clampedDt
      m.sprite.playAnimation("slide")
```
→
```brightscript
    m.slideTimer.tick(clampedDt)
    if m.slideTimer.isActive()
      m.sprite.playAnimation("slide")
```

```brightscript
    if abs(m.moveIntentX) > 0.05
      if m.moveIntentX > 0
        m.bufferedDirectionX = 1.0
      else
        m.bufferedDirectionX = -1.0
      end if
      m.directionBufferTimer = m.directionBufferTime
    else
      m.directionBufferTimer = m.directionBufferTimer - clampedDt
      if m.directionBufferTimer < 0.0
        m.directionBufferTimer = 0.0
      end if
    end if
```
→
```brightscript
    if abs(m.moveIntentX) > 0.05
      if m.moveIntentX > 0
        m.bufferedDirectionX = 1.0
      else
        m.bufferedDirectionX = -1.0
      end if
      m.directionBufferTimer.start(m.directionBufferTime)
    else
      m.directionBufferTimer.tick(clampedDt)
    end if
```

```brightscript
    jumpedThisFrame = false
    if m.grounded
      m.coyoteTimer = m.coyoteTime
    else
      m.coyoteTimer = m.coyoteTimer - clampedDt
    end if
    if m.wantsJump
      m.jumpBufferTimer = m.jumpBufferTime
    else
      m.jumpBufferTimer = m.jumpBufferTimer - clampedDt
    end if
    if m.jumpBufferTimer > 0.0 and m.coyoteTimer > 0.0
```
→
```brightscript
    jumpedThisFrame = false
    if m.grounded
      m.coyoteTimer.start(m.coyoteTime)
    else
      m.coyoteTimer.tick(clampedDt)
    end if
    if m.wantsJump
      m.jumpBufferTimer.start(m.jumpBufferTime)
    else
      m.jumpBufferTimer.tick(clampedDt)
    end if
    if m.jumpBufferTimer.isActive() and m.coyoteTimer.isActive()
```

```brightscript
      if abs(m.moveIntentX) <= 0.05 and m.directionBufferTimer > 0.0
        m.velocity.x = m.bufferedDirectionX * m.runSpeed
      end if
      m.grounded = false
      m.coyoteTimer = 0.0
      m.jumpBufferTimer = 0.0
      jumpedThisFrame = true
```
→
```brightscript
      if abs(m.moveIntentX) <= 0.05 and m.directionBufferTimer.isActive()
        m.velocity.x = m.bufferedDirectionX * m.runSpeed
      end if
      m.grounded = false
      m.coyoteTimer.stop()
      m.jumpBufferTimer.stop()
      jumpedThisFrame = true
```

```brightscript
    if m.position.y < m.fallDeathY and m.invulnerableTimer <= 0.0
      m.takeDamage()
    end if
```
→
```brightscript
    if m.position.y < m.fallDeathY and not m.invulnerableTimer.isActive()
      m.takeDamage()
    end if
```

In `respawn()`:

```brightscript
    m.grounded = false
    m.slideTimer = 0.0
```
→
```brightscript
    m.grounded = false
    m.slideTimer.stop()
```

In `takeDamage()`:

```brightscript
  sub takeDamage()
    m.invulnerableTimer = m.invulnerableTime
```
→
```brightscript
  sub takeDamage()
    m.invulnerableTimer.start(m.invulnerableTime)
```

In `onCollision()` (both the Enemy branch and the Level/`landedOnTop` branch):

```brightscript
      else if m.invulnerableTimer <= 0.0
        m.takeDamage()
```
→
```brightscript
      else if not m.invulnerableTimer.isActive()
        m.takeDamage()
```

```brightscript
        m.dust.burst(8)
        m.slideTimer = m.slideAnimTime
```
→
```brightscript
        m.dust.burst(8)
        m.slideTimer.start(m.slideAnimTime)
```

- [ ] **Step 3: Build the example and confirm no compile/type errors**

Run: `cd examples/platformer && npm run build`
Expected: build succeeds (BrighterScript's type checker will flag any remaining `m.xTimer > 0.0`/`m.xTimer = ...` sites that still treat a `CountdownTimer` as a `float` - fix any it finds; there should be none left after Step 2).

- [ ] **Step 4: Commit**

```bash
git add examples/platformer/src/source/Entities/Player.bs
git commit -m "examples/platformer: use BGE.CountdownTimer for Player's 5 hand-rolled timers"
```

---

## Task 3: `BGE.resolveAabbTileCollision` helper

**Files:**
- Create: `src/source/engine/colliders/TileCollision.bs`
- Test: `src/source/engine/colliders/TileCollision.spec.bs`

**Interfaces:**
- Consumes: `BGE.RectangleCollider` (`offset`, `width`, `height` fields - constructible without a real `Game`/compositor, since this helper only reads those three fields).
- Produces: `BGE.TileCollisionSide` enum (`none`/`top`/`bottom`/`left`/`right`), `BGE.TileCollisionResult` class (`position`, `velocity`, `side`), and `BGE.resolveAabbTileCollision(positionBefore, width, height, velocity, tileCollider, isOneWay = false, tolerancePx = 1.0) as BGE.TileCollisionResult`.

- [ ] **Step 1: Write the failing test**

```brightscript
' src/source/engine/colliders/TileCollision.spec.bs
import "pkg:/source/engine/colliders/TileCollision.bs"
import "pkg:/source/engine/colliders/RectangleCollider.bs"
import "pkg:/source/math/vector.bs"

namespace Tests
  @suite("resolveAabbTileCollision")
  class TileCollisionTest extends rooibos.BaseTestSuite

    private function makeTile(width as float, height as float, offsetX as float, offsetY as float) as BGE.RectangleCollider
      return new BGE.RectangleCollider("tile", {width: width, height: height, offset: BGE.Math.VectorOps.create(offsetX, offsetY)})
    end function

    @it("lands on top of a solid tile: snaps to tileTop, zeroes vertical velocity, side = top")
    sub _()
      tile = m.makeTile(64.0, 64.0, 0.0, 64.0) ' top edge at world y = 64
      positionBefore = BGE.Math.VectorOps.create(32.0, 63.5) ' feet within the 1px tolerance of tileTop
      velocity = BGE.Math.VectorOps.create(0.0, -200.0)
      result = BGE.resolveAabbTileCollision(positionBefore, 56.0, 72.0, velocity, tile)
      m.assertEqual(result.side, BGE.TileCollisionSide.top)
      m.assertEqual(result.position.y, 64.0)
      m.assertEqual(result.velocity.y, 0.0)
    end sub

    @it("does not land on top while still rising (velocity.y > 0)")
    sub _()
      tile = m.makeTile(64.0, 64.0, 0.0, 64.0)
      positionBefore = BGE.Math.VectorOps.create(32.0, 60.0)
      velocity = BGE.Math.VectorOps.create(0.0, 200.0)
      result = BGE.resolveAabbTileCollision(positionBefore, 56.0, 72.0, velocity, tile)
      m.assertEqual(result.side, BGE.TileCollisionSide.none)
    end sub

    @it("a one-way tile blocks a from-above landing exactly like a solid tile")
    sub _()
      tile = m.makeTile(64.0, 64.0, 0.0, 64.0)
      positionBefore = BGE.Math.VectorOps.create(32.0, 63.5) ' within the 1px tolerance of tileTop
      velocity = BGE.Math.VectorOps.create(0.0, -200.0)
      result = BGE.resolveAabbTileCollision(positionBefore, 56.0, 72.0, velocity, tile, true)
      m.assertEqual(result.side, BGE.TileCollisionSide.top)
      m.assertEqual(result.position.y, 64.0)
    end sub

    @it("a one-way tile does not block rising into it from below or a side hit")
    sub _()
      tile = m.makeTile(64.0, 64.0, 0.0, 64.0)
      ' Rising into the tile from below - not a landing.
      positionBefore = BGE.Math.VectorOps.create(32.0, 0.0)
      velocity = BGE.Math.VectorOps.create(0.0, 200.0)
      result = BGE.resolveAabbTileCollision(positionBefore, 56.0, 72.0, velocity, tile, true)
      m.assertEqual(result.side, BGE.TileCollisionSide.none)
    end sub

    @it("hits its head on the underside of a solid tile: snaps below tileBottom, zeroes vertical velocity, side = bottom")
    sub _()
      tile = m.makeTile(64.0, 64.0, 0.0, 128.0) ' tileBottom at world y = 64
      positionBefore = BGE.Math.VectorOps.create(32.0, -9.0) ' head (-9 + 72 = 63) within the 1px tolerance of tileBottom
      velocity = BGE.Math.VectorOps.create(0.0, 200.0)
      result = BGE.resolveAabbTileCollision(positionBefore, 56.0, 72.0, velocity, tile)
      m.assertEqual(result.side, BGE.TileCollisionSide.bottom)
      m.assertEqual(result.position.y, -8.0) ' tileBottom (64) - height (72)
      m.assertEqual(result.velocity.y, 0.0)
    end sub

    @it("is pushed out the left side when approaching from the left: side = left")
    sub _()
      tile = m.makeTile(64.0, 64.0, 100.0, 64.0) ' tileLeft = 100, tileRight = 164
      positionBefore = BGE.Math.VectorOps.create(70.0, 10.0) ' rightBefore = 70 + 28 = 98 <= 100 + 1
      velocity = BGE.Math.VectorOps.create(150.0, 0.0)
      result = BGE.resolveAabbTileCollision(positionBefore, 56.0, 72.0, velocity, tile)
      m.assertEqual(result.side, BGE.TileCollisionSide.left)
      m.assertEqual(result.position.x, 72.0) ' tileLeft (100) - width/2 (28)
      m.assertEqual(result.velocity.x, 0.0)
    end sub

    @it("is pushed out the right side when approaching from the right: side = right")
    sub _()
      tile = m.makeTile(64.0, 64.0, 100.0, 64.0) ' tileLeft = 100, tileRight = 164
      positionBefore = BGE.Math.VectorOps.create(195.0, 10.0) ' leftBefore = 195 - 28 = 167 >= 164 - 1
      velocity = BGE.Math.VectorOps.create(-150.0, 0.0)
      result = BGE.resolveAabbTileCollision(positionBefore, 56.0, 72.0, velocity, tile)
      m.assertEqual(result.side, BGE.TileCollisionSide.right)
      m.assertEqual(result.position.x, 192.0) ' tileRight (164) + width/2 (28)
      m.assertEqual(result.velocity.x, 0.0)
    end sub

    @it("reports side = none and leaves position/velocity unchanged when rising past a one-way tile with no landing")
    sub _()
      ' Covered by the "one-way tile does not block rising" test above too - this one
      ' additionally asserts position/velocity pass through completely unchanged.
      tile = m.makeTile(64.0, 64.0, 0.0, 64.0)
      positionBefore = BGE.Math.VectorOps.create(32.0, 10.0)
      velocity = BGE.Math.VectorOps.create(150.0, 200.0)
      result = BGE.resolveAabbTileCollision(positionBefore, 56.0, 72.0, velocity, tile, true)
      m.assertEqual(result.side, BGE.TileCollisionSide.none)
      m.assertEqual(result.position.x, 32.0)
      m.assertEqual(result.position.y, 10.0)
      m.assertEqual(result.velocity.x, 150.0)
      m.assertEqual(result.velocity.y, 200.0)
    end sub
  end class
end namespace
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm run build-tests && npm run test:ci`
Expected: FAIL - `BGE.resolveAabbTileCollision`/`BGE.TileCollisionResult`/`BGE.TileCollisionSide` don't exist yet.

- [ ] **Step 3: Write minimal implementation**

```brightscript
' src/source/engine/colliders/TileCollision.bs
import "../../math/vector.bs"
import "RectangleCollider.bs"

namespace BGE

  ' Which side of the tile (if any) resolveAabbTileCollision() resolved a collision
  ' against. "none" means the tile didn't block the entity at all this frame (e.g.
  ' rising through a one-way platform, or no overlap).
  enum TileCollisionSide
    none = "none"
    top = "top"
    bottom = "bottom"
    left = "left"
    right = "right"
  end enum

  ' The result of resolveAabbTileCollision(): the corrected position/velocity to apply
  ' this frame, and which side of the tile (if any) was resolved.
  class TileCollisionResult
    position as BGE.Math.Vector
    velocity as BGE.Math.Vector
    side as string

    sub new(position as BGE.Math.Vector, velocity as BGE.Math.Vector, side as string)
      m.position = position
      m.velocity = velocity
      m.side = side
    end sub
  end class

  ' Resolves an entity's axis-aligned hitbox against one static rectangular tile
  ' collider, using the entity's pre-move position to determine which side it
  ' approached from - the generic "solid tile world" resolution algorithm (landing on
  ' top, one-way-platform pass-through, head bumps, side pushes) needed by a tile-based
  ' platformer or top-down game's GameEntity.onCollision(). It does not replace
  ' BGE.Collider/CheckMultipleCollisions() for entity-vs-entity collision - use it only
  ' for collisions against static tile geometry.
  '
  ' The entity's own hitbox is assumed feet-anchored, matching
  ' GameEntity.addRectangleCollider()'s own convention: `positionBefore` is the bottom-
  ' center point (x = horizontal center, y = bottom edge), so the hitbox spans
  ' `positionBefore.x -+ width/2` horizontally and `positionBefore.y` to
  ' `positionBefore.y + height` vertically.
  '
  ' Precondition: only call this when the entity's *current* (post-move) position is
  ' already known to overlap this tile - e.g. from inside onCollision(), which only
  ' fires on a genuine overlap. This function is only given the entity's pre-move
  ' position/velocity (not its current position), so it has no independent way to
  ' verify an overlap actually exists; called with a position/tile pair that was never
  ' actually approaching/touching, its returned side is not meaningful (this mirrors the
  ' exact same precondition the hand-rolled onCollision() logic it replaces already had,
  ' implicitly, by virtue of only ever running inside onCollision()).
  '
  ' @param {BGE.Math.Vector} positionBefore - the entity's position as of the start of
  '   this frame, before this frame's own movement was applied (capture it at the top of
  '   onUpdate(), before integrating velocity) - used to tell which side of the tile the
  '   entity approached from.
  ' @param {float} width - the entity's hitbox width (matching the width passed to
  '   addRectangleCollider())
  ' @param {float} height - the entity's hitbox height
  ' @param {BGE.Math.Vector} velocity - the entity's current velocity (only .y's sign
  '   matters for landing/head-bump detection)
  ' @param {BGE.RectangleCollider} tileCollider - the tile's own collider (the
  '   otherCollider passed to onCollision())
  ' @param [isOneWay=false] - true if this tile only blocks a from-above landing and
  '   passes through from below/the sides (e.g. a one-way platform)
  ' @param [tolerancePx=1.0] - how many pixels of overlap/gap still count as "touching"
  '   a side, absorbing floating-point/frame-step slack
  ' @return {BGE.TileCollisionResult}
  function resolveAabbTileCollision(positionBefore as BGE.Math.Vector, width as float, height as float, velocity as BGE.Math.Vector, tileCollider as BGE.RectangleCollider, isOneWay = false as boolean, tolerancePx = 1.0 as float) as BGE.TileCollisionResult
    tileTop = tileCollider.offset.y
    tileBottom = tileCollider.offset.y - tileCollider.height
    tileLeft = tileCollider.offset.x
    tileRight = tileCollider.offset.x + tileCollider.width

    bottomBefore = positionBefore.y
    topBefore = positionBefore.y + height
    leftBefore = positionBefore.x - width / 2.0
    rightBefore = positionBefore.x + width / 2.0

    resultPosition = BGE.Math.VectorOps.create(positionBefore.x, positionBefore.y)
    resultVelocity = BGE.Math.VectorOps.create(velocity.x, velocity.y)

    if velocity.y <= 0.0 and bottomBefore >= tileTop - tolerancePx
      resultPosition.y = tileTop
      resultVelocity.y = 0.0
      return new BGE.TileCollisionResult(resultPosition, resultVelocity, BGE.TileCollisionSide.top)
    end if

    if isOneWay
      return new BGE.TileCollisionResult(resultPosition, resultVelocity, BGE.TileCollisionSide.none)
    end if

    if velocity.y > 0.0 and topBefore <= tileBottom + tolerancePx
      resultPosition.y = tileBottom - height
      resultVelocity.y = 0.0
      return new BGE.TileCollisionResult(resultPosition, resultVelocity, BGE.TileCollisionSide.bottom)
    end if

    if rightBefore <= tileLeft + tolerancePx
      resultPosition.x = tileLeft - width / 2.0
      resultVelocity.x = 0.0
      return new BGE.TileCollisionResult(resultPosition, resultVelocity, BGE.TileCollisionSide.left)
    else if leftBefore >= tileRight - tolerancePx
      resultPosition.x = tileRight + width / 2.0
      resultVelocity.x = 0.0
      return new BGE.TileCollisionResult(resultPosition, resultVelocity, BGE.TileCollisionSide.right)
    end if

    return new BGE.TileCollisionResult(resultPosition, resultVelocity, BGE.TileCollisionSide.none)
  end function

end namespace
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npm run build-tests && npm run test:ci`
Expected: PASS - all 8 `resolveAabbTileCollision` specs green.

- [ ] **Step 5: Run full engine validation**

Run: `npm run validate`
Expected: no new type errors.

- [ ] **Step 6: Commit**

```bash
git add src/source/engine/colliders/TileCollision.bs src/source/engine/colliders/TileCollision.spec.bs
git commit -m "feat: add BGE.resolveAabbTileCollision, a generic AABB-vs-tile resolver"
```

---

## Task 4: Refactor `examples/platformer` Player.bs's Level collision branch

**Files:**
- Modify: `examples/platformer/src/source/Entities/Player.bs`

**Interfaces:**
- Consumes: `BGE.resolveAabbTileCollision`, `BGE.TileCollisionSide`, `BGE.TileCollisionResult` from Task 3.

- [ ] **Step 1: Add the import**

At the top of `examples/platformer/src/source/Entities/Player.bs`, add:

```brightscript
import "../../../../../src/source/engine/colliders/TileCollision.bs"
```

Check the actual relative import convention this example already uses for engine files first (this example consumes the engine via ropm, not a relative path into `src/`) - **do not use a relative path into the engine repo's own `src/`**. Since `BGE`-namespaced engine symbols are ambient/ropm-provided in every example already (see e.g. `BGE.RectangleCollider` used directly in this same file with no import), no import is actually needed here - BrighterScript's ropm-consumed engine scope already exposes `BGE.resolveAabbTileCollision`/`BGE.TileCollisionSide` the same way it exposes every other `BGE.*` symbol this file already uses without an explicit import. Confirm by building (Step 3 below); add no import line.

- [ ] **Step 2: Replace the Level branch of `onCollision()`**

Replace:

```brightscript
    if otherEntity.name <> "Level"
      return
    end if

    ' otherCollider is always a RectangleCollider here (Level only builds
    ' rectangle tile colliders), but onCollision's signature is typed to the
    ' base BGE.Collider, which has no width/height - cast to reach them.
    tileCollider = otherCollider as BGE.RectangleCollider
    tileTop = tileCollider.offset.y
    tileBottom = tileCollider.offset.y - tileCollider.height
    tileLeft = tileCollider.offset.x
    tileRight = tileCollider.offset.x + tileCollider.width
    isOneWay = otherCollider.tagsList.hasTag("oneWay")

    ' Player.position is feet-anchored (matches the sprite's bottom-center
    ' pretranslate and the "body" collider's offset_y = m.height, i.e. its
    ' top edge sits one height above position) - so position.y IS the foot
    ' position, and the head is m.height above it, not the other way round.
    playerBottomBefore = m.positionBeforeMove.y
    playerTopBefore = m.positionBeforeMove.y + m.height
    playerLeftBefore = m.positionBeforeMove.x - m.width / 2.0
    playerRightBefore = m.positionBeforeMove.x + m.width / 2.0

    landedOnTop = m.velocity.y <= 0.0 and playerBottomBefore >= tileTop - 1.0
    if landedOnTop
      impactSpeed = -m.velocity.y
      m.position.y = tileTop
      m.velocity.y = 0.0
      m.grounded = true
      if impactSpeed > 300.0
        m.game.tweenManager.to(m.scale, {x: 1.3, y: 0.7}, 60, BGE.Tweens.Easing.QuadraticEaseOut)
        m.game.tweenManager.to(m.scale, {x: 1.0, y: 1.0}, 180, BGE.Tweens.Easing.QuadraticEaseOut, {delay: 60})
        m.dust.burst(8)
        m.slideTimer.start(m.slideAnimTime)
      end if
      return
    end if

    if isOneWay
      ' One-way platforms only ever block a landing-from-above - every
      ' other case (rising into it, approaching from a side) passes through.
      return
    end if

    hitHead = m.velocity.y > 0.0 and playerTopBefore <= tileBottom + 1.0
    if hitHead
      m.position.y = tileBottom - m.height
      m.velocity.y = 0.0
      return
    end if

    ' Horizontal: push out the side the player was already outside of.
    if playerRightBefore <= tileLeft + 1.0
      m.position.x = tileLeft - m.width / 2.0
      m.velocity.x = 0.0
    else if playerLeftBefore >= tileRight - 1.0
      m.position.x = tileRight + m.width / 2.0
      m.velocity.x = 0.0
    end if
  end sub
```

with:

```brightscript
    if otherEntity.name <> "Level"
      return
    end if

    ' otherCollider is always a RectangleCollider here (Level only builds
    ' rectangle tile colliders), but onCollision's signature is typed to the
    ' base BGE.Collider, which has no width/height - cast to reach them.
    tileCollider = otherCollider as BGE.RectangleCollider
    isOneWay = otherCollider.tagsList.hasTag("oneWay")
    impactSpeed = -m.velocity.y

    result = BGE.resolveAabbTileCollision(m.positionBeforeMove, m.width, m.height, m.velocity, tileCollider, isOneWay)
    m.position.x = result.position.x
    m.position.y = result.position.y
    m.velocity.x = result.velocity.x
    m.velocity.y = result.velocity.y

    if result.side = BGE.TileCollisionSide.top
      m.grounded = true
      if impactSpeed > 300.0
        m.game.tweenManager.to(m.scale, {x: 1.3, y: 0.7}, 60, BGE.Tweens.Easing.QuadraticEaseOut)
        m.game.tweenManager.to(m.scale, {x: 1.0, y: 1.0}, 180, BGE.Tweens.Easing.QuadraticEaseOut, {delay: 60})
        m.dust.burst(8)
        m.slideTimer.start(m.slideAnimTime)
      end if
    end if
  end sub
```

Note: `resolveAabbTileCollision` always returns a full position/velocity (unchanged when `side = none`), so the unconditional assignment above is safe even when nothing was actually resolved.

- [ ] **Step 3: Build the example**

Run: `cd examples/platformer && npm run build`
Expected: build succeeds with no import needed for `BGE.resolveAabbTileCollision`/`BGE.TileCollisionSide` (confirms Step 1's reasoning); if it fails with a "cannot find name" diagnostic instead, add `import "pkg:/source/roku_modules/bge/colliders/TileCollision.brs"`-equivalent per how this example's `bsconfig.json` resolves the `bge` ropm module, matching how it already imports any other `BGE.*` file it needs explicitly.

- [ ] **Step 4: Commit**

```bash
git add examples/platformer/src/source/Entities/Player.bs
git commit -m "examples/platformer: use BGE.resolveAabbTileCollision for tile collision resolution"
```

---

## Task 5: `BGE.newFullHeightParallaxLayer` helper

**Files:**
- Modify: `src/source/engine/drawables/DrawableParallaxLayer.bs`
- Test: `src/source/engine/drawables/DrawableParallaxLayer.spec.bs` (create if it doesn't already exist - check first)

**Interfaces:**
- Produces: `BGE.newFullHeightParallaxLayer(owner as BGE.GameEntity, region as roRegion, canvasWidth as float, canvasHeight as float, factor as float, targetX = 0.0 as float, targetY = 0.0 as float, zOffset = 0.0 as float) as BGE.DrawableParallaxLayer`.

**Scope note (flagging a real divergence, not force-fitting one abstraction):** `examples/platformer`'s `newBackgroundLayer()` and `examples/parallax`'s `newLayer()` solve the same *shape* of problem (pre-divide a target canvas offset by `parallaxFactor` to compensate for `computeEffectiveWorldPosition()`'s reference-position capture) but with genuinely different derivations - platformer assumes a single owner sitting at world origin under a camera whose Y target is fixed and only X moves; parallax's owner sits *at* the camera's own moving target, uses a different `factorY` than `factorX` (0.2x, for an extra depth cue), and anchors to a canvas corner rather than an arbitrary per-layer `targetX`. Coercing both into one call without re-deriving parallax's case from scratch risks a subtly wrong sign in a part of the codebase that has already needed several hard-won on-device fixes for exactly this kind of math (see the `SceneObjectPlane`/camera-roll bullets in CLAUDE.md). This task extracts the helper as an exact, faithful copy of platformer's own (more general - it supports staggering multiple layers via `targetX`) derivation, and **only** platformer is refactored onto it (Task 6). `examples/parallax` is left as-is; do not attempt to unify it in this task.

- [ ] **Step 1: Check for an existing spec file**

Run: `ls src/source/engine/drawables/DrawableParallaxLayer.spec.bs 2>/dev/null || echo "none"`

- [ ] **Step 2: Write the failing test**

If no spec file exists, create one; if one exists, add a new `@it` inside its existing `@suite` class instead of creating a second suite class (one `@suite` per file - see Global Constraints).

```brightscript
' src/source/engine/drawables/DrawableParallaxLayer.spec.bs (new file, if none existed)
import "pkg:/source/engine/drawables/DrawableParallaxLayer.bs"
import "pkg:/source/engine/Game.bs"
import "pkg:/source/engine/GameEntity.bs"

namespace Tests
  @suite("DrawableParallaxLayer")
  class DrawableParallaxLayerTest extends rooibos.BaseTestSuite

    private game as BGE.Game
    private owner as BGE.GameEntity

    override function beforeEach()
      m.game = new BGE.Game(320, 240)
      m.owner = new BGE.GameEntity(m.game, {name: "Owner"})
    end function

    @it("newFullHeightParallaxLayer scales the layer to fill canvas height")
    sub _()
      bmp = m.game.getEmptyBitmap()
      region = CreateObject("roRegion", bmp, 0, 0, 32, 32)
      layer = BGE.newFullHeightParallaxLayer(m.owner, region, 320.0, 240.0, 0.1, 0.0, 0.0)
      m.assertEqual(layer.scale.y, 240.0 / 32.0)
      m.assertEqual(layer.parallaxFactor.x, 0.1)
      m.assertEqual(layer.parallaxFactor.y, 0.1)
      m.assertTrue(layer.repeatX)
      m.assertTrue(layer.repeatY)
    end sub

    @it("newFullHeightParallaxLayer's offset lands the layer's seam at targetX when the camera sits at canvas center")
    sub _()
      bmp = m.game.getEmptyBitmap()
      region = CreateObject("roRegion", bmp, 0, 0, 32, 32)
      factor = 0.2
      canvasWidth = 320.0
      layer = BGE.newFullHeightParallaxLayer(m.owner, region, canvasWidth, 240.0, factor, 80.0, 0.0)
      halfCanvasWidth = canvasWidth / 2.0
      expectedOffsetX = halfCanvasWidth + (80.0 - halfCanvasWidth) / factor
      m.assertEqual(layer.offset.x, expectedOffsetX)
    end sub
  end class
end namespace
```

- [ ] **Step 3: Run test to verify it fails**

Run: `npm run build-tests && npm run test:ci`
Expected: FAIL - `BGE.newFullHeightParallaxLayer` doesn't exist yet.

- [ ] **Step 4: Write minimal implementation**

Add to the end of `src/source/engine/drawables/DrawableParallaxLayer.bs`, inside the existing `namespace BGE` block (after the `DrawableParallaxLayer` class, still inside the same `namespace ... end namespace`):

```brightscript
  ' Builds a DrawableParallaxLayer scaled to fill the canvas vertically edge-to-edge
  ' and tiled to cover it on both axes, with its tile-repeat seam anchored at a chosen
  ' canvas position (targetX, targetY) rather than wherever computeEffectiveWorldPosition()'s
  ' own reference-position capture would otherwise put it - see that method's own
  ' derivation comment, and examples/platformer's MainRoom for a worked application
  ' (including staggering several stacked layers' seams via different targetX values so
  ' they don't all reinforce into one obvious seam).
  '
  ' This assumes `owner` sits at world (0,0,0) and the camera's target on the axis
  ' orthogonal to `factor`'s own drift direction stays fixed for the object's lifetime
  ' (e.g. a side-scroller with a Y-locked camera) - it is not a general-purpose "anchor
  ' anywhere under any camera motion" solution. See examples/parallax's own hand-rolled
  ' `newLayer()` for a different derivation (owner co-located with a moving camera
  ' target, non-uniform per-axis factor) that this helper does not cover.
  '
  ' @param {BGE.GameEntity} owner - the entity this layer attaches to; must sit at world (0,0,0)
  ' @param {roRegion} region - the bitmap tile to scroll/repeat
  ' @param {float} canvasWidth
  ' @param {float} canvasHeight
  ' @param {float} factor - parallaxFactor applied uniformly to both axes
  ' @param [targetX=0.0] - on-canvas X the tile seam lands at while the camera sits at
  '   canvasWidth/2 (its assumed rest position on this axis)
  ' @param [targetY=0.0] - on-canvas Y the tile seam lands at, given the camera's fixed Y
  '   target (canvasHeight/2 is the common "camera always centers vertically" case)
  ' @param [zOffset=0.0] - Z offset for this layer, useful for stacking several layers'
  '   draw order via BGE.DrawableParallaxLayer's normal Z-based sort
  ' @return {BGE.DrawableParallaxLayer}
  function newFullHeightParallaxLayer(owner as BGE.GameEntity, region as roRegion, canvasWidth as float, canvasHeight as float, factor as float, targetX = 0.0 as float, targetY = 0.0 as float, zOffset = 0.0 as float) as BGE.DrawableParallaxLayer
    layerScale = canvasHeight / region.GetHeight()
    halfCanvasWidth = canvasWidth / 2.0
    halfCanvasHeight = canvasHeight / 2.0
    offsetX = halfCanvasWidth + (targetX - halfCanvasWidth) / factor
    offsetY = halfCanvasHeight + (halfCanvasHeight - targetY) / factor

    return new BGE.DrawableParallaxLayer(owner, region, {
      offset: BGE.Math.VectorOps.create(offsetX, offsetY, zOffset),
      parallaxFactor: BGE.Math.VectorOps.create(factor, factor),
      repeatX: true,
      repeatY: true,
      scale: BGE.Math.createScaleVector(layerScale)
    })
  end function
```

Note the `offsetY` formula generalizes platformer's original (which only ever passed `targetY = 0`, i.e. the canvas top edge): its original `offsetY = halfCanvasHeight * (1 + 1/factor)` is exactly this formula's `targetY = 0` case (`halfCanvasHeight + (halfCanvasHeight - 0)/factor`) - confirm this algebraically before moving on, since a sign error here would silently shift every tiled layer's vertical seam on-canvas.

- [ ] **Step 5: Run test to verify it passes**

Run: `npm run build-tests && npm run test:ci`
Expected: PASS.

- [ ] **Step 6: Run full engine validation**

Run: `npm run validate`

- [ ] **Step 7: Commit**

```bash
git add src/source/engine/drawables/DrawableParallaxLayer.bs src/source/engine/drawables/DrawableParallaxLayer.spec.bs
git commit -m "feat: add BGE.newFullHeightParallaxLayer helper"
```

---

## Task 6: Refactor `examples/platformer` MainRoom to use `newFullHeightParallaxLayer`

**Files:**
- Modify: `examples/platformer/src/source/Rooms/MainRoom.bs`

**Interfaces:**
- Consumes: `BGE.newFullHeightParallaxLayer` from Task 5.

- [ ] **Step 1: Replace `newBackgroundLayer()`**

Replace the entire `private function newBackgroundLayer(...)` method body in `examples/platformer/src/source/Rooms/MainRoom.bs` with a thin wrapper over the new engine helper:

```brightscript
  ' Builds one repeating, canvas-height-filling background layer from an already-loaded
  ' bitmap, via BGE.newFullHeightParallaxLayer - see that function's doc comment for the
  ' targetX/offset derivation this wraps. Callers pass a different targetX per layer so
  ' the three layers' seams land at different on-canvas spots instead of all landing near
  ' the same one (see onCreate()'s comment above on why that matters).
  private function newBackgroundLayer(bitmapName as string, factor as float, targetX as float) as BGE.DrawableParallaxLayer
    bmp = m.game.getBitmap(bitmapName)
    region = CreateObject("roRegion", bmp, 0, 0, bmp.GetWidth(), bmp.GetHeight())
    return BGE.newFullHeightParallaxLayer(m, region, m.game.canvas.getWidth(), m.game.canvas.getHeight(), factor, targetX, 0.0)
  end function
```

This drops the two locally-derived `halfCanvasWidth`/`halfCanvasHeight`/`offsetX`/`offsetY` blocks entirely - the engine helper now owns that derivation. The three call sites in `onCreate()` (`m.newBackgroundLayer("bgBack", 0.02, 0)`, etc.) are unchanged.

- [ ] **Step 2: Build the example**

Run: `cd examples/platformer && npm run build`
Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
git add examples/platformer/src/source/Rooms/MainRoom.bs
git commit -m "examples/platformer: use BGE.newFullHeightParallaxLayer for background layers"
```

---

## Task 7: `BGE.UI.MessagePanel` widget

**Files:**
- Create: `src/source/engine/ui/MessagePanel.bs`
- Test: `src/source/engine/ui/MessagePanel.spec.bs`

**Interfaces:**
- Consumes: `BGE.UI.UiContainer`, `BGE.UI.Label`, `BGE.UI.Button`, `BGE.UI.Theme`, `BGE.Game.getFont`, `BGE.Math.Max`.
- Produces: `BGE.UI.MessagePanelButton` (`label`, `onActivate`), `BGE.UI.MessagePanel extends BGE.UI.UiContainer` with constructor `new(game, panelWidth, panelHeight, buttons, title = "", message = "")`, `show(parent, withinWidth, withinHeight)`, `hide(parent)`, `setMessage(message)`.

- [ ] **Step 1: Write the failing test**

```brightscript
' src/source/engine/ui/MessagePanel.spec.bs
import "pkg:/source/engine/ui/MessagePanel.bs"
import "pkg:/source/engine/ui/UiContainer.bs"
import "pkg:/source/engine/Game.bs"

namespace Tests
  @suite("MessagePanel")
  class MessagePanelTest extends rooibos.BaseTestSuite

    private game as BGE.Game
    private parent as BGE.UI.UiContainer

    override function beforeEach()
      m.game = new BGE.Game(320, 240)
      m.parent = new BGE.UI.UiContainer(m.game)
    end function

    @it("show() adds itself, with the requested title, message, and button labels, to the parent")
    sub _()
      resumeCalled = false
      buttons = [new BGE.UI.MessagePanelButton("Resume", sub(button as BGE.UI.Button)
      end sub)]
      panel = new BGE.UI.MessagePanel(m.game, 200.0, 100.0, buttons, "Paused")
      panel.show(m.parent, 320.0, 240.0)
      m.assertEqual(m.parent.childCount(), 1)
    end sub

    @it("hide() removes itself (and its buttons) from the parent entirely")
    sub _()
      buttons = [new BGE.UI.MessagePanelButton("Resume", invalid)]
      panel = new BGE.UI.MessagePanel(m.game, 200.0, 100.0, buttons, "Paused")
      panel.show(m.parent, 320.0, 240.0)
      panel.hide(m.parent)
      m.assertEqual(m.parent.childCount(), 0)
    end sub

    @it("a button's onActivate fires when clicked")
    sub _()
      activated = false
      onActivate = sub(button as BGE.UI.Button)
        m.activated = true
      end sub
      buttons = [new BGE.UI.MessagePanelButton("Resume", onActivate)]
      panel = new BGE.UI.MessagePanel(m.game, 200.0, 100.0, buttons, "Paused")
      panel.show(m.parent, 320.0, 240.0)
      ' Exercise via the same onClick() entry point Button itself uses.
      button = panel.buttonWidgets[0]
      button.onClick()
      m.assertTrue(m.activated)
    end sub

    @it("centers itself within the given bounds")
    sub _()
      buttons = [new BGE.UI.MessagePanelButton("Resume", invalid)]
      panel = new BGE.UI.MessagePanel(m.game, 200.0, 100.0, buttons)
      panel.show(m.parent, 320.0, 240.0)
      m.assertEqual(panel.customX, (320.0 - 200.0) / 2.0)
      m.assertEqual(panel.customY, (240.0 - 100.0) / 2.0)
    end sub
  end class
end namespace
```

Note: the third test closes over `m` inside the `onActivate` sub literal to flip `m.activated` - this mirrors the existing `Button.onActivate` convention used throughout `examples/platformer` (`button.onActivate = sub(button as BGE.UI.Button) ... end sub`), which likewise closes over outer `m`/locals. If Rooibos's own `m` inside a nested anonymous sub doesn't refer to the test instance here, use a module-level/private field on the test class instead (`m.activated` is already such a field via the suite instance - confirm this compiles and actually flips during Step 2/4 below, adjusting to a `private activated as boolean = false` field read directly if the closure doesn't behave as expected).

- [ ] **Step 2: Run test to verify it fails**

Run: `npm run build-tests && npm run test:ci`
Expected: FAIL - `BGE.UI.MessagePanel`/`BGE.UI.MessagePanelButton` don't exist yet.

- [ ] **Step 3: Write minimal implementation**

```brightscript
' src/source/engine/ui/MessagePanel.bs
import "UiContainer.bs"
import "Label.bs"
import "Button.bs"
import "Theme.bs"
import "../Game.bs"
import "../../utils/utils.bs"

namespace BGE.UI

  ' One button spec for MessagePanel: a label plus the same onActivate callback shape
  ' BGE.UI.Button itself uses (function(button as BGE.UI.Button) as void).
  class MessagePanelButton
    label as string
    onActivate as function or dynamic

    sub new(label as string, onActivate as function or dynamic)
      m.label = label
      m.onActivate = onActivate
    end sub
  end class

  ' A centered modal panel (translucent background, optional heading, optional body
  ' message, a vertical stack of buttons) for pause menus, win/game-over screens, and
  ' similar - promoted from the same shape hand-rolled independently by several
  ' BGE.UI-based examples, including the same focus-safety fix each needed by hand: a
  ' Button registers itself with the global FocusManager the instant it's added to any
  ' focusEnabled container, even one not yet attached to gameUi - so a panel must be
  ' built fresh right before it's shown and torn down (not just hidden) when closed, or
  ' its buttons stay focusable/clickable while invisible. show()/hide() handle this
  ' internally: hide() removes the panel (and its buttons) from its parent entirely, and
  ' show() rebuilds its children fresh each time.
  class MessagePanel extends BGE.UI.UiContainer

    ' Panel heading, shown in a larger font above the message/buttons. Empty ("") means
    ' no heading is drawn.
    title as string = ""
    ' Body message, shown below the heading. Empty ("") means no message is drawn. Call
    ' setMessage() (not this field directly) to update it after the panel is already
    ' shown - it re-measures/re-centers the label.
    message as string = ""
    ' Buttons, top to bottom, in the order given to the constructor.
    buttons as BGE.UI.MessagePanelButton[] = []
    ' The actual BGE.UI.Button widgets built from `buttons`, in the same order - only
    ' valid after show() has built the panel's children.
    buttonWidgets as BGE.UI.Button[] = []

    private titleLabel as BGE.UI.Label = invalid
    private messageLabel as BGE.UI.Label = invalid
    private built as boolean = false

    ' @param game
    ' @param {float} panelWidth
    ' @param {float} panelHeight
    ' @param {BGE.UI.MessagePanelButton[]} buttons - shown top to bottom
    ' @param [title=""] - optional heading, drawn in a larger font
    ' @param [message=""] - optional body text below the heading
    sub new(game as BGE.Game, panelWidth as float, panelHeight as float, buttons as BGE.UI.MessagePanelButton[], title = "" as string, message = "" as string)
      super(game)
      m.customPosition = true
      m.width = panelWidth
      m.height = panelHeight
      m.backgroundRGBA = &h2B1B12E6
      m.title = title
      m.message = message
      m.buttons = buttons
    end sub

    ' Centers this panel within a `withinWidth` x `withinHeight` area (typically the ui
    ' canvas size), builds its children fresh, and adds it to `parent`. Call hide() first
    ' if this panel is already shown - calling show() again without hiding first stacks a
    ' second copy of every child on top of the first.
    '
    ' @param {BGE.UI.UiContainer} parent
    ' @param {float} withinWidth
    ' @param {float} withinHeight
    sub show(parent as BGE.UI.UiContainer, withinWidth as float, withinHeight as float)
      m.customX = (withinWidth - m.width) / 2.0
      m.customY = (withinHeight - m.height) / 2.0
      m.buildChildren()
      parent.addChild(m)
    end sub

    ' Removes this panel (and its buttons) from `parent` entirely - not just a visibility
    ' toggle - so its buttons unregister from the shared FocusManager instead of staying
    ' focusable/clickable while hidden. Call show() again to reopen; it rebuilds fresh
    ' children each time.
    '
    ' @param {BGE.UI.UiContainer} parent
    sub hide(parent as BGE.UI.UiContainer)
      parent.removeChild(m)
      m.built = false
    end sub

    ' Updates the body message after the panel has already been shown (e.g. a running
    ' score baked into the text) and re-centers it, since its width varies with the text.
    '
    ' @param {string} message
    sub setMessage(message as string)
      m.message = message
      if m.messageLabel <> invalid
        m.messageLabel.setText(message)
        messageWidth = m.game.getFont("body").GetOneLineWidth(message, 10000)
        m.messageLabel.customX = BGE.Math.Max((m.width - messageWidth) / 2.0, 10.0)
      end if
    end sub

    private sub buildChildren()
      if m.built
        return
      end if
      m.built = true
      m.clearChildren()
      m.titleLabel = invalid
      m.messageLabel = invalid
      m.buttonWidgets = []

      buttonWidth = m.width * 0.76
      buttonX = (m.width - buttonWidth) / 2.0
      buttonHeight = 56.0
      nextY = 14.0

      if m.title <> ""
        titleContainer = new BGE.UI.UiContainer(m.game)
        titleContainer.showBackground = false
        titleContainer.theme = new BGE.UI.Theme()
        titleContainer.theme.font = m.game.getFont("heading")
        titleWidth = m.game.getFont("heading").GetOneLineWidth(m.title, 10000)

        m.titleLabel = new BGE.UI.Label(m.game)
        m.titleLabel.customPosition = true
        m.titleLabel.customX = (m.width - titleWidth) / 2.0
        m.titleLabel.customY = nextY
        m.titleLabel.setText(m.title)
        m.titleLabel.drawableText.textColor = &hFFD966FF
        titleContainer.addChild(m.titleLabel)
        m.addChild(titleContainer)
        nextY += 51.0
      end if

      if m.message <> ""
        m.messageLabel = new BGE.UI.Label(m.game)
        m.messageLabel.customPosition = true
        m.messageLabel.customY = nextY
        m.messageLabel.drawableText.textColor = &hFFD966FF
        m.addChild(m.messageLabel)
        m.setMessage(m.message)
        nextY += 48.0
      end if

      for each spec in m.buttons
        button = new BGE.UI.Button(m.game)
        button.setLabel(spec.label)
        button.customPosition = true
        button.customX = buttonX
        button.customY = nextY
        button.width = buttonWidth
        button.height = buttonHeight
        button.onActivate = spec.onActivate
        m.addChild(button)
        m.buttonWidgets.push(button)
        nextY += buttonHeight + 12.0
      end for
    end sub

  end class

end namespace
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npm run build-tests && npm run test:ci`
Expected: PASS - all 4 `MessagePanel` specs green. If the closure-based `activated` test from Step 1 doesn't compile/pass as written, switch it to a `private activated as boolean = false` field set directly inside a non-closing sub (per that step's note) and re-run.

- [ ] **Step 5: Run full engine validation and lint**

Run: `npm run validate && npm run lint`

- [ ] **Step 6: Commit**

```bash
git add src/source/engine/ui/MessagePanel.bs src/source/engine/ui/MessagePanel.spec.bs
git commit -m "feat: add BGE.UI.MessagePanel, a reusable modal panel widget"
```

---

## Task 8: Refactor `examples/platformer` PauseMenu to use `MessagePanel`

**Files:**
- Modify: `examples/platformer/src/source/Entities/PauseMenu.bs`

**Interfaces:**
- Consumes: `BGE.UI.MessagePanel`, `BGE.UI.MessagePanelButton` from Task 7.

- [ ] **Step 1: Replace the field and `open()`/`close()` bodies**

Replace:

```brightscript
  panel as BGE.UI.UiContainer
  isOpen = false
```

with:

```brightscript
  panel as BGE.UI.MessagePanel
  isOpen = false
```

Replace the entire `sub open()` body with:

```brightscript
  sub open()
    width = m.game.uiCanvas.getWidth()
    height = m.game.uiCanvas.getHeight()

    resumeButton = new BGE.UI.MessagePanelButton("Resume", sub(button as BGE.UI.Button)
      menu = button.game.getEntityByName("PauseMenu") as PauseMenu
      menu.close()
    end sub)
    restartButton = new BGE.UI.MessagePanelButton("Restart Level", sub(button as BGE.UI.Button)
      ' close() (not just resume()) - Restart Level bypasses the Resume
      ' button entirely, so without this the just-built panel and its 3
      ' focus-registered buttons are never removed from gameUi: Game.
      ' handleRoomChange() (which resetRoom() drives) never clears gameUi
      ' itself and destroys entities with callOnDestroy=false, so nothing
      ' tears the panel down on its own. Left leaked, the fresh PauseMenu
      ' MainRoom.onCreate() adds next would stack a second identical panel
      ' on top of the orphaned one the next time it's opened.
      menu = button.game.getEntityByName("PauseMenu") as PauseMenu
      menu.close()
      button.game.resetRoom()
    end sub)
    quitButton = new BGE.UI.MessagePanelButton("Quit to Title", sub(button as BGE.UI.Button)
      ' Same reasoning as restartButton above: without close() here, the
      ' panel's buttons would leak straight into TitleRoom's own focus
      ' registry alongside its real Start Game button.
      menu = button.game.getEntityByName("PauseMenu") as PauseMenu
      menu.close()
      button.game.changeRoom("TitleRoom")
    end sub)

    ' Sized/colored to actually show as a panel via MessagePanel's own defaults - see
    ' MessagePanel.bs. Widened/heightened from the original 340x240 to fit the larger
    ' "heading" title font and taller buttons (48px -> 56px, for the bumped 30pt body
    ' font).
    m.panel = new BGE.UI.MessagePanel(m.game, 400.0, 275.0, [resumeButton, restartButton, quitButton], "Paused")
    m.panel.show(m.game.gameUi, width, height)
    m.isOpen = true
    m.game.pause()
  end sub
```

Replace `sub close()`:

```brightscript
  sub close()
    m.isOpen = false
    m.game.gameUi.removeChild(m.panel)
    m.game.resume()
  end sub
```

with:

```brightscript
  sub close()
    m.isOpen = false
    m.panel.hide(m.game.gameUi)
    m.game.resume()
  end sub
```

Update the class doc comment's note about *why* the panel is built fresh on every `open()` to reference `MessagePanel.show()`/`hide()` instead of re-explaining the focus-registration hazard by hand (that explanation now lives on `MessagePanel` itself - see Task 7):

Replace:

```brightscript
  ' Builds a fresh panel every time the menu opens, and close() tears it back
  ' down (gameUi.removeChild() -> UiContainer.onDestroy() -> clearChildren(),
  ' which also unregisters the buttons from the shared FocusManager). A
  ' Button registers itself with the global BGE.UI.FocusManager the instant
  ' it's added to any focusEnabled container (UiContainer.addChild()),
  ' regardless of whether that container is itself attached to gameUi -
  ' building these once in onCreate() (or reusing one built-once instance
  ' across opens) left them focusable and OK-clickable for the rest of the
  ' level even while the panel was hidden, silently swallowing the player's
  ' own Move/Jump input the moment D-pad navigation happened to focus one of
  ' them (confirmed on-device: holding Move then pressing Jump could quietly
  ' activate the still-hidden "Quit to Title" button and bounce straight back
  ' to the title screen mid-level). GameStateManager's end panel has the same
  ' underlying hazard and solves it by building once lazily (buildEndPanel())
  ' - that alone isn't enough here since, unlike the end panel, this one is
  ' meant to open and close repeatedly within a single level: close() already
  ' destroys the panel's children via removeChild(), so a "build once" guard
  ' would leave every pause after the first showing an empty panel. Building
  ' fresh on every open() (and letting close() destroy it) keeps the buttons
  ' out of the focus registry for the entire time the panel isn't shown.
```

with:

```brightscript
  ' Uses BGE.UI.MessagePanel (show()/hide()) rather than removing/hiding the panel in
  ' place - see MessagePanel's own doc comment for why a modal panel must be built fresh
  ' right before showing and torn down (not just hidden) on close, to keep its buttons
  ' out of the shared FocusManager's registry while the panel isn't visible.
```

- [ ] **Step 2: Build the example**

Run: `cd examples/platformer && npm run build`
Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
git add examples/platformer/src/source/Entities/PauseMenu.bs
git commit -m "examples/platformer: use BGE.UI.MessagePanel for PauseMenu"
```

---

## Task 9: Refactor `examples/platformer` GameStateManager's end panel to use `MessagePanel`

**Files:**
- Modify: `examples/platformer/src/source/Entities/GameStateManager.bs`

**Interfaces:**
- Consumes: `BGE.UI.MessagePanel`, `BGE.UI.MessagePanelButton` from Task 7.

- [ ] **Step 1: Replace the fields and end-panel methods**

Replace:

```brightscript
  endPanel as BGE.UI.UiContainer
  endMessageLabel as BGE.UI.Label
  endPanelBuilt = false
```

with:

```brightscript
  endPanel as BGE.UI.MessagePanel
```

Remove the whole pre-built `m.endPanel`/`m.endPanel.width`/`m.endPanel.height`/etc. block from `onCreate()` (it's replaced by `MessagePanel`'s own constructor, built lazily in `showEndPanel()` below instead of upfront):

```brightscript
    ' Sized/colored to actually show as a panel - UiContainer's background
    ' rect draws at m.width/m.height, which default to 0 (invisible) unless
    ' set explicitly. Widened/heightened from the original 340x185 to fit the
    ' larger body font (24 -> 30) and taller buttons (48px -> 56px, for the
    ' bumped 30pt body font) - see buildEndPanel() below.
    m.endPanel = new BGE.UI.UiContainer(m.game)
    m.endPanel.customPosition = true
    m.endPanel.width = 460
    m.endPanel.height = 200
    m.endPanel.customX = (width - m.endPanel.width) / 2
    m.endPanel.customY = (height - m.endPanel.height) / 2
    m.endPanel.backgroundRGBA = &h2B1B12E6 ' near-opaque dark rock-brown
```

Delete this block entirely from `onCreate()` (leaving the `scoreLabel`/`livesLabel` setup above it untouched).

Replace `private sub buildEndPanel()` and `private sub showEndPanel(message as string)` with:

```brightscript
  ' Builds a fresh end panel (win or game-over - both use this same panel, just with a
  ' different message and button set) and shows it - called from onGameEvent() below the
  ' first time an end state actually happens. A Button registers itself with the shared,
  ' global BGE.UI.FocusManager the instant it's added to any focusEnabled container, so
  ' building it lazily here (via BGE.UI.MessagePanel.show()) rather than upfront in
  ' onCreate() keeps Retry/Quit out of the focus registry (and un-clickable) for the
  ' entire time the level is actually being played.
  private sub showEndPanel(message as string)
    width = m.game.uiCanvas.getWidth()
    height = m.game.uiCanvas.getHeight()

    retryButton = new BGE.UI.MessagePanelButton("Retry", sub(button as BGE.UI.Button)
      button.game.resetRoom()
    end sub)
    quitButton = new BGE.UI.MessagePanelButton("Quit to Title", sub(button as BGE.UI.Button)
      button.game.changeRoom("TitleRoom")
    end sub)

    ' Widened/heightened from the original 340x185 to fit the larger body font
    ' (24 -> 30) and taller buttons (48px -> 56px).
    m.endPanel = new BGE.UI.MessagePanel(m.game, 460.0, 200.0, [retryButton, quitButton], "", message)
    m.endPanel.show(m.game.gameUi, width, height)
    m.game.pause()
  end sub
```

- [ ] **Step 2: Build the example**

Run: `cd examples/platformer && npm run build`
Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
git add examples/platformer/src/source/Entities/GameStateManager.bs
git commit -m "examples/platformer: use BGE.UI.MessagePanel for the win/game-over end panel"
```

---

## Task 10: Convert `examples/breakout` PauseHandler to `MessagePanel`

**Files:**
- Modify: `examples/breakout/src/source/Entities/PauseHandler.bs`

**Interfaces:**
- Consumes: `BGE.UI.MessagePanel`, `BGE.UI.MessagePanelButton` from Task 7.

**Scope note:** breakout's current pause is a plain `drawText("Paused", ...)` overlay with no buttons at all - this is a real behavior addition (a Resume button, focus-navigable), not a pure refactor, per the user's explicit choice to include breakout in this pass.

- [ ] **Step 1: Rewrite PauseHandler.bs**

Replace the whole file:

```brightscript
' Handles pause ("play") and toggling the debug overlay ("options" - FPS,
' input, memory, GC stats; see the FpsDisplay/InputDisplay/MemoryDisplay/
' GarbageCollectorDisplay added to the debug UI in main.bs). Both are
' meta/housekeeping concerns unrelated to gameplay, so they live in their
' own persistent, non-pauseable entity rather than cluttering ScoreHandler.
class PauseHandler extends BGE.GameEntity

  panel as BGE.UI.MessagePanel
  isOpen = false

  sub new(game as BGE.Game)
    super(game)
    m.name = "PauseHandler"
  end sub

  override sub onCreate(args as roAssociativeArray)
    m.persistent = true
    m.pauseable = false
  end sub

  override sub onInput(input as BGE.GameInput)
    if not input.press
      return
    end if
    if input.isButton("play")
      if m.isOpen
        m.close()
      else
        m.open()
      end if
    else if input.isButton("options")
      m.game.debugShowUi(not m.game.isDebugUiEnabled())
    end if
  end sub

  ' Builds a fresh panel every time (see BGE.UI.MessagePanel's own doc comment for why -
  ' its buttons must stay out of the shared FocusManager's registry while the panel
  ' isn't shown).
  private sub open()
    width = m.game.uiCanvas.getWidth()
    height = m.game.uiCanvas.getHeight()

    resumeButton = new BGE.UI.MessagePanelButton("Resume", sub(button as BGE.UI.Button)
      handler = button.game.getEntityByName("PauseHandler") as PauseHandler
      handler.close()
    end sub)

    m.panel = new BGE.UI.MessagePanel(m.game, 260.0, 130.0, [resumeButton], "Paused")
    m.panel.show(m.game.gameUi, width, height)
    m.isOpen = true
    m.game.pause()
  end sub

  private sub close()
    m.isOpen = false
    m.panel.hide(m.game.gameUi)
    m.game.resume()
  end sub

end class
```

- [ ] **Step 2: Build the example**

Run: `cd examples/breakout && npm run build`
Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
git add examples/breakout/src/source/Entities/PauseHandler.bs
git commit -m "examples/breakout: replace drawText pause overlay with BGE.UI.MessagePanel"
```

---

## Task 11: Update docs and run the full quality gate

**Files:**
- Modify: `CLAUDE.md`

**Interfaces:** none (documentation only).

- [ ] **Step 1: Add CLAUDE.md entries for the 4 new engine features**

In the "Math / Utils" section, after the existing `utils/` paragraph, add:

```markdown
- `BGE.CountdownTimer` (`utils/CountdownTimer.bs`) is a small dt-driven countdown - `start(seconds)`/`tick(dt)`/`isActive()`/`remaining()`/`stop()` - for the common "for the next N seconds, this is true" shape (coyote time, input buffering, invulnerability/hit-flash windows, cooldowns). It's unrelated to `BGE.GameTimer`, which wraps a wall-clock `roTimespan` for measuring real elapsed time rather than being ticked by a per-frame `dt`.
```

In the "Collision" section, after the existing `Collider`/`CircleCollider`/`RectangleCollider` paragraph, add:

```markdown
- `BGE.resolveAabbTileCollision()` (`colliders/TileCollision.bs`) is a generic AABB-vs-static-tile resolver for tile-based platformer/top-down games: given an entity's pre-move position/hitbox/velocity and a `RectangleCollider` tile (optionally one-way), it returns a `BGE.TileCollisionResult` (`position`, `velocity`, `side` - a `BGE.TileCollisionSide` of `top`/`bottom`/`left`/`right`/`none`) covering landing-on-top, one-way pass-through, head bumps, and side pushes. It complements, rather than replaces, `Collider`/`CheckMultipleCollisions()` - use it only for resolving collisions against static tile geometry from inside `onCollision()`, not for entity-vs-entity collision. See `examples/platformer`'s `Player.onCollision()` for a worked example.
```

In the "Renderer / SceneObjects" section, after the `SceneObjectPlane`/`fillMode` bullets, add:

```markdown
- `BGE.newFullHeightParallaxLayer()` (`drawables/DrawableParallaxLayer.bs`) builds a `DrawableParallaxLayer` scaled to fill the canvas height and tiled on both axes, with its tile-repeat seam anchored at a chosen on-canvas `targetX`/`targetY` - a promoted, worked-out application of `computeEffectiveWorldPosition()`'s own "pre-divide the offset by `parallaxFactor`" derivation (see that method's comment). It assumes the owning entity sits at world `(0,0,0)` under a camera whose target on the orthogonal axis stays fixed - the common side-scroller shape `examples/platformer`'s `MainRoom` uses to stack several background layers with staggered seams. `examples/parallax`'s own hand-rolled `newLayer()` solves a related-but-different case (owner co-located with a moving camera target, non-uniform per-axis factor) not covered by this helper.
```

In the "UI" section, after the existing `UiContainer`/`UiWidget`/... paragraph, add:

```markdown
- `BGE.UI.MessagePanel` (`ui/MessagePanel.bs`) is a reusable centered modal panel (translucent background, optional heading, optional body message, a vertical stack of `BGE.UI.MessagePanelButton`s) for pause menus, win/game-over screens, and similar - `show(parent, withinWidth, withinHeight)`/`hide(parent)` handle the same focus-registration hazard every hand-rolled panel in this codebase had to solve on its own: a `Button` registers with the shared `FocusManager` the instant it's added to any `focusEnabled` container, even one not yet attached to `gameUi`, so a panel must be built fresh right before showing and torn down (not just hidden) on close - `hide()` does the latter, `show()` the former, automatically. See `examples/platformer`'s `PauseMenu`/`GameStateManager` and `examples/breakout`'s `PauseHandler` for worked examples.
```

- [ ] **Step 2: Run the full engine quality gate**

Run: `npm run check`
Expected: lint, validate, and headless tests all pass.

- [ ] **Step 3: Validate every example**

Run: `npm run validate-examples`
Expected: passes for every example, including `platformer` and `breakout`.

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: document CountdownTimer, resolveAabbTileCollision, newFullHeightParallaxLayer, MessagePanel"
```

---

## Task 12: On-device verification

**Files:** none (verification only - see CLAUDE.md's note that automated tests don't exercise example app code; this task is mandatory before considering the example refactors done, not optional polish).

- [ ] **Step 1: Sideload and smoke-test `examples/platformer`**

Using the `rokubot-examples` skill: launch the example, play through a level checking (a) jump feel is unchanged (coyote time, jump buffering, variable jump height all still work - Task 2), (b) ground/one-way-platform/wall collision behaves identically to before (Task 4 - landing, head bumps, side pushes, walking off a one-way platform edge), (c) the parallax background layers still scroll with staggered, seamless tiling and no visible seam (Task 6), (d) opening/closing the pause menu (Task 8) and reaching both the win and game-over end panels (Task 9) all show correctly, are focus-navigable, and their buttons (Resume/Restart Level/Quit to Title, Retry/Quit to Title) work.

- [ ] **Step 2: Sideload and smoke-test `examples/breakout`**

Using the `rokubot-examples` skill: launch the example, press the pause button and confirm the new `MessagePanel`-based pause screen appears (title "Paused", a focus-navigable Resume button), Resume closes it and play continues, and pressing pause again re-opens a fresh panel correctly.

- [ ] **Step 2: Fix anything found, re-run the affected build/validate/test commands, and commit the fix**

If either smoke test surfaces a bug, fix it in the relevant task's file, re-run that task's Step 2/3 build command (and `npm run test:ci`/`npm run validate` if the fix touched an engine file), then commit with a message describing what the on-device check caught (matching this codebase's own convention - see e.g. `56ede35 examples/platformer: fix Enemy spawn-position capture and PauseMenu focus-registration bugs found in full-playthrough smoke test` in `git log`).

---

## Task 13: Finish the branch

- [ ] User confirmed (2026-09-06) one combined PR touching all of it is fine - no need to split into 4. Use the `superpowers:finishing-a-development-branch` skill to open one PR from this branch referencing all four issues (#202, #203, #204, #205), with a body ending in the required `Co-Authored-By`/`Generated with Claude Code` footer per this repo's git conventions.
