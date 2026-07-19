require "test_helper"

class GamesHelperTest < ActionView::TestCase
  test "clock_display formats ms as M:SS, matching the JS clock controller" do
    assert_equal "5:00", clock_display(300_000)
    assert_equal "0:07", clock_display(7_000)
    assert_equal "1:05", clock_display(65_000)
  end

  test "clock_display shows a leading minus once the clock has flagged" do
    assert_equal "-1:40", clock_display(-100_000)
    assert_equal "0:00", clock_display(0)
  end
end
