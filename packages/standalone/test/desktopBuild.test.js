'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const sharp = require('sharp');
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

test('pickIcon copies a square 512+ manifest icon as-is, without a warning', async () => {
    const appDir = tmpDir();
    const warns = [];
    const big = fakePng(512, 512);
    const result = await pickIcon({ config: CONFIG, game: { icon: { name: 'i.png', data: big } }, appDir, warn: (m) => warns.push(m) });
    assert.equal(result, path.join(appDir, 'icon.png'));
    assert.deepEqual(fs.readFileSync(result), big);
    assert.deepEqual(warns, []);
});

test('pickIcon letterboxes a small manifest icon to 512x512 and warns', async () => {
    const appDir = tmpDir();
    const warns = [];
    const small = await sharp({ create: { width: 336, height: 210, channels: 4, background: '#0000ff' } }).png().toBuffer();
    const result = await pickIcon({ config: CONFIG, game: { icon: { name: 'i.png', data: small } }, appDir, warn: (m) => warns.push(m) });
    assert.equal(result, path.join(appDir, 'icon.png'));
    const meta = await sharp(result).metadata();
    assert.equal(meta.width, 512);
    assert.equal(meta.height, 512);
    assert.equal(warns.length, 1);
    assert.match(warns[0], /letterboxed to 512x512/);
});

test('pickIcon returns null with no manifest icon, and warns when it cannot be decoded', async () => {
    const appDir = tmpDir();
    const warns = [];
    assert.equal(await pickIcon({ config: CONFIG, game: { icon: null }, appDir, warn: (m) => warns.push(m) }), null);
    assert.deepEqual(warns, []);
    // fakePng is only a header, so sharp can't decode it.
    assert.equal(await pickIcon({ config: CONFIG, game: { icon: { name: 'i.png', data: fakePng(336, 210) } }, appDir, warn: (m) => warns.push(m) }), null);
    assert.match(warns[0], /could not convert the manifest icon/);
});

test('pickIcon prefers config.icon and rejects one that is unusable', async () => {
    const dir = tmpDir();
    const good = path.join(dir, 'good.png');
    fs.writeFileSync(good, fakePng(1024, 1024));
    const wide = path.join(dir, 'wide.png');
    fs.writeFileSync(wide, fakePng(1024, 512));
    const appDir = tmpDir();
    assert.equal(await pickIcon({ config: { ...CONFIG, icon: good }, game: { icon: null }, appDir, warn: () => {} }), path.join(appDir, 'icon.png'));
    await assert.rejects(pickIcon({ config: { ...CONFIG, icon: wide }, game: { icon: null }, appDir, warn: () => {} }), /wide\.png must be a square PNG of at least 512x512/);
    await assert.rejects(pickIcon({ config: { ...CONFIG, icon: path.join(dir, 'nope.png') }, game: { icon: null }, appDir, warn: () => {} }), /icon not found/);
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
