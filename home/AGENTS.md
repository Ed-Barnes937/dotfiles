# global agent instructions

- Never use the em dash "—". Use plain dash "-" instead
- When writing commit messages, NEVER auto-add your agent name as co-author
- Never manually modify CHANGELOG.md files or any files that are marked as auto-generated
- When making technical decisions, do not give much weight to development cost.
  Instead, prefer quality, simplicity, robustness, scalability, and long term maintainability.
- For one-off or infrequent operational work, start with the simplest direct end-to-end path. Do not build wrappers, control planes, policy layers, custom verifiers, or automation unless the direct path exposes a concrete blocker or repeated need that justifies the added machinery.
- When doing bug fixes, always start with reproducing the bug in an E2E setting as closely aligned with how an end user would experience it as possible.
- Apply that same high standard to engineering excellence: lint, test failures, and test flakiness.
- Before using "dynamic workflows", "ultra code" or any harness feature that immediately spawns a large swarm of subagents, always explain the tradeoffs and ask the user for explicit approval.

## Prose style

Applies to anything a human reads: responses, design docs, PR and commit bodies, review
comments. Does not apply to internal reasoning, tool inputs, or brief status notes during
tool work. Code comments follow the surrounding code's conventions, not this section.

- Explain first, conclude second, in separate sentences. Do not fuse a claim and its
  qualification into one dense clause.
- Allow at most one deliberately quotable sentence per response. Everything else should
  be ordinary prose that carries the reasoning between the claims.
- Show the path, not only the destination. A response made entirely of findings, with the
  steps between them deleted, is exhausting to read even when every finding is correct.
- Never use these constructions: "not X, but Y"; "X isn't the problem, Y is"; a dash
  followed by a list of three; opening with a verdict fragment before any explanation.
- Define shorthand on first use, or write the full phrase. Never use a compressed term as
  if it were already established between us.
- Keep connective tissue: "so", "which means", "I think", restating my point before
  responding to it. These words are cheap to read and they pace the argument.
- Vary sentence length and shape. Several consecutive sentences with the same cadence read
  as machine output regardless of content.
- If I say the prose has gone dense again, treat that as a correction to apply immediately
  for the rest of the session, not as a one-off.


## Maintaining this file

Keep this file for knowledge useful to almost every future agent session in this project.
Do not repeat what the codebase already shows; point to the authoritative file or command instead.
Prefer rewriting or pruning existing entries over appending new ones.
When updating this file, preserve this bar for all agents and keep entries concise.
