---
paths:
  - "examples/**"
  - "scripts/examples.js"
  - "scripts/run-example.js"
  - "scripts/create-*.js"
  - "scripts/exampleTemplate/**"
  - ".vscode/settings.json"
---

# Examples

- Fan-out scripts (`scripts/examples.js`): `prepare-examples`, `build-examples` (zips to `examples/<name>/out/`), `validate-examples`, `clean-all`.
- `npm run run-example -- <name> [key=value ...]` builds the engine, sideloads one example and launches it with deep-link params. Or `cd examples/<name>` and use its own scripts (`rpg`, `visualnovel` have their own `npm test`, not in CI).
- Scaffold: `npm run create-example -- <name> ["Title"]`, `create-entity -- <example> <Entity>`, `create-scene -- <example> <Scene>` (then wire `defineScene`/`changeScene` by hand).
- **`check`/`validate-examples` don't run example code** — verify changes with an actual on-device/simulator run (`rokubot-examples` skill).
- Keep UI title-safe: ≥10% from every canvas edge.
- Package paths are case-insensitive: no `source/story` folder (collides with the engine's).
- Keep `brightscript.projects` in `.vscode/settings.json` to ≤10 entries (language server runs out of heap); always keep the root `bsconfig.json`.
- An example may have its own `CLAUDE.md` or rule file for example-specific notes; keep engine-wide facts here.
- Images over ~100 KB: WebP (lossy q90 with lossless alpha; lossless for pixel art), JPG for manifest splash/icons. Asset scripts write WebP via `scripts/webp.js`.
