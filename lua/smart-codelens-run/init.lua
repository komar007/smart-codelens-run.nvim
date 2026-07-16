local M = {}

local methods = vim.lsp.protocol.Methods

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
  local col = position[3] - 1

  local lenses = {}
  for _, lens in ipairs(vim.lsp.codelens.get(bufnr)) do
    if lens.command and lens.command.command ~= '' then
      local ra_start, ra_end = get_ra_runnable_range(lens)

      if lens.range and lens.range.start.line == row then
        table.insert(lenses, { lens, prio = -1, bufnr = bufnr })
      elseif ra_start <= row and row <= ra_end then
        local size = ra_end - ra_start
        table.insert(lenses, { lens, prio = size, bufnr = bufnr })
      end
    end
  end

  table.sort(lenses, function(a, b)
    return a.prio < b.prio
  end)

  return lenses
end

local function execute_lens(lens, bufnr)
  -- The codelens source client is not exposed here, so try all clients attached
  -- to this buffer. Clients that do not own the command should ignore it.
  for _, client in pairs(vim.lsp.get_clients({ bufnr = bufnr })) do
    client:exec_cmd(lens.command, { bufnr = bufnr }, function(...)
      vim.lsp.handlers[methods.workspace_executeCommand](...)
      vim.lsp.codelens.refresh()
    end)
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

function M.run_on(pos)
  local options = codelenses_on(pos)

  if #options == 0 then
    vim.notify('No executable codelens found for current line', vim.log.levels.INFO)
  elseif #options == 1 then
    local lens = options[1]
    execute_lens(lens[1], lens.bufnr)
  else
    vim.ui.select(options, {
      prompt = 'Code lenses:',
      kind = 'codelens',
      format_item = format_lens,
    }, function(lens)
      if lens then
        execute_lens(lens[1], lens.bufnr)
      end
    end)
  end
end

function M.smart_codelens_run()
  local pos = vim.v.register == '"' and '.' or "'" .. vim.v.register
  M.run_on(pos)
end

return M
