# Tiled JSON maps (issue #196)

## Intent

Load levels made in [Tiled](https://www.mapeditor.org/) from its JSON export, so a game can
author maps in an editor instead of strings in code. The engine already has the helpers that
turn plain lists of cells into baked images and merged colliders (`BGE.TileMap`); this adds a
parser for the format and small helpers that produce those lists.

## Goals

- `BGE.Tiled.parseMapFile(path)` / `parseMapJson(json, baseDir)` → a typed `TiledMap`.
- Helpers that turn a tile layer into `TileMap.TileSpec[]` and `TileMap.ColliderCell[]`, look up
  a tile by cell, and convert Tiled pixel coordinates to world coordinates.
- Object layers (spawn points, triggers) and custom properties on maps, layers, tiles and objects.
- `examples/platformer` level 1 moves to a `.tmj` map with an external `.tsj` tileset; levels
  2-7 stay as strings.
- A Tiled section in `docs/tile-maps.md`.

## Non-goals

- Infinite maps, non-orthogonal orientations, compressed layer data (zlib/gzip/zstd: Roku has no
  decompressor), XML formats (`.tmx`, `.tsx` external tilesets), object templates, animated
  tiles, Wang sets, image-layer rendering, diagonal-flip (rotated) tiles.
- An entity/spawner framework. Game code loops over objects and spawns its own entities.

## Decided

### Real data

Built against two real exports, kept as trimmed excerpts in the parser specs:

- Tiled's own `examples/sticker-knight/ui/title.json` (Tiled 1.8.2, public domain): object
  layers only, an image-collection tileset, tile objects, parallax, `backgroundcolor`.
- `mapeditor/tiled-bulk-animations` `src/tests/data/test_map.json` (Tiled 1.4.2, MIT): one tile
  layer as a plain array, ten embedded spritesheet tilesets, `transparentcolor`, animations.

External tilesets, properties, flip bits and base64 data follow the format reference.

### Files (`src/source/utils/tiled/`)

- `TiledTypes.bs` — interfaces only.
- `TiledParser.bs` — JSON → `TiledMap`; external `.tsj` loading; base64 layer data.
- `TiledGids.bs` — `resolveGid()`: flip flags and tileset lookup.
- `TiledLayers.bs` — `getLayer`, `getTileAt`, `getLayerCells`, `layerToTileSpecs`,
  `layerToColliderCells`, `toWorldX/Y`.

### Data model

- `TiledMap`: `width`, `height`, `tileWidth`, `tileHeight`, `backgroundColor`, `properties`,
  `tilesets`, `layers`. Group layers are flattened depth-first (offsets and visibility combined)
  so every layer is reachable by name.
- `TiledLayer`: `type` (`tilelayer`/`objectgroup`/`imagelayer`), `id`, `name`, `visible`,
  `opacity`, `offsetX/Y`, `properties`; tile layers add `width`, `height`, `data` (raw GIDs);
  object layers `objects`; image layers `image`.
- `TiledTileset`: `firstGid`, `name`, `tileCount`, `columns`, `tileWidth/Height`, `margin`,
  `spacing`, `image` (full path) + `imageWidth/Height`, `tileOffsetX/Y`, `tileRenderSize`
  (`tile`/`grid`), `tiles` (local id string → `TiledTile`). Spritesheets and image collections
  share the shape; a collection tile carries its own `image`.
- `TiledTile`: `id`, `type`, `properties`, `image`, `imageWidth/Height`.
- `TiledObject`: `id`, `name`, `type`, `shape` (`rectangle`/`point`/`ellipse`/`polygon`/
  `polyline`/`tile`/`text`), `x`, `y`, `width`, `height`, `rotation`, `visible`, `points`,
  `gid`, `properties`.

Normalised: `class` (Tiled 1.9+) and `type` (older) both become `type`; property lists become
`name → value` AAs; layer data is always an integer array.

### GIDs

Tiled packs flip flags into the top bits (H `0x80000000`, V `0x40000000`, D `0x20000000`, hex
rotation `0x10000000`). Those values don't fit a signed 32-bit Integer, so `resolveGid()` works
in LongInteger, and also accepts a negative Integer or a Double (whatever `ParseJson` gives).
Returns `TiledGidInfo` `{gid, tileset, localId, tile, flipH, flipV, flipD}`, or invalid for 0
or an unknown GID. Tilesets are sorted by `firstGid` and searched in reverse.

### Turning layers into TileMap lists

- Rows count down; world +y is up. `toWorldY(map, pixelY, offsetY)` = `map.height *
  tileHeight - pixelY + offsetY`; `toWorldX` adds `offsetX`.
- `layerToTileSpecs(map, layer, options)`: one `TileSpec` per non-empty cell. Spritesheet tiles
  use a region at `margin + col * (tileWidth + spacing)`; collection tiles the whole image.
  `tileRenderSize = "tile"` draws at the tile's own size, bottom-left aligned to the cell (as
  Tiled draws); `"grid"` stretches it to the cell. The tileset's `tileOffset` and the layer
  offset are applied. Bitmaps load once per image per call. Options: `offsetX`, `offsetY`
  (world units added to every tile).
- Flips: `TileSpec` gains optional `flipH`/`flipV`; `bakeTileMapImages()` draws those with a
  negative scale. Diagonal flips draw unflipped (printed warning once per call).
- `layerToColliderCells(map, layer, propertyName = "collision")`: a cell whose tile has a
  non-empty string value for the property becomes `{row, col, tag: value}`.
- `getTileAt(map, layer, col, row)` → `TiledGidInfo` or invalid.

### Errors

`parseMapFile`/`parseMapJson` print `[BGE.Tiled] <reason>` and return invalid for: unreadable
file, invalid JSON, `infinite`, non-orthogonal `orientation`, compressed data, a `.tsx` tileset,
an unreadable `.tsj`. Templates (`template` on an object) print a warning and the object keeps
whatever inline fields it has.

### Platformer

- `src/maps/level1.tmj` + `src/maps/tiles.tsj` (image collection: surface-solid, surface-oneWay,
  fill; `tilerendersize: grid`, `tileoffset.y = -5`, which replaces the hand-coded 5px nudge).
  Layers: `ground` (tile layer), `spawns` (object layer of points typed `player`/`coin`/`enemy`/
  `goal`, placed at the exact world anchor each entity used before).
- `LevelData`: `getLevelMapPath(i)` ("" for string levels); `getLevelMap(i)` parses once and
  caches in the global AA. `getLevelNumCols` and `isSolidGroundAt` read the map when there is one.
- `Level.onCreate` uses `layerToTileSpecs` / `layerToColliderCells` for a map level.
  `MainScene` spawns from `spawns` objects for a map level; both paths go through one
  `spawnEntity(kind, x, y)`.

### Testing

- Rooibos specs per file: parse both real excerpts; external `.tsj` written to `tmp:/`; base64
  data; compressed/infinite/isometric/`.tsx` rejection; property and `class` normalisation;
  group flattening; GIDs with every flip bit (as LongInteger, negative Integer and Double);
  tile specs for spritesheet (margin/spacing), collection `tile` vs `grid`, tile offset; collider
  cells; world coordinates; baking with `flipH`.
- Device: platformer level 1 must look and play the same as before (screenshot comparison).
