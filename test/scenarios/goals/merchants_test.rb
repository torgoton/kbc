require "test_helper"

# Tracer for a Tier-1 (board-derived) goal: Merchants is recomputed from the
# board via Scoring::Goals::Merchants, not accumulated during play, so it can
# be exercised with direct settlement placement and read back through the
# Scoring seam.
class MerchantsScenarioTest < ActiveSupport::TestCase
  test "a connected settlement group adjacent to 2 distinct locations scores 8 merchants points" do
    scenario = GameScenario.new(goals: [ "merchants" ])
    chain = scenario.connected_empty_hexes_with_specials(%w[L S], 2)
    raise "fixed board should offer a chain adjacent to 2 distinct locations" unless chain

    chain.each { |spot| scenario.place_settlement(0, at: spot) }

    assert_equal 8, scenario.score_for("merchants", 0)
  end

  test "a connected settlement group adjacent to 3 distinct locations scores 12 merchants points" do
    scenario = GameScenario.new(goals: [ "merchants" ])
    chain = scenario.connected_empty_hexes_with_specials(%w[L S], 3, max_length: 9)
    raise "fixed board should offer a chain adjacent to 3 distinct locations" unless chain

    chain.each { |spot| scenario.place_settlement(0, at: spot) }

    assert_equal 12, scenario.score_for("merchants", 0)
  end

  test "a connected settlement group with 2 paths to the same location still scores 8 merchants points" do
    scenario = GameScenario.new(goals: [ "merchants" ])
    chain = scenario.connected_empty_hexes_with_specials(%w[L S], 2, require_redundant: true)
    raise "fixed board should offer a chain with a doubly-connected location" unless chain

    chain.each { |spot| scenario.place_settlement(0, at: spot) }

    assert_equal 8, scenario.score_for("merchants", 0)
  end
end
