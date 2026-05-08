require "test_helper"

class Turn::SubPhases::FortPhaseTest < ActiveSupport::TestCase
  def setup
    @game = Game.create!(state: "waiting")
    @game.add_player(users(:chris))
    @game.add_player(users(:paula))
    @game.start
    @game.reload
    @game.instantiate
    @player = @game.current_player
  end

  def fort_phase(builds_remaining: 2, fort_terrain: "G")
    Turn::SubPhases::FortPhase.new(fort_terrain: fort_terrain, builds_remaining: builds_remaining)
  end

  test "to_h round-trips through from_h" do
    phase = fort_phase
    h = phase.to_h
    assert_equal "G", h["fort_terrain"]
    assert_equal 2, h["builds_remaining"]
    rebuilt = Turn::SubPhases::FortPhase.from_h(h)
    assert_equal phase.fort_terrain, rebuilt.fort_terrain
    assert_equal phase.builds_remaining, rebuilt.builds_remaining
  end

  test "handle(:build) emits SettlementPlaced + SubPhaseStateUpdated when builds_remaining > 1" do
    target = first_empty_terrain("G")
    phase = fort_phase(fort_terrain: "G", builds_remaining: 2)
    cs = phase.handle(:build, game: @game, player_order: 0, row: target[0], col: target[1])

    assert(cs.any? { |c| c.is_a?(Turn::Consequences::SettlementPlaced) })
    update = cs.find { |c| c.is_a?(Turn::Consequences::SubPhaseStateUpdated) }
    refute_nil update
    assert_equal 1, update.new_state["builds_remaining"]
    refute phase.complete?
  end

  test "handle(:build) marks complete when last build is consumed" do
    target = first_empty_terrain("G")
    phase = fort_phase(builds_remaining: 1)
    phase.handle(:build, game: @game, player_order: 0, row: target[0], col: target[1])
    assert phase.complete?
  end

  test "handle(:build) errors when terrain doesn't match fort_terrain" do
    target = first_empty_terrain_other_than("G")
    phase = fort_phase(fort_terrain: "G", builds_remaining: 2)
    cs = phase.handle(:build, game: @game, player_order: 0, row: target[0], col: target[1])
    assert_kind_of Turn::Consequences::Error, cs.first
  end

  test "handle(:build) errors when target is occupied" do
    target = first_empty_terrain("G")
    @game.board_contents.place_settlement(target[0], target[1], 1)
    phase = fort_phase(fort_terrain: "G", builds_remaining: 2)
    cs = phase.handle(:build, game: @game, player_order: 0, row: target[0], col: target[1])
    assert_kind_of Turn::Consequences::Error, cs.first
  end

  private

  def first_empty_terrain(terrain)
    20.times do |r|
      20.times do |c|
        return [ r, c ] if @game.board.terrain_at(r, c) == terrain && @game.board_contents.empty?(r, c)
      end
    end
    raise "no empty #{terrain}"
  end

  def first_empty_terrain_other_than(terrain)
    20.times do |r|
      20.times do |c|
        t = @game.board.terrain_at(r, c)
        next if t.nil? || t == terrain
        return [ r, c ] if @game.board_contents.empty?(r, c)
      end
    end
    raise "no empty non-#{terrain} hex"
  end
end
