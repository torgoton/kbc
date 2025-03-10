require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "should get login screen" do
    get new_session_url
    assert_response :success
  end

  test "bad credentials should report" do
    post new_session_url, params: { user: {} }
    assert_response :not_found
  end

  test "bad credentials should redirect" do
    post new_session_url, params: { user: {} }
    assert_response :not_found
  end
end
