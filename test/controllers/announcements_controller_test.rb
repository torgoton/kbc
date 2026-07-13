require "test_helper"

class AnnouncementsControllerTest < ActionDispatch::IntegrationTest
  test "index succeeds with a normal request" do
    post session_url, params: { email_address: "paula@example.com", password: "password" }

    get announcements_url

    assert_response :success
  end

  test "index clamps a negative offset instead of raising" do
    post session_url, params: { email_address: "paula@example.com", password: "password" }

    get announcements_url(offset: -1)

    assert_response :success
  end
end
