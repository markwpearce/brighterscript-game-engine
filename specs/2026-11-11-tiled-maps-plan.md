# Tiled JSON maps — implementation plan

Spec: `2026-11-11-tiled-maps-design.md`. Executed inline (TDD per task, `npm run check` at the
end of each engine task).

**Goal:** parse Tiled JSON maps into a typed `TiledMap` and turn layers into the existing
`BGE.TileMap` lists; move platformer level 1 onto a `.tmj`.

**Global constraints:** CLAUDE.md conventions (real types, imports, no single-line `if`, no
object `=`); namespace `BGE.Tiled`; files in `src/source/utils/tiled/`; one `@suite` per spec.

## Task 0: probe brs-cli behaviour

Throwaway spec (not committed): what `ParseJson` returns for `3221225473` and `2147483649`;
`roByteArray.FromBase64String` + byte reads; `DrawScaledObject` with negative scale. Results
decide the GID and flip code.

## Task 1: types + parser core (`TiledTypes.bs`, `TiledParser.bs`)

Specs (`TiledParser.spec.bs`): sticker-knight excerpt (object layers, collection tileset, tile
objects, `backgroundColor`, `parallax` ignored); bulk-animations excerpt (tile layer data,
multiple tilesets sorted by `firstGid`, `imageWidth`); property list → AA; `class` → `type`;
group layers flattened with combined offsets/visibility; base64 data; rejections (infinite,
isometric, compressed, `.tsx`, bad JSON, missing file → invalid); external `.tsj` via `tmp:/`
with image path resolved against the `.tsj` folder; object shapes (point, ellipse, polygon,
tile, text, rectangle).

## Task 2: GIDs (`TiledGids.bs`)

`resolveGid(map, gid as dynamic) as TiledGidInfo`. Specs: plain GID per tileset boundary; 0 and
out-of-range → invalid; each flag (as LongInteger, negative Integer, Double); local tile lookup
(`tile` invalid when the tileset has no entry for it).

## Task 3: layer helpers (`TiledLayers.bs`) + `TileSpec` flips

`getLayer`, `getTileAt`, `getLayerCells`, `toWorldX/Y`, `layerToColliderCells`,
`layerToTileSpecs`; `TileSpec.flipH/flipV` drawn by `bakeTileMapImages`. Specs: world coords;
collider cells by property; tile specs for spritesheet regions (margin/spacing), collection
`tile` (bottom-aligned, own size) vs `grid` (stretched), tile + layer offsets, options offsets;
flipped bake mirrors pixels.

## Task 4: platformer level 1

`src/maps/tiles.tsj`, `src/maps/level1.tmj` (generated once from the level-1 strings, same
positions); `LevelData` map lookup/cache; `Level`, `MainScene`, `isSolidGroundAt`,
`getLevelNumCols` read the map. Validate example; device screenshot level 1 before/after.

## Task 5: docs

`docs/tile-maps.md` "Map editors" → a Tiled section (export settings: JSON, CSV/base64
uncompressed, `.tsj` tilesets, embed or external; the API; coordinates; what's unsupported).
