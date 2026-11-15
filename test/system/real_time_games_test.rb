require "application_system_test_case"

class RealTimeGamesTest < ApplicationSystemTestCase
  def sign_in_as(email)
    sign_in(email_address: email)
    assert_selector "h1", text: "Dashboard"
  end

  test "real-time table is offered live to a player on the dashboard, and joining redirects both" do
    using_session(:joiner) { sign_in_as "paula@example.com" }

    sign_in_as "chris@example.com"
    click_on "Open a new table"
    select "Real Time — both of you online now, no clock", from: "game_speed"
    submit_form find("form")
    assert_selector "h1", text: "Dashboard"
    game = Game.where(realtime: true).sole

    using_session(:joiner) do
      within("#dashboard-realtime-games") { assert_text "Game #{game.id}" }
      within("#dashboard-realtime-games") { submit_form find("form") }
      assert_selector "#game-area"
    end

    assert_selector "#game-area"
    assert game.reload.playing?
  end

  test "real-time table disappears when the opener leaves the dashboard" do
    using_session(:joiner) { sign_in_as "paula@example.com" }

    sign_in_as "chris@example.com"
    click_on "Open a new table"
    select "Real Time — both of you online now, no clock", from: "game_speed"
    submit_form find("form")
    assert_selector "h1", text: "Dashboard"
    game = Game.where(realtime: true).sole

    using_session(:joiner) { within("#dashboard-realtime-games") { assert_text "Game #{game.id}" } }

    # Same effect as closing the dashboard tab (see PresenceChannelTest for the real disconnect).
    # The suite uses the :test job adapter, so run the debounced settle job by hand.
    Presence.where(user: users(:chris), kind: "dashboard").delete_all
    PresenceSettleJob.perform_now(users(:chris).id, "dashboard")
    using_session(:joiner) do
      within("#dashboard-realtime-games") { assert_no_text "Game #{game.id}", wait: 15 }
    end
  end

  test "online dots update live" do
    sign_in_as "chris@example.com"
    Game.create!(state: "waiting").tap { |g| g.add_player(users(:paula)) }
    visit dashboard_path
    assert_selector ".presence-dot.offline"

    using_session(:other) { sign_in_as "paula@example.com" }

    assert_selector ".presence-#{users(:paula).id}.online", wait: 10
  end
end
