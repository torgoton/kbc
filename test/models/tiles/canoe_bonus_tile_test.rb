require "test_helper"

class Tiles::CanoeBonusTileTest < ActiveSupport::TestCase
  # Board 1 row 0 "DDCWWTTGGG": (0,3),(0,4) Water; (0,5) Timberland.
  def setup
    @game = games(:game2player)
    @game.boards = [ [ 1, 0 ], [ 5, 0 ], [ 0, 0 ], [ 4, 0 ] ]
    @chris = game_players(:chris)
    @game.board_contents = BoardState.new.tap { |s| s.place_settlement(0, 5, @chris.order) }
    @game.mandatory_count = Game::MANDATORY_COUNT
    @game.save!
    @chris.update!(hand: [ "G" ], tiles: [ { "klass" => "CanoeBonusTile", "used" => false, "from" => nil } ])
  end

  test "builds on adjacent Water regardless of the card, then is used" do
    engine = TurnEngine.new(@game)
    assert engine.tile_activatable?(@chris.tiles.first)
    engine.select_action("canoebonus")
    assert_includes engine.legal_targets, [ 0, 4 ]
    assert_not_includes engine.legal_targets, [ 0, 6 ], "Timberland is not Water/Swamp"
    engine.click(Coordinate.new(0, 4))
    assert_equal @chris.order, @game.reload.board_contents.player_at(0, 4)
    assert @chris.reload.tiles.first["used"]
  end

  test "2nd Canoe awards the bonus tile" do
    assert_equal "CanoeBonusTile", Tiles::Location::CanoeTile.new(0).bonus_tile_klass
  end
end
