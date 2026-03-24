# Paddock Tile Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the Paddock Tile feature, allowing players to spend the tile to move one of their settlements exactly 2 hex-hops to an empty buildable hex.

**Architecture:** Movement logic (`valid_destinations`, `selectable_settlements`) lives on the tile class hierarchy — defined as default no-ops on `Tiles::Tile`, overridden by `Tiles::PaddockTile`. `Game` holds game-state methods (`tile_activatable?`, `turn_endable?`, etc.) and calls tile instance methods when needed. The `action` controller endpoint dispatches to model methods based on `current_action["type"]`. JS handles visual highlighting client-side. Undo is fully supported via reversible `Move` records.

**Tech Stack:** Ruby on Rails 8.1, Minitest, ERB, Vanilla JS (no framework)

---

## File Map

| File | Change |
|------|--------|
| `app/models/tiles/tile.rb` | Add default `valid_destinations` and `selectable_settlements` instance methods |
| `app/models/tiles/paddock_tile.rb` | Override both methods with Paddock-specific logic |
| `app/models/game.rb` | Update `populate_player_supplies`, `apply_tile_pickup`, `apply_tile_forfeit`, `move_settlement`, `undo_last_move`, `end_turn`, `turn_endable?`, `turn_state`; add `tile_activatable?` |
| `app/controllers/games_controller.rb` | Update `action` dispatch, update `end_turn` guard |
| `app/views/games/_tiles.html.erb` | Add activation button for PaddockTile |
| `app/views/games/_turn_state.html.erb` | Add `#current-action` span |
| `app/javascript/gameboard.js` | Update `unmarkAvailableCells`, `prepForMove`; add `paddockDestinations`, `markSelectableSettlements`, `markPaddockDestinations` |
| `test/models/tiles/paddock_tile_test.rb` | Tests for `PaddockTile#valid_destinations` and `PaddockTile#selectable_settlements` |
| `test/models/game_test.rb` | Update existing tile pickup assertion; add new tests |
| `test/controllers/games_controller_test.rb` | Update existing test; add new tests |

---

## Task 1: MandatoryTile rename + apply_tile_pickup "used" key

`populate_player_supplies` currently stores `["mandatory"]` — a string, not a hash. `apply_tile_pickup` omits `"used"`. Both need fixing before any Paddock tile logic can work correctly.

**Files:**
- Modify: `app/models/game.rb:499-505`, `app/models/game.rb:460`
- Modify: `test/models/game_test.rb:55`
- Modify: `test/controllers/games_controller_test.rb:11`

- [ ] **Step 1: Write the failing test for populate_player_supplies**

Add to `test/models/game_test.rb` (before `private`):

```ruby
test "populate_player_supplies initializes tiles with MandatoryTile hash" do
  game = games(:game2player)
  game.send(:populate_player_supplies)

  chris = game_players(:chris).reload
  assert_equal [{ "klass" => "MandatoryTile", "used" => true }], chris.tiles
end
```

- [ ] **Step 2: Run test to confirm it fails**

```
bin/rails test test/models/game_test.rb -n test_populate_player_supplies_initializes_tiles_with_MandatoryTile_hash
```

Expected: FAIL — tiles contains the string `"mandatory"`, not the expected hash.

- [ ] **Step 3: Update the expected tile hash in the existing pickup test**

In `test/models/game_test.rb` line 55, change:

```ruby
# Before:
assert_equal [ { "klass" => "OasisTile", "from" => "[2, 7]" } ], chris.tiles
# After:
assert_equal [ { "klass" => "OasisTile", "from" => "[2, 7]", "used" => true } ], chris.tiles
```

- [ ] **Step 4: Run to confirm the existing pickup test now also fails**

```
bin/rails test test/models/game_test.rb -n test_build_settlement_adjacent_to_tile_picks_it_up_and_decrements_qty
```

Expected: FAIL — `"used"` key is absent.

- [ ] **Step 5: Implement both fixes in game.rb**

In `populate_player_supplies` (around line 501–503):

```ruby
# Before:
p.update(tiles: [ "mandatory" ].to_json)

# After:
p.update(tiles: [{ "klass" => "MandatoryTile", "used" => true }])
```

In `apply_tile_pickup` (around line 460):

```ruby
# Before:
game_player.tiles = (game_player.tiles || []) + [ { "klass" => tile[:klass], "from" => tile[:key] } ]

# After:
game_player.tiles = (game_player.tiles || []) + [ { "klass" => tile[:klass], "from" => tile[:key], "used" => true } ]
```

- [ ] **Step 6: Update the controller test that expects `"Mandatory"` klass**

In `test/controllers/games_controller_test.rb` line 11:

```ruby
# Before:
chris.tiles = [ { "klass" => "Mandatory", "used" => false } ]
# After:
chris.tiles = [ { "klass" => "MandatoryTile", "used" => false } ]
```

- [ ] **Step 7: Run all tests to confirm they pass**

```
bin/rails test test/models/game_test.rb test/controllers/games_controller_test.rb
```

Expected: All pass.

- [ ] **Step 8: Commit**

```bash
git add app/models/game.rb test/models/game_test.rb test/controllers/games_controller_test.rb
git commit -m "Rename Mandatory→MandatoryTile; store 'used' key in tiles at pickup"
```

---

## Task 2: tile_activatable? in Game

New public method on `Game`. Returns true when a tile is unused and the mandatory condition allows activation.

**Files:**
- Modify: `app/models/game.rb`
- Modify: `test/models/game_test.rb`

- [ ] **Step 1: Write failing tests**

Add to `test/models/game_test.rb`:

```ruby
test "tile_activatable? is false when tile is used" do
  game = games(:game2player)
  tile = { "klass" => "PaddockTile", "from" => "[2, 18]", "used" => true }
  assert_not game.tile_activatable?(tile)
end

test "tile_activatable? is true when tile is unused and mandatory_count equals MANDATORY_COUNT" do
  game = games(:game2player)
  # mandatory_count starts at 3 = MANDATORY_COUNT in fixture
  tile = { "klass" => "PaddockTile", "from" => "[2, 18]", "used" => false }
  assert game.tile_activatable?(tile)
end

test "tile_activatable? is false when mandatory_count is mid-build" do
  game = games(:game2player)
  game.mandatory_count = 1
  tile = { "klass" => "PaddockTile", "from" => "[2, 18]", "used" => false }
  assert_not game.tile_activatable?(tile)
end

test "tile_activatable? is true when mandatory_count is 0" do
  game = games(:game2player)
  game.mandatory_count = 0
  tile = { "klass" => "PaddockTile", "from" => "[2, 18]", "used" => false }
  assert game.tile_activatable?(tile)
end

test "tile_activatable? is true when supply is 0 regardless of mandatory_count" do
  game = games(:game2player)
  game.mandatory_count = 1
  game.current_player.supply["settlements"] = 0
  tile = { "klass" => "PaddockTile", "from" => "[2, 18]", "used" => false }
  assert game.tile_activatable?(tile)
end
```

- [ ] **Step 2: Run to confirm they fail**

```
bin/rails test test/models/game_test.rb -n "/tile_activatable/"
```

Expected: FAIL — method does not exist.

- [ ] **Step 3: Implement tile_activatable? in game.rb**

Add after `move_settlement` (around line 244), before `turn_endable?`:

```ruby
def tile_activatable?(tile)
  return false if tile["used"]
  mandatory_count == MANDATORY_COUNT || mandatory_count <= 0 ||
    current_player.supply["settlements"] == 0
end
```

- [ ] **Step 4: Run tests to confirm they pass**

```
bin/rails test test/models/game_test.rb -n "/tile_activatable/"
```

Expected: All pass.

- [ ] **Step 5: Commit**

```bash
git add app/models/game.rb test/models/game_test.rb
git commit -m "Add Game#tile_activatable?"
```

---

## Task 3: Tile#valid_destinations + Tile#selectable_settlements, overridden by PaddockTile

`valid_destinations` and `selectable_settlements` are instance methods defined on `Tiles::Tile` (returning `[]` by default) and overridden by `Tiles::PaddockTile`. No delegates on `Game`.

The test setup uses the Paddock board at index 1 (cols 10–19). Settlement at overall `(0, 14)` (board-1-local `(0, 4)` = `'D'`) has these buildable 2-hop destinations: `(0,12)`=C, `(1,12)`=C, `(0,16)`=D. Non-buildable 2-hops include `(2,13)`=M, `(2,14)`=M, `(2,15)`=W.

**Files:**
- Modify: `app/models/tiles/tile.rb`
- Modify: `app/models/tiles/paddock_tile.rb`
- Create: `test/models/tiles/paddock_tile_test.rb`

- [ ] **Step 1: Create the test directory and file**

```bash
mkdir -p test/models/tiles
```

Create `test/models/tiles/paddock_tile_test.rb`:

```ruby
require "test_helper"

class Tiles::PaddockTileTest < ActiveSupport::TestCase
  # Paddock board at index 1 of the default setup occupies cols 10–19, rows 0–9.
  # A settlement at overall (0,14) = 'D' has buildable 2-hop destinations:
  #   (0,12)=C, (1,12)=C, (0,16)=D
  # Non-buildable 2-hops: (2,13)=M, (2,14)=M, (2,15)=W
  def setup_board(extra_contents = {})
    game = games(:game2player)
    chris = game_players(:chris)
    game.boards = [ ["Tavern", 0], ["Paddock", 0], ["Oasis", 0], ["Farm", 0] ]
    game.board_contents = {
      "[0, 14]" => { "klass" => "Settlement", "player" => chris.order }
    }.merge(extra_contents)
    game.save
    game.instantiate
    { board_contents: game.board_contents, board: game.board, chris: chris }
  end

  test "valid_destinations returns buildable empty 2-hop cells" do
    ctx = setup_board
    tile = Tiles::PaddockTile.new(0)

    result = tile.valid_destinations(0, 14, board_contents: ctx[:board_contents], board: ctx[:board])

    assert_includes result, [0, 12], "C terrain 2 hops away"
    assert_includes result, [1, 12], "C terrain 2 hops away"
    assert_includes result, [0, 16], "D terrain 2 hops away"
    assert_not_includes result, [0, 14], "origin excluded"
    assert_not_includes result, [0, 13], "direct neighbor excluded"
    assert_not_includes result, [2, 13], "M terrain excluded"
    assert_not_includes result, [2, 15], "W terrain excluded"
  end

  test "valid_destinations excludes occupied cells" do
    ctx = setup_board("[0, 12]" => { "klass" => "Settlement", "player" => 1 })
    tile = Tiles::PaddockTile.new(0)

    result = tile.valid_destinations(0, 14, board_contents: ctx[:board_contents], board: ctx[:board])

    assert_not_includes result, [0, 12], "occupied cell excluded"
    assert_includes result, [1, 12]
    assert_includes result, [0, 16]
  end

  test "selectable_settlements returns settlements with valid destinations" do
    ctx = setup_board
    tile = Tiles::PaddockTile.new(0)

    result = tile.selectable_settlements(ctx[:chris].order,
      board_contents: ctx[:board_contents], board: ctx[:board])

    assert_includes result, [0, 14]
  end

  test "selectable_settlements excludes settlements with no valid destinations" do
    ctx = setup_board(
      "[0, 12]" => { "klass" => "Settlement", "player" => 1 },
      "[1, 12]" => { "klass" => "Settlement", "player" => 1 },
      "[0, 16]" => { "klass" => "Settlement", "player" => 1 }
    )
    tile = Tiles::PaddockTile.new(0)

    result = tile.selectable_settlements(ctx[:chris].order,
      board_contents: ctx[:board_contents], board: ctx[:board])

    assert_empty result
  end

  test "base Tile returns empty array for valid_destinations" do
    tile = Tiles::Tile.new(0)
    assert_equal [], tile.valid_destinations(0, 0, board_contents: {}, board: nil)
  end

  test "base Tile returns empty array for selectable_settlements" do
    tile = Tiles::Tile.new(0)
    assert_equal [], tile.selectable_settlements(0, board_contents: {}, board: nil)
  end
end
```

- [ ] **Step 2: Run to confirm they fail**

```
bin/rails test test/models/tiles/paddock_tile_test.rb
```

Expected: FAIL — methods do not exist.

- [ ] **Step 3: Add default methods to Tiles::Tile**

Update `app/models/tiles/tile.rb`:

```ruby
module Tiles
  class Tile
    attr_accessor :qty

    def initialize(qty)
      @qty = qty
    end

    def valid_destinations(from_row, from_col, board_contents:, board:)
      []
    end

    def selectable_settlements(player_order, board_contents:, board:)
      []
    end
  end
end
```

- [ ] **Step 4: Implement overrides in Tiles::PaddockTile**

Replace `app/models/tiles/paddock_tile.rb`:

```ruby
module Tiles
  class PaddockTile < Tiles::Tile
    BUILDABLE_TERRAIN = %w[C D F T G].freeze

    def location_index
      13
    end

    def valid_destinations(from_row, from_col, board_contents:, board:)
      origin_key = "[#{from_row}, #{from_col}]"
      # Collect direct neighbors
      direct = Game::ADJACENCIES[from_row % 2]
        .map { |r, c| [from_row + r, from_col + c] }
        .select { |r, c| (0..19).include?(r) && (0..19).include?(c) }
      # Collect neighbors-of-neighbors, excluding origin and direct neighbors
      excluded = direct.map { |r, c| "[#{r}, #{c}]" }.to_set << origin_key
      candidates = direct.flat_map do |r, c|
        Game::ADJACENCIES[r % 2].map { |dr, dc| [r + dr, c + dc] }
      end
      candidates.select! { |r, c| (0..19).include?(r) && (0..19).include?(c) }
      candidates.uniq!
      candidates.reject! { |r, c| excluded.include?("[#{r}, #{c}]") }
      # Filter: empty and buildable terrain
      candidates.select do |r, c|
        board_contents["[#{r}, #{c}]"].nil? &&
          BUILDABLE_TERRAIN.include?(board.terrain_at(r, c))
      end
    end

    def selectable_settlements(player_order, board_contents:, board:)
      board_contents
        .select { |_k, v| v["klass"] == "Settlement" && v["player"] == player_order }
        .keys
        .filter_map do |key|
          r, c = key.tr("[]", "").split(", ").map(&:to_i)
          [r, c] if valid_destinations(r, c, board_contents: board_contents, board: board).any?
        end
    end
  end
end
```

- [ ] **Step 5: Run tests to confirm they pass**

```
bin/rails test test/models/tiles/paddock_tile_test.rb
```

Expected: All pass.

- [ ] **Step 6: Run all tests**

```
bin/rails test
```

Expected: All pass.

- [ ] **Step 7: Commit**

```bash
git add app/models/tiles/tile.rb app/models/tiles/paddock_tile.rb \
  test/models/tiles/paddock_tile_test.rb
git commit -m "PaddockTile overrides Tile#valid_destinations and #selectable_settlements"
```

---

## Task 4: apply_tile_forfeit creates Move records + forfeit_tile undo case

Currently `apply_tile_forfeit` silently removes tiles. It needs to create `forfeit_tile` Move records (non-deliberate, reversible) so undo can restore them. Then add the `when "forfeit_tile"` case to `undo_last_move`.

**Files:**
- Modify: `app/models/game.rb`
- Modify: `test/models/game_test.rb`

- [ ] **Step 1: Write failing tests**

Add to `test/models/game_test.rb`:

```ruby
test "apply_tile_forfeit creates a forfeit_tile Move record for each forfeited tile" do
  game = games(:game2player)
  chris = game_players(:chris)
  # Settlement moved to [1,5] — not adjacent to tile location [2,7]. Tile forfeited.
  game.boards = [ ["Oasis", 0], ["Paddock", 0], ["Farm", 0], ["Tavern", 0] ]
  game.board_contents = {
    "[2, 7]" => { "klass" => "OasisTile", "qty" => 0 },
    "[1, 7]" => { "klass" => "Settlement", "player" => chris.order }
  }
  game.current_action = { "type" => "paddock", "from" => "[1, 7]" }
  game.save
  chris.tiles = [ { "klass" => "OasisTile", "from" => "[2, 7]", "used" => false } ]
  chris.save

  game.move_settlement(1, 5)

  forfeit_move = game.moves.find_by(action: "forfeit_tile")
  assert forfeit_move, "forfeit_tile Move must be created"
  assert_equal false, forfeit_move.deliberate
  assert_equal true, forfeit_move.reversible
  assert_equal "[2, 7]", forfeit_move.from
  assert_equal "false", forfeit_move.to
  assert_equal chris, forfeit_move.game_player
end

test "undo after move_settlement that forfeits a tile restores the tile" do
  game = games(:game2player)
  chris = game_players(:chris)
  game.boards = [ ["Oasis", 0], ["Paddock", 0], ["Farm", 0], ["Tavern", 0] ]
  game.board_contents = {
    "[2, 7]" => { "klass" => "OasisTile", "qty" => 0 },
    "[1, 7]" => { "klass" => "Settlement", "player" => chris.order }
  }
  game.current_action = { "type" => "paddock", "from" => "[1, 7]" }
  game.save
  chris.tiles = [ { "klass" => "OasisTile", "from" => "[2, 7]", "used" => false } ]
  chris.save

  game.move_settlement(1, 5)
  game.reload
  game.undo_last_move
  game.reload

  chris.reload
  expected_tile = { "klass" => "OasisTile", "from" => "[2, 7]", "used" => false }
  assert_includes chris.tiles, expected_tile, "tile must be restored with its original used state"
end
```

- [ ] **Step 2: Run to confirm they fail**

```
bin/rails test test/models/game_test.rb -n "/forfeit/"
```

Expected: FAIL — no Move records created; undo has no `forfeit_tile` case.

- [ ] **Step 3: Update apply_tile_forfeit in game.rb**

Replace the existing `apply_tile_forfeit` method (around lines 407–420):

```ruby
def apply_tile_forfeit(game_player)
  return if (game_player.tiles || []).empty?
  my_settlements = board_contents
    .select { |_k, v| v["klass"] == "Settlement" && v["player"] == game_player.order }
    .keys
  game_player.tiles = game_player.tiles.reject do |tile|
    loc = tile["from"]
    next false unless loc
    should_forfeit = my_settlements.none? do |s_key|
      s = s_key.tr("[]", "").split(", ").map(&:to_i)
      ADJACENCIES[s[0] % 2].any? { |r, c| "[#{s[0] + r}, #{s[1] + c}]" == loc }
    end
    if should_forfeit
      klass = board_contents[loc]["klass"]
      self.move_count += 1
      self.moves.create(
        order: move_count,
        game_player: game_player,
        deliberate: false,
        action: "forfeit_tile",
        reversible: true,
        from: loc,
        to: tile["used"].to_s,
        message: "#{game_player.player.handle} forfeited a #{klass.delete_suffix('Tile').downcase} tile"
      )
    end
    should_forfeit
  end
end
```

- [ ] **Step 4: Add forfeit_tile case to undo_last_move in game.rb**

Inside the `case move.action` block in `undo_last_move` (around line 306), add after the existing `when "pick_up_tile"` case:

```ruby
when "forfeit_tile"
  klass = board_contents[move.from]["klass"]
  tiles = move.game_player.tiles || []
  move.game_player.tiles = tiles + [{ "klass" => klass, "from" => move.from, "used" => move.to == "true" }]
  move.game_player.save
```

- [ ] **Step 5: Run tests to confirm they pass**

```
bin/rails test test/models/game_test.rb -n "/forfeit/"
```

Expected: All pass.

- [ ] **Step 6: Run all model tests**

```
bin/rails test test/models/
```

Expected: All pass.

- [ ] **Step 7: Commit**

```bash
git add app/models/game.rb test/models/game_test.rb
git commit -m "apply_tile_forfeit creates reversible Move records; add forfeit_tile undo case"
```

---

## Task 5: move_settlement marks PaddockTile used + undo unmarks it

After a successful paddock move, the first unused PaddockTile in the current player's collection must be marked used. Undo must reverse this.

**Files:**
- Modify: `app/models/game.rb`
- Modify: `test/models/game_test.rb`

- [ ] **Step 1: Write failing tests**

Add to `test/models/game_test.rb`:

```ruby
test "move_settlement marks the first unused PaddockTile as used" do
  game = games(:game2player)
  chris = game_players(:chris)
  game.board_contents = { "[5, 5]" => { "klass" => "Settlement", "player" => chris.order } }
  game.current_action = { "type" => "paddock", "from" => "[5, 5]" }
  game.save
  chris.tiles = [
    { "klass" => "MandatoryTile", "used" => false },
    { "klass" => "PaddockTile", "from" => "[2, 18]", "used" => false },
    { "klass" => "PaddockTile", "from" => "[6, 11]", "used" => false }
  ]
  chris.save

  game.move_settlement(5, 7)
  chris.reload

  paddock_tiles = chris.tiles.select { |t| t["klass"] == "PaddockTile" }
  assert paddock_tiles.first["used"], "first PaddockTile must be marked used"
  assert_not paddock_tiles.last["used"], "second PaddockTile must remain unused"
end

test "undo after move_settlement unmarks the first used PaddockTile" do
  game = games(:game2player)
  chris = game_players(:chris)
  game.board_contents = { "[5, 5]" => { "klass" => "Settlement", "player" => chris.order } }
  game.current_action = { "type" => "paddock", "from" => "[5, 5]" }
  game.save
  chris.tiles = [
    { "klass" => "MandatoryTile", "used" => false },
    { "klass" => "PaddockTile", "from" => "[2, 18]", "used" => false }
  ]
  chris.save

  game.move_settlement(5, 7)
  game.reload
  game.undo_last_move
  chris.reload

  paddock_tile = chris.tiles.find { |t| t["klass"] == "PaddockTile" }
  assert_not paddock_tile["used"], "PaddockTile must be unmarked after undo"
end
```

- [ ] **Step 2: Run to confirm they fail**

```
bin/rails test test/models/game_test.rb -n "/marks.*PaddockTile|unmarks.*PaddockTile/"
```

Expected: FAIL — tile used state is unchanged.

- [ ] **Step 3: Update move_settlement in game.rb**

In `move_settlement`, after `self.current_action = { "type" => "mandatory" }` (around line 239), add:

```ruby
tiles = current_player.tiles || []
idx = tiles.index { |t| t["klass"] == "PaddockTile" && t["used"] == false }
if idx
  updated = tiles.dup
  updated[idx] = updated[idx].merge("used" => true)
  current_player.tiles = updated
end
```

- [ ] **Step 4: Update the move_settlement case in undo_last_move in game.rb**

After `self.current_action = { "type" => "paddock", "from" => move.from }` (around line 316), add:

```ruby
tiles = move.game_player.tiles || []
idx = tiles.index { |t| t["klass"] == "PaddockTile" && t["used"] == true }
if idx
  updated = tiles.dup
  updated[idx] = updated[idx].merge("used" => false)
  move.game_player.tiles = updated
  move.game_player.save
end
```

- [ ] **Step 5: Run tests to confirm they pass**

```
bin/rails test test/models/game_test.rb -n "/marks.*PaddockTile|unmarks.*PaddockTile/"
```

Expected: All pass.

- [ ] **Step 6: Run all model tests**

```
bin/rails test test/models/
```

Expected: All pass.

- [ ] **Step 7: Commit**

```bash
git add app/models/game.rb test/models/game_test.rb
git commit -m "move_settlement marks first unused PaddockTile used; undo reverses it"
```

---

## Task 6: end_turn resets all tiles to unused

At the beginning of each player's turn, all their tiles (including MandatoryTile) reset to `"used" => false`.

**Files:**
- Modify: `app/models/game.rb`
- Modify: `test/models/game_test.rb`

- [ ] **Step 1: Write failing test**

Add to `test/models/game_test.rb`:

```ruby
test "end_turn resets all incoming player tiles to used false" do
  game = games(:game2player)
  paula = game_players(:paula)
  paula.tiles = [
    { "klass" => "MandatoryTile", "used" => true },
    { "klass" => "PaddockTile", "from" => "[2, 18]", "used" => true }
  ]
  paula.save

  game.end_turn
  paula.reload

  assert paula.tiles.all? { |t| t["used"] == false },
    "all incoming player tiles must be reset to used: false"
end
```

- [ ] **Step 2: Run to confirm it fails**

```
bin/rails test test/models/game_test.rb -n test_end_turn_resets_all_incoming_player_tiles_to_used_false
```

Expected: FAIL — tiles still have `"used" => true`.

- [ ] **Step 3: Update end_turn in game.rb**

In `end_turn`, after `self.current_player = game_players.find { |p| p.order == next_order }` (around line 279), add:

```ruby
if current_player.tiles
  current_player.tiles = current_player.tiles.map { |t| t.merge("used" => false) }
end
```

- [ ] **Step 4: Run test to confirm it passes**

```
bin/rails test test/models/game_test.rb -n test_end_turn_resets_all_incoming_player_tiles_to_used_false
```

Expected: PASS.

- [ ] **Step 5: Run all model tests**

```
bin/rails test test/models/
```

Expected: All pass.

- [ ] **Step 6: Commit**

```bash
git add app/models/game.rb test/models/game_test.rb
git commit -m "end_turn resets all incoming player tiles to used: false"
```

---

## Task 7: turn_endable? and turn_state for Paddock phases

`turn_endable?` must return false when a paddock action is in progress. `turn_state` must return the correct message for both paddock sub-phases.

**Files:**
- Modify: `app/models/game.rb`
- Modify: `test/models/game_test.rb`

- [ ] **Step 1: Write failing tests**

Add to `test/models/game_test.rb`:

```ruby
test "turn_endable? returns false when paddock action is in progress" do
  game = games(:game2player)
  game.mandatory_count = 0
  game.current_action = { "type" => "paddock" }
  assert_not game.turn_endable?
end

test "turn_endable? returns false when paddock action has from selected" do
  game = games(:game2player)
  game.mandatory_count = 0
  game.current_action = { "type" => "paddock", "from" => "[5, 5]" }
  assert_not game.turn_endable?
end

test "turn_endable? returns true when mandatory action is complete" do
  game = games(:game2player)
  game.mandatory_count = 0
  game.current_action = { "type" => "mandatory" }
  assert game.turn_endable?
end

test "turn_endable? returns true when supply is 0 and action is mandatory" do
  game = games(:game2player)
  game.current_action = { "type" => "mandatory" }
  chris = game_players(:chris)
  chris.supply = { "settlements" => 0 }
  chris.save
  assert game.turn_endable?
end

test "turn_state returns must move a settlement when paddock has no from" do
  game = games(:game2player)
  game.current_action = { "type" => "paddock" }
  assert_match(/must move a settlement/, game.turn_state)
end

test "turn_state returns must move a settlement when paddock has from set" do
  game = games(:game2player)
  game.current_action = { "type" => "paddock", "from" => "[5, 5]" }
  assert_match(/must move a settlement/, game.turn_state)
end
```

- [ ] **Step 2: Run to confirm some fail**

```
bin/rails test test/models/game_test.rb -n "/turn_endable\?|turn_state.*paddock|must move/"
```

Expected: Some fail.

- [ ] **Step 3: Update turn_endable? in game.rb**

Replace the existing `turn_endable?` method (around lines 245–250):

```ruby
def turn_endable?
  current_action["type"] == "mandatory" &&
    (mandatory_count <= 0 || current_player.supply["settlements"] == 0)
end
```

- [ ] **Step 4: Update turn_state in game.rb**

Replace the existing `turn_state` method (around lines 258–266):

```ruby
def turn_state
  case current_action["type"]
  when "paddock"
    "#{current_player.player.handle} must move a settlement"
  else
    if mandatory_count > 0 && current_player.supply["settlements"] > 0
      "#{current_player.player.handle} must build " \
      "#{ActionController::Base.helpers.pluralize(mandatory_count, "settlement")} on " \
      "#{Boards::Board::TERRAIN_NAMES[current_player.hand]}"
    else
      "#{current_player.player.handle} must end their turn"
    end
  end
end
```

- [ ] **Step 5: Run tests to confirm they pass**

```
bin/rails test test/models/game_test.rb -n "/turn_endable\?|turn_state/"
```

Expected: All pass.

- [ ] **Step 6: Run all model tests**

```
bin/rails test test/models/
```

Expected: All pass.

- [ ] **Step 7: Commit**

```bash
git add app/models/game.rb test/models/game_test.rb
git commit -m "turn_endable? guards paddock phases; turn_state handles paddock action type"
```

---

## Task 8: Controller — action dispatch + end_turn guard

The `action` controller method currently always calls `build_settlement`. It must dispatch based on `current_action["type"]` and `"from"`. The `end_turn` guard must use `turn_endable?`.

**Files:**
- Modify: `app/controllers/games_controller.rb`
- Modify: `test/controllers/games_controller_test.rb`

- [ ] **Step 1: Write failing controller tests**

Add to `test/controllers/games_controller_test.rb`:

```ruby
test "POST action dispatches to select_settlement when paddock action has no from" do
  game = games(:game2player)
  chris = game_players(:chris)
  game.current_action = { "type" => "paddock" }
  game.board_contents = { "[5, 5]" => { "klass" => "Settlement", "player" => chris.order } }
  game.save

  post action_game_url(game), params: { build_cell: "map-cell-5-5" }

  game.reload
  assert_equal "[5, 5]", game.current_action["from"], "select_settlement must have set from"
end

test "POST action dispatches to move_settlement when paddock action has from set" do
  game = games(:game2player)
  chris = game_players(:chris)
  game.board_contents = { "[5, 5]" => { "klass" => "Settlement", "player" => chris.order } }
  game.current_action = { "type" => "paddock", "from" => "[5, 5]" }
  game.save

  post action_game_url(game), params: { build_cell: "map-cell-5-7" }

  game.reload
  assert_nil game.board_contents["[5, 5]"], "settlement must have moved"
  assert_equal chris.order, game.board_contents["[5, 7]"]["player"]
end

test "POST end_turn does not call end_turn when paddock action is in progress" do
  game = games(:game2player)
  game.mandatory_count = 0
  game.current_action = { "type" => "paddock" }
  game.save

  post end_turn_game_url(game)

  assert_equal "paddock", game.reload.current_action["type"]
end

test "POST end_turn does not call end_turn when mandatory builds are incomplete" do
  game = games(:game2player)
  # mandatory_count is 3 (from fixture), supply > 0

  post end_turn_game_url(game)

  assert_equal 3, game.reload.mandatory_count
end
```

- [ ] **Step 2: Run to confirm they fail**

```
bin/rails test test/controllers/games_controller_test.rb
```

Expected: Some fail.

- [ ] **Step 3: Update the action method in games_controller.rb**

Replace lines 41–44 (the `target`/`row`/`col`/`build_settlement` block):

```ruby
target = action_params[1]
row = target.match(/-\d*-/).to_s[1..-2].to_i
col = target.match(/-\d*\z/).to_s[1..-1].to_i
case @game.current_action["type"]
when "paddock"
  if @game.current_action["from"]
    @game.move_settlement(row, col)
  else
    @game.select_settlement(row, col)
  end
else
  @game.build_settlement(row, col)
end
```

- [ ] **Step 4: Update the end_turn guard in games_controller.rb**

Replace line 67:

```ruby
# Before:
@game.end_turn if @game.mandatory_count <= 0
# After:
@game.end_turn if @game.turn_endable?
```

- [ ] **Step 5: Run all tests**

```
bin/rails test
```

Expected: All pass.

- [ ] **Step 6: Commit**

```bash
git add app/controllers/games_controller.rb test/controllers/games_controller_test.rb
git commit -m "Controller dispatches action by current_action type; end_turn uses turn_endable?"
```

---

## Task 9: Views — tile activation button + current-action span

**Files:**
- Modify: `app/views/games/_tiles.html.erb`
- Modify: `app/views/games/_turn_state.html.erb`
- Modify: `test/controllers/games_controller_test.rb`

- [ ] **Step 1: Write failing view tests**

Add to `test/controllers/games_controller_test.rb`:

```ruby
test "game show renders a button for an activatable PaddockTile" do
  game = games(:game2player)
  chris = game_players(:chris)
  chris.tiles = [
    { "klass" => "MandatoryTile", "used" => false },
    { "klass" => "PaddockTile", "from" => "[2, 18]", "used" => false }
  ]
  chris.save

  get game_url(game)

  assert_select "form[action='#{select_action_game_path(game)}'] button", minimum: 1
end

test "game show does not render a button for a used PaddockTile" do
  game = games(:game2player)
  chris = game_players(:chris)
  chris.tiles = [
    { "klass" => "MandatoryTile", "used" => false },
    { "klass" => "PaddockTile", "from" => "[2, 18]", "used" => true }
  ]
  chris.save

  get game_url(game)

  assert_select "form[action='#{select_action_game_path(game)}'] button", count: 0
end

test "game show includes current-action span with data attributes" do
  game = games(:game2player)
  get game_url(game)
  assert_select "span#current-action[data-type='mandatory']"
end
```

- [ ] **Step 2: Run to confirm they fail**

```
bin/rails test test/controllers/games_controller_test.rb -n "/button.*Paddock|current-action/"
```

Expected: FAIL.

- [ ] **Step 3: Update _tiles.html.erb**

Replace the entire content of `app/views/games/_tiles.html.erb`:

```erb
<% (player.tiles || []).each do |tile| %>
  <% type = tile["klass"].delete_suffix("Tile").downcase %>
  <% used = tile["used"] %>
  <% if n == 0 && tile["klass"] == "PaddockTile" && game.tile_activatable?(tile) %>
    <%= button_to type.capitalize,
          select_action_game_path(game),
          params: { action_type: "paddock" },
          class: "player-tile #{type} tile-available" %>
  <% else %>
    <div class="player-tile <%= type %> <%= used ? 'tile-used' : 'tile-available' %>">
      <div class="tile location-<%= type %>"></div>
      <span class="tile-name"><%= type.capitalize %></span>
    </div>
  <% end %>
<% end %>
```

- [ ] **Step 4: Update _turn_state.html.erb**

Replace the entire content of `app/views/games/_turn_state.html.erb`:

```erb
<%= game.turn_state %>
<span class="mandatory-count"><%= game.mandatory_count %></span>
<span id="current-action"
  data-type="<%= game.current_action&.dig('type') %>"
  data-from="<%= game.current_action&.dig('from') %>">
</span>
```

(Also fixes the missing `</span>` on mandatory-count that existed in the original.)

- [ ] **Step 5: Run all tests**

```
bin/rails test
```

Expected: All pass.

- [ ] **Step 6: Commit**

```bash
git add app/views/games/_tiles.html.erb app/views/games/_turn_state.html.erb \
  test/controllers/games_controller_test.rb
git commit -m "Tiles view renders activation button for PaddockTile; add current-action span"
```

---

## Task 10: JavaScript — Paddock highlighting

**Files:**
- Modify: `app/javascript/gameboard.js`

No automated JS tests exist in this project. Manual verification is provided instead.

- [ ] **Step 1: Update unmarkAvailableCells to also remove 'selected' class**

Replace the existing `unmarkAvailableCells` function:

```js
function unmarkAvailableCells() {
  document.querySelectorAll(".hex").forEach(c => {
    c.classList.remove("selectable");
    c.classList.remove("selected");
  });
}
```

- [ ] **Step 2: Add cellKeyToCellId helper function after unmarkAvailableCells**

`current_action["from"]` is stored as `"[R, C]"` (e.g. `"[5, 5]"`). The `data-from` attribute on `#current-action` contains this value, but `paddockDestinations` and `getElementById` need the `"map-cell-R-C"` format. This helper converts between them.

```js
function cellKeyToCellId(key) {
  const parts = key.replace(/[\[\] ]/g, "").split(",");
  return `map-cell-${parts[0]}-${parts[1]}`;
}
```

- [ ] **Step 3: Add paddockDestinations function**

```js
function paddockDestinations(cellId) {
  const BUILDABLE = ["terrain-c", "terrain-d", "terrain-f", "terrain-t", "terrain-g"];
  const ADJACENCIES = [ [ [ 0, -1 ], [ 0, 1 ], [ -1, -1 ], [ -1, 0 ], [ 1, -1 ], [ 1, 0 ] ],
                        [ [ 0, -1 ], [ 0, 1 ], [ -1,  0 ], [ -1, 1 ], [ 1,  0 ], [ 1, 1 ] ] ];
  const row = Number(cellId.split("-")[2]);
  const col = Number(cellId.split("-")[3]);

  const direct = new Set();
  ADJACENCIES[row % 2].forEach(([dr, dc]) => {
    const r = row + dr, c = col + dc;
    if (r >= 0 && r <= 19 && c >= 0 && c <= 19) direct.add(`map-cell-${r}-${c}`);
  });

  const excluded = new Set([...direct, cellId]);
  const candidates = new Map();
  direct.forEach(nId => {
    const nr = Number(nId.split("-")[2]);
    const nc = Number(nId.split("-")[3]);
    ADJACENCIES[nr % 2].forEach(([dr, dc]) => {
      const r = nr + dr, c = nc + dc;
      if (r >= 0 && r <= 19 && c >= 0 && c <= 19) {
        const id = `map-cell-${r}-${c}`;
        if (!excluded.has(id)) candidates.set(id, true);
      }
    });
  });

  return [...candidates.keys()].filter(id => {
    const cell = document.getElementById(id);
    if (!cell) return false;
    if (cell.querySelector(".hex-settlement")) return false;
    return BUILDABLE.some(cls => cell.classList.contains(cls));
  });
}
```

- [ ] **Step 4: Add markSelectableSettlements function**

```js
function markSelectableSettlements() {
  const playerNo = parseInt(document.querySelector(".handle .player-order").innerText);
  document.querySelectorAll(`.hex-settlement.player-${playerNo}`).forEach(s => {
    const cell = s.closest(".hex");
    if (!cell) return;
    if (paddockDestinations(cell.id).length > 0) {
      cell.classList.add("selectable");
    }
  });
}
```

- [ ] **Step 5: Add markPaddockDestinations function**

```js
function markPaddockDestinations(from) {
  const fromCell = document.getElementById(from);
  if (fromCell) fromCell.classList.add("selected");
  paddockDestinations(from).forEach(id => {
    const cell = document.getElementById(id);
    if (cell) cell.classList.add("selectable");
  });
}
```

- [ ] **Step 6: Update prepForMove to branch on current-action type**

Replace the existing `prepForMove` function:

```js
function prepForMove() {
  console.log("Is it my turn?");
  unmarkAvailableCells();
  if (!document.querySelector(".handle.my-turn")) {
    console.log(" - nope");
    return;
  }
  console.log("It's my turn!");
  const actionEl = document.getElementById("current-action");
  const actionType = actionEl ? actionEl.dataset.type : "mandatory";
  const actionFrom = actionEl ? actionEl.dataset.from : null;

  if (actionType === "paddock") {
    if (actionFrom) {
      markPaddockDestinations(cellKeyToCellId(actionFrom));
    } else {
      markSelectableSettlements();
    }
  } else {
    markAvailableCells();
  }
}
```

- [ ] **Step 7: Run full test suite**

```
bin/rails test
```

Expected: All pass.

- [ ] **Step 8: Manual smoke test**

Start the app (`make up`) and play to a state where you hold a Paddock tile:

1. Verify the Paddock tile renders a clickable button when activatable (mandatory_count = 3 or 0)
2. Click the button — verify settlements with valid 2-hop destinations get `selectable` class
3. Click a settlement — verify that hex gets `selected` and reachable destinations get `selectable`
4. Click a destination — verify the settlement moves and the tile is now tile-used
5. Press Undo three times — verify each step reverses correctly
6. Verify the tile is not usable mid-mandatory-build (mandatory_count = 1 or 2)

- [ ] **Step 9: Commit**

```bash
git add app/javascript/gameboard.js
git commit -m "JS: paddock highlighting for settlement selection and destination phases"
```

---

## Done

All tasks complete. The Paddock Tile is fully functional: tiles are acquired with `"used" => true`, players can activate tiles between mandatory builds, settlements move 2 hops to buildable terrain, forfeited tiles are reversible, and the full undo chain works in three presses.
