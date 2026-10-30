require "test_helper"

class SiloUiTest < ActionDispatch::IntegrationTest
  setup do
    post session_url, params: { email_address: "chris@example.com", password: "password" }
    @game = games(:game2player)
    @chris = game_players(:chris)
    @game.update!(current_action: { "type" => "silo", "silo" => 2, "of" => 4 })
    @chris.update!(supply: { "settlements" => 30, "silos" => 4 })
  end

  test "the prompt names the Silo and offers Build, Move and Skip" do
    get game_url(@game)

    assert_select "#turn-state", text: /For Silo 2 \(of 4\)/
    %w[build move skip].each do |mode|
      assert_select "form[action='#{silo_choice_game_path(@game, mode:)}'] button", text: mode.capitalize
    end
  end

  test "POST silo_choice opens the mode" do
    post silo_choice_game_url(@game, mode: "build")

    assert_equal "build", @game.reload.current_action["mode"]
  end

  test "once a mode is chosen the prompt shows End action instead of the choices" do
    @game.update!(current_action: { "type" => "silo", "silo" => 2, "of" => 4, "mode" => "build", "remaining" => 3 })

    get game_url(@game)

    assert_select "form[action='#{silo_choice_game_path(@game, mode: "skip")}']", count: 0
    assert_select "form[action='#{end_tile_action_game_path(@game)}']"
    assert_select "#turn-state", text: /For Silo 2 \(of 4\)/
  end
end
