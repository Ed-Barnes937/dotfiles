#!/usr/bin/env python3
"""
Analyze Claude Code transcripts and emit a self-contained HTML usage-audit page.

Reads every *.jsonl under the projects dir (default ~/.claude/projects), computes
context-fill / turn-count / spend statistics, checks which efficiency tools are
installed, and writes an HTML fragment suitable for the Artifact tool (no
<html>/<head>/<body> wrapper — those are injected at publish time).

Usage:
    python analyze.py --out /path/to/page.html [--projects DIR] [--top N]
"""

import argparse
import html
import json
import os
import platform
import re
import shutil
import statistics
from pathlib import Path

# --- cost model: per-model rates, $ per 1M tokens (input/output published;
# cache_read = 0.1x input, cache_write derived from input x TTL multiplier:
# 1.25x for 5-minute cache, 2x for 1-hour cache). Rates as of 2026.
RATES = {
    "fable":   {"input": 10.0, "output": 50.0},   # Fable 5 / Mythos 5
    "opus":    {"input": 5.0,  "output": 25.0},    # Opus 4.6 / 4.7 / 4.8
    "sonnet":  {"input": 3.0,  "output": 15.0},    # Sonnet 4.6 / 5
    "haiku":   {"input": 1.0,  "output": 5.0},     # Haiku 4.5
    "unknown": {"input": 5.0,  "output": 25.0},    # fall back to Opus-tier
}
MODEL_LABEL = {"fable": "Fable / Mythos 5", "opus": "Opus 4.x",
               "sonnet": "Sonnet", "haiku": "Haiku", "unknown": "Other / unknown"}


def model_family(model_id):
    m = (model_id or "").lower()
    if "haiku" in m: return "haiku"
    if "sonnet" in m: return "sonnet"
    if "fable" in m or "mythos" in m: return "fable"
    if "opus" in m: return "opus"
    return "unknown"


def family_cost(fam, tok):
    """tok = {output, input, cache_read, cw5m, cw1h} raw token counts."""
    r = RATES[fam]
    return (tok["output"] * r["output"]
            + tok["input"] * r["input"]
            + tok["cache_read"] * r["input"] * 0.1
            + tok["cw5m"] * r["input"] * 1.25
            + tok["cw1h"] * r["input"] * 2.0) / 1_000_000

# OS-appropriate CLI hints (the native Claude tools are cross-platform; only the
# shell fallbacks and the package manager actually differ by OS).
_OS = platform.system()
OS_LABEL = {"Darwin": "macOS", "Linux": "Linux", "Windows": "Windows"}.get(_OS, _OS)
INSTALL_CMD = {"Darwin": "brew install", "Linux": "sudo apt install",
               "Windows": "winget install"}.get(_OS, "brew install")
VIEW_CLI = "Get-Content" if _OS == "Windows" else "bat / less"
FIND_CLI = "Get-ChildItem" if _OS == "Windows" else "fd"

# Tools that make bash-heavy work cheaper on context/tokens. (name -> why)
EFFICIENCY_TOOLS = {
    "rg":        "ripgrep — fast code search, respects .gitignore (replaces `grep -r`)",
    "fd":        "fast, simple file finding (replaces `find`)",
    "jq":        "structured JSON without regex hacks",
    "gh":        "GitHub PRs / issues / CI in one command",
    "bat":       "file viewing with syntax highlighting",
    "yq":        "structured YAML/TOML querying",
    "ast-grep":  "structural code search & refactor",
    "delta":     "readable git diffs",
    "fzf":       "interactive fuzzy filtering",
    "sd":        "simpler find-and-replace (replaces `sed`)",
}

CLAUDE_MD_SNIPPET = """# Search & File Reading

Prefer native tools over shelling out. These are faster, cheaper on tokens, and avoid permission prompts.

- **Searching code:** use the Grep tool (or `rg`). Never `grep -r`/`grep -rn` — it's slower and walks `node_modules`/ignored files.
- **Reading files:** use the Read tool. Don't `cat`, `sed -n`, `head`, or `tail` a file just to view it.
- **Finding files:** use the Glob tool (or `rg --files | rg pattern`), not `find`.
- Shelling out to `grep`/`cat`/`sed` in a pipe (e.g. `git log | grep`) is fine — the rule is about inspecting the codebase and files, not filtering command output.

# Delegating to subagents

Keep the long-lived orchestrator context lean; the spend formula is (avg context size) x (turns).

- Farm out **disposable** work — wide searches, reading many files to answer one question, bulk mechanical edits — to a subagent (Task tool / Explore agent). Only its summary returns; the bulky intermediate output never enters the main thread.
- Keep **durable** context in the orchestrator: the plan, decisions and why, running progress, final answers.
- Don't delegate short tasks or tightly iterative work where you need each result inline — subagents boot with fixed overhead."""


def iter_records(path):
    """Yield parsed JSON objects from a .jsonl file, skipping malformed lines."""
    with open(path, "r", encoding="utf-8", errors="replace") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                yield json.loads(line)
            except json.JSONDecodeError:
                continue


HEX_SUFFIX = re.compile(r"-[0-9a-f]{6,}$")


def clean_name(dirname):
    """Turn a mangled project dir into a readable label.

    e.g. '-Users-ed-Code-Worktrees-hack-spike-pls-bc10ec5d' -> 'hack-spike-pls'
    """
    name = HEX_SUFFIX.sub("", dirname)
    for marker in ("-Worktrees-", "-Code-"):
        idx = name.rfind(marker)
        if idx != -1:
            return name[idx + len(marker):]
    # fall back to the last few path-ish segments
    return "-".join(name.strip("-").split("-")[-3:])


def content_items(rec):
    """Return the list of content blocks on a record's message, if any."""
    msg = rec.get("message")
    if not isinstance(msg, dict):
        return []
    content = msg.get("content")
    return content if isinstance(content, list) else []


# search-discipline regexes (applied to Bash command strings)
RE_GREP_RECURSIVE = re.compile(r"(^|[|&;(]\s*)grep\s+-[a-zA-Z]*r")
RE_GREP_ANY = re.compile(r"(^|[|&;(]\s*)grep\s")
RE_RG = re.compile(r"(^|[|&;(]\s*)rg\s")
RE_SED_N = re.compile(r"(^|[|&;(]\s*)sed\s+-n")
RE_CAT_FILE = re.compile(r"(^|[|&;(]\s*)cat\s+[^<|]")
RE_FIND = re.compile(r"(^|[|&;(]\s*)find\s")


def analyze(projects_dir):
    sessions = []          # per-session dicts (main-thread sessions only)
    project_out = {}       # project -> summed output tokens
    by_family = {}         # model family -> raw token counts (for per-model cost)
    subagent_calls = 0     # Agent/Task spawns on main threads
    sub_turns_total = 0    # turns inside subagent (sidechain) transcripts
    subagent_files = 0     # number of subagent transcripts
    disc = {"grep_r": 0, "grep_any": 0, "rg": 0, "sed_n": 0, "cat": 0, "find": 0}

    files = list(Path(projects_dir).rglob("*.jsonl"))
    for f in files:
        project = f.parent.name
        peak_cache = 0
        out_sum = 0
        turns = 0
        sub_turns = 0
        tasks = 0
        for rec in iter_records(f):
            sidechain = rec.get("isSidechain") is True
            msg = rec.get("message")
            usage = msg.get("usage") if isinstance(msg, dict) else None
            if isinstance(usage, dict):
                o = usage.get("output_tokens", 0) or 0
                i = usage.get("input_tokens", 0) or 0
                cr = usage.get("cache_read_input_tokens", 0) or 0
                cw = usage.get("cache_creation_input_tokens", 0) or 0
                # split cache-write into 5-minute vs 1-hour TTL when available
                cc = usage.get("cache_creation") or {}
                cw1h = cc.get("ephemeral_1h_input_tokens", 0) or 0
                cw5m = cc.get("ephemeral_5m_input_tokens", 0) or 0
                if not cc:                       # no breakdown → treat all as 5m
                    cw5m = cw
                fam = model_family(msg.get("model"))
                acc = by_family.setdefault(fam, {"output": 0, "input": 0,
                                                 "cache_read": 0, "cw5m": 0, "cw1h": 0})
                acc["output"] += o
                acc["input"] += i
                acc["cache_read"] += cr
                acc["cw5m"] += cw5m
                acc["cw1h"] += cw1h
                out_sum += o
                if sidechain:
                    sub_turns += 1          # delegated (subagent) turn
                    sub_turns_total += 1    # counted even though the file is skipped below
                else:
                    turns += 1              # orchestrator / main-thread turn
                    if cr > peak_cache:
                        peak_cache = cr
            for item in content_items(rec):
                if not isinstance(item, dict) or item.get("type") != "tool_use":
                    continue
                name = item.get("name")
                if name in ("Agent", "Task"):   # both name a subagent spawn
                    tasks += 1
                    subagent_calls += 1
                elif name == "Bash":
                    cmd = (item.get("input") or {}).get("command", "")
                    if not isinstance(cmd, str):
                        continue
                    if RE_GREP_RECURSIVE.search(cmd): disc["grep_r"] += 1
                    if RE_GREP_ANY.search(cmd): disc["grep_any"] += 1
                    if RE_RG.search(cmd): disc["rg"] += 1
                    if RE_SED_N.search(cmd): disc["sed_n"] += 1
                    if RE_CAT_FILE.search(cmd): disc["cat"] += 1
                    if RE_FIND.search(cmd): disc["find"] += 1
        if turns == 0:
            if sub_turns > 0:
                subagent_files += 1     # a subagent-only transcript, not a session
            continue
        sessions.append({"project": project, "peak": peak_cache, "out": out_sum,
                         "turns": turns, "sub_turns": sub_turns, "tasks": tasks})
        project_out[project] = project_out.get(project, 0) + out_sum

    return {
        "sessions": sessions,
        "project_out": project_out,
        "by_family": by_family,
        "subagent_calls": subagent_calls,
        "sub_turns_total": sub_turns_total,
        "subagent_files": subagent_files,
        "disc": disc,
        "n_files": len(files),
    }


def pct(values, p):
    if not values:
        return 0
    s = sorted(values)
    idx = min(len(s) - 1, int(len(s) * p))
    return s[idx]


def fmt_int(n):
    return f"{n:,}"


def fmt_tok(n):
    """Human-friendly token count."""
    if n >= 1_000_000:
        return f"{n/1_000_000:.1f}M"
    if n >= 1_000:
        return f"{n/1_000:.0f}k"
    return str(n)


def fmt_usd(n):
    return f"${n:,.0f}" if n >= 1 else f"${n:.2f}"


# ------------------------- HTML rendering -------------------------

CSS = """
<style>
  :root {
    --bg: #f5f7f8; --panel: #ffffff; --panel-2: #eef1f3;
    --ink: #14181d; --muted: #5b6672; --hair: #d9e0e3;
    --accent: #0e7c86; --accent-soft: #d7ecee;
    --good: #2f8f5b; --warn: #b3720c; --crit: #c0392f;
    --good-bg: #e3f2e9; --warn-bg: #f8ecd6; --crit-bg: #f8e2df;
    --mono: ui-monospace, "SF Mono", "SFMono-Regular", Menlo, Consolas, monospace;
    --sans: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, system-ui, sans-serif;
  }
  @media (prefers-color-scheme: dark) {
    :root {
      --bg: #0e1116; --panel: #161b22; --panel-2: #1c232c;
      --ink: #e6edf3; --muted: #8b98a5; --hair: #2a323c;
      --accent: #3fb6c1; --accent-soft: #10343a;
      --good: #4cc283; --warn: #e0a13a; --crit: #e5675c;
      --good-bg: #16301f; --warn-bg: #33280f; --crit-bg: #331b18;
    }
  }
  :root[data-theme="light"] {
    --bg: #f5f7f8; --panel: #ffffff; --panel-2: #eef1f3;
    --ink: #14181d; --muted: #5b6672; --hair: #d9e0e3;
    --accent: #0e7c86; --accent-soft: #d7ecee;
    --good: #2f8f5b; --warn: #b3720c; --crit: #c0392f;
    --good-bg: #e3f2e9; --warn-bg: #f8ecd6; --crit-bg: #f8e2df;
  }
  :root[data-theme="dark"] {
    --bg: #0e1116; --panel: #161b22; --panel-2: #1c232c;
    --ink: #e6edf3; --muted: #8b98a5; --hair: #2a323c;
    --accent: #3fb6c1; --accent-soft: #10343a;
    --good: #4cc283; --warn: #e0a13a; --crit: #e5675c;
    --good-bg: #16301f; --warn-bg: #33280f; --crit-bg: #331b18;
  }
  * { box-sizing: border-box; }
  .wrap {
    background: var(--bg); color: var(--ink); font-family: var(--sans);
    line-height: 1.55; margin: 0; padding: 40px 20px 80px;
    -webkit-font-smoothing: antialiased;
  }
  .col { max-width: 960px; margin: 0 auto; display: flex; flex-direction: column; gap: 34px; }
  header .eyebrow {
    font-family: var(--mono); text-transform: uppercase; letter-spacing: .16em;
    font-size: 11px; color: var(--accent); margin: 0 0 8px;
  }
  header h1 { font-size: 30px; line-height: 1.1; margin: 0 0 6px; text-wrap: balance; font-weight: 700; letter-spacing: -.01em; }
  header .sub { color: var(--muted); margin: 0; font-size: 14px; }
  section { display: flex; flex-direction: column; gap: 14px; }
  h2 { font-size: 13px; font-family: var(--mono); text-transform: uppercase; letter-spacing: .12em;
       color: var(--muted); margin: 0; font-weight: 600; }
  .lead { margin: 0; color: var(--ink); font-size: 14.5px; }
  .lead .em { color: var(--accent); font-weight: 600; }

  /* KPI tiles */
  .tiles { display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 12px; }
  .tile { background: var(--panel); border: 1px solid var(--hair); border-radius: 10px; padding: 16px 16px 14px;
          display: flex; flex-direction: column; gap: 4px; }
  .tile .k { font-family: var(--mono); font-size: 11px; text-transform: uppercase; letter-spacing: .08em; color: var(--muted); }
  .tile .v { font-family: var(--mono); font-size: 26px; font-weight: 600; font-variant-numeric: tabular-nums; letter-spacing: -.02em; }
  .tile .note { font-size: 12px; color: var(--muted); }

  /* tables */
  .scroll { overflow-x: auto; border: 1px solid var(--hair); border-radius: 10px; background: var(--panel); }
  table { width: 100%; border-collapse: collapse; font-size: 13.5px; }
  th, td { text-align: left; padding: 10px 14px; border-bottom: 1px solid var(--hair); }
  thead th { font-family: var(--mono); font-size: 11px; text-transform: uppercase; letter-spacing: .06em;
             color: var(--muted); font-weight: 600; background: var(--panel-2); }
  tbody tr:last-child td { border-bottom: none; }
  td.num, th.num { text-align: right; font-family: var(--mono); font-variant-numeric: tabular-nums; }
  td.mono { font-family: var(--mono); font-size: 12.5px; }

  .pill { display: inline-block; font-family: var(--mono); font-size: 11px; font-weight: 600;
          padding: 2px 8px; border-radius: 999px; letter-spacing: .02em; }
  .p-good { background: var(--good-bg); color: var(--good); }
  .p-warn { background: var(--warn-bg); color: var(--warn); }
  .p-crit { background: var(--crit-bg); color: var(--crit); }
  tr.sev-crit td:first-child { box-shadow: inset 3px 0 0 var(--crit); }
  tr.sev-warn td:first-child { box-shadow: inset 3px 0 0 var(--warn); }

  /* two-column static blocks */
  .duo { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; }
  @media (max-width: 720px) { .duo { grid-template-columns: 1fr; } }
  .card { background: var(--panel); border: 1px solid var(--hair); border-radius: 10px; padding: 18px 20px; }
  .card h3 { margin: 0 0 10px; font-size: 15px; }
  .card p, .card li { font-size: 13.5px; color: var(--ink); }
  .card ul { margin: 8px 0 0; padding-left: 18px; }
  .card li { margin-bottom: 6px; }
  .card .when { color: var(--muted); font-family: var(--mono); font-size: 11px; text-transform: uppercase; letter-spacing: .06em; }

  pre.snippet { background: var(--panel-2); border: 1px solid var(--hair); border-radius: 10px;
       padding: 16px; overflow-x: auto; font-family: var(--mono); font-size: 12.5px; line-height: 1.5; margin: 0; color: var(--ink); }
  td code { font-family: var(--mono); background: var(--panel-2); padding: 1px 6px; border-radius: 4px; font-size: 12px; }
  .foot { color: var(--muted); font-size: 12px; font-family: var(--mono); text-align: center; }
  .caveat { color: var(--muted); font-size: 12px; margin: 0; }
</style>
"""


def sev_pill(peak):
    if peak > 300_000:
        return '<span class="pill p-crit">bloated</span>'
    if peak > 150_000:
        return '<span class="pill p-warn">heavy</span>'
    return '<span class="pill p-good">lean</span>'


def turn_row_class(turns):
    if turns > 1000:
        return "sev-crit"
    if turns > 500:
        return "sev-warn"
    return ""


def render(data, top_n):
    s = data["sessions"]
    peaks = [x["peak"] for x in s]
    n = len(s)
    disc = data["disc"]

    # per-model cost
    fam_costs = {fam: family_cost(fam, tok) for fam, tok in data["by_family"].items()}
    total_cost = sum(fam_costs.values())

    median_peak = int(statistics.median(peaks)) if peaks else 0
    over_150 = sum(1 for p in peaks if p > 150_000)
    over_300 = sum(1 for p in peaks if p > 300_000)

    heavy = sorted(s, key=lambda x: x["turns"], reverse=True)[:top_n]
    projects = sorted(data["project_out"].items(), key=lambda kv: kv[1], reverse=True)[:8]

    parts = [CSS, '<div class="wrap"><div class="col">']

    # header
    parts.append(f'''<header>
      <p class="eyebrow">Claude Code · usage audit</p>
      <h1>Context &amp; token discipline</h1>
      <p class="sub">{fmt_int(n)} top-level sessions · {fmt_int(data["subagent_files"])} subagent transcripts · {fmt_int(data["n_files"])} files total.</p>
    </header>''')

    # KPI tiles
    if data["subagent_calls"] == 0:
        subagent_note = "never used — a lever worth trying"
    else:
        subagent_note = f'{fmt_int(data["sub_turns_total"])} delegated turns'
    parts.append(f'''<section>
      <div class="tiles">
        <div class="tile"><span class="k">Sessions</span><span class="v">{fmt_int(n)}</span></div>
        <div class="tile"><span class="k">Median peak context</span><span class="v">{fmt_tok(median_peak)}</span><span class="note">per session</span></div>
        <div class="tile"><span class="k">Subagent spawns</span><span class="v">{fmt_int(data["subagent_calls"])}</span><span class="note">{subagent_note}</span></div>
        <div class="tile"><span class="k">Usage at API rates</span><span class="v">{fmt_usd(total_cost)}</span><span class="note">not billed on a subscription</span></div>
      </div>
    </section>''')

    # context fill
    rows = ""
    fill_rows = [
        ("Median", median_peak), ("p75", pct(peaks, 0.75)),
        ("p90", pct(peaks, 0.90)), ("p99", pct(peaks, 0.99)),
        ("Max", max(peaks) if peaks else 0),
    ]
    for label, val in fill_rows:
        rows += f'<tr><td class="mono">{label}</td><td class="num">{fmt_int(val)}</td><td>{sev_pill(val)}</td></tr>'
    parts.append(f'''<section>
      <h2>Context fill — how full the window gets</h2>
      <p class="lead">Peak context usage per session. <span class="em">{over_150}</span> of {n} sessions peaked over 150k; <span class="em">{over_300}</span> over 300k.</p>
      <div class="scroll"><table>
        <thead><tr><th>Percentile</th><th class="num">Peak tokens</th><th>State</th></tr></thead>
        <tbody>{rows}</tbody>
      </table></div>
    </section>''')

    # heavy sessions (turn count)
    hrows = ""
    for x in heavy:
        cls = turn_row_class(x["turns"])
        proj = html.escape(clean_name(x["project"])[:52])
        hrows += (f'<tr class="{cls}"><td class="mono">{proj}</td>'
                  f'<td class="num">{fmt_int(x["turns"])}</td>'
                  f'<td class="num">{fmt_int(x["peak"])}</td>'
                  f'<td class="num">{fmt_tok(x["out"])}</td>'
                  f'<td class="num">{x["tasks"]}</td></tr>')
    parts.append(f'''<section>
      <h2>Turn count — the real spend driver</h2>
      <p class="lead">Spend ≈ (avg context) × (turns). Long single-thread sessions re-read a large context every turn. Rows striped by turn count.</p>
      <div class="scroll"><table>
        <thead><tr><th>Session (project)</th><th class="num">Turns</th><th class="num">Peak ctx</th><th class="num">Output</th><th class="num">Subagents</th></tr></thead>
        <tbody>{hrows}</tbody>
      </table></div>
    </section>''')

    # search discipline
    ratio = f'{disc["grep_r"]}:{disc["rg"]}' if disc["rg"] else f'{disc["grep_r"]}:0'
    parts.append(f'''<section>
      <h2>Search &amp; read discipline (bash)</h2>
      <p class="lead">Raw shell used where a native tool is faster. Recursive grep vs ripgrep ran <span class="em">{ratio}</span>. Shell alternatives shown for {OS_LABEL}.</p>
      <div class="scroll"><table>
        <thead><tr><th>Pattern</th><th class="num">Count</th><th>Better</th></tr></thead>
        <tbody>
          <tr><td class="mono">grep -r / -rn (recursive)</td><td class="num">{fmt_int(disc["grep_r"])}</td><td>Grep tool · <code>rg</code></td></tr>
          <tr><td class="mono">rg (ripgrep)</td><td class="num">{fmt_int(disc["rg"])}</td><td>—</td></tr>
          <tr><td class="mono">sed -n (file slices)</td><td class="num">{fmt_int(disc["sed_n"])}</td><td>Read tool · <code>{VIEW_CLI}</code></td></tr>
          <tr><td class="mono">cat &lt;file&gt;</td><td class="num">{fmt_int(disc["cat"])}</td><td>Read tool · <code>{VIEW_CLI}</code></td></tr>
          <tr><td class="mono">find</td><td class="num">{fmt_int(disc["find"])}</td><td>Glob tool · <code>{FIND_CLI}</code></td></tr>
        </tbody>
      </table></div>
    </section>''')

    # installed tools
    trows = ""
    missing = []
    for tool, why in EFFICIENCY_TOOLS.items():
        present = shutil.which(tool) is not None
        pill = '<span class="pill p-good">installed</span>' if present else '<span class="pill p-warn">missing</span>'
        if not present:
            missing.append(tool)
        trows += f'<tr><td class="mono">{tool}</td><td>{pill}</td><td>{html.escape(why)}</td></tr>'
    miss_line = ("All present." if not missing
                 else f'Consider ({OS_LABEL}): <span class="em">{INSTALL_CMD} {" ".join(missing)}</span>')
    parts.append(f'''<section>
      <h2>Efficiency tooling</h2>
      <p class="lead">Tools that make bash-heavy work cheaper. {miss_line}</p>
      <div class="scroll"><table>
        <thead><tr><th>Tool</th><th>Status</th><th>Why it helps</th></tr></thead>
        <tbody>{trows}</tbody>
      </table></div>
    </section>''')

    # static: clear vs compact + subagent advice
    parts.append('''<section>
      <h2>Playbook — the two habits that matter</h2>
      <div class="duo">
        <div class="card">
          <h3>/clear vs /compact</h3>
          <p><span class="when">/clear</span><br>Wipes history, fresh start, free. Use when the <strong>next task is unrelated</strong> to the current one.</p>
          <p style="margin-top:10px"><span class="when">/compact</span><br>Summarises history, keeps the thread, costs one summarisation pass. Use for the <strong>same task</strong> when history has grown large.</p>
          <ul>
            <li>Finished / switching tasks → <strong>/clear</strong></li>
            <li>Same task, context heavy → <strong>/compact</strong></li>
            <li>Compacting the same task repeatedly → break it into smaller sessions</li>
          </ul>
        </div>
        <div class="card">
          <h3>Orchestrator + subagents</h3>
          <p>A subagent runs in its <strong>own context window</strong>; only its summary returns to the main thread. Bulky work never gets re-read on later turns.</p>
          <ul>
            <li><strong>Delegate (disposable):</strong> wide searches, reading many files, bulk edits</li>
            <li><strong>Keep (durable):</strong> the plan, decisions &amp; why, final answers</li>
            <li>Don't delegate short or tightly-iterative work — subagents boot with fixed overhead</li>
          </ul>
        </div>
      </div>
    </section>''')

    # CLAUDE.md snippet
    parts.append(f'''<section>
      <h2>Drop-in CLAUDE.md block</h2>
      <p class="lead">Paste into your global <span class="em">~/.claude/CLAUDE.md</span> to make the efficient defaults automatic.</p>
      <pre class="snippet">{html.escape(CLAUDE_MD_SNIPPET)}</pre>
    </section>''')

    # per-model cost breakdown
    crows = ""
    for fam, c in sorted(fam_costs.items(), key=lambda kv: kv[1], reverse=True):
        if c <= 0:
            continue
        r = RATES[fam]
        crows += (f'<tr><td class="mono">{MODEL_LABEL[fam]}</td>'
                  f'<td class="num">${r["input"]:.0f} / ${r["output"]:.0f}</td>'
                  f'<td class="num">{fmt_usd(c)}</td></tr>')
    parts.append(f'''<section>
      <h2>Usage at API rates, by model</h2>
      <p class="lead">Priced per model at pay-as-you-go rates (input / output $ per 1M). Cache reads bill at 0.1x input; cache writes at 1.25x (5-min) or 2x (1-hour).</p>
      <div class="scroll"><table>
        <thead><tr><th>Model</th><th class="num">Rate in/out</th><th class="num">Cost</th></tr></thead>
        <tbody>{crows}<tr><td class="mono"><strong>Total</strong></td><td class="num">—</td><td class="num"><strong>{fmt_usd(total_cost)}</strong></td></tr></tbody>
      </table></div>
    </section>''')

    parts.append('''<p class="caveat"><strong>You have not necessarily been charged this.</strong> It's the equivalent cost <em>if</em> this usage were billed at pay-as-you-go API rates. On a Claude subscription (Pro / Max / Team) you're not billed per token — treat it as a relative measure of usage, not a bill. Approximate: rates are current published prices and the 1M-context tier can bill context above 200k at a premium.</p>''')
    parts.append('<p class="foot">Generated by claude-usage-audit</p>')
    parts.append('</div></div>')
    return "\n".join(parts)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--projects", default=os.path.expanduser("~/.claude/projects"))
    ap.add_argument("--out", required=True)
    ap.add_argument("--top", type=int, default=12)
    args = ap.parse_args()

    data = analyze(os.path.expanduser(args.projects))
    htmlout = render(data, args.top)
    Path(args.out).write_text(htmlout, encoding="utf-8")

    # short text summary to stdout for the caller to relay
    s = data["sessions"]
    peaks = [x["peak"] for x in s]
    med = int(statistics.median(peaks)) if peaks else 0
    cost = sum(family_cost(fam, tok) for fam, tok in data["by_family"].items())
    families = ",".join(sorted(f for f, t in data["by_family"].items()
                               if family_cost(f, t) > 0))
    heaviest = max(s, key=lambda x: x["turns"]) if s else None
    print(f"sessions={len(s)} subagent_transcripts={data['subagent_files']} "
          f"median_peak={med} subagent_spawns={data['subagent_calls']} "
          f"delegated_turns={data['sub_turns_total']} "
          f"est_cost=${cost:,.0f} models=[{families}] "
          f"grep_r={data['disc']['grep_r']} rg={data['disc']['rg']}")
    if heaviest:
        print(f"heaviest: {heaviest['project']} turns={heaviest['turns']} out={heaviest['out']}")
    print(f"wrote {args.out}")


if __name__ == "__main__":
    main()
