require "application_system_test_case"

class AdminDashboardTest < ApplicationSystemTestCase
  def sign_in(email_address:, password: "password")
    visit root_url
    panel = find("#sign-in-panel")
    set_field(panel.find("input[name='email_address']"), email_address)
    set_field(panel.find("input[name='password']"), password)
    submit_form panel.find("form")
    assert_selector "h1", text: "KBC Dashboard"
  end

  test "admin sees the Admin menu link and can open the admin page" do
    sign_in(email_address: "chris@example.com")
    assert_selector "a", text: "Admin", visible: :all
    visit admin_url
    assert_selector "h1", text: "Admin"
  end

  test "non-admin does not see the Admin menu link" do
    sign_in(email_address: "paula@example.com")
    assert_no_selector "a", text: "Admin", visible: :all
  end
end
