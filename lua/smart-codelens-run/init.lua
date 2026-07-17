local M = {}
local function get_ra_runnable_range(lens)
  local arguments = (lens.command.arguments or {})[1]
  local target_range = arguments and arguments.location and arguments.location.targetRange
  if not target_range then
    return -1, -1
  end

  return target_range.start.line, target_range['end'].line
end

local function codelenses_on(pos)
  local position = vim.fn.getpos(pos)
  local bufnr = position[1]
  local row = position[2] - 1

  local lenses_in_buffer
  if vim.fn.has('nvim-0.12') == 1 then
    lenses_in_buffer = vim.lsp.codelens.get({ bufnr = bufnr })
  else
    lenses_in_buffer = vim.lsp.codelens.get(bufnr)
  end

  local lenses = {}
  for _, item in ipairs(lenses_in_buffer) do
    local lens
    local client_id
    if vim.fn.has('nvim-0.12') == 1 then
      lens = item.lens
      client_id = item.client_id
    else
      lens = item
      client_id = nil
    end
    if lens.command and lens.command.command ~= '' then
      local ra_start, ra_end = get_ra_runnable_range(lens)
      if lens.range and lens.range.start.line == row then
        -- highest priority for lenses on current line
        table.insert(lenses, { lens, prio = -1, bufnr = bufnr, client_id = client_id })
      elseif ra_start <= row and row <= ra_end then
        local size = ra_end - ra_start
        -- lower priority for larger range (prefer local lenses)
        table.insert(lenses, { lens, prio = size, bufnr = bufnr, client_id = client_id })
      end
    end
  end

  table.sort(lenses, function(a, b)
    return a.prio < b.prio
  end)

  return lenses
end

local function exec_cmd_handler(...)
  if vim.fn.has('nvim-0.12') ~= 1 then
    -- as in execute_lens from vim/lsp/codelens.lua of neovim-0.11.7, the handler is not passed
    -- anymore in neovim-0.12.4
    vim.lsp.handlers[vim.lsp.protocol.Methods.workspace_executeCommand](...)
    vim.lsp.codelens.refresh()
  end
end
local function execute_lens(lens, bufnr, client_id)
  if client_id ~= nil then
    local client = vim.lsp.get_client_by_id(client_id)
    if client == nil then
      vim.notify('could not execute codelens, client ' .. client_id .. ' gone', vim.log.levels.ERROR)
      return
    end
    vim.notify('excuting on ' .. client.name, vim.log.levels.DEBUG)
    client:exec_cmd(lens.command, { bufnr = bufnr }, exec_cmd_handler)
  else
    -- The codelens source client is not exposed here (<nvim-0.12), so try all clients attached
    -- to this buffer. Clients that do not own the command should ignore it.
    for _, client in pairs(vim.lsp.get_clients({ bufnr = bufnr })) do
      client:exec_cmd(lens.command, { bufnr = bufnr }, exec_cmd_handler)
    end
  end
end

local function format_lens(option)
  local command = option[1].command
  local title = command.title
  local arguments = command.arguments
  local argument = arguments and arguments[1]
  local ra_label = argument and argument.label

  if ra_label and argument.kind then
    ra_label = argument.kind .. ' ' .. ra_label
  end

  if ra_label then
    return ra_label .. ' [' .. title .. ']'
  end

  return title
end

---@class Opts
---@field select boolean? show vim.ui.select dialog when more than one codelens is found for a given position, default: true

---@param opts Opts?
---@return Opts
local function with_defaults(opts)
  opts = opts or {}
  local select
  if opts.select == nil then
    select = true
  end
  return {
    select = select
  }
end

---@param opts Opts?
local function run_on_getpos(pos, opts)
  opts = with_defaults(opts)
  local options = codelenses_on(pos)

  if #options == 0 then
    vim.notify('No executable codelens found for position', vim.log.levels.INFO)
  elseif #options == 1 or not opts.select then
    local lens = options[1]
    execute_lens(lens[1], lens.bufnr, lens.client_id)
  else
    vim.ui.select(options, {
      prompt = 'Code lenses:',
      kind = 'codelens',
      format_item = format_lens,
    }, function(lens)
      if lens then
        execute_lens(lens[1], lens.bufnr, lens.client_id)
      end
    end)
  end
end

---Run codelens in current cursor position or mark passed via register prefix
---@param opts Opts?
function M.run(opts)
  local pos = vim.v.register == '"' and '.' or "'" .. vim.v.register
  run_on_getpos(pos, opts)
end

return M
