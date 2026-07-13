require "test_helper"

class AdminAuthorizationTest < ActionDispatch::IntegrationTest
  def sign_in_as(user)
    post session_url, params: { email_address: user.email_address, password: "password" }
  end

  test "non-admin is forbidden from the admin page" do
    sign_in_as(users(:paula))
    get admin_url
    assert_response :forbidden
  end

  test "admin can reach the admin page" do
    sign_in_as(users(:chris))
    get admin_url
    assert_response :success
  end
end
