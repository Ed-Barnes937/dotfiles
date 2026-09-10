---
name: testing-notes
description: Add testing notes to a PR description. Analyzes the branch diff to generate notes covering what changed, expected behaviour, and potential regressions.
disable-model-invocation: true
allowed-tools: Bash(gh *) Bash(git *)
---

Add a **Testing Notes** section to a pull request description for the current branch.

## Step 1 — Find the PR

Get the current branch name and find open PRs with that branch as the head:

```!
git branch --show-current
```

Then run `gh pr list --head <branch> --state open --json number,title,url` to find matching PRs.

- If **no PRs** exist, tell the user and stop.
- If **one PR** exists, use it.
- If **multiple PRs** exist, present them as a numbered list and ask the user which one to update.

## Step 2 — Analyse the changes

Determine the base branch of the PR (`gh pr view <number> --json baseRefName`), then gather:

1. `git log --oneline <base>..HEAD` — commit history
2. `git diff <base>...HEAD` — full diff
3. The existing PR description (`gh pr view <number> --json body`)

Read the diff and commits carefully. Understand the intent behind the changes, not just the mechanics.

## Step 3 — Write the testing notes

Draft a **Testing Notes** section with these subsections:

### What's Changed
Summarise the user-visible and developer-visible changes in plain language. Group related changes together. Avoid restating commit messages — explain what a tester needs to know.

### Expected Behaviour
Describe the correct behaviour a tester should verify. Be specific: name the pages, actions, or API calls involved. Write these as checkable items (e.g. "Clicking X should now show Y").

### Potential Regressions
List areas that could break as a side effect of these changes. Only include this subsection if there are genuine regression risks — omit it if the changes are well-isolated.

## Step 4 — Update the PR

Show the drafted testing notes to the user for approval before applying.

Once approved, append the testing notes to the **end** of the existing PR body using:

```
gh api repos/{owner}/{repo}/pulls/<number> -X PATCH -f body="<updated body>"
```

Preserve the entire existing description — only append the new section. If a **Testing Notes** section already exists in the description, replace it rather than duplicating.
