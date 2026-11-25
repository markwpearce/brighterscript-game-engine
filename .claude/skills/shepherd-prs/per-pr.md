# Shepherding one PR

You own one PR from checkout to merge. Work in **dry-run** mode if your brief says so: do every
read-only step, but in place of a push, merge, PR comment or `gh issue create`, write down what
you would have done.

## 1. Check out

From the main repo root:

```bash
gh pr view N --json number,title,body,author,baseRefName,headRefName,isCrossRepository,maintainerCanModify,mergeStateStatus,files,closingIssuesReferences
git fetch origin <base> <headRefName>
git worktree add -B <headRefName> .claude/worktrees/pr-N origin/<headRefName>
cd .claude/worktrees/pr-N && npm ci && npx ropm install   # npm ci alone leaves rodash etc. missing
```

`-B` resets a stale local branch to the remote, so check `git log <headRefName> ^origin/<headRefName>`
first. If it's ahead, those commits haven't been pushed: ask the maintainer what to do with them.

**Fork PRs:** `git fetch origin pull/N/head` replaces the branch fetch, and `gh pr checkout N`
(run inside the worktree) sets up the fork remote. If `maintainerCanModify` is false, you can't
push. Review it, post your findings as a PR comment, and stop.

## 2. Bring it up to date

`git merge origin/<base>`. Never rebase, never force-push. To resolve a conflict, read both
sides' intent (`git log -p origin/<base> -- <file>`) and keep both behaviours. Don't just pick
one side. Run `npm run check` after resolving.

If `package-lock.json` changes, every `resolved` URL must point at `https://registry.npmjs.org/`.
Rewrite any other registry host before you commit, and don't name that host anywhere.

## 3. Review

Read first: the PR body, its linked issues, and the `docs/` guide, `specs/` file and
`.claude/rules/` file for each subsystem it touches. Then run `/code-review high`, passing the
worktree path and the range `origin/<base>...HEAD`. It may run in the background; wait for it to
finish before you sort findings. Meanwhile, review the diff yourself with these questions:

- **Performance:** does this code run per frame or per object? Look for AA literals, allocations,
  repeated method lookups or `RotateVectorAroundPoint3d`-style math in hot loops, and work that
  could be cached or culled first. On device, cost is roughly elements × statements.
- **Correctness:** edge cases, the CLAUDE.md device gotchas (`continue for` after an inner loop,
  `=` between objects, the bsc self-reference bug), missing `import`s, loose types.
- **Reuse:** does `src/source/` already have a helper for this? Is new code duplicated within the
  PR?
- **Tests:** new behaviour has a colocated `*.spec.bs`, and bug fixes have a test that failed
  before the fix.

Also read the review bot's comments and every human comment. Each one is either fixed or answered.

```bash
gh pr view N --json comments,reviews --jq '.comments[],.reviews[] | "\(.author.login): \(.body)"'
gh api repos/{owner}/{repo}/pulls/N/comments --jq '.[] | "\(.user.login) \(.path):\(.line): \(.body)"'
```

Sort every finding into one of these:

| Finding | Action |
|---|---|
| Bug or perf problem in code this PR adds or changes | Fix it here |
| Small cleanup or reuse in the PR's own code | Fix it here |
| A problem that existed before the PR, outside its scope, or bigger than the PR | File an issue |
| Speculative, or matter of taste | Leave it out; mention it in the report if it's worth knowing |

Before filing an issue, search for an existing one: `gh issue list --state all --search "<keywords>"`.
Also check the run's issue list in your brief. A new issue gets: what's wrong, where
(`file:line` on `main`), why it matters, a suggested fix, "Found while reviewing #N", and labels
from `bug`, `performance`, `enhancement`, `documentation`, plus a priority.

## 4. Fix

Follow CLAUDE.md conventions, and write tests first where you can. Run `npm run check` after
every change. Run `npm run check:all` if the PR touches `examples/`, `bsconfig*.json`, `package.json`,
`scripts/`, or any public class/function signature in `src/source/` (examples consume it).
Make one commit per logical fix. Commit messages explain *why*, and end with the attribution
lines from your system prompt.

## 5. Device testing

Test on a Roku when the PR changes rendering, drawables, cameras, audio, input, SceneGraph code
or game-loop timing, claims a perf change, or uses a construct that behaves differently on device
than in headless tests. Docs-only, script-only or test-only PRs don't need it. Say which applies
in the report. In dry-run, don't sideload. Say what you would run, on which device class, and
why.

- **Device:** use the Ultra (the default in `.env`). Use the Express, as well as or instead of
  the Ultra, when the PR is about low-end, 720p or Express-specific behaviour. For the Express, ask the maintainer for its address if your memory
  doesn't have it, and pass it as `ROKU_HOST`/`ROKU_PASSWORD` in the environment. Don't read
  `.env`. Name devices only by class in any text you write.
- **The Rokus are shared.** Before sideloading, `rokubot apps | grep ^dev`. If another project's
  dev channel is loaded, ask the maintainer before replacing it.
- Sideload and screenshot need the sandbox off and `NO_PROXY='*' no_proxy='*'`.
- **Behaviour:** run the affected example or test demo with the `rokubot-examples` skill. Run
  `TEST_SHARDS=<shards> npm run test:device` when the PR changes engine code that the headless
  tests cover. `SHARDS` in `scripts/run-tests-sharded.js` maps spec globs to shard names. Pick
  the shards that hold the changed files' specs.
- **Perf:** A/B `origin/<base>` against the PR branch on the same device. Use µs timers
  (`roTimespan.TotalMicroseconds()`), a warmup, and a `runid=` launch param so you can tell
  this run's console lines from replayed history. Do at least 2 runs per side; orbit-style cases
  vary by about 15%. You can reuse the PR description's numbers only if they came from the same
  device class.

## 6. Push, wait, merge

Green checks from before your merge or push don't count (look at `mergeStateStatus`). Wait for
a run on the commit you pushed.

```bash
git push                                   # never --force
gh pr checks N --watch --interval 30
```

Then reread the comments: the review bot reruns after each push. Address any new findings, the
same way as in step 3.

If CI is red, diagnose it with `gh run view <id> --log-failed`, fix it and push. Stop after 2
failed fix attempts. Once everything is green and every comment is resolved:

```bash
gh pr merge N --merge
gh pr view N --json state,mergeCommit    # confirm MERGED
```

## Stop conditions

Stop and **don't merge** if any of these happen:

- CI is still red after 2 fix attempts.
- The review finds a design problem that's too big to fix inside the PR.
- Device testing shows a regression, or a perf result goes against what the PR claims.
- A conflict is ambiguous: you can't tell what both sides intended.
- A Roku is needed but busy, and the maintainer hasn't freed it.

When you stop, post a PR comment covering what you found, what you pushed and what's blocking.
Then return your report.

## Report

Return exactly these sections:

```markdown
### #N Title: merged | stopped (<reason>) | dry-run
- Base update: clean | conflicts in <files>, resolved by <how>
- Review: <finding, then "fixed here (<sha>)" | "filed #M" | "would fix" | "would file: <title>">
- Comments: <bot/human comment, then how it was handled>
- Device: <Ultra|Express, what ran, result> | not needed (<why>)
- CI: <result, failures and fixes>
- Perf: <case | base | PR | change, device class, method, runs> | n/a
- Commits: <sha subject, one per line; say "pushed" or "local only">
- Not acted on: <findings left out as taste/minor, one line each> | none
- Issues filed: <#M title> | none
- Dry-run only, would do: <pushes, device runs, merge, comments, issues> | n/a
```
