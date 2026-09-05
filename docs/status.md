# Project Status

## Current Sprint — Slots redesign

### Completed
- [x] Story: `<leader>t` toggles a single jot window (open/close)
- [x] Story: Notes live in one directory (`stdpath('data')/jot`)
- [x] Story: Slot manager UI (`<leader>e`) to assign notes to slots 1..9
- [x] Story: Assignments persisted to `slots.json` (survive restarts)
- [x] Story: Config `slots` seeds the first run only
- [x] Story: Buffer-local `<leader>1..9` switch notes in place (autosave on switch)
- [x] Story: Switch hotkeys do NOT fire outside the jot window (buffer-local)
- [x] Story: `<leader>t` reopens the last-viewed note (slot 1 on fresh session)
- [x] Story: Unassigned slot hotkey warns and is a no-op
- [x] Story: Autosave on switch and on close (`q`, `:q`, and window map)
- [x] Story: On close, all generated jot buffers are saved then deleted (no
      lingering buffers in the buffer list)
- [x] Story: Slot 1 falls back to `cfg.default_note` (`jot.md`) so jot is never
      locked out when nothing is assigned (fixes empty-slot-1 chicken-and-egg)

### Docs
- [x] `docs/technical.md` rewritten for the slot/manager model
- [x] `docs/architecture.mermaid` updated (slots store + buffer swap)
- [x] BDD scenarios (`tests/features/slots.feature`)
- [x] plenary busted spec (`tests/spec/slots_spec.lua`) — 9/9 passing

## Verification
- plenary: `nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedFile tests/spec/slots_spec.lua"` → 8 pass
- Geometry now falls back to `vim.o.columns/lines` when no UI is attached (headless-safe)
- luacheck: not installed in this environment — run `luacheck lua/ plugin/` before committing

## Blockers
- none

## Notes
- Local dev wiring: use `lazy.nvim` with `dir = '~/projects/jot.nvim'`
- Hot-reload: `:lua require('plenary.reload').reload_module('jot')`
- `current_slot` (last-viewed) is session-scoped; persisting it across sessions is future work
