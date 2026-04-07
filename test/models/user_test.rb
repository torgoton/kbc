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

  test "my_games includes all playing games the user is in" do
    assert_includes users(:chris).my_games, games(:game2player)
    assert_includes users(:chris).my_games, games(:paula_turn_game)
  end

  test "my_games includes waiting games the user is in" do
    assert_includes users(:chris).my_games, games(:chris_waiting_game)
  end

  test "completed games do not appear in my_games" do
    refute_includes users(:chris).my_games, games(:completed_game)
  end

  test "waiting_games includes waiting games where the user is not a participant" do
    assert_includes users(:chris).waiting_games, games(:waiting_game)
  end

  test "completed_games includes completed games the user participated in" do
    assert_includes users(:chris).completed_games, games(:completed_game)
  end

  # --- model-level validations ---

  test "user without email address is invalid" do
    user = User.new(handle: "tester", password: "password123")
    assert_not user.valid?
    assert_includes user.errors[:email_address], "can't be blank"
  end

  test "user without handle is invalid" do
    user = User.new(email_address: "tester@example.com", password: "password123")
    assert_not user.valid?
    assert_includes user.errors[:handle], "can't be blank"
  end

  test "user without password is invalid on create" do
    user = User.new(email_address: "tester@example.com", handle: "tester")
    assert_not user.valid?
    assert_includes user.errors[:password], "can't be blank"
  end

  test "duplicate handle is invalid" do
    user = User.new(email_address: "unique@example.com", handle: users(:chris).handle, password: "abc123")
    assert_not user.valid?
    assert_includes user.errors[:handle], "has already been taken"
  end

end
