require "test_helper"

class Turn::ConsequencesTest < ActiveSupport::TestCase
  test "from_h dispatches on type discriminator" do
    placed = Turn::Consequences::SettlementPlaced.new(at: Coordinate.new(5, 7), player: 0, terrain: "G")
    consumed = Turn::Consequences::TileConsumed.new(klass: "FarmTile", player: 0)
    picked = Turn::Consequences::TilePickedUp.new(from: Coordinate.new(3, 4), klass: "FarmTile", player: 0)
    pushed = Turn::Consequences::SubPhasePushed.new(phase_type: "tile_build", state: { "x" => "y" })
    popped = Turn::Consequences::SubPhasePopped.new(prior_state: { "type" => "tile_build", "state" => {} })
    err = Turn::Consequences::Error.new(message: "nope")

    [ placed, consumed, picked, pushed, popped, err ].each do |c|
      assert_equal c, Turn::Consequences.from_h(c.to_h)
    end
  end

  test "from_h raises on unknown type" do
    assert_raises(ArgumentError) do
      Turn::Consequences.from_h({ "type" => "nonsense" })
    end
  end
end
