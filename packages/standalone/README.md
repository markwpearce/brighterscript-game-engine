# bge-standalone

Turns a built [BrighterScript Game Engine](https://github.com/markwpearce/brighterscript-game-engine)
Roku channel zip into a static web build and desktop apps (macOS, Windows, Linux) that run
without a Roku, using [brs-engine](https://github.com/lvcabral/brs-engine) and Electron.

## Install

    npm install --save-dev bge-standalone

## Build

    npx bge-standalone build --zip out/my-game.zip [--target web|mac|win|linux|all] [--config file] [--out dir]

Writes `dist/web`, `dist/electron-app` and `dist/desktop`. Desktop installers are unsigned and
can only be built on their own OS.

## Serve

    npx bge-standalone serve [dir] [--port 6502]

## Config

Optional `bge-standalone.json` in the folder you run from:

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

Full guide: https://markwpearce.github.io/brighterscript-game-engine/standalone-builds

Tested with brighterscript-game-engine 0.8.0, brs-engine 2.7.0 and Electron 45.3.2.
