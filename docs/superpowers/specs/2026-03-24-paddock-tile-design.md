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
- A newly acquired tile is marked `"used" => true` at pickup — it cannot be used the turn it is acquired.
- The tile may be used **before or after** the mandatory build action, but **not in the middle** of it. Once the first mandatory settlement is placed, no tile may be activated until all mandatory settlements are placed or the first is undone.
- **Valid destination:** exactly 2 hex-hops away, empty, and buildable terrain (`C/D/F/T/G`). Water (`W`), Mountain (`M`), Castle/Special (`S`), and Location (`L`) hexes are not valid destinations.
- Only settlements that have **at least one valid destination** are selectable when choosing which settlement to move.

---

## Tile JSON Format

All tile entries in `GamePlayer#tiles` are always Hashes:

```json
{ "klass": "PaddockTile", "from": "[r, c]", "used": true }
```

The `"used"` key is always a boolean. Tile order within the array is not significant; tiles of the same klass are interchangeable.

Every player always has a `MandatoryTile` entry representing their mandatory build action. It initializes to `"used" => true` and resets to `"used" => false` at the beginning of each turn like all other tiles. Three things distinguish it from other tiles:

1. Each player always has exactly one MandatoryTile in their collection.
2. It is the selected action at the start of each turn and immediately after any other tile is used (i.e., `current_action` returns to `{ "type" => "mandatory" }` after a paddock move completes).
3. It is never manually selectable — there is no button to activate it.

```json
{ "klass": "MandatoryTile", "used": false }
```

---

## Renaming: Mandatory → MandatoryTile

The existing `"Mandatory"` klass string in `populate_player_supplies` is renamed to `"MandatoryTile"` to be consistent with all other tile klass names (PaddockTile, TavernTile, etc.). The `_tiles.html.erb` uses `tile["klass"].delete_suffix("Tile").downcase` to produce CSS class names, so this rename produces `"mandatory"` — the same CSS output as before.

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
  → settlement moves, first unused PaddockTile marked "used" => true
  → apply_tile_forfeit runs (creates forfeit_tile Move records as needed)
  → current_action = { "type" => "mandatory" }
```

Full undo sequence: the four Move records (`select_action`, `select_settlement`, `move_settlement`, `forfeit_tile`) collapse into three undo calls, because `forfeit_tile` is non-deliberate and is bundled into the same undo step as `move_settlement`. `undo_last_move` undoes the last deliberate move plus any non-deliberate moves with higher IDs. So:

1. First undo: reverses `forfeit_tile` (non-deliberate, same batch) + `move_settlement` → `current_action = { "type" => "paddock", "from" => "..." }`
2. Second undo: reverses `select_settlement` → `current_action = { "type" => "paddock" }`
3. Third undo: reverses `select_action` → `current_action = { "type" => "mandatory" }`

After all three undos, `current_action` is back to `{ "type" => "mandatory" }` with `mandatory_count` unchanged. The existing `select_action` undo case requires no changes for Paddock.

---

## Model (`game.rb`)

### `populate_player_supplies` (updated)
Initialize each player's tiles with just the MandatoryTile, marked used:

```ruby
p.update(supply: { settlements: SETTLEMENTS_PER_PLAYER },
         tiles: [{ "klass" => "MandatoryTile", "used" => true }])
```

### `apply_tile_pickup` (updated)
Store `"used" => true` in the tile hash at pickup time — tiles cannot be used the turn they are acquired:

```ruby
{ "klass" => tile[:klass], "from" => tile[:key], "used" => true }
```

### `apply_tile_forfeit` (updated)
For each tile removed from the player's collection, increment `move_count` and create a non-deliberate, reversible `forfeit_tile` Move record before removing it:

For each forfeited tile, first resolve `klass = board_contents[tile["from"]]["klass"]` (the location entry is never deleted), then create:

- `order: move_count`
- `action: "forfeit_tile"`
- `deliberate: false`
- `reversible: true`
- `game_player: game_player`
- `from: tile["from"]` — the location key (e.g. `"[2, 8]"`)
- `to: tile["used"].to_s` — `"true"` or `"false"`, the tile's used state at time of forfeit
- `message: "#{game_player.player.handle} forfeited a #{klass.delete_suffix('Tile').downcase} tile"`

### `Game#undo_last_move` — `forfeit_tile` case (new)
Restore the tile to `move.game_player.tiles`:

```ruby
klass = board_contents[move.from]["klass"]
tiles = move.game_player.tiles || []
move.game_player.tiles = tiles + [{ "klass" => klass, "from" => move.from, "used" => move.to == "true" }]
move.game_player.save
```

### `Game#tile_activatable?(tile)`
Returns `true` when all of:
- `tile["used"] == false`
- `mandatory_count == MANDATORY_COUNT || mandatory_count <= 0 || current_player.supply["settlements"] == 0`

The third condition handles the edge case where a player has run out of settlements mid-mandatory-builds (supply = 0, mandatory_count between 0 and MANDATORY_COUNT exclusive). `turn_endable?` treats this as "mandatory complete", so tile activation should also be permitted.

### `Game#paddock_valid_destinations(from_row, from_col)`
Returns array of `[row, col]` pairs that are:
- Exactly 2 hex-hops from `(from_row, from_col)` — computed as neighbors-of-neighbors minus the origin and its immediate neighbors
- Empty in `board_contents`
- Terrain at that position (as returned by `board.terrain_at`, which returns uppercase characters) is in `%w[C D F T G]`

### `Game#paddock_selectable_settlements(player)`
Returns array of `[row, col]` pairs where:
- `board_contents` has a settlement belonging to `player`
- `paddock_valid_destinations(row, col)` is non-empty

### `Game#move_settlement` (updated)
After moving the piece, find the **first entry** in `current_player.tiles` where `tile["klass"] == "PaddockTile"` and `tile["used"] == false`, and set `"used" => true`.

### `Game#undo_last_move` — `move_settlement` case (updated)
After restoring piece position and `current_action`, find the **first entry** in `move.game_player.tiles` where `tile["klass"] == "PaddockTile"` and `tile["used"] == true`, and set `"used" => false`.

Note: `forfeit_tile` Move records have higher IDs and are processed before `move_settlement` in the reverse-order undo loop, so forfeited tiles are already restored by the time the `move_settlement` case runs.

### `Game#end_turn` (updated)
After setting `self.current_player` to the incoming player, reset all entries in that player's `tiles` array to `"used" => false`.

### `Game#turn_endable?` (updated)
Returns `true` only when the current action is the mandatory action **and** it is fully complete:

```ruby
current_action["type"] == "mandatory" &&
  (mandatory_count <= 0 || current_player.supply["settlements"] == 0)
```

Returns `false` in all paddock sub-phases.

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

### `GamesController#end_turn` (updated)
Replace the independent guard with `turn_endable?` to keep controller and model in sync:

```ruby
@game.end_turn if @game.turn_endable?
```

### `GamesController#select_action`
No changes.

---

## Views

### `_tiles.html.erb` (updated)
When `n == 0` (private player view), `tile["klass"] == "PaddockTile"`, and `game.tile_activatable?(tile)` is true, render the tile as a `button_to` posting to `select_action_game_path(game)` with `action_type: "paddock"`. Otherwise render a plain div as today.

### `_turn_state.html.erb` (updated)
Add an unconditionally rendered hidden span — always present so JS can read `.dataset` without a null check:

```html
<span id="current-action"
  data-type="<%= game.current_action&.dig('type') %>"
  data-from="<%= game.current_action&.dig('from') %>">
</span>
```

The existing `<%= game.turn_state %>` text updates automatically via the model change.

### `_quadrant.html.erb`
No changes. `selected` and `selectable` classes are applied by JavaScript. Since the board partial is re-broadcast on every `broadcast_game_update`, dynamically added CSS classes are naturally cleared on each game state update before `prepForMove()` re-applies them.

---

## JavaScript (`gameboard.js`)

### `unmarkAvailableCells()` (updated)
Also remove the `selected` class:

```js
document.querySelectorAll(".hex").forEach(c => {
  c.classList.remove("selectable");
  c.classList.remove("selected");
});
```

### `prepForMove()` (updated)
Calls `unmarkAvailableCells()` (which now clears both `selectable` and `selected`), then reads `#current-action` data attributes and branches:

- **`type == "mandatory"`** — existing `markAvailableCells()` unchanged
- **`type == "paddock"`, no `from`** — call `markSelectableSettlements()`
- **`type == "paddock"`, `from` set** — call `markPaddockDestinations(from)`

Current player number is read via the existing mechanism: `parseInt(document.querySelector(".handle .player-order").innerText)`.

### `paddockDestinations(cellId)` (new)
Computes neighbors-of-neighbors from `cellId`, removes the origin and its immediate neighbors, then filters to cells that:
- Have no `.hex-settlement` child (empty)
- Have class `terrain-c`, `terrain-d`, `terrain-f`, `terrain-t`, or `terrain-g` (buildable; CSS classes use lowercase)

Returns surviving cell IDs.

### `markSelectableSettlements()` (new)
Reads current player number from `.handle .player-order`. Finds all `.hex-settlement.player-N` elements, walks up to the containing hex div, and adds `selectable` only if `paddockDestinations(cellId)` is non-empty.

### `markPaddockDestinations(from)` (new)
Calls `paddockDestinations(from)` and adds `selectable` to each result. Adds `selected` to the `from` hex div.

### `enableClicks()` — no changes
The existing form submission (`build_cell` → `action_submit`) handles all phases. The server dispatches correctly.

---

## Tests

### Model (`game_test.rb`)

- `populate_player_supplies` — tiles initialised to `[{ "klass" => "MandatoryTile", "used" => true }]`
- `apply_tile_pickup` — tile stored with `"used" => true`
- `tile_activatable?` — true only when `tile["used"] == false` and mandatory condition met
- `paddock_valid_destinations` — correct distance-2 cells; excludes non-buildable terrain (W/M/S/L); excludes occupied cells; handles board edges
- `paddock_selectable_settlements` — excludes settlements with zero valid destinations
- `apply_tile_forfeit` — creates `forfeit_tile` Move records with correct from/to fields
- `move_settlement` — marks first PaddockTile with `"used" == false` as used; leaves others untouched
- `undo_last_move` after `move_settlement` — unmarks the first used PaddockTile on `move.game_player`
- `undo_last_move` after `move_settlement` that forfeits a tile — restores the tile to the player with its original used state
- `end_turn` — resets incoming player's tiles to `"used" => false`
- `turn_endable?` — false when `current_action["type"] == "paddock"`; false when mandatory and incomplete; true when mandatory and complete
- `turn_state` — correct string in each paddock sub-phase

### Controller (`games_controller_test.rb`)

- `POST end_turn` with incomplete mandatory action → does not call `end_turn`
- `POST end_turn` with paddock action in progress → does not call `end_turn`
- `POST action` with `current_action = { "type" => "paddock" }` (no `"from"`) → dispatches to `select_settlement`
- `POST action` with `current_action = { "type" => "paddock", "from" => "..." }` → dispatches to `move_settlement`

---

## Out of Scope

- Other tile types (Tavern, Oasis, Farm) — they follow the same pattern but have different actions; each is a separate feature.
- JS test framework — not present in this project; not added here.
- Animation for settlement movement.
