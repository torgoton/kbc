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

    # visible: :all — the clock's presence/value is what matters here; its
    # rendered visibility is flaky only under headless-Chrome layout deferral
    # late in the single-process suite (the DOM is correct; see #265).
    assert_selector ".player-clock", minimum: 2, visible: :all
    assert_selector "form[action='#{claim_victory_game_path(game)}']"

    page.execute_script(<<~JS)
      document.querySelector("form[action='#{claim_victory_game_path(game)}']").requestSubmit()
    JS

    assert_selector "#game-area"
    assert_equal "completed", game.reload.state
    assert current.reload.resigned?
  end

  test "an opponent's claim-victory button appears live when the clock runs out, without reloading" do
    game = Game.create!(state: "waiting", speed: "blitz")
    game.add_player(users(:chris))
    game.add_player(users(:paula))
    game.start
    game.reload
    current = game.current_player
    opponent = game.game_players.find { |gp| gp != current }

    sign_in(email_address: opponent.player.email_address)
    # Set the running clock *after* sign-in so only the game-page load elapses
    # against it: the opponent arrives before the flag and watches it run out.
    current.update!(clock_started_at: Time.current, time_remaining_ms: 2_500)
    visit game_path(game)

    # Not flagged yet, so the (server-gated) claim button is present but hidden.
    assert_no_selector "form[action='#{claim_victory_game_path(game)}']"

    # The Stimulus clock ticks down to zero locally and reveals the button,
    # with no server broadcast and no page reload.
    assert_selector "form[action='#{claim_victory_game_path(game)}']", wait: 6
  end

  test "opening a blitz table via the form logs the chosen speed as the game-options move" do
    sign_in(email_address: "chris@example.com")
    visit new_game_path
    assert_selector "h1", text: "New Game"

    select_el = find("select[name='game[speed]']")
    set_field(select_el, "blitz")
    submit_form find("form[action='#{games_path}']")

    assert_selector "h1", text: "KBC Dashboard"
    game = Game.order(:id).last
    assert_equal "blitz", game.speed
    options_move = game.moves.find_by(action: "game_options")
    assert_includes options_move.message, "Blitz"
  end

  test "opening an untimed table via the form logs the untimed choice" do
    sign_in(email_address: "chris@example.com")
    visit new_game_path
    submit_form find("form[action='#{games_path}']")

    assert_selector "h1", text: "KBC Dashboard"
    game = Game.order(:id).last
    assert_nil game.speed
    options_move = game.moves.find_by(action: "game_options")
    assert_includes options_move.message, "Untimed"
  end

  test "a freshly started blitz game renders the current player's clock as not running" do
    game = Game.create!(state: "waiting", speed: "blitz")
    game.add_player(users(:chris))
    game.add_player(users(:paula))
    game.start
    game.reload

    sign_in(email_address: game.current_player.player.email_address)
    visit game_path(game)

    # visible: :all — see the claim-victory test above; the value under test is
    # the running-state attribute, not headless layout timing.
    assert_selector ".player-clock[data-clock-running-value='false']", count: 2, visible: :all
    assert_no_selector ".player-clock[data-clock-running-value='true']", visible: :all
  end

  test "the create button sits on its own row, apart from the game options" do
    sign_in(email_address: "chris@example.com")
    visit new_game_path
    assert_selector "h1", text: "New Game"

    shares_row_with_speed_option = evaluate_script(<<~JS)
      document.querySelector("select[name='game[speed]']").closest("div") ===
        document.querySelector("form[action='#{games_path}'] input[type='submit']").closest("div")
    JS
    assert_not shares_row_with_speed_option,
      "Create button should be in its own row, not beside the speed option"
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
