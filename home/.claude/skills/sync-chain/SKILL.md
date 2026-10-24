---
name: sync-chain
description: Bring a chain of stacked PRs up to date by merging main into the root PR, then each parent PR into its child, pushing after every merge, optionally getting CI green from the top down. Use when the user says "merge main down the chain", "update each PR in the stack", "merge the upstream PR into this branch", or pastes a list of chained PR links.
---

# Sync a PR chain

A chain is PRs where each one's base is the previous PR's branch, ending at `main`. Syncing it means every branch contains its parent's latest commits, and every merge is pushed.

**Hard rule:** integrate only with merge commits. Use `git merge --no-edit`, `git pull --no-rebase` and plain `git push`. Never rebase or force-push. `gh stack sync` and `gh stack rebase` both rebase and force-push, so use `gh stack` only to read the chain order.

## 1. Discover the chain

From the PRs the user gave, or from the current branch:

- If a stack exists, `gh stack view --json` gives the order.
- Otherwise walk down with `gh pr view <n> --json number,headRefName,baseRefName` until the base is `main`. Walk up with `gh pr list --base <head> --json number,headRefName`.

Print the chain from root to tip as a numbered list of PR number, branch and base. If a branch has two children, or the user's list disagrees with GitHub, stop and ask.

"Merge the upstream PR into this branch" is a chain of two: merge the parent branch into the current one.

## 2. Merge root to tip

`git fetch origin`. A branch already checked out in another worktree (`git worktree list`) gets worked on there with `git -C <path>`. Otherwise use a temporary worktree under the scratchpad.

For each branch in order:

1. Make the local branch match the remote: `git merge --ff-only origin/<branch>`.
2. Merge the parent. For the root that is `origin/main`; for the others it is the parent branch you just pushed.
3. Resolve any conflicts. If a resolution needs a product or design judgement, stop and ask.
4. Carry the repo's commit-message CI tags onto the merge commit when they apply. For example, genio's `[USS]` goes on when the merged-in changes touch UI. Check the repo's CLAUDE.md.
5. Push immediately.

If a push or signing fails, stop and report. Never bypass hooks or signing.

## 3. Get CI green (when asked)

When the user wants the chain green, work top-down from the root.

- Watch with the `monitor-ci-and-fix` skill if the repo has it, otherwise `gh pr checks <n> --watch`.
- Fix a failure in the lowest PR where it originates. Then re-run step 2 from that PR down, so the fix flows into every descendant.
- If the user also wants review comments handled ("and ONLY then merge down"), finish each PR's comments before merging it into its child.

## 4. Report

The sync is complete when every branch in the chain contains its parent's head and is pushed. Report a table with these columns: position, PR, branch, merge result (clean / conflicts resolved / up to date), pushed SHA, CI status. List any conflict resolutions the user should eyeball.

Merging a PR into `main` is the user's call unless they asked for it.
