#!/usr/bin/env node
// Serves the generated docs-site/ locally under the same basePath (opts.basePath
// in jsdoc.json) it's actually deployed at on GitHub Pages - every generated
// link/asset href is basePath-prefixed, so serving docs-site/ directly at a
// server's root 404s on all of them. Mirrors docs-site/ into a temp directory
// nested under that basePath, then serves the temp directory's parent.

const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawn } = require('child_process');

const ROOT_DIR = path.join(__dirname, '..');
const DOCS_SITE_DIR = path.join(ROOT_DIR, 'docs-site');
const PORT = process.env.PORT || '8080';

function getBasePath() {
    const jsdocConfig = JSON.parse(fs.readFileSync(path.join(ROOT_DIR, 'jsdoc.json'), 'utf8'));
    const basePath = jsdocConfig.opts?.basePath;
    if (typeof basePath !== 'string' || basePath.trim().length === 0 || basePath === '/') {
        return '';
    }
    return '/' + basePath.replace(/^\/+/, '').replace(/\/+$/, '');
}

function main() {
    if (!fs.existsSync(DOCS_SITE_DIR)) {
        console.error(`docs-site/ not found at ${DOCS_SITE_DIR} - run "npm run docs" first.`);
        process.exit(1);
    }

    const basePath = getBasePath();
    const previewRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'bge-docs-preview-'));
    const mountDir = path.join(previewRoot, ...basePath.split('/').filter(Boolean));

    fs.mkdirSync(path.dirname(mountDir), { recursive: true });
    fs.cpSync(DOCS_SITE_DIR, mountDir, { recursive: true });

    const url = `http://localhost:${PORT}${basePath}/`;
    console.log(`Serving docs-site/ under ${basePath || '/'} - opening ${url}`);

    const child = spawn('npx', ['http-server', previewRoot, '-p', PORT, '-o', `${basePath}/`], {
        stdio: 'inherit',
        shell: process.platform === 'win32',
    });

    const cleanup = () => {
        fs.rmSync(previewRoot, { recursive: true, force: true });
    };
    process.on('exit', cleanup);
    process.on('SIGINT', () => {
        cleanup();
        process.exit(0);
    });

    child.on('exit', (code) => {
        cleanup();
        process.exit(code ?? 0);
    });
}

main();
