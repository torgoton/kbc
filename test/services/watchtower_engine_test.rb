require "test_helper"

class WatchtowerEngineTest < ActiveSupport::TestCase
  def setup
    @game = Game.create!(state: "waiting", options: { "expansions" => %w[harvest] })
    @game.add_player(users(:chris))
    @game.add_player(users(:paula))
    @game.start
    @game.reload
    @game.boards = [ [ 20, 0 ], [ 1, 0 ], [ 0, 0 ], [ 4, 0 ] ]
    @player = @game.current_player
    @player.update!(hand: [ "G" ], tiles: [ { "klass" => "WatchtowerTile", "from" => "[4, 7]", "used" => false } ])
    opponent = (@game.game_players - [ @player ]).first.order
    @game.board_contents = BoardState.new.tap { |s| s.place_settlement(6, 2, @player.order) && s.place_settlement(6, 4, opponent) }
    @game.save!
    @engine = TurnEngine.new(@game.reload)
  end

  test "builds next to an opponent and is used up without spending the mandatory action" do
    assert @engine.tile_activatable?(@player.tiles.first)

    @engine.select_action("watchtower")
    assert_equal [ [ 6, 3 ] ], @engine.legal_targets.to_a
    @engine.click(Coordinate.new(6, 3))
    @game.reload

    assert_equal @player.order, @game.board_contents.player_at(6, 3)
    assert_equal 3, @game.mandatory_count
    assert @player.reload.tiles.first["used"]
  end
end
