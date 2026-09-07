return {
  {
    'neovim/nvim-lspconfig',
    -- Load-ordering only, not packaging: both plugins load at startup and
    -- lazy.nvim gives no relative order otherwise. If blink came second, the
    -- first server started (the file nvim opened with) would miss its
    -- capabilities while every later one had them.
    dependencies = { 'saghen/blink.cmp' },
    config = function()
      -- blink's completion capabilities, merged into every server. nvim
      -- already deep-extends these over make_client_capabilities() when the
      -- client starts (vim/lsp/client.lua), so only blink's deltas go here.
      vim.lsp.config('*', {
        capabilities = require('blink.cmp').get_lsp_capabilities(),
      })

      -- lua_ls doesn't know about neovim's `vim` global or runtime by default
      vim.lsp.config('lua_ls', {
        settings = {
          Lua = {
            runtime = { version = 'LuaJIT' },
            diagnostics = { globals = { 'vim' } },
            workspace = {
              library = vim.api.nvim_get_runtime_file('', true),
              checkThirdParty = false,
            },
          },
        },
      })

      vim.lsp.enable({
        'nil_ls',                 -- nix
        'vtsls',                  -- typescript / javascript (incl. tsx/jsx)
        'kotlin_language_server', -- kotlin
        'lua_ls',                 -- lua
        'html',                   -- HTML
        'cssls',                  -- CSS
        'jsonls',                 -- JSON
        'eslint',                 -- ESLint (reads the repo's own config)
        'marksman',               -- Markdown
      })

      -- Apply ESLint's own --fix on save. Only attaches in buffers where the
      -- eslint server actually started, so repos with no eslint config are
      -- left alone. BufWritePost (not Pre) so it runs after conform's prettier
      -- pass, letting eslint-plugin-prettier setups converge rather than fight.
      vim.api.nvim_create_autocmd('LspAttach', {
        callback = function(args)
          local client = vim.lsp.get_client_by_id(args.data.client_id)
          if not client or client.name ~= 'eslint' then return end
          vim.api.nvim_create_autocmd('BufWritePost', {
            buffer = args.buf,
            callback = function() pcall(vim.cmd, 'LspEslintFixAll') end,
          })
        end,
      })
    end,
  },
}
