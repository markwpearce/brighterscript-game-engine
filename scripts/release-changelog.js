#!/usr/bin/env node
// CHANGELOG.md helpers for the release workflows (.github/workflows/initialize-release.yml
// and publish-release.yml).
//
// Usage:
//   node scripts/release-changelog.js prepare <version> [date]
//     Moves everything under "## [Unreleased]" into a new "## [<version>] - <date>"
//     section (date defaults to today, UTC) and updates the compare links at the
//     bottom. Fails if [Unreleased] is empty.
//   node scripts/release-changelog.js notes <version>
//     Prints the body of that version's section, for the GitHub release notes.
//   node scripts/release-changelog.js append-unreleased <file>
//     Adds the file's contents to the end of [Unreleased] under "### Pull requests"
//     (the fallback when Claude couldn't draft the changelog).

const fs = require('fs');
const path = require('path');

const CHANGELOG = path.join(__dirname, '..', 'CHANGELOG.md');
const REPO_URL = 'https://github.com/markwpearce/brighterscript-game-engine';
const LINK_REF = /^\[[^\]]+\]: /;

function fail(message) {
    console.error(`release-changelog: ${message}`);
    process.exit(1);
}

function escapeRegExp(text) {
    return text.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

// The line index of a "## [name]" heading, or -1.
function findHeading(lines, name) {
    const heading = new RegExp(`^## \\[${escapeRegExp(name)}\\]`);
    return lines.findIndex((line) => heading.test(line));
}

// Start of the compare links at the bottom of the file - only the final run of
// link references, so one inside an entry doesn't end its section early.
function findLinkRefsStart(lines) {
    let end = lines.length;
    while (end > 0 && lines[end - 1].trim() === '') {
        end--;
    }
    let start = end;
    while (start > 0 && LINK_REF.test(lines[start - 1])) {
        start--;
    }
    return start;
}

// The first line after `start` that ends a section: the next "## " heading or the link references.
function findSectionEnd(lines, start) {
    const linkRefsStart = findLinkRefsStart(lines);
    for (let i = start + 1; i < linkRefsStart; i++) {
        if (lines[i].startsWith('## ')) {
            return i;
        }
    }
    return linkRefsStart;
}

function trimBlankLines(lines) {
    let start = 0;
    let end = lines.length;
    while (start < end && lines[start].trim() === '') {
        start++;
    }
    while (end > start && lines[end - 1].trim() === '') {
        end--;
    }
    return lines.slice(start, end);
}

function prepare(text, version, date) {
    const lines = text.split('\n');
    const unreleased = findHeading(lines, 'Unreleased');
    if (unreleased < 0) {
        fail('no "## [Unreleased]" heading in CHANGELOG.md');
    }
    if (findHeading(lines, version) >= 0) {
        fail(`CHANGELOG.md already has a [${version}] section`);
    }
    const end = findSectionEnd(lines, unreleased);
    const body = trimBlankLines(lines.slice(unreleased + 1, end));
    if (body.length === 0) {
        fail('[Unreleased] is empty - add the release\'s changes to CHANGELOG.md first');
    }

    const linkIndex = lines.findIndex((line, i) => i >= end && line.startsWith('[Unreleased]: '));
    if (linkIndex < 0) {
        fail('no "[Unreleased]: " compare link in CHANGELOG.md');
    }
    const previous = /\/compare\/(.+)\.\.\.HEAD\s*$/.exec(lines[linkIndex]);
    if (!previous) {
        fail(`can't read the previous tag from: ${lines[linkIndex]}`);
    }
    const tag = `v${version}`;
    const links = [
        `[Unreleased]: ${REPO_URL}/compare/${tag}...HEAD`,
        `[${version}]: ${REPO_URL}/compare/${previous[1]}...${tag}`
    ];

    return [
        ...lines.slice(0, unreleased + 1),
        '',
        `## [${version}] - ${date}`,
        '',
        ...body,
        '',
        ...lines.slice(end, linkIndex),
        ...links,
        ...lines.slice(linkIndex + 1)
    ].join('\n');
}

function appendUnreleased(text, addition) {
    const lines = text.split('\n');
    const unreleased = findHeading(lines, 'Unreleased');
    if (unreleased < 0) {
        fail('no "## [Unreleased]" heading in CHANGELOG.md');
    }
    const end = findSectionEnd(lines, unreleased);
    const body = trimBlankLines(lines.slice(unreleased + 1, end));
    return [
        ...lines.slice(0, unreleased + 1),
        '',
        ...(body.length > 0 ? [...body, ''] : []),
        '### Pull requests',
        '',
        ...trimBlankLines(addition.split('\n')),
        '',
        ...lines.slice(end)
    ].join('\n');
}

function notes(text, version) {
    const lines = text.split('\n');
    const start = findHeading(lines, version);
    if (start < 0) {
        fail(`no [${version}] section in CHANGELOG.md`);
    }
    const body = trimBlankLines(lines.slice(start + 1, findSectionEnd(lines, start)));
    return `${body.join('\n')}\n\n**Full changelog**: [CHANGELOG.md](${REPO_URL}/blob/v${version}/CHANGELOG.md)\n`;
}

const [command, version, date] = process.argv.slice(2);
const text = fs.readFileSync(CHANGELOG, 'utf8');
if (command === 'append-unreleased') {
    if (!version) {
        fail('usage: release-changelog.js append-unreleased <file>');
    }
    fs.writeFileSync(CHANGELOG, appendUnreleased(text, fs.readFileSync(version, 'utf8')));
    process.exit(0);
}
if (!version || !/^\d+\.\d+\.\d+(-[\w.]+)?$/.test(version)) {
    fail('usage: release-changelog.js <prepare|notes> <x.y.z> [date]');
}
if (command === 'prepare') {
    fs.writeFileSync(CHANGELOG, prepare(text, version, date || new Date().toISOString().slice(0, 10)));
} else if (command === 'notes') {
    process.stdout.write(notes(text, version));
} else {
    fail(`unknown command "${command}"`);
}
