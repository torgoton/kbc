# Paddock Tile — Design Spec

**Date:** 2026-03-24
**Status:** Approved

---

## Overview

The Paddock tile gives a player one extra action per turn: move one of their settlements exactly 2 hex fields to any empty, buildable hex. This spec covers the full implementation from model through controller, views, and JavaScript.

---

## Game Rules

- A player may hold multiple Paddock tiles (up to 2, one per location hex on the Paddock board).
- Each Paddock tile may be used **once per turn**.
- Tiles reset to unused at the **beginning of the incoming player's turn** (i.e., during `end_turn` when the next player is set).
- The tile may be used **before or after** the mandatory build action, but **not in the middle** of it. Once the first mandatory settlement is placed, no tile may be activated until all mandatory settlements are placed or the first is undone.
- **Valid destination:** exactly 2 hex-hops away, empty, and buildable terrain (`C/D/F/T/G`). Water (`W`), Mountain (`M`), Castle/Special (`S`), and Location (`L`) hexes are not valid destinations.
- Only settlements that have **at least one valid destination** are selectable when choosing which settlement to move.

---

## Flow

```
Player clicks Paddock tile (button_to select_action "paddock")
  → current_action = { "type" => "paddock" }
  → turn_state: "{handle} must move a settlement"

Player clicks a selectable settlement on the board (submits action form)
  → controller dispatches to select_settlement(row, col)
  → current_action = { "type" => "paddock", "from" => "[r, c]" }
  → that hex gets class "selected"
  → turn_state: "{handle} must move a settlement" (unchanged)

Player clicks a selectable destination hex (submits action form)
  → controller dispatches to move_settlement(row, col)
  → settlement moves, first unused PaddockTile marked "used"
  → apply_tile_forfeit runs
  → current_action = { "type" => "mandatory" }
```

Undo reverses each deliberate step individually.

---

## Model (`game.rb`)

### `Game#tile_activatable?(tile)`
Returns `true` when:
- `!tile["used"]`
- `mandatory_count == MANDATORY_COUNT || mandatory_count == 0`

### `Game#paddock_valid_destinations(from_row, from_col)`
Returns array of `[row, col]` pairs that are:
- Exactly 2 hex-hops from `(from_row, from_col)` — computed as neighbors-of-neighbors minus the origin and its immediate neighbors
- Empty in `board_contents`
- Terrain at that position is in `%w[c d f t g]`

### `Game#paddock_selectable_settlements(player)`
Returns array of `[row, col]` pairs where:
- `board_contents` has a settlement belonging to `player`
- `paddock_valid_destinations(row, col)` is non-empty

### `Game#move_settlement` (updated)
After moving the piece, find the **first unused** PaddockTile entry in `current_player.tiles` and set `"used" => true`.

### `Game#undo_last_move` — `move_settlement` case (updated)
After restoring piece position and `current_action`, find the **first used** PaddockTile in the game player's tiles and set `"used" => false`.

### `Game#end_turn` (updated)
After setting `self.current_player` to the incoming player, reset all entries in that player's `tiles` array to `"used" => false`.

### `Game#turn_state` (updated)
Add cases for paddock phases:
- `current_action["type"] == "paddock"` (regardless of whether `"from"` is set) → `"#{current_player.player.handle} must move a settlement"`

---

## Controller (`games_controller.rb`)

### `GamesController#action` (updated)
Dispatch based on `current_action` after extracting row/col from `build_cell`:

```
"mandatory"               → build_settlement(row, col)
"paddock", no "from"      → select_settlement(row, col)
"paddock", "from" set     → move_settlement(row, col)
```

No new routes are needed.

### `GamesController#select_action`
No changes.

---

## Views

### `_tiles.html.erb` (updated)
When `n == 0` (private player view) and `game.tile_activatable?(tile)` is true, render the tile as a `button_to` posting to `select_action_game_path(game)` with `action_type:` set to the tile type. Otherwise render a plain div as today.

### `_turn_state.html.erb` (updated)
Add a hidden span to expose game phase to JavaScript:

```html
<span id="current-action"
  data-type="<%= game.current_action&.dig('type') %>"
  data-from="<%= game.current_action&.dig('from') %>">
</span>
```

The existing `<%= game.turn_state %>` text updates automatically via the model change.

### `_quadrant.html.erb`
No changes. `selected` and `selectable` classes are applied by JavaScript.

---

## JavaScript (`gameboard.js`)

### `prepForMove()` (updated)
Clears `selectable` and `selected` classes, then reads `#current-action` data attributes and branches:

- **`type == "mandatory"`** — existing `markAvailableCells()` unchanged
- **`type == "paddock"`, no `from`** — call `markSelectableSettlements()`
- **`type == "paddock"`, `from` set** — call `markPaddockDestinations(from)`, add `selected` to the `from` hex

### `paddockDestinations(cellId)` (new)
Computes neighbors-of-neighbors from `cellId`, removes the origin and its immediate neighbors, then filters to cells that:
- Have no `.hex-settlement` child (empty)
- Have class `terrain-c`, `terrain-d`, `terrain-f`, `terrain-t`, or `terrain-g` (buildable)

Returns surviving cell IDs.

### `markSelectableSettlements()` (new)
Finds all `.hex-settlement.player-N` elements (current player's settlements), walks up to the containing hex div, and adds `selectable` only if `paddockDestinations(cellId)` is non-empty.

### `markPaddockDestinations(from)` (new)
Calls `paddockDestinations(from)` and adds `selectable` to each result. Adds `selected` to the `from` hex div.

### `enableClicks()` — no changes
The existing form submission (`build_cell` → `action_submit`) handles all phases. The server dispatches correctly.

---

## Tests

### Model (`game_test.rb`)

- `tile_activatable?` — true/false across all combinations of `used`, `mandatory_count` (full, partial, zero)
- `paddock_valid_destinations` — correct distance-2 cells; excludes non-buildable terrain; excludes occupied cells; handles board edges
- `paddock_selectable_settlements` — excludes settlements with zero valid destinations
- `move_settlement` — marks first unused PaddockTile as used; leaves other PaddockTiles untouched
- `undo_last_move` after `move_settlement` — unmarks the used PaddockTile
- `end_turn` — resets incoming player's tiles to `"used" => false`
- `turn_state` — correct string in each paddock sub-phase

### Controller (`games_controller_test.rb`)

- `POST action` with `current_action = { "type" => "paddock" }` (no `"from"`) → dispatches to `select_settlement`
- `POST action` with `current_action = { "type" => "paddock", "from" => "..." }` → dispatches to `move_settlement`

---

## Out of Scope

- Other tile types (Tavern, Oasis, Farm) — they follow the same pattern but have different actions; each is a separate feature.
- JS test framework — not present in this project; not added here.
- Animation for settlement movement.
