#!/usr/bin/env node
// Runs a task across every project under examples/*, e.g. `npm install` or
// `npx bsc --validate`. This replaces the old examples_*.sh shell scripts so
// these tasks work on Windows too, not just macOS/Linux/Git Bash.
//
// Usage: node scripts/examples.js <task>
//   task - one of: install, build, validate, clean, audit, ropm-install
//
// Each task is just a shell command run inside every examples/<name>/
// directory in turn. A failure in one example does NOT stop the others (or
// later steps in the same example) from running - this matches the original
// scripts, which never checked exit codes either.
//
// Examples run CONCURRENTLY (a fixed-size worker pool, not all-at-once) since
// steps like `npm install` are mostly I/O/network-bound and every example
// pulls the same devDependencies - CI's "Install example dependencies" step
// was previously the slowest part of the Validate workflow, running 19
// installs back to back one at a time. Override the pool size with the
// EXAMPLES_CONCURRENCY env var (e.g. for a constrained local machine).
// Each example's own output is buffered and flushed as one block when it
// finishes, rather than streamed live, so concurrent processes' output
// doesn't interleave line-by-line into an unreadable mess.

const fs = require('fs');
const path = require('path');
const os = require('os');
const { spawn } = require('child_process');

const EXAMPLES_DIR = path.join(__dirname, '..', 'examples');
const CONCURRENCY = Number(process.env.EXAMPLES_CONCURRENCY) || Math.min(8, os.cpus().length * 2);

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

// Runs one step and resolves with its combined stdout/stderr instead of
// streaming it, so the caller can print it as one uninterrupted block.
function runStep(exampleDir, { command, args }) {
  return new Promise((resolve) => {
    let output = `\n> ${command} ${args.join(' ')}  (examples/${exampleDir})\n`;
    // shell:true lets Windows resolve npm/npx/ropm's .cmd shims, and matches
    // how these commands would be typed at a terminal on any platform.
    const child = spawn(command, args, {
      cwd: path.join(EXAMPLES_DIR, exampleDir),
      shell: true
    });
    child.stdout.on('data', (chunk) => { output += chunk; });
    child.stderr.on('data', (chunk) => { output += chunk; });
    child.on('close', (code) => {
      if (code !== 0) {
        output += `  (exited with status ${code} - continuing with the next example)\n`;
      }
      resolve(output);
    });
  });
}

async function runExample(exampleDir, steps) {
  for (const step of steps) {
    process.stdout.write(await runStep(exampleDir, step));
  }
}

// A fixed-size worker pool over `items` - the simplest way to cap
// concurrency without pulling in a dependency for it.
async function runWithConcurrency(items, concurrency, worker) {
  const queue = [...items];
  const workers = Array.from({ length: Math.min(concurrency, items.length) }, async () => {
    while (queue.length > 0) {
      await worker(queue.shift());
    }
  });
  await Promise.all(workers);
}

async function main() {
  const taskName = process.argv[2];
  const task = TASKS[taskName];

  if (!task) {
    console.error(`Usage: node scripts/examples.js <${Object.keys(TASKS).join('|')}>`);
    process.exit(1);
  }

  const exampleDirs = listExampleDirs();

  // ropm-install replaces the engine's copy of itself before reinstalling,
  // so each example always picks up the latest local engine source.
  if (taskName === 'ropm-install') {
    for (const exampleDir of exampleDirs) {
      const bgeModulePath = path.join(EXAMPLES_DIR, exampleDir, 'node_modules', 'bge');
      fs.rmSync(bgeModulePath, { recursive: true, force: true });
    }
  }

  await runWithConcurrency(exampleDirs, CONCURRENCY, (exampleDir) => runExample(exampleDir, task));
}

main();
