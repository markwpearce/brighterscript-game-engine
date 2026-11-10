---
paths:
  - "docs/**"
  - "specs/**"
  - "jsdoc.json"
  - ".github/workflows/docs.yml"
---

# Docs site

- `docs-site/` is generated and gitignored; `docs.yml` deploys it to GitHub Pages on every push to `main` (`https://markwpearce.github.io/brighterscript-game-engine/`). `npm run docs` / `npm run docs-server` (serves under `/brighterscript-game-engine`).
- **Every markdown file under `docs/` is published** (`opts.docs`, recursive). Internal designs/plans go in `specs/`.
- Guides need frontmatter (`title`, `group: Guides`, `order`). Cross-link with root-relative slugs (`[Engine Internals](/engine-internals)`); literal `opts.menu` links in `jsdoc.json` need the `/brighterscript-game-engine` prefix by hand.
- No Mermaid — diagrams are SVG/PNG in `docs/images/`.
