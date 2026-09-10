---
name: claude-usage-audit
description: >-
  Audit the user's own Claude Code usage patterns from their transcripts and
  produce a visual report (Artifact) covering context fill, turn count, token
  spend, subagent usage, and search/read tool discipline — plus static guidance
  (/clear vs /compact, efficiency tools installed, a drop-in CLAUDE.md block,
  subagent advice). Use this whenever the user wants to understand how they use
  Claude Code, where their tokens/context go, whether their sessions run too
  long, how to be more context-efficient or cheaper, or asks for a "usage
  report / audit / dashboard" of their own Claude activity. Trigger even when
  they don't say "audit" — e.g. "what am I spending tokens on", "are my
  sessions too long", "how do I use Claude more efficiently", "analyse my
  transcripts".
---

# Claude Code usage audit

Analyze the user's local Claude Code transcripts and publish a single visual
report of their usage patterns with concrete guidance.

## Why this exists

Cost and context discipline in Claude Code come down to one relationship:
**spend ≈ (average context size) × (number of turns)**. Long single-thread
sessions re-read a large accumulated context on every turn, which is where most
token spend hides. This skill measures that from the user's real transcripts and
pairs it with the fixed guidance that addresses it.

## Steps

1. **Run the analysis script.** It reads every `*.jsonl` under
   `~/.claude/projects`, computes the stats, checks which efficiency tools are
   installed on this machine, and writes a self-contained HTML fragment.

   ```bash
   python3 <skill-dir>/scripts/analyze.py --out <scratchpad>/usage-audit.html
   ```

   Write the HTML to the session scratchpad directory, not the project. The
   script prints a one-line summary (sessions, median peak, subagent calls,
   estimated cost, grep-vs-rg) to stdout — read it so you can relay the
   headline numbers.

   Optional flags: `--projects DIR` (default `~/.claude/projects`),
   `--top N` (rows in the heavy-sessions table, default 12).

2. **Publish the report as an Artifact.** The script's output is already a body
   fragment (styles + content, no `<html>/<head>/<body>` — the Artifact tool
   injects those). Publish it directly:
   - `file_path`: the HTML you just wrote
   - `title`: "Claude Code usage audit"
   - `favicon`: 📊
   - `description`: one line, e.g. "Context, turn-count and token-spend patterns from your Claude Code transcripts."

   You do NOT need to reload the artifact-design skill or hand-write HTML — the
   script already produces a designed, theme-aware page. Only open the file to
   tweak design if the user asks for changes.

3. **Relay the headline, don't dump the page.** The artifact isn't shown to the
   user automatically — give them the link plus 2–4 plain-English takeaways from
   the summary line (e.g. "median session is lean at ~47k, but your heaviest ran
   1,739 turns; grep beats rg 2130:48"). Offer the next concrete action rather
   than listing everything on the page.

   Note on subagents: they are recorded as the `Agent` tool (and `Workflow`),
   with the subagent's own turns flagged `isSidechain:true` — the script counts
   all of these. Don't claim the user "never delegates" unless the spawn count
   really is zero.

## Notes

- The script is read-only over the transcripts and safe to re-run anytime.
- Cost is an approximation using standard Opus rates and is labelled as such on
  the page; don't present it as exact.
- If `~/.claude/projects` is empty or missing, say so — there's nothing to audit
  yet rather than an error to debug.
