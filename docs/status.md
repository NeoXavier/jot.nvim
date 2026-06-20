# Project Status

## Current Sprint — MVP

### Completed
- [x] Story 1: Plugin scaffold
- [x] Story 2: Configuration (implemented alongside Story 1)
- [x] Story 3: Keymap registration (implemented alongside Story 1)
- [x] Story 4: Task file creation
- [x] Story 5: Floating window (manual treesitter verify pending)
- [x] Story 6: Split window (left/right)
- [x] Story 7: Toggle (close)
- [x] Story 8: Autosave on close (manual unmodified-buffer verify pending)

### Completed
- [x] Technical specification (`docs/technical.md`)
- [x] Architecture diagram (`docs/architecture.mermaid`)
- [x] User stories (`tasks/tasks.md`)
- [x] Project setup (`CLAUDE.md`, `.cursorrules`)

## Blockers
- none

## Notes
- Local dev wiring: use `lazy.nvim` with `dir = '~/projects/tasks.nvim'`
- Hot-reload: `:lua require('plenary.reload').reload_module('tasks')`
