#!/bin/sh
# Claude Code status line — Powerlevel10k-styled.
# Line 1: os_icon -> dir -> vcs (rounded powerline segments).
# Line 2: model([fable_rem%] ctx_tok) 5hr%/7d%

input=$(cat)

# jq via absolute path: Claude Code's status-line PATH lacks the asdf shim dir.
JQ=/opt/homebrew/bin/jq
[ -x "$JQ" ] || JQ=$(command -v jq 2>/dev/null) || JQ=jq

# --- pull fields ---------------------------------------------------------
cwd=$(printf '%s' "$input"      | "$JQ" -r '.cwd // .workspace.current_dir // ""')
model=$(printf '%s' "$input"    | "$JQ" -r '.model.display_name // ""')
day_pct=$(printf '%s' "$input"  | "$JQ" -r '.rate_limits.five_hour.used_percentage // empty')
day_pct=${day_pct%.*}
wk_pct=$(printf '%s' "$input"   | "$JQ" -r '.rate_limits.seven_day.used_percentage // empty')
wk_pct=${wk_pct%.*}
day_reset=$(printf '%s' "$input" | "$JQ" -r '.rate_limits.five_hour.resets_at // empty')
wk_reset=$(printf '%s' "$input"  | "$JQ" -r '.rate_limits.seven_day.resets_at // empty')
now=$(date +%s)
tok=$(printf '%s' "$input"      | "$JQ" -r '(.context_window.total_input_tokens // 0) + (.context_window.total_output_tokens // 0)')

# Shorten "Opus 4.8 (1M context)" -> "Opus 4.8 (1M)"
model=$(printf '%s' "$model" | sed 's/(1M context)/(1M)/')

# --- glyphs (nerdfont-complete, emitted as raw UTF-8 to avoid \u issues) --
APPLE=$(printf '\357\214\202')   # U+F302 apple
GIT=$(printf '\357\204\246')     # U+F126 branch
SEP=$(printf '\356\202\264')     # U+E0B4 right rounded separator

# --- helpers -------------------------------------------------------------
fg()  { printf '\033[38;5;%sm' "$1"; }
bg()  { printf '\033[48;5;%sm' "$1"; }
rst() { printf '\033[0m'; }

# humanize a token count: 1234 -> 1K, 59482 -> 59K, 2300000 -> 2.3M
human() {
  n=$1
  if   [ "$n" -ge 1000000 ]; then printf '%d.%dM' "$(( n / 1000000 ))" "$(( (n % 1000000) / 100000 ))"
  elif [ "$n" -ge 1000 ];    then printf '%dK' "$(( n / 1000 ))"
  else                            printf '%d' "$n"
  fi
}

# ctx_color: colour a humanised token string based on raw token count.
# orange (208) > 150k, red (196) > 200k, else dim (244).
ctx_color() {
  n=$1
  if   [ "$n" -gt 200000 ]; then fg 196
  elif [ "$n" -gt 150000 ]; then fg 208
  else                           fg 244
  fi
}

# five_color: red (196) > 80%, else dim (244).
five_color() {
  [ -n "$1" ] || { printf -- '-'; return; }
  if [ "$1" -gt 80 ]; then fg 196; else fg 244; fi
  printf '%s%%' "$1"; rst
}

# week_color: red (196) > 80%, orange (208) > 60%, else dim (244).
week_color() {
  [ -n "$1" ] || { printf -- '-'; return; }
  if   [ "$1" -gt 80 ]; then fg 196
  elif [ "$1" -gt 60 ]; then fg 208
  else                       fg 244
  fi
  printf '%s%%' "$1"; rst
}

# fmt_reset: seconds-until-reset -> "3hr", "45m", or "2d". Empty if already passed.
fmt_reset() {
  s=$1
  [ -n "$s" ] && [ "$s" -gt 0 ] || return
  if   [ "$s" -ge 86400 ]; then printf '%dd' "$(( s / 86400 ))"
  elif [ "$s" -ge 3600 ];  then printf '%dhr' "$(( s / 3600 ))"
  else                          printf '%dm' "$(( (s + 59) / 60 ))"
  fi
}

# --- shorten cwd like p10k (collapse $HOME, abbreviate parents) ----------
# Every parent component collapses to its first character, so the segment
# stays a bounded width however deep the tree; a leading dot is kept and the
# final component is never touched:
#   ~/Code/dotfiles/home/.claude -> ~/C/d/h/.claude
shorten_dir() {
  p=$1
  case "$p" in
    "~"|"/") printf '%s' "$p"; return ;;
    "~/"*) root="~/"; p=${p#\~/} ;;
    /*)    root="/";  p=${p#/} ;;
    *)     root="" ;;
  esac

  leaf=${p##*/}
  parents=${p%/*}
  # No separator left means the leaf was the only component.
  [ "$parents" = "$p" ] && { printf '%s%s' "$root" "$leaf"; return; }

  abbrev=""
  IFS=/
  for comp in $parents; do
    case "$comp" in
      ""|.|..) short_comp=$comp ;;
      .*)      short_comp=${comp%"${comp#??}"} ;;
      *)       short_comp=${comp%"${comp#?}"} ;;
    esac
    abbrev="$abbrev$short_comp/"
  done
  unset IFS

  printf '%s%s%s' "$root" "$abbrev" "$leaf"
}

case "$cwd" in
  "$HOME") short="~" ;;
  "$HOME"/*) short="~/${cwd#$HOME/}" ;;
  *) short="$cwd" ;;
esac
short=$(shorten_dir "$short")

# --- git segment ---------------------------------------------------------
branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null)
if [ -n "$branch" ]; then
  if [ -n "$(git -C "$cwd" --no-optional-locks status --porcelain 2>/dev/null)" ]; then
    git_bg=3        # yellow = modified
    git_txt="$GIT $branch *"
  else
    git_bg=2        # green = clean
    git_txt="$GIT $branch"
  fi
fi

# --- render: powerline left side ----------------------------------------
out=""
out="$out$(bg 7)$(fg 232) $APPLE "
out="$out$(bg 4)$(fg 7)$SEP$(fg 254) $short "
if [ -n "$branch" ]; then
  out="$out$(bg "$git_bg")$(fg 4)$SEP$(fg 0) $git_txt "
  out="$out$(rst)$(fg "$git_bg")$SEP$(rst)"
else
  out="$out$(rst)$(fg 4)$SEP$(rst)"
fi

# --- line 2: model([fable_rem%] ctx_tok) 5hr%/7d% -----------------------
line2=""

# Build the parenthesised section inside model(...)
paren_inner=""

# Fable remaining weekly %: only when model name contains "Fable"
case "$model" in
  *[Ff]able*)
    if [ -n "$wk_pct" ]; then
      wk_rem=$(( 100 - wk_pct ))
      paren_inner="$(fg 245)${wk_rem}% $(rst) "
    fi
    ;;
esac

# Context token count with colour
paren_inner="${paren_inner}$(ctx_color "$tok")$(human "$tok") tok$(rst)"

line2="$(fg 245)$model$(rst)$(fg 244)($(rst)${paren_inner}$(fg 244))$(rst)"

# Rate limits: 5hr% (reset)/7d% (reset) — only when at least one is present
if [ -n "$day_pct" ] || [ -n "$wk_pct" ]; then
  day_r=""; wk_r=""
  [ -n "$day_reset" ] && day_r=$(fmt_reset $(( day_reset - now )))
  [ -n "$wk_reset" ]  && wk_r=$(fmt_reset $(( wk_reset - now )))
  line2="$line2 $(fg 240)|$(rst) $(five_color "$day_pct")"
  [ -n "$day_r" ] && line2="$line2$(fg 240) ($day_r)$(rst)"
  line2="$line2$(fg 240)/$(rst)$(week_color "$wk_pct")"
  [ -n "$wk_r" ] && line2="$line2$(fg 240) ($wk_r)$(rst)"
fi

printf '%s\n%s' "$out" "$line2"
