// Shared scaffolding logic for scripts/create-entity.js and scripts/create-room.js -
// both generate a single class file under examples/<example>/src/source/<kind>/<ClassName>.bs
// from a __CLASS_NAME__ template, following the same pure-Node approach as create-example.js
// so it runs the same on Windows as macOS/Linux.

const fs = require('fs');
const path = require('path');
const readline = require('readline/promises');

const EXAMPLES_DIR = path.join(__dirname, '..', 'examples');
const CLASS_NAME_PATTERN = /^[A-Za-z][A-Za-z0-9_]*$/;

function assertValidClassName(className) {
  if (!CLASS_NAME_PATTERN.test(className)) {
    throw new Error(`"${className}" isn't a valid class name - use letters, numbers, and underscores, starting with a letter.`);
  }
}

function assertExampleExists(exampleName) {
  const exampleDir = path.join(EXAMPLES_DIR, exampleName);
  if (!fs.existsSync(exampleDir)) {
    throw new Error(`examples/${exampleName} doesn't exist, aborting.`);
  }
  return exampleDir;
}

async function promptForMissingArgs(exampleName, className, { classKind }) {
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  try {
    while (!exampleName) {
      exampleName = (await rl.question('Example name (directory under examples/): ')).trim();
    }
    while (!className) {
      className = (await rl.question(`${classKind} class name: `)).trim();
    }
  } finally {
    rl.close();
  }
  return { exampleName, className };
}

// opts:
//   subDir   - subdirectory under src/source, e.g. "Entities" or "Rooms"
//   templatePath - absolute path to the __CLASS_NAME__.bs template
//   classKind - "Entity" or "Room", used in prompts/messages
//   printNextSteps(filePath, className) - called with the created file's path
function scaffoldClass(exampleName, className, opts) {
  assertValidClassName(className);
  const exampleDir = assertExampleExists(exampleName);

  const targetDir = path.join(exampleDir, 'src', 'source', opts.subDir);
  fs.mkdirSync(targetDir, { recursive: true });

  const targetPath = path.join(targetDir, `${className}.bs`);
  if (fs.existsSync(targetPath)) {
    throw new Error(`${path.relative(process.cwd(), targetPath)} already exists, aborting.`);
  }

  const template = fs.readFileSync(opts.templatePath, 'utf8');
  fs.writeFileSync(targetPath, template.split('__CLASS_NAME__').join(className));

  opts.printNextSteps(targetPath, className);
}

function runCli({ classKind, subDir, templatePath, printNextSteps }) {
  let [exampleName, className] = process.argv.slice(2);

  Promise.resolve()
    .then(async () => {
      if (!exampleName || !className) {
        ({ exampleName, className } = await promptForMissingArgs(exampleName, className, { classKind }));
      }
      scaffoldClass(exampleName, className, { subDir, templatePath, printNextSteps });
    })
    .catch((err) => {
      console.error(err.message || err);
      process.exit(1);
    });
}

module.exports = { scaffoldClass, runCli };
