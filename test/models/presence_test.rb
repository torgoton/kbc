require "test_helper"

# == Schema Information
#
# Table name: presences
#
#  id            :bigint           not null, primary key
#  kind          :string           not null
#  last_ping_at  :datetime         not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  connection_id :string           not null
#  user_id       :bigint           not null
#
# Indexes
#
#  index_presences_on_connection_id_and_kind  (connection_id,kind) UNIQUE
#  index_presences_on_user_id                 (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class PresenceTest < ActiveSupport::TestCase
  def row(user, kind, id, at: Time.current)
    Presence.create!(user: user, kind: kind, connection_id: id, last_ping_at: at)
  end

  test "online? needs a fresh row of that kind" do
    row(users(:chris), "site", "a", at: 2.minutes.ago)
    assert_not Presence.online?(users(:chris).id, "site")
    row(users(:chris), "site", "b")
    assert Presence.online?(users(:chris).id, "site")
    assert_not Presence.online?(users(:chris).id, "dashboard")
  end

  test "sweep! deletes stale rows and returns who they belonged to" do
    row(users(:chris), "dashboard", "a", at: 5.minutes.ago)
    row(users(:paula), "site", "b")

    assert_equal [ [ users(:chris).id, "dashboard" ] ], Presence.sweep!
    assert_equal 1, Presence.count
  end
end
