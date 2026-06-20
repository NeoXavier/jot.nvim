local M = {}

local config = require('tasks.config')

function M.setup(user_opts)
  config.apply(user_opts or {})

  local toggle_key = config.get().keymaps.toggle
  if toggle_key and toggle_key ~= false then
    vim.keymap.set('n', toggle_key, function()
      require('tasks.window').toggle()
    end, { desc = 'Toggle tasks scratchpad' })
  end
end

function M.toggle()
  require('tasks.window').toggle()
end

return M