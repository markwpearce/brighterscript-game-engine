# Async Asset Loading, PR 2: Remote Assets - Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let `AssetLoader`'s built-in loads (and a plain `download()`) take `http(s)://` URLs, downloading to a `cachefs:` cache that later launches reuse.

**Architecture:** `BGE.DownloadTask` (a `LoadTask`) runs one `roUrlTransfer.AsyncGetToFile()` on its own message port, polled in `step()`, writing to `cachefs:/bge/<md5 of url><ext>` via a temporary `.part` file. The built-in load tasks share a new base, `BGE.FileLoadTask`, which steps an attached `DownloadTask` first and then loads the local file, so one queued task covers download + load. `.obj` models from a URL fetch their `mtllib`/`map_Kd` texture relative to the model's URL. Synchronous `Game` loaders refuse URLs with an error pointing at the async API; `musicPlay()` streams them.

**Tech Stack:** BrighterScript (`bsc`), Rooibos v6 (`rooibos-roku`) headless via `brs-cli`, `rokubot` for on-device runs.

**Spec:** `specs/2026-10-09-async-asset-loading-design.md` (this plan covers "Delivery" item 2. Plan 1 shipped in PR #319; roTextureManager is plan 3).

## Global Constraints

- All engine code is in the `BGE` namespace under `src/source/`; loading code goes in `src/source/engine/loading/`, pure URL helpers in `src/source/utils/urls.bs`.
- Every file that uses another file's class/interface/enum/function/const must `import` that file (SceneGraph scopes aren't ambient). An import cycle between two files is fine.
- A `*.spec.bs` file contains exactly **one** `@suite` class. Helper classes without `@suite` may sit below it in the same file.
- A test class in `namespace tests` that subclasses a `BGE` class needs an explicit `sub new(...)` calling `super(...)`, with fully-qualified param types (bsc transpile crash otherwise).
- A suite needs an `@describe(...)` before its first `@it` (Rooibos error RBS2201).
- `assertEqual` is type-strict (`1` vs `1.0` fail); compare scalars, never whole objects.
- Never compare two objects with `=` (runtime Type Mismatch); compare a string/number field.
- Never write `foo(new X(...))` - assign `new X(...)` to a local first.
- No single-line `if` (`bslint` `inline-if-style: never`).
- An instance method parameter typed as **its own class** corrupts bsc - use `as object` there (the only allowed `as object`).
- Prefer real types; `as dynamic` only for values that really can be anything (e.g. an `roUrlTransfer` that tests replace with a fake). bsc has no `invalid` in unions (`string or invalid` is a parse error). A `sub` callback type needs `as void`.
- Options bags are `interface X extends roAssociativeArray` with `optional` fields.
- Doc comments (`'` above public members, `@param`/`@return`) are for game developers; inline comments are terse "why" only (1-3 lines).
- The loader logs a failed task's `error` (`BGE.AssetLoader - <error>`), so a task must not log its own failure as well.
- Download cache folder: `cachefs:/bge`; uncached downloads: `tmp:/bge`. File name: lowercase MD5 hex of the full URL + the URL path's extension (e.g. `.png`). HTTPS: `SetCertificatesFile("common:/certs/ca-bundle.crt")` + `InitClientCertificates()`. Defaults: `timeoutSeconds` 30, `retries` 1, `maxConcurrentDownloads` 4.
- Example UI stays >= 10% in from every canvas edge (title safe).
- `npm run check` (lint + validate + headless tests) must pass at the end of every task; `npm run check:all` at the end of the plan.
- No behaviour change for local paths anywhere.

## Review Focus

- The same URL queued twice in one batch (two scenes' worth of tasks, or a model and its texture both pointing at one file): both downloads run at once and must not write the same temporary file - each attempt uses its own `.part` name (test in Task 3).
- A URL with a query string or fragment (`.../hero.png?v=3`): the cache file keeps `.png`, so the bitmap loader still accepts it, and `?v=3` vs `?v=4` cache separately (test in Task 1).
- A server that sends no `Content-Length`: progress stays at 0 until done, never divides by zero or goes past 1 (test in Task 3).
- A failed or timed-out download leaves nothing at the cache path, so the next launch tries again instead of loading a half file (test in Task 3).
- An `.obj` from a URL whose `.mtl` or texture fails to download: the model still loads, untextured, with a warning, and the task doesn't fail (test in Task 5).

---

### Task 1: URL helpers

**Files:**
- Create: `src/source/utils/urls.bs`
- Test: `src/source/utils/urls.spec.bs`

**Interfaces:**
- Consumes: nothing.
- Produces (all in `namespace BGE`):
  - `const DOWNLOAD_CACHE_FOLDER = "cachefs:/bge"`, `const DOWNLOAD_TEMP_FOLDER = "tmp:/bge"`
  - `function isUrl(path as dynamic) as boolean`
  - `function stripUrlQuery(url as string) as string`
  - `function urlFileExtension(url as string) as string` - lowercase, with the dot, or `""`
  - `function resolveRelativeUrl(baseUrl as string, relativePath as string) as string`
  - `function getDownloadFolder(useCache as boolean) as string`
  - `function getDownloadPath(url as string, useCache as boolean) as string`

- [ ] **Step 1: Write the failing tests**

Create `src/source/utils/urls.spec.bs`:

```brighterscript
import "pkg:/source/utils/urls.bs"

namespace tests

  @suite("BGE url helpers")
  class UrlHelperTests extends rooibos.BaseTestSuite

    @describe("isUrl")

    @it("accepts http and https in any case")
    function _()
      m.assertTrue(BGE.isUrl("http://example.com/a.png"))
      m.assertTrue(BGE.isUrl("https://example.com/a.png"))
      m.assertTrue(BGE.isUrl("HTTPS://EXAMPLE.COM/A.PNG"))
    end function

    @it("rejects local paths and non-strings")
    function _()
      m.assertFalse(BGE.isUrl("pkg:/images/a.png"))
      m.assertFalse(BGE.isUrl("cachefs:/bge/a.png"))
      m.assertFalse(BGE.isUrl(""))
      m.assertFalse(BGE.isUrl(invalid))
      m.assertFalse(BGE.isUrl({width: 2, height: 2}))
    end function

    @describe("urlFileExtension")

    @it("returns the lowercase extension of the url path")
    function _()
      m.assertEqual(".png", BGE.urlFileExtension("https://example.com/img/Hero.PNG"))
      m.assertEqual(".obj", BGE.urlFileExtension("https://example.com/m/ship.obj"))
    end function

    @it("ignores the query string and fragment")
    function _()
      m.assertEqual(".png", BGE.urlFileExtension("https://example.com/hero.png?v=3"))
      m.assertEqual(".png", BGE.urlFileExtension("https://example.com/hero.png#top"))
    end function

    @it("returns empty when the path has no extension")
    function _()
      m.assertEqual("", BGE.urlFileExtension("https://example.com/download"))
      m.assertEqual("", BGE.urlFileExtension("https://example.com/"))
      m.assertEqual("", BGE.urlFileExtension("https://example.com/v1.2/file"))
    end function

    @describe("resolveRelativeUrl")

    @it("resolves a sibling file against the base url's folder")
    function _()
      m.assertEqual("https://example.com/models/ship.mtl", BGE.resolveRelativeUrl("https://example.com/models/ship.obj", "ship.mtl"))
      m.assertEqual("https://example.com/models/tex/ship.png", BGE.resolveRelativeUrl("https://example.com/models/ship.obj", "./tex/ship.png"))
    end function

    @it("drops the base url's query string")
    function _()
      m.assertEqual("https://example.com/models/ship.mtl", BGE.resolveRelativeUrl("https://example.com/models/ship.obj?v=2", "ship.mtl"))
    end function

    @it("resolves a root-relative path against the host")
    function _()
      m.assertEqual("https://example.com/shared/a.png", BGE.resolveRelativeUrl("https://example.com/models/ship.obj", "/shared/a.png"))
    end function

    @it("returns a full url unchanged")
    function _()
      m.assertEqual("http://cdn.example.com/a.png", BGE.resolveRelativeUrl("https://example.com/models/ship.obj", "http://cdn.example.com/a.png"))
    end function

    @describe("getDownloadPath")

    @it("puts cached downloads in cachefs and keeps the extension")
    function _()
      downloadPath = BGE.getDownloadPath("https://example.com/hero.png?v=3", true)
      m.assertTrue(downloadPath.StartsWith("cachefs:/bge/"))
      m.assertTrue(downloadPath.EndsWith(".png"))
      ' folder + "/" + 32 hex chars + ".png"
      m.assertEqual(Len("cachefs:/bge/") + 32 + 4, Len(downloadPath))
    end function

    @it("puts uncached downloads in tmp")
    function _()
      m.assertTrue(BGE.getDownloadPath("https://example.com/hero.png", false).StartsWith("tmp:/bge/"))
    end function

    @it("gives the same url the same path and different urls different paths")
    function _()
      m.assertEqual(BGE.getDownloadPath("https://example.com/a.png", true), BGE.getDownloadPath("https://example.com/a.png", true))
      m.assertNotEqual(BGE.getDownloadPath("https://example.com/a.png?v=3", true), BGE.getDownloadPath("https://example.com/a.png?v=4", true))
    end function

  end class

end namespace
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `npm run test:ci`
Expected: FAIL - `urls.bs` doesn't exist (build error / unresolved import).

- [ ] **Step 3: Write the helpers**

Create `src/source/utils/urls.bs`:

```brighterscript
import "../roku_modules/rodash/rodash.d.bs"

namespace BGE

  ' Where downloads are cached between launches (the OS may clear it when space runs low)
  const DOWNLOAD_CACHE_FOLDER = "cachefs:/bge"
  ' Where downloads with `cache: false` go - cleared when the channel exits
  const DOWNLOAD_TEMP_FOLDER = "tmp:/bge"

  ' Whether a path is an http:// or https:// URL rather than a local file.
  '
  ' @param {dynamic} path
  ' @return {boolean}
  function isUrl(path as dynamic) as boolean
    if not rodash.isString(path)
      return false
    end if
    lowerPath = LCase(path)
    return lowerPath.StartsWith("http://") or lowerPath.StartsWith("https://")
  end function

  ' A URL without its query string or fragment.
  '
  ' @param {string} url
  ' @return {string}
  function stripUrlQuery(url as string) as string
    cut = Len(url)
    queryStart = url.Instr("?")
    if queryStart >= 0 and queryStart < cut
      cut = queryStart
    end if
    fragmentStart = url.Instr("#")
    if fragmentStart >= 0 and fragmentStart < cut
      cut = fragmentStart
    end if
    return url.Left(cut)
  end function

  ' The lowercase file extension of a URL's path (e.g. ".png"), or "" if it has none.
  '
  ' @param {string} url
  ' @return {string}
  function urlFileExtension(url as string) as string
    urlPath = BGE.stripUrlQuery(url)
    fileName = urlPath.Mid(BGE.lastIndexOfChar(urlPath, "/") + 1)
    dotIndex = BGE.lastIndexOfChar(fileName, ".")
    if dotIndex < 0
      return ""
    end if
    extension = LCase(fileName.Mid(dotIndex))
    ' a dot in a folder-like name ("v1.2") isn't an extension
    if Len(extension) < 2 or Len(extension) > 6
      return ""
    end if
    return extension
  end function

  ' Resolves a path found inside a downloaded file (e.g. an .obj's `mtllib`) against that file's URL.
  '
  ' @param {string} baseUrl - the URL of the file the path came from
  ' @param {string} relativePath - a relative path, a root-relative path ("/a/b.png") or a full URL
  ' @return {string} the full URL
  function resolveRelativeUrl(baseUrl as string, relativePath as string) as string
    if BGE.isUrl(relativePath)
      return relativePath
    end if
    base = BGE.stripUrlQuery(baseUrl)
    if relativePath.StartsWith("/")
      hostStart = base.Instr("://") + 3
      pathStart = base.Instr(hostStart, "/")
      if pathStart < 0
        return base + relativePath
      end if
      return base.Left(pathStart) + relativePath
    end if
    if relativePath.StartsWith("./")
      relativePath = relativePath.Mid(2)
    end if
    return base.Left(BGE.lastIndexOfChar(base, "/") + 1) + relativePath
  end function

  ' The folder downloads are written to.
  '
  ' @param {boolean} useCache - true for the cachefs: cache, false for tmp:
  ' @return {string}
  function getDownloadFolder(useCache as boolean) as string
    if useCache
      return BGE.DOWNLOAD_CACHE_FOLDER
    end if
    return BGE.DOWNLOAD_TEMP_FOLDER
  end function

  ' The local file a URL downloads to: the MD5 of the URL plus its extension, so the same URL
  ' always maps to the same file and the loaders can still tell the file type.
  '
  ' @param {string} url
  ' @param {boolean} useCache - true for the cachefs: cache, false for tmp:
  ' @return {string}
  function getDownloadPath(url as string, useCache as boolean) as string
    digest = CreateObject("roEVPDigest")
    digest.Setup("md5")
    bytes = CreateObject("roByteArray")
    bytes.FromAsciiString(url)
    return BGE.getDownloadFolder(useCache) + "/" + LCase(digest.Process(bytes)) + BGE.urlFileExtension(url)
  end function

  ' Index of the last occurrence of a single character in a string, or -1.
  '
  ' @param {string} text
  ' @param {string} character
  ' @return {integer}
  function lastIndexOfChar(text as string, character as string) as integer
    for i = Len(text) - 1 to 0 step -1
      if text.Mid(i, 1) = character
        return i
      end if
    end for
    return -1
  end function

end namespace
```

If `rodash.isString` isn't available in the imported `rodash.d.bs`, check `src/source/utils/strings.bs` for an existing string check, or use `GetInterface(path, "ifString") <> invalid` (guard `invalid` first).

- [ ] **Step 4: Run the tests to verify they pass**

Run: `npm run check`
Expected: lint and validate clean, `[Rooibos Result]: PASS`.

- [ ] **Step 5: Commit**

```bash
git add src/source/utils/urls.bs src/source/utils/urls.spec.bs
git commit -m "Add URL helpers for downloads (#301)"
```

---

### Task 2: Synchronous loaders refuse URLs; `musicPlay` streams them

**Files:**
- Modify: `src/source/engine/Game.bs` - `loadBitmap`, `load3dModel`, `registerFont`, `loadSound`, `loadModelTexture`, `musicPlay`, plus a new private `logSyncUrlError`
- Test: `src/source/engine/GameUrlLoads.spec.bs` (new)
- Test: `src/source/engine/GameMusic.spec.bs` (add one test)

**Interfaces:**
- Consumes: `BGE.isUrl(path as dynamic) as boolean` (Task 1).
- Produces: no new public API. Error text, exactly: `Game.<fn>() - <url> is a URL. Load it with game.assets.<fn>() or in GameScene.onLoad()` at `LogLevel.error`, where `<fn>` is `loadBitmap`, `load3dModel`, `registerFont` or `loadSound`.

- [ ] **Step 1: Write the failing tests**

Create `src/source/engine/GameUrlLoads.spec.bs`:

```brighterscript
import "pkg:/source/engine/Game.bs"

namespace tests

  @suite("BGE.Game synchronous loads with URLs")
  class GameUrlLoadsTests extends rooibos.BaseTestSuite

    game as BGE.Game

    protected override function beforeEach()
      m.game = new BGE.Game(320, 240)
    end function

    @describe("synchronous loaders")

    @it("refuses a bitmap URL")
    function _()
      m.assertFalse(m.game.loadBitmap("remote", "https://example.com/a.png"))
      m.assertInvalid(m.game.Bitmaps["remote"])
    end function

    @it("refuses a model URL")
    function _()
      m.assertFalse(m.game.load3dModel("remote", "https://example.com/a.obj"))
      m.assertInvalid(m.game.Models["remote"])
    end function

    @it("refuses a font URL")
    function _()
      m.assertFalse(m.game.registerFont("https://example.com/a.ttf"))
    end function

    @it("refuses a sound URL")
    function _()
      m.game.loadSound("remote", "https://example.com/a.wav")
      m.assertInvalid(m.game.Sounds["remote"])
    end function

    @it("loads a local model untextured when its texturePath is a URL")
    function _()
      WriteAsciiFile("tmp:/bge_url_tex.obj", "v 0 0 0" + chr(10) + "v 1 0 0" + chr(10) + "v 0 1 0" + chr(10) + "vt 0 0" + chr(10) + "vt 1 0" + chr(10) + "vt 0 1" + chr(10) + "f 1/1 2/2 3/3")
      m.assertTrue(m.game.load3dModel("tri", "tmp:/bge_url_tex.obj", {texturePath: "https://example.com/tex.png"}))
      m.assertInvalid(m.game.Models["tri"].faces[0].Texture)
    end function

  end class

end namespace
```

Add to `src/source/engine/GameMusic.spec.bs`, inside the `musicPlay / getMusicPath` describe:

```brighterscript
    @it("streams a URL without checking for a local file")
    function _()
      m.assertTrue(m.game.musicPlay("https://example.com/song.mp3", true))
      m.assertEqual("https://example.com/song.mp3", m.game.getMusicPath())
    end function
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `npm run test:ci`
Expected: FAIL - `loadSound` stores an `roAudioResource` (or invalid) without the check, the textured-URL test may pass or fail depending on `Exists`, and `musicPlay` returns false for the URL. At minimum the music test and the sound test fail.

- [ ] **Step 3: Implement**

In `src/source/engine/Game.bs`:

1. Add `import "../utils/urls.bs"` with the other imports at the top of the file.

2. Add this private helper in the Bitmap Functions section, just above `loadBitmap`:

```brighterscript
    ' Synchronous loaders can't wait for a download without freezing the game.
    private sub logSyncUrlError(functionName as string, url as string)
      m.log("Game." + functionName + "() - " + url + " is a URL. Load it with game.assets." + functionName + "() or in GameScene.onLoad()", BGE.Debug.LogLevel.error)
    end sub
```

3. `loadBitmap`: add a branch between the `roAssociativeArray` branch and `else if m.filesystem.Exists(path)`:

```brighterscript
      else if BGE.isUrl(path)
        m.logSyncUrlError("loadBitmap", path)
        return false
```

4. `load3dModel`: first lines of the function body:

```brighterscript
      if BGE.isUrl(modelPath)
        m.logSyncUrlError("load3dModel", modelPath)
        return false
      end if
```

5. `registerFont`: first lines:

```brighterscript
      if BGE.isUrl(path)
        m.logSyncUrlError("registerFont", path)
        return false
      end if
```

6. `loadSound`: first lines:

```brighterscript
      if BGE.isUrl(path)
        m.logSyncUrlError("loadSound", path)
        return
      end if
```

7. `loadModelTexture`: after the `texturePath = invalid or texturePath = ""` block, before the `Exists` check:

```brighterscript
      if BGE.isUrl(texturePath)
        m.log("Game.load3dModel() - Texture " + texturePath + " is a URL, model will render untextured. Load the model with game.assets.load3dModel() or in GameScene.onLoad()", BGE.Debug.LogLevel.warning)
        BGE.Model3dOps.clearTextures(model)
        return
      end if
```

8. `musicPlay`: change `if m.filesystem.Exists(path)` to `if BGE.isUrl(path) or m.filesystem.Exists(path)`, and add to its doc comment: `' A http(s):// URL is streamed by the music player, so it isn't downloaded first.` Update the `@param path` line to `the path or URL of the music file`.

9. Update the doc comments of `loadBitmap`, `load3dModel`, `registerFont` and `loadSound` with one line each: `' Local files only - for a URL use game.assets.<fn>() or GameScene.onLoad().`

- [ ] **Step 4: Run the tests to verify they pass**

Run: `npm run check`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/source/engine/Game.bs src/source/engine/GameUrlLoads.spec.bs src/source/engine/GameMusic.spec.bs
git commit -m "Refuse URLs in synchronous loaders, stream music URLs (#301)"
```

---

### Task 3: `DownloadTask`

**Files:**
- Create: `src/source/engine/loading/DownloadTask.bs`
- Test: `src/source/engine/loading/DownloadTask.spec.bs`

**Interfaces:**
- Consumes: Task 1's `BGE.isUrl`, `BGE.getDownloadPath`, `BGE.getDownloadFolder`; `BGE.LoadTask` (`src/source/engine/loading/LoadTask.bs`); `BGE.GameTimer` (`src/source/engine/GameTimer.bs`: `mark()`, `totalMilliseconds() as integer`, `addTime(ms as integer)`).
- Produces:
  - `interface BGE.DownloadOptions extends roAssociativeArray` - `optional cache as boolean`, `optional refresh as boolean`, `optional timeoutSeconds as integer`, `optional retries as integer`.
  - `class BGE.DownloadSlots` - `max as integer = 4`, `active as integer = 0`, `tryTake() as boolean`, `give()`.
  - `class BGE.DownloadTask extends BGE.LoadTask` - `new(url as string, options = {} as BGE.DownloadOptions)`; public fields `url as string`, `localPath as string = ""`, `fromCache as boolean = false`, `elapsedMs as integer = 0`, `slots as BGE.DownloadSlots = invalid`, `timer as BGE.GameTimer`; overridable `createTransfer() as dynamic`, `createPort() as dynamic`.

Behaviour (the tests pin each line):
- First step: not a URL -> error `not an http(s) URL: <url>`. Cached file exists and not `refresh` -> `localPath`, `fromCache = true`, done, no request.
- A download needs a slot from `slots` (if set); without one it sets `waitingForNextFrame` and waits.
- Each attempt: create port + transfer, `SetMessagePort`, `SetUrl`, HTTPS certs for `https://`, `AsyncGetToFile(<target>.<random>.part)`.
- Poll: drain the port. `GetInt() = 2` reads `content-length` from `GetResponseHeaders()`. `GetInt() = 1` finishes the attempt: 2xx -> delete any old target, rename the part file onto it; otherwise fail.
- A failure with response code `<= 0` (network) or `>= 500`, or a timeout (`timeoutSeconds` since the attempt started; `AsyncCancel()`), retries while `retries` remain; anything else fails at once. Every failure deletes the part file.
- Finishing (success or failure) gives the slot back and records `elapsedMs`.
- Progress: 1 once done; `<part file size> / content-length` capped at 0.99 while downloading; 0 if no length.

- [ ] **Step 1: Write the failing tests**

Create `src/source/engine/loading/DownloadTask.spec.bs`:

```brighterscript
import "pkg:/source/engine/loading/DownloadTask.bs"

namespace tests

  @suite("BGE.DownloadTask")
  class DownloadTaskTests extends rooibos.BaseTestSuite

    fs as roFileSystem

    protected override function beforeEach()
      m.fs = CreateObject("roFileSystem")
      for each folder in [BGE.DOWNLOAD_CACHE_FOLDER, BGE.DOWNLOAD_TEMP_FOLDER]
        for each fileName in m.fs.GetDirectoryListing(folder)
          m.fs.Delete(folder + "/" + fileName)
        end for
      end for
    end function

    @describe("cache")

    @it("uses a cached file without a request")
    function _()
      url = "https://example.com/cached.png"
      m.fs.CreateDirectory(BGE.DOWNLOAD_CACHE_FOLDER)
      WriteAsciiFile(BGE.getDownloadPath(url, true), "cached")
      task = new tests.ScriptedDownloadTask(url, {}, [])
      m.assertTrue(task.step(12))
      m.assertTrue(task.fromCache)
      m.assertEqual(BGE.getDownloadPath(url, true), task.localPath)
      m.assertEqual(0, task.transfersCreated)
      m.assertInvalid(task.error)
    end function

    @it("downloads into the cache")
    function _()
      url = "https://example.com/fresh.png"
      task = new tests.ScriptedDownloadTask(url, {}, [{code: 200, body: "fresh"}])
      m.assertTrue(tests.runDownload(task))
      m.assertInvalid(task.error)
      m.assertFalse(task.fromCache)
      m.assertEqual(BGE.getDownloadPath(url, true), task.localPath)
      m.assertEqual("fresh", ReadAsciiFile(task.localPath))
      m.assertEqual(1, m.fs.GetDirectoryListing(BGE.DOWNLOAD_CACHE_FOLDER).count())
    end function

    @it("downloads again over a cached file with refresh")
    function _()
      url = "https://example.com/refresh.png"
      m.fs.CreateDirectory(BGE.DOWNLOAD_CACHE_FOLDER)
      WriteAsciiFile(BGE.getDownloadPath(url, true), "old")
      task = new tests.ScriptedDownloadTask(url, {refresh: true}, [{code: 200, body: "new"}])
      tests.runDownload(task)
      m.assertEqual(1, task.transfersCreated)
      m.assertEqual("new", ReadAsciiFile(task.localPath))
    end function

    @it("downloads to tmp with cache false")
    function _()
      task = new tests.ScriptedDownloadTask("https://example.com/temp.png", {cache: false}, [{code: 200, body: "t"}])
      tests.runDownload(task)
      m.assertTrue(task.localPath.StartsWith("tmp:/bge/"))
    end function

    @describe("requests")

    @it("sets up certificates for https only")
    function _()
      secure = new tests.ScriptedDownloadTask("https://example.com/s.png", {}, [{code: 200, body: "s"}])
      tests.runDownload(secure)
      m.assertEqual("common:/certs/ca-bundle.crt", secure.lastTransfer.certificatesFile)
      m.assertEqual("https://example.com/s.png", secure.lastTransfer.url)
      plain = new tests.ScriptedDownloadTask("http://example.com/p.png", {}, [{code: 200, body: "p"}])
      tests.runDownload(plain)
      m.assertEqual("", plain.lastTransfer.certificatesFile)
    end function

    @it("fails a URL-less path without a request")
    function _()
      task = new tests.ScriptedDownloadTask("pkg:/images/a.png", {}, [])
      m.assertTrue(task.step(12))
      m.assertNotInvalid(task.error)
      m.assertEqual(0, task.transfersCreated)
    end function

    @it("gives two downloads of the same URL their own temporary files")
    function _()
      first = new tests.ScriptedDownloadTask("https://example.com/same.png", {}, [{hang: true}])
      second = new tests.ScriptedDownloadTask("https://example.com/same.png", {}, [{hang: true}])
      first.step(12)
      second.step(12)
      m.assertNotEqual(first.lastTransfer.toFilePath, second.lastTransfer.toFilePath)
    end function

    @describe("failures")

    @it("fails a 404 without retrying and leaves nothing behind")
    function _()
      url = "https://example.com/missing.png"
      task = new tests.ScriptedDownloadTask(url, {}, [{code: 404, body: "not found"}, {code: 200, body: "never"}])
      tests.runDownload(task)
      m.assertNotInvalid(task.error)
      m.assertTrue(task.error.Instr("404") >= 0)
      m.assertEqual(1, task.transfersCreated)
      m.assertEqual("", task.localPath)
      m.assertEqual(0, m.fs.GetDirectoryListing(BGE.DOWNLOAD_CACHE_FOLDER).count())
    end function

    @it("retries a server error")
    function _()
      task = new tests.ScriptedDownloadTask("https://example.com/flaky.png", {}, [{code: 503, body: "busy"}, {code: 200, body: "ok"}])
      tests.runDownload(task)
      m.assertInvalid(task.error)
      m.assertEqual(2, task.transfersCreated)
      m.assertEqual("ok", ReadAsciiFile(task.localPath))
    end function

    @it("gives up on a network error once its retries are used")
    function _()
      task = new tests.ScriptedDownloadTask("https://example.com/down.png", {retries: 1}, [{code: -6, body: ""}, {code: -6, body: ""}, {code: 200, body: "late"}])
      tests.runDownload(task)
      m.assertNotInvalid(task.error)
      m.assertEqual(2, task.transfersCreated)
    end function

    @it("times out a stalled download and cancels it")
    function _()
      task = new tests.ScriptedDownloadTask("https://example.com/slow.png", {timeoutSeconds: 1, retries: 0}, [{hang: true, partialBody: "half"}])
      m.assertFalse(task.step(12))
      stalled = task.lastTransfer
      task.timer.addTime(1000)
      m.assertTrue(task.step(12))
      m.assertTrue(stalled.cancelled)
      m.assertTrue(task.error.Instr("timed out") >= 0)
      m.assertEqual(0, m.fs.GetDirectoryListing(BGE.DOWNLOAD_CACHE_FOLDER).count())
    end function

    @describe("progress")

    @it("reports bytes written against content-length")
    function _()
      task = new tests.ScriptedDownloadTask("https://example.com/big.png", {}, [{hang: true, partialBody: "12345", headers: {"content-length": "10"}}])
      task.step(12)
      m.assertEqual(0.5, task.getProgress())
    end function

    @it("reports 0 without content-length, then 1 when done")
    function _()
      task = new tests.ScriptedDownloadTask("https://example.com/nolength.png", {}, [{hang: true, partialBody: "12345"}])
      task.step(12)
      m.assertEqual(0.0, task.getProgress())
      done = new tests.ScriptedDownloadTask("https://example.com/nolength2.png", {}, [{code: 200, body: "x"}])
      tests.runDownload(done)
      m.assertEqual(1.0, done.getProgress())
    end function

    @describe("slots")

    @it("waits for a free slot")
    function _()
      slots = new BGE.DownloadSlots()
      slots.max = 1
      first = new tests.ScriptedDownloadTask("https://example.com/one.png", {}, [{code: 200, body: "1"}])
      first.slots = slots
      second = new tests.ScriptedDownloadTask("https://example.com/two.png", {}, [{code: 200, body: "2"}])
      second.slots = slots
      first.step(12)
      m.assertFalse(second.step(12))
      m.assertTrue(second.waitingForNextFrame)
      m.assertEqual(0, second.transfersCreated)
      tests.runDownload(first)
      m.assertEqual(0, slots.active)
      tests.runDownload(second)
      m.assertInvalid(second.error)
    end function

  end class

  ' Steps a download until it finishes (or 20 steps pass). Returns whether it finished.
  function runDownload(task as BGE.DownloadTask) as boolean
    for i = 1 to 20
      if task.step(12)
        return true
      end if
    end for
    return false
  end function

  ' A DownloadTask whose transfers play back `responses` in order, one per attempt. Each response
  ' is {code, body} to finish, or {hang: true} to never finish; `partialBody` and `headers` also
  ' write a partial file and send a "started" event first.
  class ScriptedDownloadTask extends BGE.DownloadTask
    responses as roArray
    transfersCreated as integer = 0
    lastTransfer as dynamic = invalid

    sub new(url as string, options as BGE.DownloadOptions, responses as roArray)
      super(url, options)
      m.responses = responses
    end sub

    override function createTransfer() as dynamic
      m.transfersCreated++
      response = invalid
      if m.responses.count() > 0
        response = m.responses.Shift()
      end if
      transfer = new tests.FakeTransfer(response)
      m.lastTransfer = transfer
      return transfer
    end function

    override function createPort() as dynamic
      port = new tests.FakePort()
      return port
    end function
  end class

  class FakePort
    queue as roArray

    sub new()
      m.queue = []
    end sub

    function GetMessage() as dynamic
      if m.queue.count() = 0
        return invalid
      end if
      return m.queue.Shift()
    end function
  end class

  class FakeUrlEvent
    eventType as integer
    code as integer
    headers as roAssociativeArray

    sub new(eventType as integer, code as integer, headers as roAssociativeArray)
      m.eventType = eventType
      m.code = code
      m.headers = headers
    end sub

    function GetInt() as integer
      return m.eventType
    end function

    function GetResponseCode() as integer
      return m.code
    end function

    function GetFailureReason() as string
      return "fake failure"
    end function

    function GetResponseHeaders() as roAssociativeArray
      return m.headers
    end function
  end class

  class FakeTransfer
    response as dynamic
    port as dynamic = invalid
    url as string = ""
    certificatesFile as string = ""
    toFilePath as string = ""
    cancelled as boolean = false

    sub new(response as dynamic)
      m.response = response
    end sub

    sub SetMessagePort(port as dynamic)
      m.port = port
    end sub

    sub SetUrl(url as string)
      m.url = url
    end sub

    sub SetCertificatesFile(path as string)
      m.certificatesFile = path
    end sub

    sub InitClientCertificates()
    end sub

    function AsyncGetToFile(filePath as string) as boolean
      m.toFilePath = filePath
      if m.response = invalid
        return false
      end if
      headers = {}
      if m.response.headers <> invalid
        headers = m.response.headers
      end if
      if m.response.hang <> invalid and m.response.hang
        if m.response.partialBody <> invalid
          WriteAsciiFile(filePath, m.response.partialBody)
        end if
        startedEvent = new tests.FakeUrlEvent(2, 0, headers)
        m.port.queue.push(startedEvent)
        return true
      end if
      WriteAsciiFile(filePath, m.response.body)
      completeEvent = new tests.FakeUrlEvent(1, m.response.code, headers)
      m.port.queue.push(completeEvent)
      return true
    end function

    function AsyncCancel() as boolean
      m.cancelled = true
      return true
    end function
  end class

end namespace
```

Note: an `{hang: true}` response with no `partialBody` still sends a "started" event, so tests that need neither still work.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `npm run test:ci`
Expected: FAIL - `DownloadTask.bs` doesn't exist.

- [ ] **Step 3: Write `DownloadTask`**

Create `src/source/engine/loading/DownloadTask.bs`:

```brighterscript
import "../GameTimer.bs"
import "../../utils/urls.bs"
import "LoadTask.bs"

namespace BGE

  ' Options for downloading a URL - see `AssetLoader.download()` and the built-in loads.
  interface DownloadOptions extends roAssociativeArray
    ' false downloads to tmp: for this launch only, instead of the cachefs: cache (default true)
    optional cache as boolean
    ' true downloads again even when a cached copy exists (default false)
    optional refresh as boolean
    ' seconds a download may take before it's abandoned (default 30)
    optional timeoutSeconds as integer
    ' how many more times a download is tried after a network/server error or timeout (default 1)
    optional retries as integer
  end interface

  ' Limits how many downloads run at once. Each AssetLoader has one.
  class DownloadSlots
    ' Most downloads at once
    max as integer = 4
    ' Downloads running now
    active as integer = 0

    ' Takes a slot if one is free.
    '
    ' @return {boolean} true if a slot was taken
    function tryTake() as boolean
      if m.active >= m.max
        return false
      end if
      m.active++
      return true
    end function

    ' Gives back a slot taken with tryTake().
    sub give()
      if m.active > 0
        m.active--
      end if
    end sub
  end class

  ' Downloads a URL to a local file. A copy cached by an earlier download (even in an earlier
  ' launch) is used without a request. Queue one with `AssetLoader.download()`; once it's done
  ' without an `error`, `localPath` is the file.
  class DownloadTask extends LoadTask

    ' The URL being downloaded
    url as string
    ' The local file, once done
    localPath as string = ""
    ' True if the file was already cached, so no request was made
    fromCache as boolean = false
    ' How long the download took, in milliseconds (0 for a cached file)
    elapsedMs as integer = 0
    ' Shared with the other downloads in the same loader, to limit how many run at once
    slots as BGE.DownloadSlots = invalid
    ' Times each attempt, for the timeout
    timer as BGE.GameTimer

    private targetPath as string
    private partPath as string = ""
    private folder as string
    private refresh as boolean = false
    private timeoutMs as integer = 30000
    private retriesLeft as integer = 1
    private checkedCache as boolean = false
    private holdingSlot as boolean = false
    private contentLength as integer = 0
    private transfer as dynamic = invalid
    private port as dynamic = invalid
    private totalTimer as BGE.GameTimer
    private filesystem as roFileSystem

    sub new(url as string, options = {} as BGE.DownloadOptions)
      super()
      m.name = "download " + url
      m.url = url
      m.timer = new BGE.GameTimer()
      m.totalTimer = new BGE.GameTimer()
      m.filesystem = CreateObject("roFileSystem")
      useCache = true
      if options.cache <> invalid
        useCache = options.cache
      end if
      if options.refresh <> invalid
        m.refresh = options.refresh
      end if
      if options.timeoutSeconds <> invalid
        m.timeoutMs = options.timeoutSeconds * 1000
      end if
      if options.retries <> invalid
        m.retriesLeft = options.retries
      end if
      m.folder = BGE.getDownloadFolder(useCache)
      m.targetPath = BGE.getDownloadPath(url, useCache)
    end sub

    override function step(budgetMs as integer) as boolean
      if not m.checkedCache
        m.checkedCache = true
        if not BGE.isUrl(m.url)
          return m.finish("not an http(s) URL: " + m.url)
        end if
        if not m.refresh and m.filesystem.Exists(m.targetPath)
          m.localPath = m.targetPath
          m.fromCache = true
          return m.finish(invalid)
        end if
        m.totalTimer.mark()
      end if
      if m.transfer = invalid
        return m.startAttempt()
      end if
      return m.poll()
    end function

    override function getProgress() as float
      if m.localPath <> ""
        return 1.0
      end if
      if m.contentLength <= 0 or m.partPath = ""
        return 0.0
      end if
      info = m.filesystem.Stat(m.partPath)
      if info = invalid or info.size = invalid
        return 0.0
      end if
      progress = info.size / m.contentLength
      if progress > 0.99
        return 0.99
      end if
      return progress
    end function

    ' Creates the roUrlTransfer for each attempt. Override to customise requests (headers etc).
    '
    ' @return {dynamic} an roUrlTransfer
    function createTransfer() as dynamic
      return CreateObject("roUrlTransfer")
    end function

    ' Creates the message port each attempt's events arrive on.
    '
    ' @return {dynamic} an roMessagePort
    function createPort() as dynamic
      return CreateObject("roMessagePort")
    end function

    private function startAttempt() as boolean
      if not m.holdingSlot
        if m.slots <> invalid and not m.slots.tryTake()
          m.waitingForNextFrame = true
          return false
        end if
        m.holdingSlot = true
      end if
      m.filesystem.CreateDirectory(m.folder)
      ' a random suffix so two downloads of the same URL don't write the same file
      m.partPath = m.targetPath + "." + Rnd(1000000000).ToStr() + ".part"
      m.contentLength = 0
      m.port = m.createPort()
      m.transfer = m.createTransfer()
      m.transfer.SetMessagePort(m.port)
      m.transfer.SetUrl(m.url)
      if LCase(m.url).StartsWith("https://")
        m.transfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
        m.transfer.InitClientCertificates()
      end if
      m.timer.mark()
      if not m.transfer.AsyncGetToFile(m.partPath)
        return m.failAttempt("could not start downloading " + m.url, false)
      end if
      m.waitingForNextFrame = true
      return false
    end function

    private function poll() as boolean
      msg = m.port.GetMessage()
      while msg <> invalid
        eventType = msg.GetInt()
        if eventType = 2
          m.readContentLength(msg.GetResponseHeaders())
        else if eventType = 1
          return m.finishAttempt(msg)
        end if
        msg = m.port.GetMessage()
      end while
      if m.timer.totalMilliseconds() >= m.timeoutMs
        m.transfer.AsyncCancel()
        return m.failAttempt("timed out after " + Int(m.timeoutMs / 1000).ToStr() + "s downloading " + m.url, true)
      end if
      m.waitingForNextFrame = true
      return false
    end function

    private sub readContentLength(headers as dynamic)
      if headers = invalid
        return
      end if
      length = headers["content-length"]
      if length <> invalid
        m.contentLength = length.ToInt()
      end if
    end sub

    private function finishAttempt(msg as dynamic) as boolean
      code = msg.GetResponseCode()
      if code >= 200 and code < 300
        m.filesystem.Delete(m.targetPath)
        if not m.filesystem.Rename(m.partPath, m.targetPath)
          m.filesystem.Delete(m.partPath)
          return m.finish("could not save " + m.url + " to " + m.targetPath)
        end if
        m.localPath = m.targetPath
        return m.finish(invalid)
      end if
      message = "HTTP " + code.ToStr() + " downloading " + m.url
      if code <= 0
        message = "network error (" + msg.GetFailureReason() + ") downloading " + m.url
      end if
      return m.failAttempt(message, code <= 0 or code >= 500)
    end function

    ' Retries next frame if allowed, otherwise fails the task.
    private function failAttempt(message as string, canRetry as boolean) as boolean
      m.filesystem.Delete(m.partPath)
      m.transfer = invalid
      m.port = invalid
      if canRetry and m.retriesLeft > 0
        m.retriesLeft--
        m.waitingForNextFrame = true
        return false
      end if
      return m.finish(message)
    end function

    private function finish(errorMessage as dynamic) as boolean
      if m.holdingSlot and m.slots <> invalid
        m.slots.give()
      end if
      m.holdingSlot = false
      m.transfer = invalid
      m.port = invalid
      if not m.fromCache and m.checkedCache
        m.elapsedMs = m.totalTimer.totalMilliseconds()
      end if
      if errorMessage <> invalid
        m.error = errorMessage
      end if
      return true
    end function

  end class

end namespace
```

Notes for the implementer:
- `finish()` is also called for a non-URL before `totalTimer.mark()`; `elapsedMs` then just reads a fresh timer - harmless.
- If `Rnd()` needs seeding in brs-cli, it doesn't - Rooibos tests already use it. If two tasks in the "same URL" test get the same random number (1 in 10^9), the test would flake; that's acceptable.
- `msg` / `m.transfer` / `m.port` are `dynamic` on purpose: tests swap in fakes.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `npm run check`
Expected: PASS. If a progress assertion fails on Integer vs Float, read the types from the failure diff and adjust the expected literal (the implementation returns `float`).

- [ ] **Step 5: Commit**

```bash
git add src/source/engine/loading/DownloadTask.bs src/source/engine/loading/DownloadTask.spec.bs
git commit -m "Add DownloadTask with cachefs cache, retries and timeouts (#301)"
```

---

### Task 4: URLs in the built-in loads, `download()` and `clearCache()`

**Files:**
- Modify: `src/source/engine/loading/AssetLoadTasks.bs` - new `FileLoadTask` base; `BitmapLoadTask`, `SoundLoadTask`, `FontLoadTask` extend it
- Modify: `src/source/engine/loading/AssetLoader.bs` - `maxConcurrentDownloads`, `download()`, `newDownloadTask()`, `clearCache()`, URL-aware `loadBitmap`/`loadSound`/`registerFont`
- Test: `src/source/engine/loading/AssetLoaderDownloads.spec.bs` (new)

**Interfaces:**
- Consumes: Task 3's `BGE.DownloadTask`, `BGE.DownloadOptions`, `BGE.DownloadSlots`; Task 1's `BGE.isUrl`, `BGE.DOWNLOAD_CACHE_FOLDER`.
- Produces:
  - `class BGE.FileLoadTask extends BGE.LoadTask` - `new(path as string)`; public `path as string`, `download as BGE.DownloadTask = invalid`, `downloadShare as float = 0.8`; overridable `loadFile(budgetMs as integer) as boolean` (default `true`), `getFileProgress() as float` (default `0.0`). Its `step`/`getProgress` are final in practice - subclasses override `loadFile`/`getFileProgress` instead.
  - `BitmapLoadTask`/`SoundLoadTask`/`FontLoadTask`: same constructors as today, now `extends FileLoadTask`, their old `step` body moved into `loadFile` and reading `m.path`.
  - `AssetLoader`: `maxConcurrentDownloads as integer = 4`; `download(url as string, options = {} as BGE.DownloadOptions) as BGE.DownloadTask`; `newDownloadTask(url as string, options as BGE.DownloadOptions) as BGE.DownloadTask` (creates, doesn't queue; overridable); `clearCache()`; `loadBitmap(bitmapName, pathOrUrl, options = {} as BGE.DownloadOptions)`, `loadSound(soundName, pathOrUrl, options = {} as BGE.DownloadOptions)`, `registerFont(pathOrUrl, options = {} as BGE.DownloadOptions)` - all still return `BGE.LoadTask`.

- [ ] **Step 1: Write the failing tests**

Create `src/source/engine/loading/AssetLoaderDownloads.spec.bs`:

```brighterscript
import "pkg:/source/engine/loading/AssetLoader.bs"

namespace tests

  @suite("BGE.AssetLoader downloads")
  class AssetLoaderDownloadsTests extends rooibos.BaseTestSuite

    game as BGE.Game
    loader as tests.ServedAssetLoader

    protected override function beforeEach()
      m.game = new BGE.Game(320, 240)
      m.loader = new tests.ServedAssetLoader(m.game)
      bitmap = CreateObject("roBitmap", {width: 4, height: 2, AlphaEnable: true})
      bitmap.GetPng(0, 0, 4, 2).WriteFile("tmp:/bge_served.png")
    end function

    @describe("URL loads")

    @it("downloads then loads a bitmap from a URL")
    function _()
      m.loader.files["https://example.com/a.png"] = "tmp:/bge_served.png"
      task = m.loader.loadBitmap("remote", "https://example.com/a.png")
      tests.runLoader(m.loader)
      m.assertEqual(0, m.loader.getErrors().count())
      m.assertEqual(4, m.game.getBitmap("remote").GetWidth())
      fileTask = task as BGE.FileLoadTask
      m.assertEqual("https://example.com/a.png", fileTask.download.url)
    end function

    @it("fails the load when its download fails")
    function _()
      task = m.loader.loadBitmap("remote", "https://example.com/missing.png")
      tests.runLoader(m.loader)
      m.assertEqual(1, m.loader.getErrors().count())
      m.assertTrue(task.error.Instr("404") >= 0)
      m.assertInvalid(m.game.Bitmaps["remote"])
    end function

    @it("fails a sound load when its download fails")
    function _()
      m.loader.loadSound("remote", "https://example.com/missing.wav")
      tests.runLoader(m.loader)
      m.assertEqual(1, m.loader.getErrors().count())
    end function

    @it("still loads local paths without a download")
    function _()
      task = m.loader.loadBitmap("local", "tmp:/bge_served.png")
      tests.runLoader(m.loader)
      fileTask = task as BGE.FileLoadTask
      m.assertInvalid(fileTask.download)
      m.assertEqual(0, m.loader.requested.count())
    end function

    @it("reports download progress before the file loads")
    function _()
      m.loader.files["https://example.com/a.png"] = "tmp:/bge_served.png"
      m.loader.stepsPerDownload = 3
      task = m.loader.loadBitmap("remote", "https://example.com/a.png")
      m.loader.update(12)
      progress = m.loader.getProgress()
      m.assertTrue(progress > 0)
      m.assertTrue(progress < 0.8)
      tests.runLoader(m.loader)
      m.assertEqual(1.0, task.getProgress())
    end function

    @describe("download and the cache")

    @it("queues a plain download with the loader's slots")
    function _()
      m.loader.files["https://example.com/a.png"] = "tmp:/bge_served.png"
      m.loader.maxConcurrentDownloads = 2
      task = m.loader.download("https://example.com/a.png")
      tests.runLoader(m.loader)
      m.assertNotInvalid(task.slots)
      m.assertEqual(2, task.slots.max)
      m.assertNotEqual("", task.localPath)
    end function

    @it("clears the download cache")
    function _()
      fs = CreateObject("roFileSystem")
      fs.CreateDirectory(BGE.DOWNLOAD_CACHE_FOLDER)
      WriteAsciiFile(BGE.DOWNLOAD_CACHE_FOLDER + "/stale.png", "x")
      m.loader.clearCache()
      m.assertFalse(fs.Exists(BGE.DOWNLOAD_CACHE_FOLDER + "/stale.png"))
    end function

  end class

  ' Runs a loader until it's done (or 50 updates pass).
  sub runLoader(loader as BGE.AssetLoader)
    for i = 1 to 50
      loader.update(12)
      if loader.isDone()
        return
      end if
    end for
  end sub

  ' An AssetLoader whose downloads are served from local files instead of the network.
  ' A URL missing from `files` fails with HTTP 404.
  class ServedAssetLoader extends BGE.AssetLoader
    files as roAssociativeArray
    requested as roArray
    stepsPerDownload as integer = 1

    sub new(game as BGE.Game)
      super(game)
      m.files = {}
      m.requested = []
    end sub

    override function newDownloadTask(url as string, options as BGE.DownloadOptions) as BGE.DownloadTask
      m.requested.push(url)
      task = new tests.ServedDownloadTask(url, m.files[url], m.stepsPerDownload)
      task.slots = m.getDownloadSlots()
      return task
    end function
  end class

  class ServedDownloadTask extends BGE.DownloadTask
    sourcePath as dynamic
    stepsLeft as integer

    sub new(url as string, sourcePath as dynamic, steps as integer)
      super(url, {cache: false})
      m.sourcePath = sourcePath
      m.stepsLeft = steps
    end sub

    override function step(budgetMs as integer) as boolean
      m.stepsLeft--
      if m.stepsLeft > 0
        m.waitingForNextFrame = true
        return false
      end if
      if m.sourcePath = invalid
        m.error = "HTTP 404 downloading " + m.url
        return true
      end if
      m.localPath = m.sourcePath
      return true
    end function

    override function getProgress() as float
      if m.localPath <> ""
        return 1.0
      end if
      return 0.5
    end function
  end class

end namespace
```

`getDownloadSlots()` is a small public accessor added to `AssetLoader` in Step 3 so a subclass's `newDownloadTask` can share the loader's slots.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `npm run test:ci`
Expected: FAIL / build error - `BGE.FileLoadTask`, `newDownloadTask`, `download`, `clearCache` don't exist.

- [ ] **Step 3: Implement**

In `src/source/engine/loading/AssetLoadTasks.bs`:

1. Add `import "DownloadTask.bs"` and `import "../../utils/urls.bs"` to the imports.

2. Add `FileLoadTask` above `BitmapLoadTask`:

```brighterscript
  ' Base for the built-in loads. Given a URL, the AssetLoader attaches a `download`; this task
  ' runs it first, then loads the downloaded file. Subclasses override `loadFile()` (and
  ' `getFileProgress()` if loading takes more than one step) rather than `step()`.
  class FileLoadTask extends LoadTask

    ' The file to load - the download's local file once downloaded
    path as string
    ' Downloads `path` first when it's a URL (invalid for a local file)
    download as BGE.DownloadTask = invalid
    ' Share of this task's progress that the download counts for
    downloadShare as float = 0.8

    private downloaded as boolean = false

    sub new(path as string)
      super()
      m.path = path
    end sub

    override function step(budgetMs as integer) as boolean
      if m.download <> invalid and not m.downloaded
        if not m.download.step(budgetMs)
          m.waitingForNextFrame = true
          return false
        end if
        m.downloaded = true
        if m.download.error <> invalid
          m.error = m.download.error
          return true
        end if
        m.path = m.download.localPath
      end if
      return m.loadFile(budgetMs)
    end function

    override function getProgress() as float
      if m.download = invalid
        return m.getFileProgress()
      end if
      if not m.downloaded
        return m.download.getProgress() * m.downloadShare
      end if
      return m.downloadShare + (1 - m.downloadShare) * m.getFileProgress()
    end function

    ' Loads the local file at `path`. Called repeatedly until it returns true.
    '
    ' @param {integer} budgetMs
    ' @return {boolean} true when finished (set `error` on failure)
    function loadFile(budgetMs as integer) as boolean
      return true
    end function

    ' How far `loadFile()` has got, 0 to 1.
    '
    ' @return {float}
    function getFileProgress() as float
      return 0.0
    end function

  end class
```

3. `BitmapLoadTask`: change to `class BitmapLoadTask extends FileLoadTask`; remove its `private path as string` field; constructor becomes:

```brighterscript
    sub new(game as BGE.Game, bitmapName as string, path as string)
      super(path)
      m.name = "bitmap " + path
      m.game = game
      m.bitmapName = bitmapName
    end sub

    override function loadFile(budgetMs as integer) as boolean
      if not m.game.loadBitmap(m.bitmapName, m.path)
        m.error = "could not load bitmap " + m.path
      end if
      return true
    end function
```

(delete its old `step` override). Do the same for `SoundLoadTask` (its old `step` body becomes `loadFile`, reading `m.path`) and `FontLoadTask`. Keep `ModelLoadTask` as it is in this task - Task 5 converts it.

In `src/source/engine/loading/AssetLoader.bs`:

1. Add `import "DownloadTask.bs"` and `import "../../utils/urls.bs"`.

2. Fields (below `timer`):

```brighterscript
    ' Most downloads this loader runs at once
    maxConcurrentDownloads as integer = 4
```

and private `private downloadSlots as BGE.DownloadSlots`, created in `new()`: `m.downloadSlots = new BGE.DownloadSlots()`.

3. At the top of `update()` (before the `m.tasks.count() = 0` early return): `m.downloadSlots.max = m.maxConcurrentDownloads`.

4. Replace `loadBitmap`, `loadSound`, `registerFont` with URL-aware versions:

```brighterscript
    ' Queues loading a bitmap, as `game.loadBitmap()` would. A http(s):// URL is downloaded first
    ' (see `download()` for caching).
    '
    ' @param {string} bitmapName - the name to get it by later (`game.getBitmap()`)
    ' @param {string} pathOrUrl - local file path or URL
    ' @param {BGE.DownloadOptions} [options={}] - for a URL: caching, timeout and retries
    ' @return {BGE.LoadTask} the queued task
    function loadBitmap(bitmapName as string, pathOrUrl as string, options = {} as BGE.DownloadOptions) as BGE.LoadTask
      task = new BGE.BitmapLoadTask(m.game, bitmapName, pathOrUrl)
      m.attachDownload(task, pathOrUrl, options)
      return m.addTask(task)
    end function
```

Same shape for `loadSound(soundName as string, pathOrUrl as string, options = {} as BGE.DownloadOptions)` (`SoundLoadTask`, doc: "as `game.loadSound()` would") and `registerFont(pathOrUrl as string, options = {} as BGE.DownloadOptions)` (`FontLoadTask`, doc: "as `game.registerFont()` would").

5. New public methods, placed after `registerFont`:

```brighterscript
    ' Queues a download of a URL to a local file. It's saved in the cachefs: cache, so a later
    ' download of the same URL (even after a relaunch) uses that file without a request. The
    ' OS may clear the cache when space runs low. Once done, the task's `localPath` is the file.
    '
    ' @param {string} url - a http:// or https:// URL
    ' @param {BGE.DownloadOptions} [options={}] - `cache: false` for tmp: instead, `refresh: true` to download again, `timeoutSeconds`, `retries`
    ' @return {BGE.DownloadTask} the queued task
    function download(url as string, options = {} as BGE.DownloadOptions) as BGE.DownloadTask
      task = m.newDownloadTask(url, options)
      m.addTask(task)
      return task
    end function

    ' Creates (but doesn't queue) the DownloadTask for a URL. Used by every download this loader
    ' makes - override it to change how downloads are made.
    '
    ' @param {string} url
    ' @param {BGE.DownloadOptions} options
    ' @return {BGE.DownloadTask}
    function newDownloadTask(url as string, options as BGE.DownloadOptions) as BGE.DownloadTask
      task = new BGE.DownloadTask(url, options)
      task.slots = m.downloadSlots
      return task
    end function

    ' The slots this loader's downloads share, for a `newDownloadTask()` override.
    '
    ' @return {BGE.DownloadSlots}
    function getDownloadSlots() as BGE.DownloadSlots
      return m.downloadSlots
    end function

    ' Deletes every file in the download cache, so later downloads make a fresh request. Don't
    ' call it while downloads are running.
    sub clearCache()
      filesystem = CreateObject("roFileSystem")
      for each fileName in filesystem.GetDirectoryListing(BGE.DOWNLOAD_CACHE_FOLDER)
        filesystem.Delete(BGE.DOWNLOAD_CACHE_FOLDER + "/" + fileName)
      end for
    end sub
```

6. Private helper (near `dependenciesReady`):

```brighterscript
    private sub attachDownload(task as BGE.FileLoadTask, pathOrUrl as string, options as BGE.DownloadOptions)
      if BGE.isUrl(pathOrUrl)
        task.download = m.newDownloadTask(pathOrUrl, options)
      end if
    end sub
```

7. Update the class doc comment's first paragraph to mention URLs: `' ... A built-in load given a http(s):// URL downloads it first, caching it in cachefs: (see download()).`

- [ ] **Step 4: Run the tests to verify they pass**

Run: `npm run check`
Expected: PASS, including the existing `AssetLoadTasks.spec.bs` (local loads unchanged).

- [ ] **Step 5: Commit**

```bash
git add src/source/engine/loading/AssetLoadTasks.bs src/source/engine/loading/AssetLoader.bs src/source/engine/loading/AssetLoaderDownloads.spec.bs
git commit -m "Load bitmaps, sounds and fonts from URLs (#301)"
```

---

### Task 5: Models from URLs, with URL-relative textures

**Files:**
- Modify: `src/source/engine/loading/AssetLoadTasks.bs` - `ModelLoadTask` extends `FileLoadTask`, downloads `.mtl`/texture
- Modify: `src/source/engine/loading/AssetLoader.bs` - `load3dModel` takes a URL and `downloadOptions`
- Modify: `src/source/utils/parsers/OBJParseTask.bs` - `mtllibName` becomes public
- Test: `src/source/engine/loading/AssetLoaderModelDownloads.spec.bs` (new)

**Interfaces:**
- Consumes: Task 4's `FileLoadTask`, `AssetLoader.newDownloadTask()`; Task 3's `DownloadTask`; Task 1's `isUrl`, `resolveRelativeUrl`; `BGE.Parsers.extractMapKdPath(mtlContent as string) as string`; `Game.addLoadedModel(modelName, model, options, loadTexture)`.
- Produces:
  - `OBJParseTask.mtllibName as string` (public, read-only by convention: "the `mtllib` the file names, or empty").
  - `AssetLoader.load3dModel(modelName as string, pathOrUrl as string, options = {} as BGE.Model3dLoadOptions, downloadOptions = {} as BGE.DownloadOptions) as BGE.LoadTask`.
  - `ModelLoadTask.new(game as BGE.Game, modelName as string, path as string, options as BGE.Model3dLoadOptions)` unchanged; new public field `loader as BGE.AssetLoader = invalid` and `downloadOptions as BGE.DownloadOptions` (set by `AssetLoader.load3dModel`).

Behaviour:
- Model from a URL: the base downloads it. An `.obj` is parsed with no base folder (nothing local to resolve against), then, unless `options.texturePath` is set, its `mtllib` is resolved against the **model's URL** and downloaded, its `map_Kd` resolved against the model's URL and downloaded, and that file is the texture.
- `options.texturePath` that is a URL (model local or remote) is downloaded and used.
- A failed `.mtl`/texture download, or an `.mtl` with no `map_Kd`: warning `BGE.AssetLoader - <error>, model <name> will render untextured` via `game.log(..., LogLevel.warning)`, model added untextured, task has no `error`.
- Local model with a local texture: unchanged.
- `downloadShare` is 0.5 for models (parsing is real work).

- [ ] **Step 1: Write the failing tests**

Create `src/source/engine/loading/AssetLoaderModelDownloads.spec.bs`:

```brighterscript
import "pkg:/source/engine/loading/AssetLoader.bs"

namespace tests

  @suite("BGE.AssetLoader model downloads")
  class AssetLoaderModelDownloadsTests extends rooibos.BaseTestSuite

    game as BGE.Game
    loader as tests.ServedAssetLoader

    protected override function beforeEach()
      m.game = new BGE.Game(320, 240)
      m.loader = new tests.ServedAssetLoader(m.game)
      objLines = ["mtllib tri.mtl", "v 0 0 0", "v 1 0 0", "v 0 1 0", "vt 0 0", "vt 1 0", "vt 0 1", "f 1/1 2/2 3/3"]
      WriteAsciiFile("tmp:/bge_served_tri.obj", objLines.join(chr(10)))
      WriteAsciiFile("tmp:/bge_served_tri.mtl", "newmtl m" + chr(10) + "map_Kd tex/atlas.png")
      WriteAsciiFile("tmp:/bge_served_nomap.mtl", "newmtl m")
      bitmap = CreateObject("roBitmap", {width: 8, height: 8, AlphaEnable: true})
      bitmap.GetPng(0, 0, 8, 8).WriteFile("tmp:/bge_served_atlas.png")
    end function

    @describe("models from URLs")

    @it("downloads an .obj, its .mtl and its texture relative to the model's URL")
    function _()
      m.loader.files["https://example.com/models/tri.obj"] = "tmp:/bge_served_tri.obj"
      m.loader.files["https://example.com/models/tri.mtl"] = "tmp:/bge_served_tri.mtl"
      m.loader.files["https://example.com/models/tex/atlas.png"] = "tmp:/bge_served_atlas.png"
      m.loader.load3dModel("tri", "https://example.com/models/tri.obj")
      tests.runLoader(m.loader)
      m.assertEqual(0, m.loader.getErrors().count())
      m.assertEqual(3, m.loader.requested.count())
      m.assertEqual("https://example.com/models/tex/atlas.png", m.loader.requested[2])
      face = m.game.Models["tri"].faces[0]
      m.assertNotInvalid(face.Texture)
      m.assertNotInvalid(face.Texture.srcRegionWithId)
    end function

    @it("uses a URL texturePath instead of the .mtl")
    function _()
      m.loader.files["https://example.com/models/tri.obj"] = "tmp:/bge_served_tri.obj"
      m.loader.files["https://cdn.example.com/skin.png"] = "tmp:/bge_served_atlas.png"
      m.loader.load3dModel("tri", "https://example.com/models/tri.obj", {texturePath: "https://cdn.example.com/skin.png"})
      tests.runLoader(m.loader)
      m.assertEqual(2, m.loader.requested.count())
      m.assertNotInvalid(m.game.Models["tri"].faces[0].Texture.srcRegionWithId)
    end function

    @it("downloads a URL texturePath for a local model")
    function _()
      m.loader.files["https://cdn.example.com/skin.png"] = "tmp:/bge_served_atlas.png"
      m.loader.load3dModel("tri", "tmp:/bge_served_tri.obj", {texturePath: "https://cdn.example.com/skin.png"})
      tests.runLoader(m.loader)
      m.assertEqual(1, m.loader.requested.count())
      m.assertNotInvalid(m.game.Models["tri"].faces[0].Texture.srcRegionWithId)
    end function

    @it("loads the model untextured when its texture download fails")
    function _()
      m.loader.files["https://example.com/models/tri.obj"] = "tmp:/bge_served_tri.obj"
      m.loader.files["https://example.com/models/tri.mtl"] = "tmp:/bge_served_tri.mtl"
      task = m.loader.load3dModel("tri", "https://example.com/models/tri.obj")
      tests.runLoader(m.loader)
      m.assertInvalid(task.error)
      m.assertEqual(0, m.loader.getErrors().count())
      m.assertNotInvalid(m.game.Models["tri"])
      m.assertInvalid(m.game.Models["tri"].faces[0].Texture)
    end function

    @it("loads the model untextured when its .mtl has no map_Kd")
    function _()
      m.loader.files["https://example.com/models/tri.obj"] = "tmp:/bge_served_tri.obj"
      m.loader.files["https://example.com/models/tri.mtl"] = "tmp:/bge_served_nomap.mtl"
      m.loader.load3dModel("tri", "https://example.com/models/tri.obj")
      tests.runLoader(m.loader)
      m.assertEqual(2, m.loader.requested.count())
      m.assertInvalid(m.game.Models["tri"].faces[0].Texture)
    end function

    @it("fails the task when the model itself can't be downloaded")
    function _()
      task = m.loader.load3dModel("tri", "https://example.com/models/missing.obj")
      tests.runLoader(m.loader)
      m.assertNotInvalid(task.error)
      m.assertInvalid(m.game.Models["tri"])
    end function

    @it("still resolves a local .obj's texture locally")
    function _()
      WriteAsciiFile("tmp:/bge_local_tri.obj", "mtllib bge_local.mtl" + chr(10) + "v 0 0 0" + chr(10) + "v 1 0 0" + chr(10) + "v 0 1 0" + chr(10) + "vt 0 0" + chr(10) + "vt 1 0" + chr(10) + "vt 0 1" + chr(10) + "f 1/1 2/2 3/3")
      WriteAsciiFile("tmp:/bge_local.mtl", "newmtl m" + chr(10) + "map_Kd bge_served_atlas.png")
      m.loader.load3dModel("local", "tmp:/bge_local_tri.obj")
      tests.runLoader(m.loader)
      m.assertEqual(0, m.loader.requested.count())
      m.assertNotInvalid(m.game.Models["local"].faces[0].Texture.srcRegionWithId)
    end function

  end class

end namespace
```

`tests.ServedAssetLoader`/`tests.runLoader` come from `AssetLoaderDownloads.spec.bs` (Task 4) - same `tests` namespace, both files are in the test build.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `npm run test:ci`
Expected: FAIL - `load3dModel` doesn't download URLs.

- [ ] **Step 3: Implement**

`src/source/utils/parsers/OBJParseTask.bs`: change `private mtllibName as string = ""` to

```brighterscript
    ' The material library the file names (`mtllib`), or "" - set while parsing
    mtllibName as string = ""
```

`src/source/engine/loading/AssetLoader.bs` - replace `load3dModel`:

```brighterscript
    ' Queues loading a .obj or .stl model, parsed a slice at a time so a big model doesn't
    ' freeze the screen. A http(s):// URL is downloaded first; an .obj from a URL also downloads
    ' its .mtl and texture, found relative to the model's URL. Set the returned task's `weight`
    ' higher than other tasks' for a big model, so the progress bar reflects how long it takes.
    '
    ' @param {string} modelName - the name to get it by later (`game.get3dModel()`)
    ' @param {string} pathOrUrl - local file path or URL
    ' @param {BGE.Model3dLoadOptions} [options={}] - same options as `game.load3dModel()`; `texturePath` may be a URL
    ' @param {BGE.DownloadOptions} [downloadOptions={}] - caching, timeout and retries for every download this model needs
    ' @return {BGE.LoadTask} the queued task
    function load3dModel(modelName as string, pathOrUrl as string, options = {} as BGE.Model3dLoadOptions, downloadOptions = {} as BGE.DownloadOptions) as BGE.LoadTask
      task = new BGE.ModelLoadTask(m.game, modelName, pathOrUrl, options)
      task.loader = m
      task.downloadOptions = downloadOptions
      m.attachDownload(task, pathOrUrl, downloadOptions)
      return m.addTask(task)
    end function
```

`src/source/engine/loading/AssetLoadTasks.bs` - add `import "AssetLoader.bs"` and replace `ModelLoadTask` with:

```brighterscript
  ' Loads a .obj or .stl model a slice at a time: downloads it if it's a URL, reads the file,
  ' parses it over as many steps as it needs, downloads a remote texture if there is one, then
  ' adds it to the game (loading an .obj's texture).
  class ModelLoadTask extends FileLoadTask

    ' Makes this model's texture downloads. Set by AssetLoader.
    loader as BGE.AssetLoader = invalid
    ' Options for this model's texture downloads. Set by AssetLoader.
    downloadOptions as BGE.DownloadOptions

    private game as BGE.Game
    private modelName as string
    private options as BGE.Model3dLoadOptions
    private parseTask as BGE.Parsers.ModelParseTask = invalid
    private model as BGE.Model3d = invalid
    private isObj as boolean = false
    private parsed as boolean = false
    private modelUrl as string = ""
    private textureDownload as BGE.DownloadTask = invalid
    private mtlDownload as BGE.DownloadTask = invalid
    private localTexturePath as string = ""

    sub new(game as BGE.Game, modelName as string, path as string, options as BGE.Model3dLoadOptions)
      super(path)
      m.name = "model " + path
      m.game = game
      m.modelName = modelName
      m.options = options
      m.downloadOptions = {}
      m.downloadShare = 0.5
      if BGE.isUrl(path)
        m.modelUrl = path
      end if
    end sub

    override function loadFile(budgetMs as integer) as boolean
      if not m.parsed
        if m.parseTask = invalid
          return m.startParse()
        end if
        if not m.parseTask.step(budgetMs)
          return false
        end if
        if m.parseTask.error <> invalid
          m.error = m.parseTask.error + " (" + m.path + ")"
          return true
        end if
        m.model = m.parseTask.model
        mtllibName = ""
        if m.isObj
          objTask = m.parseTask as BGE.Parsers.OBJParseTask
          mtllibName = objTask.mtllibName
        end if
        ' the source text isn't needed once parsed
        m.parseTask = invalid
        m.parsed = true
        m.startTextureDownloads(mtllibName)
      end if
      if not m.stepTextureDownloads(budgetMs)
        m.waitingForNextFrame = true
        return false
      end if
      return m.addModel()
    end function

    override function getFileProgress() as float
      if m.parsed
        return 0.95
      end if
      if m.parseTask = invalid
        return 0.0
      end if
      return m.parseTask.getProgress() * 0.9
    end function

    ' Reads the file and creates the parse task. Returns true only if that failed.
    private function startParse() as boolean
      if not CreateObject("roFileSystem").Exists(m.path)
        m.error = "model file not found: " + m.path
        return true
      end if
      ' a downloaded file's name is a hash, so take the type from the original path/URL
      extensionLower = LCase(CreateObject("roPath", m.path).Split().extension)
      if m.modelUrl <> ""
        extensionLower = BGE.urlFileExtension(m.modelUrl)
      end if
      if extensionLower = ".obj"
        m.isObj = true
        content = ReadAsciiFile(m.path)
        ' a remote .obj's .mtl is resolved against its URL after parsing, not the cache folder
        baseDir = ""
        if m.modelUrl = ""
          baseDir = CreateObject("roPath", m.path).Split().parent
        end if
        objTask = new BGE.Parsers.OBJParseTask(content, baseDir)
        m.parseTask = objTask
      else if extensionLower = ".stl"
        content = ReadAsciiFile(m.path)
        if LCase(content.Left(5)) = "solid"
          asciiTask = new BGE.Parsers.STLAsciiParseTask(content)
          m.parseTask = asciiTask
        else
          bytes = CreateObject("roByteArray")
          if not bytes.ReadFile(m.path)
            m.error = "could not read model " + m.path
            return true
          end if
          binaryTask = new BGE.Parsers.STLBinaryParseTask(bytes)
          m.parseTask = binaryTask
        end if
      else
        m.error = "model " + m.path + " must be .stl or .obj"
        return true
      end if
      return false
    end function

    ' Starts whichever download the texture needs, if any.
    private sub startTextureDownloads(mtllibName as string)
      texturePath = ""
      if m.options <> invalid and m.options.texturePath <> invalid
        texturePath = m.options.texturePath
      end if
      if BGE.isUrl(texturePath)
        m.textureDownload = m.newDownload(texturePath)
      else if texturePath = "" and m.isObj and m.modelUrl <> "" and mtllibName <> ""
        m.mtlDownload = m.newDownload(BGE.resolveRelativeUrl(m.modelUrl, mtllibName))
      end if
    end sub

    ' Steps the .mtl then texture download. Returns true when there's nothing left to download.
    private function stepTextureDownloads(budgetMs as integer) as boolean
      if m.mtlDownload <> invalid
        if not m.mtlDownload.step(budgetMs)
          return false
        end if
        mtl = m.mtlDownload
        m.mtlDownload = invalid
        if mtl.error <> invalid
          m.warnUntextured(mtl.error)
          return true
        end if
        mapKdPath = BGE.Parsers.extractMapKdPath(ReadAsciiFile(mtl.localPath))
        if mapKdPath = ""
          m.warnUntextured(mtl.url + " has no map_Kd texture")
          return true
        end if
        m.textureDownload = m.newDownload(BGE.resolveRelativeUrl(m.modelUrl, mapKdPath))
      end if
      if m.textureDownload <> invalid
        if not m.textureDownload.step(budgetMs)
          return false
        end if
        texture = m.textureDownload
        m.textureDownload = invalid
        if texture.error <> invalid
          m.warnUntextured(texture.error)
          return true
        end if
        m.localTexturePath = texture.localPath
      end if
      return true
    end function

    private function addModel() as boolean
      addOptions = m.options
      if m.localTexturePath <> ""
        addOptions = {texturePath: m.localTexturePath}
      else if m.options <> invalid and BGE.isUrl(m.options.texturePath)
        ' the URL texture failed - don't let addLoadedModel try it as a path
        addOptions = {}
      end if
      if not m.game.addLoadedModel(m.modelName, m.model, addOptions, m.isObj)
        m.error = "could not parse model " + m.path
      end if
      m.model = invalid
      return true
    end function

    private function newDownload(url as string) as BGE.DownloadTask
      if m.loader <> invalid
        return m.loader.newDownloadTask(url, m.downloadOptions)
      end if
      task = new BGE.DownloadTask(url, m.downloadOptions)
      return task
    end function

    private sub warnUntextured(reason as string)
      m.game.log("BGE.AssetLoader - " + reason + ", model " + m.modelName + " will render untextured", BGE.Debug.LogLevel.warning)
    end sub

  end class
```

Notes for the implementer:
- `m.options.texturePath` may be absent (`invalid`); `BGE.isUrl(invalid)` is false, so `addModel()`'s check is safe.
- An `.stl` from a URL with a URL `texturePath` downloads the texture but `addLoadedModel(..., loadTexture=false)` ignores it, same as a local `.stl` today. Don't special-case it.
- The previous `ModelLoadTask.getProgress()` (`parse * 0.95`, `1.0` when parsed) is replaced by `getFileProgress()`; `FileLoadTask` maps it under the download share. The loader's high-water mark keeps the bar from moving back.
- If bsc rejects `m.parseTask as BGE.Parsers.OBJParseTask`, keep a separate `private objParseTask as BGE.Parsers.OBJParseTask = invalid` set in `startParse()` and read `mtllibName` from it.
- If the `AssetLoader.bs` <-> `AssetLoadTasks.bs` import cycle causes a bsc diagnostic, type `loader` as `object` instead and note it.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `npm run check`
Expected: PASS, including the existing `AssetLoadTasks.spec.bs` model tests and `examples/loading`'s local behaviour (validated in Task 6).

- [ ] **Step 5: Commit**

```bash
git add src/source/engine/loading/AssetLoadTasks.bs src/source/engine/loading/AssetLoader.bs src/source/utils/parsers/OBJParseTask.bs src/source/engine/loading/AssetLoaderModelDownloads.spec.bs
git commit -m "Load models from URLs with URL-relative textures (#301)"
```

---

### Task 6: `examples/loading` remote and failure scenes

**Files:**
- Create: `examples/loading/remote-assets/` - `images/rpgSplash.png` (copy of `examples/loading/src/images/big/rpgSplash.png`), `images/icon.png` (copy of `examples/loading/src/images/Channel_Icon_HD.png`), `models/d20.obj`, `models/d20.mtl`, `models/d20_atlas.png` (copies from `examples/loading/src/models/`), `sounds/hit.wav` (copy of `examples/pong/src/sounds/hit.wav`), `README.md`
- Create: `examples/loading/src/source/Scenes/RemoteAssetsScene.bs`
- Create: `examples/loading/src/source/Scenes/FailureScene.bs`
- Modify: `examples/loading/src/source/main.bs` - `baseUrl` launch param, define the two scenes
- Modify: `examples/loading/src/source/Scenes/MenuScene.bs` - three more buttons

**Interfaces:**
- Consumes: `AssetLoader.loadBitmap/loadSound/load3dModel` with URLs, `AssetLoader.clearCache()`, `FileLoadTask.download` (`fromCache`, `elapsedMs`, `url`), `game.getSceneLoader().getErrors()`; the existing `TimedLoadingScreen`.
- Produces: scenes `RemoteAssetsScene`, `FailureScene`; launch params `baseUrl` (default `https://raw.githubusercontent.com/markwpearce/brighterscript-game-engine/main/examples/loading/remote-assets/`, must end in `/`) and the existing `scene`.

- [ ] **Step 1: Copy the remote assets**

```bash
mkdir -p examples/loading/remote-assets/images examples/loading/remote-assets/models examples/loading/remote-assets/sounds
cp examples/loading/src/images/big/rpgSplash.png examples/loading/remote-assets/images/rpgSplash.png
cp examples/loading/src/images/Channel_Icon_HD.png examples/loading/remote-assets/images/icon.png
cp examples/loading/src/models/d20.obj examples/loading/src/models/d20.mtl examples/loading/src/models/d20_atlas.png examples/loading/remote-assets/models/
cp examples/pong/src/sounds/hit.wav examples/loading/remote-assets/sounds/hit.wav
```

Check `d20.mtl`'s `map_Kd` names `d20_atlas.png` (a sibling), so the URL-relative resolution finds it.

Create `examples/loading/remote-assets/README.md`:

```markdown
Files the loading example downloads (they aren't in the channel package). By default it reads
them from this folder on GitHub's `main` branch. To serve them yourself:

    python3 -m http.server 8000 --directory examples/loading/remote-assets

then launch with `baseUrl=http://<your computer's IP>:8000/`.
```

- [ ] **Step 2: Write `RemoteAssetsScene`**

Create `examples/loading/src/source/Scenes/RemoteAssetsScene.bs`:

```brighterscript
' Downloads an image, a textured model and a sound in onLoad(), then lists where each came from
' (network or cache) and how long it took. A relaunch should show everything from the cache.
class RemoteAssetsScene extends BGE.GameScene

  private baseUrl as string
  private loadTimer as roTimespan
  private tasks as roAssociativeArray

  sub new(game as BGE.Game, baseUrl as string)
    super(game)
    m.name = "RemoteAssetsScene"
    m.baseUrl = baseUrl
  end sub

  override sub onLoad(loader as BGE.AssetLoader, args as roAssociativeArray)
    m.loadTimer = CreateObject("roTimespan")
    m.game.gameUi.clearChildren()
    m.tasks = {}
    m.tasks["rpgSplash.png"] = loader.loadBitmap("remoteSplash", m.baseUrl + "images/rpgSplash.png")
    m.tasks["icon.png"] = loader.loadBitmap("remoteIcon", m.baseUrl + "images/icon.png")
    m.tasks["d20.obj"] = loader.load3dModel("remoteD20", m.baseUrl + "models/d20.obj")
    m.tasks["hit.wav"] = loader.loadSound("remoteHit", m.baseUrl + "sounds/hit.wav")
  end sub

  override function getLoadingScreen() as BGE.LoadingScreen
    screen = new TimedLoadingScreen(m.game.getFont("debugUI"))
    return screen
  end function

  override sub onCreate(args as roAssociativeArray)
    seconds = m.loadTimer.TotalMilliseconds() / 1000.0
    m.game.gameUi.clearChildren()
    lines = [`Loaded from ${m.baseUrl}`, `in ${seconds}s - OK plays the sound, Back for the menu`]
    for each fileName in m.tasks
      lines.push(m.describe(fileName, m.tasks[fileName]))
    end for
    splash = m.game.Bitmaps["remoteSplash"]
    if splash <> invalid
      lines.push(`rpgSplash.png is ${splash.GetWidth()}x${splash.GetHeight()}`)
    end if
    model = m.game.Models["remoteD20"]
    if model <> invalid
      textured = model.faces.count() > 0 and model.faces[0].Texture <> invalid
      lines.push(`d20.obj has ${model.faces.count()} faces, textured: ${textured}`)
    end if
    for each errorMessage in m.game.getSceneLoader().getErrors()
      lines.push("ERROR " + errorMessage)
    end for
    m.showLines(lines)
  end sub

  override sub onInput(input as BGE.GameInput)
    if input.press and input.isButton("OK")
      m.game.playSound("remoteHit")
    else if input.press and input.isButton("back")
      m.game.changeScene("MenuScene")
    end if
  end sub

  private function describe(fileName as string, task as BGE.LoadTask) as string
    if task.error <> invalid
      return fileName + ": failed"
    end if
    fileTask = task as BGE.FileLoadTask
    download = fileTask.download
    if download = invalid
      return fileName + ": local"
    end if
    if download.fromCache
      return fileName + ": cache"
    end if
    return `${fileName}: network, ${download.elapsedMs}ms`
  end function

  private sub showLines(lines as roArray)
    width = m.game.uiCanvas.getWidth()
    height = m.game.uiCanvas.getHeight()
    for i = 0 to lines.count() - 1
      label = new BGE.UI.Label(m.game)
      label.setText(lines[i])
      label.customPosition = true
      label.customX = width * 0.11
      label.customY = height * 0.11 + i * height * 0.05
      m.game.gameUi.addChild(label)
    end for
  end sub

end class
```

Check the button name for OK in `src/source/utils/utils.bs`'s `buttonNameFromCode` (it may be `"OK"`) and match it.

- [ ] **Step 3: Write `FailureScene`**

Create `examples/loading/src/source/Scenes/FailureScene.bs`:

```brighterscript
' Loads a missing remote file, an unreachable host and a missing local file. Each fails, the
' scene still opens, and the errors are listed from getErrors().
class FailureScene extends BGE.GameScene

  private baseUrl as string

  sub new(game as BGE.Game, baseUrl as string)
    super(game)
    m.name = "FailureScene"
    m.baseUrl = baseUrl
  end sub

  override sub onLoad(loader as BGE.AssetLoader, args as roAssociativeArray)
    m.game.gameUi.clearChildren()
    loader.loadBitmap("missingRemote", m.baseUrl + "images/missing.png", {retries: 0})
    loader.loadBitmap("badHost", "https://bge-no-such-host.invalid/image.png", {retries: 0, timeoutSeconds: 10})
    loader.loadBitmap("missingLocal", "pkg:/images/missing.png")
    ' one good load, to show the rest of the scene is unaffected
    loader.loadBitmap("icon", "pkg:/images/Channel_Icon_HD.png")
  end sub

  override sub onCreate(args as roAssociativeArray)
    m.game.gameUi.clearChildren()
    lines = ["These loads fail on purpose - Back for the menu"]
    for each errorMessage in m.game.getSceneLoader().getErrors()
      lines.push(errorMessage)
    end for
    icon = m.game.Bitmaps["icon"]
    if icon <> invalid
      lines.push(`The good load still worked: icon is ${icon.GetWidth()}x${icon.GetHeight()}`)
    end if
    width = m.game.uiCanvas.getWidth()
    height = m.game.uiCanvas.getHeight()
    for i = 0 to lines.count() - 1
      label = new BGE.UI.Label(m.game)
      label.setText(lines[i])
      label.wrapWidth = width * 0.78
      label.customPosition = true
      label.customX = width * 0.11
      label.customY = height * 0.11 + i * height * 0.1
      m.game.gameUi.addChild(label)
    end for
  end sub

  override sub onInput(input as BGE.GameInput)
    if input.press and input.isButton("back")
      m.game.changeScene("MenuScene")
    end if
  end sub

end class
```

- [ ] **Step 4: Wire up `main.bs` and the menu**

In `examples/loading/src/source/main.bs`, after the `custom` scene is defined:

```brighterscript
  baseUrl = "https://raw.githubusercontent.com/markwpearce/brighterscript-game-engine/main/examples/loading/remote-assets/"
  if args <> invalid and args.baseUrl <> invalid and args.baseUrl <> ""
    baseUrl = args.baseUrl
    if not baseUrl.EndsWith("/")
      baseUrl = baseUrl + "/"
    end if
  end if
  remote = new RemoteAssetsScene(game, baseUrl)
  game.defineScene(remote)
  failure = new FailureScene(game, baseUrl)
  game.defineScene(failure)
```

In `MenuScene.onCreate`, add three buttons below "Custom loading screen" with the same size and `customX`, at `customY = height * 0.44`, `0.54`, `0.64`:
- "Remote assets" -> `button.game.changeScene("RemoteAssetsScene")`
- "Failures" -> `button.game.changeScene("FailureScene")`
- "Clear download cache" -> `button.game.assets.clearCache()`, then set the hint label's text to `"Download cache cleared"`. The hint label needs to be reachable from the callback: store it as a field on the scene (`m.hint`) and read it through `button.game.currentScene`, e.g.

```brighterscript
    clearButton.onActivate = sub(button as BGE.UI.Button)
      button.game.assets.clearCache()
      menu = button.game.currentScene as MenuScene
      menu.showHint("Download cache cleared")
    end sub
```

with `sub showHint(text as string)` on `MenuScene` calling `m.hint.setText(text)`. Update the hint's initial text to `"Each scene loads its assets in onLoad() before it opens. Remote scenes download from the web."` if it fits title-safe; otherwise keep it short.

Check all positions stay within 10%..90% of the canvas.

- [ ] **Step 5: Validate and package**

Run: `npm run build && cd examples/loading && npm run package && cd ../..`
Expected: builds `examples/loading/out/bge-loading.zip` with no diagnostics. Also run `npm run check`.

- [ ] **Step 6: Run on a device**

Use the `rokubot-examples` skill. Serve the assets locally first (a background command), using the Mac's LAN IP (`ipconfig getifaddr en0`):

```bash
python3 -m http.server 8000 --directory examples/loading/remote-assets
```

```bash
node node_modules/rokubot/dist/cli.js sideload ./examples/loading/out/bge-loading.zip --deleteDevChannel
node node_modules/rokubot/dist/cli.js press home
node node_modules/rokubot/dist/cli.js launch dev --param scene=RemoteAssetsScene --param baseUrl=http://<ip>:8000/
```

Check, with screenshots and the console:
1. First launch: every file says `network, <n>ms`, `rpgSplash.png` has its real size, `d20.obj ... textured: true`, no errors. The server log shows 5 requests (the `.mtl` and atlas included).
2. `press home`, launch the same again: every file says `cache`, and the server log shows no new requests.
3. `--param scene=FailureScene`: three errors listed (`HTTP 404 ...`, a network error, `could not load bitmap pkg:/images/missing.png` or similar), and the good icon load line.
4. Menu -> "Clear download cache" -> "Remote assets": back to `network`.
5. Ask the user to press OK in the remote scene and confirm the sound plays (rokubot can't hear).

Record the load times in the task report. If the remote scene shows `HTTP 0`/network errors against the local server, check the Mac firewall before suspecting the code.

- [ ] **Step 7: Commit**

```bash
git add examples/loading
git commit -m "Add remote asset and failure scenes to examples/loading (#301)"
```

---

### Task 7: Docs, HTTPS check and final check

**Files:**
- Modify: `docs/loading-assets.md`
- Modify: `CLAUDE.md` (the "Scene loading stage" bullet)
- Modify: `.claude/skills/rokubot-examples/SKILL.md` (the `loading` row)

- [ ] **Step 1: Guide**

In `docs/loading-assets.md`:

1. After "Your own work" and before "Errors", add a section:

````markdown
## Loading from URLs

The built-in loads also take `http://` and `https://` URLs. The file is downloaded first, then
loaded as if it were local:

```brightscript
override sub onLoad(loader as BGE.AssetLoader, args as roAssociativeArray)
  base = "https://example.com/game/"
  loader.loadBitmap("level2", base + "images/level2.png")
  loader.load3dModel("boss", base + "models/boss.obj")
  loader.loadSound("roar", base + "sounds/roar.wav")
end sub
```

Downloads are saved in the device's `cachefs:` cache, so the next time the same URL is loaded,
even after the channel is relaunched, the saved file is used and no request is made. The OS can
clear the cache when it needs space, so the game must still work when everything downloads
again. A URL is assumed to always serve the same file, so when a file changes, give it a new
URL (`level2.png?v=2` or `v2/level2.png`).

An `.obj` from a URL downloads its `.mtl` and texture too, found relative to the model's URL.
`texturePath` may also be a URL.

Each load takes download options: `cache: false` keeps the file only until the channel exits,
`refresh: true` downloads again over a cached copy, and `timeoutSeconds` (30) and `retries` (1)
control failures. A 404 isn't retried; a network error, a server error or a timeout is.

```brightscript
loader.loadBitmap("news", "https://example.com/news.png", {cache: false})
loader.load3dModel("boss", base + "boss.obj", {}, {refresh: true})
```

`loader.download(url)` downloads without loading anything, and its task's `localPath` is the
file once done. At most `loader.maxConcurrentDownloads` (4) downloads run at once.
`game.assets.clearCache()` deletes every cached download.

`game.loadBitmap()` and the other synchronous loaders only take local files, since waiting for a
download would freeze the game. Given a URL they log an error and return false.
`game.musicPlay()` does take a URL - the music player streams it.
````

2. In "Errors", add one sentence after the code block: `A failed download's message says why, e.g. "HTTP 404 downloading https://...".`

3. Replace the last paragraph's example description with: `See examples/loading for a runnable example: one scene loads every model and some large textures under a loading screen with a timing readout, one downloads an image, a textured model and a sound and shows which came from the cache, one shows failed loads, and another builds a tile grid a row per frame under a custom screen.`

Read the whole guide afterwards and fix anything that now contradicts the URL support (e.g. "local path" wording in the built-in loads section).

- [ ] **Step 2: CLAUDE.md and the skill**

`CLAUDE.md`, in the "Scene loading stage" bullet, append: `Built-in loads also take http(s) URLs (PR 2 of #301): BGE.DownloadTask downloads on its own roUrlTransfer/port (never Game.urlPort) into cachefs:/bge/<md5 of url><ext> via a .part file, reusing a cached file with no request; BGE.FileLoadTask runs an attached download before loadFile(); a remote .obj resolves mtllib/map_Kd against its URL. Synchronous Game loaders refuse URLs (musicPlay streams them). Tests fake the network by overriding DownloadTask.createTransfer()/createPort() or AssetLoader.newDownloadTask().`

`.claude/skills/rokubot-examples/SKILL.md`, the `loading` row: add the remote and failure scenes, the `baseUrl` param (default GitHub `main`, or `python3 -m http.server 8000 --directory examples/loading/remote-assets` plus `baseUrl=http://<mac ip>:8000/`), and `scene=RemoteAssetsScene|FailureScene`. Note that a relaunch should show every remote file as `cache`.

- [ ] **Step 3: HTTPS on a device**

Push the branch (`git push -u origin feature/issue-301-url-downloads`), then launch the remote scene against the branch's raw GitHub URL, which is HTTPS:

```bash
node node_modules/rokubot/dist/cli.js launch dev --param scene=RemoteAssetsScene --param baseUrl=https://raw.githubusercontent.com/markwpearce/brighterscript-game-engine/feature/issue-301-url-downloads/examples/loading/remote-assets/
```

(Clear the cache from the menu first, or `--deleteDevChannel` on the sideload, so it's a network load.) Expected: every file `network`, textured d20, no errors. Report the times.

- [ ] **Step 4: Final check**

Run: `npm run check:all`
Expected: lint, validate and tests pass, and every example validates.

- [ ] **Step 5: Commit**

```bash
git add docs/loading-assets.md CLAUDE.md .claude/skills/rokubot-examples/SKILL.md
git commit -m "Document loading from URLs (#301)"
```
