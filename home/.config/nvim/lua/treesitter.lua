-- Tree-sitter. Parsers, queries and the nvim-treesitter plugin all come from
-- the nix store (see home.nix) via ~/.local/share/nvim/site, so there is no
-- :TSInstall step and nothing is compiled at runtime. This file only turns
-- the features on.
--
-- Highlighting is not automatic on nvim-treesitter's current layout: a parser
-- being present just means vim.treesitter.start() will succeed. So attach it
-- per-buffer on FileType.

local group = vim.api.nvim_create_augroup('treesitter_setup', { clear = true })

vim.api.nvim_create_autocmd('FileType', {
  group = group,
  callback = function(args)
    -- pcall: filetypes with no parser installed are simply left on neovim's
    -- built-in regex highlighting rather than throwing on every buffer.
    local ok = pcall(vim.treesitter.start, args.buf)
    if not ok then return end

    -- Structural folding, but open by default — nothing worse than opening a
    -- file to a wall of collapsed functions.
    vim.wo.foldmethod = 'expr'
    vim.wo.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
    vim.wo.foldlevel = 99

    -- Tree-sitter indentation. Only affects typing/`=`; conform.nvim still
    -- owns formatting on save.
    vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
  end,
})
