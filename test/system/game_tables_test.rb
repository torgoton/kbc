require "application_system_test_case"

class GameTablesTest < ApplicationSystemTestCase
  def sign_in(email_address:, password: "password")
    visit root_url
    within "#sign-in-panel" do
      fill_in "Enter your email address", with: email_address
      fill_in "Enter your password", with: password
      click_on "Sign In"
    end
    assert_selector "h1", text: "KBC Dashboard"
  end

  def sign_out
    click_on "Log out"
    assert_selector "h2", text: "Sign in"
  end

  test "approved users can create and join a game table" do
    existing_game_ids = Game.ids

    sign_in(email_address: "chris@example.com")

    click_on "Open a new table"
    assert_selector "h1", text: "New Game"
    click_on "Create Game"

    assert_selector "h1", text: "KBC Dashboard"
    created_game = Game.where.not(id: existing_game_ids).sole
    assert_text "Game #{created_game.id}"
    assert_text "Waiting for players"

    sign_out
    sign_in(email_address: "paula@example.com")

    assert_text "Game #{created_game.id}"
    within(:xpath, "//tr[.//td[contains(., 'Game #{created_game.id}')]]") do
      click_on "Join"
    end

    assert_selector "#game-area"
    assert created_game.reload.playing?
    assert_equal 2, created_game.game_players.count
  end
end
