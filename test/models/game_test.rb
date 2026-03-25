# == Schema Information
#
# Table name: games
#
#  id                :bigint           not null, primary key
#  board_contents    :json
#  boards            :json
#  current_action    :json
#  deck              :json
#  discard           :json
#  goals             :json
#  mandatory_count   :integer
#  move_count        :integer
#  scores            :json
#  state             :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  current_player_id :integer
#
# Indexes
#
#  index_games_on_current_player_id  (current_player_id)
#
require "test_helper"

class GameTest < ActiveSupport::TestCase
  test "end turn with low deck should shuffle discard pile" do
    game = games(:game2player)
    game.deck = [ "A" ]
    game.discard = [ "B", "C", "D", "E" ]
    game.save

    # Simulate end of turn
    game.end_turn

    # Check that the deck is shuffled and discard is cleared
    assert_equal [], game.discard
    assert_not_equal [ "A" ], game.deck
  end

  # Tile pickup tests
  #
  # Setup: OasisBoard has a tile location at (2, 7).
  # Row 1 col 7 is "T" terrain, and its adjacencies (odd-row offsets) include (2, 7).
  # Chris's hand is "T", so building at (1, 7) is the triggering move.

  test "build_settlement adjacent to tile picks it up and decrements qty" do
    game = game_with_tile_at_2_7(qty: 2)

    game.build_settlement(1, 7)
    game.reload

    assert_equal 1, game.board_contents["[2, 7]"]["qty"]
    chris = game_players(:chris).reload
    assert_equal [ { "klass" => "OasisTile", "from" => "[2, 7]", "used" => true } ], chris.tiles
    assert_equal 2, game.moves.count  # deliberate build + consequential pick_up_tile
    assert game.moves.exists?(action: "pick_up_tile", deliberate: false)
  end

  test "taking the last tile keeps the board_contents entry at qty zero" do
    game = game_with_tile_at_2_7(qty: 1)

    game.build_settlement(1, 7)
    game.reload

    assert game.board_contents.key?("[2, 7]"), "entry must remain so the tile class is not lost"
    assert_equal 0, game.board_contents["[2, 7]"]["qty"]
  end

  test "build_settlement does not pick up a tile the player already holds from that location" do
    game = game_with_tile_at_2_7(qty: 2)
    chris = game_players(:chris)
    chris.tiles = [ { "klass" => "OasisTile", "from" => "[2, 7]" } ]
    chris.save
    game.reload  # clear association cache

    game.build_settlement(1, 7)
    game.reload

    assert_equal 2, game.board_contents["[2, 7]"]["qty"], "tile qty must be unchanged"
    assert_equal 1, game.moves.count, "only the deliberate build move should exist"
  end

  test "build_settlement does not pick up a tile whose qty is already zero" do
    game = game_with_tile_at_2_7(qty: 0)

    game.build_settlement(1, 7)
    game.reload

    assert_equal 0, game.board_contents["[2, 7]"]["qty"], "tile qty must stay at zero"
    assert_empty game_players(:chris).reload.tiles, "player should receive no tile"
    assert_equal 1, game.moves.count, "only the deliberate build move should exist"
  end

  test "undo_last_move after a tile pickup restores tile and removes it from the player" do
    game = game_with_tile_at_2_7(qty: 2)
    game.build_settlement(1, 7)
    game.reload

    game.undo_last_move
    game.reload

    assert_equal 2, game.board_contents["[2, 7]"]["qty"], "tile qty must be restored"
    chris = game_players(:chris).reload
    assert_empty chris.tiles, "player must no longer hold the tile"
    assert_equal 40, chris.supply["settlements"], "settlement must be returned to supply"
    assert_equal 0, game.moves.count, "all moves must be destroyed"
  end

  test "undo_last_move increments a zero-qty tile back to one" do
    game = game_with_tile_at_2_7(qty: 1)
    game.build_settlement(1, 7)
    game.reload

    game.undo_last_move
    game.reload

    assert_equal 1, game.board_contents["[2, 7]"]["qty"]
  end

  # Paddock tile action tests
  #
  # Setup: Chris holds a Paddock tile. The Paddock action is a two-step deliberate
  # move: first select the action (announces intent to use the tile), then select
  # the destination settlement.

  test "select_action with paddock tile sets current_action type" do
    game = games(:game2player)
    chris = game_players(:chris)
    chris.tiles = [ { "klass" => "PaddockTile", "from" => "[2, 7]", "used" => false } ]
    chris.save

    game.select_action("paddock")
    game.reload

    assert_equal "paddock", game.current_action["type"]
  end

  test "select_settlement sets current_action from when in paddock action" do
    game = games(:game2player)
    chris = game_players(:chris)
    game.board_contents = { "[5, 5]" => { "klass" => "Settlement", "player" => chris.order } }
    game.current_action = { "type" => "paddock" }
    game.save

    game.select_settlement(5, 5)
    game.reload

    assert_equal "paddock", game.current_action["type"]
    assert_equal "[5, 5]", game.current_action["from"]
  end

  test "move_settlement moves the piece and resets current_action to mandatory" do
    game = games(:game2player)
    chris = game_players(:chris)
    game.board_contents = { "[5, 5]" => { "klass" => "Settlement", "player" => chris.order } }
    game.current_action = { "type" => "paddock", "from" => "[5, 5]" }
    game.save

    game.move_settlement(5, 7)
    game.reload

    assert_nil game.board_contents["[5, 5]"], "settlement must leave its old location"
    assert_equal chris.order, game.board_contents["[5, 7]"]["player"], "settlement must arrive at new location"
    assert_equal({ "type" => "mandatory" }, game.current_action)
  end

  test "move_settlement away from a tile location removes the tile from the player" do
    game = games(:game2player)
    chris = game_players(:chris)
    # Chris has one settlement at [1,7], which is adjacent to tile location [2,7]
    game.board_contents = { "[1, 7]" => { "klass" => "Settlement", "player" => chris.order } }
    game.current_action = { "type" => "paddock", "from" => "[1, 7]" }
    game.save
    chris.tiles = [ { "klass" => "OasisTile", "from" => "[2, 7]" } ]
    chris.save

    # Move to [1,5] — a valid paddock hop, not adjacent to [2,7]
    game.move_settlement(1, 5)

    assert_empty game_players(:chris).reload.tiles
  end

  test "undo_last_move after move_settlement returns the piece and restores current_action" do
    game = games(:game2player)
    chris = game_players(:chris)
    game.board_contents = { "[5, 5]" => { "klass" => "Settlement", "player" => chris.order } }
    game.current_action = { "type" => "paddock", "from" => "[5, 5]" }
    game.save

    game.move_settlement(5, 7)
    game.reload
    game.undo_last_move
    game.reload

    assert_nil game.board_contents["[5, 7]"], "settlement must leave the destination"
    assert_equal chris.order, game.board_contents["[5, 5]"]["player"], "settlement must be back at origin"
    assert_equal "paddock", game.current_action["type"]
    assert_equal "[5, 5]", game.current_action["from"]
    assert_equal 0, game.moves.count
  end

  test "undo_last_move after select_action resets current_action to mandatory" do
    game = games(:game2player)
    game.select_action("paddock")
    game.reload

    game.undo_last_move
    game.reload

    assert_equal({ "type" => "mandatory" }, game.current_action)
    assert_equal 0, game.moves.count
  end

  test "undo_last_move after select_settlement clears the from in current_action" do
    game = games(:game2player)
    chris = game_players(:chris)
    game.board_contents = { "[5, 5]" => { "klass" => "Settlement", "player" => chris.order } }
    game.current_action = { "type" => "paddock" }
    game.save

    game.select_settlement(5, 5)
    game.reload
    game.undo_last_move
    game.reload

    assert_equal "paddock", game.current_action["type"]
    assert_nil game.current_action["from"]
    assert_equal 0, game.moves.count
  end

  test "end_turn resets current_action to mandatory" do
    game = games(:game2player)
    game.current_action = { "type" => "paddock", "from" => "[5, 5]" }
    game.save

    game.end_turn
    game.reload

    assert_equal({ "type" => "mandatory" }, game.current_action)
  end

  test "populate_player_supplies initializes tiles with MandatoryTile hash" do
    game = games(:game2player)
    game.send(:populate_player_supplies)

    chris = game_players(:chris).reload
    assert_equal [{ "klass" => "MandatoryTile", "used" => true }], chris.tiles
  end

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

  test "move_settlement marks the first unused PaddockTile as used" do
    game = games(:game2player)
    chris = game_players(:chris)
    # Settlement moves from [5, 5] to [5, 7]. Tile from-hexes [6, 7] and [6, 8]
    # are both adjacent to [5, 7] (odd row) so they survive apply_tile_forfeit.
    game.board_contents = { "[5, 5]" => { "klass" => "Settlement", "player" => chris.order } }
    game.current_action = { "type" => "paddock", "from" => "[5, 5]" }
    game.save
    chris.tiles = [
      { "klass" => "MandatoryTile", "used" => false },
      { "klass" => "PaddockTile", "from" => "[6, 7]", "used" => false },
      { "klass" => "PaddockTile", "from" => "[6, 8]", "used" => false }
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
    # Tile from-hex [6, 7] is adjacent to destination [5, 7] (odd row) so it
    # survives apply_tile_forfeit and remains in the player's tiles after the move.
    game.board_contents = { "[5, 5]" => { "klass" => "Settlement", "player" => chris.order } }
    game.current_action = { "type" => "paddock", "from" => "[5, 5]" }
    game.save
    chris.tiles = [
      { "klass" => "MandatoryTile", "used" => false },
      { "klass" => "PaddockTile", "from" => "[6, 7]", "used" => false }
    ]
    chris.save

    game.move_settlement(5, 7)
    game.reload
    game.undo_last_move
    chris.reload

    paddock_tile = chris.tiles.find { |t| t["klass"] == "PaddockTile" }
    assert_not paddock_tile["used"], "PaddockTile must be unmarked after undo"
  end

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

  private

  # Returns a saved, in-progress game using the Oasis board with a single tile
  # entry at overall coordinate [2, 7] (the first Oasis location hex).
  # Chris is the current player with hand "T"; row 1 col 7 is adjacent "T" terrain.
  def game_with_tile_at_2_7(qty:)
    game = games(:game2player)
    game.boards = [ [ "Oasis", 0 ], [ "Paddock", 0 ], [ "Farm", 0 ], [ "Tavern", 0 ] ]
    game.board_contents = { "[2, 7]" => { "klass" => "OasisTile", "qty" => qty } }
    game.save
    game
  end
end
