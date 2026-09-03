# Migrated from ~/.zshrc. Injected at the default order (1000), which is after
# oh-my-zsh is sourced (800) and before shellAliases (1100).
#
# Prune what you don't need, then fold the survivors into home.nix proper.
# Anything marked PRUNE below is a candidate I'd drop.
#
# Already handled by modules in home.nix, so deliberately NOT copied here:
#   oh-my-zsh + theme + plugins  -> programs.zsh.oh-my-zsh
#   zsh-autosuggestions          -> programs.zsh.autosuggestion
#   zsh-syntax-highlighting      -> programs.zsh.syntaxHighlighting
#   direnv hook                  -> programs.direnv
#   static env vars / PATH       -> home.sessionVariables / home.sessionPath

# --- keybindings -----------------------------------------------------------
bindkey '^f' autosuggest-accept
# zsh binds ^U to kill-whole-line; readline (bash, python, psql) binds it to
# backward-kill-line. Match readline so CMD+Backspace behaves the same everywhere.
bindkey '^u' backward-kill-line

# --- gpg -------------------------------------------------------------------
# Dynamic per-shell, so it cannot be a sessionVariable.
export GPG_TTY=$(tty)

# --- pyenv -----------------------------------------------------------------
# `eval "$(pyenv init -)"` cost ~80 ms per shell. Most of that was a
# `pyenv rehash`, which rewrites every shim on disk on *every* shell start.
# The static parts of what it did now live in home.nix:
#   $PYENV_ROOT/shims on PATH -> home.sessionPath
#   PYENV_SHELL=zsh           -> home.sessionVariables
# Only the shell function is left, and defining a function costs nothing.
# Run `pyenv rehash` by hand after installing a package with a new entry point.
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"

# Verbatim from `pyenv init -`. Needed for `pyenv shell` / `activate`, which
# have to run in the current shell rather than a subprocess.
pyenv() {
  local command=${1:-}
  [ "$#" -gt 0 ] && shift
  case "$command" in
  activate|deactivate|rehash|shell)
    eval "$(pyenv "sh-$command" "$@")"
    ;;
  *)
    command pyenv "$command" "$@"
    ;;
  esac
}
[[ -r /opt/homebrew/opt/pyenv/completions/pyenv.zsh ]] &&
  source /opt/homebrew/opt/pyenv/completions/pyenv.zsh

# `pyenv virtualenv-init -` dropped: it cost ~50 ms and installed a precmd hook
# that auto-activates a virtualenv on cd. `pyenv virtualenvs` is empty, so it
# was doing nothing. `pyenv activate` still works via the function above.

# --- nvm -------------------------------------------------------------------
# NVM_DIR comes from home.sessionVariables.
# Sourcing nvm.sh cost ~350 ms — the single largest item in startup. node is
# genuinely wanted on PATH though, so put the default version there directly
# with a glob (~0 ms) and defer the rest until something actually calls nvm.
#
# $NVM_DIR/alias/default holds a plain version ("24", "v24.12.0"). The (n)
# qualifier sorts numerically and [-1] takes the highest match, so "24"
# resolves to v24.12.0 rather than v24.9.0. If you ever set the default to an
# alias like "lts/*" the glob finds nothing and node is simply absent until you
# run `nvm use` — which still works, via the stub below.
if [[ -r $NVM_DIR/alias/default ]]; then
  _nvm_want=${$(<$NVM_DIR/alias/default)#v}
  _nvm_bin=( $NVM_DIR/versions/node/v${_nvm_want}*/bin(N/n[-1]) )
  (( $#_nvm_bin )) && path=( $_nvm_bin $path )
  unset _nvm_want _nvm_bin
fi

# First call to `nvm` swaps this stub for the real implementation.
nvm() {
  unfunction nvm
  source "$NVM_DIR/nvm.sh"
  [ -s "$NVM_DIR/bash_completion" ] && source "$NVM_DIR/bash_completion"
  nvm "$@"
}

# --- bun completions -------------------------------------------------------
# BUN_INSTALL comes from home.sessionVariables.
[ -s "$BUN_INSTALL/_bun" ] && source "$BUN_INSTALL/_bun"

# --- colorls ---------------------------------------------------------------
# PRUNE: colorls is a Ruby gem sitting in /usr/local/bin (the Intel Homebrew
# prefix) so nothing manages it. You now have eza in home.packages — this is
# better expressed as shellAliases entries pointing at eza.
if [ -x "$(command -v colorls)" ]; then
    alias ls="colorls"
    alias la="colorls -al"
fi

# --- safe-chain ------------------------------------------------------------
source ~/.safe-chain/scripts/init-posix.sh
