// README.md (rendered into docs/index.html by jsdoc) references images via relative paths like
// `assets/screenshots/*.jpg`. jsdoc only copies files it treats as documentation source, so the
// image files themselves need to be copied into the docs output alongside it.
const fs = require('fs');
const path = require('path');

const srcDir = path.join(__dirname, '..', 'assets');
const destDir = path.join(__dirname, '..', 'docs', 'assets');

fs.cpSync(srcDir, destDir, { recursive: true });
