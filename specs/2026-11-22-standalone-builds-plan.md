# Standalone Web and Desktop Builds Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A companion npm package, `bge-standalone`, that turns any BGE game's built channel zip into a static web build and an Electron desktop app (mac/win/linux), both running on brs-engine.

**Architecture:** Plain-Node CLI in `packages/standalone/`. `build` reads the zip's manifest and resolves config, writes `dist/web/` (a runtime page plus the brs-engine libs and the game zip), and for desktop targets wraps that folder in a generated Electron app that serves it over a privileged `app://` protocol with COOP/COEP headers, then runs electron-builder. Gamepads use brs-engine's native mapping. SceneGraph (`brs-scenegraph`) is opt-in.

**Tech Stack:** Node 24 (CommonJS, `node:test`), brs-engine 2.6.x, brs-scenegraph 0.6.x (optional peer), jszip, Electron, electron-builder, Playwright (dev only, e2e).

**Spec:** `specs/2026-11-22-standalone-builds-design.md`

## Global Constraints

- The package lives in `packages/standalone/` and is a separate npm package (`bge-standalone`). Nothing is added to the root `package.json` `dependencies`/`devDependencies`, and root `files` stays `build/**`.
- Plain Node, CommonJS, no build step. It must run on Windows: use `path.join`/`path.resolve`, never hard-coded `/`, and no shell-specific npm scripts inside `packages/standalone`.
- Tests use `node:test` + `node:assert/strict`. No new test framework.
- Bundle layout must be exactly `index.html`, `runtime.js`, `game.zip`, `lib/brs.api.js`, `lib/brs.worker.js`, `assets/common.zip` (+ `lib/brs-sg.js` when `sceneGraph`). brs.api.js finds its worker next to its own URL and fetches `./assets/common.zip` relative to the page.
- Every served response (web `serve` and Electron `app://`) carries `Cross-Origin-Opener-Policy: same-origin`, `Cross-Origin-Embedder-Policy: require-corp` and `Cross-Origin-Resource-Policy: same-origin`.
- SceneGraph is off unless `"sceneGraph": true`. `brs-scenegraph` is an optional peer dependency.
- Electron windows: `contextIsolation: true`, `nodeIntegration: false`, `sandbox: true`. The preload exposes only `window.bgeHost.quit()`.
- Builds are unsigned. No cross-compiling: a desktop target other than the host OS fails.
- Do not publish the package and do not touch release workflows (follow-up).
- Engine bugs found along the way get their own issues. Don't work around them in the packager.
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## File Structure

```
packages/standalone/
├── package.json             name bge-standalone, bin, deps, scripts
├── README.md                npm-facing summary (Task 10)
├── .gitignore               node_modules, dist, test-output
├── bin/bge-standalone.js    calls lib/cli.main
├── lib/
│   ├── serve.js             COOP/COEP static server (Task 1)
│   ├── manifest.js          parse manifest, read zip, gameInfo (Task 3)
│   ├── icon.js              PNG size check (Task 3)
│   ├── config.js            load + resolve + validate config, targets (Task 4)
│   ├── webBundle.js         write dist/web (Task 5, SceneGraph in Task 9)
│   ├── electronApp.js       write dist/electron-app (Task 7)
│   ├── desktopBuild.js      electron-builder call (Task 8)
│   └── cli.js               build / serve commands (Task 6, desktop in Task 8)
├── template/
│   ├── web/index.html       runtime page (Task 2)
│   ├── web/runtime.js       brs init/execute/events (Task 2)
│   └── electron/main.js, preload.js (Task 7)
└── test/
    ├── helpers.js           makeGameZip(), tmpDir()
    ├── *.test.js            unit tests
    └── e2e/web.e2e.js       Playwright check (Task 6b)
docs/standalone-builds.md    guide (Task 10)
.github/workflows/standalone.yml  (Task 6b)
```

---

### Task 1: Package scaffold and COOP/COEP server

**Files:**
- Create: `packages/standalone/package.json`, `packages/standalone/.gitignore`, `packages/standalone/lib/serve.js`, `packages/standalone/test/helpers.js`, `packages/standalone/test/serve.test.js`

**Interfaces:**
- Produces: `createServer(root: string): http.Server`, `serve(root: string, port: number): Promise<http.Server>` (listens on 127.0.0.1; port 0 = random). `test/helpers.js`: `tmpDir(): string`, `makeGameZip(manifestText: string, extraFiles?: Record<string, Buffer|string>): Promise<Buffer>`.

- [ ] **Step 1: Scaffold the package**

`packages/standalone/package.json`:

```json
{
    "name": "bge-standalone",
    "version": "0.1.0",
    "description": "Build standalone web and desktop (Electron) versions of brighterscript-game-engine games, powered by brs-engine.",
    "license": "MIT",
    "author": "Mark Pearce",
    "repository": {
        "type": "git",
        "url": "git+https://github.com/markwpearce/brighterscript-game-engine.git",
        "directory": "packages/standalone"
    },
    "bin": {
        "bge-standalone": "bin/bge-standalone.js"
    },
    "files": ["bin/", "lib/", "template/", "README.md"],
    "engines": {
        "node": ">=20"
    },
    "scripts": {
        "test": "node --test test/",
        "test:e2e": "node --test test/e2e/"
    },
    "dependencies": {
        "brs-engine": "~2.6.2",
        "electron": "^45.3.2",
        "electron-builder": "^26.0.0",
        "jszip": "^3.10.2"
    },
    "peerDependencies": {
        "brs-scenegraph": "~0.6.2"
    },
    "peerDependenciesMeta": {
        "brs-scenegraph": { "optional": true }
    },
    "devDependencies": {
        "brs-scenegraph": "~0.6.2",
        "playwright": "^1.65.1"
    }
}
```

`node --test test/` runs `test/**/*.test.js` but not `test/e2e/web.e2e.js` (the name doesn't match `*.test.js`). If the Node version in use picks it up anyway, change `test` to `node --test test/*.test.js`.

`packages/standalone/.gitignore`:

```
node_modules/
dist/
test-output/
```

Run: `cd packages/standalone && npm install`
Expected: installs cleanly and creates `package-lock.json` (commit it).

- [ ] **Step 2: Write test helpers**

`packages/standalone/test/helpers.js`:

```js
'use strict';
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const JSZip = require('jszip');

function tmpDir() {
    return fs.mkdtempSync(path.join(os.tmpdir(), 'bge-standalone-'));
}

// A minimal 1x1 PNG header is enough for size checks; width/height are big-endian at bytes 16..23.
function fakePng(width, height) {
    const buf = Buffer.alloc(33);
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]).copy(buf, 0);
    buf.writeUInt32BE(13, 8);
    buf.write('IHDR', 12, 'ascii');
    buf.writeUInt32BE(width, 16);
    buf.writeUInt32BE(height, 20);
    return buf;
}

async function makeGameZip(manifestText, extraFiles = {}) {
    const zip = new JSZip();
    if (manifestText !== null) {
        zip.file('manifest', manifestText);
    }
    zip.file('source/main.brs', 'sub main()\nend sub\n');
    for (const [name, data] of Object.entries(extraFiles)) {
        zip.file(name, data);
    }
    return zip.generateAsync({ type: 'nodebuffer' });
}

module.exports = { tmpDir, fakePng, makeGameZip };
```

- [ ] **Step 3: Write the failing serve test**

`packages/standalone/test/serve.test.js`:

```js
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { serve } = require('../lib/serve');
const { tmpDir } = require('./helpers');

async function withServer(root, fn) {
    const server = await serve(root, 0);
    try {
        await fn(`http://127.0.0.1:${server.address().port}`);
    } finally {
        server.close();
    }
}

test('serves files with COOP/COEP/CORP headers and content types', async () => {
    const root = tmpDir();
    fs.writeFileSync(path.join(root, 'index.html'), '<p>hi</p>');
    fs.mkdirSync(path.join(root, 'lib'));
    fs.writeFileSync(path.join(root, 'lib', 'a.js'), 'x');
    await withServer(root, async (base) => {
        const res = await fetch(`${base}/`);
        assert.equal(res.status, 200);
        assert.equal(await res.text(), '<p>hi</p>');
        assert.equal(res.headers.get('cross-origin-opener-policy'), 'same-origin');
        assert.equal(res.headers.get('cross-origin-embedder-policy'), 'require-corp');
        assert.equal(res.headers.get('cross-origin-resource-policy'), 'same-origin');
        assert.match(res.headers.get('content-type'), /text\/html/);
        const js = await fetch(`${base}/lib/a.js?v=1`);
        assert.equal(js.status, 200);
        assert.match(js.headers.get('content-type'), /javascript/);
    });
});

test('404s missing files and refuses paths outside the root', async () => {
    const root = tmpDir();
    await withServer(root, async (base) => {
        assert.equal((await fetch(`${base}/nope.js`)).status, 404);
        assert.equal((await fetch(`${base}/..%2f..%2fetc%2fpasswd`)).status, 403);
    });
});
```

- [ ] **Step 4: Run it to make sure it fails**

Run: `cd packages/standalone && npm test`
Expected: FAIL, `Cannot find module '../lib/serve'`.

- [ ] **Step 5: Implement `lib/serve.js`**

```js
'use strict';
const fs = require('node:fs');
const http = require('node:http');
const path = require('node:path');

const CONTENT_TYPES = {
    '.html': 'text/html; charset=utf-8',
    '.js': 'text/javascript; charset=utf-8',
    '.json': 'application/json',
    '.zip': 'application/zip',
    '.png': 'image/png',
    '.wasm': 'application/wasm'
};

// brs-engine needs SharedArrayBuffer, which needs cross-origin isolation.
const ISOLATION_HEADERS = {
    'Cross-Origin-Opener-Policy': 'same-origin',
    'Cross-Origin-Embedder-Policy': 'require-corp',
    'Cross-Origin-Resource-Policy': 'same-origin'
};

function createServer(root) {
    const base = path.resolve(root);
    return http.createServer((req, res) => {
        const url = new URL(req.url, 'http://localhost');
        const rel = decodeURIComponent(url.pathname).replace(/^\/+/, '') || 'index.html';
        const file = path.resolve(base, rel);
        if (file !== base && !file.startsWith(base + path.sep)) {
            res.writeHead(403, ISOLATION_HEADERS);
            res.end('Forbidden');
            return;
        }
        fs.readFile(file, (err, data) => {
            if (err) {
                res.writeHead(404, ISOLATION_HEADERS);
                res.end('Not found');
                return;
            }
            const type = CONTENT_TYPES[path.extname(file).toLowerCase()] || 'application/octet-stream';
            res.writeHead(200, { ...ISOLATION_HEADERS, 'Content-Type': type });
            res.end(data);
        });
    });
}

function serve(root, port) {
    return new Promise((resolve, reject) => {
        const server = createServer(root);
        server.once('error', reject);
        server.listen(port, '127.0.0.1', () => resolve(server));
    });
}

module.exports = { createServer, serve, ISOLATION_HEADERS };
```

- [ ] **Step 6: Run the tests and make sure they pass**

Run: `cd packages/standalone && npm test`
Expected: 2 tests pass.

- [ ] **Step 7: Commit**

```bash
git add packages/standalone
git commit -m "bge-standalone: package scaffold and COOP/COEP static server (#235)"
```

---

### Task 2: Runtime page and spike (gate for everything after)

This is the spike from the spec's "Risks" section. It writes the real runtime template, then hand-assembles a web bundle for `examples/pong` and a heavier example, and records what works. **If the engine does not start under brs-engine, stop and report back before Task 3.**

**Files:**
- Create: `packages/standalone/template/web/index.html`, `packages/standalone/template/web/runtime.js`
- Modify: `specs/2026-11-22-standalone-builds-design.md` (add a "Spike results" section)

**Interfaces:**
- Produces: the template placeholders `{{TITLE}}` (HTML-escaped title) and `{{SETTINGS_JSON}}` (JSON `{"sceneGraph": boolean}`) in `index.html`. Page globals the e2e test relies on: `window.__bgeStarted` (true after the brs `started` event), `window.__bgeError` (string after an `error` event). It optionally calls `window.bgeHost.quit()` (provided by the Electron preload).

- [ ] **Step 1: Write `template/web/index.html`**

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8" />
    <title>{{TITLE}}</title>
    <link rel="icon" href="data:;base64,iVBORw0KGgo=" />
    <style>
        html, body { margin: 0; height: 100%; background: #000; overflow: hidden; }
        #display { display: block; width: 100vw; height: 100vh; object-fit: contain; image-rendering: auto; }
        #status {
            position: fixed; inset: 0; display: flex; flex-direction: column; gap: 1em;
            align-items: center; justify-content: center; color: #ddd; font: 20px sans-serif; text-align: center;
        }
        #status[hidden] { display: none; }
        #restart { font: inherit; padding: 0.4em 1.2em; }
    </style>
</head>
<body>
    <canvas id="display" width="1280" height="720"></canvas>
    <video id="player" style="display: none" crossorigin="anonymous"></video>
    <div id="status"><span id="status-text">Loading…</span><button id="restart" hidden>Restart</button></div>
    <script id="bge-settings" type="application/json">{{SETTINGS_JSON}}</script>
    <script src="lib/brs.api.js"></script>
    <script src="runtime.js"></script>
</body>
</html>
```

- [ ] **Step 2: Write `template/web/runtime.js`**

```js
(function () {
    'use strict';
    const settings = JSON.parse(document.getElementById('bge-settings').textContent);
    const debug = new URLSearchParams(location.search).get('debug') === '1';
    const status = document.getElementById('status');
    const statusText = document.getElementById('status-text');
    const restart = document.getElementById('restart');

    function showStatus(text, canRestart) {
        statusText.textContent = text;
        restart.hidden = !canRestart;
        status.hidden = false;
    }

    brs.subscribe('bge-standalone', function (event, data) {
        if (event === 'started') {
            status.hidden = true;
            window.__bgeStarted = true;
        } else if (event === 'closed') {
            if (window.bgeHost) {
                window.bgeHost.quit();
            } else {
                showStatus('Game ended', true);
            }
        } else if (event === 'error') {
            window.__bgeError = String(data);
            showStatus('Error: ' + data, true);
        }
    });

    async function start() {
        showStatus('Loading…', false);
        const res = await fetch('game.zip');
        if (!res.ok) {
            throw new Error('could not load game.zip (HTTP ' + res.status + ')');
        }
        brs.execute('game.zip', await res.arrayBuffer(), { clearDisplayOnExit: false });
    }

    async function main() {
        const deviceInfo = {};
        if (settings.sceneGraph) {
            // Path is relative to brs.worker.js.
            deviceInfo.extensions = new Map([['brs-scenegraph', './brs-sg.js']]);
        }
        await brs.initialize(deviceInfo, { disableDebug: !debug, debugToConsole: debug, showStats: debug });
        await start();
    }

    restart.addEventListener('click', function () {
        start().catch(function (e) {
            showStatus('Error: ' + e.message, true);
        });
    });
    main().catch(function (e) {
        window.__bgeError = e.message;
        showStatus('Error: ' + e.message, true);
    });
})();
```

- [ ] **Step 3: Build pong and a heavier example**

Run from the repo root:

```bash
npm run prepare-examples
(cd examples/pong && npm run package)
(cd examples/3d && npm run package)
```

Expected: `examples/pong/out/bge-pong.zip` and `examples/3d/out/bge-3d.zip` exist.

- [ ] **Step 4: Hand-assemble the bundle and serve it**

```bash
B=packages/standalone/spike-web
mkdir -p $B/lib $B/assets
cp packages/standalone/node_modules/brs-engine/lib/brs.api.js packages/standalone/node_modules/brs-engine/lib/brs.worker.js $B/lib/
cp packages/standalone/node_modules/brs-engine/assets/common.zip $B/assets/
cp packages/standalone/template/web/runtime.js $B/
sed -e 's/{{TITLE}}/Spike/' -e 's/{{SETTINGS_JSON}}/{"sceneGraph":false}/' packages/standalone/template/web/index.html > $B/index.html
cp examples/pong/out/bge-pong.zip $B/game.zip
node -e "require('./packages/standalone/lib/serve').serve('$B', 6502).then(() => console.log('http://127.0.0.1:6502/?debug=1'))"
```

Open `http://127.0.0.1:6502/?debug=1` in Chrome with DevTools open (or drive it with Playwright).

- [ ] **Step 5: Check and record each spike question**

Repeat with `bge-3d.zip` as `game.zip`. For each, write down yes/no and notes:

1. Does it start with no SceneGraph extension registered, even though the zip contains `components/Shapes`? (Console shows `started`; frames render.) If not, try deleting `components/` from a copy of the zip and record whether that fixes it.
2. Does the stats overlay show an acceptable frame rate (pong ≈ 60 fps; 3d note the number)?
3. Does audio play (pong has sound effects)?
4. Do images/fonts from `pkg:` load?
5. Do keyboard arrows/Enter work, and does a connected gamepad move the paddle (analog stick too, because of `multi_controllers=1`)?
6. Does `examples/controller` (calls `enableControllerInput()`) start without crashing? Build it like Step 3.
7. Does the canvas scale to the window with letterboxing (resize the window)?

Add a `## Spike results (2026-11-22)` section to the spec with the answers. Open a GitHub issue for each engine-side problem (`gh issue create`). If question 1 fails and stripping `components/` fixes it, add a `stripComponents` step to Task 5 (remove `components/` entries from `game.zip` when `sceneGraph` is false) and note it in the spec.

- [ ] **Step 6: Clean up and commit**

```bash
rm -rf packages/standalone/spike-web
git add packages/standalone/template specs/2026-11-22-standalone-builds-design.md
git commit -m "bge-standalone: runtime page and brs-engine spike results (#235)"
```

---

### Task 3: Manifest and icon reading

**Files:**
- Create: `packages/standalone/lib/manifest.js`, `packages/standalone/lib/icon.js`, `packages/standalone/test/manifest.test.js`, `packages/standalone/test/icon.test.js`

**Interfaces:**
- Produces:
  - `parseManifest(text: string): Record<string,string>`
  - `readGameZip(zip: Buffer): Promise<{ manifest: Record<string,string>, icon: { name: string, data: Buffer } | null }>`, which throws `Error('zip has no manifest at its root')`
  - `gameInfo(manifest): { title: string, version: string, multiControllers: boolean }`
  - `pngSize(buf: Buffer): { width: number, height: number } | null`
  - `isUsableIcon(buf: Buffer): boolean` (PNG, both sides ≥ 512)

- [ ] **Step 1: Write the failing tests**

`packages/standalone/test/manifest.test.js`:

```js
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { parseManifest, readGameZip, gameInfo } = require('../lib/manifest');
const { makeGameZip, fakePng } = require('./helpers');

const MANIFEST = [
    '#Channel Details',
    'title=Example Game - Pong',
    'major_version=1',
    'minor_version=2',
    'build_version=3',
    '',
    'mm_icon_focus_hd=pkg:/images/Channel_Icon_HD.png',
    'multi_controllers=1',
    'bad line without equals',
    'ui_resolutions = HD '
].join('\r\n');

test('parseManifest reads key=value lines, skips comments/blank/invalid, trims', () => {
    const m = parseManifest(MANIFEST);
    assert.equal(m.title, 'Example Game - Pong');
    assert.equal(m.ui_resolutions, 'HD');
    assert.equal(m.multi_controllers, '1');
    assert.equal(Object.keys(m).length, 7);
});

test('parseManifest keeps "=" inside values', () => {
    assert.equal(parseManifest('title=a=b').title, 'a=b');
});

test('readGameZip returns the manifest and the HD icon bytes', async () => {
    const png = fakePng(336, 210);
    const zip = await makeGameZip(MANIFEST, { 'images/Channel_Icon_HD.png': png });
    const game = await readGameZip(zip);
    assert.equal(game.manifest.title, 'Example Game - Pong');
    assert.equal(game.icon.name, 'Channel_Icon_HD.png');
    assert.deepEqual(game.icon.data, png);
});

test('readGameZip icon is null when the file is missing or not a pkg: path', async () => {
    assert.equal((await readGameZip(await makeGameZip(MANIFEST))).icon, null);
    assert.equal((await readGameZip(await makeGameZip('title=x\nmm_icon_focus_hd=http://x/y.png'))).icon, null);
});

test('readGameZip throws when there is no manifest', async () => {
    await assert.rejects(readGameZip(await makeGameZip(null)), /zip has no manifest at its root/);
});

test('gameInfo derives title, semver version and multiControllers', () => {
    assert.deepEqual(gameInfo(parseManifest(MANIFEST)), { title: 'Example Game - Pong', version: '1.2.3', multiControllers: true });
    assert.deepEqual(gameInfo({}), { title: 'BGE Game', version: '0.0.0', multiControllers: false });
});
```

`packages/standalone/test/icon.test.js`:

```js
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { pngSize, isUsableIcon } = require('../lib/icon');
const { fakePng } = require('./helpers');

test('pngSize reads IHDR width/height', () => {
    assert.deepEqual(pngSize(fakePng(336, 210)), { width: 336, height: 210 });
});

test('pngSize returns null for non-PNG or short data', () => {
    assert.equal(pngSize(Buffer.from('GIF89a................')), null);
    assert.equal(pngSize(Buffer.alloc(4)), null);
});

test('isUsableIcon needs a PNG of at least 512x512', () => {
    assert.equal(isUsableIcon(fakePng(512, 512)), true);
    assert.equal(isUsableIcon(fakePng(1024, 512)), true);
    assert.equal(isUsableIcon(fakePng(336, 210)), false);
    assert.equal(isUsableIcon(Buffer.from('nope')), false);
});
```

- [ ] **Step 2: Run them to make sure they fail**

Run: `cd packages/standalone && npm test`
Expected: FAIL, `Cannot find module '../lib/manifest'` / `'../lib/icon'`.

- [ ] **Step 3: Implement `lib/manifest.js` and `lib/icon.js`**

`lib/manifest.js`:

```js
'use strict';
const path = require('node:path');
const JSZip = require('jszip');

function parseManifest(text) {
    const out = {};
    for (const raw of text.split(/\r?\n/)) {
        const line = raw.trim();
        if (!line || line.startsWith('#')) {
            continue;
        }
        const eq = line.indexOf('=');
        if (eq <= 0) {
            continue;
        }
        out[line.slice(0, eq).trim()] = line.slice(eq + 1).trim();
    }
    return out;
}

async function readGameZip(zipBuffer) {
    const zip = await JSZip.loadAsync(zipBuffer);
    const manifestFile = zip.file('manifest');
    if (!manifestFile) {
        throw new Error('zip has no manifest at its root');
    }
    const manifest = parseManifest(await manifestFile.async('string'));
    let icon = null;
    const iconUri = manifest.mm_icon_focus_hd || '';
    if (iconUri.startsWith('pkg:/')) {
        const entry = zip.file(iconUri.slice('pkg:/'.length));
        if (entry) {
            icon = { name: path.posix.basename(entry.name), data: await entry.async('nodebuffer') };
        }
    }
    return { manifest, icon };
}

function gameInfo(manifest) {
    const part = (key) => String(parseInt(manifest[key], 10) || 0);
    return {
        title: manifest.title || 'BGE Game',
        version: `${part('major_version')}.${part('minor_version')}.${part('build_version')}`,
        multiControllers: manifest.multi_controllers === '1'
    };
}

module.exports = { parseManifest, readGameZip, gameInfo };
```

`lib/icon.js`:

```js
'use strict';
const PNG_SIGNATURE = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
const MIN_ICON_SIZE = 512;

function pngSize(buf) {
    if (!Buffer.isBuffer(buf) || buf.length < 24 || !buf.subarray(0, 8).equals(PNG_SIGNATURE)) {
        return null;
    }
    return { width: buf.readUInt32BE(16), height: buf.readUInt32BE(20) };
}

// electron-builder rejects mac/linux icons smaller than 512x512.
function isUsableIcon(buf) {
    const size = pngSize(buf);
    return size !== null && size.width >= MIN_ICON_SIZE && size.height >= MIN_ICON_SIZE;
}

module.exports = { pngSize, isUsableIcon, MIN_ICON_SIZE };
```

- [ ] **Step 4: Run the tests and make sure they pass**

Run: `cd packages/standalone && npm test`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add packages/standalone/lib/manifest.js packages/standalone/lib/icon.js packages/standalone/test/manifest.test.js packages/standalone/test/icon.test.js
git commit -m "bge-standalone: read manifest, version and icon from the game zip (#235)"
```

---

### Task 4: Config resolution and targets

**Files:**
- Create: `packages/standalone/lib/config.js`, `packages/standalone/test/config.test.js`

**Interfaces:**
- Consumes: `gameInfo()` output shape `{ title, version, multiControllers }` (Task 3).
- Produces:
  - `loadConfigFile(file: string, required: boolean): object`. A missing file returns `{}` unless `required`, which throws `config file not found: <file>`. Invalid JSON throws `<file>: invalid JSON (<msg>)`.
  - `resolveZipPath({ cli, file, cwd }): string` (absolute). Throws `no game zip: pass --zip <path> or set "zip" in bge-standalone.json`.
  - `hostOs(platform = process.platform): 'mac'|'win'|'linux'`
  - `resolveTargets(requested: string|string[]|undefined, platform): string[]`, ordered with `web` first
  - `resolveConfig({ cli, file, game, platform, cwd }): ResolvedConfig`, where

```
ResolvedConfig = {
  zip: string,            // absolute
  appId: string,
  productName: string,
  version: string,
  icon: string | null,    // absolute path from config, or null = use manifest icon
  sceneGraph: boolean,
  window: { width: number, height: number, fullscreen: boolean, resizable: boolean },
  targets: string[],
  outDir: string          // absolute
}
```

  `cli` is `{ target?, zip?, out? }` (strings from parseArgs). `file` is the parsed JSON.

- [ ] **Step 1: Write the failing tests**

`packages/standalone/test/config.test.js`:

```js
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { loadConfigFile, resolveZipPath, hostOs, resolveTargets, resolveConfig } = require('../lib/config');
const { tmpDir } = require('./helpers');

const GAME = { title: 'Example Game - Pong!', version: '1.2.3', multiControllers: true };
const CWD = path.resolve('/work/game');

test('loadConfigFile: missing optional file is {}; required throws; bad JSON names the file', () => {
    const dir = tmpDir();
    assert.deepEqual(loadConfigFile(path.join(dir, 'nope.json'), false), {});
    assert.throws(() => loadConfigFile(path.join(dir, 'nope.json'), true), /config file not found/);
    const bad = path.join(dir, 'bad.json');
    fs.writeFileSync(bad, '{ nope');
    assert.throws(() => loadConfigFile(bad, false), /bad\.json: invalid JSON/);
    const good = path.join(dir, 'good.json');
    fs.writeFileSync(good, '{"zip":"out/g.zip"}');
    assert.deepEqual(loadConfigFile(good, false), { zip: 'out/g.zip' });
});

test('resolveZipPath: CLI wins over file, resolved against cwd; missing throws', () => {
    assert.equal(resolveZipPath({ cli: { zip: 'a.zip' }, file: { zip: 'b.zip' }, cwd: CWD }), path.join(CWD, 'a.zip'));
    assert.equal(resolveZipPath({ cli: {}, file: { zip: 'b.zip' }, cwd: CWD }), path.join(CWD, 'b.zip'));
    assert.throws(() => resolveZipPath({ cli: {}, file: {}, cwd: CWD }), /no game zip/);
});

test('hostOs maps node platforms', () => {
    assert.equal(hostOs('darwin'), 'mac');
    assert.equal(hostOs('win32'), 'win');
    assert.equal(hostOs('linux'), 'linux');
});

test('resolveTargets: default and "all" are web + host; comma lists; foreign OS throws', () => {
    assert.deepEqual(resolveTargets(undefined, 'darwin'), ['web', 'mac']);
    assert.deepEqual(resolveTargets('all', 'linux'), ['web', 'linux']);
    assert.deepEqual(resolveTargets('web', 'linux'), ['web']);
    assert.deepEqual(resolveTargets('linux,web', 'linux'), ['web', 'linux']);
    assert.deepEqual(resolveTargets(['win'], 'win32'), ['win']);
    assert.throws(() => resolveTargets('mac', 'linux'), /build mac targets on macOS/);
    assert.throws(() => resolveTargets('ios', 'linux'), /unknown target "ios"/);
});

test('resolveConfig fills defaults from the game info', () => {
    const c = resolveConfig({ cli: {}, file: { zip: 'out/g.zip' }, game: GAME, platform: 'linux', cwd: CWD });
    assert.deepEqual(c, {
        zip: path.join(CWD, 'out/g.zip'),
        appId: 'com.bge.example-game-pong',
        productName: 'Example Game - Pong!',
        version: '1.2.3',
        icon: null,
        sceneGraph: false,
        window: { width: 1280, height: 720, fullscreen: false, resizable: true },
        targets: ['web', 'linux'],
        outDir: path.join(CWD, 'dist')
    });
});

test('resolveConfig applies file overrides, partial window, CLI out/target', () => {
    const c = resolveConfig({
        cli: { out: 'build-out', target: 'web' },
        file: { zip: 'g.zip', appId: 'com.me.pong', productName: 'Pong', version: '2.0.0', icon: 'art/icon.png', sceneGraph: true, window: { fullscreen: true }, targets: ['linux'] },
        game: GAME,
        platform: 'linux',
        cwd: CWD
    });
    assert.equal(c.appId, 'com.me.pong');
    assert.equal(c.productName, 'Pong');
    assert.equal(c.version, '2.0.0');
    assert.equal(c.icon, path.join(CWD, 'art/icon.png'));
    assert.equal(c.sceneGraph, true);
    assert.deepEqual(c.window, { width: 1280, height: 720, fullscreen: true, resizable: true });
    assert.deepEqual(c.targets, ['web']);
    assert.equal(c.outDir, path.join(CWD, 'build-out'));
});

test('resolveConfig rejects unknown keys and bad types, naming the field', () => {
    const base = { cli: {}, game: GAME, platform: 'linux', cwd: CWD };
    assert.throws(() => resolveConfig({ ...base, file: { zip: 'g.zip', colour: 'red' } }), /unknown config field "colour"/);
    assert.throws(() => resolveConfig({ ...base, file: { zip: 'g.zip', sceneGraph: 'yes' } }), /"sceneGraph" must be a boolean/);
    assert.throws(() => resolveConfig({ ...base, file: { zip: 'g.zip', window: { width: '800' } } }), /"window.width" must be a positive number/);
    assert.throws(() => resolveConfig({ ...base, file: { zip: 'g.zip', window: { depth: 1 } } }), /unknown config field "window.depth"/);
    assert.throws(() => resolveConfig({ ...base, file: { zip: 'g.zip', version: '1.2' } }), /"version" must be x\.y\.z/);
});

test('appId falls back to com.bge.game for titles with no letters/digits', () => {
    const c = resolveConfig({ cli: {}, file: { zip: 'g.zip' }, game: { ...GAME, title: '!!!' }, platform: 'linux', cwd: CWD });
    assert.equal(c.appId, 'com.bge.game');
});
```

- [ ] **Step 2: Run them to make sure they fail**

Run: `cd packages/standalone && npm test`
Expected: FAIL, `Cannot find module '../lib/config'`.

- [ ] **Step 3: Implement `lib/config.js`**

```js
'use strict';
const fs = require('node:fs');
const path = require('node:path');

const DESKTOP_TARGETS = ['mac', 'win', 'linux'];
const ALL_TARGETS = ['web', ...DESKTOP_TARGETS];
const OS_NAMES = { mac: 'macOS', win: 'Windows', linux: 'Linux' };
const FILE_KEYS = ['zip', 'appId', 'productName', 'version', 'icon', 'sceneGraph', 'window', 'targets', 'outDir'];
const WINDOW_DEFAULTS = { width: 1280, height: 720, fullscreen: false, resizable: true };

function loadConfigFile(file, required) {
    if (!fs.existsSync(file)) {
        if (required) {
            throw new Error(`config file not found: ${file}`);
        }
        return {};
    }
    try {
        return JSON.parse(fs.readFileSync(file, 'utf8'));
    } catch (e) {
        throw new Error(`${file}: invalid JSON (${e.message})`);
    }
}

function resolveZipPath({ cli, file, cwd }) {
    const zip = cli.zip || file.zip;
    if (!zip) {
        throw new Error('no game zip: pass --zip <path> or set "zip" in bge-standalone.json');
    }
    return path.resolve(cwd, zip);
}

function hostOs(platform = process.platform) {
    if (platform === 'darwin') {
        return 'mac';
    }
    if (platform === 'win32') {
        return 'win';
    }
    return 'linux';
}

function resolveTargets(requested, platform) {
    const host = hostOs(platform);
    let list;
    if (requested === undefined) {
        list = ['web', host];
    } else {
        list = Array.isArray(requested) ? requested : String(requested).split(',');
        list = list.map((t) => t.trim()).filter(Boolean);
        if (list.includes('all')) {
            list = ['web', host];
        }
    }
    for (const t of list) {
        if (!ALL_TARGETS.includes(t)) {
            throw new Error(`unknown target "${t}" (use web, mac, win, linux or all)`);
        }
        if (t !== 'web' && t !== host) {
            throw new Error(`build ${t} targets on ${OS_NAMES[t]} (or use a CI OS matrix); this machine is ${OS_NAMES[host]}`);
        }
    }
    return ALL_TARGETS.filter((t) => list.includes(t));
}

function slug(title) {
    return title.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '') || 'game';
}

function checkType(name, value, kind) {
    if (value === undefined) {
        return;
    }
    const ok = kind === 'number' ? typeof value === 'number' && value > 0 : typeof value === kind;
    if (!ok) {
        throw new Error(`"${name}" must be a ${kind === 'number' ? 'positive number' : kind}`);
    }
}

function validateFile(file) {
    for (const key of Object.keys(file)) {
        if (!FILE_KEYS.includes(key)) {
            throw new Error(`unknown config field "${key}"`);
        }
    }
    for (const key of ['zip', 'appId', 'productName', 'version', 'icon', 'outDir']) {
        checkType(key, file[key], 'string');
    }
    checkType('sceneGraph', file.sceneGraph, 'boolean');
    if (file.version !== undefined && !/^\d+\.\d+\.\d+$/.test(file.version)) {
        throw new Error('"version" must be x.y.z');
    }
    if (file.targets !== undefined && !Array.isArray(file.targets)) {
        throw new Error('"targets" must be an array');
    }
    if (file.window !== undefined) {
        if (typeof file.window !== 'object' || file.window === null) {
            throw new Error('"window" must be an object');
        }
        for (const key of Object.keys(file.window)) {
            if (!(key in WINDOW_DEFAULTS)) {
                throw new Error(`unknown config field "window.${key}"`);
            }
        }
        checkType('window.width', file.window.width, 'number');
        checkType('window.height', file.window.height, 'number');
        checkType('window.fullscreen', file.window.fullscreen, 'boolean');
        checkType('window.resizable', file.window.resizable, 'boolean');
    }
}

function resolveConfig({ cli, file, game, platform, cwd }) {
    validateFile(file);
    return {
        zip: resolveZipPath({ cli, file, cwd }),
        appId: file.appId || `com.bge.${slug(game.title)}`,
        productName: file.productName || game.title,
        version: file.version || game.version,
        icon: file.icon ? path.resolve(cwd, file.icon) : null,
        sceneGraph: file.sceneGraph === true,
        window: { ...WINDOW_DEFAULTS, ...(file.window || {}) },
        targets: resolveTargets(cli.target !== undefined ? cli.target : file.targets, platform),
        outDir: path.resolve(cwd, cli.out || file.outDir || 'dist')
    };
}

module.exports = { loadConfigFile, resolveZipPath, hostOs, resolveTargets, resolveConfig, DESKTOP_TARGETS };
```

- [ ] **Step 4: Run the tests and make sure they pass**

Run: `cd packages/standalone && npm test`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add packages/standalone/lib/config.js packages/standalone/test/config.test.js
git commit -m "bge-standalone: config file, defaults, validation and targets (#235)"
```

---

### Task 5: Web bundle writer

**Files:**
- Create: `packages/standalone/lib/webBundle.js`, `packages/standalone/test/webBundle.test.js`

**Interfaces:**
- Consumes: `ResolvedConfig` (Task 4). Template placeholders `{{TITLE}}`, `{{SETTINGS_JSON}}` (Task 2).
- Produces: `writeWebBundle({ config: ResolvedConfig, webDir: string, packageDir?: (name: string) => string }): string[]`. It empties and recreates `webDir` and returns the sorted list of written files, relative and `/`-separated. `packageDir` defaults to `name => path.dirname(require.resolve(name + '/package.json'))` and is injectable for tests. Also exports `escapeHtml(s)`.

If Task 2's spike found that `components/` must be stripped when `sceneGraph` is false, add that here as `stripComponents(zipBuffer): Promise<Buffer>` with a test that the output zip has no `components/` entries. Otherwise skip it.

- [ ] **Step 1: Write the failing tests**

`packages/standalone/test/webBundle.test.js`:

```js
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { writeWebBundle, escapeHtml } = require('../lib/webBundle');
const { tmpDir, makeGameZip } = require('./helpers');

function fakeEngineDir() {
    const dir = tmpDir();
    fs.mkdirSync(path.join(dir, 'lib'));
    fs.mkdirSync(path.join(dir, 'assets'));
    fs.writeFileSync(path.join(dir, 'lib', 'brs.api.js'), 'api');
    fs.writeFileSync(path.join(dir, 'lib', 'brs.worker.js'), 'worker');
    fs.writeFileSync(path.join(dir, 'assets', 'common.zip'), 'core-common');
    return dir;
}

async function setup(overrides = {}) {
    const work = tmpDir();
    const zip = path.join(work, 'game.zip');
    fs.writeFileSync(zip, await makeGameZip('title=x'));
    const config = { zip, productName: 'Pong <Deluxe> & "Co"', sceneGraph: false, ...overrides };
    return { work, config, webDir: path.join(work, 'dist', 'web') };
}

test('writes the Draw 2D bundle layout with filled template', async () => {
    const { config, webDir } = await setup();
    const engine = fakeEngineDir();
    const files = writeWebBundle({ config, webDir, packageDir: () => engine });
    assert.deepEqual(files, ['assets/common.zip', 'game.zip', 'index.html', 'lib/brs.api.js', 'lib/brs.worker.js', 'runtime.js']);
    const html = fs.readFileSync(path.join(webDir, 'index.html'), 'utf8');
    assert.match(html, /<title>Pong &lt;Deluxe&gt; &amp; &quot;Co&quot;<\/title>/);
    assert.match(html, /<script id="bge-settings" type="application\/json">\{"sceneGraph":false\}<\/script>/);
    assert.doesNotMatch(html, /\{\{/);
    assert.equal(fs.readFileSync(path.join(webDir, 'assets', 'common.zip'), 'utf8'), 'core-common');
    assert.deepEqual(fs.readFileSync(path.join(webDir, 'game.zip')), fs.readFileSync(config.zip));
});

test('empties a previous build first', async () => {
    const { config, webDir } = await setup();
    fs.mkdirSync(webDir, { recursive: true });
    fs.writeFileSync(path.join(webDir, 'stale.txt'), 'old');
    writeWebBundle({ config, webDir, packageDir: () => fakeEngineDir() });
    assert.equal(fs.existsSync(path.join(webDir, 'stale.txt')), false);
});

test('throws a clear error when the zip is missing', async () => {
    const { config, webDir } = await setup({ zip: path.join(tmpDir(), 'missing.zip') });
    assert.throws(() => writeWebBundle({ config, webDir, packageDir: () => fakeEngineDir() }), /game zip not found: .*missing\.zip/);
});

test('escapeHtml escapes the five HTML specials', () => {
    assert.equal(escapeHtml(`<a href="x">'&'</a>`), '&lt;a href=&quot;x&quot;&gt;&#39;&amp;&#39;&lt;/a&gt;');
});

test('default packageDir finds the real brs-engine', async () => {
    const { config, webDir } = await setup();
    writeWebBundle({ config, webDir });
    assert.ok(fs.statSync(path.join(webDir, 'lib', 'brs.worker.js')).size > 1000);
});
```

- [ ] **Step 2: Run them to make sure they fail**

Run: `cd packages/standalone && npm test`
Expected: FAIL, `Cannot find module '../lib/webBundle'`.

- [ ] **Step 3: Implement `lib/webBundle.js`**

```js
'use strict';
const fs = require('node:fs');
const path = require('node:path');

const TEMPLATE_DIR = path.join(__dirname, '..', 'template', 'web');

function defaultPackageDir(name) {
    return path.dirname(require.resolve(`${name}/package.json`));
}

function escapeHtml(s) {
    return String(s)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;');
}

function copy(from, webDir, rel) {
    const to = path.join(webDir, ...rel.split('/'));
    fs.mkdirSync(path.dirname(to), { recursive: true });
    fs.copyFileSync(from, to);
}

function writeWebBundle({ config, webDir, packageDir = defaultPackageDir }) {
    if (!fs.existsSync(config.zip)) {
        throw new Error(`game zip not found: ${config.zip}`);
    }
    fs.rmSync(webDir, { recursive: true, force: true });
    fs.mkdirSync(webDir, { recursive: true });

    const engine = packageDir('brs-engine');
    copy(path.join(engine, 'lib', 'brs.api.js'), webDir, 'lib/brs.api.js');
    copy(path.join(engine, 'lib', 'brs.worker.js'), webDir, 'lib/brs.worker.js');
    copy(path.join(engine, 'assets', 'common.zip'), webDir, 'assets/common.zip');

    copy(config.zip, webDir, 'game.zip');
    copy(path.join(TEMPLATE_DIR, 'runtime.js'), webDir, 'runtime.js');

    // "<" is escaped so the JSON can't close the <script> it sits in.
    const settings = JSON.stringify({ sceneGraph: config.sceneGraph }).replace(/</g, '\\u003c');
    const html = fs
        .readFileSync(path.join(TEMPLATE_DIR, 'index.html'), 'utf8')
        .replace('{{TITLE}}', escapeHtml(config.productName))
        .replace('{{SETTINGS_JSON}}', settings);
    fs.writeFileSync(path.join(webDir, 'index.html'), html);

    return listFiles(webDir);
}

function listFiles(dir, prefix = '') {
    const out = [];
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
        const rel = prefix ? `${prefix}/${entry.name}` : entry.name;
        if (entry.isDirectory()) {
            out.push(...listFiles(path.join(dir, entry.name), rel));
        } else {
            out.push(rel);
        }
    }
    return out.sort();
}

module.exports = { writeWebBundle, escapeHtml, listFiles };
```

- [ ] **Step 4: Run the tests and make sure they pass**

Run: `cd packages/standalone && npm test`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add packages/standalone/lib/webBundle.js packages/standalone/test/webBundle.test.js
git commit -m "bge-standalone: write the static web bundle (#235)"
```

---

### Task 6: CLI (`build --target web`, `serve`) and end-to-end web check

**Files:**
- Create: `packages/standalone/lib/cli.js`, `packages/standalone/bin/bge-standalone.js`, `packages/standalone/test/cli.test.js`, `packages/standalone/test/e2e/web.e2e.js`, `.github/workflows/standalone.yml`
- Modify: `package.json` (root): add the script `"standalone:test": "npm --prefix packages/standalone test"`

**Interfaces:**
- Consumes: `loadConfigFile`, `resolveConfig`, `resolveZipPath` (Task 4); `readGameZip`, `gameInfo` (Task 3); `writeWebBundle` (Task 5); `serve` (Task 1).
- Produces: `main(argv: string[], deps?: Partial<Deps>): Promise<number>` (exit code). `Deps = { cwd: string, platform: string, log: (msg) => void, warn: (msg) => void, buildDesktop: Function }`, all injectable for tests. `buildDesktop` is a stub until Task 8. `build` lays out `<outDir>/web`, `<outDir>/electron-app`, `<outDir>/desktop`.

- [ ] **Step 1: Write the failing CLI tests**

`packages/standalone/test/cli.test.js`:

```js
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { main } = require('../lib/cli');
const { tmpDir, makeGameZip } = require('./helpers');

function capture() {
    const logs = [];
    const warns = [];
    return { logs, warns, log: (m) => logs.push(m), warn: (m) => warns.push(m) };
}

async function gameDir(manifest = 'title=Pong\nmulti_controllers=1') {
    const cwd = tmpDir();
    fs.mkdirSync(path.join(cwd, 'out'));
    fs.writeFileSync(path.join(cwd, 'out', 'game.zip'), await makeGameZip(manifest));
    return cwd;
}

test('build --target web writes dist/web and exits 0', async () => {
    const cwd = await gameDir();
    const io = capture();
    const code = await main(['build', '--target', 'web', '--zip', 'out/game.zip'], { cwd, platform: 'linux', ...io });
    assert.equal(code, 0);
    assert.ok(fs.existsSync(path.join(cwd, 'dist', 'web', 'index.html')));
    assert.deepEqual(io.warns, []);
    assert.ok(io.logs.some((l) => l.includes(path.join(cwd, 'dist', 'web'))));
});

test('build reads bge-standalone.json from cwd', async () => {
    const cwd = await gameDir();
    fs.writeFileSync(path.join(cwd, 'bge-standalone.json'), JSON.stringify({ zip: 'out/game.zip', outDir: 'site', targets: ['web'] }));
    const code = await main(['build'], { cwd, platform: 'linux', ...capture() });
    assert.equal(code, 0);
    assert.ok(fs.existsSync(path.join(cwd, 'site', 'web', 'game.zip')));
});

test('build warns when multi_controllers=1 is missing', async () => {
    const cwd = await gameDir('title=Pong');
    const io = capture();
    await main(['build', '--target', 'web', '--zip', 'out/game.zip'], { cwd, platform: 'linux', ...io });
    assert.ok(io.warns.some((w) => w.includes('multi_controllers=1')));
});

test('errors print "bge-standalone: <message>" and exit 1', async () => {
    const cwd = tmpDir();
    const io = capture();
    assert.equal(await main(['build', '--target', 'web'], { cwd, platform: 'linux', ...io }), 1);
    assert.match(io.warns.join('\n'), /bge-standalone: no game zip/);
    assert.equal(await main(['build', '--zip', 'missing.zip', '--target', 'web'], { cwd, platform: 'linux', ...io }), 1);
    assert.match(io.warns.join('\n'), /game zip not found/);
    assert.equal(await main(['frobnicate'], { cwd, platform: 'linux', ...io }), 1);
    assert.match(io.warns.join('\n'), /unknown command "frobnicate"/);
});

test('no command prints usage and exits 1', async () => {
    const io = capture();
    assert.equal(await main([], { cwd: tmpDir(), platform: 'linux', ...io }), 1);
    assert.match(io.logs.join('\n'), /Usage: bge-standalone build/);
});

test('desktop targets call buildDesktop with the electron-app and desktop dirs', async () => {
    const cwd = await gameDir();
    const calls = [];
    const code = await main(['build', '--target', 'linux', '--zip', 'out/game.zip'], {
        cwd,
        platform: 'linux',
        ...capture(),
        buildDesktop: async (args) => calls.push(args)
    });
    assert.equal(code, 0);
    assert.equal(calls.length, 1);
    assert.equal(calls[0].target, 'linux');
    assert.equal(calls[0].webDir, path.join(cwd, 'dist', 'web'));
    assert.equal(calls[0].appDir, path.join(cwd, 'dist', 'electron-app'));
    assert.equal(calls[0].outDir, path.join(cwd, 'dist', 'desktop'));
    assert.ok(fs.existsSync(path.join(cwd, 'dist', 'web', 'index.html')), 'desktop builds still write the web bundle they wrap');
});
```

- [ ] **Step 2: Run them to make sure they fail**

Run: `cd packages/standalone && npm test`
Expected: FAIL, `Cannot find module '../lib/cli'`.

- [ ] **Step 3: Implement `lib/cli.js` and `bin/bge-standalone.js`**

`lib/cli.js`:

```js
'use strict';
const fs = require('node:fs');
const path = require('node:path');
const { parseArgs } = require('node:util');
const { loadConfigFile, resolveConfig, resolveZipPath } = require('./config');
const { readGameZip, gameInfo } = require('./manifest');
const { writeWebBundle } = require('./webBundle');
const { serve } = require('./serve');

const USAGE = [
    'Usage: bge-standalone build [--target web|mac|win|linux|all] [--config file] [--zip path] [--out dir]',
    '       bge-standalone serve [dir] [--port 6502]'
].join('\n');

async function notImplementedDesktop() {
    throw new Error('desktop targets are not available yet');
}

function defaults() {
    return {
        cwd: process.cwd(),
        platform: process.platform,
        log: (m) => console.log(m),
        warn: (m) => console.error(m),
        buildDesktop: notImplementedDesktop
    };
}

async function build(argv, deps) {
    const { values } = parseArgs({
        args: argv,
        options: { target: { type: 'string' }, config: { type: 'string' }, zip: { type: 'string' }, out: { type: 'string' } }
    });
    const configPath = values.config ? path.resolve(deps.cwd, values.config) : path.join(deps.cwd, 'bge-standalone.json');
    const file = loadConfigFile(configPath, Boolean(values.config));
    const zipPath = resolveZipPath({ cli: values, file, cwd: deps.cwd });
    if (!fs.existsSync(zipPath)) {
        throw new Error(`game zip not found: ${zipPath}`);
    }
    const game = await readGameZip(fs.readFileSync(zipPath));
    const info = gameInfo(game.manifest);
    const config = resolveConfig({ cli: values, file, game: info, platform: deps.platform, cwd: deps.cwd });
    if (!info.multiControllers) {
        deps.warn('warning: manifest has no multi_controllers=1, so analog sticks and extra gamepad buttons are off');
    }

    const webDir = path.join(config.outDir, 'web');
    writeWebBundle({ config, webDir });
    deps.log(`web build: ${webDir}`);

    for (const target of config.targets.filter((t) => t !== 'web')) {
        await deps.buildDesktop({
            config,
            game,
            target,
            webDir,
            appDir: path.join(config.outDir, 'electron-app'),
            outDir: path.join(config.outDir, 'desktop'),
            log: deps.log,
            warn: deps.warn
        });
        deps.log(`${target} build: ${path.join(config.outDir, 'desktop')}`);
    }
}

async function serveCommand(argv, deps) {
    const { values, positionals } = parseArgs({ args: argv, allowPositionals: true, options: { port: { type: 'string' } } });
    const dir = path.resolve(deps.cwd, positionals[0] || path.join('dist', 'web'));
    if (!fs.existsSync(path.join(dir, 'index.html'))) {
        throw new Error(`no index.html in ${dir} (run bge-standalone build --target web first)`);
    }
    const server = await serve(dir, Number(values.port || 6502));
    deps.log(`serving ${dir} at http://127.0.0.1:${server.address().port}/ (Ctrl+C to stop)`);
    return server;
}

async function main(argv, overrides = {}) {
    const deps = { ...defaults(), ...overrides };
    const [command, ...rest] = argv;
    try {
        if (command === 'build') {
            await build(rest, deps);
            return 0;
        }
        if (command === 'serve') {
            await serveCommand(rest, deps);
            return 0;
        }
        if (command === undefined || command === '--help' || command === '-h') {
            deps.log(USAGE);
            return command === undefined ? 1 : 0;
        }
        throw new Error(`unknown command "${command}"\n${USAGE}`);
    } catch (e) {
        deps.warn(`bge-standalone: ${e.message}`);
        return 1;
    }
}

module.exports = { main, USAGE };
```

`bin/bge-standalone.js`:

```js
#!/usr/bin/env node
'use strict';
const { main } = require('../lib/cli');

main(process.argv.slice(2)).then((code) => {
    // serve keeps the process alive through its open server; only set the code.
    process.exitCode = code;
});
```

Root `package.json`: add `"standalone:test": "npm --prefix packages/standalone test"` to `scripts`, after `test:ropm-consumer`.

- [ ] **Step 4: Run the tests and make sure they pass**

Run: `cd packages/standalone && npm test`
Expected: all pass. The desktop test passes because `buildDesktop` is injected.

- [ ] **Step 5: Write the e2e test**

`packages/standalone/test/e2e/web.e2e.js`:

```js
'use strict';
// Needs: BGE_E2E_ZIP=<path to a built game zip> and `npx playwright install chromium`.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { chromium } = require('playwright');
const { main } = require('../../lib/cli');
const { serve } = require('../../lib/serve');
const { tmpDir } = require('../helpers');

test('web build of a real game starts and draws under brs-engine', { timeout: 120000 }, async () => {
    const zip = process.env.BGE_E2E_ZIP;
    assert.ok(zip && fs.existsSync(zip), 'set BGE_E2E_ZIP to a built game zip (e.g. examples/pong/out/bge-pong.zip)');
    const out = tmpDir();
    const code = await main(['build', '--target', 'web', '--zip', path.resolve(zip), '--out', out], { log: () => {} });
    assert.equal(code, 0);

    const server = await serve(path.join(out, 'web'), 0);
    const browser = await chromium.launch();
    try {
        const page = await browser.newPage();
        const errors = [];
        page.on('pageerror', (e) => errors.push(e.message));
        await page.goto(`http://127.0.0.1:${server.address().port}/`);
        await page.waitForFunction(() => window.__bgeStarted === true || typeof window.__bgeError === 'string', null, { timeout: 60000 });
        assert.equal(await page.evaluate(() => window.__bgeError), undefined);
        assert.equal(await page.evaluate(() => self.crossOriginIsolated), true);
        await page.waitForTimeout(2000);
        const colors = await page.evaluate(() => {
            const src = document.getElementById('display');
            const c = document.createElement('canvas');
            c.width = src.width;
            c.height = src.height;
            const ctx = c.getContext('2d');
            ctx.drawImage(src, 0, 0);
            const data = ctx.getImageData(0, 0, c.width, c.height).data;
            const seen = new Set();
            for (let i = 0; i < data.length && seen.size < 3; i += 4 * 97) {
                seen.add((data[i] << 16) | (data[i + 1] << 8) | data[i + 2]);
            }
            return seen.size;
        });
        assert.ok(colors > 1, 'canvas should not be a single flat color after 2s');
        assert.deepEqual(errors, []);
    } finally {
        await browser.close();
        server.close();
    }
});
```

- [ ] **Step 6: Run the e2e test against pong**

```bash
(cd examples/pong && npm run package)
cd packages/standalone && npx playwright install chromium
BGE_E2E_ZIP=../../examples/pong/out/bge-pong.zip npm run test:e2e
```

Expected: 1 test passes. If it fails, use the spike notes from Task 2 to work out whether the runtime page or the engine is at fault before changing anything.

- [ ] **Step 7: Add the CI workflow**

`.github/workflows/standalone.yml`:

```yaml
name: Standalone Builds

on:
  pull_request:
    branches: [main]
    paths: ['packages/standalone/**', 'src/**', 'examples/pong/**', '.github/workflows/standalone.yml']
  push:
    branches: [main]
    paths: ['packages/standalone/**', 'src/**', 'examples/pong/**', '.github/workflows/standalone.yml']

jobs:
  standalone:
    runs-on: ubuntu-latest
    defaults:
      run:
        shell: bash
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: 24
          cache: npm
          cache-dependency-path: |
            package-lock.json
            packages/standalone/package-lock.json
            examples/pong/package-lock.json

      - name: Unit tests
        working-directory: packages/standalone
        run: npm ci && npm test

      - name: Build pong
        run: |
          npm ci
          npx ropm install
          cd examples/pong && npm ci && npm run package

      - name: End-to-end web check
        working-directory: packages/standalone
        run: |
          npx playwright install --with-deps chromium
          BGE_E2E_ZIP=../../examples/pong/out/bge-pong.zip npm run test:e2e
```

- [ ] **Step 8: Commit**

```bash
git add packages/standalone package.json .github/workflows/standalone.yml
git commit -m "bge-standalone: build/serve CLI and end-to-end web check (#235)"
```

---

### Task 7: Generated Electron app

**Files:**
- Create: `packages/standalone/template/electron/main.js`, `packages/standalone/template/electron/preload.js`, `packages/standalone/lib/electronApp.js`, `packages/standalone/test/electronApp.test.js`

**Interfaces:**
- Consumes: `ResolvedConfig` (Task 4), a written `webDir` (Task 5).
- Produces: `writeElectronApp({ config, webDir, appDir }): void`. It empties `appDir` and writes `package.json` (`name`, `productName`, `version`, `description`, `main: "main.js"`), `bge-app.json` (`{ title, window }`), `main.js`, `preload.js` and a copy of `webDir` as `web/`. The main process exports `resolveRequest(webRoot, url): string|null` for unit testing (it runs under plain Node because the `electron` require is lazy inside `start()`).

- [ ] **Step 1: Write the failing tests**

`packages/standalone/test/electronApp.test.js`:

```js
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { writeElectronApp } = require('../lib/electronApp');
const { tmpDir } = require('./helpers');

const CONFIG = {
    appId: 'com.bge.pong',
    productName: 'Pong',
    version: '1.2.3',
    window: { width: 1280, height: 720, fullscreen: false, resizable: true }
};

function webDir() {
    const dir = tmpDir();
    fs.writeFileSync(path.join(dir, 'index.html'), 'x');
    fs.mkdirSync(path.join(dir, 'lib'));
    fs.writeFileSync(path.join(dir, 'lib', 'brs.api.js'), 'y');
    return dir;
}

test('writes package.json, bge-app.json, main/preload and copies web/', () => {
    const appDir = path.join(tmpDir(), 'electron-app');
    writeElectronApp({ config: CONFIG, webDir: webDir(), appDir });
    const pkg = JSON.parse(fs.readFileSync(path.join(appDir, 'package.json'), 'utf8'));
    assert.deepEqual(pkg, { name: 'com.bge.pong', productName: 'Pong', version: '1.2.3', description: 'Pong', main: 'main.js' });
    assert.deepEqual(JSON.parse(fs.readFileSync(path.join(appDir, 'bge-app.json'), 'utf8')), { title: 'Pong', window: CONFIG.window });
    for (const f of ['main.js', 'preload.js', 'web/index.html', 'web/lib/brs.api.js']) {
        assert.ok(fs.existsSync(path.join(appDir, ...f.split('/'))), f);
    }
});

test('main.js resolveRequest maps app:// URLs into web/ and blocks traversal', () => {
    const appDir = path.join(tmpDir(), 'electron-app');
    writeElectronApp({ config: CONFIG, webDir: webDir(), appDir });
    const { resolveRequest } = require(path.join(appDir, 'main.js'));
    const root = path.join(appDir, 'web');
    assert.equal(resolveRequest(root, 'app://game/'), path.join(root, 'index.html'));
    assert.equal(resolveRequest(root, 'app://game/lib/brs.api.js?v=2'), path.join(root, 'lib', 'brs.api.js'));
    assert.equal(resolveRequest(root, 'app://game/..%2f..%2fsecret'), null);
});

test('main.js and preload.js keep the security settings', () => {
    const main = fs.readFileSync(path.join(__dirname, '..', 'template', 'electron', 'main.js'), 'utf8');
    assert.match(main, /contextIsolation: true/);
    assert.match(main, /nodeIntegration: false/);
    assert.match(main, /sandbox: true/);
    assert.match(main, /Cross-Origin-Embedder-Policy/);
    const preload = fs.readFileSync(path.join(__dirname, '..', 'template', 'electron', 'preload.js'), 'utf8');
    assert.match(preload, /exposeInMainWorld\('bgeHost', \{ quit:/);
});
```

- [ ] **Step 2: Run them to make sure they fail**

Run: `cd packages/standalone && npm test`
Expected: FAIL, `Cannot find module '../lib/electronApp'`.

- [ ] **Step 3: Write the templates**

`template/electron/main.js`:

```js
'use strict';
const path = require('node:path');
const { pathToFileURL } = require('node:url');

const ISOLATION_HEADERS = {
    'Cross-Origin-Opener-Policy': 'same-origin',
    'Cross-Origin-Embedder-Policy': 'require-corp',
    'Cross-Origin-Resource-Policy': 'same-origin'
};

function resolveRequest(webRoot, url) {
    const rel = decodeURIComponent(new URL(url).pathname).replace(/^\/+/, '') || 'index.html';
    const file = path.resolve(webRoot, rel);
    if (!file.startsWith(webRoot + path.sep)) {
        return null;
    }
    return file;
}

function start() {
    const { app, BrowserWindow, Menu, ipcMain, net, protocol } = require('electron');
    const settings = require('./bge-app.json');
    const webRoot = path.join(__dirname, 'web');
    const debug = process.env.BGE_STANDALONE_DEBUG === '1';

    // brs-engine needs SharedArrayBuffer: a secure, cross-origin-isolated origin.
    protocol.registerSchemesAsPrivileged([
        { scheme: 'app', privileges: { standard: true, secure: true, supportFetchAPI: true, corsEnabled: true, stream: true } }
    ]);

    app.whenReady().then(() => {
        protocol.handle('app', async (request) => {
            const file = resolveRequest(webRoot, request.url);
            if (!file) {
                return new Response('Not found', { status: 404 });
            }
            const res = await net.fetch(pathToFileURL(file).toString());
            const headers = new Headers(res.headers);
            for (const [key, value] of Object.entries(ISOLATION_HEADERS)) {
                headers.set(key, value);
            }
            return new Response(res.body, { status: res.status, headers });
        });

        ipcMain.on('bge:quit', () => app.quit());
        if (process.platform !== 'darwin') {
            Menu.setApplicationMenu(null);
        }

        const win = new BrowserWindow({
            title: settings.title,
            width: settings.window.width,
            height: settings.window.height,
            fullscreen: settings.window.fullscreen,
            resizable: settings.window.resizable,
            backgroundColor: '#000000',
            autoHideMenuBar: true,
            webPreferences: {
                preload: path.join(__dirname, 'preload.js'),
                contextIsolation: true,
                nodeIntegration: false,
                sandbox: true
            }
        });
        win.webContents.on('before-input-event', (event, input) => {
            if (input.type === 'keyDown' && input.key === 'F11') {
                win.setFullScreen(!win.isFullScreen());
                event.preventDefault();
            }
        });
        if (debug) {
            win.webContents.openDevTools({ mode: 'detach' });
        }
        win.loadURL(`app://game/index.html${debug ? '?debug=1' : ''}`);
    });

    app.on('window-all-closed', () => app.quit());
}

if (process.versions.electron) {
    start();
}

module.exports = { resolveRequest };
```

`template/electron/preload.js`:

```js
'use strict';
const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('bgeHost', { quit: () => ipcRenderer.send('bge:quit') });
```

- [ ] **Step 4: Implement `lib/electronApp.js`**

```js
'use strict';
const fs = require('node:fs');
const path = require('node:path');

const TEMPLATE_DIR = path.join(__dirname, '..', 'template', 'electron');

function writeJson(file, value) {
    fs.writeFileSync(file, JSON.stringify(value, null, 2) + '\n');
}

function writeElectronApp({ config, webDir, appDir }) {
    fs.rmSync(appDir, { recursive: true, force: true });
    fs.mkdirSync(appDir, { recursive: true });
    writeJson(path.join(appDir, 'package.json'), {
        name: config.appId,
        productName: config.productName,
        version: config.version,
        description: config.productName,
        main: 'main.js'
    });
    writeJson(path.join(appDir, 'bge-app.json'), { title: config.productName, window: config.window });
    fs.copyFileSync(path.join(TEMPLATE_DIR, 'main.js'), path.join(appDir, 'main.js'));
    fs.copyFileSync(path.join(TEMPLATE_DIR, 'preload.js'), path.join(appDir, 'preload.js'));
    fs.cpSync(webDir, path.join(appDir, 'web'), { recursive: true });
}

module.exports = { writeElectronApp };
```

- [ ] **Step 5: Run the tests and make sure they pass**

Run: `cd packages/standalone && npm test`
Expected: all pass.

- [ ] **Step 6: Smoke-run the generated app with Electron (no packaging)**

```bash
cd packages/standalone
node -e "
const { writeElectronApp } = require('./lib/electronApp');
writeElectronApp({ config: { appId: 'com.bge.pong', productName: 'Pong', version: '1.0.0', window: { width: 1280, height: 720, fullscreen: false, resizable: true } }, webDir: 'test-output/web', appDir: 'test-output/electron-app' });
"
npx electron test-output/electron-app
```

Before running it, create `test-output/web` with `node bin/bge-standalone.js build --target web --zip ../../examples/pong/out/bge-pong.zip --out test-output`.

Expected: a window opens and pong runs. Keyboard and gamepad work. When the game exits (Back on the title screen), the app quits. With `BGE_STANDALONE_DEBUG=1`, DevTools open and stats show. If the page loads but brs-engine reports that `SharedArrayBuffer` is unavailable, check the `app://` headers in DevTools → Network.

- [ ] **Step 7: Commit**

```bash
git add packages/standalone/template/electron packages/standalone/lib/electronApp.js packages/standalone/test/electronApp.test.js
git commit -m "bge-standalone: generated Electron app serving the web build over app:// (#235)"
```

---

### Task 8: Desktop packaging with electron-builder

**Files:**
- Create: `packages/standalone/lib/desktopBuild.js`, `packages/standalone/test/desktopBuild.test.js`
- Modify: `packages/standalone/lib/cli.js`: replace `notImplementedDesktop` with the real `buildDesktop`

**Interfaces:**
- Consumes: `writeElectronApp` (Task 7); `isUsableIcon`, `MIN_ICON_SIZE` (Task 3); the `cli.js` `buildDesktop` call shape `{ config, game, target, webDir, appDir, outDir, log, warn }` (Task 6).
- Produces:
  - `builderConfig({ config, outDir, iconPath: string|null, electronVersion: string }): object` (pure)
  - `pickIcon({ config, game, appDir, warn }): string|null`. It writes `icon.png` into `appDir` and returns its path, or returns null.
  - `buildDesktop(args, builder = require('electron-builder')): Promise<void>`

- [ ] **Step 1: Write the failing tests**

`packages/standalone/test/desktopBuild.test.js`:

```js
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { builderConfig, pickIcon, buildDesktop } = require('../lib/desktopBuild');
const { tmpDir, fakePng } = require('./helpers');

const CONFIG = {
    appId: 'com.bge.pong',
    productName: 'Pong',
    version: '1.0.0',
    icon: null,
    window: { width: 1280, height: 720, fullscreen: false, resizable: true }
};

test('builderConfig: unsigned per-OS targets, app files, electron version', () => {
    const c = builderConfig({ config: CONFIG, outDir: '/o', iconPath: '/a/icon.png', electronVersion: '45.3.2' });
    assert.equal(c.appId, 'com.bge.pong');
    assert.equal(c.productName, 'Pong');
    assert.equal(c.electronVersion, '45.3.2');
    assert.deepEqual(c.directories, { output: '/o' });
    assert.deepEqual(c.files, ['main.js', 'preload.js', 'bge-app.json', 'package.json', 'web/**/*']);
    assert.deepEqual(c.mac, { target: ['dmg'], category: 'public.app-category.games', identity: null, icon: '/a/icon.png' });
    assert.deepEqual(c.win, { target: ['nsis'], icon: '/a/icon.png' });
    assert.deepEqual(c.linux, { target: ['AppImage'], category: 'Game', icon: '/a/icon.png' });
});

test('builderConfig leaves icon out when there is none', () => {
    const c = builderConfig({ config: CONFIG, outDir: '/o', iconPath: null, electronVersion: '45.3.2' });
    assert.equal('icon' in c.mac, false);
});

test('pickIcon uses a big enough manifest icon, else warns and returns null', () => {
    const appDir = tmpDir();
    const warns = [];
    const big = fakePng(512, 512);
    assert.equal(pickIcon({ config: CONFIG, game: { icon: { name: 'i.png', data: big } }, appDir, warn: (m) => warns.push(m) }), path.join(appDir, 'icon.png'));
    assert.deepEqual(fs.readFileSync(path.join(appDir, 'icon.png')), big);
    assert.equal(pickIcon({ config: CONFIG, game: { icon: { name: 'i.png', data: fakePng(336, 210) } }, appDir, warn: (m) => warns.push(m) }), null);
    assert.equal(pickIcon({ config: CONFIG, game: { icon: null }, appDir, warn: (m) => warns.push(m) }), null);
    assert.equal(warns.length, 2);
    assert.match(warns[0], /512x512/);
});

test('pickIcon prefers config.icon and throws if that file is unusable', () => {
    const dir = tmpDir();
    const good = path.join(dir, 'good.png');
    fs.writeFileSync(good, fakePng(1024, 1024));
    const bad = path.join(dir, 'bad.png');
    fs.writeFileSync(bad, fakePng(64, 64));
    const appDir = tmpDir();
    assert.equal(pickIcon({ config: { ...CONFIG, icon: good }, game: { icon: null }, appDir, warn: () => {} }), path.join(appDir, 'icon.png'));
    assert.throws(() => pickIcon({ config: { ...CONFIG, icon: bad }, game: { icon: null }, appDir, warn: () => {} }), /bad\.png must be a PNG of at least 512x512/);
    assert.throws(() => pickIcon({ config: { ...CONFIG, icon: path.join(dir, 'nope.png') }, game: { icon: null }, appDir, warn: () => {} }), /icon not found/);
});

test('buildDesktop writes the electron app then calls builder.build for one platform', async () => {
    const webDir = tmpDir();
    fs.writeFileSync(path.join(webDir, 'index.html'), 'x');
    const appDir = path.join(tmpDir(), 'electron-app');
    const calls = [];
    const fakeBuilder = {
        Platform: { LINUX: { createTarget: (t) => ({ linux: t }) }, MAC: { createTarget: (t) => ({ mac: t }) }, WINDOWS: { createTarget: (t) => ({ win: t }) } },
        build: async (opts) => calls.push(opts)
    };
    await buildDesktop({ config: CONFIG, game: { icon: null }, target: 'linux', webDir, appDir, outDir: '/o', log: () => {}, warn: () => {} }, fakeBuilder);
    assert.ok(fs.existsSync(path.join(appDir, 'web', 'index.html')));
    assert.equal(calls.length, 1);
    assert.equal(calls[0].projectDir, appDir);
    assert.deepEqual(calls[0].targets, { linux: ['AppImage'] });
    assert.equal(calls[0].config.directories.output, '/o');
});
```

- [ ] **Step 2: Run them to make sure they fail**

Run: `cd packages/standalone && npm test`
Expected: FAIL, `Cannot find module '../lib/desktopBuild'`.

- [ ] **Step 3: Implement `lib/desktopBuild.js`**

```js
'use strict';
const fs = require('node:fs');
const path = require('node:path');
const { writeElectronApp } = require('./electronApp');
const { isUsableIcon, MIN_ICON_SIZE } = require('./icon');

const FORMATS = { mac: ['dmg'], win: ['nsis'], linux: ['AppImage'] };
const SIZE = `${MIN_ICON_SIZE}x${MIN_ICON_SIZE}`;

function builderConfig({ config, outDir, iconPath, electronVersion }) {
    const icon = iconPath ? { icon: iconPath } : {};
    return {
        appId: config.appId,
        productName: config.productName,
        electronVersion,
        directories: { output: outDir },
        files: ['main.js', 'preload.js', 'bge-app.json', 'package.json', 'web/**/*'],
        // identity: null = unsigned; signing is a follow-up.
        mac: { target: FORMATS.mac, category: 'public.app-category.games', identity: null, ...icon },
        win: { target: FORMATS.win, ...icon },
        linux: { target: FORMATS.linux, category: 'Game', ...icon }
    };
}

function pickIcon({ config, game, appDir, warn }) {
    const dest = path.join(appDir, 'icon.png');
    if (config.icon) {
        if (!fs.existsSync(config.icon)) {
            throw new Error(`icon not found: ${config.icon}`);
        }
        const data = fs.readFileSync(config.icon);
        if (!isUsableIcon(data)) {
            throw new Error(`${config.icon} must be a PNG of at least ${SIZE}`);
        }
        fs.writeFileSync(dest, data);
        return dest;
    }
    if (game.icon && isUsableIcon(game.icon.data)) {
        fs.writeFileSync(dest, game.icon.data);
        return dest;
    }
    if (game.icon) {
        warn(`warning: the manifest icon is smaller than ${SIZE}; using Electron's default icon (set "icon" in bge-standalone.json)`);
    }
    return null;
}

async function buildDesktop({ config, game, target, webDir, appDir, outDir, log, warn }, builder = require('electron-builder')) {
    writeElectronApp({ config, webDir, appDir });
    // After writeElectronApp, which empties appDir.
    const iconPath = pickIcon({ config, game, appDir, warn });
    const platform = { mac: builder.Platform.MAC, win: builder.Platform.WINDOWS, linux: builder.Platform.LINUX }[target];
    log(`packaging ${target} (${FORMATS[target].join(', ')})...`);
    await builder.build({
        projectDir: appDir,
        targets: platform.createTarget(FORMATS[target]),
        config: builderConfig({ config, outDir, iconPath, electronVersion: require('electron/package.json').version })
    });
}

module.exports = { builderConfig, pickIcon, buildDesktop };
```

- [ ] **Step 4: Wire it into the CLI**

In `lib/cli.js`, delete `notImplementedDesktop` and require the real one lazily, so `build --target web` never loads electron-builder:

```js
function defaults() {
    return {
        cwd: process.cwd(),
        platform: process.platform,
        log: (m) => console.log(m),
        warn: (m) => console.error(m),
        buildDesktop: (args) => require('./desktopBuild').buildDesktop(args)
    };
}
```

- [ ] **Step 5: Run the tests and make sure they pass**

Run: `cd packages/standalone && npm test`
Expected: all pass.

- [ ] **Step 6: Real build on this machine (manual check from the spec)**

```bash
cd packages/standalone
node bin/bge-standalone.js build --zip ../../examples/pong/out/bge-pong.zip --out test-output
```

Expected on macOS: `test-output/desktop/Example Game - Pong-1.1.0*.dmg` exists, plus a warning about the small manifest icon. Install it from the dmg and launch it (right-click → Open past Gatekeeper, since it's unsigned). Then check:
- [ ] pong plays with the keyboard;
- [ ] pong plays with a gamepad, analog stick included;
- [ ] F11 toggles fullscreen;
- [ ] quitting the game closes the app.

If loading from inside the asar fails (blank window, `net.fetch` errors in DevTools with `BGE_STANDALONE_DEBUG=1`), add `asar: false` to `builderConfig`, update its test, and note why in a comment.

- [ ] **Step 7: Commit**

```bash
git add packages/standalone/lib/desktopBuild.js packages/standalone/lib/cli.js packages/standalone/test/desktopBuild.test.js
git commit -m "bge-standalone: package desktop apps with electron-builder (#235)"
```

---

### Task 9: SceneGraph opt-in

**Files:**
- Modify: `packages/standalone/lib/webBundle.js`, `packages/standalone/test/webBundle.test.js`

**Interfaces:**
- Consumes: `config.sceneGraph` (Task 4); `runtime.js` already registers `./brs-sg.js` when `settings.sceneGraph` is set (Task 2).
- Produces: when `config.sceneGraph` is true, `writeWebBundle` also writes `lib/brs-sg.js` and overwrites `assets/common.zip` with brs-scenegraph's copy. If `brs-scenegraph` can't be resolved, it throws `sceneGraph is on but brs-scenegraph is not installed: npm install --save-dev brs-scenegraph`.

- [ ] **Step 1: Add the failing tests to `test/webBundle.test.js`**

```js
function fakeSceneGraphDir() {
    const dir = tmpDir();
    fs.mkdirSync(path.join(dir, 'lib'));
    fs.mkdirSync(path.join(dir, 'assets'));
    fs.writeFileSync(path.join(dir, 'lib', 'brs-sg.js'), 'sg');
    fs.writeFileSync(path.join(dir, 'assets', 'common.zip'), 'sg-common');
    return dir;
}

test('sceneGraph adds brs-sg.js and swaps in its common.zip', async () => {
    const { config, webDir } = await setup({ sceneGraph: true });
    const engine = fakeEngineDir();
    const sg = fakeSceneGraphDir();
    const files = writeWebBundle({ config, webDir, packageDir: (name) => (name === 'brs-engine' ? engine : sg) });
    assert.ok(files.includes('lib/brs-sg.js'));
    assert.equal(fs.readFileSync(path.join(webDir, 'assets', 'common.zip'), 'utf8'), 'sg-common');
    assert.match(fs.readFileSync(path.join(webDir, 'index.html'), 'utf8'), /\{"sceneGraph":true\}/);
});

test('sceneGraph without brs-scenegraph installed gives an install hint', async () => {
    const { config, webDir } = await setup({ sceneGraph: true });
    const engine = fakeEngineDir();
    const packageDir = (name) => {
        if (name === 'brs-engine') {
            return engine;
        }
        const e = new Error(`Cannot find module '${name}/package.json'`);
        e.code = 'MODULE_NOT_FOUND';
        throw e;
    };
    assert.throws(() => writeWebBundle({ config, webDir, packageDir }), /npm install --save-dev brs-scenegraph/);
});
```

- [ ] **Step 2: Run them to make sure they fail**

Run: `cd packages/standalone && npm test`
Expected: the two new tests FAIL (no `lib/brs-sg.js`; no throw).

- [ ] **Step 3: Implement it in `writeWebBundle`**

Insert after the three brs-engine copies:

```js
    if (config.sceneGraph) {
        let sceneGraph;
        try {
            sceneGraph = packageDir('brs-scenegraph');
        } catch (e) {
            if (e.code !== 'MODULE_NOT_FOUND') {
                throw e;
            }
            throw new Error('sceneGraph is on but brs-scenegraph is not installed: npm install --save-dev brs-scenegraph');
        }
        copy(path.join(sceneGraph, 'lib', 'brs-sg.js'), webDir, 'lib/brs-sg.js');
        // brs-scenegraph's common.zip is a superset of the core one (adds SceneGraph fonts/resources).
        copy(path.join(sceneGraph, 'assets', 'common.zip'), webDir, 'assets/common.zip');
    }
```

- [ ] **Step 4: Run the tests and make sure they pass**

Run: `cd packages/standalone && npm test`
Expected: all pass.

- [ ] **Step 5: Manual check with a SceneGraph example**

```bash
(cd examples/scenegraph && npm run package)
cd packages/standalone
echo '{"zip":"../../examples/scenegraph/out/bge-scenegraph.zip","sceneGraph":true,"targets":["web"],"outDir":"test-output"}' > test-output/sg.json
node bin/bge-standalone.js build --config test-output/sg.json
node bin/bge-standalone.js serve test-output/web
```

Open `http://127.0.0.1:6502/?debug=1`. Expected: the SceneGraph example renders. Write the result into the spec's "Spike results" section (SceneGraph is beta in brs-engine, so record any problems, open issues for them, and don't block on them).

- [ ] **Step 6: Commit**

```bash
git add packages/standalone/lib/webBundle.js packages/standalone/test/webBundle.test.js specs/2026-11-22-standalone-builds-design.md
git commit -m "bge-standalone: opt-in SceneGraph via brs-scenegraph (#235)"
```

---

### Task 10: Docs and README

**Files:**
- Create: `docs/standalone-builds.md`, `packages/standalone/README.md`
- Modify: `README.md` (root): add one line linking the guide wherever other guides are listed (check with `grep -n "docs/" README.md`)

- [ ] **Step 1: Write `docs/standalone-builds.md`**

Frontmatter is required (see `.claude/rules/docs-site.md`). Pick `order` as one more than the highest `order:` in `docs/*.md` (`grep -h "^order:" docs/*.md | sort -n -k2 | tail -1`).

```markdown
---
title: Standalone Builds
group: Guides
order: <next>
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

This writes `dist/web/` and, for your current OS, a desktop installer in `dist/desktop/`.
Pick targets with `--target web`, `--target mac`, `--target win`, `--target linux`
or `--target all` (web plus your OS). Desktop installers can only be built on their own
OS; use a CI matrix (one job per OS) to build all three.

Try the web build locally:

    npx bge-standalone serve

## Config

All fields in `bge-standalone.json` (next to your `package.json`) are optional:

| Field | Default | |
| --- | --- | --- |
| `zip` | — | Path to the built channel zip (or pass `--zip`). |
| `productName` | manifest `title` | App and window name. |
| `appId` | `com.bge.<title>` | Reverse-DNS app id. |
| `version` | manifest `major.minor.build` | |
| `icon` | manifest `mm_icon_focus_hd` if ≥ 512×512 | PNG, at least 512×512. Roku icons are smaller, so set this. |
| `sceneGraph` | `false` | Bundle SceneGraph support (`npm install --save-dev brs-scenegraph`). Only needed if your game mixes in SceneGraph nodes. |
| `window` | `{ "width": 1280, "height": 720, "fullscreen": false, "resizable": true }` | Desktop window. F11 toggles fullscreen. |
| `targets` | `["web", "<your OS>"]` | |
| `outDir` | `dist` | |

## Gamepads

brs-engine maps a connected gamepad to the remote: A is OK, B is Back, and the
d-pad and sticks are the arrows. Add `multi_controllers=1` to your manifest to
get X/Y/L1/R1/L2/R2 and real analog sticks, which `game.controls` reads automatically.
See [Controller Input](/controller-input). The phone controller page
(`enableControllerInput()`) does not work in standalone builds, because browsers
can't open the socket it needs.

## Hosting the web build

brs-engine needs `SharedArrayBuffer`, so the page must be served with these headers:

    Cross-Origin-Opener-Policy: same-origin
    Cross-Origin-Embedder-Policy: require-corp

On itch.io, upload `dist/web` as a zip, set it to "This file will be played in the browser"
and turn on "SharedArrayBuffer support". Opening `index.html` directly from disk does not work.

## Unsigned apps

Desktop builds are not code-signed. On macOS, right-click the app and choose
Open the first time. On Windows, choose More info → Run anyway on the SmartScreen prompt.

## Troubleshooting

Add `?debug=1` to the web URL, or set `BGE_STANDALONE_DEBUG=1` before launching the
desktop app, to see `print` output and engine errors in the DevTools console and
a frame-rate overlay.
```

Update the itch.io wording and any table rows if Tasks 2–9 found different behavior (for example, if `components/` gets stripped).

- [ ] **Step 2: Write `packages/standalone/README.md`**

A short version of the guide: one paragraph on what it is, then install, `build`, `serve`, the config table, and a link to the full guide at `https://markwpearce.github.io/brighterscript-game-engine/standalone-builds`. Copy the config table from Step 1 exactly.

- [ ] **Step 3: Check the docs build and the engine checks**

```bash
npm run docs
npm run check
npm run standalone:test
```

Expected: docs build without errors and `docs-site/` has a Standalone Builds page; `check` and `standalone:test` pass.

- [ ] **Step 4: Commit**

```bash
git add docs/standalone-builds.md packages/standalone/README.md README.md
git commit -m "Docs: standalone web and desktop builds (#235)"
```

---

## Done when

- `npm run standalone:test` passes, and the Standalone Builds workflow (unit tests and pong e2e) is green on the PR.
- The manual desktop check in Task 8, Step 6 is ticked on macOS.
- The spec has a "Spike results" section, and engine problems found have issues filed.
- The PR body lists the follow-ups: mobile, signing, a CI matrix action, and publishing `bge-standalone`.
