require "test_helper"

class GamesControllerTest < ActionDispatch::IntegrationTest
  setup do
    post session_url, params: { email_address: "chris@example.com", password: "password" }
  end

  test "game show includes a tile element for the mandatory action" do
    game = games(:game2player)
    chris = game_players(:chris)
    chris.tiles = [ { "klass" => "Mandatory", "used" => false } ]
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
end
