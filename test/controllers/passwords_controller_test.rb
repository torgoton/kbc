require "test_helper"

class PasswordsControllerTest < ActionDispatch::IntegrationTest
  test "GET new renders the password reset request form" do
    get new_password_url
    assert_response :success
  end

  test "POST create with a known email redirects with notice" do
    post passwords_url, params: { email_address: "chris@example.com" }
    assert_redirected_to root_path
    assert_match(/sent password reset instructions/, flash[:notice])
  end

  test "POST create with an unknown email still redirects with the same notice" do
    post passwords_url, params: { email_address: "nobody@example.com" }
    assert_redirected_to root_path
    assert_match(/sent password reset instructions/, flash[:notice])
  end
end
