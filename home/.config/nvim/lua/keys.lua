vim.keymap.set('n', '<Esc>', function()
  vim.cmd('nohlsearch')
  if vim.bo.modified
    and vim.bo.buftype == ''
    and vim.bo.modifiable
    and not vim.bo.readonly
    and vim.api.nvim_buf_get_name(0) ~= ''
  then
    vim.cmd('silent write')
  end
end, { desc = 'Clear search highlight; save if modified' })
vim.keymap.set('n', '<C-a>', 'ggVG', { desc = 'Select All' })
vim.keymap.set('v', 'J', ":m '>+1<CR>gv=gv", { desc = 'move selected text up a line' })
vim.keymap.set('v', 'K', ":m '<-2<CR>gv=gv", { desc = 'move selected text down a line' })
-- pasting over a selection no longer clobbers your clipboard
vim.cmd([[ xnoremap <expr> p 'pgv"'.v:register.'y' ]])
-- Lines wrap (see vim_config.lua), so j/k move by display line and a wrapped
-- line is walkable vertically. With a count they still move real lines, leaving relativenumber jumps like 5j untouched. Deliberately absent
-- from operator-pending mode: dj must stay a whole-line delete, not dgj.
vim.keymap.set({ 'n', 'x' }, 'j', function() return vim.v.count == 0 and 'gj' or 'j' end,
  { expr = true, silent = true, desc = 'down a display line when uncounted' })
vim.keymap.set({ 'n', 'x' }, 'k', function() return vim.v.count == 0 and 'gk' or 'k' end,
  { expr = true, silent = true, desc = 'up a display line when uncounted' })
-- The arrow keys get the same treatment, including in insert mode, where they
-- are the only way to move without leaving insert.
vim.keymap.set({ 'n', 'x' }, '<Down>', function() return vim.v.count == 0 and 'gj' or 'j' end,
  { expr = true, silent = true, desc = 'down a display line when uncounted' })
vim.keymap.set({ 'n', 'x' }, '<Up>', function() return vim.v.count == 0 and 'gk' or 'k' end,
  { expr = true, silent = true, desc = 'up a display line when uncounted' })
vim.keymap.set('i', '<Down>', '<C-o>gj', { silent = true, desc = 'down a display line' })
vim.keymap.set('i', '<Up>', '<C-o>gk', { silent = true, desc = 'up a display line' })
