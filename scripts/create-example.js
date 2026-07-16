#!/usr/bin/env node
// Scaffolds a new example app under examples/<name> from scripts/exampleTemplate.
// Pure Node (no cp/sed/uname), so this works on Windows as well as macOS/Linux.
//
// Usage: node scripts/create-example.js <name> ["Display Title"]
//   name  - directory name under examples/, e.g. "quickstart" -> examples/quickstart
//   title - optional manifest/display title, defaults to "Example Game - <name>"

const fs = require('fs');
const path = require('path');
const { generateExampleImages } = require('./generate-example-images.js');
const { addExampleToVscodeTasks } = require('./add-example-to-vscode-tasks.js');

const TEMPLATE_DIR = path.join(__dirname, 'exampleTemplate');
const EXAMPLES_DIR = path.join(__dirname, '..', 'examples');

// Placeholder files whose contents get the __TITLE__ token replaced.
const TITLE_PLACEHOLDER_FILES = [path.join('src', 'manifest'), path.join('.vscode', 'launch.json')];

// Recursively removes any files matching these names from `dir` - they're
// only there to make otherwise-empty template directories exist in git.
const PLACEHOLDER_FILES_TO_STRIP = new Set(['.gitkeep', '.DS_Store']);

function removePlaceholderFiles(dir) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const entryPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      removePlaceholderFiles(entryPath);
    } else if (PLACEHOLDER_FILES_TO_STRIP.has(entry.name)) {
      fs.rmSync(entryPath);
    }
  }
}

function replaceTitlePlaceholder(exampleDir, title) {
  for (const relativePath of TITLE_PLACEHOLDER_FILES) {
    const filePath = path.join(exampleDir, relativePath);
    const contents = fs.readFileSync(filePath, 'utf8');
    fs.writeFileSync(filePath, contents.split('__TITLE__').join(title));
  }
}

function printNextSteps(exampleDir) {
  const relativeDir = path.relative(process.cwd(), exampleDir) || exampleDir;
  console.log(`Created ${relativeDir}`);
  console.log('');
  console.log('Next steps:');
  console.log(`  cd ${relativeDir} && npm install`);
  console.log('  # add entities under src/source/Entities, rooms under src/source/Rooms');
  console.log('  # add sprites/sounds/models under src/sprites, src/sounds, src/models');
  console.log('  npm run build');
}

async function createExample(name, title) {
  const exampleDir = path.join(EXAMPLES_DIR, name);

  if (fs.existsSync(exampleDir)) {
    throw new Error(`${path.relative(process.cwd(), exampleDir)} already exists, aborting.`);
  }

  fs.cpSync(TEMPLATE_DIR, exampleDir, { recursive: true });
  removePlaceholderFiles(exampleDir);
  replaceTitlePlaceholder(exampleDir, title);

  // Same look as examples/rendererTest - dark background, wrapped bold title.
  await generateExampleImages(title, path.join(exampleDir, 'src', 'images'));

  addExampleToVscodeTasks(name);

  printNextSteps(exampleDir);
}

if (require.main === module) {
  const [name, titleArg] = process.argv.slice(2);

  if (!name) {
    console.error('Usage: node scripts/create-example.js <name> ["Display Title"]');
    process.exit(1);
  }

  const title = titleArg || `Example Game - ${name}`;

  createExample(name, title).catch((err) => {
    console.error(err.message || err);
    process.exit(1);
  });
}
