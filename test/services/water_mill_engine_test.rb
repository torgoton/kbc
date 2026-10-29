require "test_helper"

class WaterMillEngineTest < ActiveSupport::TestCase
  def setup
    @game = Game.create!(state: "waiting", options: { "expansions" => %w[harvest] })
    @game.add_player(users(:chris))
    @game.add_player(users(:paula))
    @game.start
    @game.reload
    @game.boards = [ [ 20, 0 ], [ 1, 0 ], [ 0, 0 ], [ 4, 0 ] ]
    @player = @game.current_player
    @player.update!(hand: [ "G" ], tiles: [ { "klass" => "WaterMillTile", "from" => "[3, 2]", "used" => false } ])
    @game.board_contents = BoardState.new.tap { |s| s.place_settlement(6, 2, @player.order) }
    @game.save!
    @engine = TurnEngine.new(@game.reload)
  end

  test "is selectable, builds next to water, and is used up without spending the mandatory action" do
    assert @engine.tile_activatable?(@player.tiles.first)

    @engine.select_action("watermill")
    assert_equal [ [ 5, 2 ], [ 6, 3 ] ], @engine.legal_targets.to_a.sort
    @engine.click(Coordinate.new(5, 2))
    @game.reload

    assert_equal @player.order, @game.board_contents.player_at(5, 2)
    assert_equal 3, @game.mandatory_count
    assert @player.reload.tiles.first["used"]
  end

  test "rejects a hex that is not next to water" do
    @engine.select_action("watermill")
    @engine.click(Coordinate.new(6, 1))
    @game.reload

    assert_nil @game.board_contents.player_at(6, 1)
  end
end
