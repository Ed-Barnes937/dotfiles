---
name: adversarial-pairing
description: >-
  Iterative adversarial pair-programming with a read-only GPT reviewer (via opencode):
  loop write → review → fix against a warm reviewer session until both models agree or a
  round cap is hit. The loop spends real tokens on an external model, so it ALWAYS confirms
  with the user before starting — it never assumes or auto-runs. Use this when the user
  wants continuous, in-the-loop external review WHILE building — e.g. "pair with GPT on
  this", "have GPT review as I go", "loop until you both agree", "adversarial pairing",
  "review each step with GPT", "co-develop this with GPT". ALSO surface it — by ASKING
  first, never by starting — when about to implement or having just implemented HIGH-STAKES
  work where a second model earns its keep: authentication/authorization/security,
  concurrency/async/locking, public API or wire/contract changes, or data migrations. Do
  NOT use it for routine feature work or "just get a PR up" with no risk signal, and do NOT
  use it for a single one-shot review of an already-finished diff — this skill is
  specifically the iterative, build-alongside pairing loop, not a one-pass reviewer.
---

# Adversarial Pairing

Pair-program a change with a **read-only GPT reviewer** running in opencode. You (Claude)
write all the code; GPT reviews each slice and argues back; you loop until you both agree
or hit a round cap.

This skill is specifically the **iterative, build-alongside loop**. If the user only wants a
single one-shot pass over an already-finished diff, that's a different need — don't start the
loop for it. And because each round spends real tokens on an external model, **never start the
loop without an explicit go-ahead** (see *Always confirm first*).

## Why it's built this way

The design deliberately keeps the two models **federated, not merged** — that is what makes
it cheap enough to run in a loop:

- **You stay a normal session and keep your prompt cache.** Nothing wraps your context. The
  reviewer is just a tool you shell out to.
- **GPT stays warm in its own persistent opencode session.** You seed it *once* with the
  intent of the change, then feed it only the new diff each round. It never re-pays to
  re-understand the goal, and it doesn't re-dig the repo from cold every time.
- **You are the single writer.** GPT is read-only — it returns findings and *proposes*
  tests as text, but never touches the tree. That removes write races and stops the
  reviewer "helpfully" rewriting your code.

The cost of federation is that GPT reviews against a *curated* intent rather than your full
reasoning. Two mechanisms below recover most of that: a clear **intent brief** up front, and
a **clarification back-channel** so GPT asks instead of guessing.

## When this skill applies

| Signal | Applies? |
|--------|----------|
| "pair with GPT", "review as I go", "loop until you agree", "co-develop with GPT" | **Yes** — confirm, then loop |
| about to build / just built auth, concurrency, API contracts, migrations | **Yes — but ask first** whether they even want it |
| routine feature work, "just get a PR up", no risk signal | No — just do the work |
| a single one-shot pass over an already-finished diff | No — this skill is the iterative loop, not a one-pass reviewer |

## Always confirm first

This skill **never starts the loop on its own.** Each round spends real tokens on an external
model, and a pairing loop changes the rhythm of the work — so the user always gets to opt in.

**Always ask, with no exceptions — including when the user named this skill or asked for pairing
directly.** Naming the skill is not the same as confirming the spend: the user may be exploring,
or expect to approve scope first. So even on an explicit request, ask the one-line yes/no and
wait for the answer before *Setup*. Do not treat "do the adversarial pairing thing" or "pair
this with gpt" as the go-ahead by itself.

Keep the question **lightweight — a single yes/no.** Don't preview the intent brief, the round
cap, or what context you'd send to GPT; that's noise at decision time. Just ask whether to pair:

**Direct** — the user explicitly asked to pair with GPT:

> Want me to pair this with a GPT reviewer as I build it?

**Offer** — you arrived here because the work is high-stakes (auth, concurrency, public API/
contract, migration) but the user didn't ask for review:

> This touches `<auth / the migration / the public API>` — want me to pair it with a GPT reviewer?

Either way, **wait for an explicit yes before *Setup*.** Write the intent brief only once they've
said yes — it's setup, not part of the question.

## Prerequisites

- `opencode` installed and authenticated for the GPT provider.
- The GPT-5.5 model id in `provider/model` form. Find it with `opencode models openai` (or the
  relevant provider) and use it as `<MODEL>` below. If the user has a default review model
  configured, use that.
- **Recommended hardening (optional):** define a read-only reviewer agent so read-only is
  *enforced*, not just requested — see *Enforcing read-only* at the end. Without it, read-only
  still holds in practice because you never ask GPT to edit, you never pass
  `--dangerously-skip-permissions`, and you alone apply changes.

## Setup

### 1. Write the intent brief

Before any review, write a short brief capturing *why* the change exists — this is the context
GPT keeps warm for the whole session, so spend a little effort here. Save it to a scratch file
(e.g. `~/tmp/pairing-intent.md`) so you can reference it:

```
## Intent
<one paragraph: what we're building and why it matters>

## Acceptance criteria
- <observable, checkable outcomes>

## Constraints / non-goals
- <what's explicitly out of scope, invariants that must hold>

## Where to look
- <key files / modules the reviewer should ground itself in>
```

If you can't state the intent crisply, that's a signal to clarify with the user first — a vague
brief produces a reviewer that reviews against the wrong goal.

### 2. Seed the warm reviewer session

Send the brief once to start a persistent session. Every later round will `--continue` it, so
GPT carries the motivation and its own prior reasoning forward without re-paying for them:

```bash
opencode run --dir "$PWD" -m <MODEL> --format default \
  "You are a read-only adversarial code reviewer paired with another AI engineer over a
multi-round session. You will receive an intent brief now, then a series of diffs to review.
You have read access to the repo (read/grep/glob) but you MUST NOT modify any files — you
report findings and propose tests as text only; the engineer applies all changes.

Here is the change we are about to build together:

$(cat ~/tmp/pairing-intent.md)

Acknowledge that you've understood the intent and acceptance criteria in 2-3 sentences. Do
not review anything yet — no code has been written. List the 1-3 risks you'll be watching
for given this intent."
```

## The review loop

Repeat until a termination condition (below) is met. **Cap at ~4 rounds** unless the user asks
to keep going — two strong models can ping-pong on taste forever, so the cap is a feature.

### Each round

1. **Implement a slice.** Make a coherent, reviewable increment — not the whole feature at once.
   Smaller slices get sharper reviews and keep the diff cheap to send.

2. **Request review.** Send only the *new* diff into the warm session via `--continue`:

   ```bash
   git diff > ~/tmp/pairing-round.diff   # or git diff --cached / HEAD~1, as appropriate
   opencode run --dir "$PWD" -c -m <MODEL> --format default \
     "Round <N>. Review ONLY this diff against the intent and acceptance criteria. You may
   read surrounding code/callers/types/tests to ground yourself, but stay within ~10 files.

   $(cat ~/tmp/pairing-round.diff)

   Report ONLY real problems — bugs, security issues, missed edge cases, silent failures,
   contract violations, missing test coverage. For each: file:line, quote the code, explain
   what breaks and when, and rate CRITICAL / HIGH / MEDIUM.

   If you assert a bug exists, you MUST also provide a concrete FAILING TEST (as code/text)
   that would demonstrate it — the engineer will run it. If you can't write a test that
   fails, downgrade or drop the finding.

   If you lack context to judge something, ASK a specific question instead of guessing —
   prefix it with 'QUESTION:'. If you find nothing real, say 'No issues found.'"
   ```

3. **Triage every finding.** Use your own judgement — the value is the *tension* between two
   models, not uncritical compliance:
   - **Agree** → fix it, and say what you changed.
   - **Disagree** → rebut with reasoning. Feed the rebuttal back next round so GPT can update
     or concede; don't silently ignore it.
   - **Needs the human** → it's a genuine judgement call (a real taste/architecture fork, not a
     correctness question) → surface it (see *Surfacing disagreements*).

4. **Answer any `QUESTION:`** GPT raised, from your warm context, in the next `--continue` call.
   This is the cheap way to give GPT the context it's missing without shipping your whole
   transcript — answer the specific gap and move on.

### Falsification — settle disputes by running code, not rhetoric

This is what keeps the loop honest. When GPT claims a bug, it must hand you a failing test. You
are the only writer, so:

1. GPT proposes the failing test (text).
2. You add it and **run it**.
3. The result decides: it fails as predicted → real, fix it. It passes → the finding was wrong,
   feed that back. Neither model gets to win by sounding confident.

Keep the genuinely-useful tests GPT surfaces; they're a bonus output of the process.

## Termination

Stop when any of these holds, and tell the user which:

- GPT returns **no CRITICAL or HIGH** findings (MEDIUMs can be noted and deferred), **or**
- GPT explicitly signs off ("No issues found"), **or**
- The **round cap** is reached — summarise what's still open rather than looping silently, **or**
- Remaining disagreements are judgement calls only a human should make.

GPT signalling done is *input*, not a veto over you — if you've reasoned through a finding and
disagree, you may conclude the loop and surface the disagreement. The human decides ties.

## Surfacing disagreements (the decision log)

The most valuable output isn't just the code — it's **where two strong models disagreed and how
it resolved.** When you finish, give the user a short log:

```
## Pairing summary
- Rounds: <N>
- Fixed (agreed): <count> — <one-line each>
- Rebutted (GPT conceded / dropped): <one-line each>
- ⚠️ For your call: <any unresolved judgement calls, both sides stated>
- Tests added during review: <list>
```

Lead with the ⚠️ items — those are where your attention is actually worth spending.

## Enforcing read-only (optional hardening)

To make read-only a hard guarantee rather than an instruction, define a reviewer agent that
denies mutation, and pass `--agent reviewer`:

```bash
opencode agent create   # follow prompts; deny edit/write/bash, allow read/grep/glob
# then add `--agent reviewer` to the opencode run calls above
```

Or hand-write the agent definition under `~/.config/opencode/` per opencode's agent docs with
edit/write/bash denied. Either way the baseline still holds without it: you never ask GPT to
write, and you apply every change yourself.
