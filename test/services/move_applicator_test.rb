require "test_helper"

class MoveApplicatorTest < ActiveSupport::TestCase
  # ---------------------------------------------------------------------------
  # select_action
  # ---------------------------------------------------------------------------

  test "dispatch select_action sets current_action" do
    state = minimal_state
    move = fake_move(action: "select_action", to: "oasis")

    MoveApplicator.dispatch(state, move)

    assert_equal({ "type" => "oasis" }, state.current_action)
  end

  # ---------------------------------------------------------------------------
  # move_settlement
  # ---------------------------------------------------------------------------

  test "dispatch move_settlement moves settlement on board and resets current_action" do
    board = BoardState.new
    board.place_settlement(5, 5, 0)
    snap_board = BoardState.dump(board)

    state = minimal_state(
      "board_contents" => snap_board,
      "current_action" => { "type" => "paddock", "from" => "[5, 5]" },
      "players" => [ { "order" => 0, "hand" => "G", "supply" => { "settlements" => 40 },
                       "tiles" => [ { "klass" => "PaddockTile", "from" => "[2, 0]", "used" => false } ] } ]
    )
    move = fake_move(action: "move_settlement", from: "[5, 5]", to: "[5, 7]", payload: { "tile_klass" => "PaddockTile" })

    MoveApplicator.dispatch(state, move)

    assert state.board.empty?(5, 5)
    assert_equal 0, state.board.player_at(5, 7)
    assert_equal({ "type" => "mandatory" }, state.current_action)
    used_tile = state.players[0]["tiles"].find { |t| t["klass"] == "PaddockTile" }
    assert used_tile["used"]
  end

  # ---------------------------------------------------------------------------
  # pick_up_tile
  # ---------------------------------------------------------------------------

  test "dispatch pick_up_tile decrements tile qty and gives tile to player" do
    board = BoardState.new
    board.place_tile(2, 7, "OasisTile", 2)
    state = minimal_state("board_contents" => BoardState.dump(board))
    move = fake_move(action: "pick_up_tile", from: "[2, 7]", payload: { "klass" => "OasisTile", "qty_before" => 2 })

    MoveApplicator.dispatch(state, move)

    assert_equal 1, state.board.tile_qty(2, 7)
    tiles = state.players[0]["tiles"]
    assert_equal 1, tiles.size
    assert_equal "OasisTile", tiles.first["klass"]
    assert_equal "[2, 7]", tiles.first["from"]
    assert tiles.first["used"], "tile picked up mid-turn should be marked used (unavailable until next turn)"
  end

  # ---------------------------------------------------------------------------
  # forfeit_tile
  # ---------------------------------------------------------------------------

  test "dispatch forfeit_tile removes tile from player" do
    state = minimal_state(
      "players" => [ { "order" => 0, "hand" => "G", "supply" => { "settlements" => 40 },
                       "tiles" => [ { "klass" => "OasisTile", "from" => "[2, 7]", "used" => false } ] } ]
    )
    move = fake_move(action: "forfeit_tile", from: "[2, 7]", to: "false", payload: { "klass" => "OasisTile" })

    MoveApplicator.dispatch(state, move)

    assert_empty state.players[0]["tiles"]
  end

  # ---------------------------------------------------------------------------
  # build
  # ---------------------------------------------------------------------------

  test "dispatch build places settlement, decrements supply, decrements mandatory_count" do
    state = minimal_state
    move = fake_move(action: "build", to: "[3, 4]", payload: { "card" => "G" })

    MoveApplicator.dispatch(state, move)

    assert_equal 0, state.board.player_at(3, 4)
    assert_equal 39, state.players[0]["supply"]["settlements"]
    assert_equal 2, state.mandatory_count
  end

  test "dispatch build with tile_klass marks tile used and resets current_action" do
    state = minimal_state(
      "current_action" => { "type" => "oasis" },
      "players" => [ { "order" => 0, "hand" => "G", "supply" => { "settlements" => 40 },
                       "tiles" => [ { "klass" => "OasisTile", "from" => "[2, 7]", "used" => false } ] } ]
    )
    move = fake_move(action: "build", to: "[0, 1]", payload: { "card" => "D", "tile_klass" => "OasisTile" })

    MoveApplicator.dispatch(state, move)

    assert_equal 0, state.board.player_at(0, 1)
    assert_equal({ "type" => "mandatory" }, state.current_action)
    assert state.players[0]["tiles"].first["used"]
  end

  # ---------------------------------------------------------------------------
  # end_turn
  # ---------------------------------------------------------------------------

  test "dispatch end_turn advances player order and resets next player's tiles" do
    # Player 1's used tile should be reset when player 0 ends their turn.
    state = minimal_state(
      "deck" => [ "T", "G" ],
      "current_player_order" => 0,
      "players" => [
        { "order" => 0, "hand" => "G", "supply" => { "settlements" => 40 }, "tiles" => [] },
        { "order" => 1, "hand" => "T", "supply" => { "settlements" => 40 },
          "tiles" => [ { "klass" => "FarmTile", "from" => "[0, 0]", "used" => true } ] }
      ]
    )
    move = fake_move(action: "end_turn", payload: {
      "card_discarded" => "G", "card_drawn" => "T", "reshuffled" => false, "deck_after" => [ "T", "G" ]
    })

    MoveApplicator.dispatch(state, move)

    assert_equal 1, state.current_player_order
    assert_equal 3, state.mandatory_count
    assert_equal({ "type" => "mandatory" }, state.current_action)
    assert_equal false, state.players[1]["tiles"].first["used"]
  end

  test "dispatch end_turn with reshuffle rebuilds deck from payload" do
    # discard=["D","F"], player discards "G" → discard becomes ["D","F","G"] before reshuffle.
    # reshuffle moves all of discard into the new deck, so "G" is included.
    state = minimal_state(
      "deck" => [ "C" ],
      "discard" => [ "D", "F" ],
      "current_player_order" => 0,
      "players" => [
        { "order" => 0, "hand" => "G", "supply" => { "settlements" => 40 }, "tiles" => [] },
        { "order" => 1, "hand" => "T", "supply" => { "settlements" => 40 }, "tiles" => [] }
      ]
    )
    move = fake_move(action: "end_turn", payload: {
      "card_discarded" => "G", "card_drawn" => "C", "reshuffled" => true, "deck_after" => [ "F", "G", "D" ]
    })

    MoveApplicator.dispatch(state, move)

    assert_equal [ "F", "G", "D" ], state.deck
    assert_empty state.discard
  end

  # ---------------------------------------------------------------------------
  # activate_outpost
  # ---------------------------------------------------------------------------

  test "dispatch activate_outpost marks OutpostTile used and sets outpost_active" do
    state = minimal_state(
      "current_action" => { "type" => "mandatory" },
      "players" => [ { "order" => 0, "hand" => "G", "supply" => { "settlements" => 40 },
                       "tiles" => [ { "klass" => "OutpostTile", "from" => "[3, 3]", "used" => false } ] } ]
    )
    move = fake_move(action: "activate_outpost")

    MoveApplicator.dispatch(state, move)

    assert state.current_action["outpost_active"]
    outpost = state.players[0]["tiles"].find { |t| t["klass"] == "OutpostTile" }
    assert outpost["used"]
  end

  # ---------------------------------------------------------------------------
  # activate_fort
  # ---------------------------------------------------------------------------

  test "dispatch activate_fort calls apply_activate_fort" do
    state = minimal_state("current_action" => { "type" => "mandatory" })
    move = fake_move(action: "activate_fort")

    MoveApplicator.dispatch(state, move)

    # apply_activate_fort is a no-op in HashState; just confirm no error raised
    assert_equal({ "type" => "mandatory" }, state.current_action)
  end

  test "dispatch draw_fort_card sets fort_terrain in current_action and updates deck" do
    state = minimal_state(
      "current_action" => { "type" => "mandatory" },
      "deck" => %w[G D F],
      "discard" => []
    )
    move = fake_move(
      action: "draw_fort_card",
      payload: { "card" => "D", "deck_after" => %w[G F], "discard_after" => [] }
    )

    MoveApplicator.dispatch(state, move)

    assert_equal "fort", state.current_action["type"]
    assert_equal "FortTile", state.current_action["klass"]
    assert_equal "D", state.current_action["fort_terrain"]
    assert_equal %w[G F], state.deck
  end

  test "dispatch build with FortTile fort_terrain places settlement and resets current_action to mandatory" do
    state = minimal_state(
      "current_action" => { "type" => "fort", "klass" => "FortTile", "fort_terrain" => "D" },
      "players" => [ { "order" => 0, "hand" => "G", "supply" => { "settlements" => 40 },
                       "tiles" => [ { "klass" => "FortTile", "from" => "[3, 3]", "used" => false } ] } ]
    )
    move = fake_move(action: "build", to: "[5, 5]", payload: { "card" => "D", "tile_klass" => "FortTile" })

    MoveApplicator.dispatch(state, move)

    assert_equal({ "type" => "mandatory" }, state.current_action)
    assert_equal 39, state.players[0]["supply"]["settlements"]
    fort = state.players[0]["tiles"].find { |t| t["klass"] == "FortTile" }
    assert fort["used"]
  end

  # ---------------------------------------------------------------------------
  # select_settlement
  # ---------------------------------------------------------------------------

  test "dispatch select_settlement merges from into current_action" do
    state = minimal_state("current_action" => { "type" => "paddock" })
    move = fake_move(action: "select_settlement", from: "[5, 5]")

    MoveApplicator.dispatch(state, move)

    assert_equal({ "type" => "paddock", "from" => "[5, 5]" }, state.current_action)
  end

  test "dispatch select_ship stores from for lighthouse action" do
    state = minimal_state("current_action" => { "type" => "lighthouse", "klass" => "LighthouseTile" })
    move = fake_move(action: "select_ship", from: "[0, 3]")

    MoveApplicator.dispatch(state, move)

    assert_equal({ "type" => "lighthouse", "klass" => "LighthouseTile", "from" => "[0, 3]" }, state.current_action)
  end

  test "dispatch move_ship can use explicit phase_after payload" do
    board = BoardState.new
    board.place_ship(0, 3, 0)
    state = minimal_state(
      "board_contents" => BoardState.dump(board),
      "current_action" => { "type" => "lighthouse", "klass" => "LighthouseTile", "from" => "[0, 3]" },
      "players" => [ { "order" => 0, "hand" => "G", "supply" => { "settlements" => 40 },
                       "tiles" => [ { "klass" => "LighthouseTile", "from" => "[2, 0]", "used" => false } ] } ]
    )
    move = fake_move(
      action: "move_ship",
      from: "[0, 3]",
      to: "[0, 4]",
      payload: {
        "action_before" => { "type" => "lighthouse", "klass" => "LighthouseTile", "from" => "[0, 3]" },
        "phase_after" => { "type" => "mandatory" }
      }
    )

    MoveApplicator.dispatch(state, move)

    assert state.board.empty?(0, 3)
    assert state.board.ship_at?(0, 4)
    assert_equal({ "type" => "mandatory" }, state.current_action)
  end

  test "dispatch place_ship marks LighthouseTile used and resets current_action" do
    state = minimal_state(
      "current_action" => { "type" => "lighthouse", "klass" => "LighthouseTile" },
      "players" => [ { "order" => 0, "hand" => "G", "supply" => { "settlements" => 40, "ships" => 1 },
                       "tiles" => [ { "klass" => "LighthouseTile", "from" => "[2, 7]", "used" => false } ] } ]
    )
    move = fake_move(action: "place_ship", to: "[0, 1]", payload: {
      "action_before" => { "type" => "lighthouse", "klass" => "LighthouseTile" }
    })

    MoveApplicator.dispatch(state, move)

    assert_equal({ "type" => "mandatory" }, state.current_action)
    assert_equal 0, state.players[0]["supply"]["ships"]
    assert state.board.ship_at?(0, 1)
    assert state.players[0]["tiles"].first["used"]
  end

  test "dispatch remove_ship marks LighthouseTile used and resets current_action" do
    board = BoardState.new
    board.place_ship(0, 1, 0)
    state = minimal_state(
      "board_contents" => BoardState.dump(board),
      "current_action" => { "type" => "lighthouse", "klass" => "LighthouseTile" },
      "players" => [ { "order" => 0, "hand" => "G", "supply" => { "settlements" => 40, "ships" => 0 },
                       "tiles" => [ { "klass" => "LighthouseTile", "from" => "[2, 7]", "used" => false } ] } ]
    )
    move = fake_move(action: "remove_ship", from: "[0, 1]", payload: {
      "action_before" => { "type" => "lighthouse", "klass" => "LighthouseTile" }
    })

    MoveApplicator.dispatch(state, move)

    assert_equal({ "type" => "mandatory" }, state.current_action)
    assert_equal 1, state.players[0]["supply"]["ships"]
    assert state.board.empty?(0, 1)
    assert state.players[0]["tiles"].first["used"]
  end

  test "dispatch place_wagon marks WagonTile used and resets current_action" do
    state = minimal_state(
      "current_action" => { "type" => "wagon", "klass" => "WagonTile" },
      "players" => [ { "order" => 0, "hand" => "G", "supply" => { "settlements" => 40, "wagons" => 1 },
                       "tiles" => [ { "klass" => "WagonTile", "from" => "[2, 7]", "used" => false } ] } ]
    )
    move = fake_move(action: "place_wagon", to: "[0, 1]", payload: {
      "action_before" => { "type" => "wagon", "klass" => "WagonTile" }
    })

    MoveApplicator.dispatch(state, move)

    assert_equal({ "type" => "mandatory" }, state.current_action)
    assert_equal 0, state.players[0]["supply"]["wagons"]
    assert state.board.wagon_at?(0, 1)
    assert state.players[0]["tiles"].first["used"]
  end

  test "dispatch remove_wagon marks WagonTile used and resets current_action" do
    board = BoardState.new
    board.place_wagon(0, 1, 0)
    state = minimal_state(
      "board_contents" => BoardState.dump(board),
      "current_action" => { "type" => "wagon", "klass" => "WagonTile" },
      "players" => [ { "order" => 0, "hand" => "G", "supply" => { "settlements" => 40, "wagons" => 0 },
                       "tiles" => [ { "klass" => "WagonTile", "from" => "[2, 7]", "used" => false } ] } ]
    )
    move = fake_move(action: "remove_wagon", from: "[0, 1]", payload: {
      "action_before" => { "type" => "wagon", "klass" => "WagonTile" }
    })

    MoveApplicator.dispatch(state, move)

    assert_equal({ "type" => "mandatory" }, state.current_action)
    assert_equal 1, state.players[0]["supply"]["wagons"]
    assert state.board.empty?(0, 1)
    assert state.players[0]["tiles"].first["used"]
  end

  test "dispatch select_action for sword preserves pending orders from payload" do
    state = minimal_state(
      "players" => [
        { "order" => 0, "hand" => "G", "supply" => { "settlements" => 40 }, "tiles" => [] },
        { "order" => 1, "hand" => "T", "supply" => { "settlements" => 40 }, "tiles" => [] }
      ]
    )
    move = fake_move(action: "select_action", to: "sword", payload: { "klass" => "SwordTile", "pending_orders" => [1] })

    MoveApplicator.dispatch(state, move)

    assert_equal({ "type" => "sword", "klass" => "SwordTile", "pending_orders" => [1] }, state.current_action)
  end

  test "dispatch place_warrior marks BarracksTile used and resets current_action" do
    state = minimal_state(
      "current_action" => { "type" => "barracks", "klass" => "BarracksTile" },
      "players" => [ { "order" => 0, "hand" => "G", "supply" => { "settlements" => 40, "warriors" => 2 },
                       "tiles" => [ { "klass" => "BarracksTile", "from" => "[2, 7]", "used" => false } ] } ]
    )
    move = fake_move(action: "place_warrior", to: "[0, 1]", payload: {
      "action_before" => { "type" => "barracks", "klass" => "BarracksTile" }
    })

    MoveApplicator.dispatch(state, move)

    assert_equal({ "type" => "mandatory" }, state.current_action)
    assert_equal 1, state.players[0]["supply"]["warriors"]
    assert state.board.warrior_at?(0, 1)
    assert state.players[0]["tiles"].first["used"]
  end

  test "dispatch remove_warrior marks BarracksTile used and resets current_action" do
    board = BoardState.new
    board.place_warrior(0, 1, 0)
    state = minimal_state(
      "board_contents" => BoardState.dump(board),
      "current_action" => { "type" => "barracks", "klass" => "BarracksTile" },
      "players" => [ { "order" => 0, "hand" => "G", "supply" => { "settlements" => 40, "warriors" => 1 },
                       "tiles" => [ { "klass" => "BarracksTile", "from" => "[2, 7]", "used" => false } ] } ]
    )
    move = fake_move(action: "remove_warrior", from: "[0, 1]", payload: {
      "action_before" => { "type" => "barracks", "klass" => "BarracksTile" }
    })

    MoveApplicator.dispatch(state, move)

    assert_equal({ "type" => "mandatory" }, state.current_action)
    assert_equal 2, state.players[0]["supply"]["warriors"]
    assert state.board.empty?(0, 1)
    assert state.players[0]["tiles"].first["used"]
  end

  private

  def minimal_state(overrides = {})
    snap = {
      "board_contents" => [],
      "boards" => [],
      "deck" => [],
      "discard" => [],
      "goals" => [],
      "mandatory_count" => 3,
      "current_action" => { "type" => "mandatory" },
      "current_player_order" => 0,
      "players" => [ { "order" => 0, "hand" => "G", "supply" => { "settlements" => 40 }, "tiles" => [] } ]
    }.merge(overrides)
    MoveApplicator::HashState.new(snap)
  end

  def fake_move(action:, player_order: 0, from: nil, to: nil, payload: nil)
    gp = Struct.new(:order).new(player_order)
    Struct.new(:action, :from, :to, :payload, :game_player).new(action, from, to, payload, gp)
  end
end
