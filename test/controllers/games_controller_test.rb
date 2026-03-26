require "test_helper"

class GamesControllerTest < ActionDispatch::IntegrationTest
  setup do
    post session_url, params: { email_address: "chris@example.com", password: "password" }
  end

  test "game show includes a tile element for the mandatory action" do
    game = games(:game2player)
    chris = game_players(:chris)
    chris.tiles = [ { "klass" => "MandatoryTile", "used" => false } ]
    chris.save

    get game_url(game)

    assert_select ".player-tile.mandatory"
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

    post action_game_url(game), params: { build_cell: "map-cell-5-5" }

    game.reload
    assert_equal "[5, 5]", game.current_action["from"], "select_settlement must have set from"
  end

  test "POST action dispatches to move_settlement when paddock action has from set" do
    game = games(:game2player)
    chris = game_players(:chris)
    game.board_contents = BoardState.new.tap { |s| s.place_settlement(5, 5, chris.order) }
    game.current_action = { "type" => "paddock", "from" => "[5, 5]" }
    game.save

    post action_game_url(game), params: { build_cell: "map-cell-5-7" }

    game.reload
    assert game.board_contents.empty?(5, 5), "settlement must have moved"
    assert_equal chris.order, game.board_contents.player_at(5, 7)
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
end
