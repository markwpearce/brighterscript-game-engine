---
paths:
  - "examples/rendererTest/**"
---

# examples/rendererTest

Menu of `BGE.Renderer` demos built without `Game`/`GameScene`; it times every demo.

- Add a demo: subclass `RendererTest` under `Tests/`, add one entry to `DemoList.bs`.
- Launch one directly with `--param demo=<id>`.
- Its loop uses `port.GetMessage()` — `wait(0, port)` waits forever.
