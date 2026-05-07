require "test_helper"

class Turn::Consequences::SubPhasePushedTest < ActiveSupport::TestCase
  def setup
    @game = games(:game2player)
    @game.current_action = nil
  end

  test "writes sub_phase under current_action.turn" do
    consequence = Turn::Consequences::SubPhasePushed.new(
      phase_type: "tile_build",
      state: { "restricted_terrain" => "G", "tile_klass" => "FarmTile" }
    )
    consequence.apply!(@game)
    sub_phase = @game.current_action.dig("turn", "sub_phase")
    assert_equal "tile_build", sub_phase["type"]
    assert_equal "G", sub_phase.dig("state", "restricted_terrain")
    assert_equal "FarmTile", sub_phase.dig("state", "tile_klass")
  end

  test "preserves other current_action keys" do
    @game.current_action = { "type" => "mandatory" }
    Turn::Consequences::SubPhasePushed.new(phase_type: "tile_build", state: {}).apply!(@game)
    assert_equal "mandatory", @game.current_action["type"]
    assert_not_nil @game.current_action.dig("turn", "sub_phase")
  end

  test "unapply! clears the active sub_phase" do
    c = Turn::Consequences::SubPhasePushed.new(
      phase_type: "tile_build",
      state: { "restricted_terrain" => "G", "tile_klass" => "FarmTile" }
    )
    c.apply!(@game)
    assert_equal "tile_build", @game.current_action.dig("turn", "sub_phase", "type")
    c.unapply!(@game)
    assert_nil @game.current_action.dig("turn", "sub_phase")
  end
end
