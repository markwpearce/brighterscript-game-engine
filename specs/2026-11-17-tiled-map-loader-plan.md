# Tiled map loader implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `AssetLoader.loadTiledMap()` loads a Tiled map, its external tilesets and its images from a local path or a URL, over several frames (#493).

**Architecture:** The parser gains a way to be handed external tilesets instead of reading them, plus listing helpers. A `TiledMapLoadTask` (a `FileLoadTask`) downloads/reads the map, then its tilesets, parses, then loads each image with `BitmapLoadTask`s, and registers the map (with `map.bitmaps`) on the `Game`. `layerToTileSpecs()` defaults to `map.bitmaps`. Spec: `specs/2026-11-17-tiled-map-loader-design.md`.

**Tech Stack:** BrighterScript, Rooibos v6, rokubot.

## Global Constraints

- No single-line `if`; real types; `import` what you use; no `=` between objects; no `continue for` after an inner loop.
- `assertEqual` is type-strict. One `@suite` per spec file; `@describe` before the first `@it`.
- Tests: `TEST_SHARDS=engine-ui npm run test:ci` covers `loading/` specs; `utils/` specs are in another shard (run `npm run check` for all). Fakes: `tests.ServedAssetLoader` (`files[url] = localPath`, `requested`), `tests.FakeTextureLoader`, `tests.runLoader(loader)`, `tests.writeAtlasSheet(path, w, h)`, `tests.TiledFixtures.mapJson(overrides)`.

---

### Task 1: Parser split

**Files:** Modify `src/source/utils/tiled/TiledParser.bs`, `src/source/utils/tiled/TiledTypes.bs`; test `src/source/utils/tiled/TiledParser.spec.bs`.

**Produces:** `BGE.Tiled.parseMapJson(json as string, baseDir as string, tilesets = invalid as dynamic) as TiledMap`; `BGE.Tiled.listExternalTilesets(json as string, baseDir as string) as string[]`; `BGE.Tiled.listTiledMapImages(map as TiledMap) as string[]`; `TiledMap.name` and `TiledMap.bitmaps` (optional).

- [ ] Failing tests (new `@describe("loading helpers")`):
  - `listExternalTilesets` on a map with `[{firstgid:1, source:"../tilesets/a.tsj"}, {firstgid:5, name:"inline", ...}, {firstgid:9, source:"../tilesets/a.tsj"}, {firstgid:13, source:"b.tsx"}]` and base `"https://host/maps/"` returns `["https://host/tilesets/a.tsj"]`.
  - `parseMapJson(json, "tmp:/x/maps/", {"tmp:/x/tilesets/a.tsj": <tileset AA with image "../art/a.png">})` gives `tilesets[0].image = "tmp:/x/art/a.png"` and never touches disk (no file written).
  - `parseMapJson` with an empty `{}` tilesets AA and an external source returns invalid.
  - `listTiledMapImages` returns the spritesheet image and each image-collection tile image once, for a map with one of each (tile images repeated across tiles listed once).
- [ ] Run; expect `cannot-find-function`.
- [ ] Implement: thread `tilesets` through `parseMapJson` → `parseTilesetEntry(raw, baseDir, tilesets)`. In `parseTilesetEntry`, after resolving `path`: if `tilesets <> invalid`, `rawTileset = tilesets[path]` instead of reading the file (the AA lookup is case-insensitive, which matches Roku's case-insensitive file paths). Add the two list functions; `listExternalTilesets` parses the JSON, walks `tilesets`, skips entries without `source` and `.tsx` ones, dedupes with an AA. Add `optional name as string` and `optional bitmaps as roAssociativeArray` to `TiledMap` with doc comments ("set by AssetLoader.loadTiledMap()").
- [ ] Run (`npm run check`); expect PASS. Commit `Tiled: let the parser take external tilesets, and list what a map needs (#493)`.

### Task 2: Game storage and `layerToTileSpecs` default

**Files:** Modify `src/source/engine/Game.bs` (next to the sprite atlas methods), `src/source/utils/tiled/TiledLayers.bs`; tests `src/source/utils/tiled/TiledLayers.spec.bs` and a Game-level test in the Task 3 spec.

**Produces:** `Game.addTiledMap(map as BGE.Tiled.TiledMap)`, `Game.getTiledMap(name as string) as BGE.Tiled.TiledMap`, `Game.unloadTiledMap(name as string)` (unloads bitmaps named `tiled:<name>:<path>` for each key of `map.bitmaps`, then forgets the map).

- [ ] Failing test in `TiledLayers.spec.bs`: a map whose `bitmaps` holds a 32x32 bitmap under its tileset image path (a path that doesn't exist on disk) gives tile specs with regions from it when `layerToTileSpecs(map, layer)` is called with no options.
- [ ] Implement: in `layerToTileSpecs`, `if bitmaps = invalid and map.bitmaps <> invalid then bitmaps = map.bitmaps` (multi-line `if`). Game: `private tiledMaps as roAssociativeArray = {}` and the three methods.
- [ ] Run, PASS. Commit with Task 3.

### Task 3: `TiledMapLoadTask` and `AssetLoader.loadTiledMap`

**Files:** Create `src/source/engine/loading/TiledMapLoadTask.bs`; modify `src/source/engine/loading/AssetLoader.bs`; test `src/source/engine/loading/AssetLoaderTiledMaps.spec.bs`.

**Consumes:** Task 1 and 2 APIs; `FileLoadTask`, `BitmapLoadTask(game, name, path)`, `AssetLoader.getDownloadTask(url, options)`, `DownloadTask.step/abort/localPath/error`.

- [ ] Failing tests. `beforeEach`: game + `FakeTextureLoader` + `ServedAssetLoader`; write `tmp:/bge_tmap/art/ground.png` (`tests.writeAtlasSheet(..., 32, 32)`), `tmp:/bge_tmap/tilesets/ground.tsj` (spritesheet, `image: "../art/ground.png"`, 4 tiles of 16x16, 2 columns), `tmp:/bge_tmap/maps/level.tmj` (`mapJson` with that external tileset and a 4x3 tile layer `ground` using gid 1). Tests:
  - loads a local map: no errors, `game.getTiledMap("level")` has `name = "level"`, `bitmaps["tmp:/bge_tmap/art/ground.png"]` width 32, one texture request.
  - `layerToTileSpecs(map, getLayer(map, "ground"))` returns tiles and makes no new texture request.
  - downloads a URL map, its tileset and image relative to the map's URL: `files` for `https://example.com/maps/level.tmj`, `https://example.com/tilesets/ground.tsj`, `https://example.com/art/ground.png`; `requested` has all three in that order; `bitmaps` keyed by `https://example.com/art/ground.png`.
  - fails naming the tileset when it's missing (local); map not added.
  - fails naming the image when the tileset image is missing; map not added.
  - a map that isn't JSON: error, and for a URL map the downloaded copy is discarded (error contains "discarded").
  - `unloadTiledMap("level")` forgets the map and its bitmap (`game.getBitmap("tiled:level:tmp:/bge_tmap/art/ground.png")` invalid).
- [ ] Run, expect failures.
- [ ] Implement `TiledMapLoadTask`:

```brightscript
import "../../utils/tiled/TiledParser.bs"
import "../../utils/urls.bs"
import "../Game.bs"
import "AssetLoadTasks.bs"
import "DownloadTask.bs"

namespace BGE

  ' Loads a Tiled map, its external .tsj tilesets and its images - see AssetLoader.loadTiledMap().
  class TiledMapLoadTask extends FileLoadTask
    ' Makes the tileset and image downloads. Set by AssetLoader.
    loader as BGE.AssetLoader = invalid
    ' Options for those downloads. Set by AssetLoader.
    downloadOptions as BGE.DownloadOptions

    private game as BGE.Game
    private mapName as string
    private mapJson as string = ""
    private baseDir as string = ""
    ' resolved .tsj path -> DownloadTask, or the parsed AA once read
    private tilesetDownloads as roAssociativeArray
    private tilesets as roAssociativeArray = invalid
    private map as BGE.Tiled.TiledMap = invalid
    private imagePaths as string[]
    private imageTasks as BGE.BitmapLoadTask[]
    private imageCount as integer = 0
    private imageErrors as string[]
    private jsonBad as boolean = false
```

  `loadFile(budgetMs)`: (1) if `mapJson = ""`: read `m.path` (`ReadAsciiFile`); empty → `error = "tiled map not found: " + m.source`, return true; `baseDir = BGE.Urls.parentFolder(m.source)` (the source URL, so relative paths resolve against it); start a download (URL) or read+`ParseJson` (local) for each `listExternalTilesets(mapJson, baseDir)`. (2) Step tileset downloads within budget; when one finishes, read+parse its `localPath`; a download error or non-AA → `error = "tiled map " + mapName + ": can't read tileset " + path` (+ download error), return true. Wait (`waitingForNextFrame = true`, return false) until all are parsed. (3) `map = BGE.Tiled.parseMapJson(mapJson, baseDir, tilesets)`; invalid → `jsonBad = true`, `error = "tiled map " + m.source + " isn't a map Tiled can load (see the [BGE.Tiled] message)"`, return true. Build one `BitmapLoadTask(game, "tiled:" + mapName + ":" + path, path)` per `listTiledMapImages(map)`, with `download = loader.getDownloadTask(path, downloadOptions)` for URLs. (4) `stepImages(budgetMs)` (same shape as `SpriteAtlasLoadTask.stepSheets`); unfinished → wait. (5) image errors → `error = "tiled map " + mapName + " (" + m.source + "): " + errors.Join("; ")`, return true. Else `map.name = mapName`, `map.bitmaps = {}` filled with `game.getBitmap("tiled:" + mapName + ":" + path)` per path, `game.addTiledMap(map)`, return true.
  Also: `getFileProgress()` (0 until parsed, then `0.1 + 0.9 * done/imageCount`, 1.0 if no images), `isDownloadedFileBad()` returns `m.jsonBad`, `abort()` aborts tileset downloads and image tasks. `downloadShare = 0.1` in `new()`.
- [ ] `AssetLoader.loadTiledMap(mapName as string, pathOrUrl as string, options = {} as BGE.DownloadOptions) as BGE.LoadTask`: same shape as `loadSpriteAtlas` (extension `.tmj`). Doc comment covers local/URL, relative resolution, caching, `game.getTiledMap()`, `layerToTileSpecs()` using `map.bitmaps`.
- [ ] Run, PASS; `npm run check`. Commit `Loading: AssetLoader.loadTiledMap() for local and remote Tiled maps (#493)`.

### Task 4: Demos and docs

- [ ] `examples/loading/remote-assets/maps/`: `meadow.tmj` (10x4, 32px tiles, one tile layer using an external tileset) and `meadow.tsj` (`image: "../images/meadow-tiles.png"`, 2x2 tiles of 32px); `remote-assets/images/meadow-tiles.png` generated by a small Node script writing a 64x64 PNG of four flat colours (or hand-made). `RemoteAssetsScene.onLoad`: `m.tasks["meadow.tmj"] = loader.loadTiledMap("remoteMeadow", m.baseUrl + "maps/meadow.tmj")`; `onCreate`: draw its `ground` layer via `layerToTileSpecs()` as images in a strip under the existing list (fit inside title-safe).
- [ ] Platformer: `MainScene.onLoad(loader, args)`: when the level's source is a Tiled path, `loader.loadTiledMap(source, source)`; in `LevelData.bs`, `getLevelMap()` first uses a map stored by `rememberLevelMap(source, map)` (called from `MainScene.onCreate` with `m.game.getTiledMap(source)`), falling back to `parseMapFile()`.
- [ ] Docs: `docs/tile-maps.md` section "Loading with AssetLoader" (example, URL note, `getTiledMap`, `unloadTiledMap`); `docs/loading-assets.md` adds `loadTiledMap` to the loader call list. `examples/loading/remote-assets/README.md` mentions the map.
- [ ] `npm run check`, validate examples. Device: serve `examples/loading/remote-assets` from the Mac (`python3 -m http.server 8000 --directory examples/loading/remote-assets`), `npm run run-example -- loading scene=RemoteAssetsScene baseUrl=http://<mac ip>:8000/` (or sideload + `launch dev --param`), screenshot the map strip; relaunch shows `cache`. Platformer level 1 (`level=1`) loads and plays.
- [ ] Commit, push, PR closing #493.
