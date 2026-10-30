require "test_helper"

class MayorMarkersTest < ActionView::TestCase
  test "renders a marker per claimed row in the matching half of the board" do
    s = GameScenario.new(goals: [ "mayors" ])
    s.give_mayor_row(0, 3)
    s.give_mayor_row(1, 12)
    s.game.game_players.reset

    top = render("games/mayor_markers", game: s.game, rows: 0...10)
    bottom = render("games/mayor_markers", game: s.game, rows: 10...20)

    assert_equal 1, top.scan("mayor-marker\"").size
    assert_equal 1, bottom.scan("mayor-marker\"").size
    assert_includes bottom, "--row: 2"
  end
end
