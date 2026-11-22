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
