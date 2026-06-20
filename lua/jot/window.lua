local M = {}

local state = {
  buf_id = nil,
  win_id = nil,
}

local function get_or_create_buf()
  local cfg = require('jot.config').get()

  if state.buf_id and vim.api.nvim_buf_is_valid(state.buf_id) then
    return state.buf_id
  end

  if vim.fn.filereadable(cfg.path) == 0 then
    vim.fn.writefile({}, cfg.path)
  end

  state.buf_id = vim.fn.bufadd(cfg.path)
  vim.bo[state.buf_id].buflisted = false
  vim.bo[state.buf_id].filetype  = 'markdown'
  vim.api.nvim_buf_call(state.buf_id, function()
    vim.cmd('silent! %d | read ' .. cfg.path)
  end)

  return state.buf_id
end

local function open_floating(buf_id, cfg)
  local ui     = vim.api.nvim_list_uis()[1]
  local width  = math.floor(ui.width  * cfg.window.width)
  local height = math.floor(ui.height * cfg.window.height)
  local row    = math.floor((ui.height - height) / 2)
  local col    = math.floor((ui.width  - width)  / 2)

  state.win_id = vim.api.nvim_open_win(buf_id, true, {
    relative = 'editor',
    width    = width,
    height   = height,
    row      = row,
    col      = col,
    style    = 'minimal',
    border   = cfg.window.border,
  })
end

local function open_split(buf_id, cfg)
  local width = math.floor(vim.o.columns * cfg.window.split_width)
  local cmd   = cfg.window.style == 'left' and 'topleft' or 'botright'
  vim.cmd(cmd .. ' vsplit')
  state.win_id = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(state.win_id, buf_id)
  vim.api.nvim_win_set_width(state.win_id, width)
end

function M.open()
  local cfg    = require('jot.config').get()
  local buf_id = get_or_create_buf()

  if cfg.window.style == 'floating' then
    open_floating(buf_id, cfg)
    -- inherit editor colors so Visual highlight remains visible
    vim.wo[state.win_id].winhighlight = 'Normal:Normal,FloatBorder:Normal'
  else
    open_split(buf_id, cfg)
  end

  vim.wo[state.win_id].number = true
end

function M.close()
  if state.buf_id and vim.api.nvim_buf_is_valid(state.buf_id) then
    vim.api.nvim_buf_call(state.buf_id, function()
      vim.cmd('silent! write')
    end)
  end
  if state.win_id and vim.api.nvim_win_is_valid(state.win_id) then
    pcall(vim.api.nvim_win_close, state.win_id, true)
  end
  state.win_id = nil
end

function M.toggle()
  if state.win_id and vim.api.nvim_win_is_valid(state.win_id) then
    M.close()
  else
    M.open()
  end
end

return M