Feature: Quick-access notes with slot hotkeys
  As a Neovim user
  I want to toggle a single notes window and switch between assigned notes
  So that I can jump to any of my notes without leaving the window

  Background:
    Given jot is set up with dir "<data>/jot"

  Scenario: Assignments persist across sessions
    Given slot 1 is assigned "todo.md" and slot 2 is assigned "scratch.md"
    When jot reloads
    Then slot 1 resolves to "todo.md"
    And slot 2 resolves to "scratch.md"

  Scenario: First run seeds slots from config and writes slots.json
    Given no slots.json exists
    And the config seeds slots { "one.md", "two.md" }
    When jot loads
    Then slots.json exists
    And slot 1 resolves to "one.md"

  Scenario: Toggle opens the last-viewed note
    Given slot 1 is assigned "one.md" and slot 2 is assigned "two.md"
    And the window is open on slot 2
    When I close the window
    And I toggle the window
    Then the window shows "two.md"

  Scenario: Switching swaps the buffer in place and autosaves
    Given slot 1 is assigned "one.md" and slot 2 is assigned "two.md"
    And the window is open on slot 1 with unsaved text "hello"
    When I press the slot-2 hotkey
    Then the same window now shows "two.md"
    And "one.md" on disk contains "hello"

  Scenario: Switch keys are buffer-local to the jot window
    Given the window is open
    When I inspect a normal (non-jot) buffer
    Then the slot hotkeys are not mapped there

  Scenario: Slot 1 always has a default note so jot is reachable
    Given no slots.json exists
    And the config seeds no slots
    When jot loads
    Then slot 1 resolves to "jot.md"
    And toggling the window opens "jot.md"

  Scenario: Clearing slot 1 in the manager restores the default
    Given slot 1 is assigned "a.md"
    When the manager commits an empty slot 1
    Then slot 1 resolves to "jot.md"

  Scenario: Switching to an unassigned slot is a no-op
    Given slot 1 is assigned "one.md"
    And the window is open on slot 1
    When I press an unassigned slot hotkey
    Then the window still shows "one.md"
