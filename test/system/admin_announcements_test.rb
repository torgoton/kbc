require "application_system_test_case"

class AdminAnnouncementsTest < ApplicationSystemTestCase
  def sign_in(email_address:, password: "password")
    visit root_url
    panel = find("#sign-in-panel")
    set_field(panel.find("input[name='email_address']"), email_address)
    set_field(panel.find("input[name='password']"), password)
    submit_form panel.find("form")
    assert_selector "h1", text: "KBC Dashboard"
  end

  def fill_rich_text(html)
    editor = find("trix-editor")
    page.execute_script("arguments[0].editor.loadHTML(arguments[1])", editor, html)
  end

  test "admin creates, edits, and deletes an announcement" do
    sign_in(email_address: "chris@example.com")
    visit new_admin_announcement_url
    set_field(find("input[name='announcement[title]']"), "Server maintenance")
    fill_rich_text("<div>Down at 2am</div>")
    submit_form find("form")
    assert_text "Server maintenance"

    a = Announcement.find_by!(title: "Server maintenance")
    visit edit_admin_announcement_url(a)
    set_field(find("input[name='announcement[title]']"), "Server maintenance (updated)")
    submit_form find("form")
    assert_text "Server maintenance (updated)"

    # Auto-accept Turbo's confirm instead of driving the native dialog: headless
    # Selenium auto-dismisses window.confirm before accept_confirm can catch it,
    # which is the source of the intermittent ModalNotFound here.
    page.execute_script("window.confirm = () => true")
    assert_difference -> { Announcement.count }, -1 do
      page.execute_script("document.querySelector('##{ActionView::RecordIdentifier.dom_id(a)} .delete-toggle button').click()")
      assert_no_text "Server maintenance (updated)"
    end
  end

  test "admin pins and unpins from the index" do
    a = Announcement.create!(title: "Pin me", body: "x", pinned: false)
    sign_in(email_address: "chris@example.com")
    visit admin_announcements_url
    page.execute_script("document.querySelector('##{ActionView::RecordIdentifier.dom_id(a)} .pin-toggle button').click()")
    assert_text "unpin", wait: 5
    assert a.reload.pinned?
  end
end
