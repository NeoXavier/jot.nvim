# jot.nvim

A lightweight Neovim plugin that provides a persistent, toggleable scratchpad for notes written in Markdown. A single keybind opens a floating or split window onto a file that persists across sessions.

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

Press `<leader>t` to toggle the jot window open or closed. The file is saved automatically on close.

You can also call the toggle directly:

```lua
require('jot').toggle()
```

## Configuration

All fields are optional. This shows the defaults:

```lua
require('jot').setup({
  -- Path to the jot file. Created automatically if it does not exist.
  path = vim.fn.stdpath('data') .. '/jot.md',

  window = {
    style       = 'floating', -- 'floating' | 'left' | 'right'
    width       = 0.8,        -- proportion of editor width (floating only)
    height      = 0.8,        -- proportion of editor height (floating only)
    border      = 'rounded',  -- 'rounded' | 'single' | 'double' | 'none'
    split_width = 0.3,        -- proportion of editor width (split only)
  },

  keymaps = {
    toggle = '<leader>t', -- set to false to disable auto-registration
  },
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