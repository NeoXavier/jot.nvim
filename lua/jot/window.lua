local M = {}

local MAX_SLOTS = 9

-- Single active jot window; buffers cached per path for fast re-open.
local state = { win_id = nil, current_slot = nil }
local bufs  = {}  -- canonical absolute path -> buf_id

local function get_or_create_buf(cfg, path)
  local buf = bufs[path]
  if buf and vim.api.nvim_buf_is_valid(buf) then
    return buf
  end

  if vim.fn.filereadable(path) == 0 then
    vim.fn.writefile({}, path)
  end

  buf = vim.fn.bufadd(path)
  vim.bo[buf].buflisted = false
  vim.bo[buf].filetype  = 'markdown'
  vim.fn.bufload(buf)

  bufs[path] = buf
  M.attach_keymaps(cfg, buf)
  return buf
end

local function title_for(slot, path)
  return string.format(' [%d] %s ', slot, vim.fn.fnamemodify(path, ':t'))
end

local function save_current()
  if not (state.win_id and vim.api.nvim_win_is_valid(state.win_id)) then
    return
  end
  local buf = vim.api.nvim_win_get_buf(state.win_id)
  if vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_call(buf, function()
      vim.cmd('silent! write')
    end)
  end
end

-- Save any unsaved edits, then delete every buffer jot created and drop the
-- cache, so closing the window leaves no jot buffers behind.
local function delete_bufs()
  for path, buf in pairs(bufs) do
    if vim.api.nvim_buf_is_valid(buf) then
      if vim.bo[buf].modified then
        vim.api.nvim_buf_call(buf, function() vim.cmd('silent! write') end)
      end
      pcall(vim.api.nvim_buf_delete, buf, { force = true })
    end
    bufs[path] = nil
  end
end

-- Editor dimensions, preferring the attached UI but falling back to option
-- values so the geometry is valid even with no UI (e.g. headless).
local function editor_size()
  local ui = vim.api.nvim_list_uis()[1]
  if ui then return ui.width, ui.height end
  return vim.o.columns, vim.o.lines
end

local function open_floating(cfg, buf, slot, path)
  local ui_w, ui_h = editor_size()
  local width  = math.floor(ui_w * cfg.window.width)
  local height = math.floor(ui_h * cfg.window.height)
  local row    = math.floor((ui_h - height) / 2)
  local col    = math.floor((ui_w - width)  / 2)

  return vim.api.nvim_open_win(buf, true, {
    relative  = 'editor',
    width     = width,
    height    = height,
    row       = row,
    col       = col,
    style     = 'minimal',
    border    = cfg.window.border,
    title     = title_for(slot, path),
    title_pos = 'center',
  })
end

local function open_split(cfg, buf)
  local width = math.floor(vim.o.columns * cfg.window.split_width)
  local cmd   = cfg.window.style == 'left' and 'topleft' or 'botright'
  vim.cmd(cmd .. ' vsplit')
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, buf)
  vim.api.nvim_win_set_width(win, width)
  return win
end

-- Set buffer-local maps so the switch/manager/close keys fire ONLY while a
-- jot note buffer is focused, never globally.
function M.attach_keymaps(cfg, buf)
  local km = cfg.keymaps

  for i = 1, MAX_SLOTS do
    if km.switch_prefix then
      vim.keymap.set('n', km.switch_prefix .. i, function()
        M.switch(cfg, i)
      end, { buffer = buf, nowait = true, desc = 'Jot: switch to slot ' .. i })
    end
  end

  if km.manager and km.manager ~= false then
    vim.keymap.set('n', km.manager, function()
      require('jot.slots').open_manager(cfg)
    end, { buffer = buf, nowait = true, desc = 'Jot: open slot manager' })
  end

  if km.close and km.close ~= false then
    vim.keymap.set('n', km.close, function()
      M.close()
    end, { buffer = buf, nowait = true, desc = 'Jot: close window' })
  end
end

function M.open(cfg, slot)
  local path = require('jot.slots').get(slot)
  if not path then
    local hint = cfg.keymaps.manager
      and (' Press ' .. cfg.keymaps.manager .. ' inside jot to assign files.')
      or ''
    vim.notify(
      string.format('jot: slot %d has no file assigned.%s', slot, hint),
      vim.log.levels.WARN)
    return
  end

  local buf = get_or_create_buf(cfg, path)

  if cfg.window.style == 'floating' then
    state.win_id = open_floating(cfg, buf, slot, path)
    vim.wo[state.win_id].winhighlight = 'Normal:Normal,FloatBorder:Normal,FloatTitle:Normal'
  else
    state.win_id = open_split(cfg, buf)
  end
  vim.wo[state.win_id].relativenumber = true
  state.current_slot = slot

  -- Autosave + reset state if the window is dismissed via :q (not the `q` map).
  local win = state.win_id
  vim.api.nvim_create_autocmd('WinClosed', {
    group   = vim.api.nvim_create_augroup('JotWindow', { clear = true }),
    pattern = tostring(win),
    once    = true,
    callback = function()
      if state.win_id == win then state.win_id = nil end
      -- Defer buffer deletion; mutating buffers during WinClosed is unsafe.
      vim.schedule(delete_bufs)
    end,
  })
end

-- Swap the target slot's note into the existing window (autosaving first).
function M.switch(cfg, slot)
  if not (state.win_id and vim.api.nvim_win_is_valid(state.win_id)) then
    return M.open(cfg, slot)
  end

  local path = require('jot.slots').get(slot)
  if not path then
    vim.notify(string.format('jot: slot %d has no file assigned.', slot),
      vim.log.levels.WARN)
    return
  end

  save_current()
  local buf = get_or_create_buf(cfg, path)
  vim.api.nvim_win_set_buf(state.win_id, buf)
  vim.api.nvim_win_set_config(state.win_id, { title = title_for(slot, path) })
  state.current_slot = slot
end

function M.close()
  save_current()
  if state.win_id and vim.api.nvim_win_is_valid(state.win_id) then
    pcall(vim.api.nvim_win_close, state.win_id, true)
  end
  state.win_id = nil
  -- Save + delete all jot buffers so none linger after close.
  delete_bufs()
  -- current_slot is retained as the "last-viewed" memory for the session.
end

function M.toggle(cfg)
  if state.win_id and vim.api.nvim_win_is_valid(state.win_id) then
    M.close()
  else
    M.open(cfg, state.current_slot or 1)
  end
end

return M
