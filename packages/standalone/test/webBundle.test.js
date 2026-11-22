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
