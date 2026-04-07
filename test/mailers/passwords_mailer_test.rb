require "test_helper"

class PasswordsMailerTest < ActionMailer::TestCase
  setup do
    @user = users(:chris)
  end

  test "reset sends to the user's email address" do
    mail = PasswordsMailer.reset(@user)
    assert_equal [ @user.email_address ], mail.to
  end

  test "reset uses the correct subject" do
    mail = PasswordsMailer.reset(@user)
    assert_equal "Reset your password", mail.subject
  end

  test "reset body contains a password reset link" do
    mail = PasswordsMailer.reset(@user)
    assert_match "/passwords/", mail.body.encoded
    assert_match "/edit", mail.body.encoded
  end
end
