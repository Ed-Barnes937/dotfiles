return {
  {
    'saghen/blink.cmp',
    version = '1.*',
    dependencies = { 'rafamadriz/friendly-snippets' },
    opts = {
      -- Each command returns truthy only if it acted, and blink walks the
      -- list until one does. select_and_accept() bails immediately when the
      -- menu isn't visible, so this chain means "take the item if the menu is
      -- up, jump if mid-snippet, otherwise just be a Tab".
      --
      -- snippet_forward has to stay here: the 'default' preset owns <Tab>,
      -- and dropping it silently kills placeholder jumping after a function
      -- signature expands.
      --
      -- <CR> is deliberately left unbound. Enter-to-accept swallows real
      -- newlines, and the fallback that is supposed to prevent that does not:
      -- fallback_to_mappings returns nil when it finds no existing mapping
      -- for the key (keymap/fallback.lua), rather than passing the key
      -- through. <Tab> survives that only because nvim ships a built-in
      -- insert-mode <Tab> mapping for it to find; there is no built-in <CR>,
      -- so binding Enter here breaks newlines outright. Use plain 'fallback'
      -- if Enter is ever wanted, not 'fallback_to_mappings'.
      keymap = {
        preset = 'default',
        ['<Tab>'] = { 'select_and_accept', 'snippet_forward', 'fallback_to_mappings' },
      },

      appearance = { nerd_font_variant = 'mono' },

      completion = {
        -- Nothing is selected when the menu opens, so auto_insert doesn't
        -- preview an item into the buffer until you actually navigate to one
        -- with <C-n>/arrows. <Tab> still takes the top item regardless, since
        -- select_and_accept selects first when there's no selection.
        list = { selection = { preselect = false, auto_insert = true } },
        -- Docs after a beat, rather than a second window opening on every
        -- keystroke.
        documentation = { auto_show = true, auto_show_delay_ms = 250 },
        -- Ghost text off: it reads as buffer content that isn't there.
        ghost_text = { enabled = false },
      },

      -- 'lsp' first so vtsls/lua_ls results outrank buffer-word noise.
      sources = { default = { 'lsp', 'path', 'snippets', 'buffer' } },

      -- Error loudly if the dylib is missing rather than silently degrading
      -- to the slower Lua matcher.
      fuzzy = { implementation = 'rust' },

      signature = { enabled = true },
    },
    opts_extend = { 'sources.default' },
  },
}
