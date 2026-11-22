'use strict';
const path = require('node:path');
const { pathToFileURL } = require('node:url');

const ISOLATION_HEADERS = {
    'Cross-Origin-Opener-Policy': 'same-origin',
    'Cross-Origin-Embedder-Policy': 'require-corp',
    'Cross-Origin-Resource-Policy': 'same-origin'
};

function resolveRequest(webRoot, url) {
    let rel;
    try {
        rel = decodeURIComponent(new URL(url).pathname).replace(/^\/+/, '') || 'index.html';
    } catch {
        // Malformed URL or percent-encoding (e.g. "/%zz").
        return null;
    }
    // Backslashes and drive letters are path syntax on Windows: reject on every OS.
    if (rel.includes('\0') || rel.includes('\\') || /^[a-zA-Z]:/.test(rel)) {
        return null;
    }
    const file = path.resolve(webRoot, rel);
    if (!file.startsWith(webRoot + path.sep)) {
        return null;
    }
    return file;
}

function respond(body, init) {
    const headers = new Headers(init.headers);
    for (const [key, value] of Object.entries(ISOLATION_HEADERS)) {
        headers.set(key, value);
    }
    return new Response(body, { status: init.status, headers });
}

async function handleRequest(webRoot, url, fetchFile) {
    const file = resolveRequest(webRoot, url);
    if (!file) {
        return respond('Not found', { status: 404 });
    }
    let res;
    try {
        res = await fetchFile(pathToFileURL(file).toString());
    } catch {
        return respond('Not found', { status: 404 });
    }
    return respond(res.body, { status: res.status, headers: res.headers });
}

function start() {
    const { app, BrowserWindow, Menu, ipcMain, net, protocol } = require('electron');
    const settings = require('./bge-app.json');
    const webRoot = path.join(__dirname, 'web');
    const debug = process.env.BGE_STANDALONE_DEBUG === '1';

    // brs-engine needs SharedArrayBuffer: a secure, cross-origin-isolated origin.
    protocol.registerSchemesAsPrivileged([
        { scheme: 'app', privileges: { standard: true, secure: true, supportFetchAPI: true, corsEnabled: true, stream: true } }
    ]);

    app.whenReady().then(() => {
        protocol.handle('app', (request) => handleRequest(webRoot, request.url, (fileUrl) => net.fetch(fileUrl)));

        ipcMain.on('bge:quit', () => app.quit());
        if (process.platform !== 'darwin') {
            Menu.setApplicationMenu(null);
        }

        const win = new BrowserWindow({
            title: settings.title,
            width: settings.window.width,
            height: settings.window.height,
            fullscreen: settings.window.fullscreen,
            resizable: settings.window.resizable,
            backgroundColor: '#000000',
            autoHideMenuBar: true,
            webPreferences: {
                preload: path.join(__dirname, 'preload.js'),
                contextIsolation: true,
                nodeIntegration: false,
                sandbox: true
            }
        });
        win.webContents.on('before-input-event', (event, input) => {
            if (input.type === 'keyDown' && !input.isAutoRepeat && input.key === 'F11') {
                win.setFullScreen(!win.isFullScreen());
                event.preventDefault();
            }
        });
        if (debug) {
            win.webContents.openDevTools({ mode: 'detach' });
        }
        win.loadURL(`app://game/index.html${debug ? '?debug=1' : ''}`);
    });

    app.on('window-all-closed', () => app.quit());
}

if (process.versions.electron) {
    start();
}

module.exports = { resolveRequest, handleRequest };
