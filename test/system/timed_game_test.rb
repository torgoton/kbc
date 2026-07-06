require "application_system_test_case"

class TimedGameTest < ApplicationSystemTestCase
  def sign_in(email_address:, password: "password")
    visit root_url
    sign_in_panel = find("#sign-in-panel")
    email_field = sign_in_panel.find("input[name='email_address']")
    password_field = sign_in_panel.find("input[name='password']")
    set_field(email_field, email_address)
    set_field(password_field, password)
    submit_form sign_in_panel.find("form")
    assert_selector "h1", text: "KBC Dashboard"
  end

  test "blitz game shows per-player clocks and lets an opponent claim victory once flagged" do
    game = Game.create!(state: "waiting", speed: "blitz")
    game.add_player(users(:chris))
    game.add_player(users(:paula))
    game.start
    game.reload
    current = game.current_player
    opponent = game.game_players.find { |gp| gp != current }
    # Deeply negative already, with clock_started_at just now, so the player
    # reads as flagged regardless of how long the page takes to render.
    current.update!(clock_started_at: Time.current, time_remaining_ms: -100_000)

    sign_in(email_address: opponent.player.email_address)
    visit game_path(game)

    assert_selector ".player-clock", minimum: 2
    assert_selector "form[action='#{claim_victory_game_path(game)}']"

    page.execute_script(<<~JS)
      document.querySelector("form[action='#{claim_victory_game_path(game)}']").requestSubmit()
    JS

    assert_selector "#game-area"
    assert_equal "completed", game.reload.state
    assert current.reload.resigned?
  end

  test "opening and closing the timed-games help dialog does not create a game" do
    sign_in(email_address: "chris@example.com")
    visit new_game_path
    assert_selector "h1", text: "New Game"

    assert_no_difference("Game.count") do
      page.execute_script(<<~JS)
        document.querySelector("button[aria-label='What is a timed game?']").click()
      JS
      assert_selector "dialog[open]"

      page.execute_script(<<~JS)
        document.querySelector("dialog button").click()
      JS
      assert_no_selector "dialog[open]"
    end

    assert_selector "h1", text: "New Game"
  end
end
