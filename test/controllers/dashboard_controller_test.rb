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
end
