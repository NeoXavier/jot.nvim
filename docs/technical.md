# jot.nvim — Technical Specification

## Overview

`jot.nvim` is a lightweight Neovim plugin for quick-access Markdown notes. A single
global keybind (`<leader>t`) toggles one floating (or split) window. Inside that
window, buffer-local hotkeys switch between up to nine notes and open a manager to
assign notes to slots. All notes live in one directory (`stdpath('data')/jot`), and
slot assignments are persisted to `slots.json` so they survive restarts.

Key design points:
- **One window, many notes** — switching swaps the buffer *in place* (a tabbed feel).
- **Buffer-local hotkeys** — switch/manager/close keys fire only while the jot
  window is focused, never globally.
- **Persistent assignments** — the manager writes `slots.json`; config only seeds
  the very first run.
- **Autosave everywhere** — the current note is written on switch and on close.

---

## Stack

| Concern     | Choice                                          |
|-------------|-------------------------------------------------|
| Language    | Lua (Neovim native)                             |
| Neovim API  | `vim.api.*`, `vim.fn.*`, `vim.keymap.set`, `vim.json` |
| File I/O    | `vim.fn.writefile`/`readfile`, buffer `:w`      |
| Min Neovim  | 0.8+ (stable `nvim_open_win` API)               |

---

## File Structure

```
jot.nvim/
├── lua/
│   └── jot/
│       ├── init.lua      # setup(), toggle(), switch(), open_manager()
│       ├── window.lua     # single-window state, buffer swap, buffer-local keymaps
│       ├── slots.lua      # slot store, persistence (slots.json), manager UI
│       └── config.lua     # defaults + user config merging
├── plugin/
│   └── jot.lua           # auto-loaded; double-load guard only
├── docs/
│   ├── technical.md      # this file
│   ├── architecture.mermaid
│   └── status.md
├── tasks/
│   └── tasks.md
└── tests/
    ├── features/         # Gherkin scenarios
    └── spec/             # plenary busted specs
```

---

## Configuration

```lua
require('jot').setup({
  -- Directory holding all note files. Created on setup if missing.
  -- Default: vim.fn.stdpath('data') .. '/jot'
  dir = vim.fn.stdpath('data') .. '/jot',

  window = {
    style       = 'floating',  -- 'floating' | 'left' | 'right'
    width       = 0.8,         -- floating: proportion of editor width
    height      = 0.8,         -- floating: proportion of editor height
    border      = 'rounded',   -- 'rounded' | 'single' | 'double' | 'none'
    split_width = 0.3,         -- left/right split: proportion of editor width
  },

  keymaps = {
    toggle        = '<leader>t',  -- global: open/close the jot window (false to disable)
    manager       = '<leader>e',  -- buffer-local: open the slot manager
    close         = 'q',          -- buffer-local: close the window
    switch_prefix = '<leader>',   -- buffer-local: prefix + digit 1..9 switches slots
  },

  -- Optional FIRST-RUN seed only: list of filenames, index = slot number.
  -- Ignored once slots.json exists on disk (the manager is the source of truth).
  slots = {},

  -- Slot 1 falls back to this note whenever it would otherwise be unassigned,
  -- so the window (and the manager inside it) is always reachable. false = opt out.
  default_note = 'jot.md',
})
```

### Defaults (`config.lua`)

See `lua/jot/config.lua`; all fields are optional and deep-merged over defaults
with `vim.tbl_deep_extend('force', ...)`.

---

## Module Responsibilities

### `lua/jot/config.lua`
- Holds defaults; `config.apply(user_opts)` deep-merges; `config.get()` returns the
  resolved singleton.

### `lua/jot/slots.lua`
Slot store, persistence, and manager UI. Module-level `bindings` maps slot index
(1..9) → canonical absolute path.

- `slots.ensure_dir(cfg)` — `mkdir -p` the notes directory.
- `slots.store_path(cfg)` — absolute path of `slots.json`.
- `slots.load(cfg)` — read `slots.json` (JSON `{ slots = { <filename>, ... } }`);
  on first run, seed from `cfg.slots` then save so the store exists.
- `slots.save(cfg)` — write `bindings` filenames back to `slots.json`.
- `slots.resolve()` / `slots.get(slot)` — read the current bindings.
- `slots.open_manager(cfg)` — floating editor; one filename per line, **line N =
  slot N** (blank line leaves a slot unassigned). On close, `_commit` rebuilds
  bindings, creates any missing files, and saves.

### `lua/jot/window.lua`
Single active window with in-place buffer swapping.

```lua
local state = { win_id = nil, current_slot = nil }  -- current_slot = last-viewed
local bufs  = {}  -- path -> buf_id (cached across open/close)
```

- `window.open(cfg, slot)` — resolve slot → path (warn + no-op if unassigned),
  create/reuse an unlisted markdown buffer, open the float/split, set title
  `[N] filename`, and attach buffer-local keymaps.
- `window.switch(cfg, slot)` — if no window, delegates to `open`; otherwise
  autosaves the visible note and swaps the target buffer into the same window.
- `window.close()` — autosave the visible note, close the window, then save +
  delete every jot buffer and clear the cache (no jot buffers linger); retain
  `current_slot` as the session's last-viewed memory.
- `window.toggle(cfg)` — open (`current_slot or 1`) if closed, else close.
- `window.attach_keymaps(cfg, buf)` — sets **buffer-local** normal-mode maps:
  `switch_prefix .. 1..9` → `switch`, `manager` → open manager, `close` → close.
- A `WinClosed` autocmd autosaves and resets `win_id` when the window is dismissed
  via `:q` rather than the `close` map.

### `lua/jot/init.lua`
Public API: `setup(opts)` (apply config, ensure dir, load slots, register the
global toggle), plus `toggle()`, `switch(slot)`, `open_manager()`.

### `plugin/jot.lua`
Double-load guard (`vim.g.loaded_jot`) only; `setup()` is called by the user.

---

## Behaviour Details

| Scenario | Behaviour |
|---|---|
| First run, no `slots.json` | Seeded from `cfg.slots`; `slots.json` written |
| Slot 1 otherwise unassigned | Falls back to `cfg.default_note` (`jot.md`) so jot stays reachable |
| `slots.json` exists | Loaded verbatim; `cfg.slots` seed ignored |
| Note file missing on open/commit | Created as an empty file automatically |
| `<leader>t` when closed | Opens last-viewed slot (slot 1 on a fresh session) |
| `<leader>t` when open | Autosaves and closes |
| `<leader>N` inside window | Autosaves current, swaps slot N in place |
| `<leader>N` for unassigned slot | Warning notify; window unchanged |
| `<leader>N` in a non-jot buffer | Nothing — the map is buffer-local |
| Manager closed (`q`/`:q`/`ZZ`) | Assignments committed and saved to `slots.json` |
| Switch / close | Visible note written to disk (autosave) |
| Close (`q`/`:q`/toggle) | All jot buffers saved, then deleted; cache cleared |
| `keymaps.toggle = false` | No global keymap; user calls `require('jot').toggle()` |

---

## Non-Goals (current)

- Per-project note directories
- Daily notes / date scaffolding
- Note syntax parsing, checkboxes, or status-line counts
- Telescope / fzf pickers
- Multiple concurrent jot windows

---

## Future Work

- `style = 'bottom'` horizontal split
- Per-project note directories (git-root detection)
- Daily notes (`YYYY-MM-DD.md`)
- Telescope / fzf picker across the notes directory
- Persist last-viewed slot across sessions
