local M = {}

local MAX_SLOTS = 9

local bindings   = {}   -- slot index (1..9) -> canonical absolute path
local editor_win = nil  -- prevent duplicate manager windows

-- Parse manager buffer lines into a position-preserving slot list.
-- Leading comment (#) lines are skipped; the next up to MAX_SLOTS lines map
-- to slots 1..N verbatim, so a blank line leaves that slot unassigned.
local function parse_names(lines)
  local names = {}
  local started = false
  for _, line in ipairs(lines) do
    local trimmed = vim.trim(line)
    if not started then
      if trimmed == '' or vim.startswith(trimmed, '#') then
        -- still in the header region
      else
        started = true
      end
    end
    if started then
      names[#names + 1] = trimmed
      if #names >= MAX_SLOTS then break end
    end
  end
  return names
end

local function abspath(cfg, name)
  return vim.fn.fnamemodify(vim.fn.expand(cfg.dir) .. '/' .. name, ':p')
end

function M.ensure_dir(cfg)
  vim.fn.mkdir(vim.fn.expand(cfg.dir), 'p')
end

function M.store_path(cfg)
  return vim.fn.fnamemodify(vim.fn.expand(cfg.dir) .. '/slots.json', ':p')
end

function M.resolve()
  return bindings
end

function M.get(slot)
  return bindings[slot]
end

-- Rebuild bindings from a list of filenames (index = slot). Blank entries
-- leave a slot unassigned.
local function set_from_names(cfg, names)
  bindings = {}
  for i = 1, MAX_SLOTS do
    local name = names[i]
    if name and name ~= '' then
      bindings[i] = abspath(cfg, name)
    end
  end
end

-- Guarantee slot 1 is always openable so the jot window (and the manager,
-- which is only reachable from inside it) can never lock the user out.
local function ensure_default(cfg)
  if not bindings[1] and cfg.default_note and cfg.default_note ~= '' then
    bindings[1] = abspath(cfg, cfg.default_note)
  end
end

function M.save(cfg)
  local names = {}
  for i = 1, MAX_SLOTS do
    names[i] = bindings[i] and vim.fn.fnamemodify(bindings[i], ':t') or ''
  end
  local ok, encoded = pcall(vim.json.encode, { slots = names })
  if not ok then
    vim.notify('jot: failed to encode slots.json', vim.log.levels.ERROR)
    return
  end
  local wrote = pcall(vim.fn.writefile, { encoded }, M.store_path(cfg))
  if not wrote then
    vim.notify('jot: failed to write slots.json', vim.log.levels.ERROR)
  end
end

function M.load(cfg)
  local path = M.store_path(cfg)
  local persisted = false

  if vim.fn.filereadable(path) == 1 then
    local ok, data = pcall(function()
      return vim.json.decode(table.concat(vim.fn.readfile(path), '\n'))
    end)
    if ok and type(data) == 'table' and type(data.slots) == 'table' then
      set_from_names(cfg, data.slots)
      persisted = true
    else
      vim.notify('jot: slots.json is unreadable; ignoring', vim.log.levels.WARN)
      set_from_names(cfg, cfg.slots or {})
    end
  else
    -- First run: seed from config.
    set_from_names(cfg, cfg.slots or {})
  end

  ensure_default(cfg)

  -- Persist so the store (and the default) exist on disk after a first run.
  if not persisted then
    M.save(cfg)
  end
end

function M._commit(cfg, buf)
  if not vim.api.nvim_buf_is_valid(buf) then return end
  local names = parse_names(vim.api.nvim_buf_get_lines(buf, 0, -1, false))
  set_from_names(cfg, names)
  ensure_default(cfg)
  -- Create any newly-referenced files so switching can open them.
  for _, path in pairs(bindings) do
    if vim.fn.filereadable(path) == 0 then
      vim.fn.writefile({}, path)
    end
  end
  M.save(cfg)
end

function M.open_manager(cfg)
  if editor_win and vim.api.nvim_win_is_valid(editor_win) then
    vim.api.nvim_set_current_win(editor_win)
    return
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = 'nofile'

  local lines = {
    '# Jot slots — one filename per line, line N = slot N (up to ' .. MAX_SLOTS .. ')',
    '# Lines starting with # are ignored. Blank line = slot unassigned.',
    '# q or :q to apply and save.',
    '',
  }
  for i = 1, MAX_SLOTS do
    local path = bindings[i]
    lines[#lines + 1] = path and vim.fn.fnamemodify(path, ':t') or ''
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  local ui     = vim.api.nvim_list_uis()[1]
  local ui_w   = ui and ui.width  or vim.o.columns
  local ui_h   = ui and ui.height or vim.o.lines
  local width  = math.floor(ui_w * cfg.window.width)
  local height = math.floor(ui_h * cfg.window.height)
  local row    = math.floor((ui_h - height) / 2)
  local col    = math.floor((ui_w - width)  / 2)

  local win = vim.api.nvim_open_win(buf, true, {
    relative  = 'editor',
    width     = width,
    height    = height,
    row       = row,
    col       = col,
    style     = 'minimal',
    border    = cfg.window.border,
    title     = ' Jot Slots ',
    title_pos = 'center',
  })
  editor_win = win
  vim.wo[win].winhighlight   = 'Normal:Normal,FloatBorder:Normal,FloatTitle:Normal'
  vim.wo[win].relativenumber = false
  vim.wo[win].number         = false

  -- Commit when the window closes (any method: q, :q, ZZ, nvim_win_close)
  vim.api.nvim_create_autocmd('WinClosed', {
    group   = vim.api.nvim_create_augroup('JotSlotEditor', { clear = true }),
    pattern = tostring(win),
    once    = true,
    callback = function()
      M._commit(cfg, buf)
      editor_win = nil
      vim.schedule(function()
        if vim.api.nvim_buf_is_valid(buf) then
          vim.api.nvim_buf_delete(buf, { force = true })
        end
      end)
    end,
  })

  vim.keymap.set('n', 'q', function()
    vim.api.nvim_win_close(win, true)
  end, { buffer = buf, nowait = true })
end

return M
