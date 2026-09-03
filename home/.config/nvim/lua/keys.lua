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
