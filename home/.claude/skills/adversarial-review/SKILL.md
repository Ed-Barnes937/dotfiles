---
name: adversarial-review
description: Adversarial code review via GPT with full repo access. Sends GPT into the repo to inspect the diff, explore callers/types/tests, and report real bugs, security issues, and missed edge cases. Use when user wants a second opinion, red-team review, or says "adversarial review".
---

Run an adversarial review by launching a GPT session with full repo access via openCode. GPT explores the repo itself to gather context. All review happens against local git state — nothing is pushed to a remote.

### 1. Determine scope

Pick the right scope based on context. If unclear, ask the user.

| Scope | Diff command | When to use |
|-------|-------------|-------------|
| `staged` | `git diff --cached` | Default. User has staged changes but not yet committed. |
| `last` | `git diff HEAD~1` | User just committed locally. |
| `branch` | `git diff <base>...HEAD` | User wants full branch review before pushing/PR. Base defaults to `main`. |

### 2. Verify the diff is non-empty

Run the appropriate `git diff` command and check for output. If empty, tell the user there are no changes to review and stop.

### 3. Launch GPT review via openCode

Run the following command, substituting `{LABEL}` (e.g. "staged changes", "branch diff vs main") and `{DIFF_CMD}` with the appropriate values from step 1:

```bash
opencode run --dir "$PWD" \
  "You are an adversarial code reviewer. Your job is to find real problems, not nitpick style. You have full access to the repo.

Review the {LABEL} in this repo.

STEP 1: Run \`{DIFF_CMD}\` to see the diff.

STEP 2: Gather context to inform your review. For each non-trivial change:
  - Read the full function/method surrounding each changed hunk
  - Grep for direct callers of any modified function to check for contract violations
  - Read type definitions and interfaces referenced by changed code
  - Check if tests exist for the changed code paths

Budget your context gathering:
  - Read at most the one function surrounding each changed hunk, not the whole file
  - Grep for direct callers only, not transitive
  - Stop gathering once you can confirm or rule out an issue
  - If a change looks straightforward, move on without gathering context
  - Limit yourself to reading at most 10 files total

STEP 3: With full context, report ONLY:
  - Bugs (logic errors, off-by-ones, null derefs, race conditions)
  - Security issues (injection, auth bypass, data leaks)
  - Missed edge cases that will break in production
  - Silent failures (errors swallowed, fallbacks that hide problems)
  - Contract violations (callers that assume old behavior the diff changes)
  - Missing test coverage for new/changed code paths

For each finding:
1. File path and line number
2. Quote the problematic code
3. Explain what breaks and under what conditions
4. Rate severity: CRITICAL / HIGH / MEDIUM

If you find nothing, say 'No issues found.' No padding, no praise, no suggestions." \
  --format default
```

This may take 1-2 minutes depending on the size of the diff.

### 4. Triage and act on findings

Once GPT responds, present the findings to the user in a summary table:

| # | Severity | File | Finding |
|---|----------|------|---------|
| 1 | CRITICAL | ... | ... |

Then for each finding:
- **Agree** — fix it immediately and explain what you changed.
- **Disagree** — explain why GPT's concern doesn't apply (false positive, already handled, etc.).
- **Needs discussion** — present both sides and let the user decide.

Do NOT blindly apply all suggestions. Use your own judgment. The value is the adversarial tension between two models, not uncritical compliance.

### 5. Optional re-review

After fixing findings, offer to re-run the review on the updated diff to verify fixes and catch any regressions introduced. Only re-run if fixes were non-trivial.
