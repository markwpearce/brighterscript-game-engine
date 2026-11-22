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
