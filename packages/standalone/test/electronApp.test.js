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

test('resolveRequest returns null for malformed URLs and NUL bytes', () => {
    const appDir = path.join(tmpDir(), 'electron-app');
    writeElectronApp({ config: CONFIG, webDir: webDir(), appDir });
    const { resolveRequest } = require(path.join(appDir, 'main.js'));
    const root = path.join(appDir, 'web');
    assert.equal(resolveRequest(root, 'app://game/%zz'), null);
    assert.equal(resolveRequest(root, 'app://game/a%00b'), null);
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
