-- Minimal init for running the plenary busted specs.
-- Usage:
--   nvim --headless -u tests/minimal_init.lua \
--     -c "PlenaryBustedDirectory tests/spec/ { minimal_init = 'tests/minimal_init.lua' }"
local function find_plenary()
  for _, p in ipairs(vim.fn.globpath(vim.o.packpath, 'pack/*/*/plenary.nvim', true, true)) do
    return p
  end
  for _, p in ipairs({
    vim.fn.stdpath('data') .. '/lazy/plenary.nvim',
    vim.fn.stdpath('data') .. '/site/pack/*/start/plenary.nvim',
  }) do
    local hit = vim.fn.glob(p)
    if hit ~= '' then return hit end
  end
  return nil
end

vim.opt.runtimepath:prepend(vim.fn.getcwd())
local plenary = find_plenary()
if plenary then
  vim.opt.runtimepath:append(plenary)
  vim.cmd('runtime! plugin/plenary.vim')
end
