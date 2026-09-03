return {
  {
    'folke/snacks.nvim',
    priority = 1000,
    lazy = false,
    opts = {
      picker = {
        enabled = true,
        sources = {
          files = { hidden = true, ignored = false },
          grep = { hidden = true, ignored = false },
          explorer = {
            hidden = true,
            jump = { close = true },
            auto_close = true,
          },
        },
      },
      notifier = { enabled = true },
      input = { enabled = true },
    },
    keys = {
      { '<leader>f', function() Snacks.picker.files() end,           desc = 'Find Files' },
      { '<leader>s', function() Snacks.picker.grep() end,            desc = 'Search Text' },
      { '<leader>b', function() Snacks.picker.buffers() end,         desc = 'Buffers' },
      { 'gd',        function() Snacks.picker.lsp_definitions() end, desc = 'Goto Definition' },
      { '<leader>e', function() Snacks.explorer() end,               desc = 'File explorer (tree)' },
    },
  }
}
