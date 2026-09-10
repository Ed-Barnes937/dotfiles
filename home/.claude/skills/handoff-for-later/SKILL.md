---
name: handoff-for-later
description: Write a handover document for a new Claude session to pick up the current task later, via /pickup. Gathers context from git state, conversation, and codebase, then writes a structured markdown file to ~/tmp/. Distinct from any repo-level handoff skill — this one is for parking work to resume in a future session.
---

# Handoff for later

Write a handover document that gives a fresh Claude session everything it needs to continue the current work.

## Step 1 — Determine the topic

If the user provided a topic or task name, use that. Otherwise, infer it from:
- The current branch name (`git branch --show-current`)
- Recent commit messages (`git log --oneline -10`)
- The conversation so far

Derive a short kebab-case slug (e.g. `broaden-pre-commit-eslint-regex`). This becomes the filename: `~/tmp/<slug>-handover.md`.

## Step 2 — Gather context

Collect information from whichever of these sources are available and relevant:

- **Repo identity**:
  - **Repository name** — the name of the canonical repository, *not* the working directory. If the current checkout is a git worktree, `git rev-parse --show-toplevel` returns the worktree folder (e.g. `bug-fixes-64647c86`), which is wrong. Resolve the main checkout first: `git rev-parse --path-format=absolute --git-common-dir` returns `<main-repo>/.git`; strip the trailing `/.git` to get the canonical repo path, and take its basename as the repository name (e.g. `malleable-plc-poc`).
  - **Canonical path** — the absolute path to that main checkout (the `<main-repo>` derived above), so a fresh session can target the real repository rather than a transient worktree.
  - Also capture the remote origin URL (`git remote get-url origin`), current branch, and base branch.
- **Conversation context**: what the user asked for, decisions made, approaches tried or rejected
- **Codebase**: key files involved, current state of the code, any configuration or tests relevant to the task

Do not dump raw command output. Synthesize what you learn into clear structured prose.

## Step 3 — Write the handover document

Use this structure (omit sections that don't apply):

```markdown
# <Title> — Handover

| Field | Value |
|-------|-------|
| **Date** | YYYY-MM-DD |
| **Status** | todo |
| **Repo** | repository name (canonical, not a worktree folder) |
| **Path** | absolute path to the main checkout |
| **Remote** | git remote origin URL |
| **Branch** | current branch |
| **PR target** | branch we're targeting for merge (e.g. main) |

## Goal

One or two sentences: what we're trying to accomplish.

## Motivation

Why this work matters. What problem it solves, what triggered it, or what breaks without it.

## Current State

Where things stand right now. Include:
- Key file paths and line numbers
- What's working and what isn't

## Proposed Change

What still needs to happen. Be specific — name files, functions, and approaches. If multiple approaches were considered, note which was chosen and why.

## Verification

How to confirm the work is correct. Include specific commands, test cases, or manual checks.

## Risk

What could go wrong or what to watch out for. Omit if the change is straightforward.

## Notes

Anything else a fresh session needs to know — environment quirks, decisions that were explicitly deferred.
```

**Status lifecycle:** A freshly written handover is always `todo`. The `/pickup` skill flips it to `in-progress` when work resumes, and the working session sets it to `done` when complete and offers to delete it. Only `todo` handoffs surface in the Raycast picker, so always write `Status: todo`.

**Writing guidelines:**
- Write for a reader with zero prior context — a new Claude session that hasn't seen this conversation.
- Be concrete: file paths, line numbers, exact commands, code snippets. Vague summaries are useless.
- Include code snippets for anything non-trivial
- If the task is partially complete, clearly separate "done" from "remaining".
- The reader should be able to search for relevant context quickly in a targetted manner given the information provided in this document

## Step 4 — Confirm

Show the user the path to the written file.
