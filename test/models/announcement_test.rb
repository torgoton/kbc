require "test_helper"

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
class AnnouncementTest < ActiveSupport::TestCase
  test "requires a title" do
    a = Announcement.new(body: "hi")
    assert_not a.valid?
    assert_includes a.errors[:title], "can't be blank"
  end

  test "pinned scope returns only pinned, newest first" do
    old = Announcement.create!(title: "old", body: "x", pinned: true, created_at: 2.days.ago)
    new = Announcement.create!(title: "new", body: "x", pinned: true, created_at: 1.day.ago)
    Announcement.create!(title: "plain", body: "x", pinned: false)
    assert_equal [ new, old ], Announcement.pinned.to_a
  end

  test "unpinned scope returns only unpinned, newest first" do
    Announcement.create!(title: "pinned", body: "x", pinned: true)
    a = Announcement.create!(title: "a", body: "x", created_at: 2.days.ago)
    b = Announcement.create!(title: "b", body: "x", created_at: 1.day.ago)
    assert_equal [ b, a ], Announcement.unpinned.to_a
  end
end
