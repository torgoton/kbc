require "application_system_test_case"

class UsersTest < ApplicationSystemTestCase
  test "user can sign in and reach the dashboard" do
    sign_in(email_address: "chris@example.com", password: "password")
    assert_selector "h1", text: "KBC Dashboard"
  end

  test "invalid credentials show an alert" do
    sign_in(email_address: "nobody@example.com", password: "wrong")
    assert_selector ".flash-alert"
  end

  test "user can request an account, get approved, and sign in" do
    token = SecureRandom.hex(4)
    handle = "newplayer-#{token}"
    email_address = "newplayer-#{token}@example.com"

    visit new_user_url
    set_field(find("input[name='user[handle]']"), handle)
    set_field(find("input[name='user[email_address]']"), email_address)
    set_field(find("input[name='user[password]']"), "secret123")
    assert_field "user_handle", with: handle
    assert_field "user_email_address", with: email_address
    assert_field "user_password", with: "secret123"
    submit_form find("form")

    assert_text "not yet been approved"

    User.find_by!(email_address: email_address).update!(approved: true)

    sign_in(email_address: email_address, password: "secret123")
    assert_selector "h1", text: "KBC Dashboard"
  end
end
