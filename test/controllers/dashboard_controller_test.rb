require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "unauthenticated user should redirect" do
    get dashboard_url
    assert_response :redirect
  end

  test "authenticated user sees dashboard" do
    post session_url, params: { email_address: "chris@example.com", password: "password" }
    get dashboard_url
    assert_response :success
  end

  test "waiting tables list shows each creator's rating badge" do
    post session_url, params: { email_address: "chris@example.com", password: "password" }

    get dashboard_url

    assert_select "td", text: /Paula \(1500\?\)/
  end

  test "waiting tables list shows a speed badge for a timed table" do
    game = Game.create!(state: "waiting", speed: "blitz")
    game.add_player(users(:paula))
    post session_url, params: { email_address: "chris@example.com", password: "password" }

    get dashboard_url

    assert_select ".speed-badge", { text: /Blitz/, count: 1 }
  end

  test "my games list shows a speed badge for a timed game" do
    game = Game.create!(state: "waiting", speed: "normal")
    game.add_player(users(:chris))
    game.add_player(users(:paula))
    game.start
    post session_url, params: { email_address: "chris@example.com", password: "password" }

    get dashboard_url

    assert_select ".speed-badge", text: /Normal/
  end
end
