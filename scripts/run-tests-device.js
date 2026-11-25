#!/usr/bin/env node
// Runs the Rooibos suite on a real Roku, one shard at a time (the same shards as
// run-tests-sharded.js, so SceneGraph tests keep their own runner), and exits non-zero if any
// shard failed, crashed or hung.
//
// The device comes from ROKU_HOST/ROKU_PASSWORD (environment, or .env, which rokubot reads
// itself). TEST_SHARDS=<name>,<name> runs only those shards. Each shard's console output is
// saved to out/device-tests-<shard>.log. A shard takes ~4 minutes on a Roku Express.

const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');
const { rokuDeploy } = require('roku-deploy');
const { getShards, writeShardConfig, findMisplacedSpecs } = require('./run-tests-sharded');

const ROOT_DIR = path.join(__dirname, '..');
const OUT_DIR = path.join(ROOT_DIR, 'out');
// its own builds, so test:ci can run meanwhile
const SHARD_DIR = path.join(ROOT_DIR, 'test-build-shards-device');
const ROKUBOT = path.join(ROOT_DIR, 'node_modules', 'rokubot', 'dist', 'cli.js');
// The console replays recent history on connect; anything that arrives this soon is old
const CONSOLE_REPLAY_MS = 3000;
// No console output for this long means the app hung
const IDLE_TIMEOUT_MS = 5 * 60 * 1000;
const SHARD_TIMEOUT_MS = 40 * 60 * 1000;

// `shell` for node_modules/.bin shims, which are .cmd files on Windows
function run(command, args, shell = false) {
    return new Promise((resolve) => {
        let output = '';
        const child = spawn(command, args, { cwd: ROOT_DIR, shell: shell && process.platform === 'win32' });
        child.stdout.on('data', (chunk) => { output += chunk; });
        child.stderr.on('data', (chunk) => { output += chunk; });
        child.on('error', (err) => resolve({ ok: false, output: output + `\n${err}\n` }));
        child.on('close', (code) => resolve({ ok: code === 0, output }));
    });
}

function rokubot(args) {
    return run(process.execPath, [ROKUBOT, ...args]);
}

function delay(ms) {
    return new Promise((resolve) => setTimeout(resolve, ms));
}

async function buildShard(shard, testConfig) {
    const { configPath, outDir } = writeShardConfig(shard, testConfig, SHARD_DIR);
    const bsc = path.join(ROOT_DIR, 'node_modules', '.bin', 'bsc');
    const result = await run(bsc, ['--project', configPath, '--create-package=false'], true);
    if (!result.ok) {
        return { ok: false, output: result.output };
    }
    const zipPath = path.join(OUT_DIR, `bge-device-tests-${shard.name}.zip`);
    await rokuDeploy.zip({ dir: outDir, out: zipPath });
    return { ok: true, zipPath };
}

// Sideloads a shard and reads the console until Rooibos reports, the app breaks, or it goes quiet
async function runShardOnDevice(shard, zipPath) {
    const consoleProcess = spawn(process.execPath, [ROKUBOT, 'console'], { cwd: ROOT_DIR });
    let log = '';
    consoleProcess.stdout.on('data', (chunk) => { log += chunk; });
    consoleProcess.stderr.on('data', (chunk) => { log += chunk; });
    await delay(CONSOLE_REPLAY_MS);
    if (/already in use/.test(log)) {
        consoleProcess.kill();
        return { outcome: 'console-busy', log };
    }

    await rokubot(['press', 'home']);
    const sideload = await rokubot(['sideload', zipPath, '--deleteDevChannel']);
    if (!sideload.ok) {
        consoleProcess.kill();
        return { outcome: 'sideload-failed', log: sideload.output };
    }
    // Only output from here on is this run's: a slow history replay can run past
    // CONSOLE_REPLAY_MS and carry the last shard's [Rooibos Result]. This run's result comes long
    // after the sideload returns (a compile error missed here still ends as "hung").
    const start = log.length;

    const started = Date.now();
    let lastLength = log.length;
    let lastChange = Date.now();
    let outcome = '';
    while (outcome === '') {
        await delay(2000);
        const output = log.slice(start);
        if (/\[Rooibos Result\]: PASS/.test(output)) {
            outcome = 'passed';
        } else if (/\[Rooibos Result\]: FAIL/.test(output)) {
            outcome = 'failed';
        } else if (/Compilation Failed/.test(output)) {
            outcome = 'compile-error';
        } else if (/Brightscript Debugger>|BrightScript Micro Debugger/i.test(output)) {
            outcome = 'crashed';
        } else if (Date.now() - lastChange > IDLE_TIMEOUT_MS) {
            outcome = 'hung';
        } else if (Date.now() - started > SHARD_TIMEOUT_MS) {
            outcome = 'timeout';
        }
        if (log.length !== lastLength) {
            lastLength = log.length;
            lastChange = Date.now();
        }
    }
    // let the reporter finish its failure details
    await delay(3000);
    consoleProcess.kill();
    return { outcome, log: log.slice(start) };
}

function summarize(log) {
    const text = log.replace(/\r/g, '');
    const counts = (text.match(/^\s*\d+ (passed|passing|failed|failing|pending|crashed)\b.*$/gm) || []).map((line) => line.trim());
    const failed = (text.match(/^\s*✖ .*$/gm) || []).map((line) => line.trim());
    return { counts, failed };
}

async function main() {
    const misplaced = findMisplacedSpecs();
    if (misplaced.length > 0) {
        console.error(misplaced.join('\n'));
        process.exit(1);
    }
    const shards = getShards();
    const testConfig = JSON.parse(fs.readFileSync(path.join(ROOT_DIR, 'bsconfig.test.json'), 'utf8'));
    fs.rmSync(SHARD_DIR, { recursive: true, force: true });
    fs.mkdirSync(SHARD_DIR, { recursive: true });
    fs.mkdirSync(OUT_DIR, { recursive: true });

    const failedShards = [];
    for (const shard of shards) {
        const started = Date.now();
        const build = await buildShard(shard, testConfig);
        if (!build.ok) {
            console.log(`\n=== Device shard: ${shard.name} (build FAILED) ===\n${build.output}`);
            failedShards.push(shard.name);
            continue;
        }
        const result = await runShardOnDevice(shard, build.zipPath);
        const logPath = path.join(OUT_DIR, `device-tests-${shard.name}.log`);
        fs.writeFileSync(logPath, result.log);
        const seconds = Math.round((Date.now() - started) / 1000);
        const { counts, failed } = summarize(result.log);
        console.log(`\n=== Device shard: ${shard.name} (${result.outcome}, ${seconds}s) === ${counts.join(', ')}`);
        for (const line of failed) {
            console.log(`    ${line}`);
        }
        if (result.outcome !== 'passed') {
            console.log(`    full output: ${path.relative(ROOT_DIR, logPath)}`);
            failedShards.push(shard.name);
        }
        if (result.outcome === 'console-busy') {
            console.error('The Roku debug console (port 8085) is in use - close the other reader and run again.');
            break;
        }
    }
    await rokubot(['press', 'home']);

    if (failedShards.length > 0) {
        console.error(`\nDevice test shards failed: ${failedShards.join(', ')}`);
        process.exit(1);
    }
    console.log(`\nAll ${shards.length} test shard(s) passed on the device.`);
}

main();
