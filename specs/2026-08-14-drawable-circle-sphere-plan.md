# DrawableCircle and DrawableSphere Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `DrawableCircle` (a flat disc that can foreshorten to an ellipse in 3D) and `DrawableSphere` (always renders as an undistorted circle) to the engine, per [#100](https://github.com/markwpearce/brighterscript-game-engine/issues/100).

**Architecture:** Fill is a texture blit of a shipped `circle.png` asset through `SceneObjectBillboard`'s existing pinned-corners/tint/cache machinery (exactly like `SceneObjectImage`) - no new Renderer draw method. Outline is N points around the ellipse inscribed in the object's own transformed `canvasPoints` quad, stroked through the existing generic `getOutlineCanvasPoints()`/`drawPolygonOutline` hook - also no new Renderer method. `DrawableSphere` reuses `SceneObjectCircle` unchanged and just forces `drawMode = directScaled` in its own constructor, since `SceneObject.getActualDrawMode()` only resolves `matchCamera` through the camera and passes any other explicit value straight through.

**Tech Stack:** BrighterScript (engine), Node.js + `pureimage` (one-time asset generation script), Rooibos (`rooibos-roku`) for specs.

Full design rationale: `specs/2026-08-14-drawable-circle-sphere-design.md`.

## Global Constraints

- One `@suite` class per `*.spec.bs` file (Rooibos v6 corrupts multi-suite files - see CLAUDE.md).
- `assertEqual` is type-strict - match Integer vs Float exactly (see CLAUDE.md's Unit Tests section); when unsure, run the test once and read the actual/expected types off the failure diff.
- Public API methods get JSDoc-style `'` comments (`@param`, `@return`) directly above them, matching every existing public engine method.
- Run `npm run validate` after any engine source change; run `npm run test:ci` after any spec change. Both must pass before moving to the next task.
- Never edit on `main` directly - all work happens on `feature/drawable-circle-sphere` (already checked out).

---

### Task 1: Generate the `circle.png` asset

**Files:**
- Create: `scripts/generate-circle-asset.js`
- Create: `src/source/images/circle.png` (generated output, committed)
- Modify: `package.json:20-25` (add an npm script next to `docs`/`docs-server`)

**Interfaces:**
- Produces: `src/source/images/circle.png`, a 128x128 transparent-background PNG with an opaque white filled circle (radius 62, 2px transparent margin) - the asset every later task's `Game.setUpCircleAsset()` and `SceneObjectCircle` rely on.

- [ ] **Step 1: Write the generator script**

`pureimage` 0.4.20's canvas defaults to an opaque black background (not transparent), and its path-based `ctx.fill()` after `ctx.arc()` alone does nothing (confirmed by spiking it) - it only fills correctly when the path starts with an explicit `moveTo` onto the arc's own starting point before the `arc()`/`closePath()` call. Both quirks are handled below.

```javascript
#!/usr/bin/env node
// Generates the engine's shipped circle fill asset (see DrawableCircle) - a
// transparent-background PNG with an opaque white filled circle, scaled and
// tinted at draw time the same way any other texture-backed drawable is.
//
// pureimage 0.4.20 quirks this works around (confirmed by hand):
//   - PImage.make() defaults every pixel to opaque black, not transparent -
//     every pixel is explicitly reset to fully transparent first.
//   - ctx.fill() after ctx.beginPath()+ctx.arc() alone silently fills
//     nothing - it only works when the path starts with an explicit
//     moveTo() onto the arc's own starting point first.
//
// Can be run standalone: node scripts/generate-circle-asset.js
// or required as a module: generateCircleAsset(outPath)

const path = require('path');
const fs = require('fs');
const PImage = require('pureimage');

const SIZE = 128;
const MARGIN = 2;

async function generateCircleAsset(outPath) {
  const img = PImage.make(SIZE, SIZE);

  for (let y = 0; y < SIZE; y++) {
    for (let x = 0; x < SIZE; x++) {
      img.setPixelRGBA(x, y, 0x00000000);
    }
  }

  const ctx = img.getContext('2d');
  ctx.fillStyle = '#ffffff';
  const cx = SIZE / 2;
  const cy = SIZE / 2;
  const r = SIZE / 2 - MARGIN;
  ctx.beginPath();
  ctx.moveTo(cx + r, cy);
  ctx.arc(cx, cy, r, 0, Math.PI * 2, false);
  ctx.closePath();
  ctx.fill();

  fs.mkdirSync(path.dirname(outPath), { recursive: true });
  await PImage.encodePNGToStream(img, fs.createWriteStream(outPath));
}

module.exports = { generateCircleAsset };

if (require.main === module) {
  const outPath = path.join(__dirname, '..', 'src', 'source', 'images', 'circle.png');
  generateCircleAsset(outPath)
    .then(() => console.log(`Generated ${outPath}`))
    .catch((err) => {
      console.error(err);
      process.exit(1);
    });
}
```

- [ ] **Step 2: Add the npm script**

In `package.json`, add this line next to the other `generate-example-images.js`-style scripts (immediately after `"docs-server"`):

```json
        "generate-circle-asset": "node scripts/generate-circle-asset.js",
```

- [ ] **Step 3: Run it and verify the output**

Run: `npm run generate-circle-asset`
Expected: prints `Generated .../src/source/images/circle.png`, and the file exists.

Verify transparency/fill with a throwaway check (not committed, just for this step):

```bash
node -e "
const PImage = require('pureimage');
const fs = require('fs');
PImage.decodePNGFromStream(fs.createReadStream('src/source/images/circle.png')).then(img => {
  console.log('corner:', (img.getPixelRGBA(1,1)>>>0).toString(16).padStart(8,'0'));
  console.log('center:', (img.getPixelRGBA(64,64)>>>0).toString(16).padStart(8,'0'));
});
"
```
Expected: `corner: 00000000` (transparent), `center: ffffffff` (opaque white).

- [ ] **Step 4: Confirm `bsc` copies it verbatim**

Run: `npm run build`
Expected: no errors, and `build/source/images/circle.png` exists (`ls build/source/images/circle.png`).

- [ ] **Step 5: Commit**

```bash
git add scripts/generate-circle-asset.js src/source/images/circle.png package.json
git commit -m "Add circle.png asset generator for DrawableCircle (#100)"
```

---

### Task 2: `Game` locates and caches the circle image region

**Files:**
- Modify: `src/source/engine/Game.bs:66-70` (private fields), `:143` (constructor), after `:236` (new private method next to `setUpFonts()`), and add a public accessor near the other Bitmap functions (`:1490`+)
- Test: `src/source/engine/Game.spec.bs`

**Interfaces:**
- Consumes: `Game.loadBitmap(bitmapName as string, path as dynamic) as boolean`, `Game.getBitmap(bitmapName as string) as roBitmap` (both already exist, `Game.bs:1499`/`:1530`).
- Produces: `Game.getCircleImageRegion() as roRegion` - returns the shared circle texture region, or `invalid` if the asset couldn't be located (never throws). Task 4's `SceneObjectCircle` calls this.

- [ ] **Step 1: Write the failing test**

In `src/source/engine/Game.spec.bs`, add a new `@describe` block (after the existing ones, before `end class`):

```brightscript
    @describe("getCircleImageRegion")

    @it("locates and returns the engine's shipped circle asset")
    function _()
      region = m.game.getCircleImageRegion()
      m.assertNotInvalid(region)
    end function
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm run test:ci`
Expected: FAIL - `getCircleImageRegion` is not a member of `BGE.Game` (compile error surfaced by `test:ci`'s build step).

- [ ] **Step 3: Implement `setUpCircleAsset()` and `getCircleImageRegion()`**

In `src/source/engine/Game.bs`, add a private field alongside `fontRegistry` (line 70):

```brightscript
    private fontRegistry as roFontRegistry = CreateObject("roFontRegistry")
    private circleImageRegion as roRegion = invalid
```

In the constructor, call the new setup method right after `m.setUpFonts()` (line 143):

```brightscript
      ' Register all fonts in package
      m.setUpFonts()
      m.setUpCircleAsset()
```

Add the private method right after `setUpFonts()` (after line 236):

```brightscript
    ' Locates and loads the engine's own shipped circle.png asset (see DrawableCircle),
    ' caching a single shared roRegion every DrawableCircle/DrawableSphere instance draws
    ' from. The on-disk path differs depending on how this engine was consumed - a real
    ' `ropm install` nests it under the package's ropm module name
    ' (roku_modules/brighterscriptgameengine/images/circle.png), while examples/*'s
    ' file-copy trick has no such nesting (roku_modules/source/images/circle.png) - so
    ' this is located the same way setUpFonts() locates consumer-supplied fonts: search
    ' for it by name rather than assuming a fixed path.
    '
    ' @return {void}
    private sub setUpCircleAsset()
      matches = m.filesystem.FindRecurse("pkg:/source/", "circle.png")
      for each relativePath in matches
        fullPath = "pkg:/source/" + relativePath
        if m.loadBitmap("__bge_circle_asset", fullPath)
          bitmap = m.getBitmap("__bge_circle_asset")
          m.circleImageRegion = CreateObject("roRegion", bitmap, 0, 0, bitmap.getWidth(), bitmap.getHeight())
          exit for
        end if
      end for
    end sub


    ' The engine's shared circle fill texture, used by every DrawableCircle/DrawableSphere
    ' instance. `invalid` if the asset couldn't be located (should not happen in a normal
    ' install - see setUpCircleAsset()).
    '
    ' @return {roRegion}
    function getCircleImageRegion() as roRegion
      return m.circleImageRegion
    end function
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npm run test:ci`
Expected: PASS.

- [ ] **Step 5: Run full validation**

Run: `npm run validate`
Expected: no errors.

- [ ] **Step 6: Commit**

```bash
git add src/source/engine/Game.bs src/source/engine/Game.spec.bs
git commit -m "Locate and cache the engine's circle asset on Game (#100)"
```

---

### Task 3: Add `SceneObjectType.Circle`

**Files:**
- Modify: `src/source/engine/renderer/sceneObjects/SceneObject.bs:6-16`

**Interfaces:**
- Produces: `BGE.SceneObjectType.Circle` (string value `"Circle"`) - Task 4's `SceneObjectCircle` constructor passes this to its `super.new()`.

- [ ] **Step 1: Add the enum value**

```brightscript
  enum SceneObjectType
    Line = "Line"
    Rectangle = "Rectangle"
    Text = "Text"
    Bitmap = "Bitmap"
    Polygon = "Polygon"
    Billboard = "Billboard"
    Model = "Model"
    Plane = "Plane"
    ParallaxLayer = "ParallaxLayer"
    Circle = "Circle"
  end enum
```

- [ ] **Step 2: Run validate**

Run: `npm run validate`
Expected: no errors (this is an additive enum change, nothing else references it yet).

- [ ] **Step 3: Commit**

```bash
git add src/source/engine/renderer/sceneObjects/SceneObject.bs
git commit -m "Add SceneObjectType.Circle (#100)"
```

---

### Task 4: `DrawableCircle` and `SceneObjectCircle`

**Files:**
- Create: `src/source/engine/drawables/DrawableCircle.bs`
- Create: `src/source/engine/renderer/sceneObjects/SceneObjectCircle.bs`
- Test: `src/source/engine/drawables/DrawableCircle.spec.bs`
- Test: `src/source/engine/renderer/sceneObjects/SceneObjectCircle.spec.bs`

**Interfaces:**
- Consumes: `Game.getCircleImageRegion() as roRegion` (Task 2), `BGE.SceneObjectType.Circle` (Task 3), `BGE.RendererHelpers.createRegionWithId(region as roRegion, id as string) as RegionWithId` (existing, `RendererHelpers.bs:25`), `BGE.Math.CornerPoints` fields `topLeft`/`topRight`/`bottomLeft` and `getCenter()` (existing, `CornerPoints.bs`), `BGE.Math.VectorOps.add/subtract/scale` (existing), `BGE.Math.PI` (existing, `math.bs:27`).
- Produces: `DrawableCircle(owner as GameEntity, radius as float, args = {} as roAssociativeArray)`, `DrawableCircle.setRadius(radius as float)`, `DrawableCircle.radius as float`, `DrawableCircle.outlineSegments as integer`. Task 5 (`DrawableSphere`) extends this class; Task 6 (`GameEntity.addCircle`) constructs it directly.

- [ ] **Step 1: Write the failing specs**

Create `src/source/engine/drawables/DrawableCircle.spec.bs`:

```brightscript
namespace tests

  ' DrawableCircle is a plain data holder - radius/outlineSegments/color/outline - and the
  ' SceneObjectCircle it registers does all the drawing. See SceneObjectCircle.spec.bs for
  ' the drawing side.
  @suite("BGE.DrawableCircle")
  class DrawableCircleTests extends rooibos.BaseTestSuite

    game as BGE.Game
    entity as BGE.GameEntity
    circle as BGE.DrawableCircle

    protected override function beforeEach()
      m.game = new BGE.Game(320, 240)
      m.entity = new BGE.GameEntity(m.game, {name: "TestEntity"})
      m.circle = new BGE.DrawableCircle(m.entity, 20)
    end function

    @describe("construction")

    @it("takes its radius from the constructor")
    function _()
      m.assertEqual(20.0, m.circle.radius)
    end function

    @it("sets width/height to the diameter")
    function _()
      size = m.circle.getSize()
      m.assertEqual(40.0, size.width)
      m.assertEqual(40.0, size.height)
    end function

    @it("has no outline by default")
    function _()
      m.assertFalse(m.circle.hasOutline())
    end function

    @it("defaults outlineSegments to 24")
    function _()
      m.assertEqual(24, m.circle.outlineSegments)
    end function

    @it("applies args from the constructor")
    function _()
      circ = new BGE.DrawableCircle(m.entity, 10, {
        outlineRGBA: BGE.ColorsRGB.Red,
        outlineWidth: 3,
        outlineSegments: 12
      })
      m.assertTrue(circ.hasOutline())
      m.assertEqual(3, circ.outlineWidth)
      m.assertEqual(12, circ.outlineSegments)
    end function

    @describe("setRadius")

    @it("changes the reported radius and size")
    function _()
      m.circle.setRadius(50)
      m.assertEqual(50.0, m.circle.radius)
      size = m.circle.getSize()
      m.assertEqual(100.0, size.width)
      m.assertEqual(100.0, size.height)
    end function

    @it("invalidates geometry, since a resize isn't movement and can't be dirty-checked")
    function _()
      versionBefore = m.circle.geometryVersion
      m.circle.setRadius(50)
      m.assertEqual(versionBefore + 1, m.circle.geometryVersion)
    end function

    @it("does nothing when set to the radius it already is")
    function _()
      versionBefore = m.circle.geometryVersion
      m.circle.setRadius(20)
      m.assertEqual(versionBefore, m.circle.geometryVersion)
    end function

    @describe("addToScene")

    @it("registers a SceneObjectCircle with the renderer")
    function _()
      sceneObj = m.circle.addToScene(m.game.canvas.renderer)
      m.assertNotInvalid(sceneObj)
      m.assertEqual(BGE.SceneObjectType.Circle, sceneObj.type)
    end function

    @it("points the registered SceneObject back at this drawable")
    function _()
      sceneObj = m.circle.addToScene(m.game.canvas.renderer)
      m.circle.outlineWidth = 12345
      m.assertEqual(12345, sceneObj.drawable.outlineWidth)
    end function

  end class

end namespace
```

Create `src/source/engine/renderer/sceneObjects/SceneObjectCircle.spec.bs`:

```brightscript
namespace tests

  ' SceneObjectCircle's fill is inherited, untested-here SceneObjectBillboard machinery
  ' (identical to SceneObjectImage) - only the outline point math below is
  ' SceneObjectCircle's own logic. Follows the same real-Renderer-over-a-real-bitmap,
  ' update-then-draw pattern SceneObjectRectangle.spec.bs uses, since canvasPoints (which
  ' the outline math reads) is only populated by an actual update+draw pass.
  @suite("BGE.SceneObjectCircle")
  class SceneObjectCircleTests extends rooibos.BaseTestSuite

    game as BGE.Game
    entity as BGE.GameEntity
    bitmap as roBitmap
    renderer as BGE.Renderer

    protected override function beforeEach()
      m.game = new BGE.Game(320, 240)
      m.entity = new BGE.GameEntity(m.game, {name: "TestEntity"})
      m.bitmap = CreateObject("roBitmap", {width: 200, height: 200, alphaEnable: true})
      m.renderer = new BGE.Renderer(m.bitmap)
      ' The default Camera2d centers on its canvas, so world (100, 100) is canvas (100, 100)
      ' and a 20-radius circle anchored there lands well inside the 200x200 bitmap.
      m.entity.position = BGE.Math.VectorOps.create(100, 100, 0)
    end function

    ' Registers the circle with the renderer and runs one frame of update+draw for it.
    private function drawOnce(circle as BGE.DrawableCircle) as BGE.SceneObjectCircle
      sceneObj = circle.addToScene(m.renderer)
      m.entity.updateTransformationMatrix()
      sceneObj.update(m.renderer.camera)
      sceneObj.draw(m.renderer)
      return sceneObj as BGE.SceneObjectCircle
    end function

    @describe("getRegionWithIdToDraw")

    @it("returns the engine's shared circle texture region")
    function _()
      sceneObj = m.drawOnce(new BGE.DrawableCircle(m.entity, 20))
      regionWithId = sceneObj.getRegionWithIdToDraw()
      m.assertNotInvalid(regionWithId)
      m.assertNotInvalid(regionWithId.region)
    end function

    @describe("getOutlineCanvasPoints")

    @it("returns invalid when the drawable has no outline")
    function _()
      sceneObj = m.drawOnce(new BGE.DrawableCircle(m.entity, 20))
      m.assertInvalid(sceneObj.getOutlineCanvasPoints())
    end function

    @it("returns outlineSegments points when the drawable has an outline")
    function _()
      circle = new BGE.DrawableCircle(m.entity, 20, {outlineRGBA: BGE.ColorsRGB.Red})
      sceneObj = m.drawOnce(circle)
      points = sceneObj.getOutlineCanvasPoints()
      m.assertNotInvalid(points)
      m.assertEqual(circle.outlineSegments, points.count())
    end function

  end class

end namespace
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `npm run test:ci`
Expected: FAIL - `BGE.DrawableCircle`/`BGE.SceneObjectCircle` are not defined (compile errors).

- [ ] **Step 3: Write `DrawableCircle`**

Create `src/source/engine/drawables/DrawableCircle.bs`:

```brightscript
namespace BGE

  ' Draws a filled circle via the engine's shipped circle texture (see
  ' Game.getCircleImageRegion), with an optional outline stroked as a regular polygon
  ' inscribed in the circle's own quad - see SceneObjectCircle.
  '
  ' Like DrawableRectangle, the circle's top left (of its bounding square) sits at the
  ' drawable's own world position, extending `radius * 2` right and down - so it anchors
  ' and composes with the rest of the engine the same way every other drawable does. In
  ' the oriented/solid/wireFrame 3D draw modes it foreshortens into an ellipse when viewed
  ' at an angle, the same as any other billboard (see DrawableSphere for a circle that
  ' never does this).
  class DrawableCircle extends Drawable

    radius as float

    ' Regular-polygon segment count used only for the outline - the fill is a texture
    ' blit, not a polygon, so this has no effect on fill smoothness.
    outlineSegments as integer = 24

    sub new(owner as GameEntity, radius as float, args = {} as roAssociativeArray)
      super(owner, args)
      m.radius = radius
      m.width = radius * 2
      m.height = radius * 2
      ' bs:disable-next-line: 1140
      m.append(args)
    end sub


    ' Resizes the circle. Use this rather than assigning to radius directly - a resize
    ' isn't movement, so it has to tell the renderer to recompute this drawable's
    ' geometry (see Drawable.invalidateGeometry).
    '
    ' @param {float} radius - new radius in world units
    sub setRadius(radius as float)
      if radius = m.radius
        return
      end if
      m.radius = radius
      m.width = radius * 2
      m.height = radius * 2
      m.invalidateGeometry()
    end sub


    override function addToScene(rendererObj as Renderer) as BGE.SceneObject
      return m.addSceneObjectToRenderer(new SceneObjectCircle(m.getSceneObjectName("circle"), m), rendererObj)
    end function

  end class

end namespace
```

- [ ] **Step 4: Write `SceneObjectCircle`**

Create `src/source/engine/renderer/sceneObjects/SceneObjectCircle.bs`:

```brightscript
namespace BGE

  ' Draws a DrawableCircle. The fill is inherited, unmodified SceneObjectBillboard
  ' machinery (pinned-corners texture warp, tinting, temp-bitmap caching) blitting the
  ' engine's shared circle texture - exactly like SceneObjectImage, just with a fixed
  ' texture instead of one supplied by the drawable. Only the outline differs from a
  ' plain Image: it's stroked as an N-gon inscribed in this object's own already-
  ' transformed canvasPoints quad (via the generic getOutlineCanvasPoints() hook), which
  ' is far cheaper than rasterizing the fill itself as a many-sided polygon and needs no
  ' new Renderer draw method.
  class SceneObjectCircle extends SceneObjectBillboard

    drawable as DrawableCircle

    sub new(name as string, drawableObj as DrawableCircle)
      super(name, drawableObj, SceneObjectType.Circle)
    end sub


    protected override function getRegionWithIdToDraw() as BGE.RendererHelpers.RegionWithId
      region = m.drawable.owner.game.getCircleImageRegion()
      return BGE.RendererHelpers.createRegionWithId(region, "__bge_circle")
    end function


    ' N points around the ellipse inscribed in this object's own transformed
    ' canvasPoints quad, computed from the quad's own corner vectors as the ellipse's
    ' basis rather than a fresh world-to-canvas transform pass - so this automatically
    ' gets the same foreshortening the quad itself has in oriented 3D draw modes.
    protected override function getOutlineCanvasPoints() as BGE.Math.Vector[]
      if not m.drawable.hasOutline()
        return invalid
      end if
      center = m.canvasPoints.getCenter()
      halfAcross = BGE.Math.VectorOps.scale(BGE.Math.VectorOps.subtract(m.canvasPoints.topRight, m.canvasPoints.topLeft), 0.5)
      halfDown = BGE.Math.VectorOps.scale(BGE.Math.VectorOps.subtract(m.canvasPoints.bottomLeft, m.canvasPoints.topLeft), 0.5)
      segments = m.drawable.outlineSegments
      points = []
      for i = 0 to segments - 1
        theta = (2 * BGE.Math.PI) * (i / segments)
        offset = BGE.Math.VectorOps.add(
        BGE.Math.VectorOps.scale(halfAcross, cos(theta)),
        BGE.Math.VectorOps.scale(halfDown, sin(theta)))
        points.push(BGE.Math.VectorOps.add(center, offset))
      end for
      return points
    end function

  end class

end namespace
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `npm run test:ci`
Expected: PASS.

- [ ] **Step 6: Run full validation**

Run: `npm run validate`
Expected: no errors.

- [ ] **Step 7: Commit**

```bash
git add src/source/engine/drawables/DrawableCircle.bs src/source/engine/drawables/DrawableCircle.spec.bs \
        src/source/engine/renderer/sceneObjects/SceneObjectCircle.bs src/source/engine/renderer/sceneObjects/SceneObjectCircle.spec.bs
git commit -m "Add DrawableCircle/SceneObjectCircle (#100)"
```

---

### Task 5: `DrawableSphere`

**Files:**
- Create: `src/source/engine/drawables/DrawableSphere.bs`
- Test: `src/source/engine/drawables/DrawableSphere.spec.bs`

**Interfaces:**
- Consumes: `DrawableCircle` (Task 4).
- Produces: `DrawableSphere(owner as GameEntity, radius as float, args = {} as roAssociativeArray)` - a `DrawableCircle` whose `drawMode` defaults to `SceneObjectDrawMode.directScaled`. Task 6 (`GameEntity.addSphere`) constructs it directly.

- [ ] **Step 1: Write the failing spec**

Create `src/source/engine/drawables/DrawableSphere.spec.bs`:

```brightscript
namespace tests

  ' DrawableSphere is DrawableCircle with drawMode forced to directScaled - see
  ' SceneObject.getActualDrawMode(), which only resolves matchCamera through the camera
  ' and passes any other explicit value straight through. No new SceneObject class is
  ' needed; SceneObjectCircle's drawing logic is unaffected by which drawMode it's asked
  ' to draw in.
  @suite("BGE.DrawableSphere")
  class DrawableSphereTests extends rooibos.BaseTestSuite

    game as BGE.Game
    entity as BGE.GameEntity

    protected override function beforeEach()
      m.game = new BGE.Game(320, 240)
      m.entity = new BGE.GameEntity(m.game, {name: "TestEntity"})
    end function

    @describe("construction")

    @it("takes its radius from the constructor, like DrawableCircle")
    function _()
      sphere = new BGE.DrawableSphere(m.entity, 20)
      m.assertEqual(20.0, sphere.radius)
    end function

    @it("forces drawMode to directScaled so it never foreshortens")
    function _()
      sphere = new BGE.DrawableSphere(m.entity, 20)
      m.assertEqual(BGE.SceneObjectDrawMode.directScaled, sphere.drawMode)
    end function

    @it("still allows drawMode to be overridden afterwards if a caller really wants to")
    function _()
      sphere = new BGE.DrawableSphere(m.entity, 20)
      sphere.drawMode = BGE.SceneObjectDrawMode.oriented
      m.assertEqual(BGE.SceneObjectDrawMode.oriented, sphere.drawMode)
    end function

    @describe("addToScene")

    @it("registers a SceneObjectCircle with the renderer, same as DrawableCircle")
    function _()
      sphere = new BGE.DrawableSphere(m.entity, 20)
      sceneObj = sphere.addToScene(m.game.canvas.renderer)
      m.assertNotInvalid(sceneObj)
      m.assertEqual(BGE.SceneObjectType.Circle, sceneObj.type)
    end function

  end class

end namespace
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm run test:ci`
Expected: FAIL - `BGE.DrawableSphere` is not defined.

- [ ] **Step 3: Write `DrawableSphere`**

Create `src/source/engine/drawables/DrawableSphere.bs`:

```brightscript
namespace BGE

  ' A circle that always looks the same from any camera angle, because a sphere looks
  ' the same from every direction. Everything about the fill/outline is identical to
  ' DrawableCircle (which this extends unchanged, including addToScene) - the only
  ' difference is forcing drawMode to directScaled in the constructor, which billboards
  ' (never rotates/foreshortens) while still scaling with camera distance in 3D. See
  ' SceneObject.getActualDrawMode(): it only resolves the matchCamera default through the
  ' camera, so any other explicit drawMode - this one included - is used as-is.
  class DrawableSphere extends DrawableCircle

    sub new(owner as GameEntity, radius as float, args = {} as roAssociativeArray)
      super(owner, radius, args)
      m.drawMode = SceneObjectDrawMode.directScaled
      ' bs:disable-next-line: 1140
      m.append(args)
    end sub

  end class

end namespace
```

Note: `args` is applied a second time after setting `drawMode`, so an explicit `{drawMode: ...}` in `args` still wins over the forced default - matching the "still allows drawMode to be overridden" spec above (which does it after construction instead, but both paths land on the same final value).

- [ ] **Step 4: Run test to verify it passes**

Run: `npm run test:ci`
Expected: PASS.

- [ ] **Step 5: Run full validation**

Run: `npm run validate`
Expected: no errors.

- [ ] **Step 6: Commit**

```bash
git add src/source/engine/drawables/DrawableSphere.bs src/source/engine/drawables/DrawableSphere.spec.bs
git commit -m "Add DrawableSphere (#100)"
```

---

### Task 6: `GameEntity.addCircle` / `GameEntity.addSphere`

**Files:**
- Modify: `src/source/engine/GameEntity.bs` (after `addRectangle`, around line 380)
- Test: `src/source/engine/GameEntity.spec.bs`

**Interfaces:**
- Consumes: `DrawableCircle`/`DrawableSphere` (Tasks 4-5), `GameEntity.addDrawable(imageName as string, drawableObject as Drawable, insertPosition = -1 as integer) as Drawable` (existing, `GameEntity.bs:389`).
- Produces: `GameEntity.addCircle(circleName as string, radius as float, args = {} as roAssociativeArray, insertPosition = -1 as integer) as DrawableCircle`, `GameEntity.addSphere(sphereName as string, radius as float, args = {} as roAssociativeArray, insertPosition = -1 as integer) as DrawableSphere`. Task 7 (`examples/pixels`) calls both.

- [ ] **Step 1: Write the failing specs**

In `src/source/engine/GameEntity.spec.bs`, find the `@describe("GameEntity.addRectangle")` block (mirrors the `DrawableRectangle.spec.bs` one already shown in this repo) and add two new blocks after it:

```brightscript
    @describe("GameEntity.addCircle")

    @it("creates and attaches a DrawableCircle of the requested radius")
    function _()
      circle = m.entity.addCircle("body", 32)
      m.assertNotInvalid(circle)
      m.assertEqual(32.0, circle.radius)
    end function

    @it("makes the circle retrievable by name from its owner")
    function _()
      circle = m.entity.addCircle("body", 32)
      circle.outlineWidth = 999
      m.assertEqual(999, m.entity.getDrawable("body").outlineWidth)
    end function

    @describe("GameEntity.addSphere")

    @it("creates and attaches a DrawableSphere of the requested radius")
    function _()
      sphere = m.entity.addSphere("body", 32)
      m.assertNotInvalid(sphere)
      m.assertEqual(32.0, sphere.radius)
      m.assertEqual(BGE.SceneObjectDrawMode.directScaled, sphere.drawMode)
    end function
```

This matches `GameEntity.spec.bs`'s existing fixture (`beforeEach` already sets `m.entity = new BGE.GameEntity(m.game, {name: "TestEntity"})`) - no new fixture needed.

- [ ] **Step 2: Run tests to verify they fail**

Run: `npm run test:ci`
Expected: FAIL - `addCircle`/`addSphere` are not members of `BGE.GameEntity`.

- [ ] **Step 3: Implement both methods**

In `src/source/engine/GameEntity.bs`, add right after `addRectangle` (after line 380):

```brightscript
    ' Adds a filled circle to be drawn for this entity, via the engine's shipped circle
    ' texture. The circle's top left (of its bounding square) sits at the entity's
    ' position (plus the drawable's own `offset`), extending `radius * 2` right and down
    ' in world space - like DrawableRectangle, it foreshortens into an ellipse in the
    ' oriented 3D draw modes. Use addSphere() instead for a circle that never does this.
    '
    ' @param {string} circleName - Name of the circle
    ' @param {float} radius - radius of the circle in world units
    ' @param [args={}] - any extra properties to set (e.g. color, outlineRGBA, outlineWidth, outlineSegments, offset, rotation, scale, drawMode)
    ' @param {integer} [insertPosition=-1] - the position/order in the drawables array where the circle should be added (defaults to being added at the end)
    ' @return {DrawableCircle} - The circle that was added, or `invalid` if there was an error
    function addCircle(circleName as string, radius as float, args = {} as roAssociativeArray, insertPosition = -1 as integer) as DrawableCircle
      circleObject = new DrawableCircle(m, radius, args)
      return m.addDrawable(circleName, circleObject, insertPosition) as DrawableCircle
    end function


    ' Adds a filled circle that always renders as an undistorted circle regardless of
    ' camera angle - because a sphere looks the same from every direction. See
    ' DrawableSphere.
    '
    ' @param {string} sphereName - Name of the sphere
    ' @param {float} radius - radius of the sphere in world units
    ' @param [args={}] - any extra properties to set (e.g. color, outlineRGBA, outlineWidth, outlineSegments, offset, scale)
    ' @param {integer} [insertPosition=-1] - the position/order in the drawables array where the sphere should be added (defaults to being added at the end)
    ' @return {DrawableSphere} - The sphere that was added, or `invalid` if there was an error
    function addSphere(sphereName as string, radius as float, args = {} as roAssociativeArray, insertPosition = -1 as integer) as DrawableSphere
      sphereObject = new DrawableSphere(m, radius, args)
      return m.addDrawable(sphereName, sphereObject, insertPosition) as DrawableSphere
    end function
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `npm run test:ci`
Expected: PASS.

- [ ] **Step 5: Run full validation**

Run: `npm run validate`
Expected: no errors.

- [ ] **Step 6: Commit**

```bash
git add src/source/engine/GameEntity.bs src/source/engine/GameEntity.spec.bs
git commit -m "Add GameEntity.addCircle/addSphere (#100)"
```

---

### Task 7: Visual check - `CircleRoom` in `examples/pixels`

**Files:**
- Create: `examples/pixels/src/source/Entitites/CircleEntity.bs`
- Create: `examples/pixels/src/source/Entitites/SphereEntity.bs`
- Create: `examples/pixels/src/source/Rooms/CircleRoom.bs`
- Modify: `examples/pixels/src/source/main.bs`

**Interfaces:**
- Consumes: `BGE.GameEntity.addCircle`/`addSphere` (Task 6).
- Produces: a new "CircleRoom" reachable from the existing room-cycling controls, for manual/rokubot visual verification. Nothing later depends on this task.

- [ ] **Step 1: Write `CircleEntity`**

Create `examples/pixels/src/source/Entitites/CircleEntity.bs`, mirroring `RectangleEntity.bs`:

```brightscript
class CircleEntity extends BGE.GameEntity

  circleDrawable as BGE.DrawableCircle = invalid
  color as object = {r: rnd(256), g: rnd(256), b: rnd(256)}

  sub new(game as BGE.Game)
    super(game)
    m.name = "Circle"
  end sub

  override sub onCreate(args as roAssociativeArray)
    m.position.y = args.y
    m.position.x = args.x
    m.circleDrawable = new BGE.DrawableCircle(m, args.radius)
    m.addDrawable("circle", m.circleDrawable)
    m.circleDrawable.color = BGE.RGBAtoRGBA(m.color.r, m.color.g, m.color.b, 1) / 256
    m.circleDrawable.outlineRGBA = m.getRandomColor()
  end sub

  function getRandomColor() as integer
    color% = rnd(256 * 256 * 256)
    return color%
  end function

  sub setDrawMode(drawMode as BGE.SceneObjectDrawMode)
    m.circleDrawable.drawMode = drawMode
  end sub

end class
```

- [ ] **Step 2: Write `SphereEntity`**

Create `examples/pixels/src/source/Entitites/SphereEntity.bs`:

```brightscript
class SphereEntity extends BGE.GameEntity

  sphereDrawable as BGE.DrawableSphere = invalid
  color as object = {r: rnd(256), g: rnd(256), b: rnd(256)}

  sub new(game as BGE.Game)
    super(game)
    m.name = "Sphere"
  end sub

  override sub onCreate(args as roAssociativeArray)
    m.position.y = args.y
    m.position.x = args.x
    m.sphereDrawable = new BGE.DrawableSphere(m, args.radius)
    m.addDrawable("sphere", m.sphereDrawable)
    m.sphereDrawable.color = BGE.RGBAtoRGBA(m.color.r, m.color.g, m.color.b, 1) / 256
    m.sphereDrawable.outlineRGBA = m.getRandomColor()
  end sub

  function getRandomColor() as integer
    color% = rnd(256 * 256 * 256)
    return color%
  end function

end class
```

- [ ] **Step 3: Write `CircleRoom`**

Create `examples/pixels/src/source/Rooms/CircleRoom.bs` - a fixed side-by-side circle and sphere so the foreshortening difference is directly comparable, with the same draw-mode-cycling controls `PolygonRoom` uses:

```brightscript
class CircleRoom extends BGE.Room

  circleEntity as CircleEntity = invalid
  sphereEntity as SphereEntity = invalid
  drawMode = 3

  drawModeLabel as BGE.UI.Label = invalid

  sub new(game as BGE.Game)
    super(game)
    m.name = "CircleRoom"
    m.drawModeLabel = new BGE.UI.Label(m.game)
  end sub

  override sub onCreate(args as roAssociativeArray)
    centerX = m.game.canvas.getWidth() / 2
    centerY = m.game.canvas.getHeight() / 2
    m.circleEntity = m.game.addEntity(new CircleEntity(m.game), {x: centerX - 150, y: centerY, radius: 80})
    m.sphereEntity = m.game.addEntity(new SphereEntity(m.game), {x: centerX + 150, y: centerY, radius: 80})
    m.circleEntity.setDrawMode(m.drawMode as BGE.SceneObjectDrawMode)

    m.drawModeLabel.customPosition = true
    m.drawModeLabel.customX = m.game.gameUI.width / 2
    m.drawModeLabel.customY = m.game.gameUI.height - 200
    m.drawModeLabel.drawableText.alignment = BGE.UI.HorizAlignment.center
    m.drawModeLabel.setText(`Circle DrawMode: ${m.drawMode} (Sphere always directScaled)`)
    m.game.gameUi.addChild(m.drawModeLabel)
  end sub

  sub changeDrawMode()
    m.drawMode = (m.drawMode + 1)
    if m.drawMode > 7
      m.drawMode = 1
    end if
    m.circleEntity.setDrawMode(m.drawMode as BGE.SceneObjectDrawMode)
    m.drawModeLabel.setText(`Circle DrawMode: ${m.drawMode} (Sphere always directScaled)`)
  end sub

  override sub onInput(input as BGE.GameInput)
    if not input.press
      return
    end if
    if input.isButton("options")
      m.changeDrawMode()
    else if input.isButton("fastforward")
      goToNextRoom(m, 1)
    else if input.isButton("rewind")
      goToNextRoom(m, -1)
    end if
  end sub

  override sub onGameEvent(event as string, data as object)
  end sub

  override sub onChangeRoom(newRoom as BGE.Room)
    m.game.gameUi.removeChild(m.drawModeLabel)
  end sub

end class
```

- [ ] **Step 4: Wire it into `main.bs`**

In `examples/pixels/src/source/main.bs`, add the new room next to the others:

```brightscript
  circleRoom = new CircleRoom(game)
  ' ... alongside the existing polyRoom/rectRoom/spriteExampleRoom/ghostExampleRoom lines
  game.defineRoom(circleRoom)
```

And add `"CircleRoom"` to the array `getRoomNames()` returns.

- [ ] **Step 5: Build the example**

Run: `cd examples/pixels && npm run build`
Expected: no errors.

- [ ] **Step 6: Manually verify on-device via rokubot**

Follow the `rokubot-examples` skill workflow against `127.0.0.1` (password `rokudev`). Sideload `examples/pixels`, navigate to `CircleRoom` (cycle rooms with fast-forward/rewind), and confirm:
- The circle renders as a filled circle with a visible outline in its default draw mode.
- Cycling draw modes (`options` button) with `fastforward`/`rewind` shows the circle foreshortening into an ellipse in the oriented 3D modes, while the sphere next to it stays a perfect circle throughout.

Since this is a real-time visual check, take a screenshot per the project's "no real-time game play via rokubot" convention rather than trying to watch it live - one screenshot per draw mode cycled is enough to confirm the shapes look right.

- [ ] **Step 7: Commit**

```bash
cd /path/to/repo/root
git add examples/pixels/src/source/Entitites/CircleEntity.bs examples/pixels/src/source/Entitites/SphereEntity.bs \
        examples/pixels/src/source/Rooms/CircleRoom.bs examples/pixels/src/source/main.bs
git commit -m "Add CircleRoom to examples/pixels to visually verify DrawableCircle/Sphere (#100)"
```

---

### Task 8: Final validation and docs

**Files:**
- Modify: `CLAUDE.md` (Drawables/SceneObjects section, per the project's own "review docs on significant changes" rule)

**Interfaces:** none - this task only validates and documents what Tasks 1-7 already built.

- [ ] **Step 1: Run the full quality gate**

Run: `npm run check`
Expected: lint, validate, and headless tests all pass.

- [ ] **Step 2: Validate every example still builds**

Run: `npm run validate-examples`
Expected: no errors, including `examples/pixels`.

- [ ] **Step 3: Update `CLAUDE.md`**

In the "Entities, Rooms, Drawables" section's bullet list (where `Drawable` subclasses are named: `Image`, `Sprite`, `AnimatedImage`, `DrawableRectangle`, `DrawableLine`, `DrawablePolygon`, `DrawableText`, `Model3d`, `DrawablePlane`), add `DrawableCircle`, `DrawableSphere` to that list, and add one sentence noting the fill-via-shipped-asset / outline-via-inscribed-N-gon split, cross-referencing the design spec.

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md
git commit -m "Document DrawableCircle/DrawableSphere in CLAUDE.md (#100)"
```

- [ ] **Step 5: Open the PR**

Push the branch and open a PR against `main` referencing #100, summarizing the fill/outline split and linking both spec files (`specs/2026-08-14-drawable-circle-sphere-design.md`, `specs/2026-08-14-drawable-circle-sphere-plan.md`).
