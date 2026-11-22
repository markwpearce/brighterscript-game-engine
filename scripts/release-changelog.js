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
//   node scripts/release-changelog.js pr-body <version> <drafted|fallback|none> [prListFile]
//     Prints the release PR's description: the version's notes, then the PR list if
//     it fits under GitHub's body limit (the notes are cut short if even they don't).
//   node scripts/release-changelog.js check-draft <originalFile>
//     Fails unless CHANGELOG.md differs from <originalFile> only inside [Unreleased],
//     and [Unreleased] isn't empty.

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

// The changelog with the body of [Unreleased] cut out, to compare everything else.
function withoutUnreleasedBody(text) {
    const lines = text.split('\n');
    const unreleased = findHeading(lines, 'Unreleased');
    if (unreleased < 0) {
        return undefined;
    }
    return [...lines.slice(0, unreleased + 1), ...lines.slice(findSectionEnd(lines, unreleased))].join('\n');
}

function checkDraft(text, original) {
    const outside = withoutUnreleasedBody(text);
    if (outside === undefined || outside !== withoutUnreleasedBody(original)) {
        fail('the draft changed CHANGELOG.md outside [Unreleased]');
    }
    const lines = text.split('\n');
    const unreleased = findHeading(lines, 'Unreleased');
    if (trimBlankLines(lines.slice(unreleased + 1, findSectionEnd(lines, unreleased))).length === 0) {
        fail('[Unreleased] is empty after the draft');
    }
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

// GitHub rejects PR bodies over 65536 characters; leave headroom.
const PR_BODY_LIMIT = 60000;

const NOTES_INTRO = {
    drafted: '> Claude drafted these notes from the PRs merged since the last release - check them, and edit CHANGELOG.md on this branch to fix anything.',
    fallback: '> Claude didn\'t draft usable notes, so CHANGELOG.md has a plain PR list - rewrite it on this branch before merging.',
    none: '> No PRs were merged since the last release, so these are the [Unreleased] notes as written.'
};

function prBody(text, version, kind, prList, limit = PR_BODY_LIMIT) {
    const head = [
        `Release ${version}. Merging this tags \`v${version}\`, publishes to npm and creates the GitHub release with these notes:`,
        '',
        NOTES_INTRO[kind] || NOTES_INTRO.none,
        '',
        '---',
        '',
        ''
    ].join('\n');
    const releaseNotes = notes(text, version);
    const list = (prList || '').trim();
    if (list) {
        const full = `${head}${releaseNotes}\n---\n\nPRs in this release:\n\n${list}\n`;
        if (full.length <= limit) {
            return full;
        }
    }
    const omitted = list ? '\n---\n\n_The list of PRs in this release is left out to keep this description under GitHub\'s size limit._\n' : '';
    if (head.length + releaseNotes.length + omitted.length <= limit) {
        return `${head}${releaseNotes}${omitted}`;
    }
    const cut = `\n\n_The notes are cut short here to fit GitHub's size limit - see CHANGELOG.md on this branch for the rest._\n${omitted}`;
    const room = limit - head.length - cut.length;
    const kept = releaseNotes.slice(0, room);
    const lastLine = kept.lastIndexOf('\n');
    return `${head}${lastLine > 0 ? kept.slice(0, lastLine) : kept}${cut}`;
}

const [command, version, date, extra] = process.argv.slice(2);
const text = fs.readFileSync(CHANGELOG, 'utf8');
if (command === 'append-unreleased') {
    if (!version) {
        fail('usage: release-changelog.js append-unreleased <file>');
    }
    fs.writeFileSync(CHANGELOG, appendUnreleased(text, fs.readFileSync(version, 'utf8')));
    process.exit(0);
}
if (command === 'check-draft') {
    if (!version) {
        fail('usage: release-changelog.js check-draft <originalFile>');
    }
    checkDraft(text, fs.readFileSync(version, 'utf8'));
    process.exit(0);
}
if (!version || !/^\d+\.\d+\.\d+(-[\w.]+)?$/.test(version)) {
    fail('usage: release-changelog.js <prepare|notes|pr-body> <x.y.z> [date|notesKind] [prListFile]');
}
if (command === 'prepare') {
    fs.writeFileSync(CHANGELOG, prepare(text, version, date || new Date().toISOString().slice(0, 10)));
} else if (command === 'pr-body') {
    process.stdout.write(prBody(text, version, date, extra && fs.existsSync(extra) ? fs.readFileSync(extra, 'utf8') : ''));
} else if (command === 'notes') {
    process.stdout.write(notes(text, version));
} else {
    fail(`unknown command "${command}"`);
}
