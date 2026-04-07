# == Schema Information
#
# Table name: games
#
#  id                :bigint           not null, primary key
#  base_snapshot     :jsonb
#  board_contents    :json
#  boards            :json
#  current_action    :json
#  deck              :json
#  discard           :json
#  ending            :boolean          default(FALSE), not null
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

require "turbo/broadcastable/test_helper"

class GameTest < ActiveSupport::TestCase
  include Turbo::Broadcastable::TestHelper
  test "end turn with low deck should shuffle discard pile" do
    game = games(:game2player)
    game.deck = [ "A" ]
    game.discard = [ "B", "C", "D", "E" ]
    game.save

    # Simulate end of turn
    engine(game).end_turn

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

    engine(game).build_settlement(1, 7)
    game.reload

    assert_equal 1, game.board_contents.tile_qty(2, 7)
    chris = game_players(:chris).reload
    assert_equal [ { "klass" => "OasisTile", "from" => "[2, 7]", "used" => true } ], chris.tiles
    assert_equal 2, game.moves.count  # deliberate build + consequential pick_up_tile
    assert game.moves.exists?(action: "pick_up_tile", deliberate: false)
  end

  test "taking the last tile keeps the board_contents entry at qty zero" do
    game = game_with_tile_at_2_7(qty: 1)

    engine(game).build_settlement(1, 7)
    game.reload

    assert_not game.board_contents.empty?(2, 7), "entry must remain so the tile class is not lost"
    assert_equal 0, game.board_contents.tile_qty(2, 7)
  end

  test "build_settlement does not pick up a tile the player already holds from that location" do
    game = game_with_tile_at_2_7(qty: 2)
    chris = game_players(:chris)
    chris.tiles = [ { "klass" => "OasisTile", "from" => "[2, 7]" } ]
    chris.save
    game.reload  # clear association cache

    engine(game).build_settlement(1, 7)
    game.reload

    assert_equal 2, game.board_contents.tile_qty(2, 7), "tile qty must be unchanged"
    assert_equal 1, game.moves.count, "only the deliberate build move should exist"
  end

  test "build_settlement does not pick up a tile whose qty is already zero" do
    game = game_with_tile_at_2_7(qty: 0)

    engine(game).build_settlement(1, 7)
    game.reload

    assert_equal 0, game.board_contents.tile_qty(2, 7), "tile qty must stay at zero"
    assert_empty game_players(:chris).reload.tiles, "player should receive no tile"
    assert_equal 1, game.moves.count, "only the deliberate build move should exist"
  end

  test "undo_last_move after a tile pickup restores tile and removes it from the player" do
    game = game_with_tile_at_2_7(qty: 2)
    engine(game).build_settlement(1, 7)
    game.reload

    engine(game).undo_last_move
    game.reload

    assert_equal 2, game.board_contents.tile_qty(2, 7), "tile qty must be restored"
    chris = game_players(:chris).reload
    assert_empty chris.tiles, "player must no longer hold the tile"
    assert_equal 40, chris.supply["settlements"], "settlement must be returned to supply"
    assert_equal 0, game.moves.count, "all moves must be destroyed"
  end

  test "undo_last_move increments a zero-qty tile back to one" do
    game = game_with_tile_at_2_7(qty: 1)
    engine(game).build_settlement(1, 7)
    game.reload

    engine(game).undo_last_move
    game.reload

    assert_equal 1, game.board_contents.tile_qty(2, 7)
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

    engine(game).select_action("paddock")
    game.reload

    assert_equal "paddock", game.current_action["type"]
  end

  test "select_settlement sets current_action from when in paddock action" do
    game = games(:game2player)
    chris = game_players(:chris)
    game.board_contents = BoardState.new.tap { |s| s.place_settlement(5, 5, chris.order) }
    game.current_action = { "type" => "paddock" }
    game.save

    engine(game).select_settlement(5, 5)
    game.reload

    assert_equal "paddock", game.current_action["type"]
    assert_equal "[5, 5]", game.current_action["from"]
  end

  test "move_settlement moves the piece and resets current_action to mandatory" do
    game = games(:game2player)
    chris = game_players(:chris)
    game.board_contents = BoardState.new.tap { |s| s.place_settlement(5, 5, chris.order) }
    game.current_action = { "type" => "paddock", "from" => "[5, 5]" }
    game.save

    engine(game).move_settlement(5, 7)
    game.reload

    assert game.board_contents.empty?(5, 5), "settlement must leave its old location"
    assert_equal chris.order, game.board_contents.player_at(5, 7), "settlement must arrive at new location"
    assert_equal({ "type" => "mandatory" }, game.current_action)
  end

  test "move_settlement away from a tile location removes the tile from the player" do
    game = games(:game2player)
    chris = game_players(:chris)
    # Chris has one settlement at [1,7], which is adjacent to tile location [2,7]
    game.board_contents = BoardState.new.tap { |s| s.place_settlement(1, 7, chris.order) }
    game.current_action = { "type" => "paddock", "from" => "[1, 7]" }
    game.save
    chris.tiles = [ { "klass" => "OasisTile", "from" => "[2, 7]" } ]
    chris.save

    # Move to [1,5] — a valid paddock hop, not adjacent to [2,7]
    engine(game).move_settlement(1, 5)

    assert_empty game_players(:chris).reload.tiles
  end

  # When a settlement moves onto a cell adjacent to a tile location hex the same
  # pickup rules apply as for building: decrement qty, give tile to player,
  # skip if player already holds one from that location, skip if qty is zero.
  # Setup: settlement at [1, 5] moves to [1, 7], which is adjacent to [2, 7].

  test "move_settlement adjacent to a tile location picks it up and decrements qty" do
    game = game_with_tile_at_2_7(qty: 2)
    chris = game_players(:chris)
    state = game.board_contents.dup
    state.place_settlement(1, 5, chris.order)
    game.board_contents = state
    game.current_action = { "type" => "paddock", "from" => "[1, 5]" }
    game.save

    engine(game).move_settlement(1, 7)
    game.reload

    assert_equal 1, game.board_contents.tile_qty(2, 7)
    chris = game_players(:chris).reload
    assert_equal [ { "klass" => "OasisTile", "from" => "[2, 7]", "used" => true } ], chris.tiles
  end

  test "move_settlement does not pick up a tile the player already holds from that location" do
    game = game_with_tile_at_2_7(qty: 2)
    chris = game_players(:chris)
    state = game.board_contents.dup
    state.place_settlement(1, 5, chris.order)
    game.board_contents = state
    game.current_action = { "type" => "paddock", "from" => "[1, 5]" }
    game.save
    chris.tiles = [ { "klass" => "OasisTile", "from" => "[2, 7]" } ]
    chris.save

    engine(game).move_settlement(1, 7)
    game.reload

    assert_equal 2, game.board_contents.tile_qty(2, 7), "tile qty must be unchanged"
    assert_equal 1, game_players(:chris).reload.tiles.length, "player must still hold exactly one tile"
  end

  test "move_settlement does not pick up a tile whose qty is already zero" do
    game = game_with_tile_at_2_7(qty: 0)
    chris = game_players(:chris)
    state = game.board_contents.dup
    state.place_settlement(1, 5, chris.order)
    game.board_contents = state
    game.current_action = { "type" => "paddock", "from" => "[1, 5]" }
    game.save

    engine(game).move_settlement(1, 7)
    game.reload

    assert_equal 0, game.board_contents.tile_qty(2, 7), "tile qty must stay at zero"
    assert_empty game_players(:chris).reload.tiles, "player should receive no tile"
  end

  test "undo_last_move after move_settlement returns the piece and restores current_action" do
    game = games(:game2player)
    chris = game_players(:chris)
    game.board_contents = BoardState.new.tap { |s| s.place_settlement(5, 5, chris.order) }
    game.current_action = { "type" => "paddock", "from" => "[5, 5]" }
    game.save

    engine(game).move_settlement(5, 7)
    game.reload
    engine(game).undo_last_move
    game.reload

    assert game.board_contents.empty?(5, 7), "settlement must leave the destination"
    assert_equal chris.order, game.board_contents.player_at(5, 5), "settlement must be back at origin"
    assert_equal "paddock", game.current_action["type"]
    assert_equal "[5, 5]", game.current_action["from"]
    assert_equal 0, game.moves.count
  end

  test "undo_last_move after select_action resets current_action to mandatory" do
    game = games(:game2player)
    engine(game).select_action("paddock")
    game.reload

    engine(game).undo_last_move
    game.reload

    assert_equal({ "type" => "mandatory" }, game.current_action)
    assert_equal 0, game.moves.count
  end

  test "undo_last_move after select_settlement clears the from in current_action" do
    game = games(:game2player)
    chris = game_players(:chris)
    game.board_contents = BoardState.new.tap { |s| s.place_settlement(5, 5, chris.order) }
    game.current_action = { "type" => "paddock" }
    game.save

    engine(game).select_settlement(5, 5)
    game.reload
    engine(game).undo_last_move
    game.reload

    assert_equal "paddock", game.current_action["type"]
    assert_nil game.current_action["from"]
    assert_equal 0, game.moves.count
  end

  test "end_turn resets current_action to mandatory" do
    game = games(:game2player)
    game.current_action = { "type" => "paddock", "from" => "[5, 5]" }
    game.save

    engine(game).end_turn
    game.reload

    assert_equal({ "type" => "mandatory" }, game.current_action)
  end

  test "populate_player_supplies initializes tiles with MandatoryTile hash" do
    game = games(:game2player)
    game.send(:populate_player_supplies)

    chris = game_players(:chris).reload
    assert_equal [ { "klass" => "MandatoryTile", "used" => true } ], chris.tiles
  end

  test "tile_activatable? is false when tile is used" do
    game = games(:game2player)
    tile = { "klass" => "PaddockTile", "from" => "[2, 18]", "used" => true }
    assert_not engine(game).tile_activatable?(tile)
  end

  test "tile_activatable? is true when tile is unused and mandatory_count equals MANDATORY_COUNT" do
    game = games(:game2player)
    game.mandatory_count = Game::MANDATORY_COUNT
    game.boards = [ [ "Paddock", 0 ], [ "Oasis", 0 ], [ "Farm", 0 ], [ "Tavern", 0 ] ]
    state = BoardState.new.tap { |s| s.place_settlement(0, 0, game.current_player.order) }
    game.board_contents = state
    tile = { "klass" => "PaddockTile", "from" => "[2, 18]", "used" => false }
    assert engine(game).tile_activatable?(tile)
  end

  test "tile_activatable? is true for BarnTile at start of turn" do
    game = games(:game2player)
    game.mandatory_count = Game::MANDATORY_COUNT
    game.boards = [ [ "Barn", 0 ], [ "Paddock", 0 ], [ "Farm", 0 ], [ "Tavern", 0 ] ]
    state = BoardState.new.tap { |s| s.place_settlement(0, 0, game.current_player.order) }
    game.board_contents = state
    tile = { "klass" => "BarnTile", "from" => "[2, 6]", "used" => false }
    assert engine(game).tile_activatable?(tile)
  end

  test "tile_activatable? is true for BarnTile alongside PaddockTile" do
    game = games(:game2player)
    game.mandatory_count = Game::MANDATORY_COUNT
    game.boards = [ [ "Barn", 0 ], [ "Paddock", 0 ], [ "Farm", 0 ], [ "Tavern", 0 ] ]
    state = BoardState.new.tap { |s| s.place_settlement(0, 0, game.current_player.order) }
    game.board_contents = state
    game.current_player.update!(
      tiles: [
        { "klass" => "MandatoryTile", "used" => false },
        { "klass" => "PaddockTile", "from" => "[2, 18]", "used" => false },
        { "klass" => "BarnTile", "from" => "[2, 6]", "used" => false }
      ]
    )
    barn_tile = game.current_player.tiles.find { |t| t["klass"] == "BarnTile" }
    assert engine(game).tile_activatable?(barn_tile)
  end

  test "tile_activatable? is false when mandatory_count is mid-build" do
    game = games(:game2player)
    game.mandatory_count = 1
    tile = { "klass" => "PaddockTile", "from" => "[2, 18]", "used" => false }
    assert_not engine(game).tile_activatable?(tile)
  end

  test "tile_activatable? is true when mandatory_count is 0" do
    game = games(:game2player)
    game.mandatory_count = 0
    game.boards = [ [ "Paddock", 0 ], [ "Oasis", 0 ], [ "Farm", 0 ], [ "Tavern", 0 ] ]
    state = BoardState.new.tap { |s| s.place_settlement(0, 0, game.current_player.order) }
    game.board_contents = state
    tile = { "klass" => "PaddockTile", "from" => "[2, 18]", "used" => false }
    assert engine(game).tile_activatable?(tile)
  end

  test "tile_activatable? is true when supply is 0 regardless of mandatory_count" do
    game = games(:game2player)
    game.mandatory_count = 1
    game.current_player.supply["settlements"] = 0
    game.boards = [ [ "Paddock", 0 ], [ "Oasis", 0 ], [ "Farm", 0 ], [ "Tavern", 0 ] ]
    state = BoardState.new.tap { |s| s.place_settlement(0, 0, game.current_player.order) }
    game.board_contents = state
    tile = { "klass" => "PaddockTile", "from" => "[2, 18]", "used" => false }
    assert engine(game).tile_activatable?(tile)
  end

  test "apply_tile_forfeit creates a forfeit_tile Move record for each forfeited tile" do
    game = games(:game2player)
    chris = game_players(:chris)
    # Settlement moved to [1,5] — not adjacent to tile location [2,7]. Tile forfeited.
    game.boards = [ [ "Oasis", 0 ], [ "Paddock", 0 ], [ "Farm", 0 ], [ "Tavern", 0 ] ]
    game.board_contents = BoardState.new.tap do |s|
      s.place_tile(2, 7, "OasisTile", 0)
      s.place_settlement(1, 7, chris.order)
    end
    game.current_action = { "type" => "paddock", "from" => "[1, 7]" }
    game.save
    chris.tiles = [ { "klass" => "OasisTile", "from" => "[2, 7]", "used" => false } ]
    chris.save

    engine(game).move_settlement(1, 5)

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
    game.boards = [ [ "Oasis", 0 ], [ "Paddock", 0 ], [ "Farm", 0 ], [ "Tavern", 0 ] ]
    game.board_contents = BoardState.new.tap do |s|
      s.place_tile(2, 7, "OasisTile", 0)
      s.place_settlement(1, 7, chris.order)
    end
    game.current_action = { "type" => "paddock", "from" => "[1, 7]" }
    game.save
    chris.tiles = [ { "klass" => "OasisTile", "from" => "[2, 7]", "used" => false } ]
    chris.save

    engine(game).move_settlement(1, 5)
    game.reload
    engine(game).undo_last_move
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
    game.board_contents = BoardState.new.tap { |s| s.place_settlement(5, 5, chris.order) }
    game.current_action = { "type" => "paddock", "from" => "[5, 5]" }
    game.save
    chris.tiles = [
      { "klass" => "MandatoryTile", "used" => false },
      { "klass" => "PaddockTile", "from" => "[6, 7]", "used" => false },
      { "klass" => "PaddockTile", "from" => "[6, 8]", "used" => false }
    ]
    chris.save

    engine(game).move_settlement(5, 7)
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
    game.board_contents = BoardState.new.tap { |s| s.place_settlement(5, 5, chris.order) }
    game.current_action = { "type" => "paddock", "from" => "[5, 5]" }
    game.save
    chris.tiles = [
      { "klass" => "MandatoryTile", "used" => false },
      { "klass" => "PaddockTile", "from" => "[6, 7]", "used" => false }
    ]
    chris.save

    engine(game).move_settlement(5, 7)
    game.reload
    engine(game).undo_last_move
    chris.reload

    paddock_tile = chris.tiles.find { |t| t["klass"] == "PaddockTile" }
    assert_not paddock_tile["used"], "PaddockTile must be unmarked after undo"
  end

  test "undo after harbor move_settlement returns piece and restores harbor current_action" do
    game = games(:game2player)
    chris = game_players(:chris)
    game.board_contents = BoardState.new.tap { |s| s.place_settlement(5, 5, chris.order) }
    game.current_action = { "type" => "harbor", "from" => "[5, 5]" }
    game.save
    chris.tiles = [ { "klass" => "HarborTile", "used" => false } ]
    chris.save

    engine(game).move_settlement(5, 7)
    game.reload
    engine(game).undo_last_move
    game.reload

    assert game.board_contents.empty?(5, 7), "settlement must leave the destination"
    assert_equal chris.order, game.board_contents.player_at(5, 5), "settlement must be back at origin"
    assert_equal "harbor", game.current_action["type"]
    assert_equal "[5, 5]", game.current_action["from"]
  end

  test "undo after harbor move_settlement unmarks HarborTile" do
    game = games(:game2player)
    chris = game_players(:chris)
    game.board_contents = BoardState.new.tap { |s| s.place_settlement(5, 5, chris.order) }
    game.current_action = { "type" => "harbor", "from" => "[5, 5]" }
    game.save
    chris.tiles = [ { "klass" => "HarborTile", "used" => false } ]
    chris.save

    engine(game).move_settlement(5, 7)
    engine(game).undo_last_move
    chris.reload

    harbor_tile = chris.tiles.find { |t| t["klass"] == "HarborTile" }
    assert_not harbor_tile["used"], "HarborTile must be unmarked after undo"
  end

  test "end_turn resets all incoming player tiles to used false" do
    game = games(:game2player)
    paula = game_players(:paula)
    paula.tiles = [
      { "klass" => "MandatoryTile", "used" => true },
      { "klass" => "PaddockTile", "from" => "[2, 18]", "used" => true }
    ]
    paula.save

    engine(game).end_turn
    paula.reload

    assert paula.tiles.all? { |t| t["used"] == false },
      "all incoming player tiles must be reset to used: false"
  end

  test "turn_endable? returns false when paddock action is in progress" do
    game = games(:game2player)
    game.mandatory_count = 0
    game.current_action = { "type" => "paddock" }
    assert_not engine(game).turn_endable?
  end

  test "turn_endable? returns false when paddock action has from selected" do
    game = games(:game2player)
    game.mandatory_count = 0
    game.current_action = { "type" => "paddock", "from" => "[5, 5]" }
    assert_not engine(game).turn_endable?
  end

  test "turn_endable? returns true when mandatory action is complete" do
    game = games(:game2player)
    game.mandatory_count = 0
    game.current_action = { "type" => "mandatory" }
    assert engine(game).turn_endable?
  end

  test "turn_endable? returns true when supply is 0 and action is mandatory" do
    game = games(:game2player)
    game.current_action = { "type" => "mandatory" }
    chris = game_players(:chris)
    chris.supply = { "settlements" => 0 }
    chris.save
    assert engine(game).turn_endable?
  end

  test "turn_state says 'must end their turn or select a tile' when mandatory done and tile is activatable" do
    game = games(:game2player)
    game.boards = [ [ "Oasis", 0 ], [ "Paddock", 0 ], [ "Farm", 0 ], [ "Tavern", 0 ] ]
    game.save
    chris = game_players(:chris)
    chris.tiles = [ { "klass" => "OasisTile", "from" => "[2, 7]", "used" => false } ]
    chris.save
    game.reload

    assert_match(/must end their turn or select a tile/, engine(game).turn_state)
  end

  test "turn_state says 'must end their turn' without tile option when no activatable tiles" do
    game = games(:game2player)

    assert_match(/must end their turn/, engine(game).turn_state)
    assert_no_match(/or select a tile/, engine(game).turn_state)
  end

  test "turn_state includes 'or select a tile' at start of turn when player has an activatable tile" do
    game = games(:game2player)
    game.boards = [ [ "Oasis", 0 ], [ "Paddock", 0 ], [ "Farm", 0 ], [ "Tavern", 0 ] ]
    game.mandatory_count = 3
    game.save
    chris = game_players(:chris)
    chris.tiles = [ { "klass" => "OasisTile", "from" => "[2, 7]", "used" => false } ]
    chris.save
    game.reload

    assert_match(/or select a tile/, engine(game).turn_state)
  end

  test "turn_state returns must move a settlement when paddock has no from" do
    game = games(:game2player)
    game.current_action = { "type" => "paddock" }
    assert_match(/must move a settlement/, engine(game).turn_state)
  end

  test "turn_state returns must move a settlement when paddock has from set" do
    game = games(:game2player)
    game.current_action = { "type" => "paddock", "from" => "[5, 5]" }
    assert_match(/must move a settlement/, engine(game).turn_state)
  end

  test "turn_state returns must move a settlement when harbor action has no from" do
    game = games(:game2player)
    game.current_action = { "type" => "harbor" }
    assert_match(/must move a settlement/, engine(game).turn_state)
  end

  test "turn_state returns must move a settlement when harbor action has from set" do
    game = games(:game2player)
    game.current_action = { "type" => "harbor", "from" => "[5, 5]" }
    assert_match(/must move a settlement/, engine(game).turn_state)
  end

  test "turn_state returns must move a settlement to a Water space when harbor action" do
    game = games(:game2player)
    game.current_action = { "type" => "harbor" }
    assert_match(/must move a settlement to a Water space/, engine(game).turn_state)
  end

  test "turn_state returns must build at the edge of the board when tower action" do
    game = games(:game2player)
    game.current_action = { "type" => "tower" }
    assert_match(/must build at the edge of the board/, engine(game).turn_state)
  end

  # Oasis tile action tests
  #
  # Oasis board at index 0, rows 0-9, cols 0-9.
  # (0,1) is Desert and adjacent to a settlement at (0,2). Used for the main build tests.
  # (7,6) is Desert, adjacent to settlement at (7,7), and adjacent to tile location (7,5).
  # This second scenario is used to test that build_on_terrain triggers tile pickup.

  test "select_action with oasis tile sets current_action type" do
    game = games(:game2player)
    chris = game_players(:chris)
    chris.tiles = [ { "klass" => "OasisTile", "from" => "[2, 7]", "used" => false } ]
    chris.save

    engine(game).select_action("oasis")
    game.reload

    assert_equal "oasis", game.current_action["type"]
  end

  test "build_on_terrain places a settlement on the target terrain hex" do
    game = game_in_oasis_action
    chris = game_players(:chris)

    engine(game).activate_tile_build(0, 1)
    game.reload

    assert_equal chris.order, game.board_contents.player_at(0, 1)
  end

  test "build_on_terrain decrements the player supply by one" do
    game = game_in_oasis_action

    engine(game).activate_tile_build(0, 1)

    assert_equal 39, game_players(:chris).reload.supply["settlements"]
  end

  test "build_on_terrain marks the activating tile as used" do
    game = game_in_oasis_action

    engine(game).activate_tile_build(0, 1)

    oasis_tile = game_players(:chris).reload.tiles.find { |t| t["klass"] == "OasisTile" }
    assert oasis_tile["used"]
  end

  test "build_on_terrain resets current_action to mandatory" do
    game = game_in_oasis_action

    engine(game).activate_tile_build(0, 1)
    game.reload

    assert_equal({ "type" => "mandatory" }, game.current_action)
  end

  test "build_on_terrain triggers tile pickup when the new settlement is adjacent to a tile location" do
    # Oasis board at index 0: tile location at (7,5). (7,6) is Desert and adjacent to both
    # the settlement at (7,7) and the location (7,5). Chris holds a tile from (2,7) only,
    # so a second pickup from (7,5) is allowed.
    game = games(:game2player)
    chris = game_players(:chris)
    game.boards = [ [ "Oasis", 0 ], [ "Paddock", 0 ], [ "Farm", 0 ], [ "Tavern", 0 ] ]
    game.board_contents = BoardState.new.tap do |s|
      s.place_tile(7, 5, "OasisTile", 2)
      s.place_settlement(7, 7, chris.order)
    end
    game.current_action = { "type" => "oasis" }
    game.save
    chris.tiles = [ { "klass" => "OasisTile", "from" => "[2, 7]", "used" => false } ]
    chris.save

    engine(game).activate_tile_build(7, 6)
    game.reload

    assert game.moves.exists?(action: "pick_up_tile"), "tile pickup must be triggered"
    assert_equal 1, game.board_contents.tile_qty(7, 5)
  end

  test "undo_last_move after build_on_terrain removes the settlement and restores supply" do
    game = game_in_oasis_action

    engine(game).activate_tile_build(0, 1)
    game.reload
    engine(game).undo_last_move
    game.reload

    assert game.board_contents.empty?(0, 1)
    assert_equal 40, game_players(:chris).reload.supply["settlements"]
  end

  test "undo_last_move after build_on_terrain unmarks the activating tile" do
    game = game_in_oasis_action

    engine(game).activate_tile_build(0, 1)
    game.reload
    engine(game).undo_last_move
    game.reload

    oasis_tile = game_players(:chris).reload.tiles.find { |t| t["klass"] == "OasisTile" }
    assert_not oasis_tile["used"]
  end

  test "undo_last_move after build_on_terrain restores current_action to the tile action type" do
    game = game_in_oasis_action

    engine(game).activate_tile_build(0, 1)
    game.reload
    engine(game).undo_last_move
    game.reload

    assert_equal "oasis", game.current_action["type"]
    assert_equal 0, game.moves.count
  end

  test "turn_state returns must build on a Desert space when oasis action" do
    game = games(:game2player)
    game.current_action = { "type" => "oasis" }
    assert_match(/must build on a Desert space/, engine(game).turn_state)
  end

  test "turn_endable? returns false when oasis action is in progress" do
    game = games(:game2player)
    game.mandatory_count = 0
    game.current_action = { "type" => "oasis" }
    assert_not engine(game).turn_endable?
  end

  test "tile_activatable? returns true for unused OasisTile when Desert hexes exist" do
    game = games(:game2player)
    game.boards = [ [ "Oasis", 0 ], [ "Paddock", 0 ], [ "Farm", 0 ], [ "Tavern", 0 ] ]
    game.board_contents = BoardState.new
    game.save
    tile = { "klass" => "OasisTile", "from" => "[2, 7]", "used" => false }
    assert engine(game).tile_activatable?(tile)
  end

  test "tile_activatable? returns false for unused OasisTile when all Desert hexes are occupied" do
    desert_hexes = [
      [ 0, 0 ], [ 0, 1 ], [ 1, 0 ], [ 2, 0 ], [ 2, 1 ], [ 5, 8 ], [ 6, 8 ], [ 7, 6 ], [ 7, 7 ], [ 8, 7 ], [ 8, 8 ],
      [ 0, 13 ], [ 0, 14 ], [ 0, 16 ], [ 0, 17 ], [ 0, 18 ], [ 0, 19 ], [ 1, 13 ], [ 1, 14 ], [ 1, 16 ], [ 1, 17 ], [ 1, 18 ], [ 1, 19 ],
      [ 2, 16 ], [ 2, 17 ], [ 3, 16 ],
      [ 10, 0 ], [ 10, 1 ], [ 10, 11 ], [ 10, 12 ], [ 10, 15 ], [ 10, 16 ], [ 11, 0 ], [ 11, 12 ], [ 11, 13 ], [ 11, 14 ],
      [ 13, 5 ], [ 13, 6 ], [ 14, 6 ], [ 14, 7 ], [ 15, 7 ], [ 15, 8 ], [ 16, 8 ], [ 16, 9 ], [ 16, 10 ],
      [ 17, 8 ], [ 17, 10 ], [ 17, 11 ], [ 18, 10 ], [ 18, 11 ], [ 18, 12 ], [ 19, 10 ], [ 19, 11 ]
    ]
    game = games(:game2player)
    game.boards = [ [ "Oasis", 0 ], [ "Paddock", 0 ], [ "Farm", 0 ], [ "Tavern", 0 ] ]
    game.board_contents = BoardState.new.tap do |s|
      desert_hexes.each { |r, c| s.place_settlement(r, c, 1) }
    end
    game.save
    tile = { "klass" => "OasisTile", "from" => "[2, 7]", "used" => false }
    assert_not engine(game).tile_activatable?(tile)
  end

  # Move payload tests
  #
  # Each action type that has non-obvious or non-deterministic data stores a
  # payload jsonb column on the Move record so events are self-describing.

  test "build stores the terrain card played in payload" do
    game = game_with_tile_at_2_7(qty: 0)  # Oasis board, Chris hand "T", build at (1,7)

    engine(game).build_settlement(1, 7)

    build_move = game.moves.find_by(action: "build")
    assert_equal "T", build_move.payload["card"]
    assert_nil build_move.payload["tile_klass"], "mandatory build must not carry a tile_klass"
  end

  test "build_on_terrain stores terrain card and tile_klass in payload" do
    game = game_in_oasis_action

    engine(game).activate_tile_build(0, 1)

    build_move = game.moves.find_by(action: "build")
    assert_equal "D", build_move.payload["card"]
    assert_equal "OasisTile", build_move.payload["tile_klass"]
  end

  test "end_turn stores card_discarded and card_drawn in payload" do
    game = games(:game2player)
    chris = game_players(:chris)
    chris.hand = "G"
    chris.save
    game.deck = [ "C", "D", "F" ]
    game.discard = []
    game.save

    engine(game).end_turn

    move = game.moves.find_by(action: "end_turn")
    assert_equal "G", move.payload["card_discarded"]
    assert_equal "C", move.payload["card_drawn"]
    assert_equal false, move.payload["reshuffled"]
  end

  test "end_turn stores reshuffled true and deck_after when deck runs out mid-draw" do
    game = games(:game2player)
    chris = game_players(:chris)
    chris.hand = "G"
    chris.save
    game.deck = [ "C" ]
    game.discard = [ "D", "F", "T" ]
    game.save

    engine(game).end_turn

    move = game.moves.find_by(action: "end_turn")
    assert_equal "G", move.payload["card_discarded"]
    assert_equal "C", move.payload["card_drawn"]
    assert_equal true, move.payload["reshuffled"]
    assert_not_empty move.payload["deck_after"]
  end

  test "pick_up_tile stores tile klass and qty_before in payload" do
    game = game_with_tile_at_2_7(qty: 2)

    engine(game).build_settlement(1, 7)

    pickup_move = game.moves.find_by(action: "pick_up_tile")
    assert_equal "OasisTile", pickup_move.payload["klass"]
    assert_equal 2, pickup_move.payload["qty_before"]
  end

  test "pick_up_tile message uses correct article for vowel-initial tile names" do
    game = game_with_tile_at_2_7(qty: 2)

    engine(game).build_settlement(1, 7)

    pickup_move = game.moves.find_by(action: "pick_up_tile")
    assert_match(/picked up an Oasis tile/, pickup_move.message)
  end

  test "forfeit_tile stores tile klass in payload" do
    game = games(:game2player)
    chris = game_players(:chris)
    game.boards = [ [ "Oasis", 0 ], [ "Paddock", 0 ], [ "Farm", 0 ], [ "Tavern", 0 ] ]
    game.board_contents = BoardState.new.tap do |s|
      s.place_tile(2, 7, "OasisTile", 0)
      s.place_settlement(1, 7, chris.order)
    end
    game.current_action = { "type" => "paddock", "from" => "[1, 7]" }
    game.save
    chris.tiles = [ { "klass" => "OasisTile", "from" => "[2, 7]", "used" => false } ]
    chris.save

    engine(game).move_settlement(1, 5)

    forfeit_move = game.moves.find_by(action: "forfeit_tile")
    assert_equal "OasisTile", forfeit_move.payload["klass"]
  end

  test "forfeit_tile message uses correct article for vowel-initial tile names" do
    game = games(:game2player)
    chris = game_players(:chris)
    game.boards = [ [ "Oasis", 0 ], [ "Paddock", 0 ], [ "Farm", 0 ], [ "Tavern", 0 ] ]
    game.board_contents = BoardState.new.tap do |s|
      s.place_tile(2, 7, "OasisTile", 0)
      s.place_settlement(1, 7, chris.order)
    end
    game.current_action = { "type" => "paddock", "from" => "[1, 7]" }
    game.save
    chris.tiles = [ { "klass" => "OasisTile", "from" => "[2, 7]", "used" => false } ]
    chris.save

    engine(game).move_settlement(1, 5)

    forfeit_move = game.moves.find_by(action: "forfeit_tile")
    assert_match(/forfeited an oasis tile/, forfeit_move.message)
  end

  test "undo after forfeit_tile restores tile klass from payload not board state" do
    # If undo read klass from board_contents it would get nil here (qty:0 entry exists
    # but we'll remove it to prove undo reads from payload instead).
    game = games(:game2player)
    chris = game_players(:chris)
    game.boards = [ [ "Oasis", 0 ], [ "Paddock", 0 ], [ "Farm", 0 ], [ "Tavern", 0 ] ]
    game.board_contents = BoardState.new.tap do |s|
      s.place_tile(2, 7, "OasisTile", 0)
      s.place_settlement(1, 7, chris.order)
    end
    game.current_action = { "type" => "paddock", "from" => "[1, 7]" }
    game.save
    chris.tiles = [ { "klass" => "OasisTile", "from" => "[2, 7]", "used" => false } ]
    chris.save

    engine(game).move_settlement(1, 5)
    game.reload

    # Remove the tile entry from board_contents so undo cannot read klass from it
    bc = game.board_contents
    bc.instance_variable_get(:@cells).delete([ 2, 7 ])
    game.board_contents = bc
    game.save

    engine(game).undo_last_move
    game.reload

    restored = game_players(:chris).reload.tiles
    assert_includes restored, { "klass" => "OasisTile", "from" => "[2, 7]", "used" => false }
  end

  # ── End-game modal ───────────────────────────────────────────────────────────

  test "winners returns the player(s) with the highest total score" do
    game = games(:game2player)
    chris = game_players(:chris)
    paula = game_players(:paula)
    game.scores = {
      chris.order.to_s => { "total" => 10 },
      paula.order.to_s => { "total" => 6 }
    }
    game.save

    assert_equal [ chris ], game.winners
  end

  test "winners returns all tied players when scores are equal" do
    game = games(:game2player)
    chris = game_players(:chris)
    paula = game_players(:paula)
    game.scores = {
      chris.order.to_s => { "total" => 8 },
      paula.order.to_s => { "total" => 8 }
    }
    game.save

    assert_equal [ chris, paula ].map(&:id).sort, game.winners.map(&:id).sort
  end

  test "winners returns empty when scores are not yet stored" do
    game = games(:game2player)
    assert_empty game.winners
  end

  # ── Live scores ──────────────────────────────────────────────────────────────

  test "live_scores returns a hash keyed by player order with goal breakdowns and total" do
    game = games(:game2player)
    game.boards = [ [ "Oasis", 0 ], [ "Paddock", 0 ], [ "Farm", 0 ], [ "Tavern", 0 ] ]
    game.goals  = [ "castles", "fishermen", "knights", "merchants" ]
    game.save

    result = game.live_scores

    assert result.key?(game_players(:chris).order.to_s)
    assert result.key?(game_players(:paula).order.to_s)
    chris_scores = result[game_players(:chris).order.to_s]
    assert chris_scores.key?("castles")
    assert chris_scores.key?("total")
  end

  # ── End-game detection ───────────────────────────────────────────────────────

  test "build_settlement sets ending when the player places their last settlement" do
    game = games(:game2player)
    game.boards = [ [ "Oasis", 0 ], [ "Paddock", 0 ], [ "Farm", 0 ], [ "Tavern", 0 ] ]
    game.mandatory_count = 1
    game.save
    chris = game_players(:chris)
    chris.update!(supply: { "settlements" => 1 }, hand: "G")

    engine(game).build_settlement(0, 7)  # OasisBoard (0,7)=G
    game.reload

    assert game.ending, "ending must be set when last settlement is placed"
  end

  test "build_settlement does not set ending when supply remains above zero" do
    game = games(:game2player)
    game.boards = [ [ "Oasis", 0 ], [ "Paddock", 0 ], [ "Farm", 0 ], [ "Tavern", 0 ] ]
    game.mandatory_count = 1
    game.save
    chris = game_players(:chris)
    chris.update!(supply: { "settlements" => 2 }, hand: "G")

    engine(game).build_settlement(0, 7)
    game.reload

    assert_not game.ending, "ending must not be set when settlements remain"
  end

  test "end_turn keeps state playing when non-last-order player ends turn while ending" do
    game = new_started_game
    game.update!(ending: true, mandatory_count: 0)
    last_player_order = game.game_players.count - 1
    non_last = game.game_players.find { |gp| gp.order != last_player_order }
    game.update!(current_player: non_last)

    engine(game).end_turn
    game.reload

    assert_equal "playing", game.state
  end

  test "end_turn completes game when last-order player ends turn while ending" do
    game = new_started_game
    last_gp = game.game_players.max_by(&:order)
    game.update!(ending: true, mandatory_count: 0, current_player: last_gp)

    engine(game).end_turn
    game.reload

    assert_equal "completed", game.state
  end

  test "complete! sets state to completed and populates scores" do
    game = new_started_game
    game.complete!
    game.reload

    assert_equal "completed", game.state
    assert_not_nil game.scores, "scores must be stored"
    assert game.scores.key?(game.game_players.first.order.to_s), "scores keyed by player order"
  end

  test "undo_last_move after last settlement clears the ending flag" do
    game = games(:game2player)
    game.boards = [ [ "Oasis", 0 ], [ "Paddock", 0 ], [ "Farm", 0 ], [ "Tavern", 0 ] ]
    game.mandatory_count = 1
    game.save
    chris = game_players(:chris)
    chris.update!(supply: { "settlements" => 1 }, hand: "G")

    engine(game).build_settlement(0, 7)
    game.reload
    assert game.ending

    engine(game).undo_last_move
    game.reload

    assert_not game.ending, "ending must be cleared after undoing the last-settlement build"
  end

  test "turn_state returns the same message as TurnEngine for playing games" do
    game = games(:game2player)
    assert_equal TurnEngine.new(game).turn_state, game.turn_state
  end

  test "turn_state returns 'Waiting for players' for waiting games" do
    assert_equal "Waiting for players", games(:chris_waiting_game).turn_state
  end

  test "broadcast_dashboard_update sends to each participant's user channel" do
    game = games(:game2player)
    chris = users(:chris)
    paula = users(:paula)

    assert_turbo_stream_broadcasts("user_#{chris.id}") do
      assert_turbo_stream_broadcasts("user_#{paula.id}") do
        game.broadcast_dashboard_update
      end
    end
  end

  test "complete! broadcasts dashboard update to participants" do
    game = games(:game2player)
    chris = users(:chris)

    assert_turbo_stream_broadcasts("user_#{chris.id}") do
      game.complete!
    end
  end

  # Board selection tests

  test "start selects 4 unique boards from the known pool" do
    game = new_started_game
    board_names = game.boards.map(&:first)
    assert_equal 4, board_names.size
    assert_equal board_names.uniq, board_names
    assert (board_names - Boards::Board::BOARD_CLASSES.keys).empty?
  end

  test "start randomizes board selection across games" do
    boards_seen = 10.times.map { new_started_game.boards.map(&:first) }
    assert boards_seen.uniq.size > 1, "expected varied board selection, got always #{boards_seen.first}"
  end

  test "broadcast_game_update broadcasts dashboard update to participants" do
    game = games(:game2player)
    chris = users(:chris)

    assert_turbo_stream_broadcasts("user_#{chris.id}") do
      game.broadcast_game_update
    end
  end

  private

  def new_started_game
    game = Game.create!(state: "waiting")
    game.add_player(users(:chris))
    game.add_player(users(:paula))
    game.start
    game.reload
    game
  end

  def engine(game)
    TurnEngine.new(game)
  end

  # Returns a saved, in-progress game using the Oasis board with a single tile
  # entry at overall coordinate [2, 7] (the first Oasis location hex).
  # Chris is the current player with hand "T"; row 1 col 7 is adjacent "T" terrain.
  def game_with_tile_at_2_7(qty:)
    game = games(:game2player)
    game.boards = [ [ "Oasis", 0 ], [ "Paddock", 0 ], [ "Farm", 0 ], [ "Tavern", 0 ] ]
    game.board_contents = BoardState.new.tap { |s| s.place_tile(2, 7, "OasisTile", qty) }
    game.save
    game
  end

  # Returns a saved game ready for the Oasis tile action.
  # Oasis board at index 0. Chris has a settlement at (0,2) making (0,1) an adjacent
  # Desert destination. Chris holds an unused OasisTile.
  def game_in_oasis_action
    game = games(:game2player)
    chris = game_players(:chris)
    game.boards = [ [ "Oasis", 0 ], [ "Paddock", 0 ], [ "Farm", 0 ], [ "Tavern", 0 ] ]
    game.board_contents = BoardState.new.tap { |s| s.place_settlement(0, 2, chris.order) }
    game.current_action = { "type" => "oasis" }
    game.save
    chris.tiles = [ { "klass" => "OasisTile", "from" => "[2, 7]", "used" => false } ]
    chris.save
    game
  end
end
