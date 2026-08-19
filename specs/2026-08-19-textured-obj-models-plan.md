# Textured .obj Models Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a loaded `.obj` 3D model carry a diffuse texture (sampled via UV coordinates, affine-mapped) instead of only ever rendering flat-shaded, via either standard `mtllib`/`map_Kd` resolution or an explicit caller-supplied texture path.

**Architecture:** `OBJParser` stays a pure, `Game`-independent parser that resolves `vt`/`mtllib`/`map_Kd` into a normalized-UV `Model3d` plus a `texturePath` string. A new `BGE.Model3dOps` namespace (in `Model3d.bs`) holds the fully unit-testable finalization logic — given an already-loaded `roBitmap`, wrap it once in a shared `RegionWithId` and convert every face's UV points from normalized to pixel space. `Game.load3dModel` is the thin, untestable-without-disk glue that loads the actual bitmap file and calls that finalization logic. `SceneObjectModel`'s single per-face draw dispatch (`drawFaceToCanvas`) gains a texture-aware branch using the existing `Renderer.drawBitmapTriangle(To)` primitive, tinted by the same brightness system every flat face already uses.

**Tech Stack:** BrighterScript (`bsc`), Rooibos (`rooibos-roku`) for unit tests, `brs-cli` for headless CI, `rokubot` for on-device verification.

**Spec:** `specs/2026-08-19-textured-obj-models-design.md`

## Global Constraints

- Every existing 2-arg `load3dModel(modelName, modelPath)` call site (including all `.stl` loads) must keep working unchanged.
- `OBJParser.bs` must stay `Game`-independent — no `CreateObject("roBitmap"/"roRegion", ...)` calls in that file. (Design §2)
- v1 supports exactly one texture per model — no per-face/multi-material meshes, `usemtl` stays ignored. (Design §Summary)
- A face missing a `vt` index on any corner gets no `Texture` at all — falls back to flat color for that face only. (Design §2)
- Missing/bad texture file: log a warning, leave every face untextured, `load3dModel` still returns `true`. (Design §4)
- UV pixel conversion happens exactly once at load (in `Game.load3dModel`/`Model3dOps.applyTexture`), never per-frame. (Design §2, §4)
- Textured faces are tinted by the existing `colorBrightness(face.color, face.brightness)` result, passed as `drawBitmapTriangle`'s RGBA tint — same lighting model as flat faces. (Design §5)
- `drawBitmapTriangleTo`'s staged scratch bitmaps must be returned via `bmpPool.returnStagedRegions()` exactly once per draw batch, never per-triangle, never left unreturned. (Renderer.bs:932-934 doc comment; confirmed via research that neither `drawScene()` nor `drawPendingClusterPrimitives()` does this automatically)
- New/changed engine code follows this repo's existing JSDoc-comment-above-public-method convention.
- Run `npm run validate` after engine changes; run `npm run check` before considering the branch done.

---

### Task 1: Data model — `Model3dTexture`/`Model3d`/`Model3dLoadOptions`/`Model3dOps`

**Files:**
- Modify: `src/source/engine/drawables/Model3d.bs`
- Test: `src/source/engine/drawables/Model3d.spec.bs`

**Interfaces:**
- Produces:
  - `class Model3dTexture` — field `srcRegionWithId as BGE.RendererHelpers.RegionWithId` (renamed from `srcImage as ifRegion`), field `points as BGE.Math.Vector[]` (unchanged name; normalized 0..1 until `Model3dOps.applyTexture` runs, pixel-space after).
  - `class Model3d` — new field `texturePath as string = invalid`.
  - `interface Model3dLoadOptions` — `optional texturePath as string`.
  - `namespace BGE.Model3dOps`:
    - `function resolveEffectiveTexturePath(options as BGE.Model3dLoadOptions, model as BGE.Model3d) as dynamic` — returns `options.texturePath` if non-invalid/non-empty, else `model.texturePath`, else `invalid`. (`as dynamic`, not `as string` — BrightScript's runtime enforces a return-type cast that `bsc --validate`'s static check does not catch, so a function declared `as string` that actually returns `invalid` crashes at real runtime with "Type Mismatch. Unable to cast Invalid to String," even though it validates and builds cleanly. Confirmed by direct testing during implementation; see ledger.)
    - `sub applyTexture(model as BGE.Model3d, bitmap as roBitmap, cacheId as string)` — builds one `roRegion` + one `BGE.RendererHelpers.RegionWithId` (id = `cacheId`) from `bitmap`, then for every face in `model.faces` with a non-invalid `Texture`, converts its 3 `points` from normalized (`u`, `v`) to pixel space (`u * bitmap.GetWidth()`, `(1 - v) * bitmap.GetHeight()`) and sets `.srcRegionWithId` to the one shared region.
- Consumes: `BGE.RendererHelpers.createRegionWithId(region as roRegion, id as string) as BGE.RendererHelpers.RegionWithId` (existing, `RendererHelpers.bs:25`), `BGE.Math.VectorOps.create` (existing).

- [ ] **Step 1: Write the failing tests**

Add to `src/source/engine/drawables/Model3d.spec.bs`, inside `Model3dTests`, after the existing `@describe("Model3d")` block:

```brighterscript
    @describe("Model3dOps.resolveEffectiveTexturePath")

    @it("prefers the explicit options.texturePath over the model's own texturePath")
    function _()
      model = new BGE.Model3d([])
      model.texturePath = "pkg:/models/from-mtllib.png"
      options = {texturePath: "pkg:/models/explicit.png"} as BGE.Model3dLoadOptions
      m.assertEqual("pkg:/models/explicit.png", BGE.Model3dOps.resolveEffectiveTexturePath(options, model))
    end function

    @it("falls back to the model's own texturePath when no explicit override is given")
    function _()
      model = new BGE.Model3d([])
      model.texturePath = "pkg:/models/from-mtllib.png"
      options = {} as BGE.Model3dLoadOptions
      m.assertEqual("pkg:/models/from-mtllib.png", BGE.Model3dOps.resolveEffectiveTexturePath(options, model))
    end function

    @it("returns invalid when neither an override nor a model texturePath exists")
    function _()
      model = new BGE.Model3d([])
      options = {} as BGE.Model3dLoadOptions
      m.assertInvalid(BGE.Model3dOps.resolveEffectiveTexturePath(options, model))
    end function

    @describe("Model3dOps.applyTexture")

    @it("converts normalized UV points to pixel space and shares one RegionWithId across faces")
    function _()
      face1 = BGE.Model3dFaceOps.create([
        BGE.Math.VectorOps.create(0, 0, 0),
        BGE.Math.VectorOps.create(1, 0, 0),
        BGE.Math.VectorOps.create(0, 1, 0)
      ])
      face1.Texture = new BGE.Model3dTexture(BGE.RendererHelpers.createRegionWithId(invalid, ""), [
        BGE.Math.VectorOps.create(0, 0, 0),
        BGE.Math.VectorOps.create(1, 0, 0),
        BGE.Math.VectorOps.create(0.5, 1, 0)
      ])
      face2 = BGE.Model3dFaceOps.create([
        BGE.Math.VectorOps.create(0, 0, 1),
        BGE.Math.VectorOps.create(1, 0, 1),
        BGE.Math.VectorOps.create(0, 1, 1)
      ])
      face2.Texture = new BGE.Model3dTexture(BGE.RendererHelpers.createRegionWithId(invalid, ""), [
        BGE.Math.VectorOps.create(0, 0, 0),
        BGE.Math.VectorOps.create(1, 0, 0),
        BGE.Math.VectorOps.create(0.5, 1, 0)
      ])
      model = new BGE.Model3d([face1, face2])
      bitmap = CreateObject("roBitmap", {width: 200, height: 100, alphaEnable: true})

      BGE.Model3dOps.applyTexture(model, bitmap, "my-texture-id")

      ' u * width, (1 - v) * height
      m.assertTrue(BGE.Math.VectorOps.equals(model.faces[0].Texture.points[0], BGE.Math.VectorOps.create(0, 100, 0)))
      m.assertTrue(BGE.Math.VectorOps.equals(model.faces[0].Texture.points[1], BGE.Math.VectorOps.create(200, 100, 0)))
      m.assertTrue(BGE.Math.VectorOps.equals(model.faces[0].Texture.points[2], BGE.Math.VectorOps.create(100, 0, 0)))
      m.assertEqual("my-texture-id", model.faces[0].Texture.srcRegionWithId.id)
      m.assertEqual("my-texture-id", model.faces[1].Texture.srcRegionWithId.id)
    end function

    @it("leaves untextured faces alone")
    function _()
      face = BGE.Model3dFaceOps.create([
        BGE.Math.VectorOps.create(0, 0, 0),
        BGE.Math.VectorOps.create(1, 0, 0),
        BGE.Math.VectorOps.create(0, 1, 0)
      ])
      model = new BGE.Model3d([face])
      bitmap = CreateObject("roBitmap", {width: 200, height: 100, alphaEnable: true})

      BGE.Model3dOps.applyTexture(model, bitmap, "my-texture-id")

      m.assertInvalid(model.faces[0].Texture)
    end function
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `npm run build-tests && npm run test:ci`
Expected: FAIL — `Model3dOps`, `Model3dLoadOptions`, `.texturePath`, and `.srcRegionWithId` don't exist yet (compile error from `bsc` before tests even run).

- [ ] **Step 3: Implement**

In `src/source/engine/drawables/Model3d.bs`, replace the `Model3dTexture` class (lines 3-10) with:

```brighterscript
  class Model3dTexture
    srcRegionWithId as BGE.RendererHelpers.RegionWithId
    points as BGE.Math.Vector[]
    sub new(srcRegionWithId as BGE.RendererHelpers.RegionWithId, points as BGE.Math.Vector[])
      m.srcRegionWithId = srcRegionWithId
      m.points = points
    end sub
  end class

  ' The options accepted by Game.load3dModel() for an .obj model's texture.
  interface Model3dLoadOptions
    optional texturePath as string
  end interface
```

Add `texturePath as string` to the `Model3d` class (after `name as string = "Model3d"`, `Model3d.bs` around line 66):

```brighterscript
  class Model3d
    faces as Model3dFace[]
    name as string = "Model3d"
    texturePath as string
```

Add a new `Model3dOps` namespace after the closing `end namespace` of `Model3dFaceOps` (after line 62, before `class Model3d`):

```brighterscript
  namespace Model3dOps

    ' Picks the texture path an .obj model should actually use: an explicit override
    ' always wins over whatever `mtllib`/`map_Kd` resolution found while parsing.
    '
    ' @param {BGE.Model3dLoadOptions} options
    ' @param {BGE.Model3d} model
    ' @return {string|invalid}
    function resolveEffectiveTexturePath(options as BGE.Model3dLoadOptions, model as BGE.Model3d) as dynamic
      if options <> invalid and options.texturePath <> invalid and options.texturePath <> ""
        return options.texturePath
      end if
      return model.texturePath
    end function

    ' Finalizes every face's texture data now that the texture bitmap is loaded and its
    ' dimensions are known: wraps `bitmap` in one shared region+id (every face on this
    ' model points at the same RegionWithId - one texture per model, per issue #89's v1
    ' scope), and converts each textured face's normalized (0..1) UV points to pixel
    ' space, flipping v since .obj UVs are bottom-up and bitmaps are top-down. Faces
    ' with no Texture (a corner was missing a vt index while parsing) are left alone.
    '
    ' @param {BGE.Model3d} model
    ' @param {roBitmap} bitmap
    ' @param {string} cacheId - a stable, unique-per-texture id (the resolved texture path works well) used as the triangle-cache key for every draw of this texture
    sub applyTexture(model as BGE.Model3d, bitmap as roBitmap, cacheId as string)
      width = bitmap.GetWidth()
      height = bitmap.GetHeight()
      region = CreateObject("roRegion", bitmap, 0, 0, width, height)
      regionWithId = BGE.RendererHelpers.createRegionWithId(region, cacheId)

      for each face in model.faces
        if face.Texture <> invalid
          pixelPoints = [] as BGE.Math.Vector[]
          for each uv in face.Texture.points
            pixelPoints.push(BGE.Math.VectorOps.create(uv.x * width, (1 - uv.y) * height, 0))
          end for
          face.Texture = new BGE.Model3dTexture(regionWithId, pixelPoints)
        end if
      end for
    end sub

  end namespace
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `npm run build-tests && npm run test:ci`
Expected: PASS

- [ ] **Step 5: Validate and commit**

Run: `npm run validate`
Expected: no errors (this also compiles `bsconfig.build.json`, confirming nothing outside tests references the old `srcImage` field name — grep first: `grep -rn "srcImage" src/source` should return nothing after this change).

```bash
git add src/source/engine/drawables/Model3d.bs src/source/engine/drawables/Model3d.spec.bs
git commit -m "Add Model3dOps texture finalization + Model3dLoadOptions (issue #89)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 2: `OBJParser` — parse `vt`/UV, per-corner texture, `mtllib`/`map_Kd`

**Files:**
- Modify: `src/source/utils/parsers/OBJParser.bs`
- Test: `src/source/utils/parsers/OBJParser.spec.bs`

**Interfaces:**
- Consumes: `BGE.Model3dTexture` constructor, `BGE.RendererHelpers.createRegionWithId` (Task 1), `BGE.Model3d.texturePath` field (Task 1).
- Produces:
  - `function parseOBJContent(content as string, baseDir = "" as string) as BGE.Model3d` — signature gains an optional `baseDir` param (default `""` keeps every existing 1-arg call working unchanged); when `baseDir <> ""`, resolves `mtllib`/`map_Kd` from disk and sets the returned model's `texturePath`.
  - `function extractMapKdPath(mtlContent as string) as string` — pure, given raw `.mtl` file content, returns the first `map_Kd <path>` line's path (trimmed), or `""` if none found.
  - `function joinObjPath(baseDir as string, relativePath as string) as string` — pure path join (handles a `baseDir` with or without a trailing `/`).
  - `parseOBJFile(filePath as string) as BGE.Model3d` — unchanged public signature; internally now computes `baseDir` via `CreateObject("roPath", filePath).Split().parent` and passes it to `parseOBJContent`.

- [ ] **Step 1: Write the failing tests**

Add to `src/source/utils/parsers/OBJParser.spec.bs`, inside `OBJParserTests`, after the existing `@describe("n-gon triangulation")` block (after line 95):

```brighterscript
    @describe("texture coordinates (vt)")

    @it("resolves per-corner vt indices into normalized UV points on each face's Texture")
    function _()
      obj = "v 0 0 0" + Chr(10) +
        "v 1 0 0" + Chr(10) +
        "v 0 1 0" + Chr(10) +
        "vt 0 0" + Chr(10) +
        "vt 1 0" + Chr(10) +
        "vt 0.5 1" + Chr(10) +
        "f 1/1 2/2 3/3"

      model = BGE.Parsers.parseOBJContent(obj)

      m.assertEqual(1, model.faces.count())
      texture = model.faces[0].Texture
      m.assertNotInvalid(texture)
      m.assertTrue(BGE.Math.VectorOps.equals(texture.points[0], BGE.Math.VectorOps.create(0, 0, 0)))
      m.assertTrue(BGE.Math.VectorOps.equals(texture.points[1], BGE.Math.VectorOps.create(1, 0, 0)))
      m.assertTrue(BGE.Math.VectorOps.equals(texture.points[2], BGE.Math.VectorOps.create(0.5, 1, 0)))
    end function

    @it("resolves vt from v/vt/vn tokens the same as v/vt tokens")
    function _()
      obj = "v 0 0 0" + Chr(10) +
        "v 1 0 0" + Chr(10) +
        "v 0 1 0" + Chr(10) +
        "vt 0 0" + Chr(10) +
        "vt 1 0" + Chr(10) +
        "vt 0.5 1" + Chr(10) +
        "vn 0 0 1" + Chr(10) +
        "f 1/1/1 2/2/1 3/3/1"

      model = BGE.Parsers.parseOBJContent(obj)
      m.assertNotInvalid(model.faces[0].Texture)
    end function

    @it("gives no Texture at all when any corner is missing a vt index (v//vn / bare v)")
    function _()
      obj = "v 0 0 0" + Chr(10) +
        "v 1 0 0" + Chr(10) +
        "v 0 1 0" + Chr(10) +
        "vn 0 0 1" + Chr(10) +
        "f 1//1 2//1 3//1"

      model = BGE.Parsers.parseOBJContent(obj)
      m.assertInvalid(model.faces[0].Texture)
    end function

    @it("fans a textured quad's UVs the same way it fans vertices")
    function _()
      obj = "v 0 0 0" + Chr(10) +
        "v 1 0 0" + Chr(10) +
        "v 1 1 0" + Chr(10) +
        "v 0 1 0" + Chr(10) +
        "vt 0 0" + Chr(10) +
        "vt 1 0" + Chr(10) +
        "vt 1 1" + Chr(10) +
        "vt 0 1" + Chr(10) +
        "f 1/1 2/2 3/3 4/4"

      model = BGE.Parsers.parseOBJContent(obj)

      m.assertEqual(2, model.faces.count())
      m.assertNotInvalid(model.faces[0].Texture)
      m.assertNotInvalid(model.faces[1].Texture)
      ' Both triangles' first UV corner is the fan's shared origin corner (vt index 1: 0,0)
      m.assertTrue(BGE.Math.VectorOps.equals(model.faces[0].Texture.points[0], BGE.Math.VectorOps.create(0, 0, 0)))
      m.assertTrue(BGE.Math.VectorOps.equals(model.faces[1].Texture.points[0], BGE.Math.VectorOps.create(0, 0, 0)))
    end function

    @describe("mtllib / map_Kd resolution (extractMapKdPath, joinObjPath)")

    @it("extractMapKdPath finds the first map_Kd line's path")
    function _()
      mtl = "newmtl material0" + Chr(10) +
        "Ka 1.0 1.0 1.0" + Chr(10) +
        "map_Kd car_texture.png" + Chr(10) +
        "Kd 0.8 0.8 0.8"

      m.assertEqual("car_texture.png", BGE.Parsers.extractMapKdPath(mtl))
    end function

    @it("extractMapKdPath returns empty string when no map_Kd line exists")
    function _()
      mtl = "newmtl material0" + Chr(10) + "Kd 0.8 0.8 0.8"
      m.assertEqual("", BGE.Parsers.extractMapKdPath(mtl))
    end function

    @it("extractMapKdPath returns the FIRST material's map_Kd when a .mtl defines several materials (v1: single texture per model)")
    function _()
      ' Modeled on a real multi-material Blender-exported .mtl: several newmtl blocks,
      ' each with its own map_Kd, plus other directives (map_Bump, d, illum) that must
      ' be skipped rather than mistaken for a texture reference.
      mtl = "newmtl Body_mat" + Chr(10) +
        "Ns 769.607422" + Chr(10) +
        "Ka 1.000000 1.000000 1.000000" + Chr(10) +
        "d 1.000000" + Chr(10) +
        "illum 1" + Chr(10) +
        "map_Kd body_texture.png" + Chr(10) +
        "map_Bump body_normal.png" + Chr(10) +
        Chr(10) +
        "newmtl Glass_mat" + Chr(10) +
        "Ns 250.000000" + Chr(10) +
        "d 0.275000" + Chr(10) +
        "map_Kd glass_texture.png"

      m.assertEqual("body_texture.png", BGE.Parsers.extractMapKdPath(mtl))
    end function

    @it("joinObjPath joins a baseDir without a trailing slash")
    function _()
      m.assertEqual("pkg:/models/car.mtl", BGE.Parsers.joinObjPath("pkg:/models", "car.mtl"))
    end function

    @it("joinObjPath joins a baseDir that already has a trailing slash")
    function _()
      m.assertEqual("pkg:/models/car.mtl", BGE.Parsers.joinObjPath("pkg:/models/", "car.mtl"))
    end function
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `npm run build-tests && npm run test:ci`
Expected: FAIL — `extractMapKdPath`/`joinObjPath` don't exist yet; `.Texture` assertions fail since `vt` is currently discarded.

- [ ] **Step 3: Implement**

Replace `src/source/utils/parsers/OBJParser.bs` in full:

```brighterscript
namespace BGE.Parsers

  ' Loads and parses a Wavefront .obj file's geometry, plus its texture if the file
  ' references one via `mtllib`/`map_Kd` (see parseOBJContent's doc comment).
  '
  ' @param {string} filePath
  ' @return {BGE.Model3d}
  function parseOBJFile(filePath as string) as BGE.Model3d
    content = ReadAsciiFile(filePath)
    if rodash.isNotInvalid(content)
      pathObject = CreateObject("roPath", filePath)
      baseDir = pathObject.Split().parent
      return parseOBJContent(content, baseDir)
    end if
    return invalid
  end function

  ' Parses the geometry of a Wavefront .obj file's content: `v` vertices, `vt` texture
  ' coordinates, and `f` faces, fan-triangulating any face with more than 3 vertices (a
  ' quad or n-gon). `vn` indices in a face line are read only far enough to skip over
  ' them correctly - per-vertex normals aren't retained, since Model3dFace only
  ' supports one flat normal per face; every face's normal is instead computed from its
  ' own vertex geometry (Model3dFaceOps.create()'s default when no normal is given),
  ' the same as an STL face with a missing/zero normal.
  '
  ' `vt` UV coordinates ARE retained now (issue #89): a face where every corner has a
  ' `vt` index (`v/vt` or `v/vt/vn`) gets a Model3dFace.Texture with normalized (0..1)
  ' UV points; a face where any corner lacks one (`v//vn` or bare `v`) gets no Texture
  ' at all, falling back to flat-color rendering for that face only.
  '
  ' `mtllib <name>.mtl` (first occurrence only, matching this parser's `o`/`g` handling)
  ' is resolved relative to `baseDir` and read from disk to find the first `map_Kd`
  ' line, which becomes the returned model's `texturePath` (also resolved relative to
  ' `baseDir`) - only when `baseDir` is given (parseOBJFile always supplies it; a bare
  ' `parseOBJContent(content)` call, e.g. from a unit test with no real file on disk,
  ' skips mtllib/map_Kd resolution entirely and just parses geometry). `usemtl` is
  ' still ignored - a model has at most one texture in this engine's current scope.
  '
  ' @param {string} content - the raw text content of a .obj file
  ' @param {string} baseDir - the directory the .obj file lives in, for resolving mtllib/map_Kd paths; "" skips that resolution entirely
  ' @return {BGE.Model3d}
  function parseOBJContent(content as string, baseDir = "" as string) as BGE.Model3d
    lines = content.Split(chr(10))

    vertices = [] as BGE.Math.Vector[]
    texCoords = [] as BGE.Math.Vector[]
    faces = [] as BGE.Model3dFace[]
    name = "OBJModel"
    hasName = false
    mtllibName = ""

    for each rawLine in lines
      tokens = rodash.compact(rawLine.Trim().Split(" "))
      if tokens.count() > 0
        keyword = tokens[0]
        if keyword = "v" and tokens.count() >= 4
          vertices.push(BGE.Math.VectorOps.create(BGE.stringToFloat(tokens[1]), BGE.stringToFloat(tokens[2]), BGE.stringToFloat(tokens[3])))
        else if keyword = "vt" and tokens.count() >= 3
          texCoords.push(BGE.Math.VectorOps.create(BGE.stringToFloat(tokens[1]), BGE.stringToFloat(tokens[2]), 0))
        else if (keyword = "o" or keyword = "g") and tokens.count() >= 2 and not hasName
          name = tokens[1]
          hasName = true
        else if keyword = "mtllib" and tokens.count() >= 2 and mtllibName = ""
          mtllibName = tokens[1]
        else if keyword = "f" and tokens.count() >= 4
          appendOBJFace(faces, resolveOBJFaceVertices(tokens, vertices), resolveOBJFaceTexCoords(tokens, texCoords))
        end if
      end if
    end for

    model = new BGE.Model3d(faces)
    model.name = name
    if baseDir <> "" and mtllibName <> ""
      model.texturePath = resolveOBJTexturePath(baseDir, mtllibName)
    end if
    return model
  end function

  ' Resolves a face line's `v`/`v/vt`/`v//vn`/`v/vt/vn` tokens (tokens[1..]) to the
  ' actual vertex positions they reference.
  '
  ' @param {string[]} faceTokens - the full tokenized face line, including the leading "f"
  ' @param {BGE.Math.Vector[]} vertices - every vertex parsed so far
  ' @return {BGE.Math.Vector[]}
  function resolveOBJFaceVertices(faceTokens as string[], vertices as BGE.Math.Vector[]) as BGE.Math.Vector[]
    faceVertices = [] as BGE.Math.Vector[]
    for i = 1 to faceTokens.count() - 1
      vIndex = resolveOBJIndex(faceTokens[i].Split("/")[0], vertices.count())
      if vIndex >= 0 and vIndex < vertices.count()
        faceVertices.push(vertices[vIndex])
      end if
    end for
    return faceVertices
  end function

  ' Resolves a face line's per-corner `vt` index (the 2nd `/`-separated part of each
  ' `v/vt`/`v/vt/vn` token) to the actual UV points they reference. Returns a SHORTER
  ' array than the face's corner count (possibly empty) the moment any corner is
  ' missing a `vt` index or an already-parsed texCoord - callers compare the returned
  ' array's length against the vertex count to know whether every corner resolved.
  '
  ' @param {string[]} faceTokens - the full tokenized face line, including the leading "f"
  ' @param {BGE.Math.Vector[]} texCoords - every vt UV point parsed so far
  ' @return {BGE.Math.Vector[]}
  function resolveOBJFaceTexCoords(faceTokens as string[], texCoords as BGE.Math.Vector[]) as BGE.Math.Vector[]
    faceTexCoords = [] as BGE.Math.Vector[]
    for i = 1 to faceTokens.count() - 1
      parts = faceTokens[i].Split("/")
      if parts.count() < 2 or parts[1] = ""
        return []
      end if
      vtIndex = resolveOBJIndex(parts[1], texCoords.count())
      if vtIndex < 0 or vtIndex >= texCoords.count()
        return []
      end if
      faceTexCoords.push(texCoords[vtIndex])
    end for
    return faceTexCoords
  end function

  ' Fan-triangulates a face's already-resolved vertices (3 for a plain triangle, more
  ' for a quad/n-gon) and appends the resulting triangle(s) to `faces`. `faceTexCoords`
  ' is fanned the same way when it has one UV point per vertex (i.e. every corner
  ' resolved a `vt` - see resolveOBJFaceTexCoords) - otherwise no triangle from this
  ' face gets a Texture.
  '
  ' @param {BGE.Model3dFace[]} faces
  ' @param {BGE.Math.Vector[]} faceVertices
  ' @param {BGE.Math.Vector[]} faceTexCoords
  sub appendOBJFace(faces as BGE.Model3dFace[], faceVertices as BGE.Math.Vector[], faceTexCoords as BGE.Math.Vector[])
    hasTexture = faceTexCoords.count() = faceVertices.count() and faceVertices.count() > 0
    for i = 1 to faceVertices.count() - 2
      face = BGE.Model3dFaceOps.create([faceVertices[0], faceVertices[i], faceVertices[i + 1]])
      if hasTexture
        face.Texture = new BGE.Model3dTexture(BGE.RendererHelpers.createRegionWithId(invalid, ""), [faceTexCoords[0], faceTexCoords[i], faceTexCoords[i + 1]])
      end if
      faces.push(face)
    end for
  end sub

  ' Resolves a single (1-based, or negative/relative per the .obj spec) OBJ index string
  ' to a 0-based index into an array of the given count.
  '
  ' @param {string} indexStr
  ' @param {integer} count - the current length of the array this index is into
  ' @return {integer}
  function resolveOBJIndex(indexStr as string, count as integer) as integer
    index = indexStr.ToInt()
    if index < 0
      return count + index
    end if
    return index - 1
  end function

  ' Reads `baseDir/mtllibName` from disk and returns the resolved path to its first
  ' `map_Kd` texture, or invalid if the file can't be read or has no map_Kd line.
  '
  ' @param {string} baseDir - the .obj file's own directory
  ' @param {string} mtllibName - the mtllib line's filename, as written in the .obj
  ' @return {string}
  function resolveOBJTexturePath(baseDir as string, mtllibName as string) as string
    mtlPath = joinObjPath(baseDir, mtllibName)
    mtlContent = ReadAsciiFile(mtlPath)
    if rodash.isNotInvalid(mtlContent)
      mapKdPath = extractMapKdPath(mtlContent)
      if mapKdPath <> ""
        return joinObjPath(baseDir, mapKdPath)
      end if
    end if
    return invalid
  end function

  ' Finds the first `map_Kd <path>` line in a .mtl file's raw content.
  '
  ' @param {string} mtlContent - the raw text content of a .mtl file
  ' @return {string} the path, or "" if no map_Kd line was found
  function extractMapKdPath(mtlContent as string) as string
    lines = mtlContent.Split(chr(10))
    for each rawLine in lines
      tokens = rodash.compact(rawLine.Trim().Split(" "))
      if tokens.count() >= 2 and tokens[0] = "map_Kd"
        return tokens[1]
      end if
    end for
    return ""
  end function

  ' Joins a base directory and a relative path, regardless of whether baseDir already
  ' ends with a "/".
  '
  ' @param {string} baseDir
  ' @param {string} relativePath
  ' @return {string}
  function joinObjPath(baseDir as string, relativePath as string) as string
    if baseDir.Right(1) = "/"
      return baseDir + relativePath
    end if
    return baseDir + "/" + relativePath
  end function

end namespace
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `npm run build-tests && npm run test:ci`
Expected: PASS

- [ ] **Step 5: Validate and commit**

Run: `npm run validate`
Expected: no errors.

```bash
git add src/source/utils/parsers/OBJParser.bs src/source/utils/parsers/OBJParser.spec.bs
git commit -m "Parse .obj vt/UV coordinates and mtllib/map_Kd texture path (issue #89)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 3: `Game.load3dModel` — texture loading glue

**Files:**
- Modify: `src/source/engine/Game.bs:1550-1574`

**Interfaces:**
- Consumes: `BGE.Model3dOps.resolveEffectiveTexturePath`, `BGE.Model3dOps.applyTexture` (Task 1); `BGE.Model3dLoadOptions` (Task 1); `BGE.Parsers.parseOBJFile` (Task 2, unchanged public signature).
- Produces: `function load3dModel(modelName as string, modelPath as string, options = {} as BGE.Model3dLoadOptions) as boolean` — new optional 3rd param, backward compatible.

This task's disk-loading glue (an actual `CreateObject("roBitmap", texturePath)` call) is not covered by a Rooibos unit test, matching this repo's existing convention: `load3dModel`/`loadBitmap`'s own real-file-loading code paths have no existing Rooibos coverage today (confirmed: no spec anywhere calls either with a real `pkg:/` path). The testable logic it calls (`Model3dOps.applyTexture`/`resolveEffectiveTexturePath`) is already covered by Task 1's tests. This task's actual behavior is verified by Task 6's on-device run.

- [ ] **Step 1: Implement**

Replace `load3dModel` in `src/source/engine/Game.bs` (lines 1550-1574):

```brighterscript
    ' Loads a 3d model file (.stl or .obj) to be used in the game. For an .obj file,
    ' also resolves and loads its texture (if any) - either from options.texturePath
    ' (always takes priority) or from the .obj's own mtllib/map_Kd reference. A missing
    ' or unreadable texture file logs a warning and leaves the model untextured
    ' (flat-shaded) rather than failing the whole load - see BGE.Model3dOps.applyTexture.
    '
    ' @param {string} modelName - the name this model will be referenced by later
    ' @param {string} modelPath - the path to the model file
    ' @param {BGE.Model3dLoadOptions} options - optional load options (currently just texturePath, an .obj-only explicit texture override)
    ' @return {boolean} true if the model was loaded
    function load3dModel(modelName as string, modelPath as string, options = {} as BGE.Model3dLoadOptions) as boolean
      if m.filesystem.Exists(modelPath)
        path_object = CreateObject("roPath", modelPath)
        parts = path_object.Split()
        extensionLower = lcase(parts.extension)
        if extensionLower = ".stl"
          m.models[modelName] = BGE.Parsers.parseSTLFile(modelPath)
          return true
        else if extensionLower = ".obj"
          model = BGE.Parsers.parseOBJFile(modelPath)
          m.models[modelName] = model
          m.loadModelTexture(model, options)
          return true
        else
          m.log("Game.load3dModel() - Model " + modelPath + " not loaded, file must be of type .stl or .obj", BGE.Debug.LogLevel.error)
          return false
        end if
      else
        m.log("Game.load3dModel() - Model not created, invalid path provided", BGE.Debug.LogLevel.error)
        return false
      end if
    end function

    ' Loads and finalizes an .obj model's texture, if it has one. Private glue between
    ' the pure parsing (BGE.Parsers.parseOBJFile) and the pure finalization logic
    ' (BGE.Model3dOps.applyTexture) - the actual disk read lives here since neither of
    ' those may depend on Game.
    '
    ' @param {BGE.Model3d} model
    ' @param {BGE.Model3dLoadOptions} options
    private sub loadModelTexture(model as BGE.Model3d, options as BGE.Model3dLoadOptions)
      texturePath = BGE.Model3dOps.resolveEffectiveTexturePath(options, model)
      if texturePath = invalid or texturePath = ""
        return
      end if
      if not m.filesystem.Exists(texturePath)
        m.log("Game.load3dModel() - Texture " + texturePath + " not found, model will render untextured", BGE.Debug.LogLevel.warning)
        return
      end if
      bitmap = CreateObject("roBitmap", texturePath)
      if bitmap = invalid or bitmap.GetWidth() = 0
        m.log("Game.load3dModel() - Texture " + texturePath + " could not be loaded, model will render untextured", BGE.Debug.LogLevel.warning)
        return
      end if
      BGE.Model3dOps.applyTexture(model, bitmap, texturePath)
    end sub
```

- [ ] **Step 2: Validate**

Run: `npm run validate`
Expected: no errors. (No new automated test for this task, per the note above — the existing `Model3d.spec.bs`/`OBJParser.spec.bs` suites from Tasks 1-2 already cover everything reachable without disk I/O; `npm run test:ci` should still show the same pass count as after Task 2.)

Run: `npm run test:ci`
Expected: PASS, same test count as Task 2's end state.

- [ ] **Step 3: Commit**

```bash
git add src/source/engine/Game.bs
git commit -m "Wire .obj texture loading into Game.load3dModel (issue #89)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 4: `SceneObjectModel` — draw textured faces

**Files:**
- Modify: `src/source/engine/renderer/sceneObjects/SceneObjectModel.bs:46-76`
- Test: `src/source/engine/renderer/sceneObjects/SceneObjectModel.spec.bs`

**Interfaces:**
- Consumes: `Renderer.drawBitmapTriangle(srcRegionWithId as BGE.RendererHelpers.RegionWithId, srcPoints as BGE.Math.Vector[], destPoints as BGE.Math.Vector[], rgba = -1 as integer) as boolean` (existing, `Renderer.bs:922`), `Renderer.drawBitmapTriangleTo(draw2d as ifDraw2d, srcRegionWithId as BGE.RendererHelpers.RegionWithId, srcPoints as BGE.Math.Vector[], destPoints as BGE.Math.Vector[], rgba = -1 as integer) as boolean` (existing, `Renderer.bs:942`), `Renderer.bmpPool.returnStagedRegions()` (existing, `ScratchBitmapPool.bs:204`), `BGE.Model3dTexture` (Task 1).
- Produces: no new public methods — `drawFaceToCanvas`, `drawToCanvas`, `drawToTempBitmap` keep their existing signatures.

- [ ] **Step 1: Write the failing tests**

Add to `src/source/engine/renderer/sceneObjects/SceneObjectModel.spec.bs`, inside `SceneObjectModelTests`, after the `@describe("drawable field")` block (after line 33):

```brighterscript
    @describe("textured faces")

    function makeTexturedFace() as BGE.Model3dFace
      face = BGE.Model3dFaceOps.create([BGE.Math.VectorOps.create(-10, -10, 0), BGE.Math.VectorOps.create(10, -10, 0), BGE.Math.VectorOps.create(0, 10, 0)])
      textureBitmap = CreateObject("roBitmap", {width: 8, height: 8, alphaEnable: true})
      region = CreateObject("roRegion", textureBitmap, 0, 0, 8, 8)
      regionWithId = BGE.RendererHelpers.createRegionWithId(region, "test-texture")
      face.Texture = new BGE.Model3dTexture(regionWithId, [
        BGE.Math.VectorOps.create(0, 0, 0),
        BGE.Math.VectorOps.create(8, 0, 0),
        BGE.Math.VectorOps.create(4, 8, 0)
      ])
      return face
    end function

    @it("draws a textured face via the solo draw path without crashing, using drawBitmapTriangle")
    function _()
      face = m.makeTexturedFace()
      model = new BGE.Model3d([face])
      drawableModel = new BGE.DrawableModel(m.entity, model)
      drawableModel.drawMode = BGE.SceneObjectDrawMode.solidDrawBackFace
      sceneObj = drawableModel.addToScene(m.renderer)
      m.entity.updateTransformationMatrix()
      m.renderer.setupCameraForFrame()
      sceneObj.update(m.renderer.camera)
      m.renderer.resetDrawCallCounter()
      sceneObj.draw(m.renderer) ' draw() is a sub (void) - no return value to assert
      m.assertTrue(m.renderer.getDrawCallsLastFrame() > 0)
    end function

    @it("draws a textured face via the cluster drawPrimitive path without crashing, and can repeat across frames without leaking staged regions")
    function _()
      face = m.makeTexturedFace()
      model = new BGE.Model3d([face])
      drawableModel = new BGE.DrawableModel(m.entity, model)
      drawableModel.drawMode = BGE.SceneObjectDrawMode.solidDrawBackFace
      sceneObj = drawableModel.addToScene(m.renderer)
      m.entity.updateTransformationMatrix()
      m.renderer.setupCameraForFrame()
      sceneObj.update(m.renderer.camera)
      sceneObj.draw(m.renderer)
      for i = 1 to 5
        m.renderer.resetDrawCallCounter()
        result = sceneObj.drawPrimitive(m.renderer, 0)
        m.assertTrue(result)
        m.assertTrue(m.renderer.getDrawCallsLastFrame() > 0)
      end for
    end function

    @it("still draws an untextured face via the flat-color path (no regression)")
    function _()
      face1 = BGE.Model3dFaceOps.create([BGE.Math.VectorOps.create(-10, -10, 0), BGE.Math.VectorOps.create(10, -10, 0), BGE.Math.VectorOps.create(0, 10, 0)])
      model = new BGE.Model3d([face1])
      drawableModel = new BGE.DrawableModel(m.entity, model)
      drawableModel.drawMode = BGE.SceneObjectDrawMode.solidDrawBackFace
      sceneObj = drawableModel.addToScene(m.renderer)
      m.entity.updateTransformationMatrix()
      m.renderer.setupCameraForFrame()
      sceneObj.update(m.renderer.camera)
      m.renderer.resetDrawCallCounter()
      sceneObj.draw(m.renderer) ' draw() is a sub (void) - no return value to assert
      m.assertTrue(m.renderer.getDrawCallsLastFrame() > 0)
    end function
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `npm run build-tests && npm run test:ci`
Expected: FAIL — `drawFaceToCanvas` doesn't read `face.Texture` yet, so these should currently still pass as flat-color draws EXCEPT they're asserting real behavior that will be validated once the texture branch exists; run to confirm the suite at least compiles, then proceed (if these happen to already pass because `drawTriangle` also returns `true`/draws something, that's fine — Step 3 makes the texture path actually distinct via `drawCallsLastFrame`, which is the meaningful signal either way once implemented).

Note: because `drawTriangle` and `drawBitmapTriangle` both return `boolean` and both increment `drawCallsLastFrame`, these specific assertions can't distinguish "textured" from "flat" by call count alone — their real purpose is regression coverage (no crash, still draws) across all three draw entry points (`draw`, `drawPrimitive`, repeated `drawPrimitive` calls) once texture support exists. Proceed to Step 3 regardless of whether Step 2 shows red or already-green for these specific assertions - the important failure mode this step guards is a crash from `face.Texture.srcRegionWithId` handling once Step 3 adds that code path.

- [ ] **Step 3: Implement**

Replace `drawFaceToCanvas` (`SceneObjectModel.bs:46-54`):

```brighterscript
    ' Draws one face directly to the live canvas - the single place per-face draw
    ' dispatch lives, shared by the normal solo draw path (drawToCanvas, above) and the
    ' cluster draw path (drawPrimitive, below). Deliberately does not touch
    ' m.modelCanvasFaces/m.tempBitmap - this always draws live, never builds or relies
    ' on the whole-model temp-bitmap cache, since that cache aggregates every face in
    ' this model's own internal order and can't represent this face being interleaved
    ' with a different object's primitives.
    '
    ' A textured face (face.Texture <> invalid) draws via drawBitmapTriangle, warping
    ' the texture's UV points onto this face's canvas points, tinted by the same
    ' brightness-shaded color a flat face gets - a caller batching many faces in one
    ' draw pass (drawToCanvas/drawToTempBitmap) must call
    ' rendererObj.bmpPool.returnStagedRegions() itself once after the whole batch, per
    ' drawBitmapTriangleTo's staged-scratch-bitmap contract - this method does not do
    ' that itself, since it draws exactly one face at a time.
    '
    ' @param {Renderer} rendererObj
    ' @param {Model3dFace} face
    ' @param {SceneObjectDrawMode} drawMode
    ' @return {boolean}
    private function drawFaceToCanvas(rendererObj as BGE.Renderer, face as BGE.Model3dFace, drawMode as SceneObjectDrawMode) as boolean
      shadedColor = BGE.colorBrightness(face.color, face.brightness)
      if drawMode = BGE.SceneObjectDrawMode.oriented or drawMode = BGE.SceneObjectDrawMode.orientedDrawBackFace or drawMode = BGE.SceneObjectDrawMode.solid or drawMode = BGE.SceneObjectDrawMode.solidDrawBackFace
        if face.Texture <> invalid
          return rendererObj.drawBitmapTriangle(face.Texture.srcRegionWithId, face.Texture.points, face.vertices, shadedColor)
        end if
        return rendererObj.drawTriangle(face.vertices, 0, 0, shadedColor)
      else if drawMode = BGE.SceneObjectDrawMode.wireFrame or drawMode = BGE.SceneObjectDrawMode.wireFrameDrawBackFace
        return rendererObj.drawTriangleOutline(face.vertices, shadedColor)
      end if
      return false
    end function
```

Replace `drawToCanvas` (`SceneObjectModel.bs:26-32`):

```brighterscript
    protected override function drawToCanvas(rendererObj as BGE.Renderer, drawMode as SceneObjectDrawMode) as boolean
      someWorked = false
      usedTexture = false
      for each face in m.modelCanvasFaces
        someWorked = m.drawFaceToCanvas(rendererObj, face, drawMode) or someWorked
        if face.Texture <> invalid
          usedTexture = true
        end if
      end for
      if usedTexture
        rendererObj.bmpPool.returnStagedRegions()
      end if
      return someWorked
    end function
```

Replace `drawToTempBitmap` (`SceneObjectModel.bs:57-76`):

```brighterscript
    protected override function drawToTempBitmap(rendererObj as BGE.Renderer, tempBitmap as ifDraw2d, canvasPointsTopLeftBound as BGE.Math.Vector, drawMode as SceneObjectDrawMode, allowFastDraw = false as boolean) as TempBitmapDrawResult
      if tempBitmap = invalid
        return {worked: false, didFastDraw: false}
      end if
      someWorked = false
      usedTexture = false
      offsetX = -canvasPointsTopLeftBound.x
      offsetY = -canvasPointsTopLeftBound.y

      for each face in m.modelCanvasFaces
        shadedColor = BGE.colorBrightness(face.color, face.brightness)
        thisWorked = true
        if drawMode = BGE.SceneObjectDrawMode.oriented or drawMode = BGE.SceneObjectDrawMode.orientedDrawBackFace or drawMode = BGE.SceneObjectDrawMode.solid or drawMode = BGE.SceneObjectDrawMode.solidDrawBackFace
          if face.Texture <> invalid
            offsetPoints = [] as BGE.Math.Vector[]
            for each vert in face.vertices
              offsetPoints.push(BGE.Math.VectorOps.create(vert.x + offsetX, vert.y + offsetY, 0))
            end for
            thisWorked = rendererObj.drawBitmapTriangleTo(tempBitmap, face.Texture.srcRegionWithId, face.Texture.points, offsetPoints, shadedColor)
            usedTexture = true
          else
            thisWorked = rendererObj.drawTriangleTo(tempBitmap, face.vertices, offsetX, offsetY, shadedColor, allowFastDraw)
          end if
        else if drawMode = BGE.SceneObjectDrawMode.wireFrame or drawMode = BGE.SceneObjectDrawMode.wireFrameDrawBackFace
          thisWorked = rendererObj.drawTriangleOutlineTo(tempBitmap, face.vertices, face.color, {x: offsetX, y: offsetY})
        end if
        someWorked = thisWorked or someWorked
      end for
      if usedTexture
        rendererObj.bmpPool.returnStagedRegions()
      end if
      return {worked: someWorked, didFastDraw: allowFastDraw}
    end function
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `npm run build-tests && npm run test:ci`
Expected: PASS

- [ ] **Step 5: Validate and commit**

Run: `npm run validate`

```bash
git add src/source/engine/renderer/sceneObjects/SceneObjectModel.bs src/source/engine/renderer/sceneObjects/SceneObjectModel.spec.bs
git commit -m "Draw textured Model3d faces via drawBitmapTriangle (issue #89)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 5: `Renderer.drawPendingClusterPrimitives` — flush staged regions once per cluster batch

**Files:**
- Modify: `src/source/engine/renderer/Renderer.bs:380-395`

**Interfaces:**
- Consumes: `m.bmpPool.returnStagedRegions()` (existing).
- Produces: no signature change to `drawPendingClusterPrimitives`.

This closes a real gap that predates this feature but was harmless until now: no `SceneObject.drawPrimitive()` override ever called `drawBitmapTriangleTo` before Task 4, so nothing was ever staged during a cluster batch. Now that `SceneObjectModel.drawPrimitive` can, the Renderer must flush once after the whole cluster batch finishes drawing.

- [ ] **Step 1: Implement**

In `src/source/engine/renderer/Renderer.bs`, in `drawPendingClusterPrimitives` (around lines 380-395), add the flush right after the primitive-draw loop and before the `afterDraw()` loop:

```brighterscript
    private sub drawPendingClusterPrimitives()
      primitiveEntries = []
      for each sceneObj in m.pendingClusterDraws
        for i = 0 to sceneObj.getPrimitiveCount() - 1
          primitiveEntries.push({sceneObj: sceneObj, index: i, depth: sceneObj.getPrimitiveDepth(i)})
        end for
      end for
      primitiveEntries.SortBy("depth")
      for each entry in primitiveEntries
        entry.sceneObj.drawPrimitive(m, entry.index)
      end for
      ' A drawPrimitive() call above may have staged scratch bitmaps (e.g. a textured
      ' Model3d face, see SceneObjectModel/issue #89) via drawBitmapTriangleTo - flush
      ' them all at once now that every primitive in this batch has finished drawing,
      ' matching drawBitmapTriangleTo's "return staged regions once per batch, not
      ' per-triangle" contract (see its doc comment). Cheap no-op when nothing staged.
      m.bmpPool.returnStagedRegions()
      for each sceneObj in m.pendingClusterDraws
        sceneObj.afterDraw()
      end for
      m.pendingClusterDraws = []
    end sub
```

- [ ] **Step 2: Run tests**

Run: `npm run build-tests && npm run test:ci`
Expected: PASS (Task 4's cluster-path test, run repeatedly across 5 `drawPrimitive` calls, already exercises this without crashing; this task makes that safe under real multi-frame/multi-object use rather than just by accident).

- [ ] **Step 3: Validate and commit**

Run: `npm run validate`

```bash
git add src/source/engine/renderer/Renderer.bs
git commit -m "Flush staged scratch regions once per cluster draw batch (issue #89)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 6: `examples/3d` demo + on-device verification

**Files:**
- Create: `examples/3d/src/models/car.obj` (copy of the user-supplied file)
- Create: `examples/3d/src/sprites/car_texture.png` (copy of the user-supplied texture)
- Create: `examples/3d/src/source/Entities/CarModel3d.bs`
- Create: `examples/3d/src/source/Rooms/CarRoom.bs`
- Create: `examples/3d/src/models/d20.obj` (a proper icosahedron: 12 vertices, 20 triangular faces, `mtllib d20.mtl`) — exercises the standard `mtllib`/`map_Kd` path end-to-end, since `car.obj` only exercises the explicit-override path
- Create: `examples/3d/src/models/d20.mtl`
- Create: `examples/3d/src/models/d20_atlas.png` (generated 5×4 grid texture atlas, one numbered/colored cell per face, faces 1-20)
- Create: `examples/3d/src/source/Entities/D20Model3d.bs`
- Create: `examples/3d/src/source/Rooms/D20Room.bs`
- Modify: `examples/3d/src/source/main.bs`

**Interfaces:**
- Consumes: `Game.load3dModel(modelName as string, modelPath as string, options as BGE.Model3dLoadOptions)` (Task 3), `Game.get3dModel`, `BGE.DrawableModel` (all existing/unchanged).

- [ ] **Step 1: Copy the fixture assets**

```bash
cp /Users/mpearce/Downloads/car.obj examples/3d/src/models/car.obj
```

Save the texture image the user attached earlier in this conversation as `examples/3d/src/sprites/car_texture.png` (a 512x512 PNG texture atlas for the car model).

Create `examples/3d/src/models/d20.obj` — a proper icosahedron (12 vertices from the standard golden-ratio construction, 20 already-triangular faces, no fan-triangulation needed) with a `mtllib` reference and no `usemtl`/explicit override, specifically to exercise the `mtllib`/`map_Kd` resolution path end-to-end on a real device. Each face's 3 UV points sample the lower-left triangular half of its own cell in a 5×4 texture atlas (face *N* → atlas cell *N-1*, `col = (N-1) mod 5`, `row = (N-1) \ 5`), so each face shows one distinct numbered/colored cell — this exact geometry was generated and verified (12 `v`, 60 `vt`, 20 `f` lines, valid icosahedron topology) during design:

```
mtllib d20.mtl
v -1 1.6180339887 0
v 1 1.6180339887 0
v -1 -1.6180339887 0
v 1 -1.6180339887 0
v 0 -1 1.6180339887
v 0 1 1.6180339887
v 0 -1 -1.6180339887
v 0 1 -1.6180339887
v 1.6180339887 0 -1
v 1.6180339887 0 1
v -1.6180339887 0 -1
v -1.6180339887 0 1
vt 0.000000 0.750000
vt 0.200000 0.750000
vt 0.000000 1.000000
vt 0.200000 0.750000
vt 0.400000 0.750000
vt 0.200000 1.000000
vt 0.400000 0.750000
vt 0.600000 0.750000
vt 0.400000 1.000000
vt 0.600000 0.750000
vt 0.800000 0.750000
vt 0.600000 1.000000
vt 0.800000 0.750000
vt 1.000000 0.750000
vt 0.800000 1.000000
vt 0.000000 0.500000
vt 0.200000 0.500000
vt 0.000000 0.750000
vt 0.200000 0.500000
vt 0.400000 0.500000
vt 0.200000 0.750000
vt 0.400000 0.500000
vt 0.600000 0.500000
vt 0.400000 0.750000
vt 0.600000 0.500000
vt 0.800000 0.500000
vt 0.600000 0.750000
vt 0.800000 0.500000
vt 1.000000 0.500000
vt 0.800000 0.750000
vt 0.000000 0.250000
vt 0.200000 0.250000
vt 0.000000 0.500000
vt 0.200000 0.250000
vt 0.400000 0.250000
vt 0.200000 0.500000
vt 0.400000 0.250000
vt 0.600000 0.250000
vt 0.400000 0.500000
vt 0.600000 0.250000
vt 0.800000 0.250000
vt 0.600000 0.500000
vt 0.800000 0.250000
vt 1.000000 0.250000
vt 0.800000 0.500000
vt 0.000000 0.000000
vt 0.200000 0.000000
vt 0.000000 0.250000
vt 0.200000 0.000000
vt 0.400000 0.000000
vt 0.200000 0.250000
vt 0.400000 0.000000
vt 0.600000 0.000000
vt 0.400000 0.250000
vt 0.600000 0.000000
vt 0.800000 0.000000
vt 0.600000 0.250000
vt 0.800000 0.000000
vt 1.000000 0.000000
vt 0.800000 0.250000
f 1/1 12/2 6/3
f 1/4 6/5 2/6
f 1/7 2/8 8/9
f 1/10 8/11 11/12
f 1/13 11/14 12/15
f 2/16 6/17 10/18
f 6/19 12/20 5/21
f 12/22 11/23 3/24
f 11/25 8/26 7/27
f 8/28 2/29 9/30
f 4/31 10/32 5/33
f 4/34 5/35 3/36
f 4/37 3/38 7/39
f 4/40 7/41 9/42
f 4/43 9/44 10/45
f 5/46 10/47 6/48
f 3/49 5/50 12/51
f 7/52 3/53 11/54
f 9/55 7/56 8/57
f 10/58 9/59 2/60
```

Create `examples/3d/src/models/d20.mtl`:

```
newmtl d20_mat
Ka 1.0 1.0 1.0
Kd 0.8 0.8 0.8
map_Kd d20_atlas.png
```

Generate `examples/3d/src/models/d20_atlas.png` — a 640×512 (5 cols × 4 rows of 128×128 cells) atlas, each cell a distinct color with its face number drawn bottom-left-anchored (so it falls inside the triangular UV region each face actually samples, not the cell's unused upper-right half). This exact script was run and its output visually verified (all 20 numbers legible, correctly positioned) during design:

```bash
mkdir -p examples/3d/src/models/tiles
FONT="/System/Library/Fonts/Supplemental/Verdana Bold.ttf"
colors=(tomato steelblue seagreen goldenrod orchid darkorange teal crimson slateblue chocolate mediumvioletred cadetblue olive indianred darkcyan sienna mediumseagreen darkslateblue firebrick darkgoldenrod)

for n in $(seq 1 20); do
  color=${colors[$((n-1))]}
  magick -size 128x128 xc:"$color" -gravity SouthWest -font "$FONT" -pointsize 56 -fill white -stroke black -strokewidth 1 -annotate +8+8 "$n" examples/3d/src/models/tiles/tile_$n.png
done

magick montage examples/3d/src/models/tiles/tile_{1..20}.png -tile 5x4 -geometry 128x128+0+0 examples/3d/src/models/d20_atlas.png
rm -rf examples/3d/src/models/tiles
```

(If `magick`/a system font at that exact path isn't available in the execution environment, any equivalent tool producing a 640×512 PNG with the same 5×4 layout and numbering works — the `.obj`'s UV coordinates are what actually matter for correctness, not how the atlas pixels were drawn.)

- [ ] **Step 2: Create the entity**

Create `examples/3d/src/source/Entities/CarModel3d.bs`:

```brighterscript
class CarModel3d extends BGE.GameEntity

  modelDraw as BGE.DrawableModel

  doRotation = false
  speed = 1

  sub new(game as BGE.Game)
    super(game)
    m.name = "car"
  end sub

  override sub onCreate(args as roAssociativeArray)
    m.modelDraw = new BGE.DrawableModel(m, m.game.get3dModel("car"))
    m.modelDraw.scale = BGE.Math.createScaleVector(50)
    m.addDrawable("model", m.modelDraw)
  end sub

  override sub onUpdate(deltaTime as float)
    if m.doRotation
      m.rotation.y += deltaTime * m.speed
    end if
  end sub

  override sub onInput(input as BGE.GameInput)
    if input.press
      if input.isButton("ok")
        m.doRotation = not m.doRotation
      end if
    end if
  end sub

end class
```

Create `examples/3d/src/source/Entities/D20Model3d.bs`:

```brighterscript
class D20Model3d extends BGE.GameEntity

  modelDraw as BGE.DrawableModel

  doRotation = false
  speed = 1

  sub new(game as BGE.Game)
    super(game)
    m.name = "d20"
  end sub

  override sub onCreate(args as roAssociativeArray)
    m.modelDraw = new BGE.DrawableModel(m, m.game.get3dModel("d20"))
    m.modelDraw.scale = BGE.Math.createScaleVector(80)
    m.addDrawable("model", m.modelDraw)
  end sub

  override sub onUpdate(deltaTime as float)
    if m.doRotation
      m.rotation.y += deltaTime * m.speed
    end if
  end sub

  override sub onInput(input as BGE.GameInput)
    if input.press
      if input.isButton("ok")
        m.doRotation = not m.doRotation
      end if
    end if
  end sub

end class
```

- [ ] **Step 3: Create the rooms**

Create `examples/3d/src/source/Rooms/CarRoom.bs`:

```brighterscript
class CarRoom extends BaseRoom

  car as CarModel3d

  sub new(game as BGE.Game)
    super(game)
    m.name = "CarRoom"
    m.instructions = "Rotation Toggle: OK"
  end sub

  override sub onCreate(args as roAssociativeArray)
    m.car = new CarModel3d(m.game)
    m.game.addEntity(m.car)
  end sub

  override sub onChangeRoom(newRoom as BGE.Room)
    m.car.invalidate()
  end sub

end class
```

Create `examples/3d/src/source/Rooms/D20Room.bs`:

```brighterscript
class D20Room extends BaseRoom

  d20 as D20Model3d

  sub new(game as BGE.Game)
    super(game)
    m.name = "D20Room"
    m.instructions = "Rotation Toggle: OK"
  end sub

  override sub onCreate(args as roAssociativeArray)
    m.d20 = new D20Model3d(m.game)
    m.game.addEntity(m.d20)
  end sub

  override sub onChangeRoom(newRoom as BGE.Room)
    m.d20.invalidate()
  end sub

end class
```

- [ ] **Step 4: Wire it into main.bs**

In `examples/3d/src/source/main.bs`, after the existing `game.load3dModel("bird", "pkg:/models/low_poly_bird.stl")` line:

```brighterscript
  game.load3dModel("car", "pkg:/models/car.obj", {texturePath: "pkg:/sprites/car_texture.png"})
  game.load3dModel("d20", "pkg:/models/d20.obj")
```

(`d20` is loaded with no `options` argument at all — it must resolve its texture purely via `mtllib`/`map_Kd`, proving that path works independent of the explicit-override path `car` exercises.)

After the existing `model_room = new ModelRoom(game)` / `game.defineRoom(model_room)` block:

```brighterscript
  car_room = new CarRoom(game)
  game.defineRoom(car_room)

  d20_room = new D20Room(game)
  game.defineRoom(d20_room)
```

In `getRoomNames()`, add `"CarRoom"` and `"D20Room"` to the returned array (matching the existing string list style).

- [ ] **Step 5: Build and validate the example**

Run: `cd examples/3d && npm install && npm run build`
Expected: builds without error.

Run (from repo root): `npm run validate-examples`
Expected: no errors for `examples/3d`.

- [ ] **Step 6: On-device verification via rokubot**

Per this repo's established convention (CLAUDE.md: "Treat an actual on-device (or simulator) run via the rokubot-examples skill as mandatory before considering a new/changed example's runtime behavior verified, not as optional polish"), sideload and run `examples/3d`, and check both new rooms:

`CarRoom` (deep-link via `demo`/room param per the rokubot-examples skill, or navigate manually):
- The car model renders with the texture visible (not flat gray/white).
- Pressing OK toggles rotation, and the texture stays correctly mapped as the model rotates (no swimming/detachment beyond the expected affine-mapping limitation).
- No crash when leaving/re-entering the room (validates `onChangeRoom`'s `invalidate()`/re-`onCreate()` cycle with a textured model).

`D20Room`:
- The D20 renders with distinct colored/numbered faces visible (proves the `mtllib`/`map_Kd`-resolved texture, loaded with zero explicit override, actually made it onto the model).
- Numbers are legible and not obviously sampling the wrong atlas cell (each visible face shows one clean number, not a blend of two).
- Pressing OK toggles rotation without crashing.

- [ ] **Step 7: Commit**

```bash
git add examples/3d/src/models/car.obj examples/3d/src/sprites/car_texture.png examples/3d/src/models/d20.obj examples/3d/src/models/d20.mtl examples/3d/src/models/d20_atlas.png examples/3d/src/source/Entities/CarModel3d.bs examples/3d/src/source/Rooms/CarRoom.bs examples/3d/src/source/Entities/D20Model3d.bs examples/3d/src/source/Rooms/D20Room.bs examples/3d/src/source/main.bs
git commit -m "Add textured car.obj and mtllib-textured d20.obj demos to examples/3d (issue #89)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 7: Fix intra-model face draw order (issue #112)

**Why this is in scope for issue #89's work**: this pre-existing bug was already latent (affecting flat-shaded self-overlapping models), but the new textured car/D20 demos make it directly visible and noticeable — surfaced during Task 6's on-device verification. Added to this plan at the user's explicit request, since it now directly impacts how these models look.

**Files:**
- Modify: `src/source/engine/renderer/sceneObjects/SceneObjectModel.bs`
- Test: `src/source/engine/renderer/sceneObjects/SceneObjectModel.spec.bs`

**Interfaces:**
- Consumes: nothing new.
- Produces: no signature changes — `updateCanvasPosition`, `getPrimitiveDepth`, `drawPrimitive` keep their existing signatures. Only the internal sort direction of `m.modelCanvasFaces` changes.

**Root cause** (per issue #112): `updateCanvasPosition()`'s `m.modelCanvasFaces.SortBy("priority")` (`SceneObjectModel.bs:224`) sorts ascending by `priority` — a positive value, larger for a face farther from the camera — so index 0 is the *nearest* face and the last index is the *farthest*. `drawToCanvas()`/`drawToTempBitmap()` iterate that list in stored order with no reversal (`for each face in m.modelCanvasFaces`), so the nearest face draws first and the farthest face draws last — on top, backwards from a standard painter's algorithm, where the farthest primitive should draw first (as background) and the nearest should draw last (on top, correctly occluding what's behind it).

**Why this is safe to fix without touching the cluster path**: `getPrimitiveDepth(index)`/`drawPrimitive(rendererObj, index)` (`SceneObjectModel.bs:276-285`) look up `m.modelCanvasFaces[index]` by explicit index, never by iterating the array's order — and `Renderer.drawPendingClusterPrimitives()` (the cluster path's caller) builds its own combined `primitiveEntries` list by visiting every index `0..getPrimitiveCount()-1` and re-sorting that combined list itself by depth. Reversing `modelCanvasFaces`'s internal storage order has zero effect on the cluster path's correctness — only the solo `drawToCanvas`/`drawToTempBitmap` iteration order actually depends on it.

**The fix**: change the sort to descending (farthest-first, matching the required draw order), so the two draw loops need no other change:

```brighterscript
m.modelCanvasFaces.SortBy("priority", "r")
```

(Roku's `roArray.SortBy(fieldName, flags)` accepts `"r"` in `flags` to reverse the sort — descending instead of ascending.)

Also update the stale `KNOWN LIMITATION (see issue #112)` doc comment on `getPrimitiveDepth` (`SceneObjectModel.bs:261-272`), which currently describes the solo/cluster disagreement as an open, undisclosed inconsistency — replace it with a note that the fix landed and the two paths now agree, per issue #112's own closing note ("the disclosed solo-vs-clustered inconsistency... should be resolved for free").

- [ ] **Step 1: Write the failing test**

Add to `src/source/engine/renderer/sceneObjects/SceneObjectModel.spec.bs`, inside `SceneObjectModelTests`, after the existing `@describe("getPrimitiveCount / getPrimitiveDepth / drawPrimitive (cluster draw contract)")` block's tests (after the "getPrimitiveDepth ranks a closer face as greater..." test):

```brighterscript
    @describe("intra-model solo draw order (issue #112)")

    @it("stores the farthest face first and the nearest face last, so the solo draw loop paints farthest-first (painter's algorithm)")
    function _()
      ' Two faces at very different depths from the camera - faceFar should be
      ' drawn first (as background), faceNear drawn last (on top, correctly
      ' occluding faceFar if they overlapped on screen).
      faceNear = BGE.Model3dFaceOps.create([BGE.Math.VectorOps.create(-10, -10, -5), BGE.Math.VectorOps.create(10, -10, -5), BGE.Math.VectorOps.create(0, 10, -5)])
      faceFar = BGE.Model3dFaceOps.create([BGE.Math.VectorOps.create(-10, -10, -500), BGE.Math.VectorOps.create(10, -10, -500), BGE.Math.VectorOps.create(0, 10, -500)])
      model = new BGE.Model3d([faceNear, faceFar])
      drawableModel = new BGE.DrawableModel(m.entity, model)
      drawableModel.drawMode = BGE.SceneObjectDrawMode.solidDrawBackFace
      sceneObj = drawableModel.addToScene(m.renderer)
      m.entity.updateTransformationMatrix()
      m.renderer.setupCameraForFrame()
      sceneObj.update(m.renderer.camera)
      sceneObj.draw(m.renderer)
      m.assertEqual(2, sceneObj.getPrimitiveCount())
      ' getPrimitiveDepth(index) reads -m.modelCanvasFaces[index].priority (more
      ' negative = farther). Index 0 must be the farthest face (drawn first, as
      ' background) and the last index must be the nearest face (drawn last, on
      ' top) - this directly verifies modelCanvasFaces' stored order without
      ' needing pixel-level rendering readback.
      m.assertTrue(sceneObj.getPrimitiveDepth(0) < sceneObj.getPrimitiveDepth(1))
    end function
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm run build-tests && npm run test:ci`
Expected: FAIL — with the current ascending `SortBy("priority")`, index 0 is the nearest face (less negative depth) and index 1 is the farthest (more negative), so `getPrimitiveDepth(0) < getPrimitiveDepth(1)` is false as currently implemented.

- [ ] **Step 3: Implement**

In `src/source/engine/renderer/sceneObjects/SceneObjectModel.bs`, change line 224:

```brighterscript
      m.modelCanvasFaces.SortBy("priority", "r")
```

Update the doc comment on `getPrimitiveDepth` (replacing the `KNOWN LIMITATION` paragraph, `SceneObjectModel.bs:261-272`):

```brighterscript
    ' Fixed (issue #112): updateCanvasPosition()'s `m.modelCanvasFaces.SortBy("priority", "r")`
    ' now sorts descending (farthest-first), matching this method's own farthest-first
    ' convention - the solo draw loop (drawToCanvas/drawToTempBitmap, which iterate
    ' modelCanvasFaces in stored order with no reversal) and the cluster draw path
    ' (this method + drawPrimitive, which look up by index and get re-sorted by
    ' Renderer.drawPendingClusterPrimitives independently) now agree: both draw a
    ' model's self-overlapping faces farthest-first, nearest-last-on-top, regardless
    ' of whether the model draws solo or as part of a multi-member overlap cluster.
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npm run build-tests && npm run test:ci`
Expected: PASS. Also re-run the full suite to confirm no regression in the other `SceneObjectModel.spec.bs` tests (which don't depend on inter-face ordering, only single-face or count-based assertions) or elsewhere.

- [ ] **Step 5: Validate, on-device spot-check, and commit**

Run: `npm run validate`

Since this changes already-shipped model rendering behavior (not new code), do a quick on-device/simulator spot-check of `examples/3d`'s `ModelRoom` (the pre-existing bird model) and the new `CarRoom`/`D20Room` from Task 6, to confirm no visual regression — per issue #112's own suggested verification step.

```bash
git add src/source/engine/renderer/sceneObjects/SceneObjectModel.bs src/source/engine/renderer/sceneObjects/SceneObjectModel.spec.bs
git commit -m "Fix intra-model face draw order: farthest-first, matching painter's algorithm (issue #112)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 8: Docs — close out issue #89's references in CLAUDE.md

**Files:**
- Modify: `/Users/mpearce/redspace/roku/brighterscript-game-engine/CLAUDE.md`

Per this project's standing rule to review docs on significant engine changes, `CLAUDE.md`'s `OBJParser` note under **Math / Utils** currently describes texture mapping as unimplemented follow-up work referencing issue #89 by name — that's now stale.

- [ ] **Step 1: Update the OBJParser bullet**

Find the bullet starting `- **\`OBJParser\` is geometry-only today** (issue #89):` in the **Math / Utils** section and replace it with:

```markdown
- **`OBJParser` supports geometry and one diffuse texture per model** (issue #89): it parses `.obj` `v`/`vt`/`f` lines (fan-triangulating any quad/n-gon face, including each face's UV points) into `Model3dFace`, computing each face's normal from its own vertex geometry rather than trusting `vn` data (`Model3dFace` only supports one flat normal per face, not smooth/per-vertex shading). A texture comes from either `mtllib`/`map_Kd` (resolved relative to the `.obj`'s own directory) or an explicit `options.texturePath` passed to `Game.load3dModel` (which always wins) - `usemtl`/multi-material meshes are still out of scope, one texture per model. `BGE.Model3dOps.applyTexture` does the actual bitmap-load-to-pixel-space-UV finalization; `SceneObjectModel` draws a textured face via `Renderer.drawBitmapTriangle(To)` (affine-mapped, not perspective-correct) instead of a flat fill. See `specs/2026-08-19-textured-obj-models-design.md`.
```

- [ ] **Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "Update CLAUDE.md: OBJParser textured model support is implemented (issue #89)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Final Verification

- [ ] Run `npm run check` from the repo root — lint, validate, and headless tests all pass.
- [ ] Confirm Task 6's on-device verification actually happened and the texture rendered correctly (not just that the build succeeded).
- [ ] Close/reference issue #89 in the eventual PR description.
