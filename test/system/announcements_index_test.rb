require "application_system_test_case"

class AnnouncementsIndexTest < ApplicationSystemTestCase
  def sign_in(email_address:, password: "password")
    visit root_url
    panel = find("#sign-in-panel")
    set_field(panel.find("input[name='email_address']"), email_address)
    set_field(panel.find("input[name='password']"), password)
    submit_form panel.find("form")
    assert_selector "h1", text: "KBC Dashboard"
  end

  test "pinned appear first and scrolling loads more unpinned" do
    Announcement.create!(title: "PINNED", body: "p", pinned: true)
    8.times { |i| Announcement.create!(title: "unpinned-#{i}", body: "u", created_at: i.minutes.ago) }

    sign_in(email_address: "paula@example.com")

    # Shrink the viewport so page 0's content + lazy sentinel can't both fit on
    # load (the default 1400px-tall window is borderline and flakes: the lazy
    # frame sometimes intersects the viewport before any scroll happens).
    page.driver.browser.manage.window.resize_to(1400, 400)

    visit announcements_url

    assert_text "PINNED"
    assert_text "unpinned-0"          # first (newest) unpinned in page 0
    assert_no_text "unpinned-7", wait: 1  # 8th unpinned is on page 2, not loaded yet

    # Scroll the lazy sentinel into view to trigger the next page.
    page.execute_script("window.scrollTo(0, document.body.scrollHeight)")
    assert_text "unpinned-7", wait: 5
  end
end
