#!/usr/bin/env node
// Adds a new example name to the "example" pickString options in the root
// .vscode/tasks.json, so it shows up in the "Select the example to build"
// prompt used by the root debug/launch configs.
//
// Note: .vscode/tasks.json uses trailing commas (JSONC), which a strict
// JSON.parse would choke on - so this edits the options array with a
// targeted regex instead of parsing/re-serializing the whole file.
//
// Can be run standalone: node scripts/add-example-to-vscode-tasks.js <name>
// or required as a module: addExampleToVscodeTasks(name)

const fs = require('fs');
const path = require('path');

const TASKS_PATH = path.join(__dirname, '..', '.vscode', 'tasks.json');
const OPTIONS_REGEX = /("options":\s*\[)([\s\S]*?)(\n(\s*)\])/;

// Inserts `name` into the sorted "options" list, unless it's already there.
function addExampleToVscodeTasks(name, tasksPath = TASKS_PATH) {
  const text = fs.readFileSync(tasksPath, 'utf8');

  const match = text.match(OPTIONS_REGEX);
  if (!match) {
    throw new Error(`Could not find "options" array in ${tasksPath}`);
  }

  const [, open, body, , closeIndent] = match;
  const items = Array.from(body.matchAll(/"([^"]+)"/g)).map((m) => m[1]);

  if (items.includes(name)) {
    return false;
  }

  items.push(name);
  items.sort((a, b) => a.localeCompare(b));

  const itemIndent = `${closeIndent}    `;
  const rebuiltBody = `\n${items.map((i) => `${itemIndent}"${i}",`).join('\n')}\n`;

  fs.writeFileSync(tasksPath, text.replace(OPTIONS_REGEX, `${open}${rebuiltBody}${closeIndent}]`));
  return true;
}

module.exports = { addExampleToVscodeTasks };

// Allow running directly: node scripts/add-example-to-vscode-tasks.js <name>
if (require.main === module) {
  const name = process.argv[2];
  if (!name) {
    console.error('Usage: node scripts/add-example-to-vscode-tasks.js <name>');
    process.exit(1);
  }

  const added = addExampleToVscodeTasks(name);
  console.log(
    added
      ? `Added "${name}" to .vscode/tasks.json's example options.`
      : `"${name}" is already in .vscode/tasks.json's example options.`
  );
}
