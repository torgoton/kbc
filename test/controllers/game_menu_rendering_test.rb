require "test_helper"

class GameMenuRenderingTest < ActionDispatch::IntegrationTest
  test "a player in a game that is playing sees the resign link" do
    post session_url, params: { email_address: "chris@example.com", password: "password" }
    game = games(:game2player)

    get game_url(game)

    assert_select "a[href='#{resign_game_path(game)}']"
  end

  test "a player in a game that is completed does not see the resign link" do
    post session_url, params: { email_address: "chris@example.com", password: "password" }
    game = games(:completed_game)

    get game_url(game)

    assert_select "a[href='#{resign_game_path(game)}']", count: 0
  end
end
