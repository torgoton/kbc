require "test_helper"

class Turn::SubPhases::ResettlementPhaseTest < ActiveSupport::TestCase
  def setup
    @game = Game.create!(state: "waiting")
    @game.add_player(users(:chris))
    @game.add_player(users(:paula))
    @game.start
    @game.reload
    @game.boards = [ [ 10, 0 ], [ 5, 0 ], [ 0, 0 ], [ 4, 0 ] ]
    @game.instantiate
    @player = @game.current_player
  end

  test "to_h round-trips through from_h" do
    phase = Turn::SubPhases::ResettlementPhase.new(
      budget: 2,
      vacated: [ "[0, 0]" ],
      moves: 1,
      source: Coordinate.new(0, 1)
    )

    rebuilt = Turn::SubPhases::ResettlementPhase.from_h(phase.to_h)

    assert_equal 2, rebuilt.budget
    assert_equal [ "[0, 0]" ], rebuilt.vacated
    assert_equal 1, rebuilt.moves
    assert_equal Coordinate.new(0, 1), rebuilt.source
  end

  test "select_settlement records selectable source" do
    @game.board_contents.place_settlement(0, 0, @player.order)

    cs = phase.handle(:select_settlement, game: @game, player_order: @player.order, row: 0, col: 0)

    update = cs.find { |c| c.is_a?(Turn::Consequences::SubPhaseStateUpdated) }
    refute_nil update
    assert_equal "[0, 0]", update.new_state["source"]
  end

  test "select_settlement rejects city hall source" do
    @game.board_contents.place_city_hall_hex(0, 0, @player.order)

    cs = phase.handle(:select_settlement, game: @game, player_order: @player.order, row: 0, col: 0)

    assert_kind_of Turn::Consequences::Error, cs.first
  end

  test "move_settlement deducts actual cost and keeps phase active when budget remains" do
    @game.board_contents.place_settlement(0, 0, @player.order)
    p = phase(source: Coordinate.new(0, 0))

    cs = p.handle(:move_settlement, game: @game, player_order: @player.order, row: 0, col: 2)

    moved = cs.find { |c| c.is_a?(Turn::Consequences::SettlementMoved) }
    update = cs.find { |c| c.is_a?(Turn::Consequences::SubPhaseStateUpdated) }
    refute_nil moved
    refute_nil update
    assert_equal 2, update.new_state["budget"]
    assert_equal [ "[0, 0]" ], update.new_state["vacated"]
    assert_equal 1, update.new_state["moves"]
    assert_nil update.new_state["source"]
    refute p.complete?
  end

  test "move_settlement consumes tile and completes when budget is exhausted" do
    @game.board_contents.place_settlement(0, 0, @player.order)
    p = phase(budget: 1, source: Coordinate.new(0, 0))

    cs = p.handle(:move_settlement, game: @game, player_order: @player.order, row: 0, col: 1)

    assert(cs.any? { |c| c.is_a?(Turn::Consequences::SettlementMoved) })
    assert(cs.any? { |c| c.is_a?(Turn::Consequences::TileConsumed) && c.klass == "ResettlementTile" })
    assert p.complete?
  end

  test "move_settlement emits pickup and forfeit consequences" do
    @player.update!(tiles: [
      { "klass" => "FarmTile", "from" => "[1, 0]", "used" => false },
      { "klass" => "ResettlementTile", "from" => "[0, 0]", "used" => false }
    ])
    @game.board_contents.place_settlement(0, 0, @player.order)
    @game.board_contents.place_tile(1, 0, "FarmTile", 1)
    @game.board_contents.place_tile(0, 3, "OracleTile", 1)
    p = phase(source: Coordinate.new(0, 0))

    cs = p.handle(:move_settlement, game: @game, player_order: @player.order, row: 0, col: 2)

    discard = cs.find { |c| c.is_a?(Turn::Consequences::TileDiscarded) && c.klass == "FarmTile" }
    pickup = cs.find { |c| c.is_a?(Turn::Consequences::TilePickedUp) && c.klass == "OracleTile" }
    refute_nil discard
    refute_nil pickup
  end

  test "end_tile_action consumes tile only after at least one move" do
    cs = phase(moves: 0).handle(:end_tile_action, game: @game, player_order: @player.order)
    assert_kind_of Turn::Consequences::Error, cs.first

    p = phase(moves: 1)
    cs = p.handle(:end_tile_action, game: @game, player_order: @player.order)
    assert(cs.any? { |c| c.is_a?(Turn::Consequences::TileConsumed) && c.klass == "ResettlementTile" })
    assert p.complete?
  end

  private

  def phase(budget: 4, vacated: [], moves: 0, source: nil)
    Turn::SubPhases::ResettlementPhase.new(budget:, vacated:, moves:, source:)
  end
end
