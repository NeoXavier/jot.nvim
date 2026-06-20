# tasks.nvim — Technical Specification

## Overview

`tasks.nvim` is a lightweight Neovim plugin that provides a persistent, toggleable
scratchpad for task notes, written in Markdown. It is designed to be minimal,
fast, and unintrusive — a single keybind opens a floating or split window onto a
persistent Markdown file.

---

## Stack

| Concern       | Choice                                     |
|---------------|--------------------------------------------|
| Language       | Lua (Neovim native)                        |
| Neovim API    | `vim.api.*`, `vim.fn.*`, `vim.keymap.set` |
| File I/O      | Native Neovim buffer write (`:w`)         |
| Min Neovim    | 0.8+ (stable `nvim_open_win` API)         |

---

## File Structure

```
tasks.nvim/
├── lua/
│   └── tasks/
│       ├── init.lua      # setup(), toggle() — public API surface
│       ├── window.lua    # open/close/toggle window logic + state
│       └── config.lua    # default config + user config merging
├── plugin/
│   └── tasks.lua         # auto-loaded by Neovim; registers keymap
├── docs/
│   ├── technical.md      # this file
│   ├── architecture.mermaid
│   └── status.md
└── tasks/
    └── tasks.md
```

---

## Configuration

Users call `require('tasks').setup(opts)` in their Neovim config. All fields are
optional — defaults are applied for anything omitted.

### Schema

```lua
require('tasks').setup({
  -- Path to the task file. Created automatically if it does not exist.
  -- Default: vim.fn.stdpath('data') .. '/tasks.md'
  path = vim.fn.stdpath('data') .. '/tasks.md',

  window = {
    -- 'floating' | 'left' | 'right'
    -- Default: 'floating'
    style = 'floating',

    -- Floating window options (ignored when style is 'left' or 'right')
    width  = 0.8,   -- proportion of editor width
    height = 0.8,   -- proportion of editor height
    border = 'rounded', -- 'rounded' | 'single' | 'double' | 'none'

    -- Split window options (ignored when style is 'floating')
    split_width = 0.3, -- proportion of editor width
  },

  keymaps = {
    -- Set to false to disable auto-registration and wire it up manually.
    toggle = '<leader>t',
  },
})
```

### Defaults (config.lua)

```lua
local defaults = {
  path = vim.fn.stdpath('data') .. '/tasks.md',
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
```

---

## Module Responsibilities

### `lua/tasks/config.lua`

- Holds the default config table.
- Exports `config.apply(user_opts)` which deep-merges user opts over defaults
  using `vim.tbl_deep_extend('force', defaults, user_opts)`.
- Stores the resolved config as a module-level singleton accessible to other modules.

### `lua/tasks/window.lua`

Manages all window/buffer state. Exposes:

- `window.toggle()` — opens the window if not visible; closes + autosaves if visible.
- `window.open()` — creates or re-shows the buffer in a new window.
- `window.close()` — writes the buffer (`:w`) then closes the window.

**State tracking:**

```lua
local state = {
  buf_id = nil,  -- buffer handle (persists across open/close for fast re-open)
  win_id = nil,  -- window handle (nil when closed)
}
```

**Toggle logic:**

```lua
function window.toggle()
  if state.win_id and vim.api.nvim_win_is_valid(state.win_id) then
    window.close()
  else
    window.open()
  end
end
```

**Buffer creation (first open):**

```lua
-- Create file if missing
if vim.fn.filereadable(config.path) == 0 then
  vim.fn.writefile({}, config.path)
end

-- Create unlisted scratch buffer pointed at the file
state.buf_id = vim.fn.bufadd(config.path)
vim.bo[state.buf_id].buflisted = false
vim.bo[state.buf_id].filetype  = 'markdown'
vim.api.nvim_buf_call(state.buf_id, function() vim.cmd('silent! %d | read ' .. config.path) end)
```

**Subsequent opens:** buffer already exists; just open a new window onto it.

**Floating window geometry:**

```lua
local ui     = vim.api.nvim_list_uis()[1]
local width  = math.floor(ui.width  * cfg.window.width)
local height = math.floor(ui.height * cfg.window.height)
local row    = math.floor((ui.height - height) / 2)
local col    = math.floor((ui.width  - width)  / 2)

state.win_id = vim.api.nvim_open_win(state.buf_id, true, {
  relative = 'editor',
  width    = width,
  height   = height,
  row      = row,
  col      = col,
  style    = 'minimal',
  border   = cfg.window.border,
})
```

**Split window geometry (left/right):**

```lua
local width = math.floor(vim.o.columns * cfg.window.split_width)
local cmd   = cfg.window.style == 'left' and 'topleft' or 'botright'
vim.cmd(cmd .. ' vsplit')
state.win_id = vim.api.nvim_get_current_win()
vim.api.nvim_win_set_buf(state.win_id, state.buf_id)
vim.api.nvim_win_set_width(state.win_id, width)
```

**Autosave on close:**

```lua
function window.close()
  if state.buf_id and vim.api.nvim_buf_is_valid(state.buf_id) then
    vim.api.nvim_buf_call(state.buf_id, function()
      vim.cmd('silent! write')
    end)
  end
  if state.win_id and vim.api.nvim_win_is_valid(state.win_id) then
    vim.api.nvim_win_close(state.win_id, true)
  end
  state.win_id = nil
end
```

### `lua/tasks/init.lua`

Public API:

```lua
local M = {}

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
```

### `plugin/tasks.lua`

Auto-loaded by Neovim on startup. Kept intentionally minimal — only guards against
double-load:

```lua
if vim.g.loaded_tasks then return end
vim.g.loaded_tasks = true
-- setup() is called by the user in their config, not here.
```

---

## Behaviour Details

| Scenario | Behaviour |
|---|---|
| File does not exist on first open | Created as empty file automatically |
| Window closed via `:q` or `:bd` | Buffer may be deleted; state resets on next toggle |
| Multiple nvim instances | Last-write-wins on `tasks.md`; no file locking |
| `setup()` not called | Plugin loads but no keymap is registered |
| `keymaps.toggle = false` | No keymap auto-registered; user calls `require('tasks').toggle()` manually |
| Buffer already loaded | Re-uses existing buffer handle; no duplicate reads |

---

## Non-Goals (MVP)

- Project-specific task files
- Daily task lists
- Task syntax / parsing (just raw Markdown)
- Telescope / fzf integration
- Task completion tracking / checkboxes
- Multiple concurrent scratchpad windows

---

## Future Work

- `style = 'bottom'` horizontal split
- Per-project task files (detect git root, store `.tasks.md` in repo)
- Daily notes (`YYYY-MM-DD.md` in a notes directory)
- Telescope picker across all task files
- Optional status line component showing task count
