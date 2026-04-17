require "test_helper"
require "turbo/broadcastable/test_helper"

class GamesControllerTest < ActionDispatch::IntegrationTest
  include Turbo::Broadcastable::TestHelper

  setup do
    post session_url, params: { email_address: "chris@example.com", password: "password" }
  end

  test "game show includes a tile element for the mandatory action" do
    game = games(:game2player)
    chris = game_players(:chris)
    chris.tiles = [ { "klass" => "MandatoryTile", "used" => false } ]
    chris.save

    get game_url(game)

    assert_select ".tile-container.mandatory"
  end

  test "mandatory tile renders as tile-used when the turn is endable" do
    game = games(:game2player)
    chris = game_players(:chris)
    game.mandatory_count = 0
    game.save
    chris.tiles = [ { "klass" => "MandatoryTile", "used" => false } ]
    chris.save

    get game_url(game)

    assert_select ".player-tile.tile-used .tile-container.mandatory"
  end

  test "mandatory tile does not render as tile-used when mandatory builds remain" do
    game = games(:game2player)
    chris = game_players(:chris)
    game.mandatory_count = 3
    game.save
    chris.tiles = [ { "klass" => "MandatoryTile", "used" => false } ]
    chris.save

    get game_url(game)

    assert_select ".player-tile.tile-used .tile-container.mandatory", count: 0
  end

  test "select_action sets current_action type on the game" do
    game = games(:game2player)
    post select_action_game_url(game), params: { action_type: "paddock" }

    assert_response :redirect
    assert_equal "paddock", game.reload.current_action["type"]
  end

  test "POST action dispatches to select_settlement when paddock action has no from" do
    game = games(:game2player)
    chris = game_players(:chris)
    game.current_action = { "type" => "paddock" }
    game.board_contents = BoardState.new.tap { |s| s.place_settlement(5, 5, chris.order) }
    game.save

    post action_game_url(game), params: { build_row: 5, build_col: 5 }

    game.reload
    assert_equal "[5, 5]", game.current_action["from"], "select_settlement must have set from"
  end

  test "POST action dispatches to move_settlement when paddock action has from set" do
    game = games(:game2player)
    chris = game_players(:chris)
    game.board_contents = BoardState.new.tap { |s| s.place_settlement(5, 5, chris.order) }
    game.current_action = { "type" => "paddock", "from" => "[5, 5]" }
    game.save

    post action_game_url(game), params: { build_row: 5, build_col: 7 }

    game.reload
    assert game.board_contents.empty?(5, 5), "settlement must have moved"
    assert_equal chris.order, game.board_contents.player_at(5, 7)
  end

  test "POST action dispatches to select_settlement when harbor action has no from" do
    game = games(:game2player)
    chris = game_players(:chris)
    game.current_action = { "type" => "harbor" }
    game.board_contents = BoardState.new.tap { |s| s.place_settlement(5, 5, chris.order) }
    game.save

    post action_game_url(game), params: { build_row: 5, build_col: 5 }

    game.reload
    assert_equal "[5, 5]", game.current_action["from"], "select_settlement must have set from"
  end

  test "POST action dispatches to move_settlement when harbor action has from set" do
    game = games(:game2player)
    chris = game_players(:chris)
    game.boards = [ [ "Harbor", 0 ], [ "Paddock", 0 ], [ "Farm", 0 ], [ "Tavern", 0 ] ]
    game.board_contents = BoardState.new.tap { |s| s.place_settlement(5, 5, chris.order) }
    game.current_action = { "type" => "harbor", "from" => "[5, 5]" }
    game.save

    post action_game_url(game), params: { build_row: 0, build_col: 5 }

    game.reload
    assert game.board_contents.empty?(5, 5), "settlement must have moved from origin"
    assert_equal chris.order, game.board_contents.player_at(0, 5)
  end

  test "POST action dispatches to activate_tile_build when tower action" do
    game = games(:game2player)
    chris = game_players(:chris)
    game.boards = [ [ "Tower", 0 ], [ "Paddock", 0 ], [ "Farm", 0 ], [ "Tavern", 0 ] ]
    game.board_contents = BoardState.new.tap { |s| s.place_settlement(5, 5, chris.order) }
    game.current_action = { "type" => "tower" }
    game.save
    chris.update!(tiles: [ { "klass" => "TowerTile", "from" => "[3, 5]", "used" => false } ])

    post action_game_url(game), params: { build_row: 0, build_col: 0 }

    game.reload
    assert_equal chris.order, game.board_contents.player_at(0, 0), "tower tile must have built at border"
  end

  test "End turn button is absent for non-current player" do
    game = games(:game2player)
    post session_url, params: { email_address: "paula@example.com", password: "password" }

    get game_url(game)

    assert_select "button", text: "End turn", count: 0
  end

  test "End turn button is absent when game is completed" do
    game = games(:game2player)
    game.update!(state: "completed")

    get game_url(game)

    assert_select "button", text: "End turn", count: 0
  end

  test "POST action does nothing when the requesting player is not the current player" do
    game = games(:game2player)
    game.boards = [ [ "Tavern", 0 ], [ "Paddock", 0 ], [ "Farm", 0 ], [ "Oasis", 0 ] ]
    game.board_contents = BoardState.new
    game.mandatory_count = 3
    game.save
    post session_url, params: { email_address: "paula@example.com", password: "password" }

    post action_game_url(game), params: { build_row: 3, build_col: 6 }

    assert game.reload.board_contents.empty?(3, 6)
  end

  test "POST select_action does nothing when the requesting player is not the current player" do
    game = games(:game2player)
    post session_url, params: { email_address: "paula@example.com", password: "password" }

    post select_action_game_url(game), params: { action_type: "paddock" }

    assert_equal "mandatory", game.reload.current_action["type"]
  end

  test "POST end_turn does nothing when the requesting player is not the current player" do
    game = games(:game2player)
    post session_url, params: { email_address: "paula@example.com", password: "password" }

    post end_turn_game_url(game)

    assert_equal 0, game.reload.mandatory_count, "turn must not have advanced"
    assert_equal game_players(:chris).id, game.reload.current_player_id, "current player must not have changed"
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
    game.mandatory_count = 3
    game.save

    post end_turn_game_url(game)

    assert_equal 3, game.reload.mandatory_count
  end

  test "game show renders a button for an activatable PaddockTile" do
    game = games(:game2player)
    game.boards = [ [ "Paddock", 0 ], [ "Oasis", 0 ], [ "Farm", 0 ], [ "Tavern", 0 ] ]
    state = BoardState.new.tap { |s| s.place_settlement(0, 0, game.current_player.order) }
    game.board_contents = state
    game.save!
    chris = game_players(:chris)
    chris.tiles = [
      { "klass" => "MandatoryTile", "used" => false },
      { "klass" => "PaddockTile", "from" => "[2, 18]", "used" => false }
    ]
    chris.save

    get game_url(game)

    assert_select "form[action='#{select_action_game_path(game)}'] button", minimum: 1
  end

  test "game show does not render tile action buttons when it is not the viewer's turn" do
    game = games(:game2player)
    game.boards = [ [ "Oasis", 0 ], [ "Paddock", 0 ], [ "Farm", 0 ], [ "Tavern", 0 ] ]
    game.mandatory_count = 0
    game.save
    paula = game_players(:paula)
    paula.tiles = [
      { "klass" => "MandatoryTile", "used" => false },
      { "klass" => "OasisTile", "from" => "[2, 7]", "used" => false }
    ]
    paula.save
    post session_url, params: { email_address: "paula@example.com", password: "password" }

    get game_url(game)

    assert_select "form[action='#{select_action_game_path(game)}'] button", count: 0
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

  test "POST action dispatches to place_wall when quarry action" do
    game = games(:game2player)
    chris = game_players(:chris)
    game.boards = [ [ "Tavern", 0 ], [ "Paddock", 0 ], [ "Farm", 0 ], [ "Oasis", 0 ] ]
    game.board_contents = BoardState.new.tap { |s| s.place_settlement(3, 5, chris.order) }
    game.current_action = { "type" => "quarry", "walls_placed" => 0 }
    game.save
    chris.update!(tiles: [ { "klass" => "QuarryTile", "from" => "[2, 0]", "used" => false } ])

    post action_game_url(game), params: { build_row: 3, build_col: 6 }

    assert_equal "Wall", game.reload.board_contents.tile_klass(3, 6), "quarry action must place a wall, not a settlement"
  end

  test "POST action auto-ends quarry action when no valid walls remain after first placement" do
    game = games(:game2player)
    chris = game_players(:chris)
    game.boards = [ [ "Tavern", 0 ], [ "Paddock", 0 ], [ "Farm", 0 ], [ "Oasis", 0 ] ]
    game.board_contents = BoardState.new.tap { |s| s.place_settlement(3, 5, chris.order) }
    game.current_action = { "type" => "quarry", "walls_placed" => 0 }
    game.save
    chris.update!(tiles: [ { "klass" => "QuarryTile", "from" => "[2, 0]", "used" => false } ])

    post action_game_url(game), params: { build_row: 3, build_col: 6 }

    assert_equal "mandatory", game.reload.current_action["type"], "quarry action must auto-end when no valid placements remain"
  end

  test "GET new renders the new game form" do
    get new_game_url
    assert_response :success
  end

  test "POST create creates a game and redirects to dashboard" do
    assert_difference("Game.count", 1) do
      post games_url
    end
    assert_redirected_to dashboard_path
  end

  test "POST action with mandatory current_action dispatches build_settlement" do
    game = games(:game2player)
    game.boards = [ [ "Oasis", 0 ], [ "Paddock", 0 ], [ "Farm", 0 ], [ "Tavern", 0 ] ]
    game.board_contents = BoardState.new
    game.current_action = { "type" => "mandatory" }
    game.save

    post action_game_url(game), params: { build_row: 1, build_col: 7 }

    assert_equal game_players(:chris).order, game.reload.board_contents.player_at(1, 7)
  end

  test "POST action with oasis current_action dispatches activate_tile_build" do
    game = games(:game2player)
    chris = game_players(:chris)
    game.boards = [ [ "Oasis", 0 ], [ "Paddock", 0 ], [ "Farm", 0 ], [ "Tavern", 0 ] ]
    game.board_contents = BoardState.new.tap { |s| s.place_settlement(0, 2, chris.order) }
    game.current_action = { "type" => "oasis" }
    game.save
    chris.tiles = [ { "klass" => "OasisTile", "from" => "[2, 7]", "used" => false } ]
    chris.save

    post action_game_url(game), params: { build_row: 0, build_col: 1 }

    assert_equal chris.order, game.reload.board_contents.player_at(0, 1)
  end

  test "POST action with donation tile current_action dispatches activate_tile_build" do
    game = games(:game2player)
    chris = game_players(:chris)
    # OasisBoard has Desert at [0,0]; place settlement elsewhere so fallback path is used
    game.boards = [ [ "Oasis", 0 ], [ "Paddock", 0 ], [ "Farm", 0 ], [ "Tavern", 0 ] ]
    game.board_contents = BoardState.new.tap { |s| s.place_settlement(5, 5, chris.order) }
    game.current_action = { "type" => "donationdesert", "klass" => "DonationDesertTile", "remaining" => 3 }
    game.save
    chris.tiles = [ { "klass" => "DonationDesertTile", "from" => "[0, 5]", "used" => false } ]
    chris.save

    post action_game_url(game), params: { build_row: 0, build_col: 0 }

    assert_equal chris.order, game.reload.board_contents.player_at(0, 0)
  end

  test "GET show as turbo_stream renders without error" do
    get game_url(games(:game2player)), as: :turbo_stream

    assert_response :success
  end

  test "POST join adds the current user to the game" do
    game = Game.create!(state: "waiting")
    game.add_player(users(:chris))

    post session_url, params: { email_address: "paula@example.com", password: "password" }
    post join_game_url(game)

    assert_includes game.reload.players, users(:paula)
  end

  test "POST join redirects to the game" do
    game = Game.create!(state: "waiting")
    game.add_player(users(:chris))

    post session_url, params: { email_address: "paula@example.com", password: "password" }
    post join_game_url(game)

    assert_redirected_to game_path(game)
  end

  test "POST undo_move redirects to the game" do
    game = games(:game2player)
    post undo_move_game_url(game)
    assert_redirected_to game_path(game)
  end

  test "POST action does nothing when game is completed" do
    game = games(:game2player)
    game.update!(state: "completed")
    move_count_before = game.moves.count

    post action_game_url(game), params: { build_row: 0, build_col: 0 }, as: :turbo_stream

    assert_equal move_count_before, game.moves.count
  end

  test "POST select_action does nothing when game is completed" do
    game = games(:game2player)
    game.update!(state: "completed")
    action_before = game.current_action

    post select_action_game_url(game), params: { action_type: "oasis" }, as: :turbo_stream

    assert_equal action_before, game.reload.current_action
  end

  test "POST end_turn does nothing when game is completed" do
    game = games(:game2player)
    game.update!(state: "completed", mandatory_count: 0)
    move_count_before = game.moves.count

    post end_turn_game_url(game), as: :turbo_stream

    assert_equal move_count_before, game.moves.count
  end

  test "POST undo_move does nothing when game is completed" do
    game = games(:game2player)
    game.update!(state: "completed")
    move_count_before = game.moves.count

    post undo_move_game_url(game), as: :turbo_stream

    assert_equal move_count_before, game.moves.count
  end

  test "POST create broadcasts dashboard update to non-participating users" do
    paula = users(:paula)

    assert_turbo_stream_broadcasts("user_#{paula.id}") do
      post games_url
    end
  end

  test "join broadcasts dashboard update to the joining user" do
    post session_url, params: { email_address: "paula@example.com", password: "password" }
    paula = users(:paula)

    assert_turbo_stream_broadcasts("user_#{paula.id}") do
      post join_game_url(games(:waiting_game))
    end
  end

  test "join broadcasts game update so waiting players see the game start" do
    game = games(:waiting_game)
    post session_url, params: { email_address: "paula@example.com", password: "password" }

    assert_turbo_stream_broadcasts("game_#{game.id}") do
      post join_game_url(game)
    end
  end
end

class GamesControllerUnauthenticatedTest < ActionDispatch::IntegrationTest
  test "GET show redirects to login when not authenticated" do
    get game_url(games(:game2player))
    assert_redirected_to new_session_path
  end

  test "POST action redirects to login when not authenticated" do
    post action_game_url(games(:game2player)), params: { build_row: 0, build_col: 0 }
    assert_redirected_to new_session_path
  end
end
