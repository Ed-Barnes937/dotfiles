{ config, pkgs, lib, user, ... }:

let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
  home = config.home.homeDirectory;

  # A ZSH_CUSTOM tree built in the nix store, so nothing is read from
  # ~/.oh-my-zsh any more. Layout matches what oh-my-zsh expects:
  #   $ZSH_CUSTOM/themes/<name>/<name>.zsh-theme
  #   $ZSH_CUSTOM/plugins/<name>/<name>.plugin.zsh
  zshCustom = pkgs.runCommand "zsh-custom" { } ''
    mkdir -p $out/themes $out/plugins
    ln -s ${pkgs.zsh-powerlevel10k}/share/zsh/themes/powerlevel10k $out/themes/powerlevel10k
    ln -s ${./home/zsh/omz-custom/plugins/custom-git} $out/plugins/custom-git
  '';
in

{
  home.username = user;
  home.homeDirectory = "/Users/${user}";
  home.stateVersion = "26.05";
  home.packages = with pkgs; [
    nixfmt-rfc-style   # formatter (the current official style)
    nil                # Nix LSP
    statix             # linter — catches antipatterns
    nvd                # diffs generations: "what changed in this rebuild?"
    fd                 # you have ripgrep (as a dependency); fd is its `find` counterpart
    eza                # replaces colorls
    fzf                # fuzzy finder
    delta              # git diffs
    lazygit            # git TUI
    bat                # cat with syntax highlighting
    deno               # JavaScript/TypeScript runtime
    gh                 # GitHub CLI
    git-lfs            # git large file storage
    jq                 # JSON processor
    ncdu               # disk usage browser (TUI)
    p7zip              # 7-Zip archives
  ];

  # Static exports lifted out of .zshrc. These land in hm-session-vars.sh,
  # which is sourced early, so init-main.zsh can rely on them.
  home.sessionVariables = {
    USE_GKE_GCLOUD_AUTH_PLUGIN = "True";
    PYENV_ROOT = "${home}/.pyenv";
    NVM_DIR = "${home}/.nvm";
    BUN_INSTALL = "${home}/.bun";
    DOT_NET_HOME = "/usr/local/share/dotnet";
    PNPM_HOME = "${home}/Library/pnpm";
    COREPACK_ENABLE_AUTO_PIN = "0";
  };

  # PATH entries lifted out of .zshrc and .zshenv.
  home.sessionPath = [
    "${home}/bin"
    "${home}/.local/bin"
    "${home}/.cargo/bin"        # was: . "$HOME/.cargo/env" in ~/.zshenv
    "${home}/.grit/bin"         # was: . "$HOME/.grit/bin/env"
    "${home}/.bun/bin"
    "${home}/Library/pnpm"
    "/usr/local/share/dotnet"
    "/usr/local/bin"
  ];

  # Replaces `eval "$(direnv hook zsh)"`.
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;      # ghost text from history
    syntaxHighlighting.enable = true;  # commands turn green when valid

    oh-my-zsh = {
      enable = true;
      theme = "powerlevel10k/powerlevel10k";
      # Built above from pkgs.zsh-powerlevel10k plus the custom-git plugin
      # vendored into this repo. ~/.oh-my-zsh is no longer read at all.
      custom = "${zshCustom}";
      # zsh-syntax-highlighting and zsh-autosuggestions dropped from this list:
      # programs.zsh loads them natively above, and loading twice is a bug.
      plugins = [ "git" "custom-git" ];
    };

    shellAliases = {
      ".." = "cd ..";
      add = "git add .";
      push = "git push";
      pull = "git pull";
      m = "git switch main";
      cc = "claude --dangerously-skip-permissions";
      co = "codex --full-auto";
    };

    initContent = lib.mkMerge [
      (lib.mkOrder 500 (builtins.readFile ./home/zsh/init-early.zsh))
      (builtins.readFile ./home/zsh/init-main.zsh)
    ];
  };

  # Edit-in-place: the real file stays in my repo, ~/.config just points at it.
  home.file.".config/wezterm".source =
  config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/wezterm";
}
