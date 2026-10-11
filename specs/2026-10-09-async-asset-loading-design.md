# Async asset loading and a scene loading stage (issue #301)

## Problem

Every asset loader on `Game` (`loadBitmap`, `loadSound`, `load3dModel`, `registerFont`,
`musicPlay`) takes a local path only, checks `m.filesystem.Exists(path)` first, and does all
its work synchronously in one call. So:

1. A game can't load assets from a server (DLC/levels, user content, a smaller channel
   package). `roBitmap`, `roAudioResource` and the font registry need a local file, so a URL
   has to be downloaded first, and downloads are asynchronous.
2. Slow *local* work has nowhere to go either. A big `.obj` parse, a large texture, or
   building a level all happen inside one frame (usually `onCreate`), freezing the screen
   with no feedback.

## Goals

- A **loading stage** in every scene change: after the outgoing scene is torn down and
  before the incoming scene's `onCreate()`, the engine runs whatever async/incremental work
  the incoming scene asked for, drawing a loading screen with progress.
- General enough that a developer can do "basically anything" during it: built-in asset
  loads, their own task classes, or a plain function called once a frame until it's done.
- Smooth progress bars: long work (e.g. parsing a 3D model) is broken into time-budgeted
  steps that report fractional progress.
- Load assets from `http(s)://` URLs, cached in `cachefs:` so later launches reuse them.
- Try `roTextureManager` for decoding bitmaps, and measure whether it keeps large decodes off
  the main loop.
- **Zero change for existing games**: a scene that doesn't opt in changes scene exactly as
  today, in the same frame, with no loading screen.

## Non-goals (v1)

- Cancelling a load from the loading screen.
- Cache expiry/ETag validation (a URL is assumed to always serve the same file; use versioned
  URLs).
- Splitting a single native call (`ReadAsciiFile`, `content.Split()`, one `roBitmap` decode,
  one `roAudioResource`) - see "Limits".
- Multi-material `.obj` (unchanged from #89).

## Scene change phases

Today: optional fade out -> `handleSceneChange()` (notify entities, destroy non-persistent
ones, old scene's `onChangeScene`, new scene's `onCreate`) -> optional fade in.

New:

1. **Fade out** - only with `changeSceneWithFade()`, unchanged.
2. **Teardown** - the existing first half of `handleSceneChange()`: every entity's
   `onChangeScene`, `gameUi`/`debugUi`'s, destroy non-persistent entities, the outgoing
   scene's `onChangeScene`. Happens *before* loading so the old scene's memory (textures on
   64MB HD devices) is free for the new one.
3. **Loading** (new) - `m.currentScene` becomes the new scene, then the engine creates a
   fresh `BGE.AssetLoader` and calls `newScene.onLoad(loader, args)`. If the loader has no
   tasks, loading ends immediately and phase 4 runs in the same frame (today's behaviour). Otherwise, each frame
   until the loader finishes:
   - input/URL/audio ports are read and dispatched as usual - persistent entities and
     `gameUi` keep updating and drawing. The new scene is already `currentScene` (so
     `onLoad` can read `game.currentScene`), but `Game` skips its per-frame callbacks
     (`onUpdate`, `onInput`, collisions, `onDrawBegin`/`End`, etc.) while `isLoading()`, so
     it gets none until after `onCreate()`;
   - `loader.update(budgetMs)` runs task steps (default budget 12ms/frame);
   - the loading screen is drawn (see below).
4. **Create** - `newScene.onCreate(args)`, `renderQuality.notifySceneChanged()`, garbage
   collection, as today.
5. **Fade in** - only with `changeSceneWithFade()`, unchanged.

`GameScene.onLoad(loader as BGE.AssetLoader, args as roAssociativeArray)` is an empty
overridable hook on `GameScene`. `resetScene()` runs the loading stage again (args are the
same; assets already loaded under a name are reloaded unless the scene skips them, e.g.
`if game.getBitmap("x") = invalid`).

A `changeScene()` requested during the loading stage is deferred until the stage ends,
then applied as a normal scene change (the loading scene gets its `onCreate`, then is torn
down). Simpler than cancelling mid-load, and v1 doesn't need cancellation.

New `Game` API:

- `isLoading() as boolean` - true during phase 3.
- `getLoadingProgress() as float` - 0..1, the active loader's progress (1 when not loading).
- `isTransitioning()` also returns true during phase 3.
- `loadingBudgetMs as integer = 12` - per-frame task budget during the loading stage.

## Task model

```brighterscript
class LoadTask
  weight as float = 1.0       ' share of the overall progress bar
  error as dynamic = invalid  ' string message once failed
  dependsOn as LoadTask[]     ' not started until these are done
  function step(budgetMs as integer) as boolean ' true when done (success or failure)
  function getProgress() as float               ' 0..1, never decreasing
end class
```

`BGE.AssetLoader`:

- `addTask(task as LoadTask) as LoadTask` - a developer's own subclass.
- `addStep(stepFunction as function, context as dynamic, weight = 1.0) as LoadTask` - wraps a
  plain `function(context) as dynamic` called once per step until it returns `true`; it may
  instead return a float 0..1 for progress (anything else = not done, progress unknown). The
  quickest way to build a level a few rows per frame.
- Built-in helpers, all returning their `LoadTask` (so another task can depend on them):
  - `loadBitmap(name, pathOrUrl, options = {})` - `options.width`/`height` resizes on load
    (see roTextureManager).
  - `loadSound(name, pathOrUrl, options = {})`
  - `load3dModel(name, pathOrUrl, options = {} as BGE.Model3dLoadOptions)` - incremental
    parse, then texture.
  - `registerFont(pathOrUrl, options = {})`
  - `download(url, options = {})` - just the download; `task.localPath` once done.
- `update(budgetMs)` - runs ready tasks round-robin, repeatedly, until all are done or the
  budget is used. Fast tasks complete many to a frame; a slow task gets at most one step per
  pass. Up to `maxConcurrentDownloads` (default 4) downloads in flight at once; local tasks
  are naturally serial since BrightScript is single-threaded.
- `isDone()`, `getProgress()` (weighted mean of task progress), `getErrors() as string[]`,
  `onComplete as function or dynamic` (called once, with the loader).

A failed task logs an error (same message style and `LogLevel.error` as today's loaders),
sets `error`, and counts as done; tasks depending on it also fail ("dependency failed")
without running. A scene that cares checks `game.getSceneLoader().getErrors()` in
`onCreate()` (`getSceneLoader()` returns the loader from the current scene's loading stage,
until the next scene change), so `onCreate(args)`'s signature doesn't change.

Loaded assets land in the same registries as today (`m.Bitmaps`, `m.Sounds`, `m.models`,
font registry), so `game.getBitmap(name)` etc. work unchanged.

### Background loading: `game.assets`

`Game` owns a long-lived `BGE.AssetLoader` (`game.assets`) with the same API, ticked once per
frame (after `processEntitiesPreDraw`, before draw) with `assetsBudgetMs` (default 4ms) so it
doesn't eat gameplay frames. For loading outside a scene change, e.g. fetching the next level
while this one plays. Its `onComplete` fires each time its queue drains. The loading stage
uses its own separate `AssetLoader` instance with the larger budget.

## Incremental model parsing

`BGE.Parsers.OBJParseTask` / `STLParseTask` (in `utils/parsers/`) hold their state between
steps: the file content split into lines (ASCII STL/OBJ) or the byte array (binary STL), the
current index, and the partially built `Model3d`. `step(budgetMs)` parses lines/triangles
until the budget is used, using an `roTimespan`; progress is `index / total`.

`parseOBJContent`/`parseSTLFile` become thin wrappers that run the same parse task to
completion in one call, so there's one parser, not two, and `game.load3dModel()` behaves
exactly as today. `AssetLoader.load3dModel()` adds the parse task, then a texture task
depending on it.

## Downloads and caching

`BGE.DownloadTask`:

- Its own `roUrlTransfer` + its own `roMessagePort`, polled in `step()`. It never touches
  `Game.urlPort`, so a game's `onUrlEvent` traffic is unaffected (today's loop reads only one
  URL message per frame).
- `AsyncGetToFile()` into a temporary `<target>.part`, renamed on success, deleted on failure.
- HTTPS: `SetCertificatesFile("common:/certs/ca-bundle.crt")` + `InitClientCertificates()`
  for `https://` URLs.
- Progress is 0 until done, then 1: on a real Roku the file only appears, complete, when the
  download finishes, and no "started" event is sent.
- `timeoutSeconds` (default 30) and `retries` (default 1).
- Failure (non-2xx, timeout, network error) sets `error` and logs it.
- The `roUrlTransfer` is created through an overridable factory (`createTransfer()`), so tests
  can pass a fake and never hit the network.

Cache:

- Default target: `cachefs:/bge/<hash of URL><original extension>` (the extension is kept
  because the loaders choose by it). Hash via `roEVPDigest` (MD5).
- If the file already exists it's used with no request.
- `options.cache = false` downloads to `tmp:/bge/` instead; `options.refresh = true`
  re-downloads over a cached copy.
- `game.assets.clearCache()` deletes `cachefs:/bge/`.
- `cachefs:` survives relaunches but the OS may evict it - it's a speed-up, never relied on.

URL-relative `.obj` textures: for a model loaded from a URL, `mtllib`/`map_Kd` paths resolve
against the model's URL (not its cache path) and become follow-on download tasks;
`options.texturePath` may also be a URL.

## Existing synchronous loaders

- `game.loadBitmap/loadSound/load3dModel/registerFont` given an `http(s)://` path log an error
  naming the async alternative (`game.assets.loadBitmap(...)` or `GameScene.onLoad`) and
  return false (`loadSound` is a `sub` today; it logs and returns). They can't block the
  game loop waiting for a download.
- Local-path behaviour is unchanged. The built-in loader tasks call these same functions once
  the file is local, so loading logic lives in one place.
- `musicPlay(url)` skips its `Exists()` check for `http(s)://` and lets `roAudioPlayer`
  stream it.

## roTextureManager

`roTextureManager` loads images asynchronously into an `roBitmap` and can resize while
loading (`roTextureRequest.SetSize`/`SetScaleMode`). Roku doesn't document whether the
decode happens off the BrightScript thread; brs-engine decodes on the main thread when
polled, so only a device can tell.

1. **Measure first.** A `rendererTest` demo (`texture-decode-benchmark`) decodes the same
   large PNG via `CreateObject("roBitmap", path)` and via an async `roTextureRequest`, while
   animating, and reports the worst frame time and average fps during each load. Run on a
   real device (FHD and, if available, HD).
2. If the texture manager keeps frames smooth, `BitmapLoadTask` decodes local files
   (including downloaded `cachefs:` files) through one shared `roTextureManager` owned by
   `Game`. Otherwise it uses `CreateObject("roBitmap")` and the texture manager is used only
   when a resize is requested.
3. Either way: downloads always go through `DownloadTask` (the texture manager's own HTTP
   cache is in memory only and gives no byte progress), and `game.unloadBitmap(name)` also
   calls the manager's `UnloadBitmap(uri)` for bitmaps it loaded, so memory is actually freed.
4. Before Roku OS 16, bitmaps from the texture manager can't be drawn *into*
   (`SetDrawable()` is OS 16+). The plan checks whether anything in the engine draws into a
   loaded bitmap; any such load keeps using `CreateObject("roBitmap")`.

The public API is the same either way.

### Result (PR 3)

`texture-decode-benchmark`, 2048x1024 images, 3 runs each:

| | Roku Ultra 4850CA (OS 15.3.4) | Simulator |
|---|---|---|
| roBitmap .png | 160ms frame | 81ms |
| texture manager .png | 17ms frame, ready in ~175ms | 67ms (decoded inside GetMessage) |
| roBitmap .jpg | 79ms frame | 87ms |
| texture manager .jpg | 17ms frame, ready in ~90ms | 81ms |
| texture manager, resized to 512x256 | 17ms frame | ~80ms |

The device decodes off-thread, so `BitmapLoadTask` uses one shared `BGE.TextureLoader`
(`game.getTextureLoader()`) for every load, local or downloaded. The simulator is no worse than
roBitmap, so it isn't gated (lvcabral/brs-engine#1250). Nothing in the engine draws into a loaded
bitmap; `BitmapLoadOptions.drawable` keeps the roBitmap path for a game that does. A request for
a file another request is decoding at the same time comes back at the other request's size on a
device, so the task checks the size and resizes itself. A failed decode falls back to roBitmap.

Model textures (`.obj` `map_Kd`) still decode with roBitmap inside `addLoadedModel()`.

## Loading screen

```brighterscript
class LoadingScreen
  showAfterSeconds as float = 0.25
  sub onShow()
  sub onHide()
  sub draw(renderer as BGE.Renderer, progress as float, dt as float)
end class
```

- Drawn on the UI canvas where the fade overlay is: above `gameUi`, below `debugUi` (so debug
  overlays stay visible), and above the fade overlay itself.
- Shown only once loading has lasted `showAfterSeconds`, so fast loads don't flash.
- Default (`BGE.DefaultLoadingScreen`): black fill, a centred progress bar in
  `game.defaultTheme` colours, a small "Loading" label.
- Override, first match wins: `GameScene.getLoadingScreen()` (default `invalid`), then
  `game.loadingScreen`, then the default.
- The game canvas still renders under it (persistent entities only, since the old scene is
  gone); a full-screen loading screen hides it, a partial one (corner spinner) doesn't.
- With a fade: fade out -> loading screen over the black overlay -> `onCreate` -> loading
  screen hidden -> fade in.
- The loading screen takes no input.

## Limits

One native call can't be split: `ReadAsciiFile` of a huge file, `content.Split(chr(10))`, a
single `roBitmap` decode (unless roTextureManager turns out to run off-thread), one
`roAudioResource`. That frame hitches and the bar jumps by that task's share. For normal asset
sizes the BrightScript per-line parse loop dominates, and that is what's split.

## Testing

Rooibos (headless, CI):

- `AssetLoader` with fake tasks: budget respected, fast tasks batched per frame, weighted
  progress, `dependsOn` ordering, failure counts as done and fails dependants, `onComplete`
  once, `addStep` with boolean and float returns.
- Scene change: `onLoad` before `onCreate`; zero tasks -> `onCreate` the same frame; old
  entities destroyed before `onLoad`; `isLoading`/`isTransitioning`/`getLoadingProgress`;
  fade sequence out -> load -> create -> in; loading screen only after `showAfterSeconds`;
  scene screen beats game screen beats default; `changeScene` during loading is deferred.
- Parse tasks produce the same `Model3d` as the old one-shot parsers on the existing test
  models; progress is monotonic 0 -> 1.
- `DownloadTask` with a fake transfer: cache path, cache hit skips the request,
  `refresh`/`cache: false`, non-2xx, timeout + retry, partial file removed, URL-relative
  `.obj` texture resolution.
- Sync loaders reject URLs with the error; `musicPlay` URL skips `Exists()`.

On device:

- `rendererTest`'s `texture-decode-benchmark` (roTextureManager decision).
- New `examples/loading`:
  1. **Large local assets** - big model + big textures through `onLoad`; bar is smooth and
     the loading screen shows a live frame-time readout.
  2. **Remote assets** - images, a model + texture, a sound from URLs; each shows
     "network"/"cache" and its load time; a relaunch should be all "cache".
  3. **Custom loading screen** - its own `LoadingScreen`, plus a level built via `addStep`.
  4. **Failure** - a bad URL and a missing file; errors shown via `getErrors()`, the scene
     still opens.
- Remote files live in `examples/loading/remote-assets/`, outside the channel package.
  Default base URL is this repo's `raw.githubusercontent.com/.../main/examples/loading/remote-assets/`;
  a `baseUrl` launch param points it at a local HTTP server on the Mac for development
  (and for testing slow/failing servers).

## Docs

- New guide `docs/loading-assets.md` (fundamentals first: `onLoad` examples, built-in loads,
  custom tasks/steps, URLs and caching, custom loading screens; limits as asides).
- `CLAUDE.md` architecture entry for the loading stage.

## Delivery

One spec, three PRs:

1. **Loading stage + local tasks** - `LoadTask`, `AssetLoader`, `GameScene.onLoad`, the
   scene change phases, `LoadingScreen` + default, incremental parsers, `game.assets`,
   example scenes 1 and 3, the guide.
2. **Remote assets (#301)** - `DownloadTask`, `cachefs:` cache, HTTPS, URL support in the
   built-in loads, URL-relative `.obj` textures, sync-loader URL error, `musicPlay`
   streaming, example scenes 2 and 4.
3. **roTextureManager** - the benchmark (can be done first, independently), the decode
   backend if the numbers support it, resize on load, `unloadBitmap` integration.

Follow-up (separate issue): move `examples/terrain`'s big texture loads into `onLoad`.
