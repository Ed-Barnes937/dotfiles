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

# --- powerlevel10k ---------------------------------------------------------
# ~/.p10k.zsh is a 1836-line generated file; regenerate with `p10k configure`.
# Left outside nix on purpose — it is machine-tuned, not config you hand-edit.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# --- gpg -------------------------------------------------------------------
# Dynamic per-shell, so it cannot be a sessionVariable.
export GPG_TTY=$(tty)

# --- pyenv -----------------------------------------------------------------
# PYENV_ROOT comes from home.sessionVariables.
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"

# --- nvm -------------------------------------------------------------------
# NVM_DIR comes from home.sessionVariables.
# PRUNE: nvm adds noticeable startup cost and overlaps with pnpm/corepack.
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

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
