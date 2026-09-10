#!/usr/bin/env node
// Real end-to-end proof that `ropm install` actually works for a downstream
// consumer of this engine: packs it exactly as `npm publish` would (which also
// triggers the `prepack` script, rebuilding `build/` fresh), installs that tarball
// into a throwaway consumer project via `ropm install` (using the README's
// recommended `ropm.noprefix` + `roku_modules` `diagnosticFilters` setup), then
// runs `bsc --validate` against it.
//
// This exists to catch a silent regression back to the ~1640-compile-error state
// that existed before PR #43 fixed `package.json` to publish the compiled `build/`
// output instead of raw `.bs` source - none of the `examples/*` apps exercise a
// real `ropm install` (they consume the engine via a direct file-copy trick), so
// nothing else in CI would ever catch this class of bug.

const fs = require('fs');
const path = require('path');
const os = require('os');
const { execFileSync } = require('child_process');

const ROOT_DIR = path.join(__dirname, '..');
const FIXTURE_TEMPLATE_DIR = path.join(__dirname, 'ropmConsumerFixture');
const PACKAGE_NAME = require(path.join(ROOT_DIR, 'package.json')).name;
const IS_WINDOWS = process.platform === 'win32';

const EXPECTED_KNOWN_ERRORS = 0;

function run(cmd, args, cwd) {
    console.log(`\n$ ${cmd} ${args.join(' ')}  (in ${cwd})`);
    execFileSync(cmd, args, { cwd, stdio: 'inherit', shell: IS_WINDOWS });
}

// Runs `bsc --validate`, returning its reported error count. Unlike `run()`, this
// doesn't throw on a non-zero exit - bsc exits non-zero whenever it finds ANY
// errors, including the known ones above, so the caller decides what count is
// acceptable.
function countValidateErrors(cwd) {
    const args = ['bsc', '--validate', '--create-package=false'];
    console.log(`\n$ npx ${args.join(' ')}  (in ${cwd})`);
    let output;
    try {
        output = execFileSync('npx', args, { cwd, shell: IS_WINDOWS }).toString();
    } catch (err) {
        // execFileSync throws on non-zero exit; bsc's actual output is on the error.
        output = (err.stdout || '').toString() + (err.stderr || '').toString();
    }
    console.log(output);
    const match = output.match(/Found (\d+) errors?/);
    return match ? Number(match[1]) : 0;
}

function copyDir(src, dest) {
    fs.mkdirSync(dest, { recursive: true });
    for (const entry of fs.readdirSync(src, { withFileTypes: true })) {
        const srcPath = path.join(src, entry.name);
        const destPath = path.join(dest, entry.name);
        if (entry.isDirectory()) {
            copyDir(srcPath, destPath);
        } else {
            fs.copyFileSync(srcPath, destPath);
        }
    }
}

function main() {
    const packDir = fs.mkdtempSync(path.join(os.tmpdir(), 'bge-ropm-pack-'));
    const consumerDir = fs.mkdtempSync(path.join(os.tmpdir(), 'bge-ropm-consumer-'));
    console.log(`Pack dir: ${packDir}`);
    console.log(`Consumer dir: ${consumerDir}`);

    // 1. Pack the engine exactly as `npm publish` would. Build explicitly first
    // (rather than relying on the `prepack` lifecycle hook here) and pack with
    // `--ignore-scripts`, so `prepack`'s own build-log output doesn't end up
    // interleaved into the `--json` output we need to parse below.
    run('npm', ['run', 'build'], ROOT_DIR);
    const packOutput = execFileSync(
        'npm',
        ['pack', '--json', '--ignore-scripts', '--pack-destination', packDir],
        { cwd: ROOT_DIR, shell: IS_WINDOWS }
    ).toString();
    const [{ filename }] = JSON.parse(packOutput);
    const tarballPath = path.join(packDir, filename);
    console.log(`Packed tarball: ${tarballPath}`);

    // 2. Set up a throwaway consumer project from the committed fixture template,
    // wiring in the just-packed tarball as its dependency (the template's own
    // package.json intentionally has no dependency entry, so it never needs to
    // change between runs - only this copy is touched).
    copyDir(FIXTURE_TEMPLATE_DIR, consumerDir);
    const pkgJsonPath = path.join(consumerDir, 'package.json');
    const pkgJson = JSON.parse(fs.readFileSync(pkgJsonPath, 'utf8'));
    pkgJson.dependencies[PACKAGE_NAME] = `file:${tarballPath}`;
    fs.writeFileSync(pkgJsonPath, JSON.stringify(pkgJson, null, 2));

    // 3. Install deps, then let ropm copy/rewrite the engine into roku_modules/.
    run('npm', ['install'], consumerDir);
    run('npx', ['ropm', 'install'], consumerDir);

    // 4. The real proof: does a downstream consumer's own `bsc --validate` pass?
    // (modulo the known, upstream-tracked errors documented above).
    const errorCount = countValidateErrors(consumerDir);
    if (errorCount > EXPECTED_KNOWN_ERRORS) {
        const direction = errorCount > EXPECTED_KNOWN_ERRORS ? 'more' : 'fewer';
        throw new Error(
            `Expected exactly ${EXPECTED_KNOWN_ERRORS} known errors, ` +
            `but got ${errorCount} - ${direction} than expected. If this is a genuine ` +
            `regression, fix it. If the upstream brighterscript/ropm bugs got fixed, update ` +
            `EXPECTED_KNOWN_ERRORS and the README's caveat instead of just bumping this number.`
        );
    }

    console.log(`\nropm consumer check passed - nothing new.`);
    fs.rmSync(packDir, { recursive: true, force: true });
    fs.rmSync(consumerDir, { recursive: true, force: true });
}

try {
    main();
} catch (err) {
    console.error('\nropm consumer check FAILED - see output above for the real bsc/ropm error.');
    console.error(err.message);
    process.exit(1);
}
