-- Node types that suppress pairing in the js/ts family, shared by the four
-- filetypes below. Names come from the grammar, so check with :Inspect
-- before extending this to another language.
--
-- 'template_string' is deliberately absent, though upstream ships it for
-- javascript: there is no rule for '${', so the '{' of `${` goes through the
-- ordinary brace rule and suppressing pairs inside backticks would stop it
-- closing.
local JS_STRINGS = { 'string', 'string_fragment', 'comment' }

return {
  -- Types the closing half of a pair for you, and removes both halves on
  -- backspace.
  {
    'windwp/nvim-autopairs',
    event = 'InsertEnter',
    opts = {
      -- Judge context by the tree-sitter node under the cursor rather than
      -- by regex, so a bracket typed inside a string or comment is left
      -- alone. Only as good as the cursor's own node: typing at the very end
      -- of a comment, or between the last character and the closing quote,
      -- lands on a node that isn't the string/comment itself and still
      -- pairs. Partial, but there is no cost to it.
      check_ts = true,

      -- A filetype with no entry here simply pairs everywhere, which is the
      -- harmless default. Listing javascript explicitly is what drops
      -- upstream's 'template_string', since tbl_deep_extend replaces a list
      -- rather than merging into it.
      ts_config = {
        javascript = JS_STRINGS,
        javascriptreact = JS_STRINGS,
        typescript = JS_STRINGS,
        typescriptreact = JS_STRINGS,
      },
    },
  },

  -- Closes and renames JSX/HTML tag pairs.
  --
  -- No `dependencies` entry, even though this is a tree-sitter consumer:
  -- nvim-treesitter comes from the nix store (see home.nix and
  -- lua/plugins/treesitter.lua), and naming it here would have lazy clone a
  -- second, unpinned copy.
  --
  -- The filetype list is limited to parsers home.nix actually pins, plus
  -- markdown, whose parser neovim bundles and which autotag treats as html.
  {
    'windwp/nvim-ts-autotag',
    ft = {
      'html',
      'javascript',
      'javascriptreact',
      'typescript',
      'typescriptreact',
      'markdown',
    },
    opts = {},
  },
}
