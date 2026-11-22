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

test('parseManifest strips a leading UTF-8 BOM', () => {
    assert.equal(parseManifest('\uFEFFtitle=Pong\nmajor_version=1').title, 'Pong');
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
