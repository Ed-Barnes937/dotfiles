{
  config,
  lib,
  pkgs,
  user,
  ...
}:

let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
  home = config.home.homeDirectory;

  # A ZSH_CUSTOM tree built in the nix store, so nothing is read from
  # ~/.oh-my-zsh any more. Layout matches what oh-my-zsh expects:
  #   $ZSH_CUSTOM/plugins/<name>/<name>.plugin.zsh
  # No themes/ any more — the prompt is starship, configured below.
  zshCustom = pkgs.runCommand "zsh-custom" { } ''
    mkdir -p $out/plugins
    ln -s ${./home/zsh/omz-custom/plugins/custom-git} $out/plugins/custom-git
  '';

  # Tree-sitter grammars, pinned by the flake instead of compiled at runtime
  # by :TSInstall. nvim-treesitter's current (main-branch) layout reads parsers
  # from <install_dir>/parser/<lang>.so, and its default install_dir is
  # stdpath('data')/site — already on neovim's default runtimepath, so the
  # symlinks below are all the wiring needed.
  #
  # nixpkgs spells these with hyphens; neovim wants the parser file named with
  # underscores (tree-sitter-git-config -> git_config.so), hence the rename.
  #
  # Deliberately absent, and both exclusions are load-bearing:
  #
  # 1. c, lua, markdown, markdown-inline, query, vim, vimdoc. Neovim bundles
  #    these parsers itself, matched to the queries in its own runtime. Because
  #    site/parser sorts ahead of $VIMRUNTIME on runtimepath, listing them here
  #    shadows and *downgrades* what neovim ships.
  # 2. kotlin, regex. No bundled fallback, so these lose tree-sitter and fall
  #    back to regex syntax highlighting until the grammars catch up.
  #
  # Both are the same root cause: parsers come from pkgs.tree-sitter-grammars
  # while the queries below come from pkgs.vimPlugins.nvim-treesitter, and
  # nixpkgs updates the two on separate cadences. As of the current pin they are
  # ~11 months apart, which is enough for the newer queries to reference nodes
  # and fields the older grammars do not have (e.g. lua highlights matching
  # `operator:` on binary_expression, absent from tree-sitter-lua 2025-05-16).
  #
  # To re-add a language from group 2, check first that its query set still
  # compiles against the pinned grammar:
  #   nvim --headless -c 'lua print(pcall(vim.treesitter.query.get,"regex","highlights"))' -c qa
  tsLangs = [
    "bash"
    "css"
    "diff"
    "dockerfile"
    "git-config"
    "git-rebase"
    "gitcommit"
    "gitignore"
    "html"
    "javascript"
    "json"
    "nix"
    "python"
    "toml"
    "tsx"
    "typescript"
    "yaml"
  ];

  tsParsers = pkgs.runCommand "nvim-treesitter-parsers" { } ''
    mkdir -p $out/parser
    ${lib.concatMapStringsSep "\n" (
      g:
      "ln -s ${pkgs.tree-sitter-grammars."tree-sitter-${g}"}/parser"
      + " $out/parser/${lib.replaceStrings [ "-" ] [ "_" ] g}.so"
    ) tsLangs}
  '';
in

{
  home.username = user;
  home.homeDirectory = "/Users/${user}";
  home.stateVersion = "26.05";
  home.packages = with pkgs; [
    nixfmt-rfc-style # formatter (the current official style)
    nil # Nix LSP
    statix # linter — catches antipatterns
    nvd # diffs generations: "what changed in this rebuild?"
    fd # you have ripgrep (as a dependency); fd is its `find` counterpart
    eza # replaces colorls
    fzf # fuzzy finder
    delta # git diffs
    lazygit # git TUI
    bat # cat with syntax highlighting
    deno # JavaScript/TypeScript runtime
    gh # GitHub CLI
    git-lfs # git large file storage
    jq # JSON processor
    ncdu # disk usage browser (TUI)
    p7zip # 7-Zip archives
    uv # Python package/env manager; drives the excalidraw-diagram skill renderer
    neovim
    claude-code # from the sadjow flake overlay, not nixpkgs

    # LSP servers for neovim (wired up in home/.config/nvim/lua/plugins/lsp.lua);
    # nil above covers Nix itself
    lua-language-server
    vtsls # typescript/javascript (incl. react tsx/jsx)
    kotlin-language-server
    marksman # markdown
    vscode-langservers-extracted # html, css, json, eslint servers

    # formatting: fallback only. conform.nvim prefers the repo's own
    # node_modules/.bin/prettier so output matches that repo's pinned version.
    prettierd

    # the font everything renders in
    nerd-fonts.monaspace
  ];
  fonts.fontconfig.enable = true;

  home.sessionVariables = {
    USE_GKE_GCLOUD_AUTH_PLUGIN = "True";
    PYENV_ROOT = "${home}/.pyenv";
    PYENV_SHELL = "zsh"; # was: eval "$(pyenv init -)"
    NVM_DIR = "${home}/.nvm";
    BUN_INSTALL = "${home}/.bun";
    DOT_NET_HOME = "/usr/local/share/dotnet";
    PNPM_HOME = "${home}/Library/pnpm";
    COREPACK_ENABLE_AUTO_PIN = "0";
    EDITOR = "nvim";
    DISABLE_AUTOUPDATER = "1"; # Claude Code: don't self-install into ~/.local; nix (claude-code-nix flake) is authoritative
  };

  # PATH entries lifted out of .zshrc and .zshenv.
  home.sessionPath = [
    "${home}/.pyenv/shims"
    "${home}/bin"
    "${home}/.local/bin"
    "${home}/.cargo/bin"
    "${home}/.grit/bin"
    "${home}/.bun/bin"
    "${home}/Library/pnpm"
    "/usr/local/share/dotnet"
    "/usr/local/bin"
  ];

  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;
      format = "$directory$git_branch$git_status$cmd_duration$line_break$character";
      character = {
        success_symbol = "[❯](purple)";
        error_symbol = "[❯](red)";
      };
      cmd_duration.format = "[$duration]($style) ";
    };
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true; # ghost text from history
    syntaxHighlighting.enable = true; # commands turn green when valid

    oh-my-zsh = {
      enable = true;
      custom = "${zshCustom}";
      plugins = [
        "git"
        "custom-git"
      ];
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

    initContent = builtins.readFile ./home/zsh/init-main.zsh;
  };

  # Edit-in-place: the real file stays in my repo, ~/.config just points at it.
  home.file.".config/wezterm".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/wezterm";
  home.file.".config/herdr".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/herdr";
  home.file.".claude/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.claude/settings.json";
  home.file.".claude/skills".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.claude/skills";
  home.file.".claude/statusline-command.sh".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.claude/statusline-command.sh";
  home.file.".config/nvim".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/nvim";

  home.file.".claude/CLAUDE.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";
  home.file.".codex/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";
  home.file.".config/opencode/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";

  home.file.".local/share/nvim/site/parser".source = "${tsParsers}/parser";
  home.file.".local/share/nvim/site/queries".source =
    "${pkgs.vimPlugins.nvim-treesitter}/runtime/queries";
  home.file.".local/share/nvim/site/pack/nix/start/nvim-treesitter".source =
    pkgs.vimPlugins.nvim-treesitter;
}
