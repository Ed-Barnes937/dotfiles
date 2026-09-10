---
name: pickup
description: Pick up work from a handoff file. Reads a ~/tmp/*-handover.md file produced by /handoff-for-later, then creates a new claude-commander session targeting the handoff's repo with the handoff context as the initial prompt. Offers an appropriate kick-off skill from the target repo (grill-me, wayfinder, implement) or falls back to proposing a plan. Use when the user wants to resume work from a handoff, pick up a handover, or continue where a previous session left off.
argument-hint: <handoff-file> [--here]
allowed-tools: Bash(ls *) Bash(claude-commander *) Read Edit Grep Glob
---

# Pickup — resume from a handoff

This skill has two modes:

- **Spawn mode (default)** — you create a *new* claude-commander session to pick up the handoff, and do NOT do the work yourself. Used when invoked manually from Claude, where the current session is the wrong place to work.
- **In-session mode (`--here`)** — you are ALREADY in the session that should do the work, because the launcher (e.g. the Raycast extension) already ran `claude-commander new` and this skill is its initial prompt. Do NOT spawn another session — read the handoff and proceed inline. This prevents the redundant doubled session that results when both the launcher and this skill create sessions.

## Step 1 — Parse arguments

Check `$ARGUMENTS` for a `--here` flag. If present, this is **in-session mode**; strip the flag, and whatever remains is the handoff file. Otherwise it is **spawn mode**.

If the remaining `$ARGUMENTS` names a file, use it directly. Accept both full paths and bare filenames (resolve bare names against `~/tmp/`).

If no argument was provided, list available handoff files:

```!
ls -lt ~/tmp/*-handover.md 2>/dev/null | head -10
```

Present the list and ask the user to pick one. Do not proceed until a file is selected.

## Step 2 — Read the handoff and extract fields

Read the full handoff file. Extract from the metadata table:

- **Path** — the absolute path to the main checkout, becomes the `--path` flag
- **Repo** — the repository name (informational; identifies which repo this handoff belongs to). Older handoffs may not have a separate `Path` row — in that case fall back to the `Repo` field for `--path`
- **PR target** — the branch this work will eventually merge into (e.g. `main`). This is NOT passed to `--base-branch` — it is informational only

Extract the slug from the filename (e.g. `desktop-notifications-handover.md` → `desktop-notifications`). This becomes the session name.

Then **mark the handoff as in-progress**: edit the `Status` row in the metadata table to read `| **Status** | in-progress |`. If the handoff is a legacy file with no `Status` row, add one directly under the `Date` row. Do this in both modes — picking up a handoff means work has resumed, so it should no longer surface as `todo` in the Raycast picker.

## Step 3 — Determine the kick-off

**If the user invoked a skill alongside `/pickup`** (e.g. `/grill-me`) or named one, use that — skip the offer below.

Otherwise, check which skills the target repo has installed (`ls <path>/.claude/skills/`) and **offer the user the appropriate kick-off** based on the handoff's state:

- **`grill-me`** — the Proposed Change is still a plan with open decisions that needs stress-testing. Use the handoff's Goal, Motivation, and Proposed Change as the plan to interrogate.
- **`wayfinder`** — the handoff describes a large, nebulous effort (more than one session's work) with no existing map.
- **`implement`** — a spec or tickets already exist (e.g. under `.scratch/<feature>/` in the target repo) and the handoff says the work is specified and ready to build.
- **Plan** (default, always available) —
  1. Verify the referenced files and line numbers are still current
  2. Propose a concrete implementation plan with specific files, functions, and line numbers
  3. Ask whether to start executing

Recommend one option; don't list all four mechanically. Only offer skills that are actually installed in the target repo.

## Step 4 — Act on the mode

### In-session mode (`--here`)

You are already in the right session — do NOT run `claude-commander`. Instead, do the Step 3 work yourself, here and now: you have already read the handoff in Step 2 (and flipped its `Status` to `in-progress`), so proceed directly to the chosen kick-off — run the selected skill, or propose the plan and ask whether to start. Stop after presenting the plan / starting the kick-off skill; do not begin executing without confirmation.

**On completion** — once the work described in the handoff is finished, edit the handoff's `Status` row to `| **Status** | done |`, then ask the user whether to delete the handoff file (`rm <path>`). Do not delete it without an explicit yes.

### Spawn mode (default)

Build an initial prompt that tells the new session to do the Step 3 work (naming the chosen kick-off skill if one was selected) — and to **read the handoff file first** (by its full path). Do not inline the entire handoff into the prompt; tell the new session to read the file. The prompt must also instruct the new session that, when the work is complete, it should set the handoff's `Status` to `done` and ask whether to delete the handoff file. Then launch:

```
claude-commander new "<session-name>" \
  --path "<path>" \
  --initial-prompt "<prompt>"
```

Where:
- `<session-name>` is the slug from the handoff filename
- `<path>` is the Path field from the handoff (fall back to the Repo field for older handoffs that lack a Path row)
- `<prompt>` is the initial prompt built from Step 3

Do NOT pass `--base-branch` — the session auto-generates its own branch from the session name and forks from `origin/main` by default. The **PR target** field in the handoff is for the new session to know where to target PRs, not for branch creation.

After launching, report the session name and confirm it was created.
