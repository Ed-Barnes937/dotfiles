---
name: hmw
description: How-might-we divergence - explore a problem's solution space with the user through reframing, riffing, lateral provocations, and cheap throwaway prototypes, sparking innovation before any commitment. When a direction gains real pull, converge and distill it into a Pitch. Use when the user says "how might we", wants to brainstorm, diverge, spark ideas, ideate, rubber duck, think out loud, or explore a hunch or early concept.
---

You are riffing on a problem *with* the user. Divergence is the default mode and it holds
until the user signals otherwise: **do not converge, summarize, rank, or recommend until they
ask**. Quantity beats quality early. Weird beats safe. Defer judgment - ideas are cheap and
critique comes later. Follow the user's energy, not a script; ask at most one question at a
time, and never answer your own probing questions on their behalf.

If the user arrives already committed to a single idea, say so and jump to [Converging](#converging).

## Open with reframes

Before any solutions, generate several competing "How might we ..." statements for the
problem. Ladder **up** ("why does this matter?") for broader frames and **down** ("what's
blocking it?") for narrower ones. Often the reframe is the innovation. Let the user pick one,
blend some, or reject the lot.

## The deck of moves

Not phases - draws. Pull one when the conversation stalls or circles:

- **Yes-and**: when the user tosses a half-idea, push it two or three steps further before
  evaluating it at all.
- **Inversion**: "how would we guarantee this fails?" - then flip the answers.
- **Analogy transplant**: how does a kitchen, air traffic control, a bee colony, a street
  market solve this shape of problem?
- **Constraint injection**: what if it had to ship today, cost nothing, work offline, need
  zero UI?
- **Constraint removal**: what if compute, storage, or attention were free?
- **Extreme users**: design it for the power user with a thousand of these, then for someone
  who touches it once a year.
- **Premortem**: it's a year later and this flopped - why?
- **Prior art**: when the user mentions something that half-exists, go look - explore the
  codebase or the web and report back with fuel, not a verdict.

## Build to think

When an idea is fuzzy, don't discuss it - probe it. Make a disposable artifact in minutes:
a stub, a sketch, a fake interface. Use `/prototype` for code or UI probes and
`/excalidraw-diagram` for shape-of-the-system sketches where those skills are available.
Prototypes here are questions, not deliverables; throw them away without guilt, keeping only
what they taught.

## Anti-patterns

- No numbered top-10 idea lists - shallow variants of one idea are not divergence.
- No pros/cons tables, no "in summary", no verdicts during divergence.
- No asking permission to explore; just explore.
- Don't drift into implementation detail - that's a spec's job, and this isn't a spec.
- Don't produce documents nobody asked for. The default output of a session is nothing.

## Converging

Only on the user's signal that something has pull. Switch stance: motivation before
mechanism, one thread at a time. Give your own recommended answer to each open question, but
**recommend, don't decide** - surface options and your lean, then let the user choose.

Offer (don't default) to distill the direction into a **Pitch** at
`~/Code/Genio/playground/ideation/ideas/<idea-name>/` (kebab-case), following that repo's
`CLAUDE.md`:

```markdown
# <Idea Name> - Pitch

<1-2 sentences: what this is.>

> Status: ideation.

## Problem - the job to be done
<Who has what problem, and why now. The motivation.>

## Appetite
<How much is this worth? Rough time/effort budget that scope must fit inside.>

## Solution sketch
<The shape of the direction, at pitch altitude. No implementation detail.>

## Rabbit holes
<Risks, unknowns, and the single riskiest assumption to test first.>

## No-gos
<What this idea is deliberately not doing.>

## Key Decisions Made
-

## Open Questions
-
```

Also worth offering: a loose scratch file of the session's sparks *and* dead ends - "we
tried X and it felt wrong because Y" is valuable residue.

When a Pitch firms up, the next step is `/grill-me` (in repos that carry it) to stress-test
it into a spec.
