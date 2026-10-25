require "test_helper"

# Outpost waives adjacency only for builds that name a terrain: the mandatory
# action, or a tile that builds on a specific terrain (fixed, the played card,
# or Fort's drawn card). "The settlement must still be built on the appropriate
# terrain type for your mandatory action or the specific extra action."
class OutpostEligibilityTest < ActiveSupport::TestCase
  OUTPOST = { "klass" => "OutpostTile", "used" => false, "from" => "[9, 9]" }.freeze
  ALLOWED = %w[
    OracleTile FarmTile OasisTile GardenTile ForestersLodgeTile MonasteryTile FortTile CanoeBonusTile
    DonationCanyonTile DonationDesertTile DonationFlowerTile DonationGrassTile
    DonationMountainTile DonationTimberTile DonationWaterTile
  ].freeze
  NOT_ALLOWED = %w[TavernTile TowerTile VillageTile FountainTile CanoeTile].freeze

  def setup
    @game = games(:game2player)
    @game.boards = [ [ 1, 0 ], [ 5, 0 ], [ 0, 0 ], [ 4, 0 ] ]
    @game.board_contents = BoardState.new.tap { |s| s.place_settlement(19, 19, game_players(:chris).order) }
    @game.mandatory_count = Game::MANDATORY_COUNT
    @game.save!
    @chris = game_players(:chris)
    @chris.update!(hand: [ "G" ], tiles: [ OUTPOST.dup ])
  end

  def engine = TurnEngine.new(@game.reload)

  test "Outpost applies only to tiles that build on a named terrain" do
    ALLOWED.each { |klass| assert Tiles::Tile.for_klass(klass).new(0).outpost_applies?, klass }
    NOT_ALLOWED.each { |klass| assert_not Tiles::Tile.for_klass(klass).new(0).outpost_applies?, klass }
  end

  test "Outpost is usable for the mandatory action" do
    assert engine.outpost_activatable?(OUTPOST)
  end

  test "Outpost is usable for a tile with a named terrain" do
    @game.update!(current_action: { "type" => "farm", "klass" => "FarmTile" })
    assert engine.outpost_activatable?(OUTPOST)
  end

  test "Outpost is not usable for a tile without a named terrain" do
    @game.update!(current_action: { "type" => "village", "klass" => "VillageTile" })
    assert_not engine.outpost_activatable?(OUTPOST)
    assert_equal "Not in build action", engine.activate_outpost
    assert_equal "village", @game.reload.turn_phase.type
  end

  test "Outpost with Fort builds anywhere on the drawn card's terrain, and stays a Fort build" do
    @chris.update!(tiles: [ OUTPOST.dup, { "klass" => "FortTile", "used" => false, "from" => "[9, 8]" } ])
    @game.update!(current_action: { "type" => "fort", "klass" => "FortTile", "fort_terrain" => "G" })
    adjacent_only = engine.legal_targets

    engine.activate_outpost
    @game.reload
    assert_equal "fort", @game.turn_phase.type
    targets = engine.legal_targets
    assert_equal @game.board_contents.available_cells_of([ "G" ]).to_set, targets.to_set
    assert_operator targets.size, :>, adjacent_only.size

    far = (targets - adjacent_only).first
    engine.click(Coordinate.new(*far))
    assert_equal @chris.order, @game.reload.board_contents.player_at(*far)
  end
end
