---
title: Standalone Builds
group: Guides
order: 19
---

# Standalone Builds

Ship your game as a web page or a desktop app (macOS, Windows, Linux) that runs
without a Roku. The `bge-standalone` package wraps your built channel zip with
[brs-engine](https://github.com/lvcabral/brs-engine), a BrightScript engine that
runs in browsers and Electron.

## Install

    npm install --save-dev bge-standalone

## Build

Build your channel zip as usual (for example `roku-deploy zip`), then:

    npx bge-standalone build --zip out/my-game.zip

Options: `--target web|mac|win|linux|all`, `--config <file>`, `--zip <path>`, `--out <dir>`.

Output goes under `dist/` (or your `--out` / `outDir`):

- `web/` - the static web build.
- `electron-app/` - the generated Electron app the installer is built from.
- `desktop/` - the installer for your OS: a `.dmg` on macOS, an NSIS installer on
  Windows, an AppImage on Linux. It is built for your machine's CPU architecture.

By default `build` makes `web` plus your own OS. `--target all` means the same thing.
Desktop installers can only be built on their own OS; use a CI matrix (one job per OS)
to build all three.

Try the web build locally:

    npx bge-standalone serve

This serves `dist/web` at http://127.0.0.1:6502/. Pass a folder to serve another build
(`serve <dir>`, which needs an `index.html` at its root) and `--port` to change the port.

## Config

All fields in `bge-standalone.json` (in the folder you run the command from) are optional,
except that the zip path must come from `zip` or `--zip`:

| Field | Default | |
| --- | --- | --- |
| `zip` | none | Path to the built channel zip (or pass `--zip`). Required. |
| `productName` | manifest `title` | App and window name. |
| `appId` | `com.bge.<title>` | Reverse-DNS app id (title lowercased, non-alphanumerics become `-`). |
| `version` | manifest `major.minor.build` | Must be `x.y.z`. |
| `icon` | manifest `mm_icon_focus_hd` | Square PNG, at least 512×512, or the build fails. Without it, a square 512+ manifest icon is used as-is. Otherwise the manifest icon is letterboxed to 512×512 with transparent bars, and the build warns. |
| `sceneGraph` | `false` | Bundle SceneGraph support (`npm install --save-dev brs-scenegraph`). Only needed if your game uses SceneGraph nodes. |
| `window` | `{ "width": 1280, "height": 720, "fullscreen": false, "resizable": true }` | Desktop window. F11 toggles fullscreen. |
| `targets` | `["web", "<your OS>"]` | Any of `web`, `mac`, `win`, `linux`. |
| `outDir` | `dist` | Output folder. |

## Keyboard and gamepads

Keyboard: arrow keys, Enter is OK, Esc is Back, Backspace is Replay, End is Play/Pause.

brs-engine maps a connected gamepad to the remote: A is OK, B is Back, and the
d-pad and sticks are the arrows. Add `multi_controllers=1` to your manifest to
get X/Y/L1/R1/L2/R2 and real analog sticks, which `game.controls` reads automatically
(the build warns if it's missing). See [Controller Input](/controller-input).
Chrome only detects a gamepad after you press a button with the page focused.

## Hosting the web build

brs-engine needs `SharedArrayBuffer`, so the page must be served with these headers:

    Cross-Origin-Opener-Policy: same-origin
    Cross-Origin-Embedder-Policy: require-corp

`bge-standalone serve` sends them for you. On itch.io, upload the contents of `dist/web`
as a zip, set it to "This file will be played in the browser" and turn on
"SharedArrayBuffer support". Opening `index.html` directly from disk does not work.

## Unsigned apps

Desktop builds are not code-signed. On macOS, right-click the app and choose
Open the first time. On Windows, choose More info, then Run anyway, on the SmartScreen prompt.

## When the game exits

The page shows `Loading…` while the game starts. If the game ends normally (for
example it calls `game.End()` or the player presses Back), the web page shows `Game ended`
with a Restart button and the desktop app quits. Any other exit reason shows
`Game crashed (<reason>)` on screen with a Restart button, and the desktop window stays open.

## Troubleshooting

Add `?debug=1` to the web URL, or set `BGE_STANDALONE_DEBUG=1` before launching the
desktop app, to see `print` output and engine errors in the console, a frame-rate
overlay, and (on desktop) DevTools.

If you run the generated `electron-app/` directly with `npx electron` and Electron has no
binary, npm 11 may have skipped its install script. Run
`node node_modules/electron/install.js`. Behind a corporate proxy, Node's `fetch` ignores
proxy environment variables unless `NODE_USE_ENV_PROXY=1` is set.
This applies to Electron's install script and to the downloads `electron-builder` does when packaging.

## Known issues

- Changing text can draw over its old value, because of a brs-engine bug in
  `roRegion.Clear` ([brs-engine#1337](https://github.com/lvcabral/brs-engine/issues/1337)).
- `enableControllerInput()` (the phone controller page) is disabled in standalone builds.
  It logs that and the game keeps running.
- SceneGraph support in brs-engine is beta. In `examples/scenegraph` one shape renders wrong.
