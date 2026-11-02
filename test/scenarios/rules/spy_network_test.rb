require "test_helper"

class SpyNetworkScenarioTest < ActiveSupport::TestCase
  # Player 0 holds the Spy Network beside grass; player 1 (to their right) holds the given tiles.
  def spy_scenario(*opponent_tiles, players: 2, mine: [])
    scenario = GameScenario.new(players:, hands: { 0 => "G", 1 => "D", 2 => "D" })
    @home = scenario.empty_hex_adjacent_to("G")
    scenario.place_settlement(0, at: @home)
    scenario.give_tile(0, "SpyNetworkTile", from: [ 0, 0 ])
    mine.each { |klass| scenario.give_tile(0, klass, from: [ 0, 1 ]) }
    opponent_tiles.each { |klass, used| scenario.give_tile(1, klass, from: [ 0, 2 ], used: used || false) }
    scenario
  end

  test "lists the right-hand opponent's location tiles, used or not" do
    assert_equal [ [ "FarmTile", nil, nil ] ], spy_scenario([ "FarmTile", false ]).spy_entries(0)
    assert_equal [ [ "FarmTile", nil, nil ] ], spy_scenario([ "FarmTile", true ]).spy_entries(0)
  end

  test "leaves out Canoe, Nomad, Bonus and permanent tiles" do
    scenario = spy_scenario([ "FarmTile" ], [ "CanoeTile" ], [ "OutpostTile" ], [ "TempleBonusTile" ], [ "FarmlandTile" ])
    assert_equal [ [ "FarmTile", nil, nil ] ], scenario.spy_entries(0)
  end

  test "only the opponent to the right counts, not the one to the left" do
    scenario = spy_scenario(players: 3)
    scenario.give_tile(1, "FarmTile", from: [ 0, 2 ]) # player 1 is to player 0's left
    assert_empty scenario.spy_entries(0)
    scenario.give_tile(2, "FarmTile", from: [ 0, 3 ]) # player 2 plays just before player 0
    assert_equal [ [ "FarmTile", nil, nil ] ], scenario.spy_entries(0)
  end

  test "using their Farm builds like Farm, uses up Spy Network, and leaves their Farm alone" do
    scenario = spy_scenario([ "FarmTile", true ])
    scenario.activate_spy("FarmTile")

    assert_equal %w[select_action spy_copy], scenario.moves.pluck(:action)
    targets = scenario.buildable_cells
    assert targets.any?
    assert(targets.all? { |t| scenario.terrain_at(t) == "G" })
    scenario.build_settlement(at: targets.first)

    assert scenario.tile_used?(0, "SpyNetworkTile")
    assert scenario.tile_used?(1, "FarmTile"), "their Farm keeps the state it had"
    assert_equal 3, scenario.mandatory_remaining
  end

  test "can be undone" do
    scenario = spy_scenario([ "FarmTile" ])
    scenario.activate_spy("FarmTile")
    scenario.undo
    assert_not scenario.tile_used?(0, "SpyNetworkTile")
    assert_equal [ [ "FarmTile", nil, nil ] ], scenario.spy_entries(0)
  end

  test "using their Crossroads draws an extra card at the end of the turn" do
    scenario = spy_scenario([ "CrossroadsTile" ])
    scenario.activate_spy("CrossroadsTile")
    assert scenario.tile_used?(0, "SpyNetworkTile")
    scenario.end_turn
    assert_equal 2, scenario.hand(0).size
  end

  test "using their Bazaar copies one of my own tiles, without a Bazaar of my own" do
    scenario = spy_scenario([ "BazaarTile" ], mine: [ "FarmTile" ])
    assert_equal [ [ "FarmTile", nil, "BazaarTile" ] ], scenario.spy_entries(0)

    scenario.activate_spy("FarmTile", via: "BazaarTile")
    targets = scenario.buildable_cells
    assert(targets.all? { |t| scenario.terrain_at(t) == "G" })
    scenario.build_settlement(at: targets.first)

    assert scenario.tile_used?(0, "SpyNetworkTile")
    assert_not scenario.tile_used?(0, "FarmTile"), "my Farm is untouched"
  end

  test "a tile I could only use through their Bazaar isn't offered twice" do
    scenario = spy_scenario([ "BazaarTile" ], [ "FarmTile" ], mine: [ "FarmTile" ])
    assert_equal [ [ "FarmTile", nil, nil ] ], scenario.spy_entries(0)
  end

  test "can't be used without anything to use" do
    scenario = spy_scenario
    assert_not_includes scenario.available_tile_actions(0), "SpyNetworkTile"
    assert_raises(GameScenario::IllegalMove) { scenario.activate_spy("FarmTile") }
  end
end
