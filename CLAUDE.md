# CLAUDE.md

Object-oriented Roku game engine in [BrighterScript](https://github.com/rokucommunity/brighterscript), shipped via ROPM. Engine source: `src/source/` (namespace `BGE`). `examples/` are sample channels consuming it via ROPM (the end-to-end check). Unit tests: colocated Rooibos `*.spec.bs`.

Topic rules live in `.claude/rules/` and load when you touch matching files. Before changing a subsystem, read its guide in `docs/` or spec in `specs/`.

## Commands (repo root)

- `npm run check` — lint, validate, headless tests. **Always run after engine changes.**
- `npm run check:all` — `check` + validate every example.
- `npm run validate` / `lint` / `build` / `clean`.
- `npm run test:ci` — headless tests in shards (`scripts/run-tests-sharded.js`); add a shard past ~1000 tests. `npm run test:device` uses `ROKU_HOST`/`ROKU_PASSWORD`.
- `scripts/*.js` are plain Node (must run on Windows).
- Run/drive an example on a Roku: the `rokubot-examples` skill.

## Conventions

- No single-line `if` (bslint `inline-if-style: never`).
- **Always `import` files whose symbols you use** — SceneGraph component scopes aren't ambient (`cannot-find-name`).
- **Real types**, not `as object`/`as dynamic`: classes, `interface X extends roAssociativeArray`, native types, typed casts. Options bags are interfaces with `optional` fields (iterate `.Keys()`). `sub(...)` callback types need `as void`. No `invalid` in unions — use `as dynamic`. Cast computed integers to enums.
- **`=` between two objects crashes at runtime** (Type Mismatch; bsc misses it, casts don't help). Compare an id/scalar.
- **bsc self-reference bug**: a namespace function returning, or method param typed as, a class from the same file can corrupt types in that file. Move it to another file or type the param `as object`.
- Doc comments (`'` JSDoc, `@param`/`@return`) are for consumers; rationale goes in short inline comments.
- Releasing: never by hand — see `.claude/rules/releasing.md`.
