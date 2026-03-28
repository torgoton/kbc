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
end
