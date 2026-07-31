# Consistent, configurable Drawable anchoring — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give `Image`/`Sprite`/`AnimatedImage`, `DrawableRectangle`, and `DrawableText` a normalized `anchor` point, unifying the previously native-only (`Image`) and ad hoc (`DrawableText`'s `alignment`) anchoring mechanisms behind one API.

**Architecture:** `Drawable` gains an `anchor` field (normalized 0-1, default `(0,0)` = top-left) and a base `getPretranslation()` formula derived from it. `Image` overrides `setAnchor()` to write the computed value through to its `roRegion`'s native pretranslation (what the plain 2D fast path already relies on via Roku's own blit). `DrawableText`'s bespoke `alignment`-based `getWorldPosition()` override is deleted and replaced with `alignment` becoming sugar for `anchor.x` (fixing a pre-existing bug in the process). `SceneObjectBillboard` gains one opt-in hook so `DrawableRectangle` and `DrawableText` — which have no native region to lean on — can apply the anchor manually in the one draw path that doesn't already consult `getPretranslation()`.

**Tech Stack:** BrighterScript compiled with `bsc`; Rooibos v6 (`rooibos-roku`) specs colocated as `*.spec.bs`; `brs-cli` for headless test runs; `rokubot` for on-device verification.

**Spec:** `specs/2026-07-30-drawable-anchor-design.md`
**Issue:** [#50](https://github.com/markwpearce/brighterscript-game-engine/issues/50)
**Branch:** `feature/drawable-anchor` (already created, spec doc already committed)

## Global Constraints

- All engine source lives under `src/source/` inside the `BGE` namespace. Specs live in `namespace tests`.
- `bslint.json` sets `inline-if-style: never` — never write a single-line `if`. Always use a multi-line `if` / `end if`.
- **A `*.spec.bs` file may contain only one `@suite` class.** Two or more silently corrupt Rooibos metadata and crash the run in a later, unrelated suite.
- **`assertEqual` is type-strict**: `1` (Integer) and `1.0` (Float) fail against each other. When a comparison fails unexpectedly, read the actual/expected *types* out of the Rooibos failure diff rather than guessing.
- Never compare whole engine objects with `assertEqual` — they embed circular references and native components. Compare a distinguishing scalar.
- Public engine methods get JSDoc-style `'` comments with `@param`/`@return`. Protected/internal ones get a plain explanatory comment.
- Per-task verification is `npm run test:ci`. The full gate before the PR is `npm run check` (lint + validate + headless tests).
- Constructing a real `BGE.Game`/`GameEntity` inside a spec works fine headlessly (see `Game.spec.bs`) — prefer it over hand-rolling engine logic in a test double.

## File Structure

**Modified:**

- `src/source/engine/drawables/Drawable.bs` — Task 1. Adds `anchor`/`anchorIsSet`/`getAnchor()`/`setAnchor()`, replaces the base `getPretranslation()`.
- `src/source/engine/drawables/Drawable.spec.bs` — Task 1.
- `src/source/engine/drawables/Image.bs` — Task 2. `setAnchor()` override, `applyAnchorToRegion()`.
- `src/source/engine/drawables/AnimatedImage.bs` — Task 2. One line added to `update()`.
- `src/source/engine/drawables/DrawableText.bs` — Task 3. Deletes the `getWorldPosition()` override, adds `update()` override + `lastAlignment`.
- `src/source/engine/drawables/DrawableText.spec.bs` — Task 3 (new file — none exists today).
- `src/source/engine/renderer/sceneObjects/SceneObjectBillboard.bs` — Task 4. New hook + `updateCanvasPosition`'s `isDirectDrawMode` branch.
- `src/source/engine/renderer/sceneObjects/SceneObjectRectangle.bs` — Task 4. Overrides the new hook.
- `src/source/engine/renderer/sceneObjects/SceneObjectText.bs` — Task 4. Overrides the new hook.
- `src/source/engine/renderer/sceneObjects/SceneObjectRectangle.spec.bs` — Task 4.
- `src/source/engine/renderer/sceneObjects/SceneObjectText.spec.bs` — Task 4 (new file — none exists today).
- `docs/drawables-and-scene-objects.md` — Task 5. Line 58's "anchored at its top left corner" claim, and the `SceneObjectBillboard` TODO's retirement.
- `examples/3d/src/source/Rooms/ImagesRoom.bs` — Task 6. Adds the bottom-anchored billboard demo.

**Not touched:** `DrawablePolygon`, `DrawableLine`, `DrawablePlane`, `Model3d` — out of scope per the design doc (no implicit rectangular box to anchor).

---

### Task 1: `Drawable` base anchor mechanism

**Files:**
- Modify: `src/source/engine/drawables/Drawable.bs` (fields ~46-56, `getPretranslation()` at 134-136)
- Test: `src/source/engine/drawables/Drawable.spec.bs`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `Drawable.getAnchor() as BGE.Math.Vector`, `Drawable.setAnchor(x as float, y as float)`, `protected Drawable.anchor as BGE.Math.Vector`, `protected Drawable.anchorIsSet as boolean`. `getPretranslation()`'s new formula: `create(-width * anchor.x, -height * anchor.y)`.

- [ ] **Step 1: Write the failing tests**

Read `src/source/engine/drawables/Drawable.spec.bs` first to match its existing `beforeEach`/suite setup (it already constructs a real `Game`/`GameEntity` — reuse that pattern, don't hand-roll one). Add:

```brightscript
    @describe("anchor / getPretranslation")

    @it("defaults to (0,0), matching today's top-left behavior")
    function _()
      drawable = new BGE.DrawableRectangle(m.entity, 100, 50)
      m.assertEqual(0.0, drawable.getAnchor().x)
      m.assertEqual(0.0, drawable.getAnchor().y)
      pretrans = drawable.getPretranslation()
      m.assertEqual(0.0, pretrans.x)
      m.assertEqual(0.0, pretrans.y)
    end function

    @it("getPretranslation derives from anchor and size once setAnchor is called")
    function _()
      drawable = new BGE.DrawableRectangle(m.entity, 100, 50)
      drawable.setAnchor(0.5, 1)
      pretrans = drawable.getPretranslation()
      m.assertEqual(-50.0, pretrans.x)
      m.assertEqual(-50.0, pretrans.y)
    end function

    @it("setAnchor bumps geometryVersion, same as setSize")
    function _()
      drawable = new BGE.DrawableRectangle(m.entity, 100, 50)
      before = drawable.geometryVersion
      drawable.setAnchor(0.5, 0.5)
      m.assertTrue(drawable.geometryVersion > before)
    end function
```

Use `BGE.DrawableRectangle` here (not a bare `Drawable` — it's abstract in spirit even though BrighterScript won't stop you instantiating it, and `DrawableRectangle` is the simplest concrete subclass with real `width`/`height`).

- [ ] **Step 2: Run tests to verify they fail**

Run: `npm run build-tests && npm run test:ci`
Expected: FAIL — `getAnchor`/`setAnchor` are not members of `Drawable`.

- [ ] **Step 3: Implement in `Drawable.bs`**

Add near the other "Values That Can Be Changed" fields (after `geometryVersion`, before `owner`):

```brightscript
    ' Normalized anchor point (0-1 on each axis) this drawable pivots around, where (0,0) is
    ' the top left corner (today's default behavior for every existing drawable) and (1,1) is
    ' the bottom right. Change it via setAnchor(), not by assigning directly - the renderer
    ' needs to know the geometry changed.
    protected anchor = BGE.Math.VectorOps.create(0, 0)

    ' Whether setAnchor() has ever been called. Image consults this to decide whether to keep
    ' honoring whatever pretranslation is already on its region (e.g. from a sprite atlas
    ' pivot) or to override it - see Image.applyAnchorToRegion().
    protected anchorIsSet as boolean = false
```

Add accessor/mutator right after `invalidateGeometry()`:

```brightscript
    function getAnchor() as BGE.Math.Vector
      return BGE.Math.VectorOps.copy(m.anchor)
    end function

    ' Sets the normalized anchor point this drawable pivots around. (0,0) is top left (the
    ' default), (0.5, 1) is bottom-center, etc. This isn't movement, so it can't be picked up
    ' by the per-frame MotionChecker dirty-check - invalidateGeometry() tells the renderer to
    ' recompute this drawable's projected geometry even though nothing moved.
    '
    ' @param {float} x
    ' @param {float} y
    sub setAnchor(x as float, y as float)
      if x = m.anchor.x and y = m.anchor.y and m.anchorIsSet
        return
      end if
      m.anchor.x = x
      m.anchor.y = y
      m.anchorIsSet = true
      m.invalidateGeometry()
    end sub
```

Replace the base `getPretranslation()`:

```brightscript
    function getPretranslation() as BGE.Math.Vector
      return BGE.Math.VectorOps.create(-m.width * m.anchor.x, -m.height * m.anchor.y)
    end function
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `npm run build-tests && npm run test:ci`
Expected: PASS for all three new tests, and every pre-existing test still passes (401 before this task).

- [ ] **Step 5: Commit**

```bash
git add src/source/engine/drawables/Drawable.bs src/source/engine/drawables/Drawable.spec.bs
git commit -m "Add a normalized anchor point to Drawable

getPretranslation() becomes a real derived accessor (-width*anchor.x,
-height*anchor.y) instead of always returning (0,0). Default anchor (0,0)
keeps every existing drawable's behavior unchanged until setAnchor() is
called.

Part of #50"
```

---

### Task 2: `Image` writes anchor through to its region (`Sprite`/`AnimatedImage` included)

**Files:**
- Modify: `src/source/engine/drawables/Image.bs`, `src/source/engine/drawables/AnimatedImage.bs` (`update()` at line ~34-48)
- Test: `src/source/engine/drawables/Model3d.spec.bs`'s sibling — actually use a new file: `src/source/engine/drawables/Image.spec.bs` (none exists today; check with `ls src/source/engine/drawables/*.spec.bs` before assuming — if it truly doesn't exist, create it following `Drawable.spec.bs`'s suite/beforeEach pattern)

**Interfaces:**
- Consumes: `Drawable.anchor`, `Drawable.anchorIsSet`, `Drawable.setAnchor()` from Task 1.
- Produces: `Image.applyAnchorToRegion()` (protected), consumed by `AnimatedImage.update()` in this same task.

- [ ] **Step 1: Check for an existing Image spec file**

Run: `ls src/source/engine/drawables/*.spec.bs`

If `Image.spec.bs` doesn't exist, create it. Model the suite/`beforeEach` on `Drawable.spec.bs` (real `Game`/`GameEntity`, a real `roBitmap`-backed `roRegion` — see how `Drawable.spec.bs` or `SceneObjectImage.spec.bs` construct one for a `new BGE.Image(...)`).

- [ ] **Step 2: Write the failing tests**

```brightscript
    @describe("setAnchor")

    @it("writes the computed pretranslation through to the region")
    function _()
      image = new BGE.Image(m.entity, m.testRegion)
      image.setAnchor(0.5, 1)
      m.assertEqual(-1.0 * (image.getSize().width / 2), image.region.GetPretranslationX())
      m.assertEqual(-1.0 * image.getSize().height, image.region.GetPretranslationY())
    end function

    @it("leaves the region's existing pretranslation alone until setAnchor is called")
    function _()
      m.testRegion.SetPretranslation(7, 9)
      image = new BGE.Image(m.entity, m.testRegion)
      m.assertEqual(7.0, image.region.GetPretranslationX())
      m.assertEqual(9.0, image.region.GetPretranslationY())
    end function
```

(Adjust `m.testRegion`/`m.entity` to whatever names the file's `beforeEach` actually uses.)

For `AnimatedImage`, add to the same file or a sibling `AnimatedImage.spec.bs` if one exists — check first:

```brightscript
    @it("reapplies the anchor to a new cell region after a frame swap")
    function _()
      regionA = CreateObject("roRegion", m.testBitmap, 0, 0, 20, 10)
      regionB = CreateObject("roRegion", m.testBitmap, 20, 0, 40, 30)
      animImage = new BGE.AnimatedImage(m.entity, [regionA, regionB])
      animImage.setAnchor(0.5, 1)
      animImage.index = 1
      animImage.update()
      m.assertEqual(-1.0 * (40 / 2), regionB.GetPretranslationX())
      m.assertEqual(-1.0 * 30, regionB.GetPretranslationY())
    end function
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `npm run build-tests && npm run test:ci`
Expected: FAIL — `setAnchor` on `Image` still uses the base no-op-on-region behavior (the region's pretranslation is never touched).

- [ ] **Step 4: Implement in `Image.bs`**

```brightscript
    override sub setAnchor(x as float, y as float)
      super.setAnchor(x, y)
      m.applyAnchorToRegion()
    end sub

    ' Pushes the anchor-derived pretranslation onto the region so Roku's own DrawObject/
    ' DrawScaledObject picks it up natively in the plain 2D draw path - see
    ' getPretranslation(), which reads it straight back off the region.
    protected sub applyAnchorToRegion()
      if m.anchorIsSet and invalid <> m.region
        m.region.SetPretranslation(-m.width * m.anchor.x, -m.height * m.anchor.y)
      end if
    end sub
```

Place both right after the existing `getPretranslation()` override.

- [ ] **Step 5: Implement in `AnimatedImage.bs`**

In `update()`, right after `m.height = m.region.getHeight()`:

```brightscript
        m.width = m.region.getWidth()
        m.height = m.region.getHeight()
        m.applyAnchorToRegion()
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `npm run build-tests && npm run test:ci`
Expected: PASS for all new tests, all 404 (401 + 3) passing overall.

- [ ] **Step 7: Commit**

```bash
git add src/source/engine/drawables/Image.bs src/source/engine/drawables/AnimatedImage.bs src/source/engine/drawables/Image.spec.bs
git commit -m "Image.setAnchor writes through to the region's native pretranslation

Keeps the plain 2D fast path correct via Roku's own DrawObject/
DrawScaledObject, which already apply a region's pretranslation
natively. AnimatedImage reapplies it on every cell swap, since cells can
differ in size and a one-time push would only reach whichever region
happened to be active at that moment.

Part of #50"
```

---

### Task 3: `DrawableText` — `alignment` becomes anchor.x sugar

**Files:**
- Modify: `src/source/engine/drawables/DrawableText.bs` (`getWorldPosition()` at 67-76, add `update()`)
- Test: `src/source/engine/drawables/DrawableText.spec.bs` (new file — none exists today)

**Interfaces:**
- Consumes: `Drawable.anchor`/`setAnchor()`/`getPretranslation()` from Task 1.
- Produces: nothing new consumed by later tasks (Task 4's `SceneObjectText` doesn't depend on this task's internals, only on `getPretranslation()` from Task 1).

- [ ] **Step 1: Write the failing tests**

Create `src/source/engine/drawables/DrawableText.spec.bs`. Model the suite/`beforeEach` on `Drawable.spec.bs` (real `Game`, real `GameEntity`, `m.entity.game.getFont("default")` for the font).

```brightscript
namespace tests

  @suite("BGE.DrawableText")
  class DrawableTextTests extends rooibos.BaseTestSuite

    entity as BGE.GameEntity

    protected override function beforeEach()
      m.game = new BGE.Game(320, 240)
      m.entity = new BGE.GameEntity(m.game)
    end function

    @describe("alignment / anchor")

    @it("defaults to left, which is anchor.x = 0")
    function _()
      text = new BGE.DrawableText(m.entity, "hi", m.game.getFont("default"))
      m.assertEqual(0.0, text.getAnchor().x)
    end function

    @it("center alignment sets anchor.x to 0.5 once update() runs")
    function _()
      text = new BGE.DrawableText(m.entity, "hi", m.game.getFont("default"))
      text.alignment = BGE.UI.HorizAlignment.center
      text.update()
      m.assertEqual(0.5, text.getAnchor().x)
    end function

    @it("right alignment sets anchor.x to 1, shifting world position by -width (not -height)")
    function _()
      text = new BGE.DrawableText(m.entity, "hi", m.game.getFont("default"))
      text.alignment = BGE.UI.HorizAlignment.right
      text.update()
      width = text.getSize().width
      height = text.getSize().height
      m.assertEqual(1.0, text.getAnchor().x)
      pretrans = text.getPretranslation()
      m.assertEqual(-1.0 * width, pretrans.x)
      m.assertNotEqual(-1.0 * height, pretrans.x)
    end function

    @it("anchor.y is independently settable")
    function _()
      text = new BGE.DrawableText(m.entity, "hi", m.game.getFont("default"))
      text.setAnchor(text.getAnchor().x, 1)
      m.assertEqual(1.0, text.getAnchor().y)
      m.assertEqual(0.0, text.getAnchor().x)
    end function

  end class

end namespace
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `npm run build-tests && npm run test:ci`
Expected: FAIL — `alignment` doesn't touch `anchor` at all yet (base `Drawable.getAnchor()` always reports `(0,0)`, and the right-align case reads `getPretranslation()` returning `(0,0)`, not `-width`).

- [ ] **Step 3: Implement in `DrawableText.bs`**

Delete the existing `getWorldPosition()` override (lines 67-76) entirely — `DrawableText` reverts to the plain `Drawable.getWorldPosition()`.

Add a field near the other `protected` fields:

```brightscript
    protected lastAlignment as BGE.UI.HorizAlignment = BGE.UI.HorizAlignment.left
```

Add, after `getTextImage()`:

```brightscript
    override sub update()
      if m.alignment <> m.lastAlignment
        m.lastAlignment = m.alignment
        x = 0.0
        if m.alignment = BGE.UI.HorizAlignment.center
          x = 0.5
        else if m.alignment = BGE.UI.HorizAlignment.right
          x = 1.0
        end if
        m.setAnchor(x, m.getAnchor().y)
      end if
    end sub
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `npm run build-tests && npm run test:ci`
Expected: PASS for all 4 new tests, all previously-passing tests still pass.

- [ ] **Step 5: Commit**

```bash
git add src/source/engine/drawables/DrawableText.bs src/source/engine/drawables/DrawableText.spec.bs
git commit -m "DrawableText: make alignment sugar for anchor.x

Deletes the bespoke getWorldPosition() override that shifted x by
-width/2 for center and (buggily) -height for right. alignment now
sets anchor.x through the unified anchor mechanism instead, fixing the
right-align bug (correct -width shift) as a side effect. anchor.y stays
independently settable for vertical anchoring.

Part of #50"
```

---

### Task 4: Plain 2D fast path for `DrawableRectangle` and `DrawableText`

**Files:**
- Modify: `src/source/engine/renderer/sceneObjects/SceneObjectBillboard.bs` (`updateCanvasPosition` at 419-446)
- Modify: `src/source/engine/renderer/sceneObjects/SceneObjectRectangle.bs`
- Modify: `src/source/engine/renderer/sceneObjects/SceneObjectText.bs`
- Test: `src/source/engine/renderer/sceneObjects/SceneObjectRectangle.spec.bs`, and a new `src/source/engine/renderer/sceneObjects/SceneObjectText.spec.bs` (none exists today — check with `ls` first)

**Interfaces:**
- Consumes: `Drawable.getPretranslation()`/`setAnchor()` from Task 1; nothing from Tasks 2-3.
- Produces: `SceneObjectBillboard.needsManualPretranslationForDirectMode() as boolean` (protected, default `false`), consumed nowhere else in this plan but is the extension point any future non-region billboard subclass should override.

- [ ] **Step 1: Write the failing tests**

For `SceneObjectRectangle.spec.bs`, read the existing file first to match its `beforeEach`/draw-mode-setup pattern (per CLAUDE.md, this needs a real `Game`/`GameEntity`, `Renderer.setupCameraForFrame()` before `drawScene()`). Add:

```brightscript
    @describe("anchor in the plain 2D fast path")

    @it("shifts the drawn rectangle by its anchor under directToCamera")
    function _()
      rect = m.entity.addRectangle("body", 100, 50, {})
      rect.setAnchor(0.5, 0.5)
      m.game.canvas.renderer.setupCameraForFrame()
      m.game.canvas.renderer.drawScene()
      sceneObj = rect.sceneObjects.items()[0].value
      m.assertNotInvalid(sceneObj.canvasPosition)
      ' canvasPosition is the quad's top-left; centering a 100x50 rect on the entity's
      ' position should shift it left by 50 and up by 25 (canvas is y-down) from the
      ' unanchored position.
      unanchored = new BGE.DrawableRectangle(m.entity, 100, 50, {})
      m.entity.addDrawable("unanchored", unanchored)
      m.game.canvas.renderer.drawScene()
      unanchoredSceneObj = unanchored.sceneObjects.items()[0].value
      m.assertEqual(unanchoredSceneObj.canvasPosition.x - 50.0, sceneObj.canvasPosition.x)
      m.assertEqual(unanchoredSceneObj.canvasPosition.y - 25.0, sceneObj.canvasPosition.y)
    end function
```

Check the actual `beforeEach` in the existing file before finalizing this test — adjust helper calls (`addRectangle`, `addDrawable`, how `sceneObjects` is reached) to match what's really there rather than guessing further.

For `SceneObjectText.spec.bs` (new file, mirror the pattern), add an equivalent test using `m.entity.addText(...)` (check `GameEntity.bs` for the exact helper name/signature first) with `setAnchor(0.5, 0)` and asserting the canvas position shifts left by half the text's rendered width.

- [ ] **Step 2: Run tests to verify they fail**

Run: `npm run build-tests && npm run test:ci`
Expected: FAIL — `canvasPosition` is identical with or without `setAnchor()` in `directToCamera`/`matchCamera` mode.

- [ ] **Step 3: Implement the hook in `SceneObjectBillboard.bs`**

Add near `needsCanvasCornerPoints()` (line ~455):

```brightscript
    ' Whether this object's plain 2D draw path (directToCamera/matchCamera) gets its anchor
    ' applied automatically some other way, so updateCanvasPosition should leave canvasPosition
    ' alone. True for anything backed by a native roRegion (e.g. SceneObjectImage), since
    ' Roku's own DrawObject/DrawScaledObject already apply the region's pretranslation for
    ' free. False (the default) for anything without a region to lean on - it needs the
    ' anchor applied manually here instead.
    '
    ' @return {boolean}
    protected function needsManualPretranslationForDirectMode() as boolean
      return false
    end function
```

Modify `updateCanvasPosition`'s `isDirectDrawMode` branch (lines 420-427):

```brightscript
      if isDirectDrawMode(drawMode)
        worldPos = m.worldPosition
        if m.needsManualPretranslationForDirectMode()
          pretrans = m.drawable.getPretranslation()
          worldPos = BGE.Math.VectorOps.add(worldPos, BGE.Math.VectorOps.create(
          pretrans.x * m.drawable.scale.x, -pretrans.y * m.drawable.scale.y, 0))
        end if
        m.canvasPosition = rendererObj.worldPointToCanvasPoint(worldPos)
        if invalid = m.canvasPosition
          return false
        end if
        if m.needsCanvasCornerPoints()
          m.updateCanvasPointsForDirectMode()
        end if
```

- [ ] **Step 4: Override the hook in `SceneObjectRectangle.bs` and `SceneObjectText.bs`**

In `SceneObjectRectangle.bs`, near `needsCanvasCornerPoints()`:

```brightscript
    protected override function needsManualPretranslationForDirectMode() as boolean
      return true
    end function
```

Same override, verbatim, in `SceneObjectText.bs`.

- [ ] **Step 5: Run tests to verify they pass**

Run: `npm run build-tests && npm run test:ci`
Expected: PASS for the new tests. Re-run the full suite and confirm `SceneObjectImage`-related tests are unaffected (the hook's default is `false`, so `Image`'s behavior is untouched).

- [ ] **Step 6: Commit**

```bash
git add src/source/engine/renderer/sceneObjects/SceneObjectBillboard.bs src/source/engine/renderer/sceneObjects/SceneObjectRectangle.bs src/source/engine/renderer/sceneObjects/SceneObjectText.bs src/source/engine/renderer/sceneObjects/SceneObjectRectangle.spec.bs src/source/engine/renderer/sceneObjects/SceneObjectText.spec.bs
git commit -m "Apply anchor manually in the plain 2D fast path for Rectangle/Text

SceneObjectBillboard.updateCanvasPosition's isDirectDrawMode branch
never consulted pretranslation at all - Image gets it for free via the
native region blit, but Rectangle (no region) and Text (region carries
no pretranslation) had no such channel. New opt-in hook,
needsManualPretranslationForDirectMode(), defaults to false so
SceneObjectImage is completely untouched; SceneObjectRectangle and
SceneObjectText override it to true.

Part of #50"
```

---

### Task 5: Docs

**Files:**
- Modify: `docs/drawables-and-scene-objects.md` (line 58's rectangle-anchoring paragraph; the `SceneObjectBillboard.drawToCanvas` TODO mention, if the doc quotes it - check with `grep -n "locked position" docs/drawables-and-scene-objects.md` first, since the design doc quotes the TODO from the source file, not necessarily from this doc)

**Interfaces:**
- Consumes: nothing (documentation only).
- Produces: nothing consumed by other tasks.

- [ ] **Step 1: Check what the doc currently says about the TODO**

Run: `grep -n "locked position\|anchor" docs/drawables-and-scene-objects.md`

- [ ] **Step 2: Update the rectangle-anchoring paragraph**

At line 58, replace:

```markdown
A rectangle is anchored at its **top left corner** and extends right and downwards on screen, the
same as an `Image` - so an entity whose `position` is meant to be its center wants the drawable
offset by half its size:
```

with:

```markdown
A rectangle is anchored at its **top left corner** by default (anchor `(0, 0)`) and extends right
and downwards on screen, the same as an `Image`. Call `setAnchor(x, y)` with normalized 0-1
coordinates to pivot around a different point instead - `setAnchor(0.5, 0.5)` centers it on the
entity's position, `setAnchor(0.5, 1)` plants its bottom edge there (handy for a sprite that should
grow from the ground up rather than from its center). Every `Drawable` with a rectangular
width/height (`Image`, `Sprite`/`AnimatedImage`, `DrawableRectangle`, `DrawableText`) supports this
the same way. Without `setAnchor()`, nothing changes - offsetting the drawable by half its size to
fake a centered anchor still works exactly as before:
```

- [ ] **Step 3: Remove or update the standing TODO if this doc quotes it**

If the `grep` from Step 1 shows the "locked position... trees" TODO text present in this doc, replace it with a short note that it's resolved: `setAnchor(0.5, 1)` on a billboard's `Drawable` now gives it exactly that "feet on the ground" anchoring. If the TODO isn't quoted in this doc at all (it only lives as a source comment in `SceneObjectBillboard.bs`), instead update that source comment directly:

Run: `grep -n "locked position" src/source/engine/renderer/sceneObjects/SceneObjectBillboard.bs`

Replace the TODO comment block (around `drawToCanvas`'s `directScaled` branch) with:

```brightscript
        ' A Drawable's setAnchor(x, y) (e.g. (0.5, 1) for "feet on the ground") controls this -
        ' see Drawable.getPretranslation(). drawRegion places the region by its *top left*
        ' corner, so that's what it has to be given - passing the quad's center drew every
        ' directScaled sprite half its own size down and to the right of where it belonged.
```

- [ ] **Step 4: Commit**

```bash
git add docs/drawables-and-scene-objects.md src/source/engine/renderer/sceneObjects/SceneObjectBillboard.bs
git commit -m "docs: describe the new Drawable anchor mechanism

Part of #50"
```

---

### Task 6: Worked example + on-device verification

**Files:**
- Modify: `examples/3d/src/source/Rooms/ImagesRoom.bs`

**Interfaces:**
- Consumes: `Drawable.setAnchor()` (Task 1), `Image` write-through (Task 2).
- Produces: nothing consumed by other tasks - this is the terminal, demonstrable deliverable.

- [ ] **Step 1: Read the existing `ImagesRoom.bs` and its `ImageCube` entity**

Run: `cat examples/3d/src/source/Rooms/ImagesRoom.bs` and find the `ImageCube` entity it constructs (likely `examples/3d/src/source/Entities/ImageCube.bs`) to see how it builds its `Image` drawable(s) and what draw mode it uses, so the new billboard is added consistently with existing conventions in this file.

- [ ] **Step 2: Add a bottom-anchored billboard to `ImagesRoom.onCreate`**

Add a second, simple entity - a plain `GameEntity` holding one `Image` drawable using the existing `roku-logo-purple.png` bitmap (already loaded somewhere in this example's asset registry - check `Game.loadBitmap`/`getBitmap` calls in the example's `main.bs` or room setup for the exact registered name to reuse), in `SceneObjectDrawMode.directScaled`, positioned at a fixed world point representing "ground level" (e.g. `y = 0`), with:

```brightscript
billboardImage.drawMode = BGE.SceneObjectDrawMode.directScaled
billboardImage.setAnchor(0.5, 1)
```

Place it a reasonable distance from the existing cube(s) so it's visible without overlapping. Add a second, unanchored (`setAnchor` never called) copy of the same billboard next to it for visual comparison, so cycling the camera closer/further shows one sprite's base staying planted on the ground while the other's center stays fixed instead.

- [ ] **Step 3: Build the example**

Run: `npm run build` (engine) then, from `examples/3d`, `npm install && npm run build` (or from the repo root, `npm run prepare-examples && npm run build-examples` if the example's `node_modules` needs refreshing against the just-built engine).

- [ ] **Step 4: Verify on-device via rokubot**

Check `.claude/skills/rokubot-examples/SKILL.md` for the current workflow (sideload/launch/act/screenshot commands and per-example gotchas) rather than guessing the CLI invocation here. Sideload `examples/3d`, navigate to `ImagesRoom`, and take a screenshot. Confirm both billboards render or a bug will need investigating with a systematic-debugging pass before the CLAUDE.md-mandated example validation is considered complete - do not just assert success without looking.

If the camera in this room doesn't already support moving closer/further, don't add camera controls as part of this task - a single static screenshot showing the two billboards positioned differently (one with its visual mass centered on the anchor point, one with its top-left corner there) is sufficient to demonstrate the feature; only add movement if it's already trivial given what's in the room.

- [ ] **Step 5: Commit**

```bash
git add examples/3d/src/source/Rooms/ImagesRoom.bs
git commit -m "examples/3d: demonstrate Drawable.setAnchor with a bottom-anchored billboard

Closes out #50's worked example - a directScaled sprite anchored at
(0.5, 1) keeps its base planted at a fixed world point, next to an
unanchored copy for comparison.

Part of #50"
```

---

### Task 7: Full quality gate and PR

**Files:** none (verification only)

- [ ] **Step 1: Run the full local gate**

Run: `npm run check` (lint + validate + headless tests). Fix anything that fails before proceeding - do not skip or silence a failure.

- [ ] **Step 2: Validate every example still builds**

Run: `npm run check:all`

- [ ] **Step 3: Push and open the PR**

```bash
git push -u origin feature/drawable-anchor
gh pr create --repo markwpearce/brighterscript-game-engine \
  --title "Consistent, configurable anchoring for every Drawable" \
  --body "Fixes #50. See specs/2026-07-30-drawable-anchor-design.md and specs/2026-07-30-drawable-anchor-plan.md for the full design/plan."
```

Fill in the PR body's summary/test-plan sections from what actually happened across Tasks 1-6 (new tests added, on-device verification result) rather than copying this plan verbatim.
