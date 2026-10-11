require "test_helper"

class RefugeTileTest < ActiveSupport::TestCase
  # Board 1 row 0 "DDCWWTTGGG": (0,4)=W, (0,5)=T, (0,6)=T.
  def setup
    @game = games(:game2player)
    @game.boards = [ [ 1, 0 ], [ 5, 0 ], [ 0, 0 ], [ 4, 0 ] ]
    @chris = game_players(:chris)
    @game.board_contents = BoardState.new.tap { |s| s.place_settlement(0, 5, @chris.order) }
    @game.mandatory_count = Game::MANDATORY_COUNT
    @game.save!
    @chris.update!(hand: [ "G" ], tiles: [ { "klass" => "RefugeTile", "used" => false, "from" => "[0, 7]" } ])
    @tile = Tiles::Location::RefugeTile.new(0)
  end

  def destinations(contents = @game.tap(&:instantiate).board_contents)
    @tile.valid_destinations(from_row: 0, from_col: 5, board_contents: contents)
  end

  test "moves to adjacent unoccupied buildable hexes only" do
    dests = destinations
    assert_includes dests, [ 0, 6 ]
    assert_not_includes dests, [ 0, 4 ], "Water is not suitable"
    assert_not_includes dests, [ 0, 5 ]
    assert dests.all? { |d| @game.board_contents.neighbors(0, 5).include?(d) }, "only adjacent hexes"
  end

  test "occupied hexes are excluded" do
    @game.board_contents.place_settlement(0, 6, game_players(:paula).order)
    assert_not_includes destinations, [ 0, 6 ]
  end

  test "Swamp is a suitable terrain" do
    @game.boards = [ [ 17, 0 ], [ 1, 0 ], [ 0, 0 ], [ 4, 0 ] ] # board 17: (3,6)=B
    @game.board_contents = BoardState.new
    @game.save!
    @game.instantiate
    assert_includes @tile.valid_destinations(from_row: 3, from_col: 5, board_contents: @game.board_contents), [ 3, 6 ]
  end

  test "the full move: select the tile, the settlement, then the destination" do
    engine = TurnEngine.new(@game)
    engine.select_action("refuge")
    engine.click(Coordinate.new(0, 5))
    engine.click(Coordinate.new(0, 6))
    @game.reload

    assert_equal @chris.order, @game.board_contents.player_at(0, 6)
    assert_nil @game.board_contents.player_at(0, 5)
    assert_equal "mandatory", @game.turn_phase.type
    assert @chris.reload.tiles.first["used"]
  end
end
