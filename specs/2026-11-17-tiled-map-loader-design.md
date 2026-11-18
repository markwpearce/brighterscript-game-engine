# Loading Tiled maps with AssetLoader (#493)

## Problem

`BGE.Tiled.parseMapFile()` only reads local files: the map and any external `.tsj` tilesets are
read with `ReadAsciiFile`, and `layerToTileSpecs()` loads tileset images with
`CreateObject("roBitmap", path)`. A map can't come from a URL, and a big local map loads all at
once on the main thread.

## Parser split (`utils/tiled/TiledParser.bs`)

Existing calls behave as today.

- `parseMapJson(json, baseDir, tilesets = invalid)`: optional `tilesets` maps a resolved `.tsj`
  path/URL to its parsed JSON (an AA). When given, external tilesets come only from it; a missing
  entry is an error ("can't read tileset ..."), as an unreadable file is now.
- `listExternalTilesets(json, baseDir) as string[]`: resolved paths/URLs of the external `.tsj`
  files the map names, in order, without duplicates. `.tsx` entries are skipped here (the parse
  reports them).
- `listTiledMapImages(map) as string[]`: every distinct image path the map's tilesets use
  (spritesheet `image`s and image-collection tile `image`s).
- Paths resolve with `BGE.Urls.joinPath`, which already handles URL bases; an external tileset's
  images resolve against the tileset's own folder.

## `AssetLoader.loadTiledMap(mapName, pathOrUrl, options = {})`

Returns a `TiledMapLoadTask` (`loading/TiledMapLoadTask.bs`, a `FileLoadTask` like
`SpriteAtlasLoadTask`). A URL is downloaded first via `attachDownload` (extension `.tmj`).

`loadFile()` steps:

1. Read the map file. Empty/missing: error `tiled map not found: <source>`.
2. `listExternalTilesets()`. For each: a URL gets a `DownloadTask` from the loader (shared and
   cached like other downloads); a local path is read directly. Step downloads within the budget.
   A tileset that won't download or parse: error.
3. `parseMapJson(json, baseDir, tilesets)`. Invalid: error, and mark the downloaded map bad
   (`isDownloadedFileBad()`), so it isn't kept in the cache.
4. For each `listTiledMapImages()` path, a `BitmapLoadTask` named `tiled:<mapName>:<path>`
   (URLs download through the loader), stepped within the budget like atlas sheets.
5. Done: `map.name = mapName`, `map.bitmaps = {path: bitmap}`, `game.addTiledMap(map)`. Any
   image errors: the task's `error` lists them and the map isn't added.

Progress: 0.1 once the map and tilesets are parsed, then 0.9 spread over the images. `abort()`
also aborts tileset downloads and image tasks.

## Game and TiledLayers

- `TiledMap` gets optional `name as string` and `bitmaps as roAssociativeArray`.
- `Game.addTiledMap(map)`, `getTiledMap(name)`, `unloadTiledMap(name)` (also unloads its
  `tiled:<name>:` bitmaps), next to the sprite atlas methods.
- `layerToTileSpecs()` uses `map.bitmaps` when `options.bitmaps` isn't given.

## Testing

Rooibos:

- Parser: `listExternalTilesets()` (local and URL base, dedupe, `.tsx` skipped); `parseMapJson()`
  with supplied tilesets and with one missing; `listTiledMapImages()` for a spritesheet and an
  image collection.
- `TiledMapLoadTask` with the existing download fakes: a local map with an external tileset; a URL
  map whose `.tsj` and image resolve against the map's URL and download; a missing tileset and a
  missing image fail; a map that isn't valid JSON is marked bad; `getTiledMap()` returns the map
  with `bitmaps` filled; `layerToTileSpecs()` uses them.

Device:

- `examples/loading`: a small map (external `.tsj`, one tileset image) in `remote-assets/maps/`,
  loaded and drawn in the Remote assets scene; checked by serving `remote-assets` from the Mac.
- Platformer: level 1 loads through `loadTiledMap()` in the level scene's `onLoad`.

## Docs

`docs/tile-maps.md` (loading with the loader) and `docs/loading-assets.md` (the new loader call).
