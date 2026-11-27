'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const sharp = require('sharp');
const { pngSize, isUsableIcon, letterboxIcon } = require('../lib/icon');
const { fakePng } = require('./helpers');

function solid(width, height, format = 'png') {
    return sharp({ create: { width, height, channels: 4, background: { r: 255, g: 0, b: 0, alpha: 1 } } })[format]().toBuffer();
}

async function pixels(buf) {
    const { data, info } = await sharp(buf).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
    const at = (x, y) => Array.from(data.subarray((y * info.width + x) * 4, (y * info.width + x) * 4 + 4));
    return { info, at };
}

test('pngSize reads IHDR width/height', () => {
    assert.deepEqual(pngSize(fakePng(336, 210)), { width: 336, height: 210 });
});

test('pngSize returns null for non-PNG or short data', () => {
    assert.equal(pngSize(Buffer.from('GIF89a................')), null);
    assert.equal(pngSize(Buffer.alloc(4)), null);
});

test('isUsableIcon needs a square PNG of at least 512x512', () => {
    assert.equal(isUsableIcon(fakePng(512, 512)), true);
    assert.equal(isUsableIcon(fakePng(1024, 1024)), true);
    assert.equal(isUsableIcon(fakePng(1024, 512)), false);
    assert.equal(isUsableIcon(fakePng(336, 210)), false);
    assert.equal(isUsableIcon(Buffer.from('nope')), false);
});

test('letterboxIcon fits a wide icon into 512x512 with transparent top/bottom bars', async () => {
    // 336x210 scales to 512x320, leaving 96px bars top and bottom.
    const { info, at } = await pixels(await letterboxIcon(await solid(336, 210)));
    assert.equal(info.width, 512);
    assert.equal(info.height, 512);
    assert.equal(at(256, 10)[3], 0);
    assert.equal(at(256, 500)[3], 0);
    assert.deepEqual(at(256, 256), [255, 0, 0, 255]);
    assert.deepEqual(at(5, 256), [255, 0, 0, 255], 'full width is used');
});

test('letterboxIcon fits a tall icon with transparent side bars', async () => {
    const { at } = await pixels(await letterboxIcon(await solid(100, 200)));
    assert.equal(at(10, 256)[3], 0);
    assert.deepEqual(at(256, 5), [255, 0, 0, 255], 'full height is used');
});

test('letterboxIcon accepts JPEG input', async () => {
    const { info } = await pixels(await letterboxIcon(await solid(290, 218, 'jpeg')));
    assert.equal(info.width, 512);
    assert.equal(info.height, 512);
});

test('letterboxIcon rejects data it cannot decode', async () => {
    await assert.rejects(letterboxIcon(fakePng(336, 210)));
});
