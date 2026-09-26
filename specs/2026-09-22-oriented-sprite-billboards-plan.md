# Angle-Based Sprite Billboards (issue #104) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `DrawableOrientedSprite`, a `Sprite` subclass that swaps which named animation is playing based on the angle between the camera and the entity, faking Doom/Duke3D-style pseudo-3D billboards — then demo it in `examples/terrain` with the supplied Helix character spritesheet.

**Architecture:** `DrawableOrientedSprite extends BGE.Sprite`. It registers one real `SpriteAnimation` per (elevation band, angle bucket) cell of a small grid under a "base" animation name (e.g. `"walk"`), and every `update()` recomputes which cell is active from `owner.game.canvas.renderer.camera` vs. the entity's own position/rotation, then delegates to `Sprite`'s already-existing `playAnimation()`/frame-indexing machinery unchanged. Mirroring (skip drawing a duplicate view) reuses the engine's existing negative-`scale.x`-flips-a-billboard behavior. No changes to `SceneObjectImage`/`SceneObject`.

**Tech Stack:** BrighterScript, Rooibos (`rooibos-roku`) unit tests, `rokubot` for on-device/simulator verification.

**Spec:** `specs/2026-09-22-oriented-sprite-billboards-design.md`

## Global Constraints

- `numAngles` default `8`; `numElevationBands` default `1` (no vertical distinction) — both configurable, not hard-coded.
- Zero changes to `SceneObjectImage`/`SceneObject`/`Image`/`AnimatedImage`/`Sprite` — purely additive new files.
- Validation errors use this codebase's existing convention — `m.owner.game.log(message, BGE.Debug.LogLevel.error)` plus returning `invalid`/no-op — not BrighterScript `throw` (confirmed unused/commented-out elsewhere in this engine; see `Sprite.addAnimation`'s own warning-log convention).
- Bucket 0 (azimuth) = entity's front facing the camera; buckets increase clockwise (viewed from above). Elevation band 0 = camera below the entity looking up; band `numElevationBands - 1` = camera above looking down.
- Every new/changed public method gets a `'`-style JSDoc doc comment (pulled into `npm run docs`), written for the game-developer consumer, per this repo's convention.
- Run `npm run validate` after engine changes and `npm run build-tests && npm run test:ci` after test changes, per this repo's standard workflow.

---

## File Structure

| File | Responsibility |
|---|---|
| `src/source/engine/drawables/DrawableOrientedSprite.bs` (new) | The `DrawableOrientedSprite` class: registration (`addOrientedAnimation`/`addElevationOrientedAnimation`), bucket geometry (`computeAngleBucket`/`computeElevationBand`), and per-frame switching (`update()`/`playOrientedAnimation`). |
| `src/source/engine/drawables/DrawableOrientedSprite.spec.bs` (new) | Rooibos unit tests for all of the above. |
| `src/source/engine/GameEntity.bs` (modify) | Add `addOrientedSprite()` factory method, mirroring `addSprite()`/`addSphere()`. |
| `docs/drawables-and-scene-objects.md` (modify) | New table row + section describing `DrawableOrientedSprite`, matching the existing `DrawableSphere` section's depth. |
| `examples/terrain/src/sprites/helix_full_sheet.png` (new, copied) | The supplied character spritesheet asset. |
| `examples/terrain/src/source/main.bs` (modify) | `game.loadBitmap("guardSheet", "pkg:/sprites/helix_full_sheet.png")`. |
| `examples/terrain/src/source/Entities/Guard.bs` (new) | A `BGE.GameEntity` using `DrawableOrientedSprite`, following the `LowWall` convention. |
| `examples/terrain/src/source/Rooms/GuardPlacements.bs` (new) | Fixed placement data for `Guard` instances, following `WallPlacements.bs`'s convention. |
| `examples/terrain/src/source/Rooms/WorldRoom.bs` (modify) | Add `addGuards()`, called from `onCreate()` alongside `addTrees()`/`addLowWalls()`. |

---

## Task 1: `DrawableOrientedSprite` scaffold + animation registration

**Files:**
- Create: `src/source/engine/drawables/DrawableOrientedSprite.bs`
- Create: `src/source/engine/drawables/DrawableOrientedSprite.spec.bs`

**Interfaces:**
- Produces: `class BGE.DrawableOrientedSprite extends BGE.Sprite` with public fields `numAngles as integer`, `numElevationBands as integer`; public methods `addOrientedAnimation(baseName as string, angleFrames as object, frameRate as integer, playMode = SpritePlayMode.Loop as SpritePlayMode) as void`, `addElevationOrientedAnimation(baseName as string, elevationBands as object, frameRate as integer, playMode = SpritePlayMode.Loop as SpritePlayMode) as void`; a test-only accessor `registeredAnimationNameForTests(baseName as string, elevationBand as integer, angleBucket as integer) as string` (returns the real underlying `Sprite` animation name a bucket resolves to, following a mirror to its source — mirrors `Sprite.rawAnimationClockMsForTests()`'s "for tests only" convention).

- [ ] **Step 1: Write the failing test for basic single-band registration**

```brighterscript
' src/source/engine/drawables/DrawableOrientedSprite.spec.bs
namespace tests

  @suite("BGE.DrawableOrientedSprite")
  class DrawableOrientedSpriteTests extends rooibos.BaseTestSuite

    game as BGE.Game
    entity as BGE.GameEntity
    spriteSheet as roBitmap
    orientedSprite as BGE.DrawableOrientedSprite

    protected override function beforeEach()
      m.game = new BGE.Game(320, 240)
      m.entity = new BGE.GameEntity(m.game, {name: "TestEntity"})
      ' 8 columns (one per angle bucket) x 1 row, 10x10 cells - enough to slice 8
      ' single-frame walk "animations" for a numAngles=8, numElevationBands=1 sprite.
      m.spriteSheet = CreateObject("roBitmap", {width: 80, height: 10, alphaEnable: true})
      m.orientedSprite = new BGE.DrawableOrientedSprite(m.entity, m.spriteSheet, 10, 10)
    end function

    @describe("addOrientedAnimation")

    @it("registers one real Sprite animation per angle bucket")
    function _()
      m.orientedSprite.addOrientedAnimation("walk", [[0], [1], [2], [3], [4], [5], [6], [7]], 10, BGE.SpritePlayMode.Loop)
      for bucket = 0 to 7
        name = m.orientedSprite.registeredAnimationNameForTests("walk", 0, bucket)
        m.assertTrue(invalid <> m.orientedSprite.animations[name], "expected a real Sprite animation registered for bucket " + bucket.toStr())
      end for
    end function

  end class

end namespace
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm run build-tests && npm run test:ci`
Expected: FAIL — `DrawableOrientedSprite` does not exist yet (compile error).

- [ ] **Step 3: Write the class with constructor + real-bucket registration (no mirroring yet)**

```brighterscript
' src/source/engine/drawables/DrawableOrientedSprite.bs
import "../../roku_modules/rodash/rodash.d.bs"
import "../debug/LogLevel.bs"
import "../GameEntity.bs"
import "../renderer/cameras/Camera.bs"
import "../renderer/cameras/Camera3d.bs"
import "../../math/math.bs"
import "../../math/vector.bs"
import "Sprite.bs"

namespace BGE

  ' One resolved angle/elevation bucket: either real art (its own registered Sprite
  ' animation) or a mirror of another bucket's art (same animation, flipped via scale.x).
  class OrientedSpriteBucket
    animationName as string
    isMirror as boolean = false
  end class

  ' A Sprite that swaps which named animation is active based on the angle between the
  ' camera and this entity - the classic Doom/Duke3D "billboard sprite" technique for
  ' faking full 3D orientation with pre-rendered 2D views. See
  ' docs/drawables-and-scene-objects.md for a full walkthrough and
  ' specs/2026-09-22-oriented-sprite-billboards-design.md for the design.
  class DrawableOrientedSprite extends Sprite

    ' Number of horizontal (azimuth) view buckets around the entity. Bucket 0 is the
    ' entity's front facing the camera; buckets increase clockwise (viewed from above).
    numAngles as integer = 8

    ' Number of vertical (elevation) view bands, from the camera looking up at the
    ' entity (band 0) to looking down on it (band numElevationBands - 1). The default
    ' of 1 means no vertical distinction at all - every elevation resolves to band 0.
    numElevationBands as integer = 1

    ' baseName -> (numElevationBands x numAngles) array of OrientedSpriteBucket
    private orientedAnimations as roAssociativeArray = {}
    private activeBaseAnimationName as string = ""
    private currentElevationBand as integer = -1
    private currentAngleBucket as integer = -1
    private baseScaleX as float = 1.0

    sub new(owner as GameEntity, spriteSheet as ifDraw2d, cellWidth as integer, cellHeight as integer, numAngles = 8 as integer, numElevationBands = 1 as integer, args = {} as roAssociativeArray)
      super(owner, spriteSheet, cellWidth, cellHeight, args)
      m.numAngles = numAngles
      m.numElevationBands = numElevationBands
      m.baseScaleX = m.scale.x
    end sub

    ' Registers one animation per angle bucket under `baseName` (e.g. "walk"), for the
    ' single elevation band case (the common one - a sheet with no distinct top-down/
    ' bottom-up art). Sugar for addElevationOrientedAnimation with a single-band wrapper;
    ' errors (via addElevationOrientedAnimation's own validation) if numElevationBands
    ' isn't actually 1.
    '
    ' @param {string} baseName
    ' @param angleFrames - array of exactly numAngles entries, each either an integer[]
    '   of frame indexes, or {mirrorOf: {elevation: E, angle: A}} to reuse another
    '   bucket's frames flipped horizontally.
    ' @param {integer} frameRate
    ' @param [playMode="loop"]
    function addOrientedAnimation(baseName as string, angleFrames as object, frameRate as integer, playMode = SpritePlayMode.Loop as SpritePlayMode) as void
      m.addElevationOrientedAnimation(baseName, [angleFrames], frameRate, playMode)
    end function

    ' Registers the full elevation x angle grid under `baseName`. See
    ' specs/2026-09-22-oriented-sprite-billboards-design.md for the full bucket-index
    ' semantics.
    '
    ' @param {string} baseName
    ' @param elevationBands - array of exactly numElevationBands entries; each entry is
    '   itself an angleFrames array in the same shape addOrientedAnimation takes.
    ' @param {integer} frameRate
    ' @param [playMode="loop"]
    function addElevationOrientedAnimation(baseName as string, elevationBands as object, frameRate as integer, playMode = SpritePlayMode.Loop as SpritePlayMode) as void
      if elevationBands.Count() <> m.numElevationBands
        m.owner.game.log(`DrawableOrientedSprite.addElevationOrientedAnimation() - '${baseName}' expected ${m.numElevationBands.toStr()} elevation band(s), got ${elevationBands.Count().toStr()}`, BGE.Debug.LogLevel.error)
        return
      end if

      grid = []
      for e = 0 to m.numElevationBands - 1
        angleFrames = elevationBands[e]
        if angleFrames.Count() <> m.numAngles
          m.owner.game.log(`DrawableOrientedSprite.addElevationOrientedAnimation() - '${baseName}' elevation band ${e.toStr()} expected ${m.numAngles.toStr()} angle bucket(s), got ${angleFrames.Count().toStr()}`, BGE.Debug.LogLevel.error)
          return
        end if
        grid.push([invalid, invalid, invalid, invalid, invalid, invalid, invalid, invalid].Slice(0, m.numAngles))
      end for

      ' First pass: register real (non-mirrored) buckets as actual Sprite animations.
      for e = 0 to m.numElevationBands - 1
        angleFrames = elevationBands[e]
        for a = 0 to m.numAngles - 1
          bucketEntry = angleFrames[a]
          if rodash.isArray(bucketEntry)
            animName = m.internalAnimationName(baseName, e, a)
            m.addAnimation(animName, bucketEntry, frameRate, playMode)
            grid[e][a] = new OrientedSpriteBucket()
            grid[e][a].animationName = animName
            grid[e][a].isMirror = false
          end if
        end for
      end for

      ' Second pass: resolve mirrorOf entries against the real buckets just registered.
      for e = 0 to m.numElevationBands - 1
        angleFrames = elevationBands[e]
        for a = 0 to m.numAngles - 1
          bucketEntry = angleFrames[a]
          if not rodash.isArray(bucketEntry)
            if invalid = bucketEntry or invalid = bucketEntry.mirrorOf
              m.owner.game.log(`DrawableOrientedSprite.addElevationOrientedAnimation() - '${baseName}' elevation band ${e.toStr()} angle bucket ${a.toStr()} is neither a frame list nor a {mirrorOf} entry`, BGE.Debug.LogLevel.error)
              return
            end if
            targetElevation = bucketEntry.mirrorOf.elevation
            targetAngle = bucketEntry.mirrorOf.angle
            validTarget = targetElevation >= 0 and targetElevation < m.numElevationBands and targetAngle >= 0 and targetAngle < m.numAngles
            if validTarget
              target = grid[targetElevation][targetAngle]
              validTarget = invalid <> target and not target.isMirror
            end if
            if not validTarget
              m.owner.game.log(`DrawableOrientedSprite.addElevationOrientedAnimation() - '${baseName}' elevation band ${e.toStr()} angle bucket ${a.toStr()} has a mirrorOf target that isn't a real registered bucket`, BGE.Debug.LogLevel.error)
              return
            end if
            grid[e][a] = new OrientedSpriteBucket()
            grid[e][a].animationName = grid[targetElevation][targetAngle].animationName
            grid[e][a].isMirror = true
          end if
        end for
      end for

      m.orientedAnimations[baseName] = grid
    end function

    private function internalAnimationName(baseName as string, elevationBand as integer, angleBucket as integer) as string
      return baseName + "_e" + elevationBand.toStr() + "_a" + angleBucket.toStr()
    end function

    ' For tests only - the real underlying Sprite animation name a bucket resolves to
    ' (following a mirror to its source). Mirrors Sprite's own "for tests only"
    ' accessor convention (see rawAnimationClockMsForTests()).
    '
    ' @param {string} baseName
    ' @param {integer} elevationBand
    ' @param {integer} angleBucket
    ' @return {string}
    function registeredAnimationNameForTests(baseName as string, elevationBand as integer, angleBucket as integer) as string
      grid = m.orientedAnimations[baseName]
      if invalid = grid
        return ""
      end if
      bucket = grid[elevationBand][angleBucket]
      if invalid = bucket
        return ""
      end if
      return bucket.animationName
    end function

  end class

end namespace
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npm run build-tests && npm run test:ci`
Expected: PASS

- [ ] **Step 5: Write the failing test for validation errors and mirroring**

```brighterscript
    @describe("addOrientedAnimation validation")

    @it("does not register anything if angleFrames.Count() doesn't match numAngles")
    function _()
      m.orientedSprite.addOrientedAnimation("walk", [[0], [1]], 10)
      m.assertEqual("", m.orientedSprite.registeredAnimationNameForTests("walk", 0, 0))
    end function

    @describe("mirrorOf")

    @it("resolves a mirrored bucket to its source bucket's real animation name")
    function _()
      angleFrames = [[0], [1], [2], [3], {mirrorOf: {elevation: 0, angle: 2}}, [5], [6], [7]]
      m.orientedSprite.addOrientedAnimation("walk", angleFrames, 10)
      sourceAnim = m.orientedSprite.registeredAnimationNameForTests("walk", 0, 2)
      mirroredAnim = m.orientedSprite.registeredAnimationNameForTests("walk", 0, 4)
      m.assertEqual(sourceAnim, mirroredAnim)
      m.assertTrue(sourceAnim <> "", "expected the source bucket to have resolved to a real animation")
    end function

    @it("does not register anything if a mirrorOf target isn't a real bucket")
    function _()
      angleFrames = [{mirrorOf: {elevation: 0, angle: 1}}, [1], [2], [3], [4], [5], [6], [7]]
      m.orientedSprite.addOrientedAnimation("walk", angleFrames, 10)
      m.assertEqual("", m.orientedSprite.registeredAnimationNameForTests("walk", 0, 1))
    end function
```

- [ ] **Step 6: Run tests to verify they pass (implementation from Step 3 already handles these)**

Run: `npm run build-tests && npm run test:ci`
Expected: PASS for all of the above. If the mirror/validation tests fail, fix `addElevationOrientedAnimation` (most likely culprit: the two-pass ordering, or the `grid` pre-fill loop) before moving on.

- [ ] **Step 7: Commit**

```bash
git add src/source/engine/drawables/DrawableOrientedSprite.bs src/source/engine/drawables/DrawableOrientedSprite.spec.bs
git commit -m "Add DrawableOrientedSprite scaffold with angle-bucket animation registration"
```

---

## Task 2: Angle/elevation bucket geometry

**Files:**
- Modify: `src/source/engine/drawables/DrawableOrientedSprite.bs`
- Modify: `src/source/engine/drawables/DrawableOrientedSprite.spec.bs`

**Interfaces:**
- Consumes: `m.owner.position`/`m.owner.rotation` (`BGE.GameEntity`, both `BGE.Math.Vector`), `m.numAngles`/`m.numElevationBands` from Task 1.
- Produces: `function computeAngleBucket(camera as BGE.Camera) as integer`, `function computeElevationBand(camera as BGE.Camera) as integer` — both public (useful for a consumer's own debug overlay, not test-only).

- [ ] **Step 1: Write the failing tests**

```brighterscript
    @describe("computeAngleBucket")

    @it("is bucket 0 when the camera is directly in front of the entity's facing")
    function _()
      m.entity.position = BGE.Math.VectorOps.create(0, 0, 0)
      m.entity.rotation.y = 0
      camera = new BGE.Camera3d()
      ' Entity facing (yaw=0) is (0,0,-1) (see Camera3d.rotate's convention) - so
      ' "directly in front" is the camera positioned further along -Z from the entity.
      camera.position = BGE.Math.VectorOps.create(0, 0, -100)
      m.assertEqual(0, m.orientedSprite.computeAngleBucket(camera))
    end function

    @it("moves to the next bucket as the camera orbits by one bucket's worth of angle")
    function _()
      m.entity.position = BGE.Math.VectorOps.create(0, 0, 0)
      m.entity.rotation.y = 0
      camera = new BGE.Camera3d()
      bucketAngle = (2 * BGE.Math.PI) / 8
      ' Orbit 1.5 buckets clockwise from "directly in front" (camera at -Z) - past the
      ' bucket-1/bucket-2 boundary so this isn't sensitive to the exact centering.
      angle = 1.5 * bucketAngle
      camera.position = BGE.Math.VectorOps.create(100 * sin(angle), 0, -100 * cos(angle))
      m.assertEqual(1, m.orientedSprite.computeAngleBucket(camera))
    end function

    @it("wraps back to bucket 0 for a camera almost a full turn around")
    function _()
      m.entity.position = BGE.Math.VectorOps.create(0, 0, 0)
      m.entity.rotation.y = 0
      camera = new BGE.Camera3d()
      bucketAngle = (2 * BGE.Math.PI) / 8
      angle = -0.4 * bucketAngle ' just short of a full turn back the other way
      camera.position = BGE.Math.VectorOps.create(100 * sin(angle), 0, -100 * cos(angle))
      m.assertEqual(0, m.orientedSprite.computeAngleBucket(camera))
    end function

    @it("always resolves to bucket 0 for a non-Camera3d camera")
    function _()
      camera = new BGE.Camera2d()
      m.assertEqual(0, m.orientedSprite.computeAngleBucket(camera))
    end function

    @describe("computeElevationBand")

    @it("always resolves to band 0 when numElevationBands is 1 (the default)")
    function _()
      m.entity.position = BGE.Math.VectorOps.create(0, 0, 0)
      camera = new BGE.Camera3d()
      camera.position = BGE.Math.VectorOps.create(0, 500, 0) ' directly overhead
      m.assertEqual(0, m.orientedSprite.computeElevationBand(camera))
    end function

    @it("resolves to the top band when the camera is directly overhead, with 3 bands")
    function _()
      m.orientedSprite.numElevationBands = 3
      m.entity.position = BGE.Math.VectorOps.create(0, 0, 0)
      camera = new BGE.Camera3d()
      camera.position = BGE.Math.VectorOps.create(0, 500, 0)
      m.assertEqual(2, m.orientedSprite.computeElevationBand(camera))
    end function

    @it("resolves to the bottom band when the camera is directly below, with 3 bands")
    function _()
      m.orientedSprite.numElevationBands = 3
      m.entity.position = BGE.Math.VectorOps.create(0, 0, 0)
      camera = new BGE.Camera3d()
      camera.position = BGE.Math.VectorOps.create(0, -500, 0)
      m.assertEqual(0, m.orientedSprite.computeElevationBand(camera))
    end function

    @it("resolves to the middle band when the camera is level with the entity, with 3 bands")
    function _()
      m.orientedSprite.numElevationBands = 3
      m.entity.position = BGE.Math.VectorOps.create(0, 0, 0)
      camera = new BGE.Camera3d()
      camera.position = BGE.Math.VectorOps.create(0, 0, -500)
      m.assertEqual(1, m.orientedSprite.computeElevationBand(camera))
    end function
```

Add `import "../renderer/cameras/Camera2d.bs"` to the spec file's needs (Rooibos specs pick up `BGE.Camera2d` via the test bsconfig's ambient scope the same way other specs already reference engine classes without importing them directly — confirm by running; if `cannot-find-name` appears, add the import to the spec file itself, not the production file, since `Camera2d` isn't otherwise used by `DrawableOrientedSprite.bs`).

- [ ] **Step 2: Run tests to verify they fail**

Run: `npm run build-tests && npm run test:ci`
Expected: FAIL — `computeAngleBucket`/`computeElevationBand` don't exist yet.

- [ ] **Step 3: Implement the geometry methods**

Add to `DrawableOrientedSprite.bs`, inside the class body:

```brighterscript
    ' Computes which of numAngles horizontal view buckets is currently visible, from the
    ' angle between this entity's facing (rotation.y) and the direction from this entity
    ' to the camera. Bucket 0 = the entity's front is facing the camera; buckets increase
    ' clockwise as viewed from above. Always 0 for a camera that isn't a Camera3d (a 2D
    ' camera has no facing/orbit concept).
    '
    ' @param {BGE.Camera} camera
    ' @return {integer}
    function computeAngleBucket(camera as BGE.Camera) as integer
      if camera.name <> "Camera3d"
        return 0
      end if
      camera3d = camera as BGE.Camera3d
      toCamera = BGE.Math.VectorOps.subtract(camera3d.position, m.owner.position)
      ' Matches Camera3d.rotate()'s own yaw convention: a yaw of `theta` points the
      ' default forward vector (0,0,-1) at (sin(theta), 0, -cos(theta)), so the inverse
      ' (a direction -> yaw) is Atan2(x, -z).
      angleToCamera = BGE.Math.Atan2(toCamera.x, -toCamera.z)
      relative = BGE.Math.constrainAngle(angleToCamera - m.owner.rotation.y)
      bucketSize = (2 * BGE.Math.PI) / m.numAngles
      bucket = Int((relative + bucketSize / 2) / bucketSize) mod m.numAngles
      return Int(bucket)
    end function

    ' Computes which of numElevationBands vertical view bands is currently visible, from
    ' the camera's pitch relative to this entity - band 0 is the camera below the entity
    ' looking up at it, band numElevationBands - 1 is the camera above looking down.
    ' Always 0 if numElevationBands is 1 (no vertical distinction requested) or the
    ' camera isn't a Camera3d.
    '
    ' @param {BGE.Camera} camera
    ' @return {integer}
    function computeElevationBand(camera as BGE.Camera) as integer
      if camera.name <> "Camera3d" or m.numElevationBands = 1
        return 0
      end if
      camera3d = camera as BGE.Camera3d
      toCamera = BGE.Math.VectorOps.subtract(camera3d.position, m.owner.position)
      horizontalDistance = Sqr(toCamera.x * toCamera.x + toCamera.z * toCamera.z)
      pitch = BGE.Math.Atan2(toCamera.y, horizontalDistance)
      bandSize = BGE.Math.PI / m.numElevationBands
      band = Int((pitch + BGE.Math.HALF_PI) / bandSize)
      if band < 0
        band = 0
      else if band > m.numElevationBands - 1
        band = m.numElevationBands - 1
      end if
      return band
    end function
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `npm run build-tests && npm run test:ci`
Expected: PASS. If the orbit/wrap tests fail, double check the `sin`/`cos` sign convention against `Camera3d.rotate()` (see `src/source/math/Matrix44.bs`'s `getRotationMatrix`) rather than adjusting the test's expected bucket to make it pass.

- [ ] **Step 5: Commit**

```bash
git add src/source/engine/drawables/DrawableOrientedSprite.bs src/source/engine/drawables/DrawableOrientedSprite.spec.bs
git commit -m "Add camera-relative angle/elevation bucket geometry to DrawableOrientedSprite"
```

---

## Task 3: Per-frame bucket switching + `playOrientedAnimation`

**Files:**
- Modify: `src/source/engine/drawables/DrawableOrientedSprite.bs`
- Modify: `src/source/engine/drawables/DrawableOrientedSprite.spec.bs`

**Interfaces:**
- Consumes: `registeredAnimationNameForTests`/`computeAngleBucket`/`computeElevationBand` (Tasks 1-2), `Sprite.playAnimation`/`Sprite.activeAnimation`.
- Produces: `sub playOrientedAnimation(baseName as string)`, `override sub update()`.

- [ ] **Step 1: Write the failing tests**

```brighterscript
    @describe("playOrientedAnimation")

    @it("logs an error and does not set an active animation for an unregistered baseName")
    function _()
      m.orientedSprite.playOrientedAnimation("nonexistent")
      m.assertInvalid(m.orientedSprite.activeAnimation)
    end function

    @it("plays the bucket 0 animation immediately when the camera is directly in front")
    function _()
      m.game.canvas.renderer.setCamera(new BGE.Camera3d())
      m.entity.position = BGE.Math.VectorOps.create(0, 0, 0)
      m.entity.rotation.y = 0
      m.game.canvas.renderer.camera.position = BGE.Math.VectorOps.create(0, 0, -100)

      m.orientedSprite.addOrientedAnimation("walk", [[0], [1], [2], [3], [4], [5], [6], [7]], 10)
      m.orientedSprite.playOrientedAnimation("walk")
      m.orientedSprite.update()

      expected = m.orientedSprite.registeredAnimationNameForTests("walk", 0, 0)
      m.assertEqual(expected, m.orientedSprite.activeAnimation.name)
    end function

    @it("switches to the new bucket's animation as the camera moves to a different bucket")
    function _()
      m.game.canvas.renderer.setCamera(new BGE.Camera3d())
      m.entity.position = BGE.Math.VectorOps.create(0, 0, 0)
      m.entity.rotation.y = 0
      m.game.canvas.renderer.camera.position = BGE.Math.VectorOps.create(0, 0, -100)

      m.orientedSprite.addOrientedAnimation("walk", [[0], [1], [2], [3], [4], [5], [6], [7]], 10)
      m.orientedSprite.playOrientedAnimation("walk")
      m.orientedSprite.update()

      bucketAngle = (2 * BGE.Math.PI) / 8
      angle = 1.5 * bucketAngle
      m.game.canvas.renderer.camera.position = BGE.Math.VectorOps.create(100 * sin(angle), 0, -100 * cos(angle))
      m.orientedSprite.update()

      expected = m.orientedSprite.registeredAnimationNameForTests("walk", 0, 1)
      m.assertEqual(expected, m.orientedSprite.activeAnimation.name)
    end function

    @it("flips scale.x negative while a mirrored bucket is active, and back when it isn't")
    function _()
      m.game.canvas.renderer.setCamera(new BGE.Camera3d())
      m.entity.position = BGE.Math.VectorOps.create(0, 0, 0)
      m.entity.rotation.y = 0
      m.game.canvas.renderer.camera.position = BGE.Math.VectorOps.create(0, 0, -100)

      angleFrames = [[0], [1], [2], [3], {mirrorOf: {elevation: 0, angle: 0}}, [5], [6], [7]]
      m.orientedSprite.addOrientedAnimation("walk", angleFrames, 10)
      m.orientedSprite.playOrientedAnimation("walk")
      m.orientedSprite.update()
      m.assertEqual(1.0, m.orientedSprite.scale.x)

      bucketAngle = (2 * BGE.Math.PI) / 8
      angle = 4 * bucketAngle ' bucket 4, the mirrored one
      m.game.canvas.renderer.camera.position = BGE.Math.VectorOps.create(100 * sin(angle), 0, -100 * cos(angle))
      m.orientedSprite.update()
      m.assertEqual(-1.0, m.orientedSprite.scale.x)
    end function
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `npm run build-tests && npm run test:ci`
Expected: FAIL — `playOrientedAnimation` doesn't exist, `update()` doesn't switch buckets yet.

- [ ] **Step 3: Implement `playOrientedAnimation` and `update()`**

Add to `DrawableOrientedSprite.bs`, inside the class body:

```brighterscript
    ' Selects which base animation is currently playing, analogous to Sprite.
    ' playAnimation - but this picks among the (numElevationBands x numAngles)
    ' per-bucket animations registered for baseName via addOrientedAnimation /
    ' addElevationOrientedAnimation, resolving which one to actually play every
    ' update() from the camera's angle to this entity.
    '
    ' @param {string} baseName
    sub playOrientedAnimation(baseName as string)
      if invalid = m.orientedAnimations[baseName]
        m.owner.game.log(`DrawableOrientedSprite.playOrientedAnimation() - No oriented animation named '${baseName}' exists`, BGE.Debug.LogLevel.error)
        return
      end if
      m.activeBaseAnimationName = baseName
      ' Force the next update() to resolve and apply a bucket even if the camera hasn't
      ' moved since the last call - switching baseName should always take effect
      ' immediately, matching Sprite.playAnimation()'s applies-right-away contract.
      m.currentElevationBand = -1
      m.currentAngleBucket = -1
    end sub

    override sub update()
      if m.activeBaseAnimationName <> ""
        camera = m.owner.game.canvas.renderer.camera
        elevationBand = m.computeElevationBand(camera)
        angleBucket = m.computeAngleBucket(camera)
        if elevationBand <> m.currentElevationBand or angleBucket <> m.currentAngleBucket
          m.currentElevationBand = elevationBand
          m.currentAngleBucket = angleBucket
          bucket = m.orientedAnimations[m.activeBaseAnimationName][elevationBand][angleBucket]
          super.playAnimation(bucket.animationName)
          if bucket.isMirror
            m.scale.x = -m.baseScaleX
          else
            m.scale.x = m.baseScaleX
          end if
        end if
      end if
      super.update()
    end sub
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `npm run build-tests && npm run test:ci`
Expected: PASS

- [ ] **Step 5: Run the full validate + test suite**

Run: `npm run validate && npm run build-tests && npm run test:ci`
Expected: PASS, no new lint/type errors.

- [ ] **Step 6: Commit**

```bash
git add src/source/engine/drawables/DrawableOrientedSprite.bs src/source/engine/drawables/DrawableOrientedSprite.spec.bs
git commit -m "Wire up per-frame angle-bucket switching and mirroring in DrawableOrientedSprite"
```

---

## Task 4: `GameEntity.addOrientedSprite()` factory method

**Files:**
- Modify: `src/source/engine/GameEntity.bs`

**Interfaces:**
- Consumes: `DrawableOrientedSprite.new(owner, spriteSheet, cellWidth, cellHeight, numAngles, numElevationBands, args)` (Task 1).
- Produces: `GameEntity.addOrientedSprite(imageName as string, spriteSheet as roBitmap, cellWidth as integer, cellHeight as integer, numAngles = 8 as integer, numElevationBands = 1 as integer, args = {} as roAssociativeArray, insertPosition = -1 as integer) as DrawableOrientedSprite` — used by Task 6's `Guard` entity.

- [ ] **Step 1: Add the import**

In `src/source/engine/GameEntity.bs`, add alongside the other `drawables/` imports (alphabetical, after `drawables/DrawableCircle.bs`):

```brighterscript
import "drawables/DrawableOrientedSprite.bs"
```

- [ ] **Step 2: Add the factory method**

In `src/source/engine/GameEntity.bs`, immediately after the existing `addSprite()` method (around line 513, right before the `addRectangle` doc comment):

```brighterscript
    ' Adds a DrawableOrientedSprite to be drawn for this entity - a Sprite that swaps
    ' which named animation is active based on the angle between the camera and this
    ' entity, faking a full-3D Doom/Duke3D-style billboard sprite. See
    ' docs/drawables-and-scene-objects.md for a full walkthrough.
    '
    ' @param {string} imageName - Name of the image
    ' @param {roBitmap} spriteSheet - Sprite sheet to pick cells from
    ' @param {integer} cellWidth - Width of each animation cell in pixels
    ' @param {integer} cellHeight - Height of each animation cell in pixels
    ' @param [numAngles=8] - Number of horizontal (azimuth) view buckets
    ' @param [numElevationBands=1] - Number of vertical (elevation) view bands
    ' @param [args={}] - any extra properties to set (e.g. offset_x, offset_y, rotation, scale_x, scale_y, etc.)
    ' @param [insertPosition=-1] - position among this entity's other drawables to insert at (-1 appends)
    ' @return {DrawableOrientedSprite}
    function addOrientedSprite(imageName as string, spriteSheet as roBitmap, cellWidth as integer, cellHeight as integer, numAngles = 8 as integer, numElevationBands = 1 as integer, args = {} as roAssociativeArray, insertPosition = -1 as integer) as DrawableOrientedSprite
      imageObject = new DrawableOrientedSprite(m, spriteSheet, cellWidth, cellHeight, numAngles, numElevationBands, args)
      return m.addDrawable(imageName, imageObject, insertPosition) as DrawableOrientedSprite
    end function
```

- [ ] **Step 3: Validate**

Run: `npm run validate`
Expected: PASS, no type errors.

- [ ] **Step 4: Commit**

```bash
git add src/source/engine/GameEntity.bs
git commit -m "Add GameEntity.addOrientedSprite() factory method"
```

---

## Task 5: Docs update

**Files:**
- Modify: `docs/drawables-and-scene-objects.md`

**Interfaces:**
- Consumes: none (documentation only).

- [ ] **Step 1: Add a table row**

In the drawable/SceneObject correspondence table (around line 28-32), add a row after the `DrawableSphere` row:

```markdown
| `DrawableOrientedSprite` | `SceneObjectImage`   | A `Sprite` that swaps its active animation based on the camera's angle to the entity, faking a Doom-style billboard sprite. |
```

- [ ] **Step 2: Add a section**

After the existing `DrawableSphere` section (around line 187), add:

```markdown
`DrawableOrientedSprite` is a `Sprite` that fakes full 3D orientation the way classic
Doom/Duke3D monster sprites do: instead of one animation per action, it registers one
animation per (elevation band, angle bucket) via `addOrientedAnimation()`/
`addElevationOrientedAnimation()`, and every frame swaps which one is actually playing
based on the angle between the camera and the entity - `GameEntity.addOrientedSprite`
builds one. Bucket 0 (of `numAngles`, default 8) is the entity's front facing the
camera, and buckets increase clockwise as viewed from above; `numElevationBands`
(default 1, meaning no vertical distinction) optionally adds a second axis for a sheet
that also draws a distinct top-down or bottom-up view. A bucket's frames can instead be
declared `{mirrorOf: {elevation, angle}}` to reuse another bucket's art flipped
horizontally (via a negated `scale.x`, the same mechanism a billboard's mirroring
already uses) - handy for a sheet that only draws one side profile. See
`examples/terrain`'s `Guard` entity for a runnable demo, and
`specs/2026-09-22-oriented-sprite-billboards-design.md` for the full design.
```

- [ ] **Step 3: Regenerate docs locally to confirm no markdown/JSDoc errors**

Run: `npm run docs`
Expected: completes without error; spot check `docs-site/` mentions `DrawableOrientedSprite`.

- [ ] **Step 4: Commit**

```bash
git add docs/drawables-and-scene-objects.md
git commit -m "Document DrawableOrientedSprite in the drawables/SceneObjects guide"
```

---

## Task 6: `examples/terrain` — `Guard` entity

**Files:**
- Create: `examples/terrain/src/sprites/helix_full_sheet.png` (copy of `/Users/mpearce/Downloads/helix_full_sheet.png`)
- Modify: `examples/terrain/src/source/main.bs`
- Create: `examples/terrain/src/source/Rooms/GuardPlacements.bs`
- Create: `examples/terrain/src/source/Entities/Guard.bs`
- Modify: `examples/terrain/src/source/Rooms/WorldRoom.bs`

**Interfaces:**
- Consumes: `GameEntity.addOrientedSprite()` (Task 4).
- Produces: `Guard` entities placed in `WorldRoom`, visible via `npm run build-examples`/`rokubot-examples`.

The Helix sheet is 640x1024 RGBA, an 8-column x 16-row grid of 80x64 cells. Sheet rows
8-15 (pixel y 512-1023) are an 8-direction x 8-frame walk cycle, one direction per row,
one frame per column — this is the only part of the sheet this task uses (see the design
spec's Appendix for why the top block is skipped). The exact row-to-bucket mapping below
is a best-effort starting guess from visual inspection, expected to need correction in
Task 7 once it's actually visible in the running example — don't treat the specific
row/mirror numbers here as validated.

- [ ] **Step 1: Copy the spritesheet asset**

```bash
cp /Users/mpearce/Downloads/helix_full_sheet.png examples/terrain/src/sprites/helix_full_sheet.png
```

- [ ] **Step 2: Register the bitmap**

In `examples/terrain/src/source/main.bs`, add alongside the other `loadBitmap` calls:

```brighterscript
  game.loadBitmap("guardSheet", "pkg:/sprites/helix_full_sheet.png")
```

- [ ] **Step 3: Write placement data**

```brighterscript
' src/source/Rooms/GuardPlacements.bs
' Fixed placements for Guard entities in WorldRoom - arbitrary spots near the map's
' center clearing, chosen so the free-fly camera can reach and orbit each one easily
' while verifying DrawableOrientedSprite's angle-bucket switching (issue #104).
function getGuardPlacements() as object[]
  return [
    {x: 0.0, z: 0.0, rotY: 0.0}
    {x: 60.0, z: 40.0, rotY: 90.0}
    {x: -60.0, z: 40.0, rotY: 180.0}
  ]
end function
```

- [ ] **Step 4: Write the `Guard` entity**

```brighterscript
' src/source/Entities/Guard.bs
' A Doom-style oriented-sprite character built from the Helix character spritesheet
' (helix_full_sheet.png, 640x1024, 8 cols x 16 rows of 80x64 cells) - demonstrates
' DrawableOrientedSprite (issue #104). Only the sheet's bottom 8x8 walk grid (sheet
' rows 8-15) is used; frame 0 of each direction's walk row doubles as that direction's
' idle pose, sidestepping the sheet's separate, ambiguous top idle block (see
' specs/2026-09-22-oriented-sprite-billboards-design.md's Appendix).
class Guard extends BGE.GameEntity

  sprite as BGE.DrawableOrientedSprite

  sub new(game as BGE.Game)
    super(game)
    m.name = "Guard"
  end sub

  override sub onCreate(args as roAssociativeArray)
    m.position = BGE.Math.VectorOps.create(args.x, 0, args.z)
    m.rotation = BGE.Math.VectorOps.create(0, BGE.Math.DegreesToRadians(args.rotY), 0)

    sheet = m.game.getBitmap("guardSheet")
    ' Row-major cell index for sheet row r, column c (8 columns per row).
    walkRow = function(r as integer) as integer[]
      frames = []
      for c = 0 to 7
        frames.push(r * 8 + c)
      end for
      return frames
    end function

    ' Best-effort starting guess at which sheet row is which facing - see Task 7 to
    ' verify/correct this against the actual running example.
    frontRow = walkRow(9)
    frontRightRow = walkRow(10)
    rightRow = walkRow(11)
    backRightRow = walkRow(12)
    backRow = walkRow(13)
    backLeftRow = walkRow(14)

    walkAngleFrames = [
      frontRow
      frontRightRow
      rightRow
      backRightRow
      backRow
      backLeftRow
      {mirrorOf: {elevation: 0, angle: 2}} ' left profile - mirrors the right profile row
      {mirrorOf: {elevation: 0, angle: 1}} ' front-left - mirrors front-right
    ]
    idleAngleFrames = [
      [frontRow[0]]
      [frontRightRow[0]]
      [rightRow[0]]
      [backRightRow[0]]
      [backRow[0]]
      [backLeftRow[0]]
      {mirrorOf: {elevation: 0, angle: 2}}
      {mirrorOf: {elevation: 0, angle: 1}}
    ]

    m.sprite = m.addOrientedSprite("visual", sheet, 80, 64, 8, 1, {
      drawMode: BGE.SceneObjectDrawMode.directScaled,
      banksWithCameraRoll: true
    })
    m.sprite.setAnchor(0.5, 1.0)
    m.sprite.addOrientedAnimation("walk", walkAngleFrames, 8, BGE.SpritePlayMode.Loop)
    m.sprite.addOrientedAnimation("idle", idleAngleFrames, 1, BGE.SpritePlayMode.Loop)
    m.sprite.playOrientedAnimation("idle")
  end sub

end class
```

- [ ] **Step 5: Wire `Guard` into `WorldRoom`**

In `examples/terrain/src/source/Rooms/WorldRoom.bs`, add a new private method (following the `addLowWalls()` pattern) and call it from `onCreate()`:

```brighterscript
    m.addTrees()
    m.addLowWalls()
    m.addGuards()
```

```brighterscript
  ' Guard characters demonstrating DrawableOrientedSprite (issue #104) - see
  ' GuardPlacements.bs.
  private sub addGuards()
    placements = getGuardPlacements()
    for i = 0 to placements.count() - 1
      placement = placements[i]
      m.game.addEntity(new Guard(m.game), {
        x: placement.x,
        z: placement.z,
        rotY: placement.rotY
      })
    end for
  end sub
```

- [ ] **Step 6: Build the example**

Run: `npm run build-examples` (or, faster while iterating, `cd examples/terrain && npm run build`)
Expected: builds cleanly, no compile errors.

- [ ] **Step 7: Commit**

```bash
git add examples/terrain/src/sprites/helix_full_sheet.png examples/terrain/src/source/main.bs examples/terrain/src/source/Rooms/GuardPlacements.bs examples/terrain/src/source/Entities/Guard.bs examples/terrain/src/source/Rooms/WorldRoom.bs
git commit -m "Add Guard entity to examples/terrain demoing DrawableOrientedSprite (issue #104)"
```

---

## Task 7: Manual verification and row-mapping correction

**Files:**
- Modify: `examples/terrain/src/source/Entities/Guard.bs` (only if the row mapping/mirrors from Task 6 turn out wrong)

This task is required, not optional polish — per this repo's convention, no automated
check exercises example/runtime behavior, so an actual sideload is the only way to
confirm `Guard` looks right (and the only way to pin down the Helix sheet's real
row-to-facing mapping, which was a best-effort guess in Task 6).

- [ ] **Step 1: Read the `rokubot-examples` skill**

Invoke the `rokubot-examples` skill for the exact sideload/launch/screenshot workflow and per-example gotchas before proceeding.

- [ ] **Step 2: Sideload and launch `examples/terrain`**

Follow the skill's workflow to sideload the built `examples/terrain` package and launch it into `WorldRoom` (the default starting room).

- [ ] **Step 3: Orbit the camera around a `Guard` and screenshot at each ~45-degree step**

Using the free-fly camera controls, move to face a `Guard` directly (its front, per its `rotY` placement), screenshot, then orbit roughly 45 degrees at a time around it (8 steps for a full circle), screenshotting at each step.

- [ ] **Step 4: Compare each screenshot's sprite against the expected facing**

For each screenshot, confirm the sprite's visible facing (front/three-quarter/side/back) matches what that camera angle should show relative to the `Guard`'s `rotY`. Note any step where it looks wrong (e.g. showing a back view when a front view was expected, or a mirrored profile that looks flipped upside-down rather than left-right).

- [ ] **Step 5: Fix any wrong row/mirror assignments found in Step 4**

If a mismatch was found, adjust `Guard.bs`'s `frontRow`/`frontRightRow`/etc. row assignments (which sheet row maps to which bucket) and/or the `mirrorOf` targets to match. Rebuild (`cd examples/terrain && npm run build`) and repeat Steps 2-4 until every orbit step looks correct.

- [ ] **Step 6: Confirm idle-vs-walk switching still looks right**

Stand still near a `Guard` (don't move the free-fly camera's drive input) and confirm it shows its idle pose; then move the camera to walk past it in view and confirm nothing about `playOrientedAnimation("idle")` needs to change for this demo (the example itself never calls `playOrientedAnimation("walk")` — this step just confirms idle looks correct standing still; walking would only trigger if a future example enhancement adds it, which is out of scope here).

- [ ] **Step 7: Final commit (if Step 5 required changes)**

```bash
git add examples/terrain/src/source/Entities/Guard.bs
git commit -m "Correct Guard's sheet row-to-facing mapping after visual verification"
```

- [ ] **Step 8: Run the full quality gate**

Run: `npm run check` (lint + validate + headless tests) and `npm run validate-examples`
Expected: PASS

---

## Self-Review Notes

- **Spec coverage:** `numAngles`/`numElevationBands` configurability (Tasks 1-2), zero
  `SceneObjectImage`/`SceneObject` changes (confirmed — no task touches those files),
  mirroring via `scale.x` (Task 3), error handling via `game.log(..., error)` (Tasks 1,
  3), pure-math + `Game`-backed tests (Tasks 1-3), `examples/terrain` demo + manual
  verification (Tasks 6-7), docs update (Task 5) — all covered.
- **Type consistency:** `DrawableOrientedSprite` constructor signature
  (`owner, spriteSheet, cellWidth, cellHeight, numAngles, numElevationBands, args`) is
  identical across Task 1's class definition, Task 4's `GameEntity.addOrientedSprite`,
  and Task 6's `Guard.onCreate` usage. `OrientedSpriteBucket.animationName`/`isMirror`
  field names are used consistently in Tasks 1 and 3.
- **No placeholders:** every step has real code; the only intentionally-approximate
  content is `Guard.bs`'s row mapping (Task 6), which Task 7 explicitly exists to
  verify and correct — flagged inline as a guess, not left ambiguous.
