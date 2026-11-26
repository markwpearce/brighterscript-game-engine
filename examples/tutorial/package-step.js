#!/usr/bin/env node
// Builds the tutorial's step folders (steps/stepN) as their own zips, or validates all of them.
//
// Usage:
//   npm run package:step -- 3   -> out/bge-tutorial-step3.zip (the code at the end of step 3)
//   npm run validate            -> checks every step's bsconfig.stepN.json

const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

const EXAMPLE_DIR = __dirname;
const STEPS_DIR = path.join(EXAMPLE_DIR, 'steps');

// shell: true so npx resolves on Windows too
function run(args) {
  const result = spawnSync('npx', args, { cwd: EXAMPLE_DIR, stdio: 'inherit', shell: true });
  if (result.status !== 0) {
    process.exit(result.status || 1);
  }
}

function stepNumbers() {
  return fs.readdirSync(STEPS_DIR)
    .map((name) => /^step(\d+)$/.exec(name))
    .filter(Boolean)
    .map((match) => Number(match[1]))
    .sort((a, b) => a - b);
}

const arg = process.argv[2];

if (arg === 'validate') {
  for (const step of stepNumbers()) {
    console.log(`Validating step ${step}`);
    run(['bsc', '--project', `bsconfig.step${step}.json`, '--validate', '--create-package=false']);
  }
} else if (/^\d+$/.test(arg || '') && stepNumbers().includes(Number(arg))) {
  const step = Number(arg);
  run(['bsc', '--project', `bsconfig.step${step}.json`, '--create-package=false']);
  run(['roku-deploy', 'zip', '--dir', `./build/step${step}`, '--out', `./out/bge-tutorial-step${step}.zip`]);
  console.log(`Wrote out/bge-tutorial-step${step}.zip`);
} else {
  console.error('Usage: npm run package:step -- <step number, 1-9>   or   npm run validate');
  process.exit(1);
}
