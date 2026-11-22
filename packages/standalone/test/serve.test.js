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
        server.closeAllConnections();
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

test('malformed percent-encoding gets 400 and does not kill the server', async () => {
    const root = tmpDir();
    fs.writeFileSync(path.join(root, 'index.html'), '<p>hi</p>');
    await withServer(root, async (base) => {
        const bad = await fetch(`${base}/%zz`);
        assert.equal(bad.status, 400);
        assert.equal(bad.headers.get('cross-origin-embedder-policy'), 'require-corp');
        assert.equal((await fetch(`${base}/`)).status, 200);
    });
});

test('a NUL byte in the path gets 400 or 404 and does not kill the server', async () => {
    const root = tmpDir();
    fs.writeFileSync(path.join(root, 'index.html'), '<p>hi</p>');
    await withServer(root, async (base) => {
        const nul = await fetch(`${base}/a%00b`);
        assert.ok([400, 404].includes(nul.status), `unexpected status ${nul.status}`);
        assert.equal((await fetch(`${base}/`)).status, 200);
    });
});
