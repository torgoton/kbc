require "application_system_test_case"

class UsersTest < ApplicationSystemTestCase
  test "user can sign in and reach the dashboard" do
    visit root_url
    fill_in "Enter your email address", with: "chris@example.com"
    fill_in "Enter your password", with: "password"
    click_on "Sign in"
    assert_selector "h1", text: "KBC Dashboard"
  end

  test "invalid credentials show an alert" do
    visit root_url
    fill_in "Enter your email address", with: "nobody@example.com"
    fill_in "Enter your password", with: "wrong"
    click_on "Sign in"
    assert_selector ".flash-alert"
  end

  test "user can request an account" do
    visit new_user_url
    fill_in "Enter your desired handle", with: "newplayer"
    fill_in "Enter your email address", with: "newplayer@example.com"
    fill_in "Create a password", with: "secret123"
    click_on "Create User"
    assert_text "not yet been approved"
  end
end
