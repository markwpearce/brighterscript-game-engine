---
paths:
  - "CHANGELOG.md"
  - "scripts/release-*.js"
  - "package.json"
  - ".github/workflows/**"
---

# Releasing

Never by hand. Run the **Initialize Release** workflow (patch/minor/major): it bumps the version, drafts CHANGELOG's `[Unreleased]` from merged PRs, and opens a `release/x.y.z` PR. Edit the notes there and merge promptly; merging runs **Publish Release** (tag, `npm publish` via OIDC trusted publishing, GitHub release). Publish Release is re-runnable after partial failure.
