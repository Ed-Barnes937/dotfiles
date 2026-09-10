# Generate Documentation Chapter

Generate a documentation chapter for the Genio living documentation site from a topic definition YAML file.

## When to use

When the user wants to generate or regenerate a documentation chapter for the living documentation site. Invoked as `/generate-docs <topic-name>` where topic-name matches a YAML file under `docs/topics/` (e.g. `system-overview`, `state-management`).

## Process

### 1. Read the topic definition

Read `docs/topics/<number>-<topic-name>.yaml` to get:
- Title, description, audience
- Glob patterns for source files
- Guiding questions to answer
- Tab configuration (if any)
- Frontend/backend split (if any)

If the topic name doesn't match a file, list available topics and ask.

### 2. Explore source files

Resolve all glob patterns from the topic definition. Read the key source files to understand the architecture, patterns, and technologies in use. Focus on understanding:
- How things are structured
- What technologies are used
- How components relate to each other
- Key entry points and patterns

Use the Explore agent for thorough codebase investigation when needed.

### 3. Generate the MDX content

Write the chapter as an MDX file following this template:

```mdx
---
sidebar_position: <chapter-number>
title: '<Title>'
generated: '<YYYY-MM-DD>'
sources:
  - path: '<file-path>'
    hash: '<7-char-hash>'
watches:
  - glob: '<pattern>'
    count: <number>
---

import Tabs from '@theme/Tabs'
import TabItem from '@theme/TabItem'

# <Title>

> <Punchy subtitle with real numbers from the codebase — specific, engaging, grounded in what was found>

## Overview

<2-3 paragraphs accessible to non-engineers. What is this area, why does it matter, how does it fit into the bigger picture. Problem-solution framing.>

## Architecture

```mermaid
<Mermaid diagram showing high-level structure/flow>
```

<Brief explanation of the diagram>

## <Main content sections>

<If tabs are configured, use:>
<Tabs>
  <TabItem value="tab-key" label="Tab Name" default>
    <Content for this tab>
  </TabItem>
</Tabs>

<For each key concept, show short REAL code snippets from the repo>

<For technology deep dives, use collapsible sections:>
<details>
<summary>What is <Technology X>?</summary>

<Explain the technology/concept — what it is, how it works conceptually, why it's used here. This is about the TECHNOLOGY, not the implementation details. Optionally reference the implementation where it adds value.>

</details>

## Key Files

| File | Purpose |
|------|---------|
| `path/to/file.ts` | One-line description |
```

### 4. Tone and style rules

- **Straightforward technical documentation** inspired by React docs
- **Professional, concise, problem-solution framing**
- **Minimal prose** — let code speak
- **Code snippets must be real** — copied from actual repo files, kept short (5-15 lines)
- **Collapsible deep dives explain the TECHNOLOGY** (e.g. "What is Redux Toolkit's createSlice?"), not implementation details
- **Subtitles can be theatrical/engaging** — they're the hook
- **No comments explaining code** — code should be self-explanatory
- **Audience-appropriate** — "everyone" chapters need overviews a PM can follow; "engineers" chapters can assume technical knowledge

### 5. Compute metadata

After generating content, compute the drift-detection frontmatter:

1. For each source file referenced in code snippets or the Key Files table, compute its hash using the metadata script:
   ```bash
   node docs/scripts/metadata.mjs hash <file-path>
   ```

2. For each glob pattern from the topic definition, resolve the count:
   ```bash
   node docs/scripts/metadata.mjs resolve-globs "<pattern>"
   ```

3. Inject the `sources` and `watches` arrays into the MDX frontmatter.

**Always single-quote hash values** (`hash: '7885e80'`, not `hash: 7885e80`). A 7-char hex hash that matches YAML's number grammar — digits then `e` then digits, e.g. `7885e80` — parses as a scientific-notation float and corrupts to `Infinity`, failing validation. Quoting makes every hash an unambiguous string.

### 6. Write the file

Write the generated MDX to `docs/docs/<chapter-slug>/index.mdx` (replacing the placeholder).

### 7. Verify

Run `task docs:build` to confirm the page builds without errors. If there are build errors, fix them.

Run `node docs/scripts/metadata.mjs validate docs/docs/<chapter-slug>/index.mdx` to confirm the frontmatter is valid. `task docs:check-drift` reports drift across all chapters and should show the freshly generated chapter as `CLEAN`.
