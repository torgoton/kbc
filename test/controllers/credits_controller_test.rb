require "test_helper"

class CreditsControllerTest < ActionDispatch::IntegrationTest
  test "unauthenticated user can access credits" do
    get credits_url
    assert_response :success
  end

  test "authenticated user can access credits" do
    post session_url, params: { email_address: "chris@example.com", password: "password" }
    get credits_url
    assert_response :success
  end
end
