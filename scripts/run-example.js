#!/usr/bin/env node
// Builds the engine, packages one example, sideloads it and launches it with
// deep-link params - the whole edit/run loop in one command.
//
// Usage: node scripts/run-example.js <example> [key=value ...]
//   e.g. npm run run-example -- rendererTest demo=lighting
//
// The device comes from ROKU_HOST/ROKU_PASSWORD in .env, which rokubot reads
// itself. Stops at the first failing step.

const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

const ROOT = path.join(__dirname, '..');
const EXAMPLES_DIR = path.join(ROOT, 'examples');
const ROKUBOT = path.join(ROOT, 'node_modules', 'rokubot', 'dist', 'cli.js');

function listExamples() {
  return fs
    .readdirSync(EXAMPLES_DIR, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => entry.name)
    .sort();
}

function fail(message) {
  console.error(message);
  process.exit(1);
}

function run(label, command, args, cwd) {
  console.log(`\n> ${label}`);
  // shell:true lets Windows resolve npm/npx's .cmd shims
  const result = spawnSync(command, args, { cwd, stdio: 'inherit', shell: true });
  if (result.status !== 0) {
    fail(`\n${label} failed (exit status ${result.status})`);
  }
}

function rokubot(label, args) {
  // node directly rather than npx: much faster, and no shell quoting of params
  console.log(`\n> ${label}`);
  const result = spawnSync(process.execPath, [ROKUBOT, ...args], { cwd: ROOT, stdio: 'inherit' });
  if (result.status !== 0) {
    fail(`\n${label} failed (exit status ${result.status})`);
  }
}

function main() {
  const [exampleArg, ...params] = process.argv.slice(2);
  const examples = listExamples();
  if (!exampleArg) {
    fail(`Usage: npm run run-example -- <example> [key=value ...]\nExamples: ${examples.join(', ')}`);
  }
  // package paths are case-insensitive on device, so match the folder the same way
  const example = examples.find((name) => name.toLowerCase() === exampleArg.toLowerCase());
  if (!example) {
    fail(`No example named "${exampleArg}". Examples: ${examples.join(', ')}`);
  }
  const badParam = params.find((param) => !/^[^=]+=/.test(param));
  if (badParam) {
    fail(`Params must be key=value, got "${badParam}"`);
  }
  const exampleDir = path.join(EXAMPLES_DIR, example);
  if (!fs.existsSync(path.join(exampleDir, 'node_modules'))) {
    fail(`examples/${example} has no node_modules - run \`npm run prepare-examples\` first`);
  }
  if (!fs.existsSync(ROKUBOT)) {
    fail('rokubot isn\'t built - run `npm install` at the repo root');
  }

  run('Building the engine', 'npm', ['run', 'build'], ROOT);
  // the same steps as the example's own `npm run package`, which needs a POSIX shell
  const zipPath = path.join(exampleDir, 'out', `bge-${example}.zip`);
  run(`Building examples/${example}`, 'npx', ['bsc'], exampleDir);
  run(`Packaging examples/${example}`, 'npx', ['roku-deploy', 'zip', '--dir', './build', '--out', `./out/bge-${example}.zip`], exampleDir);

  rokubot('Sideloading', ['sideload', zipPath, '--deleteDevChannel']);
  // sideloading starts the channel without params, and launch won't restart a running app
  rokubot('Returning to Home', ['press', 'home']);
  rokubot(`Launching${params.length ? ` with ${params.join(' ')}` : ''}`, ['launch', 'dev', ...params.flatMap((param) => ['--param', param])]);
}

main();
