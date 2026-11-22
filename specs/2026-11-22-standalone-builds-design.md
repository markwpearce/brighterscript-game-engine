# Standalone web and desktop builds via brs-engine (issue #235)

## Goal

Let any BGE game ship as a standalone build that runs without a Roku or the BrightScript Simulator:

- a static **web** build (itch.io or any static host), and
- **desktop** apps for macOS, Windows and Linux (Electron).

Both are powered by [brs-engine](https://github.com/lvcabral/brs-engine). The tooling has to work for any game that uses BGE through ROPM/npm, not only the `examples/` in this repo.

## Non-goals (v1)

- Mobile (Android/iOS) and touch controls. These get a separate issue.
- Code signing and notarization. Builds are unsigned, and the docs explain the Gatekeeper/SmartScreen warnings.
- Cross-compiling. Each OS builds its own installers, and CI uses an OS matrix.
- The phone controller web page (`game.enableControllerInput()`). It needs a real `roStreamSocket`, which brs-engine fakes in the browser. The engine must still start and run without it (see Risks).
- Building the game. The CLI starts from an already-built channel zip.

## Key findings

- The engine draws with `roScreen`/`roBitmap`/`roCompositor`, the Draw 2D profile brs-engine fully supports. A Draw 2D app only needs `lib/brs.api.js`, `lib/brs.worker.js` and `assets/common.zip`. `brs.api.js` finds the worker next to its own script URL and fetches `./assets/common.zip` relative to the page, so the bundle must keep that `lib/` + `assets/` layout.
- **SceneGraph is opt-in.** It is not part of `brs-engine`. It is the separate `brs-scenegraph` package (`lib/brs-sg.js` plus its own SceneGraph-ready `assets/common.zip`, registered through `DeviceInfo.extensions`). Most BGE games are pure `roScreen`, so the bundle leaves SceneGraph out unless the config sets `"sceneGraph": true` (for games that mix in SceneGraph, like `examples/scenegraph`/`hybrid`). Engine zips always contain `components/Shapes`, so the spike must confirm that brs-engine runs such a zip as a plain Draw 2D app when no SceneGraph extension is registered.
- brs-engine needs `SharedArrayBuffer`, so the page has to be served with COOP/COEP headers. That rules out loading it as `file://`.
- **Gamepads are native.** brs-engine's browser library maps Gamepad API buttons and sticks to remote keys. When the manifest has `multi_controllers=1`, it adds X/Y/L1/R1/L2/R2 and analog values through `roUniversalControlEvent.GetValue(axis)`. `BGE.Controller.ControllerRegistry` already reads that path (`HasFeature("multi_controllers")`), and the examples already set `multi_controllers=1`. No new engine input code is needed.

## Architecture

```
game repo
├── out/game.zip              (built by the game's own bsc / roku-deploy step)
├── bge-standalone.json       (optional overrides)
└── devDependency: bge-standalone
          │
          │  npx bge-standalone build --target web|mac|win|linux|all
          ▼
dist/web/                      static, host with COOP/COEP
├── index.html                 runtime page (canvas + brs.initialize/execute)
├── runtime.js
├── lib/brs.api.js, lib/brs.worker.js   (+ lib/brs-sg.js if sceneGraph)
├── assets/common.zip                   (brs-scenegraph's copy if sceneGraph)
└── game.zip
          │  (desktop targets only)
          ▼
dist/electron-app/             generated: main.js + package.json + web/
          │  electron-builder
          ▼
dist/desktop/                  .dmg (mac), NSIS .exe (win), .AppImage (linux)
```

### Package

- It lives at `packages/standalone/` in this repo and is published separately as `bge-standalone` (working name; check it's free on npm before the first release). This keeps Electron out of the main `brighterscript-game-engine` package, which every Roku-only ROPM consumer installs.
- Its dependencies are `brs-engine` (pinned to a tested minor version), `electron`, `electron-builder`, `jszip` (for reading the manifest) and `sharp` (for letterboxing the icon). `brs-scenegraph` is an optional peer dependency, needed only when `sceneGraph` is on; the CLI fails with an install hint if it's missing.
- It's plain Node (CommonJS, no build step) and has to run on Windows, like `scripts/*.js`.
- Its version is independent of the engine's. The README lists the BGE and brs-engine versions it was tested with.

### CLI: `bge-standalone build`

```
npx bge-standalone build [--target web|mac|win|linux|all] [--config bge-standalone.json] [--zip path] [--out dist]
npx bge-standalone serve [dir] [--port 6502]    # serve a web build locally with COOP/COEP
```

- The default target is `web` plus the current OS's desktop target.
- `all` means `web` plus the current OS only. Asking for another OS's desktop target fails with a clear message.

Modules (each a separate file in `packages/standalone/lib/`, unit tested):

| Module | Purpose |
| --- | --- |
| `config.js` | Merges CLI flags, `bge-standalone.json` and defaults into one resolved config. Validates it and throws errors that name the bad field. |
| `manifest.js` | Reads `manifest` from the zip and parses it with the same `key=value` rules as Roku. Pulls out `title`, `major/minor/build_version`, `mm_icon_focus_hd` and `multi_controllers`, and extracts the icon bytes. |
| `webBundle.js` | Writes `dist/web/`: copies the runtime template, the brs-engine files from `node_modules/brs-engine` and the game zip, and fills `index.html` with the title and runtime settings. |
| `electronApp.js` | Writes `dist/electron-app/` (main process, `package.json` and a copy of `dist/web/`). |
| `serve.js` | A tiny static `http` server that adds the COOP/COEP headers. Used by `bge-standalone serve` and the end-to-end test. |
| `desktopBuild.js` | Runs electron-builder on the generated app through its JS API with targets dmg/nsis/AppImage. |
| `cli.js` | Parses arguments and sends each target to the right module. |

### Config (`bge-standalone.json`, every field optional)

| Field | Default |
| --- | --- |
| `zip` | required (in the config or as `--zip`) |
| `appId` | `com.bge.<slug of title>` |
| `productName` | manifest `title` |
| `version` | manifest `major.minor.build` |
| `icon` | Manifest `mm_icon_focus_hd`, read from the zip. A square PNG of at least 512×512 is used as-is. Anything else, such as a typical 336×210 Roku icon, is **letterboxed**: scaled to fit 512×512 with its aspect ratio kept and centered with **transparent** bars, with a warning suggesting a proper icon. If it can't be decoded, the build warns and uses Electron's default icon. An explicit `icon` must be a square PNG of at least 512×512, otherwise the build fails. |
| `sceneGraph` | `false` (bundle `brs-scenegraph` when `true`) |
| `window` | `{ "width": 1280, "height": 720, "fullscreen": false, "resizable": true }` |
| `targets` | `["web", "<current os>"]` |
| `outDir` | `dist` |

### Runtime page (`template/index.html` + `runtime.js`)

- One `<canvas id="display">` scaled to fit the window with letterboxing, plus a hidden `<video id="player">` (brs-engine expects one).
- `brs.initialize(deviceInfo, { disableDebug: true, debugToConsole: false })`. `deviceInfo` is `{ assets }` (the page fetches `assets/common.zip` itself, see Spike results), plus `{ extensions: new Map([["brs-scenegraph", "./brs-sg.js"]]) }` when `sceneGraph` is on (the path is relative to the worker). Keyboard and gamepads stay on with brs-engine's default mapping.
- It fetches `game.zip` and calls `brs.execute("game.zip", buffer, { clearDisplayOnExit: false })`.
- It shows "Loading…" until the `started` event.
- `closed` event: on desktop, the window asks the main process to quit. On the web, it shows "Game ended" with a Restart button.
- `error` event: it shows the error message on screen instead of a blank canvas.
- `?debug=1` in the URL (or `BGE_STANDALONE_DEBUG=1` on desktop) turns on `debugToConsole` and `showStats`, for troubleshooting.

### Electron main process (`template/electron/main.js`)

- It registers a privileged `app://` protocol that serves files from `web/` and adds `Cross-Origin-Opener-Policy: same-origin` and `Cross-Origin-Embedder-Policy: require-corp` to every response. There's no localhost server and no open port.
- One `BrowserWindow` with the configured size and fullscreen setting, `contextIsolation: true` and no `nodeIntegration`. A small preload exposes only `quit()`.
- The menu bar is hidden, F11 toggles fullscreen, and DevTools only open with the debug env var.

## Error handling

- Missing or unreadable zip, or a zip without a `manifest`: exit 1 with the path and what was expected.
- Manifest without `multi_controllers=1`: a warning that analog sticks and the extra gamepad buttons will be off. The build continues.
- Asking for another OS's desktop target: exit 1 with "build mac targets on macOS (or use the CI matrix)".
- electron-builder failure: pass its output through and exit 1.
- At runtime, errors are shown on screen (see above). They never leave a blank window.

## Testing

- **Unit tests** (`node:test`, no new test framework) for `config.js`, `manifest.js`, `webBundle.js` (writes into a temp dir; checks the file list and the filled template) and `electronApp.js`.
- **End-to-end web check:** build `examples/pong`'s zip, run `bge-standalone build --target web`, serve `dist/web` with COOP/COEP, load it in headless Chromium (Playwright, a devDependency of the package only), wait for the `started` event and check the canvas has non-blank pixels after a few frames. The check runs in CI on Linux.
- **Manual desktop check** (documented, not automated): build the mac target, launch it, play pong with keyboard and a gamepad, check the analog stick and that the window quits when the game exits.
- `npm run check` for the engine is unchanged. The package gets its own `npm test` and a CI job.

## Risks / spike first

Before building the CLI, spend about a day hand-assembling a `dist/web` for `examples/pong` and one heavier example (`3d` or `terrain`), and check:

1. The engine starts under brs-engine in Chromium with **no** SceneGraph extension registered, even though the zip contains `components/Shapes`. If it doesn't, decide between stripping `components/` from the bundled zip when `sceneGraph` is off and an engine/brs-engine fix. `deviceRenderTier` and `DeviceQualitySeed` already branch on `HasFeature("simulation_engine")`; confirm those defaults look right.
2. Frame rate is acceptable.
3. Audio (`roAudioResource`/`roAudioPlayer`) plays. brs-engine supports only one `roAudioPlayer`.
4. Asset loading through `roUrlTransfer`/`roTextureManager` works from `pkg:`.
5. The game doesn't break if it calls `enableControllerInput()` (sockets are fake in the browser).

Engine bugs found here get their own issues or PRs and are fixed in the engine, not worked around in the packager.

## Spike results (2026-11-22)

brs-engine 2.6.2, headless Chromium (Playwright's headless shell) on macOS, hand-assembled bundle served by `lib/serve.js`, `?debug=1`. Gamepad and real window resizing need a person and were not checked.

**Runtime fix found first.** `brs.initialize()` starts its own `fetch("./assets/common.zip")` and returns without waiting for it. Calling `execute()` straight after ran the app with an empty `common:` volume: `[sound] Error unzipping audio files: invalid zip data`, `Error setting up file system: Start offset -22...`, `ENOENT ... common:/fonts/default-fonts.json`, then `EXIT_BRIGHTSCRIPT_CRASH`. `runtime.js` now fetches `assets/common.zip` itself and passes it as `deviceInfo.assets` (a documented `DeviceInfo` field), which skips the internal fetch. Side effect: brs-engine only loads closed-caption fonts on its own fetch path, so captions fonts aren't loaded. BGE games don't use captions. This is a brs-engine race, worth reporting upstream.

| # | Question | pong | 3d | controller |
| - | -------- | ---- | -- | ---------- |
| 1 | Starts with no SceneGraph extension (zip has `components/Shapes`) | Yes | Yes | Yes |
| 2 | Frame rate (frames copied to the display canvas over 5 s, idle) | ~52 fps (BGE's own log: 18-24 ms/frame) | ~40 fps idle, ~12-22 fps while the camera moves (example's own `avgMs=45`/`82`) | ~60 fps |
| 3 | Audio | No audio errors; 16 `AudioBufferSourceNode.start()` calls in 20 s of play, `AudioContext` running. Not listened to. | n/a | n/a |
| 4 | `pkg:` images and fonts | Yes (sprites, remote overlay image, fonts) | Yes (textured Roku logo plane) | Yes |
| 5 | Keyboard | Yes: arrows move the paddle, Enter works | Yes: arrows move the camera, OK toggles rotation | Yes: Enter fired (`fire! (fire1)`) |
| 5 | Gamepad / analog stick | Not checked, needs a person | | |
| 6 | `enableControllerInput()` | | | Starts, no crash: `failed to listen on port 8888 - controller input is disabled this run`; the QR code isn't shown |
| 7 | Letterboxing | Yes at 900x900 (bars top/bottom) and 1600x600 (bars left/right) | same page | same page |

Stripping `components/` isn't needed. Quality starts at `Medium` (pong) / `Medium (auto)` (3d) under `simulation_engine`.

**brs-engine bug that shows in games:** `roRegion.Clear(0)` on an alpha-enabled bitmap leaves the old pixels (`roBitmap.Clear(0)` works). `DrawableText` reuses its bitmap and clears it through a region, so changing text draws over the old text: the FPS debug label is unreadable and pong's score shows the old digit under the new one. 20-line repro: draw a white rect into an `AlphaEnable` bitmap, `CreateObject("roRegion", bmp, 0, 0, w, h).Clear(0)`, draw the region; the white rect still shows. This needs an upstream brs-engine fix. Changing the engine to clear the bitmap instead would be a BGE workaround, so it's left out of the packager.

Timings are from headless Chromium with software rendering and may be lower than desktop Chrome or Electron. Check fps again in the manual desktop check.

## Docs

- `docs/standalone-builds.md` (Guides): install, config fields, targets, hosting the web build with COOP/COEP (including itch.io's SharedArrayBuffer option), unsigned-build warnings, gamepad notes.
- `packages/standalone/README.md`: the npm-facing summary.

## Follow-ups (separate issues)

- Publishing `bge-standalone`: wire it into the Initialize/Publish Release workflows (see `.claude/rules/releasing.md`). v1 is not published by hand.

- Mobile builds (Capacitor or similar) with a nipple.js touch overlay.
- Code signing and notarization in CI.
- A GitHub Action or reusable workflow that builds all three OSes for a consuming game.
