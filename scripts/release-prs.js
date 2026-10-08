#!/usr/bin/env node
// Collects the PRs merged to main since the last release tag, for
// .github/workflows/initialize-release.yml. Needs `git` (with tags and full
// history) and an authenticated `gh`.
//
// Usage: node scripts/release-prs.js <outDir>
//   Writes <outDir>/prs.md (each PR's title, description and closed issues, for
//   Claude to draft the changelog from) and <outDir>/pr-list.md (one bullet per
//   PR), and prints how many PRs it found.

const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

function run(command, args) {
    return execFileSync(command, args, { encoding: 'utf8' }).trim();
}

// A merge commit's subject, or a squash merge's "Title (#123)".
function prNumberFromSubject(subject) {
    const match = /^Merge pull request #(\d+)/.exec(subject) || /\(#(\d+)\)$/.exec(subject);
    return match ? Number(match[1]) : undefined;
}

const outDir = process.argv[2];
if (!outDir) {
    console.error('usage: release-prs.js <outDir>');
    process.exit(1);
}

const tag = run('git', ['describe', '--tags', '--abbrev=0', '--match', 'v[0-9]*']);
const subjects = run('git', ['log', '--first-parent', '--format=%s', `${tag}..HEAD`]).split('\n');
const numbers = [...new Set(subjects.map(prNumberFromSubject).filter((n) => n !== undefined))].sort((a, b) => a - b);

const prs = numbers
    .map((n) => JSON.parse(run('gh', ['pr', 'view', String(n), '--json', 'number,title,body,url,headRefName,closingIssuesReferences'])))
    .filter((pr) => !pr.headRefName.startsWith('release/'));

const details = prs.map((pr) => {
    const closes = pr.closingIssuesReferences.map((issue) => `#${issue.number}`).join(', ') || 'none';
    return `## #${pr.number}: ${pr.title}\n\nCloses: ${closes}\n\n${(pr.body || '').trim()}\n`;
});
fs.writeFileSync(path.join(outDir, 'prs.md'), `# PRs merged since ${tag}\n\n${details.join('\n')}`);
fs.writeFileSync(path.join(outDir, 'pr-list.md'), prs.map((pr) => `- ${pr.title} ([#${pr.number}](${pr.url}))`).join('\n') + '\n');
console.log(prs.length);
