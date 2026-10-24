---
name: pr-triage
description: Triage PR review comments (Copilot or human) into a table with suggested actions, wait for per-item decisions, then fix, push and resolve threads. Also a read-only pair-review mode for someone else's PR that posts nothing. Use when the user says "review the copilot comments", "what do you make of X's comments", "address the PR comments", gives a cc-comments-*.md file, or asks to "pair review" a PR.
---

# PR triage

Two modes. Pick from the request:

- **Comments mode**: there are review comments to deal with on a PR, usually the user's own.
- **Pair-review mode**: the user wants to review someone else's PR with you, or says "don't post anything". This mode is read-only on GitHub from start to finish.

## Triage table

Both modes present findings in one table, with a row for every finding (no top-N cap):

| # | | Who | Where | Gist | Suggested action |
|---|---|---|---|---|---|

The second column is an icon:
- 🔴 bug or correctness issue
- 🟠 worth changing
- 🟡 nit or optional
- ⚪ disagree or dismiss
- 🔵 needs the user's call

"Where" is `file:line`, and "Gist" fits in one line. Put longer reasoning under the table, keyed by number.

## Comments mode

### 1. Gather

- **The PR:** use the number given, or `gh pr view --json number,headRefName,baseRefName,author`. Confirm the current branch is the PR's head branch. If it isn't, check it out or switch to the worktree that has it before reading code.
- **Pending reviews:** if Copilot still has a review pending (`reviewRequests`), wait for it, polling every 30s for up to 10 minutes.
- **The threads:** fetch unresolved review threads via GraphQL:
  ```bash
  gh api graphql -F owner='{owner}' -F repo='{repo}' -F pr=<n> -f query='
  query($owner:String!,$repo:String!,$pr:Int!){repository(owner:$owner,name:$repo){pullRequest(number:$pr){
    reviewThreads(first:100){nodes{id isResolved comments(first:20){nodes{databaseId path line body author{login}}}}}}}}' \
    --jq '[.data.repository.pullRequest.reviewThreads.nodes[]|select(.isResolved|not)]'
  ```
- **Exported comments:** if the user gave a `cc-comments-*.md` file (exported from CC-GUI review mode), read it instead. Those comments have no GitHub threads.
- **Scope:** if the user restricted the set ("only Copilot's", "only the unresolved ones", "Alex's comments"), filter to it.

### 2. Triage and STOP

Read the code around each comment and judge it on its merits; reviewers, Copilot included, are often wrong. Present the triage table. Then stop. Make no edits, replies or resolutions until the user answers per item (e.g. "1, 4 fix; 5 remove it; 7 leave"). Silence, or an all-fix table, is not approval.

### 3. Act on the decisions

1. Make every approved change.
2. Run the repo's checks for the affected packages, as described in its CLAUDE.md.
3. Commit once and push.

Then handle each GitHub thread, unless the user set a different reply policy for this run:

- **Fixed:** resolve it, with no reply.
- **Declined Copilot comment:** reply in one plain sentence saying why, then resolve.
- **Declined human comment:** reply in one or two plain sentences saying why, and leave the thread open for them.

Write replies the way the user would type them: short, direct, no preamble.

```bash
gh api repos/{owner}/{repo}/pulls/<n>/comments -X POST -f body='<reply>' -F in_reply_to=<databaseId>
gh api graphql -f query='mutation{resolveReviewThread(input:{threadId:"<id>"}){thread{isResolved}}}'
```

This mode is complete when every approved item is pushed and every thread is handled per its decision. Report what was fixed, replied to and left open.

## Pair-review mode

1. Read the PR description, the linked ticket if any, the full diff (`gh pr diff <n>`) and existing review threads. Explore callers, types and tests around the changed code. On a large PR, split the exploration across subagents by area.
2. Look for correctness bugs, edge cases, spec drift, unnecessary complexity, missing tests and readability issues. Check each finding against the actual code before listing it.
3. Present the triage table with every finding. For each, give a draft comment in the user's voice, one or two plain sentences.
4. Make no GitHub writes in this mode: no comments, no reviews, no approvals. If the user later picks drafts to post, post exactly those, as they asked.
