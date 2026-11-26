#!/usr/bin/env node
// Fails when an asset file added since <base> isn't named in a credits file (#696).
// Credits are free-form, so a file counts as credited when a CREDITS.md/credits.txt/README.md
// in its folder or a parent folder (up to the example's root) mentions its file name, its
// name without extension in backticks (`sword`), or a backticked glob (`grunt*.wav`, `art/npcs/*`).
//
// Usage: node scripts/check-asset-credits.js [base]   (default: origin/main)

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { execFileSync } = require('child_process');

const ROOT = path.join(__dirname, '..');
const TEMPLATE_DIR = path.join(__dirname, 'exampleTemplate');
const ASSET_EXT = /\.(png|jpe?g|webp|gif|bmp|wav|mp3|ogg|m4a|ttf|otf|fnt|obj|stl|mtl|blend|tmx|tsx)$/i;
const IGNORED_DIR = /(^|\/)(node_modules|build|out)\//;
const CREDIT_FILE = /^(credits(\.md|\.txt)?|readme\.md)$/i;

function git(...args) {
  return execFileSync('git', args, { cwd: ROOT, encoding: 'utf8' });
}

function changedFiles(base) {
  const mergeBase = git('merge-base', base, 'HEAD').trim();
  const changed = git('diff', '--name-only', '--diff-filter=AR', '-z', mergeBase).split('\0');
  const untracked = git('ls-files', '--others', '--exclude-standard', '-z').split('\0');
  return [...new Set([...changed, ...untracked])].filter(Boolean);
}

// Where to stop looking for credit files, or undefined if the file is out of scope
function creditRoot(file) {
  const parts = file.split('/');
  if (parts[0] === 'examples' && parts.length > 2) {
    return parts.slice(0, 2).join('/');
  }
  if (parts[0] === 'src') {
    return 'src';
  }
  if (file.startsWith('scripts/exampleTemplate/')) {
    return 'scripts/exampleTemplate';
  }
  return undefined;
}

function hash(file) {
  return crypto.createHash('sha1').update(fs.readFileSync(file)).digest('hex');
}

// create-example copies these, so a copy is the template's asset, not a new one
function templateHashes() {
  const hashes = new Set();
  const walk = (dir) => {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      const full = path.join(dir, entry.name);
      if (entry.isDirectory()) {
        walk(full);
      } else if (ASSET_EXT.test(entry.name)) {
        hashes.add(hash(full));
      }
    }
  };
  walk(TEMPLATE_DIR);
  return hashes;
}

function creditTexts(dir, stopAt) {
  const texts = [];
  let current = dir;
  while (true) {
    const full = path.join(ROOT, current);
    if (fs.existsSync(full)) {
      for (const name of fs.readdirSync(full)) {
        if (CREDIT_FILE.test(name)) {
          texts.push({ dir: current, text: fs.readFileSync(path.join(full, name), 'utf8') });
        }
      }
    }
    if (current === stopAt || !current.includes('/')) {
      break;
    }
    current = path.posix.dirname(current);
  }
  if (stopAt === 'src') {
    texts.push({ dir: '', text: fs.readFileSync(path.join(ROOT, 'LICENSE-THIRD-PARTY.md'), 'utf8') });
  }
  return texts;
}

function globToRegExp(glob) {
  const escaped = glob.replace(/[.+?^${}()|[\]\\]/g, '\\$&').replace(/\*/g, '[^/]*');
  return new RegExp('(^|/)' + escaped + '$');
}

function escapeRegExp(text) {
  return text.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function isCredited(file, texts) {
  const name = path.posix.basename(file);
  const stem = name.replace(/\.[^.]+$/, '');
  // a whole file name, so `data.png` doesn't credit `a.png`
  const namePattern = new RegExp('(^|[^\\w.-])' + escapeRegExp(name) + '(?![\\w-]|\\.\\w)', 'i');
  return texts.some(({ dir, text }) => {
    if (namePattern.test(text) || text.includes('`' + stem + '`')) {
      return true;
    }
    const relPath = path.posix.relative(dir, file);
    // a bare `*` is the Roku options key in controls tables, not a glob
    const globs = [...text.matchAll(/`([^`\s]*\*[^`\s]*)`/g)]
      .map((match) => match[1])
      .filter((glob) => /[a-z0-9]/i.test(glob));
    return globs.some((glob) => globToRegExp(glob).test(relPath));
  });
}

function main() {
  const base = process.argv[2] || 'origin/main';
  const fromTemplate = templateHashes();
  const missing = changedFiles(base).filter((file) => {
    const stopAt = creditRoot(file);
    if (!stopAt || !ASSET_EXT.test(file) || IGNORED_DIR.test(file) || !fs.existsSync(path.join(ROOT, file))) {
      return false;
    }
    if (!file.startsWith('scripts/exampleTemplate/') && fromTemplate.has(hash(path.join(ROOT, file)))) {
      return false;
    }
    return !isCredited(file, creditTexts(path.posix.dirname(file), stopAt));
  });

  if (missing.length === 0) {
    console.log(`Asset credits: every asset added since ${base} is credited.`);
    return;
  }
  console.error(`Asset credits: ${missing.length} new asset file(s) aren't named in a credits file:\n`);
  for (const file of missing) {
    console.error(`  ${file}`);
  }
  console.error('\nName each one (author, licence, source, or "made for this repo") in a CREDITS.md in its');
  console.error('folder or a parent folder up to the example root (engine assets: LICENSE-THIRD-PARTY.md).');
  process.exit(1);
}

main();
