#!/usr/bin/env node
// Builds and runs the engine's Rooibos suite in shards, each in its own brs-cli process.
//
// One brs-cli run of the whole suite grows to ~16GB on a GitHub runner (about 6MB per
// test, mostly bitmaps from every BGE.Game the specs create) and the runner is killed
// (#429). Each shard is a bsconfig.test.json build with only its own spec files (Rooibos
// only transforms the specs it finds, so the others can't be in the build at all); between
// them they cover every spec file exactly once.

const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

const ROOT_DIR = path.join(__dirname, '..');
const SHARD_DIR = path.join(ROOT_DIR, 'test-build-shards');

// Spec globs (relative to rootDir) for each shard, added after every spec is excluded
const SHARDS = [
    { name: 'renderer', specs: ['source/engine/renderer/**/*.spec.bs'] },
    { name: 'engine', specs: ['source/engine/**/*.spec.bs', '!source/engine/renderer/**/*.spec.bs'] },
    { name: 'other', specs: ['source/**/*.spec.bs', '!source/engine/**/*.spec.bs'] }
];

function run(command, args) {
    const result = spawnSync(command, args, { cwd: ROOT_DIR, stdio: 'inherit', shell: process.platform === 'win32' });
    return result.status === 0;
}

function writeShardConfig(shard, testConfig) {
    const outDir = path.join(SHARD_DIR, shard.name);
    const [everything, ...rest] = testConfig.files;
    const config = {
        extends: path.relative(SHARD_DIR, path.join(ROOT_DIR, 'bsconfig.test.json')),
        outDir: path.relative(SHARD_DIR, outDir),
        files: [everything, '!**/*.spec.bs', ...shard.specs, ...rest]
    };
    const configPath = path.join(SHARD_DIR, `bsconfig.${shard.name}.json`);
    fs.writeFileSync(configPath, JSON.stringify(config, null, 4));
    return { configPath, outDir };
}

function main() {
    const testConfig = JSON.parse(fs.readFileSync(path.join(ROOT_DIR, 'bsconfig.test.json'), 'utf8'));
    fs.rmSync(SHARD_DIR, { recursive: true, force: true });
    fs.mkdirSync(SHARD_DIR, { recursive: true });

    const bsc = path.join(ROOT_DIR, 'node_modules', '.bin', 'bsc');
    const failed = [];
    for (const shard of SHARDS) {
        console.log(`\n=== Test shard: ${shard.name} ===`);
        const { configPath, outDir } = writeShardConfig(shard, testConfig);
        const ok = run(bsc, ['--project', configPath, '--create-package=false'])
            && run(process.execPath, [path.join(__dirname, 'run-tests-ci.js'), path.relative(ROOT_DIR, outDir)]);
        if (!ok) {
            failed.push(shard.name);
        }
    }
    if (failed.length > 0) {
        console.error(`\nTest shards failed: ${failed.join(', ')}`);
        process.exit(1);
    }
    console.log(`\nAll ${SHARDS.length} test shards passed.`);
}

main();
