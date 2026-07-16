if vim.g.loaded_smart_codelens_run == 1 then
  return
end
vim.g.loaded_smart_codelens_run = 1

vim.keymap.set('n', '<Plug>(SmartCodelensRun)', function()
  require('smart-codelens-run').smart_codelens_run()
end, { desc = 'Run nearest executable codelens' })
