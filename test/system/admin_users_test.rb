require "application_system_test_case"

class AdminUsersTest < ApplicationSystemTestCase
  def sign_in(email_address:, password: "password")
    visit root_url
    panel = find("#sign-in-panel")
    set_field(panel.find("input[name='email_address']"), email_address)
    set_field(panel.find("input[name='password']"), password)
    submit_form panel.find("form")
    assert_selector "h1", text: "KBC Dashboard"
  end

  test "admin toggles a user's approved flag from the admin page" do
    pending = User.create!(handle: "Pending", email_address: "pending@example.com", password: "password", approved: false)
    sign_in(email_address: "chris@example.com")
    visit admin_url
    checkbox_id = "approved_#{pending.id}"
    page.execute_script("document.getElementById('#{checkbox_id}').click()")
    # Wait for the Turbo Stream round-trip: the server only renders the
    # `checked` attribute once @user.approved is actually true, unlike the
    # JS click which flips the DOM property immediately. See the same
    # pattern in admin_announcements_test.rb's pin-toggle test.
    assert_selector "##{checkbox_id}[checked]", wait: 5
    assert pending.reload.approved?, "expected user to become approved"
  end
end
