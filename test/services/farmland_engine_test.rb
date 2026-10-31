require "test_helper"

class FarmlandEngineTest < ActiveSupport::TestCase
  # Section 20 at index 0: row 6 is "MCCHHHHHDM", so (6,2) is Canyon beside farmland at (6,3).
  def setup
    @game = Game.create!(state: "waiting", options: { "expansions" => %w[harvest] })
    @game.add_player(users(:chris))
    @game.add_player(users(:paula))
    @game.start
    @game.reload
    @game.boards = [ [ 20, 0 ], [ 1, 0 ], [ 0, 0 ], [ 4, 0 ] ]
    @player = @game.current_player
    @player.update!(hand: [ "G" ], tiles: [ { "klass" => "FarmlandTile", "used" => false } ])
  end

  def place(*cells)
    @game.board_contents = BoardState.new.tap { |s| cells.each { |r, c| s.place_settlement(r, c, @player.order) } }
    @game.save!
    TurnEngine.new(@game.reload)
  end

  test "selectable only with a settlement adjacent to open farmland" do
    tile = @player.tiles.first

    assert place([ 6, 2 ]).tile_activatable?(tile)
    assert_not place([ 0, 0 ]).tile_activatable?(tile)
  end

  test "builds a settlement on adjacent farmland and is used up for the turn" do
    engine = place([ 6, 2 ])
    engine.select_action("farmland")
    assert_includes engine.legal_targets, [ 6, 3 ]
    assert_not_includes engine.legal_targets, [ 6, 6 ], "farmland not adjacent to a settlement"

    engine.click(Coordinate.new(6, 3))
    @game.reload

    assert_equal "H", @game.board.terrain_at(6, 3)
    assert_equal @player.order, @game.board_contents.player_at(6, 3)
    assert_equal 3, @game.mandatory_count, "tile build does not use up the mandatory action"
    assert @player.reload.tiles.first["used"]
    assert_not TurnEngine.new(@game).tile_activatable?(@player.tiles.first)
  end

  test "is usable again the next turn" do
    engine = place([ 6, 2 ])
    engine.select_action("farmland")
    engine.click(Coordinate.new(6, 3))
    @player.reload.reset_tiles!

    assert_not @player.tiles.first["used"]
  end

  test "Outpost waives adjacency: any open farmland is a target" do
    @player.update!(tiles: @player.tiles + [ { "klass" => "OutpostTile", "used" => false } ])
    engine = place([ 6, 2 ])
    engine.select_action("farmland")
    engine.activate_outpost

    assert_includes TurnEngine.new(@game.reload).legal_targets, [ 6, 6 ]
    assert_equal @game.board_contents.available_cells_of([ "H" ]).sort, TurnEngine.new(@game).legal_targets.to_a.sort
  end
end
