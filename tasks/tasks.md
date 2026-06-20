# tasks.nvim — Stories & Tasks

## MVP

### Story 1: Plugin scaffold
**As a developer**, I want the plugin directory structure in place so that Neovim
can load it and I can begin wiring up functionality.

Tasks:
- [x] Create `plugin/tasks.lua` (guard + entrypoint)
- [x] Create `lua/tasks/init.lua` (public API stub)
- [x] Create `lua/tasks/config.lua` (defaults + merge)
- [x] Create `lua/tasks/window.lua` (state + stub functions)
- [x] Wire plugin into local Neovim via `lazy.nvim` `dir =` spec
- [x] Verify `require('tasks')` loads without error

---

### Story 2: Configuration
**As a user**, I want to call `require('tasks').setup({})` with optional overrides
so that I can customise the file path and window style without forking the plugin.

Acceptance criteria:
- Calling `setup()` with no args applies all defaults
- Calling `setup({ path = '~/my-tasks.md' })` overrides only path
- Invalid/unknown keys are silently ignored (no error on extra keys)
- Config is accessible to all modules after `setup()` is called

Tasks:
- [x] Implement `config.apply(user_opts)` using `vim.tbl_deep_extend`
- [x] Expose `config.get()` for other modules to read resolved config
- [x] Write manual test: call setup with partial opts, print resolved config

---

### Story 3: Keymap registration
**As a user**, I want `<leader>t` registered automatically after `setup()` so that
I don't need to add a `vim.keymap.set` call myself.

Acceptance criteria:
- `<leader>t` is registered in normal mode after `setup()`
- Setting `keymaps.toggle = false` skips auto-registration
- Keymap description reads `'Toggle tasks scratchpad'`

Tasks:
- [x] Register keymap in `init.lua` `setup()` after config is resolved
- [x] Guard against registration when `keymaps.toggle == false`

---

### Story 4: Task file creation
**As a user**, I want the task file created automatically on first open so that I
don't need to create it myself.

Acceptance criteria:
- If `tasks.md` does not exist, it is created as an empty file on first `toggle()`
- File is created at the configured path (default: `stdpath('data')/tasks.md`)
- No error is shown to the user

Tasks:
- [x] Check `vim.fn.filereadable(path)` in `window.open()`
- [x] Create file with `vim.fn.writefile({}, path)` if missing

---

### Story 5: Floating window
**As a user**, I want `<leader>t` to open a centered floating window (80% × 80%,
rounded border) showing my `tasks.md` so that I can view and edit my tasks without
leaving my current buffer.

Acceptance criteria:
- Window opens centered on the editor
- Width is 80% of editor width, height is 80% of editor height
- Border style is `rounded`
- Buffer filetype is `markdown`
- Cursor is placed in the window on open

Tasks:
- [x] Implement `window.open()` floating path using `nvim_open_win`
- [x] Set `filetype = 'markdown'` on the buffer
- [x] Verify treesitter/syntax highlighting works in the float

---

### Story 6: Split window (left/right)
**As a user**, I want the option to open my task list as a left or right split
(30% width) instead of a float, so that I can keep tasks visible while I work.

Acceptance criteria:
- `window.style = 'left'` opens a `topleft vsplit` at 30% width
- `window.style = 'right'` opens a `botright vsplit` at 30% width
- Same buffer and filetype as floating path

Tasks:
- [x] Implement `window.open()` split path
- [x] Ensure split width calculation uses `vim.o.columns`

---

### Story 7: Toggle (close)
**As a user**, I want pressing `<leader>t` again to close the task window so that
I can quickly dismiss it and return to my work.

Acceptance criteria:
- Pressing `<leader>t` while the window is open closes it
- Window state (`win_id`) is cleared on close
- Buffer remains loaded in the background (not wiped)

Tasks:
- [x] Implement `window.toggle()` checking `nvim_win_is_valid(win_id)`
- [x] Implement `window.close()` that closes the window without wiping the buffer

---

### Story 8: Autosave on close
**As a user**, I want my tasks automatically saved when I close the window so that
I never lose changes by forgetting to `:w`.

Acceptance criteria:
- Closing via `<leader>t` always writes the buffer before closing the window
- No "unsaved changes" prompt
- Works even if the buffer has no changes (silent no-op write)

Tasks:
- [x] Call `vim.cmd('silent! write')` inside `window.close()` before `nvim_win_close`
- [x] Verify behaviour when buffer is unmodified (should not error)

---

## Post-MVP Backlog

- [ ] **Per-project tasks** — detect git root, use `.tasks.md` in repo directory
- [ ] **Daily notes** — open/create `YYYY-MM-DD.md` in a configurable notes dir
- [ ] **Bottom split** — `style = 'bottom'` horizontal split option
- [ ] **Telescope picker** — browse all task files with preview
- [ ] **Status line component** — show open checkbox count in lualine/statusline
- [ ] **Custom window title** — show filename or "Tasks" in float title bar
