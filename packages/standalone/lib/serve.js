'use strict';
const fs = require('node:fs');
const http = require('node:http');
const path = require('node:path');

const CONTENT_TYPES = {
    '.html': 'text/html; charset=utf-8',
    '.js': 'text/javascript; charset=utf-8',
    '.json': 'application/json',
    '.zip': 'application/zip',
    '.png': 'image/png',
    '.wasm': 'application/wasm'
};

// brs-engine needs SharedArrayBuffer, which needs cross-origin isolation.
const ISOLATION_HEADERS = {
    'Cross-Origin-Opener-Policy': 'same-origin',
    'Cross-Origin-Embedder-Policy': 'require-corp',
    'Cross-Origin-Resource-Policy': 'same-origin'
};

function createServer(root) {
    const base = path.resolve(root);
    return http.createServer((req, res) => {
        let rel;
        try {
            const url = new URL(req.url, 'http://localhost');
            rel = decodeURIComponent(url.pathname).replace(/^\/+/, '') || 'index.html';
        } catch {
            // Malformed percent-encoding (e.g. "/%zz"); throwing here would crash the server.
            res.writeHead(400, ISOLATION_HEADERS);
            res.end('Bad request');
            return;
        }
        const file = path.resolve(base, rel);
        if (file !== base && !file.startsWith(base + path.sep)) {
            res.writeHead(403, ISOLATION_HEADERS);
            res.end('Forbidden');
            return;
        }
        if (file.includes('\0')) {
            // fs.readFile throws synchronously on NUL bytes; treat as not found.
            res.writeHead(404, ISOLATION_HEADERS);
            res.end('Not found');
            return;
        }
        fs.readFile(file, (err, data) => {
            if (err) {
                res.writeHead(404, ISOLATION_HEADERS);
                res.end('Not found');
                return;
            }
            const type = CONTENT_TYPES[path.extname(file).toLowerCase()] || 'application/octet-stream';
            res.writeHead(200, { ...ISOLATION_HEADERS, 'Content-Type': type });
            res.end(data);
        });
    });
}

function serve(root, port) {
    return new Promise((resolve, reject) => {
        const server = createServer(root);
        server.once('error', reject);
        server.listen(port, '127.0.0.1', () => resolve(server));
    });
}

module.exports = { createServer, serve, ISOLATION_HEADERS };
