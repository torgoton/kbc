require "test_helper"

class Turn::SubPhases::WallPlacementPhaseTest < ActiveSupport::TestCase
  def setup
    @game = Game.create!(state: "waiting")
    @game.add_player(users(:chris))
    @game.add_player(users(:paula))
    @game.start
    @game.reload
    @game.instantiate
    @player = @game.current_player
  end

  test "to_h round-trips through from_h" do
    phase = Turn::SubPhases::WallPlacementPhase.new(walls_placed: 1, chosen_terrain: "G")

    rebuilt = Turn::SubPhases::WallPlacementPhase.from_h(phase.to_h)

    assert_equal 1, rebuilt.walls_placed
    assert_equal "G", rebuilt.chosen_terrain
  end

  test "place_wall emits WallPlaced and persists chosen terrain when another wall remains" do
    setup_quarry_target("G")
    target = quarry_targets("G").first
    phase = Turn::SubPhases::WallPlacementPhase.new

    cs = phase.handle(:place_wall, game: @game, player_order: @player.order, row: target[0], col: target[1])

    assert(cs.any? { |c| c.is_a?(Turn::Consequences::WallPlaced) })
    update = cs.find { |c| c.is_a?(Turn::Consequences::SubPhaseStateUpdated) }
    refute_nil update
    assert_equal 1, update.new_state["walls_placed"]
    assert_equal "G", update.new_state["chosen_terrain"]
    refute phase.complete?
  end

  test "place_wall consumes tile and completes on second wall" do
    setup_quarry_target("G")
    first, second = quarry_targets("G").first(2)
    @game.board_contents.place_wall(first[0], first[1])
    phase = Turn::SubPhases::WallPlacementPhase.new(walls_placed: 1, chosen_terrain: "G")

    cs = phase.handle(:place_wall, game: @game, player_order: @player.order, row: second[0], col: second[1])

    assert(cs.any? { |c| c.is_a?(Turn::Consequences::WallPlaced) })
    assert(cs.any? { |c| c.is_a?(Turn::Consequences::TileConsumed) && c.klass == "QuarryTile" })
    assert phase.complete?
  end

  test "place_wall rejects non-hand terrain" do
    setup_quarry_target("G")
    @player.update!(hand: [ "D" ])
    target = quarry_targets("G").first

    cs = Turn::SubPhases::WallPlacementPhase.new.handle(:place_wall, game: @game, player_order: @player.order, row: target[0], col: target[1])

    assert_kind_of Turn::Consequences::Error, cs.first
  end

  test "end_tile_action consumes tile only after at least one wall" do
    cs = Turn::SubPhases::WallPlacementPhase.new(walls_placed: 0).handle(:end_tile_action, game: @game, player_order: @player.order)
    assert_kind_of Turn::Consequences::Error, cs.first

    phase = Turn::SubPhases::WallPlacementPhase.new(walls_placed: 1)
    cs = phase.handle(:end_tile_action, game: @game, player_order: @player.order)

    assert(cs.any? { |c| c.is_a?(Turn::Consequences::TileConsumed) && c.klass == "QuarryTile" })
    assert phase.complete?
  end

  private

  def setup_quarry_target(terrain)
    @player.update!(hand: [ terrain, "D" ].uniq)
    source, = first_quarry_setup(terrain)
    @game.board_contents.place_settlement(source[0], source[1], @player.order)
    @game.save!
  end

  def quarry_targets(terrain)
    Tiles::QuarryTile.new(0).valid_destinations(
      board_contents: @game.board_contents,
      board: @game.board,
      player_order: @player.order,
      hand: terrain
    )
  end

  def first_quarry_setup(terrain)
    20.times do |row|
      20.times do |col|
        next unless Tiles::Tile::BUILDABLE_TERRAIN.include?(@game.board.terrain_at(row, col))
        next unless @game.board_contents.empty?(row, col)
        targets = @game.board_contents.neighbors(row, col).select do |nr, nc|
          @game.board_contents.empty?(nr, nc) && @game.board.terrain_at(nr, nc) == terrain
        end
        return [ [ row, col ], targets ] if targets.size >= 2
      end
    end
    raise "no Quarry setup for #{terrain}"
  end
end
