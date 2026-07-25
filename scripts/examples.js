#!/usr/bin/env node
// Runs a task across every project under examples/*, e.g. `npm install` or
// `npx bsc --validate`. This replaces the old examples_*.sh shell scripts so
// these tasks work on Windows too, not just macOS/Linux/Git Bash.
//
// Usage: node scripts/examples.js <task>
//   task - one of: install, build, validate, clean, audit, ropm-install
//
// Each task is just a shell command run inside every examples/<name>/
// directory in turn (matching the old examples_command.sh behavior). A
// failure in one example does NOT stop the others from running - this
// matches the original scripts, which never checked exit codes either.

const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

const EXAMPLES_DIR = path.join(__dirname, '..', 'examples');

// Each task is a list of {command, args} steps run in every example directory.
const TASKS = {
  install: [{ command: 'npm', args: ['install'] }],
  build: [{ command: 'npm', args: ['run', 'package'] }],
  validate: [{ command: 'npx', args: ['bsc', '--validate', '--create-package=false'] }],
  clean: [{ command: 'npm', args: ['run', 'clean'] }, { command: 'ropm', args: ['clean'] }],
  audit: [{ command: 'npm', args: ['audit', 'fix', '--force'] }],
  'ropm-install': [{ command: 'ropm', args: ['install'] }]
};

function listExampleDirs() {
  return fs
    .readdirSync(EXAMPLES_DIR, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => entry.name)
    .sort();
}

function runStep(exampleDir, { command, args }) {
  console.log(`\n> ${command} ${args.join(' ')}  (examples/${exampleDir})`);
  // shell:true lets Windows resolve npm/npx/ropm's .cmd shims, and matches
  // how these commands would be typed at a terminal on any platform.
  const result = spawnSync(command, args, {
    cwd: path.join(EXAMPLES_DIR, exampleDir),
    stdio: 'inherit',
    shell: true
  });
  if (result.status !== 0) {
    console.warn(`  (exited with status ${result.status} - continuing with the next example)`);
  }
}

function main() {
  const taskName = process.argv[2];
  const task = TASKS[taskName];

  if (!task) {
    console.error(`Usage: node scripts/examples.js <${Object.keys(TASKS).join('|')}>`);
    process.exit(1);
  }

  // ropm-install replaces the engine's copy of itself before reinstalling,
  // so each example always picks up the latest local engine source.
  if (taskName === 'ropm-install') {
    for (const exampleDir of listExampleDirs()) {
      const bgeModulePath = path.join(EXAMPLES_DIR, exampleDir, 'node_modules', 'bge');
      fs.rmSync(bgeModulePath, { recursive: true, force: true });
    }
  }

  for (const exampleDir of listExampleDirs()) {
    for (const step of task) {
      runStep(exampleDir, step);
    }
  }
}

main();
