require "test_helper"

class Turn::SubPhases::SettlementMovePhaseTest < ActiveSupport::TestCase
  def setup
    @game = Game.create!(state: "waiting")
    @game.add_player(users(:chris))
    @game.add_player(users(:paula))
    @game.start
    @game.reload
    @game.instantiate
  end

  def phase(tile_klass: "PaddockTile", source: nil)
    Turn::SubPhases::SettlementMovePhase.new(tile_klass: tile_klass, source: source)
  end

  test "to_h round-trips through from_h with nil source" do
    p = phase
    h = p.to_h
    assert_nil h["source"]
    rebuilt = Turn::SubPhases::SettlementMovePhase.from_h(h)
    assert_nil rebuilt.source
  end

  test "to_h round-trips through from_h with a source" do
    p = phase(source: Coordinate.new(5, 7))
    h = p.to_h
    assert_equal "[5, 7]", h["source"]
    rebuilt = Turn::SubPhases::SettlementMovePhase.from_h(h)
    assert_equal Coordinate.new(5, 7), rebuilt.source
  end

  test "select_settlement on own settlement emits SubPhaseStateUpdated with source set" do
    @game.board_contents.place_settlement(5, 5, 0)
    p = phase
    cs = p.handle(:select_settlement, game: @game, player_order: 0, row: 5, col: 5)
    update = cs.find { |c| c.is_a?(Turn::Consequences::SubPhaseStateUpdated) }
    refute_nil update
    assert_equal "[5, 5]", update.new_state["source"]
  end

  test "select_settlement on opponent settlement errors" do
    @game.board_contents.place_settlement(5, 5, 1)
    p = phase
    cs = p.handle(:select_settlement, game: @game, player_order: 0, row: 5, col: 5)
    assert_kind_of Turn::Consequences::Error, cs.first
  end

  test "select_settlement on empty hex errors" do
    p = phase
    cs = p.handle(:select_settlement, game: @game, player_order: 0, row: 5, col: 5)
    assert_kind_of Turn::Consequences::Error, cs.first
  end

  test "move_settlement requires source already selected" do
    p = phase
    cs = p.handle(:move_settlement, game: @game, player_order: 0, row: 5, col: 5)
    assert_kind_of Turn::Consequences::Error, cs.first
  end

  test "move_settlement on a valid Paddock destination emits SettlementMoved + TileConsumed and completes" do
    src = first_paddock_movable_source
    dst = paddock_destination_for(src)

    @game.board_contents.place_settlement(src[0], src[1], 0)
    @game.save!

    p = phase(source: Coordinate.new(src[0], src[1]))
    cs = p.handle(:move_settlement, game: @game, player_order: 0, row: dst[0], col: dst[1])

    moved = cs.find { |c| c.is_a?(Turn::Consequences::SettlementMoved) }
    consumed = cs.find { |c| c.is_a?(Turn::Consequences::TileConsumed) }
    refute_nil moved
    refute_nil consumed
    assert_equal "PaddockTile", consumed.klass
    assert p.complete?
  end

  test "move_settlement to a non-valid destination errors" do
    @game.board_contents.place_settlement(5, 5, 0)
    p = phase(source: Coordinate.new(5, 5))
    cs = p.handle(:move_settlement, game: @game, player_order: 0, row: 0, col: 0)
    assert_kind_of Turn::Consequences::Error, cs.first
  end

  private

  def first_paddock_movable_source
    20.times do |r|
      20.times do |c|
        next if @game.board.terrain_at(r, c).nil?
        next unless @game.board_contents.empty?(r, c)
        # Source needs to have a valid 2-step destination, i.e. PaddockTile.valid_destinations(from_row: r, from_col: c) is non-empty.
        instance = Tiles::PaddockTile.new(0)
        next unless instance.valid_destinations(from_row: r, from_col: c, board_contents: @game.board_contents, board: @game.board, player_order: 0).any?
        return [ r, c ]
      end
    end
    raise "no Paddock-movable source on this board"
  end

  def paddock_destination_for(src)
    Tiles::PaddockTile.new(0).valid_destinations(
      from_row: src[0], from_col: src[1],
      board_contents: @game.board_contents, board: @game.board, player_order: 0
    ).first
  end
end
