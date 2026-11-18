# One row per open page-connection (a browser tab) per kind. A user is
# "online" on the site / "on the dashboard" while any fresh row exists, so
# closing one of several tabs doesn't flip them offline. Rows go stale when a
# client stops pinging (crash, deploy) and are swept.
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
class Presence < ApplicationRecord
  KINDS = %w[site dashboard].freeze
  FRESH_FOR = 75.seconds

  belongs_to :user
  validates :kind, inclusion: { in: KINDS }

  scope :fresh, -> { where(last_ping_at: FRESH_FOR.ago..) }

  def self.online?(user_id, kind)
    fresh.exists?(user_id: user_id, kind: kind)
  end

  # User ids with at least one fresh row of this kind.
  def self.online_user_ids(kind)
    fresh.where(kind: kind).distinct.pluck(:user_id)
  end

  # Deletes dead rows; returns the [user_id, kind] pairs they belonged to.
  def self.sweep!
    stale = where(last_ping_at: ...FRESH_FOR.ago)
    pairs = stale.distinct.pluck(:user_id, :kind)
    stale.delete_all
    pairs
  end
end
