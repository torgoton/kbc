require "test_helper"

class AdminMailerTest < ActionMailer::TestCase
  setup do
    @user = users(:chris)
    ENV["ADMIN_EMAIL"] = "admin@example.com"
  end

  test "new_signup sends to ADMIN_EMAIL" do
    mail = AdminMailer.new_signup(@user)
    assert_equal [ "admin@example.com" ], mail.to
  end

  test "new_signup uses the correct subject" do
    mail = AdminMailer.new_signup(@user)
    assert_equal "New signup: #{@user.handle}", mail.subject
  end

  test "new_signup body contains the user's handle and email address" do
    mail = AdminMailer.new_signup(@user)
    assert_match @user.handle, mail.body.encoded
    assert_match @user.email_address, mail.body.encoded
  end
end
