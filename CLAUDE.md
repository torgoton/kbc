# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

KBC is a Ruby on Rails 8.1 implementation of the board game **Kingdom Builder**, built as a real-time multiplayer web app.

## Common Commands

```bash
make up           # Start Valkey if needed, then start Rails server
make down         # Stop the server (kills Puma)
make tail         # Tail log files

bin/rails test                        # Run all unit tests
bin/rails test test/models/game_test.rb  # Run a single test file
bin/rails test:system                 # Run system (Capybara/Selenium) tests
bin/rails db:migrate                  # Run pending migrations
bin/rails db:test:prepare             # Prepare the test database

bin/rubocop                           # Ruby linting (RuboCop with Rails Omakase)
bin/brakeman --no-pager               # Security scan
```

**Prerequisites:** Valkey (or Redis) must be running before starting the app. In development, the DB password is set in `.env.dev.local`.

## Architecture

### Board Coordinate System

The game uses a **20×20 hex grid** divided into four 10×10 quadrants, one per board section. The quadrant layout is:
- Boards 0 and 1 occupy rows 0–9 (columns 0–9 and 10–19 respectively)
- Boards 2 and 3 occupy rows 10–19

Hex adjacency uses offset-coordinate rules: even rows and odd rows have different neighbor offsets (`BoardState::ADJACENCIES`).

### Game State

All mutable game state lives in `Game` (AR model) as JSON columns:
- `board_contents` — hash keyed by `"[row, col]"` strings, values are `{klass:, qty:}` for tiles or `{klass: "Settlement", player: order}` for settlements
- `boards` — array of `[section_id, rotation]` pairs (section_id indexes into `Boards::BoardSection::SECTIONS`)
- `deck`/`discard` — terrain card strings (`"C"`, `"D"`, `"F"`, `"G"`, `"T"`)
- `goals`, `scores`, `current_action` — JSON

Per-player state lives in `GamePlayer`: `hand` (terrain card), `supply` (settlements remaining), `tiles` (held location tiles with their source hex), `order` (turn order).

### Board Instantiation Pattern

`Game` stores state as plain JSON. The `game.instantiate` / `game.instantiate_board` method reconstructs a `Boards::Board` object from that JSON. `Boards::Board` holds a `@map` array of board section objects and a `@content` 20×20 array populated from `board_contents`. Always call `instantiate` before reading board state in game logic methods.

### Board Sections (`app/models/boards/`)

All board sections are instances of `Boards::BoardSection`. Layouts (map, silver hexes, location hexes) live in the `BoardSection::SECTIONS` array, indexed by integer id. Each section exposes `terrain_at(row, col)` and `location_hexes` (positions where tiles spawn).

### Tiles (`app/models/tiles/`)

Tile subclasses represent special-action tokens that players pick up. They are instantiated from `board_contents` by `Boards::Board`. Tiles are picked up automatically when a player builds adjacent to a location hex with remaining quantity (`apply_tile_pickup`). After a move, tiles whose source hex is no longer adjacent to any player settlement are forfeited (`apply_tile_forfeit`).

### Move History and Undo

Every game state change creates a `Move` record with `deliberate:` (player-initiated vs. consequential), `reversible:`, `action:`, `from:`, `to:`. `undo_last_move` replays moves in reverse from the most recent deliberate move. Non-reversible moves (e.g., `end_turn`) block undo.

### Real-Time Updates (Turbo Streams)

`game.broadcast_game_update` sends Turbo Stream updates over:
- `"game_#{id}"` — public channel (board, log, turn state, common resources, public player panels)
- `"game_player_#{gp.id}_private"` — private channel per player (private hand/tile info)

### Controllers and Routes

`GamesController` handles the main game flow. Key routes:
- `POST /games/:id/action` — build or move a settlement
- `POST /games/:id/end_turn` — end the current player's turn
- `POST /games/:id/select_action` — choose an optional board action type (e.g., Paddock)
- `POST /games/:id/undo_move` — undo the last deliberate move

### Authentication

Rails 8 built-in auth (BCrypt password digest, single `Session` resource). `Current.user` set per request. New users require admin approval (`approved` flag on `User`).
