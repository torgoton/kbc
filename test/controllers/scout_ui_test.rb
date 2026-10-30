require "test_helper"

class ScoutUiTest < ActionDispatch::IntegrationTest
  setup do
    post session_url, params: { email_address: "chris@example.com", password: "password" }
  end

  test "a scout renders as a person token in its player's colour, not as a settlement" do
    game = games(:game2player)
    game.board_contents = BoardState.new.tap { |s| s.place_scout(5, 4, 0) }
    game.save!

    get game_url(game)

    assert_select "#map-cell-5-4 svg.hex-scout path[fill='#{GamesHelper::PLAYER_COLORS[0]}']"
    assert_select "#map-cell-5-4 svg.hex-settlement", count: 0
  end
end
