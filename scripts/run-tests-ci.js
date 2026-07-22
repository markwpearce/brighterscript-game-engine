#!/usr/bin/env node
// Runs the Rooibos test suite headlessly via brs-cli (no device/simulator/display
// needed) and exits non-zero if any test failed. Assumes `npm run build-tests` has
// already produced ./test-build.
//
// brs-cli never exits on its own once the app finishes (it keeps a background
// handle open even after printing its shutdown line), so this watches stdout for
// Rooibos's own `[Rooibos Result]: PASS`/`FAIL` line (framework-level, present
// regardless of which reporter is configured - the reporter-specific `RESULT:
// Success`/`Fail` line only appears with the default "console" reporter, not with
// "mocha") and kills the process itself once seen, with a timeout as a safety net
// in case that line never appears (e.g. a crash before Rooibos gets a chance to
// report).

const path = require('path');
const { spawn } = require('child_process');
const { rokuDeploy } = require('roku-deploy');

const ROOT_DIR = path.join(__dirname, '..');
const BUILD_DIR = path.join(ROOT_DIR, 'test-build');
const OUT_DIR = path.join(ROOT_DIR, 'out');
const ZIP_NAME = 'bge-tests.zip';
const RESULT_TIMEOUT_MS = 60000;

function runTests(zipPath) {
    return new Promise((resolve) => {
        const brsCli = path.join(ROOT_DIR, 'node_modules', '.bin', 'brs-cli');
        const child = spawn(brsCli, [zipPath, '--debug'], { cwd: ROOT_DIR });

        let output = '';
        let settled = false;

        const finish = (outcome) => {
            if (settled) {
                return;
            }
            settled = true;
            clearTimeout(timer);
            child.kill();
            resolve(outcome);
        };

        const timer = setTimeout(() => {
            console.error(`\nNo RESULT line seen within ${RESULT_TIMEOUT_MS}ms - assuming a hang/crash.`);
            finish('timeout');
        }, RESULT_TIMEOUT_MS);

        child.stdout.on('data', (chunk) => {
            const text = chunk.toString();
            output += text;
            process.stdout.write(text);
            if (/\[Rooibos Result\]: PASS/.test(output)) {
                finish('success');
            } else if (/\[Rooibos Result\]: FAIL/.test(output)) {
                finish('failure');
            }
        });
        child.stderr.on('data', (chunk) => {
            process.stderr.write(chunk);
        });
        child.on('error', (err) => {
            console.error(err);
            finish('spawn-error');
        });
        child.on('exit', (code, signal) => {
            // brs-cli never exits on its own on success (see note above), so an exit
            // here - before we've seen a RESULT line - means it crashed. Fail fast
            // instead of waiting out the full timeout.
            if (!settled) {
                console.error(`\nbrs-cli exited early (code=${code}, signal=${signal}) before reporting a RESULT line.`);
                finish('crashed');
            }
        });
    });
}

async function main() {
    await rokuDeploy.zip({
        stagingDir: BUILD_DIR,
        outDir: OUT_DIR,
        outFile: ZIP_NAME
    });

    const outcome = await runTests(path.join(OUT_DIR, ZIP_NAME));
    if (outcome === 'success') {
        process.exit(0);
    }
    console.error(`\nRooibos test run did not succeed (outcome: ${outcome}) - failing CI.`);
    process.exit(1);
}

main();
