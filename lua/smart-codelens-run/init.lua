local M = {}
local function get_ra_runnable_range(lens)
  local arguments = (lens.command.arguments or {})[1]
  local target_range = arguments and arguments.location and arguments.location.targetRange
  if not target_range then
    return -1, -1
  end

  return target_range.start.line, target_range['end'].line
end

--- Get the extended codelens range using treesitter parent of the node determined by codelens range
---@param lens lsp.CodeLens
---@param bufnr integer
---@return integer, integer the start and end row of extended range
local function get_treesitter_extended_range(lens, bufnr)
  local parser, _ = vim.treesitter.get_parser(bufnr)
  if parser == nil then
    return -1, -1
  end
  local range = {
    lens.range.start.line,
    lens.range.start.character,
    lens.range["end"].line,
    lens.range["end"].character
  }
  local node = parser:node_for_range(range)
  if node == nil then
    return -1, -1
  end
  local parent = node:parent()
  if parent == nil then
    return -1, -1
  end
  local start_row, _, end_row, _ = parent:range()
  return start_row, end_row
end

local extended_range_fun = {
  ["rust-analyzer"] = get_ra_runnable_range,
}

---@param lens lsp.CodeLens
---@param bufnr integer
---@param client vim.lsp.Client
---@return integer, integer the start and end row of extended range
local function get_extended_range(lens, bufnr, client)
  local start_row = -1
  local end_row = -1
  local ext = extended_range_fun[client and client.name]
  if ext ~= nil then
    start_row, end_row = ext(lens)
  end
  if start_row == -1 and end_row == -1 then
    start_row, end_row = get_treesitter_extended_range(lens, bufnr)
  end
  return start_row, end_row
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
    local client
    if vim.fn.has('nvim-0.12') == 1 then
      lens = item.lens
      client = vim.lsp.get_client_by_id(item.client_id)
      if client == nil then
        goto continue
      end
    else
      lens = item
      client = nil
    end
    if lens.command == nil or lens.command.command == '' then
      goto continue
    end
    if lens.range and lens.range.start.line == row then
      -- highest priority for lenses on current line
      table.insert(lenses, { lens, prio = -1, bufnr = bufnr, client = client })
      goto continue
    end
    local ext_start, ext_end = get_extended_range(lens, bufnr, client)
    if ext_start <= row and row <= ext_end then
      local size = ext_end - ext_start
      -- lower priority for larger range (prefer local lenses)
      table.insert(lenses, { lens, prio = size, bufnr = bufnr, client = client })
    end
    ::continue::
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

---@param lens lsp.CodeLens
---@param bufnr integer
---@param client vim.lsp.Client?
local function execute_lens(lens, bufnr, client)
  if client ~= nil then
    vim.notify('excuting on ' .. client.name, vim.log.levels.DEBUG)
    client:exec_cmd(lens.command, { bufnr = bufnr }, exec_cmd_handler)
  else
    -- The codelens source client is not exposed here (<nvim-0.12), so try all clients attached
    -- to this buffer. Clients that do not own the command should ignore it.
    for _, c in pairs(vim.lsp.get_clients({ bufnr = bufnr })) do
      c:exec_cmd(lens.command, { bufnr = bufnr }, exec_cmd_handler)
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
    execute_lens(lens[1], lens.bufnr, lens.client)
  else
    vim.ui.select(options, {
      prompt = 'Code lenses:',
      kind = 'codelens',
      format_item = format_lens,
    }, function(lens)
      if lens then
        execute_lens(lens[1], lens.bufnr, lens.client)
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
