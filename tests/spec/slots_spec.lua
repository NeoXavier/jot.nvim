-- Plenary busted spec for jot.nvim slot behaviour.
-- Run: nvim --headless -c "PlenaryBustedFile tests/spec/slots_spec.lua"

local function reset_modules()
  for _, m in ipairs({ 'jot', 'jot.config', 'jot.window', 'jot.slots' }) do
    package.loaded[m] = nil
  end
end

local function fresh(dir_opts)
  reset_modules()
  vim.g.mapleader = ' '
  local jot = require('jot')
  jot.setup(dir_opts)
  return jot
end

describe('jot slots', function()
  local dir

  before_each(function()
    dir = vim.fn.tempname()
    vim.fn.mkdir(dir, 'p')
  end)

  it('seeds from config and writes slots.json on first run', function()
    fresh({ dir = dir, slots = { 'one.md', 'two.md' } })
    local slots = require('jot.slots')
    assert.equals(1, vim.fn.filereadable(slots.store_path(require('jot.config').get())))
    assert.equals('one.md', vim.fn.fnamemodify(slots.get(1), ':t'))
    assert.equals('two.md', vim.fn.fnamemodify(slots.get(2), ':t'))
  end)

  it('persists assignments across reloads and ignores the config seed', function()
    fresh({ dir = dir, slots = { 'one.md', 'two.md' } })
    fresh({ dir = dir, slots = { 'ignored.md' } })
    local slots = require('jot.slots')
    assert.equals('one.md', vim.fn.fnamemodify(slots.get(1), ':t'))
    assert.equals('two.md', vim.fn.fnamemodify(slots.get(2), ':t'))
  end)

  it('commits the manager buffer position-preserving (blank = unassigned)', function()
    fresh({ dir = dir })
    local slots = require('jot.slots')
    local cfg = require('jot.config').get()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
      '# header', '', 'a.md', '', 'c.md',
    })
    slots._commit(cfg, buf)
    assert.equals('a.md', vim.fn.fnamemodify(slots.get(1), ':t'))
    assert.is_nil(slots.get(2))
    assert.equals('c.md', vim.fn.fnamemodify(slots.get(3), ':t'))
    assert.equals(1, vim.fn.filereadable(slots.get(1)))
  end)

  it('switches in place and autosaves the previous note', function()
    fresh({ dir = dir, slots = { 'one.md', 'two.md' } })
    local window = require('jot.window')
    local cfg = require('jot.config').get()

    window.toggle(cfg)
    local win = vim.api.nvim_get_current_win()
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'hello' })

    window.switch(cfg, 2)
    assert.equals(win, vim.api.nvim_get_current_win())
    assert.equals('two.md', vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ':t'))
    assert.equals('hello', vim.fn.readfile(dir .. '/one.md')[1])
  end)

  it('toggle reopens the last-viewed slot', function()
    fresh({ dir = dir, slots = { 'one.md', 'two.md' } })
    local window = require('jot.window')
    local cfg = require('jot.config').get()
    window.toggle(cfg)
    window.switch(cfg, 2)
    window.close()
    window.toggle(cfg)
    assert.equals('two.md', vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ':t'))
  end)

  it('defaults slot 1 to jot.md when nothing is assigned', function()
    fresh({ dir = dir })
    local slots = require('jot.slots')
    assert.equals('jot.md', vim.fn.fnamemodify(slots.get(1), ':t'))

    local window = require('jot.window')
    window.toggle(require('jot.config').get())
    assert.is_true(vim.api.nvim_win_is_valid(vim.api.nvim_get_current_win()))
    assert.equals('jot.md', vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ':t'))
  end)

  it('restores the default when the manager clears slot 1', function()
    fresh({ dir = dir, slots = { 'a.md' } })
    local slots = require('jot.slots')
    local cfg = require('jot.config').get()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { '' })
    slots._commit(cfg, buf)
    assert.equals('jot.md', vim.fn.fnamemodify(slots.get(1), ':t'))
  end)

  it('deletes all generated buffers on close (after saving)', function()
    fresh({ dir = dir, slots = { 'one.md', 'two.md' } })
    local window = require('jot.window')
    local cfg = require('jot.config').get()

    window.toggle(cfg)
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'edited' })
    window.switch(cfg, 2)          -- one.md now cached, two.md visible
    local one = vim.fn.bufnr(dir .. '/one.md')
    local two = vim.fn.bufnr(dir .. '/two.md')
    assert.is_true(one > 0 and vim.api.nvim_buf_is_valid(one))
    assert.is_true(two > 0 and vim.api.nvim_buf_is_valid(two))

    window.close()

    assert.is_false(vim.api.nvim_buf_is_valid(one))
    assert.is_false(vim.api.nvim_buf_is_valid(two))
    assert.equals('edited', vim.fn.readfile(dir .. '/one.md')[1])  -- saved, not lost
  end)

  it('maps switch keys buffer-local only', function()
    fresh({ dir = dir, slots = { 'one.md' } })
    local window = require('jot.window')
    local cfg = require('jot.config').get()
    local jbuf = vim.api.nvim_create_buf(false, true)
    window.attach_keymaps(cfg, jbuf)

    local function has(b, lhs)
      for _, m in ipairs(vim.api.nvim_buf_get_keymap(b, 'n')) do
        if m.lhs == lhs then return true end
      end
      return false
    end
    assert.is_true(has(jbuf, ' 1'))
    assert.is_true(has(jbuf, ' 9'))
    assert.is_false(has(vim.api.nvim_create_buf(false, true), ' 1'))
  end)
end)
