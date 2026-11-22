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
    let text;
    try {
        text = fs.readFileSync(file, 'utf8');
    } catch (e) {
        throw new Error(`${file}: ${e.message}`);
    }
    let parsed;
    try {
        parsed = JSON.parse(text.replace(/^\uFEFF/, '')); // Windows editors write a BOM
    } catch (e) {
        throw new Error(`${file}: invalid JSON (${e.message})`);
    }
    if (!isObject(parsed)) {
        throw new Error(`${file}: must be a JSON object`);
    }
    return parsed;
}

function isObject(value) {
    return typeof value === 'object' && value !== null && !Array.isArray(value);
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
    if (list.length === 0) {
        throw new Error('no targets selected (use web, mac, win, linux or all)');
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
    if (!isObject(file)) {
        throw new Error('config must be a JSON object');
    }
    for (const key of Object.keys(file)) {
        if (!FILE_KEYS.includes(key)) {
            throw new Error(`unknown config field "${key}"`);
        }
    }
    for (const key of ['zip', 'appId', 'productName', 'version', 'icon', 'outDir']) {
        checkType(key, file[key], 'string');
    }
    checkType('sceneGraph', file.sceneGraph, 'boolean');
    if (file.appId !== undefined && !/^[a-zA-Z0-9-]+(\.[a-zA-Z0-9-]+)+$/.test(file.appId)) {
        throw new Error('"appId" must be reverse-DNS, like com.example.mygame');
    }
    if (file.version !== undefined && !/^\d+\.\d+\.\d+$/.test(file.version)) {
        throw new Error('"version" must be x.y.z');
    }
    if (file.targets !== undefined && (!Array.isArray(file.targets) || !file.targets.every((t) => typeof t === 'string'))) {
        throw new Error('"targets" must be an array of strings');
    }
    if (file.window !== undefined) {
        if (typeof file.window !== 'object' || file.window === null) {
            throw new Error('"window" must be an object');
        }
        for (const key of Object.keys(file.window)) {
            if (!Object.hasOwn(WINDOW_DEFAULTS, key)) {
                throw new Error(`unknown config field "window.${key}"`);
            }
        }
        checkType('window.width', file.window.width, 'number');
        checkType('window.height', file.window.height, 'number');
        checkType('window.fullscreen', file.window.fullscreen, 'boolean');
        checkType('window.resizable', file.window.resizable, 'boolean');
    }
}

function isInside(child, parent) {
    const rel = path.relative(parent, child);
    return rel === '' || (!rel.startsWith('..') && !path.isAbsolute(rel));
}

function resolveConfig({ cli, file, game, platform, cwd }) {
    validateFile(file);
    const zip = resolveZipPath({ cli, file, cwd });
    const outDir = path.resolve(cwd, cli.out || file.outDir || 'dist');
    // The build deletes <outDir>/web and <outDir>/electron-app, so keep it away from the project.
    if (isInside(cwd, outDir)) {
        throw new Error('"outDir" must be a dedicated folder, not the project folder or a parent of it');
    }
    if (isInside(zip, outDir)) {
        throw new Error(`game zip must not be inside "outDir" (${outDir}); the build deletes that folder`);
    }
    return {
        zip,
        appId: file.appId || `com.bge.${slug(game.title)}`,
        productName: file.productName || game.title,
        version: file.version || game.version,
        icon: file.icon ? path.resolve(cwd, file.icon) : null,
        sceneGraph: file.sceneGraph === true,
        window: { ...WINDOW_DEFAULTS, ...(file.window || {}) },
        targets: resolveTargets(cli.target !== undefined ? cli.target : file.targets, platform),
        outDir
    };
}

module.exports = { loadConfigFile, resolveZipPath, hostOs, resolveTargets, resolveConfig, DESKTOP_TARGETS };
