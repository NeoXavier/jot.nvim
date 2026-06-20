local M = {}

local defaults = {
  path = vim.fn.stdpath('data') .. '/jot.md',
  window = {
    style       = 'floating',
    width       = 0.8,
    height      = 0.8,
    border      = 'rounded',
    split_width = 0.3,
  },
  keymaps = {
    toggle = '<leader>t',
  },
}

local resolved = vim.deepcopy(defaults)

function M.apply(user_opts)
  resolved = vim.tbl_deep_extend('force', defaults, user_opts or {})
end

function M.get()
  return resolved
end

return M