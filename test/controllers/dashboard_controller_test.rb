require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "unauthenticated user should redirect" do
    get dashboard_url
    assert_response :redirect
  end
end
