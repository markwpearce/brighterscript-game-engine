'use strict';
const fs = require('node:fs');
const path = require('node:path');

const DESKTOP_TARGETS = ['mac', 'win', 'linux'];
const ALL_TARGETS = ['web', ...DESKTOP_TARGETS];
const OS_NAMES = { mac: 'macOS', win: 'Windows', linux: 'Linux' };
const FILE_KEYS = ['zip', 'appId', 'productName', 'version', 'icon', 'sceneGraph', 'window', 'targets', 'outDir'];
const WINDOW_DEFAULTS = { width: 1280, height: 720, fullscreen: false, resizable: true };

function loadConfigFile(file, required) {
    if (!fs.existsSync(file)) {
        if (required) {
            throw new Error(`config file not found: ${file}`);
        }
        return {};
    }
    try {
        return JSON.parse(fs.readFileSync(file, 'utf8'));
    } catch (e) {
        throw new Error(`${file}: invalid JSON (${e.message})`);
    }
}

function resolveZipPath({ cli, file, cwd }) {
    const zip = cli.zip || file.zip;
    if (!zip) {
        throw new Error('no game zip: pass --zip <path> or set "zip" in bge-standalone.json');
    }
    return path.resolve(cwd, zip);
}

function hostOs(platform = process.platform) {
    if (platform === 'darwin') {
        return 'mac';
    }
    if (platform === 'win32') {
        return 'win';
    }
    return 'linux';
}

function resolveTargets(requested, platform) {
    const host = hostOs(platform);
    let list;
    if (requested === undefined) {
        list = ['web', host];
    } else {
        list = Array.isArray(requested) ? requested : String(requested).split(',');
        list = list.map((t) => t.trim()).filter(Boolean);
        if (list.includes('all')) {
            list = ['web', host];
        }
    }
    for (const t of list) {
        if (!ALL_TARGETS.includes(t)) {
            throw new Error(`unknown target "${t}" (use web, mac, win, linux or all)`);
        }
        if (t !== 'web' && t !== host) {
            throw new Error(`build ${t} targets on ${OS_NAMES[t]} (or use a CI OS matrix); this machine is ${OS_NAMES[host]}`);
        }
    }
    return ALL_TARGETS.filter((t) => list.includes(t));
}

function slug(title) {
    return title.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '') || 'game';
}

function checkType(name, value, kind) {
    if (value === undefined) {
        return;
    }
    const ok = kind === 'number' ? typeof value === 'number' && value > 0 : typeof value === kind;
    if (!ok) {
        throw new Error(`"${name}" must be a ${kind === 'number' ? 'positive number' : kind}`);
    }
}

function validateFile(file) {
    for (const key of Object.keys(file)) {
        if (!FILE_KEYS.includes(key)) {
            throw new Error(`unknown config field "${key}"`);
        }
    }
    for (const key of ['zip', 'appId', 'productName', 'version', 'icon', 'outDir']) {
        checkType(key, file[key], 'string');
    }
    checkType('sceneGraph', file.sceneGraph, 'boolean');
    if (file.version !== undefined && !/^\d+\.\d+\.\d+$/.test(file.version)) {
        throw new Error('"version" must be x.y.z');
    }
    if (file.targets !== undefined && !Array.isArray(file.targets)) {
        throw new Error('"targets" must be an array');
    }
    if (file.window !== undefined) {
        if (typeof file.window !== 'object' || file.window === null) {
            throw new Error('"window" must be an object');
        }
        for (const key of Object.keys(file.window)) {
            if (!(key in WINDOW_DEFAULTS)) {
                throw new Error(`unknown config field "window.${key}"`);
            }
        }
        checkType('window.width', file.window.width, 'number');
        checkType('window.height', file.window.height, 'number');
        checkType('window.fullscreen', file.window.fullscreen, 'boolean');
        checkType('window.resizable', file.window.resizable, 'boolean');
    }
}

function resolveConfig({ cli, file, game, platform, cwd }) {
    validateFile(file);
    return {
        zip: resolveZipPath({ cli, file, cwd }),
        appId: file.appId || `com.bge.${slug(game.title)}`,
        productName: file.productName || game.title,
        version: file.version || game.version,
        icon: file.icon ? path.resolve(cwd, file.icon) : null,
        sceneGraph: file.sceneGraph === true,
        window: { ...WINDOW_DEFAULTS, ...(file.window || {}) },
        targets: resolveTargets(cli.target !== undefined ? cli.target : file.targets, platform),
        outDir: path.resolve(cwd, cli.out || file.outDir || 'dist')
    };
}

module.exports = { loadConfigFile, resolveZipPath, hostOs, resolveTargets, resolveConfig, DESKTOP_TARGETS };
