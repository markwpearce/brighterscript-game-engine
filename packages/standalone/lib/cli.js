'use strict';
const fs = require('node:fs');
const path = require('node:path');
const { parseArgs } = require('node:util');
const { loadConfigFile, resolveConfig, resolveZipPath } = require('./config');
const { readGameZip, gameInfo } = require('./manifest');
const { writeWebBundle } = require('./webBundle');
const { serve } = require('./serve');

const USAGE = [
    'Usage: bge-standalone build [--target web|mac|win|linux|all] [--config file] [--zip path] [--out dir]',
    '       bge-standalone serve [dir] [--port 6502]'
].join('\n');

function defaults() {
    return {
        cwd: process.cwd(),
        platform: process.platform,
        log: (m) => console.log(m),
        warn: (m) => console.error(m),
        // Lazy: `--target web` must never load electron-builder.
        buildDesktop: (args) => require('./desktopBuild').buildDesktop(args),
        onServer: () => {}
    };
}

async function build(argv, deps) {
    const { values } = parseArgs({
        args: argv,
        options: { target: { type: 'string' }, config: { type: 'string' }, zip: { type: 'string' }, out: { type: 'string' } }
    });
    const configPath = values.config ? path.resolve(deps.cwd, values.config) : path.join(deps.cwd, 'bge-standalone.json');
    const file = loadConfigFile(configPath, Boolean(values.config));
    const zipPath = resolveZipPath({ cli: values, file, cwd: deps.cwd });
    if (!fs.existsSync(zipPath)) {
        throw new Error(`game zip not found: ${zipPath}`);
    }
    const game = await readGameZip(fs.readFileSync(zipPath));
    const info = gameInfo(game.manifest);
    const config = resolveConfig({ cli: values, file, game: info, platform: deps.platform, cwd: deps.cwd });
    if (!info.multiControllers) {
        deps.warn('warning: manifest has no multi_controllers=1, so analog sticks and extra gamepad buttons are off');
    }

    const webDir = path.join(config.outDir, 'web');
    writeWebBundle({ config, webDir });
    deps.log(`web build: ${webDir}`);

    for (const target of config.targets.filter((t) => t !== 'web')) {
        await deps.buildDesktop({
            config,
            game,
            target,
            webDir,
            appDir: path.join(config.outDir, 'electron-app'),
            outDir: path.join(config.outDir, 'desktop'),
            log: deps.log,
            warn: deps.warn
        });
        deps.log(`${target} build: ${path.join(config.outDir, 'desktop')}`);
    }
}

async function serveCommand(argv, deps) {
    const { values, positionals } = parseArgs({ args: argv, allowPositionals: true, options: { port: { type: 'string' } } });
    const dir = path.resolve(deps.cwd, positionals[0] || path.join('dist', 'web'));
    if (!fs.existsSync(path.join(dir, 'index.html'))) {
        throw new Error(`no index.html in ${dir} (run bge-standalone build --target web first)`);
    }
    const port = values.port === undefined ? 6502 : Number(values.port);
    if (!/^\d+$/.test(String(values.port ?? port)) || port > 65535) {
        throw new Error('--port must be an integer from 0 to 65535');
    }
    const server = await serve(dir, port);
    deps.onServer(server);
    deps.log(`serving ${dir} at http://127.0.0.1:${server.address().port}/ (Ctrl+C to stop)`);
    return server;
}

async function main(argv, overrides = {}) {
    const deps = { ...defaults(), ...overrides };
    const [command, ...rest] = argv;
    try {
        if (command === 'build') {
            await build(rest, deps);
            return 0;
        }
        if (command === 'serve') {
            await serveCommand(rest, deps);
            return 0;
        }
        if (command === undefined || command === '--help' || command === '-h') {
            deps.log(USAGE);
            return command === undefined ? 1 : 0;
        }
        throw new Error(`unknown command "${command}"\n${USAGE}`);
    } catch (e) {
        deps.warn(`bge-standalone: ${e.message}`);
        return 1;
    }
}

module.exports = { main, USAGE };
