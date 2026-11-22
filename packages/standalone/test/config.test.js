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

test('loadConfigFile: a non-object JSON value names the file', () => {
    const dir = tmpDir();
    for (const [name, text] of [['null.json', 'null'], ['arr.json', '[1,2]'], ['num.json', '42']]) {
        const file = path.join(dir, name);
        fs.writeFileSync(file, text);
        assert.throws(() => loadConfigFile(file, false), new RegExp(`${name.replace('.', '\\.')}: must be a JSON object`));
    }
});

test('loadConfigFile: strips a leading UTF-8 BOM before parsing', () => {
    const dir = tmpDir();
    const file = path.join(dir, 'bom.json');
    fs.writeFileSync(file, '﻿{"zip":"g.zip"}');
    assert.deepEqual(loadConfigFile(file, false), { zip: 'g.zip' });
});

test('loadConfigFile: a read error is reported as a read error, not invalid JSON', () => {
    const dir = tmpDir();
    assert.throws(() => loadConfigFile(dir, false), (e) => {
        assert.match(e.message, new RegExp(`^${dir.replace(/[\\^$.*+?()[\]{}|]/g, '\\$&')}: `));
        assert.doesNotMatch(e.message, /invalid JSON/);
        return true;
    });
});

test('resolveConfig: a non-object file is a named error, not a TypeError', () => {
    const base = { cli: {}, game: GAME, platform: 'linux', cwd: CWD };
    for (const file of [null, [], 'str']) {
        assert.throws(() => resolveConfig({ ...base, file }), /config must be a JSON object/);
    }
});

test('resolveConfig rejects inherited object keys as unknown window fields', () => {
    const base = { cli: {}, game: GAME, platform: 'linux', cwd: CWD };
    assert.throws(() => resolveConfig({ ...base, file: { zip: 'g.zip', window: { constructor: 1 } } }), /unknown config field "window.constructor"/);
    assert.throws(() => resolveConfig({ ...base, file: { zip: 'g.zip', window: JSON.parse('{"__proto__":1}') } }), /unknown config field "window.__proto__"/);
});

test('resolveTargets: an empty selection throws instead of resolving to []', () => {
    assert.throws(() => resolveTargets('', 'linux'), /no targets selected/);
    assert.throws(() => resolveTargets(',', 'linux'), /no targets selected/);
    assert.throws(() => resolveTargets([], 'linux'), /no targets selected/);
});

test('resolveConfig: "targets" must be an array of strings', () => {
    const base = { cli: {}, game: GAME, platform: 'linux', cwd: CWD };
    assert.throws(() => resolveConfig({ ...base, file: { zip: 'g.zip', targets: [1] } }), /"targets" must be an array of strings/);
    assert.throws(() => resolveConfig({ ...base, file: { zip: 'g.zip', targets: [null] } }), /"targets" must be an array of strings/);
    assert.throws(() => resolveConfig({ ...base, file: { zip: 'g.zip', targets: [] } }), /no targets selected/);
});

test('resolveConfig rejects an outDir that is the project folder or a parent of it', () => {
    const base = { cli: {}, game: GAME, platform: 'linux', cwd: CWD };
    const msg = /"outDir" must be a dedicated folder, not the project folder or a parent of it/;
    assert.throws(() => resolveConfig({ ...base, file: { zip: 'g.zip', outDir: '.' } }), msg);
    assert.throws(() => resolveConfig({ ...base, file: { zip: 'g.zip', outDir: '..' } }), msg);
    assert.throws(() => resolveConfig({ ...base, cli: { out: path.resolve(CWD, '..', '..') }, file: { zip: 'g.zip' } }), msg);
    assert.doesNotThrow(() => resolveConfig({ ...base, file: { zip: 'g.zip', outDir: 'build/out' } }));
});

test('resolveConfig rejects a zip inside the folders the build deletes, but not elsewhere in outDir', () => {
    const base = { cli: {}, game: GAME, platform: 'linux', cwd: CWD };
    const out = path.join(CWD, 'out');
    assert.throws(
        () => resolveConfig({ ...base, file: { zip: 'out/web/game.zip', outDir: 'out' } }),
        (e) => e.message.includes(`the game zip is inside ${path.join(out, 'web')}, which the build deletes; move it or choose another outDir`)
    );
    assert.throws(
        () => resolveConfig({ ...base, file: { zip: 'out/electron-app/x.zip', outDir: 'out' } }),
        /inside .*electron-app, which the build deletes/
    );
    assert.doesNotThrow(() => resolveConfig({ ...base, file: { zip: 'out/game.zip', outDir: 'out' } }));
});

test('resolveConfig treats a folder named like "..proj" as a real child, not outside', () => {
    const parent = path.resolve('/tmp/a');
    const cwd = path.join(parent, '..proj');
    assert.throws(
        () => resolveConfig({ cli: {}, file: { zip: 'g.zip', outDir: parent }, game: GAME, platform: 'linux', cwd }),
        /"outDir" must be a dedicated folder/
    );
});

test('resolveConfig validates appId as reverse-DNS', () => {
    const base = { cli: {}, game: GAME, platform: 'linux', cwd: CWD };
    assert.throws(() => resolveConfig({ ...base, file: { zip: 'g.zip', appId: 'mygame' } }), /"appId" must be reverse-DNS, like com\.example\.mygame/);
    assert.throws(() => resolveConfig({ ...base, file: { zip: 'g.zip', appId: 'com.bad id' } }), /"appId" must be reverse-DNS/);
    assert.equal(resolveConfig({ ...base, file: { zip: 'g.zip', appId: 'com.Example.MyGame' } }).appId, 'com.Example.MyGame');
});
