# == Schema Information
#
# Table name: announcements
#
#  id         :bigint           not null, primary key
#  pinned     :boolean          default(FALSE), not null
#  title      :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_announcements_on_pinned_and_created_at  (pinned,created_at)
#
class Announcement < ApplicationRecord
  PAGE_SIZE = 5

  has_rich_text :body

  validates :title, presence: true

  scope :pinned,   -> { where(pinned: true).order(created_at: :desc) }
  scope :unpinned, -> { where(pinned: false).order(created_at: :desc) }
end
