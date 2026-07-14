require "application_system_test_case"

class DashboardAnnouncementsTest < ApplicationSystemTestCase
  def sign_in(email_address:, password: "password")
    visit root_url
    panel = find("#sign-in-panel")
    set_field(panel.find("input[name='email_address']"), email_address)
    set_field(panel.find("input[name='password']"), password)
    submit_form panel.find("form")
    assert_selector "h1", text: "KBC Dashboard"
  end

  test "dashboard shows pinned announcements and the latest unpinned" do
    Announcement.create!(title: "PINNED-NEWS", body: "x", pinned: true)
    Announcement.create!(title: "OLD-UNPINNED", body: "x", created_at: 2.days.ago)
    Announcement.create!(title: "LATEST-UNPINNED", body: "x", created_at: 1.hour.ago)

    sign_in(email_address: "paula@example.com")
    assert_text "PINNED-NEWS"
    assert_text "LATEST-UNPINNED"
    assert_no_text "OLD-UNPINNED"
    assert_link "All announcements"
  end
end
