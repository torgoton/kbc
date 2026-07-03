require "application_system_test_case"

class FortTileSystemTest < ApplicationSystemTestCase
  setup do
    @game = games(:game2player)
    @chris = game_players(:chris)

    @game.update!(
      current_action: { "type" => "mandatory" },
      mandatory_count: 0,
      deck: %w[D F G],
      discard: []
    )
    @chris.update!(
      tiles: [
        { "klass" => "FortTile", "from" => "[3, 3]", "used" => false }
      ]
    )
  end

  test "current player can open the Fort warning and activate the tile" do
    visit root_path
    within "#sign-in-panel" do
      fill_in "Enter your email address", with: "chris@example.com"
      fill_in "Enter your password", with: "password"
      click_on "Sign In"
    end
    assert_selector "h1", text: "KBC Dashboard"

    visit game_path(@game)

    assert_selector "form[action='#{activate_fort_game_path(@game)}']", visible: false
    page.execute_script("document.querySelector(\"form[action='#{activate_fort_game_path(@game)}']\").requestSubmit()")

    assert_selector "#current-action[data-type='fort']", visible: false
    assert_text "Chris drew a Desert card"
    assert_selector ".fort-drawn .player-card.card-D"
  end
end
