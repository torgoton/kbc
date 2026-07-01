require "test_helper"

class RatingHelperTest < ActionView::TestCase
  test "shows the plain rating once a player has 10+ rated games" do
    user = users(:chris)
    user.update!(rating: 1620)
    user.define_singleton_method(:rated_games_count) { 10 }

    assert_equal "1620", rating_badge(user)
  end

  test "marks the rating provisional under 10 rated games" do
    user = users(:chris)
    user.update!(rating: 1500)
    user.define_singleton_method(:rated_games_count) { 3 }

    assert_equal "1500?", rating_badge(user)
  end
end
