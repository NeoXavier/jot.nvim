local M = {}

local defaults = {
  dir    = vim.fn.stdpath('data') .. '/jot',
  window = {
    style       = 'floating',
    width       = 0.8,
    height      = 0.8,
    border      = 'rounded',
    split_width = 0.3,
  },
  keymaps = {
    -- Global: open/close the jot window. Set to false to disable.
    toggle        = '<leader>t',
    -- Buffer-local (only active inside the jot window):
    manager       = '<leader>e',  -- open the slot manager
    close         = 'q',          -- close the jot window
    switch_prefix = '<leader>',   -- prefix + digit 1..9 switches slots
  },
  -- Optional first-run seed: list of filenames, index = slot number.
  -- Ignored once slots.json exists on disk.
  slots = {},
  -- Slot 1 falls back to this note whenever nothing is assigned, so the jot
  -- window (and thus the slot manager) is always reachable. Set to false to
  -- opt out.
  default_note = 'jot.md',
}

local resolved = vim.deepcopy(defaults)

function M.apply(user_opts)
  resolved = vim.tbl_deep_extend('force', defaults, user_opts or {})
end

function M.get()
  return resolved
end

return M
