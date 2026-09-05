# jot.nvim

A lightweight Neovim plugin for quick-access Markdown notes. One keybind
(`<leader>t`) toggles a single floating (or split) window; inside it, buffer-local
hotkeys switch between up to nine notes and open a manager to assign them. All
notes live in one directory and slot assignments persist across restarts.

## Highlights

- **One window, many notes** — switching swaps the buffer *in place* (a tabbed feel).
- **Buffer-local hotkeys** — the switch/manager/close keys fire *only* while the jot
  window is focused, never globally.
- **Persistent slots** — a manager UI writes assignments to `slots.json`; they
  survive restarts.
- **Autosave everywhere** — notes are written on switch and on close. Closing also
  cleans up the buffers it created.
- **Never locked out** — slot 1 always falls back to a default note, so the window
  (and the manager inside it) is always reachable.

## Requirements

- Neovim 0.8+

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  'NeoXavier/jot.nvim',
  lazy = false,
  config = function()
    require('jot').setup()
  end,
}
```

## Usage

Press `<leader>t` to toggle the jot window. On a fresh session it opens slot 1;
after that it reopens the **last-viewed** note.

Inside the jot window (these keys are buffer-local — they do nothing elsewhere):

| Key            | Action                                             |
|----------------|----------------------------------------------------|
| `<leader>1`–`<leader>9` | Autosave the current note, swap in slot N |
| `<leader>e`    | Open the slot manager                              |
| `q`            | Autosave and close the window                      |

The current note is saved automatically when you switch slots and when you close
the window. On close, jot also deletes the buffers it created so none linger in
your buffer list.

### Assigning notes to slots

Press `<leader>e` inside the jot window to open the manager. It's a plain buffer,
**one filename per line, where line N = slot N**:

```
# Jot slots — one filename per line, line N = slot N (up to 9)
# Lines starting with # are ignored. Blank line = slot unassigned.
# q or :q to apply and save.

jot.md
todo.md

ideas.md
```

In the example above, slot 1 = `jot.md`, slot 2 = `todo.md`, slot 3 is unassigned
(blank line), slot 4 = `ideas.md`. Press `q` (or `:q`) to apply: missing files are
created, assignments are rebuilt, and everything is saved to `slots.json`.

### Public API

```lua
require('jot').toggle()          -- open/close the jot window
require('jot').switch(n)         -- switch to slot n (opens the window if closed)
require('jot').open_manager()    -- open the slot manager
```

## Configuration

All fields are optional. This shows the defaults:

```lua
require('jot').setup({
  -- Directory holding all note files (and slots.json). Created if missing.
  dir = vim.fn.stdpath('data') .. '/jot',

  window = {
    style       = 'floating', -- 'floating' | 'left' | 'right'
    width       = 0.8,        -- proportion of editor width (floating only)
    height      = 0.8,        -- proportion of editor height (floating only)
    border      = 'rounded',  -- 'rounded' | 'single' | 'double' | 'none'
    split_width = 0.3,        -- proportion of editor width (split only)
  },

  keymaps = {
    toggle        = '<leader>t', -- global: open/close (false to disable)
    manager       = '<leader>e', -- buffer-local: open the slot manager
    close         = 'q',         -- buffer-local: close the window
    switch_prefix = '<leader>',  -- buffer-local: prefix + digit 1..9 switches slots
  },

  -- Optional FIRST-RUN seed only: list of filenames, index = slot number.
  -- Ignored once slots.json exists (the manager is then the source of truth).
  slots = {},

  -- Slot 1 falls back to this note whenever it would otherwise be unassigned,
  -- so the window is always reachable. Set to false to opt out.
  default_note = 'jot.md',
})
```

### Seeding slots from config

`slots` is a convenience for the very first run — after that, `slots.json` (written
by the manager) takes over and the config seed is ignored:

```lua
require('jot').setup({
  slots = { 'jot.md', 'todo.md', 'ideas.md' }, -- slot 1, 2, 3
})
```

### Disable the default keymap

```lua
require('jot').setup({
  keymaps = { toggle = false },
})

-- Wire it up yourself
vim.keymap.set('n', '<your-key>', require('jot').toggle)
```

## How persistence works

- **Slot assignments** persist to `<dir>/slots.json` and survive restarts.
- **Last-viewed slot** is session-scoped (in memory), so the first `<leader>t`
  after restarting Neovim opens slot 1.

## Notes / limitations

- One jot window at a time (no concurrent jot windows).
- Notes all live in a single directory (no per-project note dirs yet).
