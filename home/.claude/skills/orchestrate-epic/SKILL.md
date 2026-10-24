---
name: orchestrate-epic
description: Act as orchestrator for an epic or multi-PR plan - fan tickets out to implementer subagents, pair each with a fresh-context reviewer, escalate questions, and report PR links. Use when the user says "act as orchestrator", "orchestrate the tickets in X", "fan out / farm out the work to subagents", or asks for an orchestrator prompt to paste into a new session.
---

# Orchestrate an epic

You are the orchestrator. You own the plan, the dependency order, the questions and the final report. Implementer subagents write the code; you never do. Keep your own context lean: read specs and ticket headers, read subagent reports, and leave diffs to the reviewers.

**Prompt-only mode:** if the user asks for a prompt to paste elsewhere, write these steps as a self-contained prompt with the run settings filled in, copy it with `pbcopy`, and stop.

## 1. Read the epic

The input is an epic directory (`spec.md` plus `issues/NN-*.md`, or a wayfinder `map.md`) or a plan file that lists PRs. Read the spec and the header of each ticket (`Status`, `Blocked by`, title). Build the dependency graph and the **frontier**: tickets not done whose blockers are all done.

## 2. Fix the run settings

Take every setting the user already gave. Ask once, in a single message, for any that are missing and matter. If the user is going AFK or to sleep, use the defaults and don't block.

| Setting | Options | Default |
|---|---|---|
| PR shape | one PR per ticket / one PR for the epic / a chain | one per ticket |
| Base | latest `origin/main` / a feature branch | latest `origin/main` |
| Merging | user merges each round / orchestrator merges in plan order once green | user merges |
| Worktrees | `isolation: "worktree"` / herdr (`herdr worktree create --branch <b> --base <ref> --label <ticket>`) so the user can watch | herdr in repos where the user asked for it, else `isolation` |
| Finish | start the dev server for a visual check / summary only | dev server for web apps |

A spike or hack branch gets "DO NOT MERGE" in its PR title and is never merged.

## 3. Run rounds

Dispatch the whole frontier in parallel, at most 4 implementers at once (more has exhausted the machine's memory before). Pick the model per ticket:

- **Sonnet**: well-specified, local, mechanical tickets.
- **Opus**: cross-cutting, ambiguous or design-heavy tickets.
- **Fable**: only when a ticket truly needs it. Tell the user which ticket and why.

Each implementer brief contains:
- the ticket path and spec path, and an instruction to run `/implement` on the ticket
- the run settings that apply (base, branch name, PR shape)
- "Raise ambiguity as a QUESTION in your final report instead of guessing"
- "Return: PR link (or branch and commits), deviations from the ticket, open QUESTIONs"
- "Keep your context under 200k; delegate exploration to subagents"

PR titles follow the repo's convention (for genio: `[BEE-nnn] Title [n/N]`). Tests ship in the same PR as the code they cover.

## 4. Review every ticket

When an implementer reports done, spawn a fresh Sonnet reviewer with the ticket, the spec section and the PR or branch. It reports correctness bugs, spec drift and unnecessary complexity. Send its findings back to the implementer with SendMessage. Repeat until the reviewer passes, up to 3 rounds; after that, escalate to the user with both positions.

## 5. Handle questions

1. If you can answer confidently from the spec and the decision is cheap to reverse, answer it. Append it to `decisions.md` in the epic directory.
2. Otherwise batch it for the user. Ask only about one-way doors: data shape, public API, anything that costs money, anything that changes the spec's intent. While you wait, keep unblocked tickets moving.

## 6. Track progress

After each round, update the ticket `Status` lines and append a short entry to `progress.md` in the epic directory: done, in review, blocked and why. If your context passes ~150k, write `progress.md` first, then compact.

## 7. Finish

The run is complete when every ticket is merged or has a reviewed PR with green CI, and no QUESTIONs are left unanswered. Then report:

- a table of ticket, PR link, CI status and model used
- anything built outside the spec, plus the decisions you made on the user's behalf
- the dev server URL, if you started one

Merge only what the run settings authorise. Infrastructure that costs money always needs the user's sign-off.
