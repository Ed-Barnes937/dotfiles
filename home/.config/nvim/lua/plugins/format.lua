-- Format-on-save via prettier, deferring entirely to each repo's own config.
--
-- Two things have to match the repo, not just one:
--   * config  — prettier walks up from the file to find .prettierrc et al,
--               so this is free.
--   * version — prettier's output changes between majors. A global prettier
--               will happily produce a diff the repo's CI rejects, so the
--               repo's own node_modules/.bin/prettier wins when present.
--               prettierd (from home.nix) is only the fallback.
--
-- If a repo has no prettier config at all, nothing is formatted: silently
-- reformatting someone else's file to prettier defaults makes a garbage diff.

local PRETTIER_CONFIGS = {
  '.prettierrc',
  '.prettierrc.json',
  '.prettierrc.yml',
  '.prettierrc.yaml',
  '.prettierrc.json5',
  '.prettierrc.js',
  '.prettierrc.cjs',
  '.prettierrc.mjs',
  '.prettierrc.toml',
  'prettier.config.js',
  'prettier.config.cjs',
  'prettier.config.mjs',
  '.editorconfig',
}

-- True when this file sits under a repo that opts into prettier: either a
-- config file above it, or a "prettier" key in the nearest package.json.
local function has_prettier_config(ctx)
  if vim.fs.find(PRETTIER_CONFIGS, { path = ctx.filename, upward = true })[1] then
    return true
  end
  local pkg = vim.fs.find('package.json', { path = ctx.filename, upward = true })[1]
  if not pkg then return false end
  local ok, contents = pcall(vim.fn.readfile, pkg)
  if not ok then return false end
  local ok_json, decoded = pcall(vim.json.decode, table.concat(contents, '\n'))
  return ok_json and decoded ~= nil and decoded.prettier ~= nil
end

-- Nearest node_modules/.bin/<name> walking up from the file, else nil.
local function local_bin(ctx, name)
  local dir = vim.fs.find('node_modules', {
    path = ctx.filename,
    upward = true,
    type = 'directory',
  })[1]
  if not dir then return nil end
  local bin = dir .. '/.bin/' .. name
  return vim.uv.fs_stat(bin) and bin or nil
end

local PRETTIER_FILETYPES = {
  'javascript', 'javascriptreact',
  'typescript', 'typescriptreact',
  'vue', 'svelte',
  'css', 'scss', 'less',
  'html',
  'json', 'jsonc',
  'yaml',
  'markdown', 'markdown.mdx',
  'graphql',
}

return {
  {
    'stevearc/conform.nvim',
    event = { 'BufWritePre' },
    cmd = { 'ConformInfo' },
    keys = {
      {
        '<leader>F',
        function() require('conform').format({ async = true, lsp_format = 'fallback' }) end,
        mode = { 'n', 'v' },
        desc = 'Format buffer',
      },
    },
    opts = function()
      -- lua is deliberately absent: lsp_format='fallback' lets lua_ls format
      -- it, so there's no need for a separate formatter binary.
      local by_ft = {
        nix = { 'nixfmt' },
      }
      for _, ft in ipairs(PRETTIER_FILETYPES) do
        by_ft[ft] = { 'prettier' }
      end

      return {
        formatters_by_ft = by_ft,
        formatters = {
          prettier = {
            -- Prefer the repo's pinned prettier; fall back to prettierd.
            command = function(_, ctx)
              return local_bin(ctx, 'prettier') or 'prettierd'
            end,
            condition = function(_, ctx)
              return has_prettier_config(ctx)
            end,
          },
        },
        format_on_save = function(bufnr)
          -- :noautocmd w, or :FormatDisable, escapes formatting entirely.
          if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
            return nil
          end
          return { timeout_ms = 3000, lsp_format = 'fallback' }
        end,
      }
    end,
    config = function(_, opts)
      require('conform').setup(opts)

      vim.api.nvim_create_user_command('FormatDisable', function(args)
        if args.bang then
          vim.b.disable_autoformat = true
        else
          vim.g.disable_autoformat = true
        end
      end, { desc = 'Disable format-on-save (! = this buffer only)', bang = true })

      vim.api.nvim_create_user_command('FormatEnable', function()
        vim.b.disable_autoformat = false
        vim.g.disable_autoformat = false
      end, { desc = 'Re-enable format-on-save' })
    end,
  },
}
