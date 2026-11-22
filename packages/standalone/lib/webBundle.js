'use strict';
const fs = require('node:fs');
const path = require('node:path');

const TEMPLATE_DIR = path.join(__dirname, '..', 'template', 'web');

function defaultPackageDir(name) {
    return path.dirname(require.resolve(`${name}/package.json`));
}

function escapeHtml(s) {
    return String(s)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;');
}

function copy(from, webDir, rel) {
    const to = path.join(webDir, ...rel.split('/'));
    fs.mkdirSync(path.dirname(to), { recursive: true });
    fs.copyFileSync(from, to);
}

/**
 * Writes the static Draw 2D web bundle (`index.html`, `runtime.js`, `game.zip`, brs-engine files).
 * Empties `webDir` first.
 * @param {{ config: ResolvedConfig, webDir: string, packageDir?: (name: string) => string }} options
 * @returns {string[]} sorted, `/`-separated paths of the written files, relative to `webDir`
 */
function writeWebBundle({ config, webDir, packageDir = defaultPackageDir }) {
    if (!fs.existsSync(config.zip)) {
        throw new Error(`game zip not found: ${config.zip}`);
    }
    fs.rmSync(webDir, { recursive: true, force: true });
    fs.mkdirSync(webDir, { recursive: true });

    const engine = packageDir('brs-engine');
    copy(path.join(engine, 'lib', 'brs.api.js'), webDir, 'lib/brs.api.js');
    copy(path.join(engine, 'lib', 'brs.worker.js'), webDir, 'lib/brs.worker.js');
    copy(path.join(engine, 'assets', 'common.zip'), webDir, 'assets/common.zip');

    copy(config.zip, webDir, 'game.zip');
    copy(path.join(TEMPLATE_DIR, 'runtime.js'), webDir, 'runtime.js');

    // "<" is escaped so the JSON can't close the <script> it sits in.
    const settings = JSON.stringify({ sceneGraph: config.sceneGraph }).replace(/</g, '\\u003c');
    const values = { TITLE: escapeHtml(config.productName), SETTINGS_JSON: settings };
    // One pass with a replacer function: values are inserted literally (no "$&" expansion)
    // and a value can't be re-scanned for placeholders.
    const html = fs
        .readFileSync(path.join(TEMPLATE_DIR, 'index.html'), 'utf8')
        .replace(/\{\{(TITLE|SETTINGS_JSON)\}\}/g, (_, key) => values[key]);
    fs.writeFileSync(path.join(webDir, 'index.html'), html);

    return listFiles(webDir);
}

function listFiles(dir, prefix = '') {
    const out = [];
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
        const rel = prefix ? `${prefix}/${entry.name}` : entry.name;
        if (entry.isDirectory()) {
            out.push(...listFiles(path.join(dir, entry.name), rel));
        } else {
            out.push(rel);
        }
    }
    return out.sort();
}

module.exports = { writeWebBundle, escapeHtml };
