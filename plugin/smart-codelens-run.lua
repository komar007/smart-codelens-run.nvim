if vim.g.loaded_smart_codelens_run == 1 then
  return
end
vim.g.loaded_smart_codelens_run = 1

vim.keymap.set('n', '<Plug>(smart-codelens-run)', function()
  require('smart-codelens-run').run()
end, { desc = 'Run one of the executable codelenses associated with cursor/mark' })

vim.keymap.set('n', '<Plug>(smart-codelens-run-one)', function()
  require('smart-codelens-run').run({ select = false })
end, { desc = 'Run the executable codelens most closely associated with cursor/mark' })
