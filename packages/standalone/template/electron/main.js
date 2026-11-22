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
    if (rel.includes('\0')) {
        return null;
    }
    const file = path.resolve(webRoot, rel);
    if (!file.startsWith(webRoot + path.sep)) {
        return null;
    }
    return file;
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
        protocol.handle('app', async (request) => {
            const file = resolveRequest(webRoot, request.url);
            if (!file) {
                return new Response('Not found', { status: 404 });
            }
            const res = await net.fetch(pathToFileURL(file).toString());
            const headers = new Headers(res.headers);
            for (const [key, value] of Object.entries(ISOLATION_HEADERS)) {
                headers.set(key, value);
            }
            return new Response(res.body, { status: res.status, headers });
        });

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
            if (input.type === 'keyDown' && input.key === 'F11') {
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

module.exports = { resolveRequest };
