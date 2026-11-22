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
