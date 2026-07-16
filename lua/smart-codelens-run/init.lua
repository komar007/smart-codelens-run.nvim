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

local function execute_lens(lens, bufnr, client_id)
  if client_id ~= nil then
    local client = vim.lsp.get_client_by_id(client_id)
    if client == nil then
      vim.notify('could not excute codelens, client ' .. client_id .. ' gone')
      return
    end
    vim.notify('excuting on ' .. client.name)
    client:exec_cmd(lens.command, { bufnr = bufnr }, function(...)
      vim.lsp.handlers[methods.workspace_executeCommand](...)
      vim.lsp.codelens.refresh()
    end)
  else
    -- The codelens source client is not exposed here (<nvim-0.12), so try all clients attached
    -- to this buffer. Clients that do not own the command should ignore it.
    for _, client in pairs(vim.lsp.get_clients({ bufnr = bufnr })) do
      client:exec_cmd(lens.command, { bufnr = bufnr }, function(...)
        vim.lsp.handlers[methods.workspace_executeCommand](...)
        vim.lsp.codelens.refresh()
      end)
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

function M.run_on(pos)
  local options = codelenses_on(pos)

  if #options == 0 then
    vim.notify('No executable codelens found for current line', vim.log.levels.INFO)
  elseif #options == 1 then
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

function M.smart_codelens_run()
  local pos = vim.v.register == '"' and '.' or "'" .. vim.v.register
  M.run_on(pos)
end

return M
