'use strict';
const fs = require('node:fs');
const path = require('node:path');
const { writeElectronApp } = require('./electronApp');
const { isUsableIcon, letterboxIcon, ICON_SIZE } = require('./icon');

const FORMATS = { mac: ['dmg'], win: ['nsis'], linux: ['AppImage'] };
const SIZE = `${ICON_SIZE}x${ICON_SIZE}`;

function builderConfig({ config, outDir, iconPath, electronVersion }) {
    const icon = iconPath ? { icon: iconPath } : {};
    return {
        appId: config.appId,
        productName: config.productName,
        electronVersion,
        directories: { output: outDir },
        files: ['main.js', 'preload.js', 'bge-app.json', 'package.json', 'web/**/*'],
        // identity: null = unsigned; signing is a follow-up.
        mac: { target: FORMATS.mac, category: 'public.app-category.games', identity: null, ...icon },
        win: { target: FORMATS.win, ...icon },
        linux: { target: FORMATS.linux, category: 'Game', ...icon }
    };
}

async function pickIcon({ config, game, appDir, warn }) {
    const dest = path.join(appDir, 'icon.png');
    if (config.icon) {
        if (!fs.existsSync(config.icon)) {
            throw new Error(`icon not found: ${config.icon}`);
        }
        const data = fs.readFileSync(config.icon);
        if (!isUsableIcon(data)) {
            throw new Error(`${config.icon} must be a square PNG of at least ${SIZE}`);
        }
        fs.writeFileSync(dest, data);
        return dest;
    }
    if (!game.icon) {
        return null;
    }
    if (isUsableIcon(game.icon.data)) {
        fs.writeFileSync(dest, game.icon.data);
        return dest;
    }
    try {
        fs.writeFileSync(dest, await letterboxIcon(game.icon.data));
    } catch (e) {
        warn(`warning: could not convert the manifest icon (${e.message}); using Electron's default icon`);
        return null;
    }
    warn(`warning: no "icon" set, so the manifest icon ${game.icon.name} was letterboxed to ${SIZE} with transparent bars; set "icon" in bge-standalone.json to a square ${SIZE}+ PNG for a sharper icon`);
    return dest;
}

async function buildDesktop({ config, game, target, webDir, appDir, outDir, log, warn }, builder = require('electron-builder')) {
    writeElectronApp({ config, webDir, appDir });
    // After writeElectronApp, which empties appDir.
    const iconPath = await pickIcon({ config, game, appDir, warn });
    const platform = { mac: builder.Platform.MAC, win: builder.Platform.WINDOWS, linux: builder.Platform.LINUX }[target];
    log(`packaging ${target} (${FORMATS[target].join(', ')})...`);
    await builder.build({
        projectDir: appDir,
        targets: platform.createTarget(FORMATS[target]),
        config: builderConfig({ config, outDir, iconPath, electronVersion: require('electron/package.json').version })
    });
}

module.exports = { builderConfig, pickIcon, buildDesktop };
