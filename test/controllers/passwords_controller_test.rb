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

  test "GET edit with a valid token renders the reset form" do
    user = users(:chris)
    get edit_password_url(user.password_reset_token)
    assert_response :success
  end

  test "GET edit with an invalid token redirects to root with alert" do
    get edit_password_url("not-a-real-token")
    assert_redirected_to root_path
    assert_match(/invalid or has expired/, flash[:alert])
  end

  test "PATCH update with matching passwords resets the password and redirects" do
    user = users(:chris)
    patch password_url(user.password_reset_token), params: {
      password: "newpassword1",
      password_confirmation: "newpassword1"
    }
    assert_redirected_to root_path
    assert_match(/Password has been reset/, flash[:notice])
  end

  test "PATCH update with mismatched passwords redirects back with alert" do
    user = users(:chris)
    token = user.password_reset_token
    patch password_url(token), params: {
      password: "newpassword1",
      password_confirmation: "different"
    }
    assert_redirected_to edit_password_path(token)
    assert_match(/did not match/, flash[:alert])
  end
end
