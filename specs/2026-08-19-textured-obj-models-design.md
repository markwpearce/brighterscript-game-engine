# Textured `.obj` 3D models — design

Issue: #89

## Summary

Extend `OBJParser`/`Model3d`/`SceneObjectModel` so a loaded `.obj` model can
carry a diffuse texture (a `.png` sampled via UV coordinates) instead of only
ever rendering as flat-shaded triangles. Texture mapping is affine, via the
existing `Renderer.drawBitmapTriangle(To)` primitive (already exercised by the
`rendererTest` "Bitmap Triangle Warp" demo) — no perspective-correct
interpolation. v1 supports exactly one texture per model (no per-face/
multi-material meshes).

Two ways to get a texture onto a model, both supported:

1. **Standard `.obj`/`.mtl` convention** — a `mtllib` line in the `.obj`
   pointing at a `.mtl` file with a `map_Kd <path>` diffuse texture.
2. **Explicit override** — the caller passes a texture path directly to
   `load3dModel`, which always wins over anything found via `mtllib`. This is
   required for `.obj` files that carry `vt`/`vn`/UV data but no
   `mtllib`/`usemtl` at all (confirmed real-world case — a supplied
   `car.obj` + separate texture atlas PNG, no material file).

## Public API

```brighterscript
interface Model3dLoadOptions
  optional texturePath as string
end interface

function load3dModel(modelName as string, modelPath as string, options = {} as BGE.Model3dLoadOptions) as boolean
```

Existing 2-arg callers (including every `.stl` load) are unaffected.
`options.texturePath`, when given, overrides any `mtllib`/`map_Kd` resolution
from the `.obj`/`.mtl` files.

## Parsing (`OBJParser.bs`) — stays Game-independent

`OBJParser` remains a pure parser with no `Game`/bitmap dependency, preserving
today's `OBJParser.spec.bs` convention of testing it without constructing a
`Game`.

- Parse `vt` lines into a `texCoords as Vector[]` list, **normalized** (0..1,
  `.obj`'s bottom-up `v` convention, unflipped at this stage).
- `resolveOBJFaceVertices` (or a sibling function) additionally resolves each
  face-corner's `vt` index (`v/vt/vn`, `v/vt`, or absent — `v//vn`/bare `v`
  have no `vt`) into a parallel per-corner texCoord list.
- Fan-triangulation (`appendOBJFace`) fans the texCoord list the same way it
  already fans vertices, so each emitted triangle's `Model3dFace` gets 3 UV
  points lined up with its 3 `vertices`.
- **Partial-texture graceful degrade**: a face where any corner lacks a `vt`
  index gets no `Texture` at all (`invalid`) — falls back to flat-color
  rendering for that face only, not the whole model.
- Parse `mtllib <name>.mtl` (first occurrence only, matching the existing
  `o`/`g` first-occurrence handling) → resolve relative to the `.obj` file's
  own directory → read that file → find the first `map_Kd <path>` line →
  resolve that path the same way (relative to the same directory) → store as
  a new `Model3d.texturePath as string` field (`invalid` if nothing found).
  `usemtl` stays ignored (single texture per model in v1 — no per-face
  material tracking).
- UV points on `Model3dFace.Texture` stay **normalized** at parse time —
  pixel-space conversion happens once, later, in `Game.load3dModel` (see
  below), since only `Game` can load the bitmap and learn its dimensions
  without breaking the parser's `Game`-independence. This still satisfies
  "convert once at load, not per frame" — it just lives in a different file
  than a naive reading of that requirement might suggest.

## Data model (`Model3d.bs`)

```brighterscript
class Model3dTexture
  srcRegionWithId as BGE.RendererHelpers.RegionWithId
  points as BGE.Math.Vector[]  ' 3 UV points: normalized while parsing, pixel-space after Game.load3dModel finalizes
  sub new(srcRegionWithId as BGE.RendererHelpers.RegionWithId, points as BGE.Math.Vector[])
    m.srcRegionWithId = srcRegionWithId
    m.points = points
  end sub
end class
```

`srcImage as ifRegion` becomes `srcRegionWithId as BGE.RendererHelpers.RegionWithId`
— matching how every other warp-draw source is carried elsewhere in the
engine (`SceneObjectImage`, `Renderer.getCircleRegionWithId`). Safe to change
since this field is unused scaffolding today (confirmed: no consumer reads
`.srcImage`, only pass-through copies of the whole `Texture` reference in
`SceneObjectModel`).

`Model3d` gains `texturePath as string` (resolved path from `mtllib`/`map_Kd`,
or `invalid`) — model-level, not per-face, matching the single-texture-per-
model decision.

## Texture finalization (`Game.load3dModel`)

After `BGE.Parsers.parseOBJFile(modelPath)` returns:

1. Resolve the effective texture path: `options.texturePath` if given, else
   `model.texturePath`, else skip texturing entirely (model loads flat-color,
   same as today — this is also the path every `.stl` load takes).
2. Load the bitmap via a small private helper (not `Game.loadBitmap`/
   `Game.Bitmaps` — see rationale below), mirroring
   `Renderer.getCircleRegionWithId`'s existing pattern:
   - `bmp = CreateObject("roBitmap", path)`
   - validate: `bmp <> invalid and bmp.GetWidth() > 0`
   - `region = CreateObject("roRegion", bmp, 0, 0, bmp.GetWidth(), bmp.GetHeight())`
   - `regionWithId = BGE.RendererHelpers.createRegionWithId(region, path)` — id
     is the resolved path (stable, unique per texture).
3. **On failure** (bad path, zero-size bitmap): log a warning via `m.log`,
   leave every face's `Texture` as `invalid`, `load3dModel` still returns
   `true` — geometry loads fine, just untextured. Matches the "fall back to
   flat-color" decision.
4. **On success**: walk `model.faces`; for each face with a non-invalid
   `Texture`, convert its 3 normalized UV points to pixel space
   (`u * width`, `(1 - v) * height` — flipping `v` since `.obj` UVs are
   bottom-up and bitmaps are top-down) and set `.srcRegionWithId` to the one
   shared `regionWithId` from step 2 (same reference across every face — one
   bitmap, one region, one triangle-cache key for the whole model).

**Why not `Game.loadBitmap`/`Game.Bitmaps`**: that registry is a
developer-facing, name-keyed table for bitmaps a game explicitly loads and
looks up later. A model's texture is internal state owned by the
`Model3d`/`Model3dTexture` themselves, not something looked up by name
elsewhere — so it gets its own private helper instead, and isn't registered
in `Game.Bitmaps`.

## Rendering (`SceneObjectModel.bs`)

`drawFaceToCanvas` (and its `drawToTempBitmap`/cluster-primitive
counterpart) — the single per-face draw dispatch used by both the solo-draw
and depth-sort cluster paths — gets a texture-aware branch, only for the fill
modes (`oriented`/`orientedDrawBackFace`/`solid`/`solidDrawBackFace`);
wireframe modes are unchanged (outline-only already, texture doesn't apply
there):

```brighterscript
shadedColor = BGE.colorBrightness(face.color, face.brightness)
if <fill mode>
  if face.Texture <> invalid
    return rendererObj.drawBitmapTriangle(face.Texture.srcRegionWithId, face.Texture.points, face.vertices, shadedColor)
  else
    return rendererObj.drawTriangle(face.vertices, 0, 0, shadedColor)
  end if
else if <wireframe mode>
  ' unchanged
end if
```

`shadedColor` — the existing brightness-tinted color every flat face already
gets — is passed through as `drawBitmapTriangle`'s optional RGBA tint, so a
textured face responds to the same lighting/brightness system as everything
else, rather than always drawing the texture at full untinted color.
`drawToTempBitmap` mirrors this with `drawBitmapTriangleTo` (mind the
existing "must call `bmpPool.returnStagedRegions()` after drawing" gotcha
noted on `drawBitmapTriangleTo`'s doc comment).

## Testing

- `OBJParser.spec.bs`: `vt`/UV parsing + fan-triangulation (parallel to the
  existing vertex fan-triangulation tests); `mtllib` → `.mtl` → `map_Kd` path
  resolution against small fixture `.obj`/`.mtl` files; a face missing a `vt`
  index falls back to no `Texture` (while sibling faces on the same model
  keep theirs); an explicit `texturePath` override takes precedence over
  `mtllib`. All Game-independent, matching the suite's current style for this
  file.
- A colocated `Game`-backed spec (matching the `Game.spec.bs`/
  `GameEntity.spec.bs` convention of constructing a real `Game`): `load3dModel`
  with a real texture image — success producing pixel-space UVs and one
  shared `srcRegionWithId` across faces; missing/bad texture path falling
  back gracefully (model loads, faces stay untextured, no crash).
- No automated coverage for actual rendered pixels — per this repo's
  established pattern, that's a `rendererTest`/example on-device concern, not
  something Rooibos can verify.

## Demo / on-device verification

Add the user-supplied `car.obj` + texture atlas PNG as a fixture under
`examples/3d` (new entity/room, e.g. `CarRoom`), loaded via `load3dModel`
with the explicit `texturePath` override (this file has no `mtllib`). Verify
it renders correctly via `rokubot` against a real/simulated Roku before
considering this done — mandatory per this repo's established convention for
any renderer-facing example change, not optional polish once static analysis
is clean.

## Out of scope (v1)

- Multiple textures/materials per model (per-face material assignment via
  `usemtl` groups).
- Perspective-correct UV interpolation (affine only, via the existing
  `drawBitmapTriangleTo` primitive).
- Registering the model's texture bitmap in `Game.Bitmaps`.
- Per-vertex normals / smooth shading (`Model3dFace` still carries one flat
  normal per face, per #89's existing scope note — untouched by this work).
