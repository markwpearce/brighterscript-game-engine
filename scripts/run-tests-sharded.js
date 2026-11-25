#!/usr/bin/env node
// Builds and runs the engine's Rooibos suite in shards, each in its own brs-cli process.
//
// One brs-cli run of the whole suite grows to ~16GB on a GitHub runner (about 6MB per
// test, mostly bitmaps from every BGE.Game the specs create) and the runner is killed
// (#429). Each shard is a bsconfig.test.json build with only its own spec files (Rooibos
// only transforms the specs it finds, so the others can't be in the build at all); between
// them they cover every spec file exactly once.
//
// Shards build and run at the same time, as many as cores and memory allow (#523); set
// TEST_SHARD_CONCURRENCY to override. TEST_SHARDS=<name>,<name> runs only those shards, and
// `--list` prints every shard name as a JSON array (CI runs one shard per job). Each shard's output is printed in one block when it
// finishes, so shards running together don't interleave.

const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawn } = require('child_process');

const ROOT_DIR = path.join(__dirname, '..');
const SHARD_DIR = path.join(ROOT_DIR, 'test-build-shards');

// Spec globs (relative to rootDir) for each shard, added after every spec is excluded.
// UiContainer.spec.bs stays with the engine shard: Game.spec.bs uses its test widgets.
// SceneObjectTestDoubles.spec.bs has no tests, only helpers the renderer and drawables shards use.
// Drawables test with their scene objects, so the two share a shard.
// Slowest first, so they start first.
const SHARDS = [
    { name: 'renderer', specs: ['source/engine/renderer/*.spec.bs', 'source/engine/renderer/sceneObjects/SceneObjectTestDoubles.spec.bs'] },
    { name: 'drawables', specs: ['source/engine/renderer/sceneObjects/**/*.spec.bs', 'source/engine/drawables/**/*.spec.bs'] },
    { name: 'renderer-parts', specs: ['source/engine/renderer/*/**/*.spec.bs', '!source/engine/renderer/sceneObjects/**/*.spec.bs'] },
    { name: 'other', specs: ['source/**/*.spec.bs', '!source/engine/**/*.spec.bs'] },
    { name: 'engine', specs: ['source/engine/**/*.spec.bs', '!source/engine/renderer/**/*.spec.bs', '!source/engine/drawables/**/*.spec.bs', '!source/engine/ui/**/*.spec.bs', '!source/engine/loading/**/*.spec.bs', '!source/engine/quality/**/*.spec.bs', 'source/engine/ui/UiContainer.spec.bs'] },
    { name: 'engine-ui', specs: ['source/engine/ui/**/*.spec.bs', 'source/engine/loading/**/*.spec.bs', 'source/engine/quality/**/*.spec.bs', '!source/engine/ui/UiContainer.spec.bs'] },
    // SceneGraph tests (@SGNode suites, next to their components) run on Rooibos's own runner:
    // the roScreen runner patch (scripts/rooibos-roscreen-runner-plugin.js) is off for them
    { name: 'scenegraph', specs: ['components/**/*.spec.bs'], options: { roScreenTestRunner: false } }
];

// Test helpers (no suites) every shard can use
const SHARED_SPECS = ['source/testing/**/*.spec.bs'];

const GIB = 1024 * 1024 * 1024;
// The five shards before drawables split off peaked at ~5.7GB of brs-cli memory together locally; leave headroom
const MEMORY_PER_SHARD = 2.5 * GIB;

function getShards() {
    if (!process.env.TEST_SHARDS) {
        return SHARDS;
    }
    const names = process.env.TEST_SHARDS.split(',').map((name) => name.trim());
    const unknown = names.filter((name) => !SHARDS.some((shard) => shard.name === name));
    if (unknown.length > 0) {
        console.error(`Unknown test shard(s): ${unknown.join(', ')}. Shards: ${SHARDS.map((shard) => shard.name).join(', ')}`);
        process.exit(1);
    }
    return SHARDS.filter((shard) => names.includes(shard.name));
}

function getConcurrency(shardCount) {
    const fromEnv = Number(process.env.TEST_SHARD_CONCURRENCY);
    if (fromEnv > 0) {
        return Math.min(fromEnv, shardCount);
    }
    const cores = os.availableParallelism ? os.availableParallelism() : os.cpus().length;
    const byMemory = Math.floor(os.totalmem() / MEMORY_PER_SHARD);
    return Math.max(1, Math.min(shardCount, cores, byMemory));
}

// Runs a command, resolving with whether it succeeded and its combined output.
function run(command, args) {
    return new Promise((resolve) => {
        let output = '';
        const child = spawn(command, args, { cwd: ROOT_DIR, shell: process.platform === 'win32' });
        child.stdout.on('data', (chunk) => { output += chunk; });
        child.stderr.on('data', (chunk) => { output += chunk; });
        child.on('error', (err) => {
            output += `\n${err}\n`;
            resolve({ ok: false, output });
        });
        child.on('close', (code) => resolve({ ok: code === 0, output }));
    });
}

function writeShardConfig(shard, testConfig, shardDir = SHARD_DIR) {
    const outDir = path.join(shardDir, shard.name);
    const [everything, ...rest] = testConfig.files;
    const config = {
        extends: path.relative(shardDir, path.join(ROOT_DIR, 'bsconfig.test.json')),
        outDir: path.relative(shardDir, outDir),
        files: [everything, '!**/*.spec.bs', ...shard.specs, ...SHARED_SPECS, ...rest],
        ...shard.options
    };
    const configPath = path.join(shardDir, `bsconfig.${shard.name}.json`);
    fs.writeFileSync(configPath, JSON.stringify(config, null, 4));
    return { configPath, outDir };
}

async function runShard(shard, testConfig) {
    const started = Date.now();
    const { configPath, outDir } = writeShardConfig(shard, testConfig);
    const bsc = path.join(ROOT_DIR, 'node_modules', '.bin', 'bsc');
    let result = await run(bsc, ['--project', configPath, '--create-package=false']);
    let output = result.output;
    if (result.ok) {
        result = await run(process.execPath, [path.join(__dirname, 'run-tests-ci.js'), path.relative(ROOT_DIR, outDir)]);
        output += result.output;
    }
    const seconds = Math.round((Date.now() - started) / 1000);
    process.stdout.write(`\n=== Test shard: ${shard.name} (${result.ok ? 'passed' : 'FAILED'}, ${seconds}s) ===\n${output}`);
    return result.ok;
}

function listSpecs(dir, found = []) {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
        const full = path.join(dir, entry.name);
        if (entry.isDirectory()) {
            if (entry.name !== 'roku_modules') {
                listSpecs(full, found);
            }
        } else if (entry.name.endsWith('.spec.bs')) {
            found.push(full);
        }
    }
    return found;
}

// An @SGNode suite on the roScreen runner, or a BGE.Game on the SceneGraph runner, hangs on a
// Roku (see scripts/rooibos-roscreen-runner-plugin.js), so keep each kind where it belongs.
function findMisplacedSpecs() {
    const srcDir = path.join(ROOT_DIR, 'src');
    const problems = [];
    for (const file of listSpecs(srcDir)) {
        const relative = path.relative(srcDir, file).split(path.sep).join('/');
        const code = fs.readFileSync(file, 'utf8');
        const isSceneGraphSpec = relative.startsWith('components/');
        if (!isSceneGraphSpec && /@SGNode\s*\(/i.test(code)) {
            problems.push(`${relative}: @SGNode suites go under src/components/ (the SceneGraph runner)`);
        }
        if (isSceneGraphSpec && /\bBGE\.Game\s*\(/.test(code)) {
            problems.push(`${relative}: a SceneGraph spec can't make a BGE.Game (its roScreen hangs SceneGraph on a device)`);
        }
    }
    return problems;
}

async function main() {
    if (process.argv.includes('--list')) {
        console.log(JSON.stringify(SHARDS.map((shard) => shard.name)));
        return;
    }
    const misplaced = findMisplacedSpecs();
    if (misplaced.length > 0) {
        console.error(misplaced.join('\n'));
        process.exit(1);
    }
    const shards = getShards();
    const testConfig = JSON.parse(fs.readFileSync(path.join(ROOT_DIR, 'bsconfig.test.json'), 'utf8'));
    fs.rmSync(SHARD_DIR, { recursive: true, force: true });
    fs.mkdirSync(SHARD_DIR, { recursive: true });

    const concurrency = getConcurrency(shards.length);
    console.log(`Running ${shards.length} test shard(s), ${concurrency} at a time`);
    const queue = [...shards];
    const failed = [];
    const workers = Array.from({ length: concurrency }, async () => {
        while (queue.length > 0) {
            const shard = queue.shift();
            if (!(await runShard(shard, testConfig))) {
                failed.push(shard.name);
            }
        }
    });
    await Promise.all(workers);

    if (failed.length > 0) {
        console.error(`\nTest shards failed: ${failed.join(', ')}`);
        process.exit(1);
    }
    console.log(`\nAll ${shards.length} test shard(s) passed.`);
}

if (require.main === module) {
    main();
}

// scripts/run-tests-device.js builds the same shards
module.exports = { SHARDS, getShards, writeShardConfig, findMisplacedSpecs };
