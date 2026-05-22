require "application_system_test_case"

class UsersTest < ApplicationSystemTestCase
  def sign_in(email_address:, password:)
    visit root_url
    within "#sign-in-panel" do
      fill_in "Enter your email address", with: email_address
      fill_in "Enter your password", with: password
      click_on "Sign In"
    end
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
    fill_in "Enter your desired handle", with: handle
    fill_in "Enter your email address", with: email_address
    fill_in "Create a password", with: "secret123"
    click_on "Create User"

    assert_text "not yet been approved"

    User.find_by!(email_address: email_address).update!(approved: true)

    sign_in(email_address: email_address, password: "secret123")
    assert_selector "h1", text: "KBC Dashboard"
  end
end
