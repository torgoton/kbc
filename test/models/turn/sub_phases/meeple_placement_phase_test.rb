require "test_helper"

class Turn::SubPhases::MeeplePlacementPhaseTest < ActiveSupport::TestCase
  def setup
    @game = Game.create!(state: "waiting")
    @game.add_player(users(:chris))
    @game.add_player(users(:paula))
    @game.start
    @game.reload
    @game.instantiate
    @gp = @game.game_players.find { |g| g.order == 0 }
    @gp.update!(supply: { "settlements" => 40, "warriors" => 2 })
  end

  def phase(tile_klass: "BarracksTile", kind: "warrior")
    Turn::SubPhases::MeeplePlacementPhase.new(tile_klass: tile_klass, kind: kind)
  end

  test "to_h round-trips through from_h" do
    p = phase
    h = p.to_h
    rebuilt = Turn::SubPhases::MeeplePlacementPhase.from_h(h)
    assert_equal "BarracksTile", rebuilt.tile_klass
    assert_equal "warrior", rebuilt.kind
  end

  test "place_meeple at a valid placement hex emits MeeplePlaced + TileConsumed and completes" do
    target = first_buildable_hex
    p = phase
    cs = p.handle(:place_meeple, game: @game, player_order: 0, row: target[0], col: target[1])

    assert(cs.any? { |c| c.is_a?(Turn::Consequences::MeeplePlaced) && c.kind == "warrior" })
    assert(cs.any? { |c| c.is_a?(Turn::Consequences::TileConsumed) && c.klass == "BarracksTile" })
    assert p.complete?
  end

  test "place_meeple at a non-empty non-meeple hex errors" do
    target = first_buildable_hex
    @game.board_contents.place_settlement(target[0], target[1], 0)
    @game.save!

    p = phase
    cs = p.handle(:place_meeple, game: @game, player_order: 0, row: target[0], col: target[1])
    assert_kind_of Turn::Consequences::Error, cs.first
  end

  test "place_meeple on own warrior emits MeepleRemoved + TileConsumed (Barracks remove)" do
    target = first_buildable_hex
    @game.board_contents.place_warrior(target[0], target[1], 0)
    @game.save!

    p = phase  # Barracks (warrior, !meeple_movable?)
    cs = p.handle(:place_meeple, game: @game, player_order: 0, row: target[0], col: target[1])

    assert(cs.any? { |c| c.is_a?(Turn::Consequences::MeepleRemoved) })
    assert(cs.any? { |c| c.is_a?(Turn::Consequences::TileConsumed) && c.klass == "BarracksTile" })
    assert p.complete?
  end

  test "place_meeple on own ship for movable tile (Lighthouse) errors (deferred to slice 3i.7)" do
    target = first_buildable_hex
    @game.board_contents.place_ship(target[0], target[1], 0)
    @game.save!

    p = phase(tile_klass: "LighthouseTile", kind: "ship")
    cs = p.handle(:place_meeple, game: @game, player_order: 0, row: target[0], col: target[1])
    assert_kind_of Turn::Consequences::Error, cs.first
  end

  test "place_meeple on opponent meeple errors" do
    target = first_buildable_hex
    @game.board_contents.place_warrior(target[0], target[1], 1)
    @game.save!

    p = phase
    cs = p.handle(:place_meeple, game: @game, player_order: 0, row: target[0], col: target[1])
    assert_kind_of Turn::Consequences::Error, cs.first
  end

  test "place_meeple at an unbuildable (e.g. water) hex errors" do
    target = first_water_hex
    p = phase
    cs = p.handle(:place_meeple, game: @game, player_order: 0, row: target[0], col: target[1])
    assert_kind_of Turn::Consequences::Error, cs.first
  end

  test "unsupported action returns Error" do
    p = phase
    cs = p.handle(:nonsense, game: @game, player_order: 0)
    assert_kind_of Turn::Consequences::Error, cs.first
  end

  private

  def first_buildable_hex
    20.times do |r|
      20.times do |c|
        next unless [ "C", "D", "F", "G", "T" ].include?(@game.board.terrain_at(r, c))
        return [ r, c ] if @game.board_contents.empty?(r, c)
      end
    end
    raise "no buildable hex"
  end

  def first_water_hex
    20.times do |r|
      20.times do |c|
        return [ r, c ] if @game.board.terrain_at(r, c) == "W" && @game.board_contents.empty?(r, c)
      end
    end
    raise "no water hex"
  end
end
