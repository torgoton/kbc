# == Schema Information
#
# Table name: users
#
#  id              :bigint           not null, primary key
#  approved        :boolean          default(FALSE)
#  email_address   :string           not null
#  handle          :string           not null
#  password_digest :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_users_on_email_address  (email_address) UNIQUE
#  index_users_on_handle         (handle) UNIQUE
#
require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "save without email address raises exception" do
    user = User.new(handle: "testuser", password: "password123")
    assert_raises(ActiveRecord::NotNullViolation) {
      user.save!(validate: false)
    }
  end

  test "save without password raises exception" do
    user = User.new(email_address: "test@example.com", handle: "testuser")
    assert_raises(ActiveRecord::NotNullViolation) {
      user.save!(validate: false)
    }
  end

  test "save without handle raises exception" do
    user = User.new(email_address: "test@example.com", password: "password123")
    assert_raises(ActiveRecord::NotNullViolation) {
      user.save!(validate: false)
    }
  end
end
