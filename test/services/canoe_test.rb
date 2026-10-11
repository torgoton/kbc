require "test_helper"

class CanoeTest < ActiveSupport::TestCase
  CANOE = { "klass" => "CanoeTile", "used" => false, "from" => "[2, 8]" }.freeze

  def setup
    @game = games(:game2player)
    @game.boards = [ [ 1, 0 ], [ 5, 0 ], [ 0, 0 ], [ 4, 0 ] ] # Oasis location at (2,7); (1,7) is Timberland next to it
    @game.board_contents = BoardState.new.tap { |s| s.place_tile(2, 7, "OasisTile", 1) }
    @game.mandatory_count = Game::MANDATORY_COUNT
    @game.save!
    @chris = game_players(:chris)
    @paula = game_players(:paula)
    @chris.update!(hand: [ "T" ], tiles: [ CANOE.dup ])
    @paula.update!(tiles: [ CANOE.dup ])
  end

  def engine = TurnEngine.new(@game)

  def empty_the_location
    engine.click(Coordinate.new(1, 7))
    @game.reload
  end

  test "emptying a location hands the turn to each Canoe holder in turn" do
    empty_the_location

    assert_equal "canoe", @game.turn_phase.type
    assert_equal @chris, @game.current_player, "the active player reacts first"
    assert_equal [ @paula.order ], @game.interrupts.last["queue"]
  end

  test "a reactor chooses a terrain, builds, and the next reactor is up" do
    empty_the_location
    engine.choose_canoe_terrain("G")
    @game.reload
    target = engine.legal_targets.first
    assert_equal "G", @game.board_contents.terrain_at(*target)

    engine.click(Coordinate.new(*target))
    @game.reload

    assert_equal @chris.order, @game.board_contents.player_at(*target)
    assert @chris.reload.tiles.find { |t| t["klass"] == "CanoeTile" }["used"]
    assert_equal @paula, @game.current_player
    assert_equal "canoe", @game.turn_phase.type
  end

  test "skipping everyone returns to the interrupted action" do
    empty_the_location
    engine.skip_canoe
    @game.reload
    assert_equal @paula, @game.current_player
    engine.skip_canoe
    @game.reload

    assert_equal @chris, @game.current_player
    assert_equal "mandatory", @game.turn_phase.type
    assert_equal [ [ 1, 7 ] ], @game.turn_phase.builds
    assert_empty @game.interrupts
  end

  test "no reaction when nobody holds an unused Canoe" do
    @chris.update!(tiles: [])
    @paula.update!(tiles: [ CANOE.merge("used" => true) ])
    empty_the_location

    assert_equal "mandatory", @game.turn_phase.type
    assert_empty @game.interrupts
  end

  test "a location that still has tiles does not trigger Canoe" do
    @game.board_contents = BoardState.new.tap { |s| s.place_tile(2, 7, "OasisTile", 2) }
    @game.save!
    empty_the_location

    assert_equal "mandatory", @game.turn_phase.type
  end

  test "a Canoe build that empties another location is resolved before the others continue" do
    # (6,5) is Grass next to chris's (7,4) and to the second location at (7,5).
    @game.board_contents = BoardState.new.tap do |s|
      s.place_tile(2, 7, "OasisTile", 1)
      s.place_tile(7, 5, "OasisTile", 1)
      s.place_settlement(7, 4, @chris.order)
    end
    @game.save!
    empty_the_location
    engine.choose_canoe_terrain("G")
    engine.click(Coordinate.new(6, 5))
    @game.reload

    assert_equal 2, @game.interrupts.size, "the nested emptying pushes a second frame"
    assert_equal @paula, @game.current_player
    engine.skip_canoe # nested frame finished; paula is still owed her turn at the outer frame
    @game.reload
    assert_equal @paula, @game.current_player
    assert_equal 1, @game.interrupts.size
    engine.skip_canoe
    @game.reload

    assert_equal @chris, @game.current_player
    assert_equal "mandatory", @game.turn_phase.type
    assert_empty @game.interrupts
  end

  test "undo is refused to a player whose move is not the last one" do
    empty_the_location
    @paula_move = @game.moves.where(deliberate: true).order(order: :desc).first
    assert_equal @chris.id, @paula_move.game_player_id
    engine.skip_canoe
    @game.reload
    assert_not engine.undo_allowed?, "paula is up but the last deliberate move is chris's"
  end

  test "choose_canoe_terrain rejects unbuildable terrain" do
    empty_the_location
    engine.choose_canoe_terrain("W")
    assert_nil @game.reload.turn_phase.chosen_terrain
  end
end
