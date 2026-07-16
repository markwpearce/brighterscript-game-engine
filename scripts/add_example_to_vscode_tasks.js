#!/usr/bin/env node
// Adds a new example name to the "example" pickString options in the root
// .vscode/tasks.json, so it shows up in the "Select the example to build"
// prompt used by the root debug/launch configs.
//
// Note: .vscode/tasks.json uses trailing commas (JSONC), so this edits the
// options array with a targeted regex rather than a strict JSON.parse.
//
// Usage: node scripts/add_example_to_vscode_tasks.js <name>

const fs = require('fs');
const path = require('path');

const name = process.argv[2];
if (!name) {
  console.error('Usage: node scripts/add_example_to_vscode_tasks.js <name>');
  process.exit(1);
}

const tasksPath = path.join(__dirname, '..', '.vscode', 'tasks.json');
const text = fs.readFileSync(tasksPath, 'utf8');

const optionsRegex = /("options":\s*\[)([\s\S]*?)(\n(\s*)\])/;
const match = text.match(optionsRegex);
if (!match) {
  console.error('Could not find "options" array in .vscode/tasks.json - leaving it unchanged.');
  process.exit(1);
}

const [, open, body, , closeIndent] = match;
const items = Array.from(body.matchAll(/"([^"]+)"/g)).map((m) => m[1]);

if (items.includes(name)) {
  console.log(`"${name}" is already in .vscode/tasks.json's example options.`);
  process.exit(0);
}

items.push(name);
items.sort((a, b) => a.localeCompare(b));

const itemIndent = `${closeIndent}    `;
const rebuiltBody = `\n${items.map((i) => `${itemIndent}"${i}",`).join('\n')}\n`;

const updated = text.replace(optionsRegex, `${open}${rebuiltBody}${closeIndent}]`);
fs.writeFileSync(tasksPath, updated);

console.log(`Added "${name}" to .vscode/tasks.json's example options.`);
