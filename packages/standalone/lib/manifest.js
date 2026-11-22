'use strict';
const path = require('node:path');
const JSZip = require('jszip');

function parseManifest(text) {
    const out = {};
    for (const raw of text.replace(/^\uFEFF/, '').split(/\r?\n/)) {
        const line = raw.trim();
        if (!line || line.startsWith('#')) {
            continue;
        }
        const eq = line.indexOf('=');
        if (eq <= 0) {
            continue;
        }
        out[line.slice(0, eq).trim()] = line.slice(eq + 1).trim();
    }
    return out;
}

async function readGameZip(zipBuffer) {
    const zip = await JSZip.loadAsync(zipBuffer);
    const manifestFile = zip.file('manifest');
    if (!manifestFile) {
        throw new Error('zip has no manifest at its root');
    }
    const manifest = parseManifest(await manifestFile.async('string'));
    let icon = null;
    const iconUri = manifest.mm_icon_focus_hd || '';
    if (iconUri.startsWith('pkg:/')) {
        const entry = zip.file(iconUri.slice('pkg:/'.length));
        if (entry) {
            icon = { name: path.posix.basename(entry.name), data: await entry.async('nodebuffer') };
        }
    }
    return { manifest, icon };
}

function gameInfo(manifest) {
    const part = (key) => String(parseInt(manifest[key], 10) || 0);
    return {
        title: manifest.title || 'BGE Game',
        version: `${part('major_version')}.${part('minor_version')}.${part('build_version')}`,
        multiControllers: manifest.multi_controllers === '1'
    };
}

module.exports = { parseManifest, readGameZip, gameInfo };
