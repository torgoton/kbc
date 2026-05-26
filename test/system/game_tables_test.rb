require "application_system_test_case"

class GameTablesTest < ApplicationSystemTestCase
  def sign_in(email_address:, password: "password")
    visit root_url
    sign_in_panel = find("#sign-in-panel")
    email_field = sign_in_panel.find("input[name='email_address']")
    password_field = sign_in_panel.find("input[name='password']")
    set_field(email_field, email_address)
    set_field(password_field, password)
    assert_equal email_address, email_field.value
    assert_equal password, password_field.value
    submit_form sign_in_panel.find("form")
    assert_selector "h1", text: "KBC Dashboard"
  end

  def sign_out
    submit_form find("#logout_btn form")
    assert_selector "h2", text: "Sign in"
  end

  test "approved users can create and join a game table" do
    existing_game_ids = Game.ids

    sign_in(email_address: "chris@example.com")

    click_on "Open a new table"
    assert_selector "h1", text: "New Game"
    submit_form find("form")

    assert_selector "h1", text: "KBC Dashboard"
    created_game = Game.where.not(id: existing_game_ids).sole
    assert_text "Game #{created_game.id}"
    assert_text "Waiting for players"

    sign_out
    sign_in(email_address: "paula@example.com")

    assert_text "Game #{created_game.id}"
    within(:xpath, "//tr[.//td[contains(., 'Game #{created_game.id}')]]") do
      submit_form find("form")
    end

    assert_selector "#game-area"
    assert created_game.reload.playing?
    assert_equal 2, created_game.game_players.count
  end

  test "game page registers the play_sound turbo stream action" do
    sign_in(email_address: "chris@example.com")

    visit game_path(games(:game2player))

    assert_selector "#game-area"
    assert_equal true, page.evaluate_script("typeof Turbo.StreamActions.play_sound === 'function'")
  end
end
