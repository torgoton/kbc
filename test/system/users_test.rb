require "application_system_test_case"

class UsersTest < ApplicationSystemTestCase
  def sign_in(email_address:, password:)
    visit root_url
    sign_in_panel = find("#sign-in-panel")
    email_field = sign_in_panel.find("input[name='email_address']")
    password_field = sign_in_panel.find("input[name='password']")
    set_field(email_field, email_address)
    set_field(password_field, password)
    assert_equal email_address, email_field.value
    assert_equal password, password_field.value
    submit_form sign_in_panel.find("form")
  end

  test "user can sign in and reach the dashboard" do
    sign_in(email_address: "chris@example.com", password: "password")
    assert_selector "h1", text: "KBC Dashboard"
  end

  test "invalid credentials show an alert" do
    visit root_url
    within "#sign-in-panel" do
      fill_in "Enter your email address", with: "nobody@example.com"
      fill_in "Enter your password", with: "wrong"
      click_on "Sign In"
    end
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
