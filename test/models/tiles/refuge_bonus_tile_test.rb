require "test_helper"

class Tiles::RefugeBonusTileTest < ActiveSupport::TestCase
  # Board 1 row 0 "DDCWWTTGGG": (0,4)=W, (0,5)=T, (0,6)=T, (0,7)=G.
  def setup
    @game = games(:game2player)
    @game.boards = [ [ 1, 0 ], [ 5, 0 ], [ 0, 0 ], [ 4, 0 ] ]
    @chris = game_players(:chris)
    @game.board_contents = BoardState.new.tap { |s| s.place_settlement(0, 5, @chris.order) }
    @game.mandatory_count = Game::MANDATORY_COUNT
    @game.save!
    @tile = Tiles::Bonus::RefugeBonusTile.new(0)
  end

  def destinations
    @game.instantiate
    @tile.valid_destinations(from_row: 0, from_col: 5, board_contents: @game.board_contents)
  end

  test "nearest suitable hex per line, jumping unsuitable terrain" do
    assert_includes destinations, [ 0, 6 ] # east, adjacent
    assert_includes destinations, [ 0, 2 ] # west: Water skipped
  end

  test "jumps occupied hexes" do
    @game.board_contents.place_settlement(0, 6, game_players(:paula).order)
    @game.board_contents.place_settlement(0, 7, game_players(:paula).order)
    assert_includes destinations, [ 0, 8 ]
    assert_not_includes destinations, [ 0, 6 ]
  end

  test "is selectable, awarded with the 2nd Refuge, moves the settlement" do
    @game.board_contents.place_tile(0, 7, "RefugeTile", 2)
    @chris.update!(hand: [ "G" ], tiles: [ { "klass" => "RefugeBonusTile", "used" => false, "from" => nil } ])
    engine = TurnEngine.new(@game)
    assert engine.tile_activatable?(@chris.tiles.first)
    engine.select_action("refugebonus")
    engine.click(Coordinate.new(0, 5))
    engine.click(Coordinate.new(0, 6))
    assert_equal @chris.order, @game.reload.board_contents.player_at(0, 6)
    assert_nil @game.board_contents.player_at(0, 5)
  end
end
