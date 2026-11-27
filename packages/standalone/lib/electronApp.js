'use strict';
const fs = require('node:fs');
const path = require('node:path');

const TEMPLATE_DIR = path.join(__dirname, '..', 'template', 'electron');

function writeJson(file, value) {
    fs.writeFileSync(file, JSON.stringify(value, null, 2) + '\n');
}

function writeElectronApp({ config, webDir, appDir }) {
    fs.rmSync(appDir, { recursive: true, force: true });
    fs.mkdirSync(appDir, { recursive: true });
    writeJson(path.join(appDir, 'package.json'), {
        name: config.appId.toLowerCase(),
        productName: config.productName,
        version: config.version,
        description: config.productName,
        author: config.productName,
        main: 'main.js'
    });
    writeJson(path.join(appDir, 'bge-app.json'), { title: config.productName, window: config.window });
    fs.copyFileSync(path.join(TEMPLATE_DIR, 'main.js'), path.join(appDir, 'main.js'));
    fs.copyFileSync(path.join(TEMPLATE_DIR, 'preload.js'), path.join(appDir, 'preload.js'));
    fs.cpSync(webDir, path.join(appDir, 'web'), { recursive: true });
}

module.exports = { writeElectronApp };
