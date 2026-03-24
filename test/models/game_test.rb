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
    assert_equal [ { "klass" => "OasisTile", "from" => "[2, 7]" } ], chris.tiles
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
