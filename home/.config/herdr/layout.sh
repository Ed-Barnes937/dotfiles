#!/usr/bin/env sh
# nvim left half | claude top-right (2/3) | shell bottom-right (1/3)
# Bound to prefix+shift+L. Press it in a fresh worktree's single pane.
#
# Ratios are the share kept by the *existing* pane, so 0.5 then 0.7 reproduces
# the standard layout. Pane cwd is inherited (terminal.new_cwd defaults to
# "follow"), so no --cwd is needed and this works as-is in a new worktree.
set -eu

# keys.command runs this detached with no terminal attached, so a failure would
# otherwise vanish. Truncated each run, so it always holds just the last press.
exec >"${TMPDIR:-/tmp}/herdr-layout.log" 2>&1
set -x

new_pane() { python3 -c 'import sys,json;print(json.load(sys.stdin)["result"]["pane"]["pane_id"])'; }

# HERDR_PANE_ID may be unset when run detached; fall back to the UI-focused pane.
root="${HERDR_PANE_ID:-$(herdr pane list | python3 -c 'import sys,json
print(next(p["pane_id"] for p in json.load(sys.stdin)["result"]["panes"] if p["focused"]))')}"

right=$(herdr pane split --pane "$root" --direction right --ratio 0.5 --no-focus | new_pane)
herdr pane split --pane "$right" --direction down --ratio 0.7 --no-focus >/dev/null

# pane run, not `agent start`. agent start blocks waiting for interactive
# readiness and never completed under the detached keybind runner, leaving a
# bare shell. Herdr's agent detection registers a plain `claude` on its own, so
# the pane still gets its sidebar row and status - same as launching it by hand.
herdr pane run "$root" nvim .
herdr pane run "$right" claude
