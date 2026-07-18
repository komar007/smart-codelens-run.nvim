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

vim.keymap.set('n', '<Plug>(smart-codelens-run-mark)', function()
  local mark = vim.fn.getcharstr()
  require('smart-codelens-run').run_at_mark(mark)
end, { desc = 'Run one of the executable codelenses associated with mark passed as argument' })

vim.keymap.set('n', '<Plug>(smart-codelens-run-one-mark)', function()
  local mark = vim.fn.getcharstr()
  require('smart-codelens-run').run_at_mark(mark, { select = false })
end, { desc = 'Run the executable codelens most closely associated with mark passed as argument' })

local saved_position

---@param opts Opts?
local function run_at(opts)
  local motion_start = vim.api.nvim_buf_get_mark(0, "[")
  local motion_end = vim.api.nvim_buf_get_mark(0, "]")
  vim.api.nvim_win_set_cursor(0, saved_position)
  local target = nil
  if vim.deep_equal(motion_start, saved_position) then
    target = motion_end
  elseif vim.deep_equal(motion_end, saved_position) then
    target = motion_start
  end
  if target ~= nil then
    require('smart-codelens-run').run_at(0, target[1], opts)
  end
end
function _G._smart_codelens_run__run_at(_)
  run_at()
end

function _G._smart_codelens_run__run_one_at(_)
  run_at({ select = false })
end

vim.keymap.set("n", "<Plug>(smart-codelens-run-at)", function()
  saved_position = vim.api.nvim_win_get_cursor(0)
  vim.go.operatorfunc = "v:lua._smart_codelens_run__run_at"
  return "g@"
end, { expr = true })

vim.keymap.set("n", "<Plug>(smart-codelens-run-one-at)", function()
  saved_position = vim.api.nvim_win_get_cursor(0)
  vim.go.operatorfunc = "v:lua._smart_codelens_run__run_one_at"
  return "g@"
end, { expr = true })
