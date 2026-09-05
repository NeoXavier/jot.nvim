local M = {}

local config = require('jot.config')

function M.setup(user_opts)
  config.apply(user_opts or {})
  local cfg   = config.get()
  local slots = require('jot.slots')

  slots.ensure_dir(cfg)
  slots.load(cfg)

  local toggle_key = cfg.keymaps.toggle
  if toggle_key and toggle_key ~= false then
    vim.keymap.set('n', toggle_key, function()
      require('jot.window').toggle(cfg)
    end, { desc = 'Toggle Jot window' })
  end
end

function M.toggle()
  require('jot.window').toggle(config.get())
end

function M.switch(slot)
  require('jot.window').switch(config.get(), slot)
end

function M.open_manager()
  require('jot.slots').open_manager(config.get())
end

return M
