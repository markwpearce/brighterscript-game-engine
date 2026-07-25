# Changelog

All notable changes to this project are documented here, following [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) conventions. This project uses [Semantic Versioning](https://semver.org/).

## [0.6.0] - 2026-07-24

### Added

- Central logging: `Game.log(message, level)` / `Game.getLogHistory()`, with a `BGE.Debug.LogLevel` enum (`info`/`warning`/`error`). Existing `print`-only warnings across `Game.bs`/`GameEntity.bs`/`Sprite.bs` now route through it, and previously-silent lookups (`getBitmap`, `get3dModel`, `getFont`, `getDrawable`, `getEntityByID`, `getEntityByName`, `getCollider`) now warn on a miss instead of returning `invalid` with no trace.
- `BGE.Debug.LogDisplay`, a new debug window: bottom-center, auto-scrolling to the latest entries, colored white/yellow/red by level. Wired into all examples alongside the existing `FpsDisplay`/`InputDisplay`/`MemoryDisplay`/`GarbageCollectorDisplay`.
- `DrawableText.textColor` field, enabling per-line text coloring (used by `LogDisplay`).
- A Rooibos (v6) unit test suite, colocated as `*.spec.bs` files, runnable headlessly in CI via `brs-cli` or on-device.
- `examples/breakout`.

### Fixed

- **`ropm install` now actually works for consumers.** Publishing raw `.bs` source (rather than the already-compiled `build/` output) produced ~1640 compile errors for any real consumer - see the [README's Installation section](README.md#installation) for the recommended `ropm.noprefix` + `roku_modules` `diagnosticFilters` consumer setup.
- `examples/hybrid`'s broken build (stale `getImage` call) and `examples/pixels`' room-navigation graph (two rooms were unreachable).
- `BGE.Colors`/`BGE.ColorsRGB` changed to enums.

### Changed

- Docs site (`docs-site/`) is now built and deployed via GitHub Actions on every push to `main`, rather than committing generated output.
- Hand-written guides (`docs/`) folded into the same sidebar as the API reference, instead of a bolted-on menu.

## [0.5.0] - 2026-07-16

### Added

- Renderer overhaul: `SceneObject`s for images, billboards, lines, polygons, text, and 3D models, with configurable draw modes (`matchCamera`, `directToCamera`, `oriented`, `wireframe`, `solid`, and back-face variants).
- Billboard shading and wireframe drawing for models and billboards.
- Triangle bitmap caching and other rendering performance improvements.
- `npm run create-example -- <name> ["Title"]` scaffolds a new example (manifest, bsconfig, generated icon/splash images, minimal `MainRoom`).
- `examples/quickstart`, matching the README's sample code.
- `validate`/`lint` required status checks on PRs to `main`; automated docs regeneration.

### Changed

- UI moved to its own dedicated canvas/layer, with `Drawable`s refactored accordingly.
- README rewrite: engine + standalone drawing-library pitch, runnable quick-start code sample, examples table, screenshots.
- Example tooling (`prepare-examples`, `build-examples`, `validate-examples`, `clean-all`, `create-example`) rewritten in plain Node, so it works on Windows without Git Bash/WSL.

[0.6.0]: https://github.com/markwpearce/brighterscript-game-engine/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/markwpearce/brighterscript-game-engine/compare/1.1...v0.5.0
