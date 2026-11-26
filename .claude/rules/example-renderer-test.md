---
paths:
  - "examples/rendererTest/**"
---

# examples/rendererTest

Menu of `BGE.Renderer` demos built without `Game`/`GameScene`; it times every demo.

- Add a demo: subclass `RendererTest` under `Tests/`, add one entry to a group in `DemoList.bs` (the menu shows groups in that order; don't add a second group with an existing title).
- Launch one directly with `--param demo=<id>`.
- Its loop uses `port.GetMessage()` — `wait(0, port)` waits forever.
