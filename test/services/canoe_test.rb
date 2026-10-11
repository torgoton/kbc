require "test_helper"

class CanoeTest < ActiveSupport::TestCase
  # tile "used" is irrelevant: a Canoe reacts every time a location is emptied
  CANOE = { "klass" => "CanoeTile", "used" => true, "from" => "[2, 8]" }.freeze

  def setup
    @game = games(:game2player)
    @game.boards = [ [ 1, 0 ], [ 5, 0 ], [ 0, 0 ], [ 4, 0 ] ] # Oasis location at (2,7); (1,7) is Timberland next to it
    @game.board_contents = BoardState.new.tap { |s| s.place_tile(2, 7, "OasisTile", 1) }
    @game.mandatory_count = Game::MANDATORY_COUNT
    @game.save!
    @chris = game_players(:chris) # order 0, the active player
    @paula = game_players(:paula) # order 1
    @chris.update!(hand: [ "T" ], tiles: [ CANOE.dup ])
    @paula.update!(tiles: [ CANOE.dup ])
  end

  def engine = TurnEngine.new(@game)

  def reload = @game.reload

  def empty_the_location
    engine.click(Coordinate.new(1, 7))
    reload
  end

  def skip
    engine.skip_canoe
    reload
  end

  test "emptying a location asks the mover to confirm, then reactions go next player first, mover last" do
    empty_the_location

    assert_equal "canoe_confirm", @game.turn_phase.type
    assert_equal @chris, @game.current_player
    assert_equal [ @paula.order, @chris.order ], @game.turn_phase.holders
  end

  test "the mover can undo before confirming" do
    empty_the_location
    assert engine.undo_allowed?
    engine.undo_max
    reload

    assert_equal 1, @game.board_contents.tile_qty(2, 7)
    assert_equal "mandatory", @game.turn_phase.type
  end

  test "confirming makes the emptying move final and starts the reactions" do
    empty_the_location
    engine.confirm_canoe
    reload

    assert_equal @paula, @game.current_player
    assert_equal "canoe", @game.turn_phase.type
    assert_not engine.undo_allowed?, "the emptying move is final"
  end

  test "a reactor builds on Water or Swamp, then confirms or undoes before anyone proceeds" do
    empty_the_location
    engine.confirm_canoe
    reload
    targets = engine.legal_targets
    assert targets.all? { |r, c| %w[W B].include?(@game.board_contents.terrain_at(r, c)) }
    assert_equal @game.board_contents.available_cells_of(%w[W B]).to_set, targets.to_set, "all Water and Swamp hexes are offered"
    target = targets.first

    engine.click(Coordinate.new(*target))
    reload
    assert_equal @paula.order, @game.board_contents.player_at(*target)
    assert_equal "canoe_confirm", @game.turn_phase.type
    assert_equal @paula, @game.current_player, "others cannot proceed yet"
    assert engine.undo_allowed?

    engine.undo_max
    reload
    assert_nil @game.board_contents.player_at(*target)
    assert_equal "canoe", @game.turn_phase.type
    assert_equal @paula, @game.current_player

    engine.click(Coordinate.new(*target))
    reload
    engine.confirm_canoe
    reload
    assert_equal @chris, @game.current_player, "the active player reacts last"
    assert_equal "canoe", @game.turn_phase.type
  end

  test "with a settlement on the board, only adjacent Water and Swamp hexes are offered" do
    @game.board_contents = BoardState.new.tap do |s|
      s.place_tile(2, 7, "OasisTile", 1)
      s.place_settlement(7, 4, @paula.order)
    end
    @game.save!
    empty_the_location
    engine.confirm_canoe
    reload

    targets = engine.legal_targets
    assert_equal [ [ 6, 4 ], [ 8, 4 ], [ 8, 5 ] ].to_set, targets.to_set
  end

  test "everyone skipping returns to the interrupted action" do
    empty_the_location
    engine.confirm_canoe
    reload
    skip
    assert_equal @chris, @game.current_player
    skip

    assert_equal @chris, @game.current_player
    assert_equal "mandatory", @game.turn_phase.type
    assert_equal [ [ 1, 7 ] ], @game.turn_phase.builds
    assert_empty @game.interrupts
  end

  test "no confirmation when nobody holds a Canoe" do
    @chris.update!(tiles: [])
    @paula.update!(tiles: [])
    empty_the_location

    assert_equal "mandatory", @game.turn_phase.type
  end

  test "a location that still has tiles does not trigger Canoe" do
    @game.board_contents = BoardState.new.tap { |s| s.place_tile(2, 7, "OasisTile", 2) }
    @game.save!
    empty_the_location

    assert_equal "mandatory", @game.turn_phase.type
  end

  test "each Canoe tile reacts, so a player with two reacts twice" do
    @paula.update!(tiles: [ CANOE.dup, CANOE.dup ])
    empty_the_location

    assert_equal [ @paula.order, @paula.order, @chris.order ], @game.turn_phase.holders
  end

  test "adjacency is applied to Water and Swamp separately, as for a two-card hand" do
    # Board 17: (3,1) Timberland touches Water at (3,2) but no Swamp.
    @game.boards = [ [ 17, 0 ], [ 5, 0 ], [ 0, 0 ], [ 4, 0 ] ]
    @game.board_contents = BoardState.new.tap do |s|
      s.place_tile(1, 1, "RefugeTile", 1)
      s.place_settlement(3, 1, @paula.order)
    end
    @game.save!
    @game.update!(current_action: TurnPhase::CanoePhase.new.serialize, current_player: @paula)
    @game.instantiate

    targets = engine.legal_targets
    assert_includes targets, [ 3, 2 ], "adjacent Water"
    assert_includes targets, [ 3, 6 ], "Swamp is not adjacent, so every Swamp hex is offered"
    assert_not_includes targets, [ 3, 4 ], "other Water is not adjacent"
  end

  test "a Canoe build that empties another location is resolved before the outer reactions continue" do
    # Paula's water settlement at (7,4); (8,5) is Water next to both (7,4) and the second location (7,5).
    @game.board_contents = BoardState.new.tap do |s|
      s.place_tile(2, 7, "OasisTile", 1)
      s.place_tile(7, 5, "OasisTile", 1)
      s.place_settlement(7, 4, @paula.order)
    end
    @game.save!
    empty_the_location
    engine.confirm_canoe
    reload
    engine.click(Coordinate.new(8, 5))
    reload
    assert_equal "canoe_confirm", @game.turn_phase.type
    assert_equal [ @chris.order, @paula.order ], @game.turn_phase.holders

    engine.confirm_canoe
    reload
    assert_equal 2, @game.interrupts.size
    assert_equal @chris, @game.current_player, "nested reactions start after paula"
    skip # chris, nested
    assert_equal @paula, @game.current_player
    skip # paula, nested; the nested frame is done
    assert_equal @chris, @game.current_player, "back to the outer queue: chris is still owed his reaction"
    skip

    assert_equal @chris, @game.current_player
    assert_equal "mandatory", @game.turn_phase.type
    assert_empty @game.interrupts
  end

  test "in timed games a reactor's time is charged to their own clock" do
    t0 = Time.zone.local(2026, 10, 10, 12, 0, 0)
    @game.update!(speed: "normal", turn_started_at: t0)
    @chris.update!(time_remaining_ms: 100_000, clock_started_at: t0 - 60)
    @paula.update!(time_remaining_ms: 100_000, clock_started_at: t0 - 60)

    travel_to(t0 + 10) { empty_the_location }
    travel_to(t0 + 10) { engine.confirm_canoe }
    reload
    assert_equal 90_000, @chris.reload.time_remaining_ms, "the mover is charged up to the handover"
    assert_equal @paula, @game.current_player

    travel_to(t0 + 15) { skip }
    assert_equal 95_000, @paula.reload.time_remaining_ms, "the reactor is charged for their own 5s"
    assert_equal 90_000, @chris.reload.time_remaining_ms
  end

  test "undo is refused to a player whose move is not the last one" do
    empty_the_location
    engine.confirm_canoe
    reload
    assert_not engine.undo_allowed?
  end
end
