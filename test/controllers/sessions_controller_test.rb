require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "GET new renders the login form" do
    get new_session_url
    assert_response :success
  end

  test "POST create with valid approved credentials redirects to the originally requested page" do
    get dashboard_url   # unauthenticated access stores dashboard_url as the return destination
    post session_url, params: { email_address: "chris@example.com", password: "password" }
    assert_redirected_to dashboard_path
  end

  test "POST create with invalid credentials redirects to root with alert" do
    post session_url, params: { email_address: "nobody@example.com", password: "wrong" }
    assert_redirected_to root_path
    assert_equal "Invalid credentials. Please try another email address or password.", flash[:alert]
  end

  test "POST create with unapproved user redirects to unapproved page" do
    post session_url, params: { email_address: "exemplar@example.com", password: "password" }
    assert_redirected_to unapproved_users_url
  end

  test "DELETE destroy terminates session and redirects to root" do
    post session_url, params: { email_address: "chris@example.com", password: "password" }
    delete session_url
    assert_redirected_to root_path
  end
end
