---
name: shepherd-prs
description: Work through this repo's open, non-draft pull requests one at a time - bring each up to date with its base, review and fix it, file follow-up issues, test on a Roku when needed, then merge once CI is green. Run only when a maintainer invokes /shepherd-prs.
disable-model-invocation: true
argument-hint: "[dry-run] [PR numbers...]"
---

# Shepherd open PRs

You coordinate; a fresh subagent handles each PR, one at a time, following
[per-pr.md](per-pr.md). Running PRs one after another matters: each merge changes `main` for the
next one, and the Rokus are shared.

## Arguments

- `dry-run`: plan and review, but don't push, merge, comment or file issues. Each PR report says
  what *would* have happened.
- PR numbers: work only on those PRs (still in dependency order).

## 1. Collect

```bash
gh pr list --state open --limit 100 \
  --json number,title,isDraft,author,baseRefName,headRefName,isCrossRepository,additions,deletions,changedFiles,files,labels
```

Leave out drafts and `release/*` PRs. Merging a release PR publishes to npm (see
`.claude/rules/releasing.md`), so list those in the summary for the maintainer instead.

## 2. Order

1. **Stacks first:** a PR whose base is another open PR's branch goes after that PR. When the base
   PR merges, GitHub retargets the stacked PR to `main`. Check that it did before you start on it.
   Stacks also hide behind a `main` base: if another open PR's head commit is an ancestor of this
   branch (`git merge-base --is-ancestor origin/<other-head> origin/<this-head>`), this PR
   includes that one, so it goes after it.
2. **Then smallest blast radius first:** fewer lines changed, fewer shared files. When two PRs
   touch the same files, take the smaller one first so the bigger one merges `main` once, at
   the end.
3. Print the order with a one-line reason for each PR, then start. After every merge, recompute
   the order for the PRs that are left.

## 3. Run each PR

Start the run's ledger at `out/shepherd-prs.md` (git-ignored). Append each PR's report as it
comes in, so the summary survives context compaction.

For each PR, dispatch one `general-purpose` subagent with this brief, filled in:

> Shepherd PR #N (`<title>`, base `<base>`, author `<login>`, fork: yes/no) in
> `<repo root>`. Mode: live | dry-run. Earlier PRs this run: `<merged #s>`; issues already
> filed this run: `<#s + titles>` (don't duplicate them). Read and follow
> `.claude/skills/shepherd-prs/per-pr.md` exactly, and return its report.

Wait for each report before you dispatch the next PR. If a PR stops (see per-pr.md), keep going
with the rest. Its PR comment explains why.

## 4. Final summary

Build the summary from the ledger, in this shape:

```markdown
## PRs
### #N Title: merged | stopped (reason) | dry-run
- Base update: clean | conflicts in <files>, resolved by <how>
- Review: <findings, each marked "fixed here (sha)" or "filed #M">
- Review bot / human comments: <addressed how>
- Device: <device class, what was run, result> | not needed (why)
- CI: <green after N runs; what failed and the fix>

### Performance
<one block per perf-relevant PR>
**#N** <what changed>. Device class (Ultra/Express), method, runs.
| Case | main | PR | Change |

## New issues
- #M Title (from #N), labels

## Skipped
- Drafts, release PRs, and anything else left alone, with the reason
```

Refer to devices only by class ("the Ultra", "the Express"). Never give IP addresses, hostnames
or credentials in the summary, ledger, commits, PR comments or issues.

Delete the PR worktrees the subagents made (`git worktree remove .claude/worktrees/pr-<N>`).
