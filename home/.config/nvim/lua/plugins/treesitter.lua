-- nvim-treesitter itself comes from the nix store (see home.nix), which puts
-- it in ~/.local/share/nvim/site/pack/nix/start. That location is never
-- loaded: lazy.nvim sets `loadplugins = false` and sources plugin/ only for
-- the runtimepath it captured, so nvim's own start-package step never runs.
--
-- Registering it with lazy as a local plugin (`dir`, so nothing is cloned)
-- is what makes its plugin/ files run. Three things depend on them:
--   * plugin/filetypes.lua      - filetype -> parser names (typescriptreact
--                                 -> tsx, javascriptreact -> javascript,
--                                 sh -> bash, jsonc -> json). Without it
--                                 vim.treesitter.start() fails on those
--                                 filetypes and they silently fall back to
--                                 regex highlighting.
--   * plugin/query_predicates.lua - custom predicates the queries in
--                                 site/queries reference.
--   * lua/nvim-treesitter/       - the module treesitter.lua's indentexpr
--                                 calls into.
return {
  {
    dir = vim.fn.stdpath('data') .. '/site/pack/nix/start/nvim-treesitter',
    name = 'nvim-treesitter',
    lazy = false,
    priority = 100,
  },
}
