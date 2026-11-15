# == Schema Information
#
# Table name: users
#
#  id                :bigint           not null, primary key
#  admin             :boolean          default(FALSE), not null
#  approved          :boolean          default(FALSE)
#  dashboard_seen_at :datetime
#  email_address     :string           not null
#  handle            :string           not null
#  last_seen_at      :datetime
#  password_digest   :string           not null
#  rating            :integer          default(1500), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
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

  test "my_games and waiting_games list the oldest first, completed_games the most recently updated first" do
    user = users(:chris)
    assert_equal user.my_games.sort_by { |g| [ g.created_at, g.id ] }.map(&:id), user.my_games.map(&:id)
    assert_equal user.waiting_games.sort_by { |g| [ g.created_at, g.id ] }.map(&:id), user.waiting_games.map(&:id)
    older = Game.create!(state: "completed", updated_at: 2.days.ago).tap { |g| g.add_player(user); g.save! }
    newer = Game.create!(state: "completed").tap { |g| g.add_player(user); g.save! }
    older.update_column(:updated_at, 2.days.ago)
    ids = user.completed_games.map(&:id)
    assert ids.index(newer.id) < ids.index(older.id)
    assert_equal user.completed_games.sort_by { |g| [ g.updated_at, g.id ] }.reverse.map(&:id), ids
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

  # --- online? ---

  test "online? is false with no site presence" do
    assert_not users(:chris).online?
  end

  test "online? is true while any site connection is fresh" do
    Presence.create!(user: users(:chris), kind: "site", connection_id: "a", last_ping_at: Time.current)
    assert users(:chris).online?
  end

  test "online? survives closing one of two tabs" do
    Presence.create!(user: users(:chris), kind: "site", connection_id: "a", last_ping_at: Time.current)
    Presence.create!(user: users(:chris), kind: "site", connection_id: "b", last_ping_at: Time.current)
    Presence.find_by(connection_id: "a").destroy
    assert users(:chris).online?
  end

  test "online? is false once connections go stale" do
    Presence.create!(user: users(:chris), kind: "site", connection_id: "a", last_ping_at: 2.minutes.ago)
    assert_not users(:chris).online?
  end

  test "on_dashboard? only counts dashboard connections" do
    Presence.create!(user: users(:chris), kind: "site", connection_id: "a", last_ping_at: Time.current)
    assert_not users(:chris).on_dashboard?
    Presence.create!(user: users(:chris), kind: "dashboard", connection_id: "a", last_ping_at: Time.current)
    assert users(:chris).on_dashboard?
  end

  # --- admin? ---

  test "admin? reflects the admin column" do
    assert users(:chris).admin?
    assert_not users(:paula).admin?
  end
end
