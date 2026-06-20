# Project Intelligence — tasks.nvim

## Tech Stack

- **Language:** Lua (Neovim native, no external dependencies)
- **Runtime:** Neovim 0.8+ (`nvim_open_win`, `vim.api.*`, `vim.fn.*`)
- **Entry point:** `plugin/tasks.lua` (auto-loaded by Neovim)
- **Public API:** `lua/tasks/init.lua`

## Project Overview

`tasks.nvim` is a lightweight Neovim plugin providing a persistent, toggleable
Markdown scratchpad. A single keymap (`<leader>t`) opens a floating or split
window onto a `tasks.md` file stored in `vim.fn.stdpath('data')`. The buffer
is auto-saved on close. No external dependencies required.

## Required Reading on Startup

Before making any changes, read:
- `docs/architecture.mermaid` — Module graph and data flow
- `docs/technical.md` — Full technical specification (config schema, API, behaviour table)
- `tasks/tasks.md` — MVP stories with acceptance criteria and task checklist
- `docs/status.md` — Current sprint progress and blockers

## File Structure

```
tasks.nvim/
├── lua/tasks/
│   ├── init.lua      # setup(), toggle() — public API
│   ├── window.lua    # open/close/toggle + window state
│   └── config.lua    # defaults + vim.tbl_deep_extend merge
├── plugin/
│   └── tasks.lua     # auto-loaded guard + entrypoint
├── docs/
│   ├── technical.md
│   ├── architecture.mermaid
│   └── status.md
└── tasks/
    └── tasks.md
```

## Code Style

- **Module pattern:** Use `local M = {}` … `return M` in every module.
- **No globals:** Never set globals. Use `vim.g.loaded_tasks` only for the load guard in `plugin/tasks.lua`.
- **Config access:** All modules read config via `require('tasks.config').get()` — never pass config as function arguments across modules.
- **State:** Window state (`win_id`, `buf_id`) lives only in `window.lua`. No other module touches it.
- **Error handling:** Use `pcall` around any `vim.api` calls that could fail if a window/buffer handle is stale. Do not surface errors to the user for expected conditions (e.g. closing an already-closed window).
- **Neovim API preference:** Prefer `vim.api.*` over Vimscript (`vim.cmd`) where an equivalent API exists. Use `vim.cmd('silent! write')` for buffer writes (no equivalent pure API).
- **Naming:** `snake_case` for all Lua identifiers. Module files are also `snake_case`.
- **Comments:** Comment the *why*, not the *what*. API calls are self-documenting.

## Key Implementation Details

Refer to `docs/technical.md` for the full spec. Critical points:

1. **Toggle check:** `vim.api.nvim_win_is_valid(state.win_id)` — always validate before operating on a handle.
2. **Buffer reuse:** Create the buffer once (`vim.fn.bufadd`), reuse it across opens. Do not create a new buffer on each `open()`.
3. **File creation:** Check `vim.fn.filereadable(path) == 0` on first open; create with `vim.fn.writefile({}, path)`.
4. **Floating geometry:** Width/height are proportions (0–1) multiplied against `vim.api.nvim_list_uis()[1]` dimensions.
5. **Split geometry:** Width proportion multiplied against `vim.o.columns`.
6. **Filetype:** Set `vim.bo[buf_id].filetype = 'markdown'` after buffer creation.

## File Change Protocol

After any code change:
1. Check `docs/architecture.mermaid` — confirm the change doesn't violate module boundaries (e.g. window state leaking into `init.lua`).
2. Update `docs/status.md` — mark the relevant story task complete or note blockers.
3. Validate against `docs/technical.md` — especially the behaviour table and config schema.
4. Tick off the task checkbox in `tasks/tasks.md`.

## Testing

No test framework for MVP. Manual testing approach:
- Wire plugin via `lazy.nvim` `dir =` spec pointing at local repo path.
- Hot-reload with `:lua require('plenary.reload').reload_module('tasks')` (requires plenary).
- Or restart Neovim after changes.
- Verify each acceptance criterion in `tasks/tasks.md` by hand.
