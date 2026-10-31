require "test_helper"

class PalisadeEngineTest < ActiveSupport::TestCase
  def setup
    @game = Game.create!(state: "waiting", options: { "expansions" => %w[harvest] })
    @game.add_player(users(:chris))
    @game.add_player(users(:paula))
    @game.start
    @game.reload
    @game.boards = [ [ 20, 0 ], [ 1, 0 ], [ 0, 0 ], [ 4, 0 ] ]
    @player = @game.current_player
    @player.update!(hand: [ "G" ], tiles: [ { "klass" => "PalisadeTile", "from" => "[6, 2]", "used" => false } ])
    @game.board_contents = BoardState.new.tap { |s| [ [ 6, 3 ], [ 6, 4 ], [ 6, 5 ] ].each { |r, c| s.place_settlement(r, c, @player.order) } }
    @game.save!
    @engine = TurnEngine.new(@game.reload)
  end

  test "moves the middle settlement next to an end piece and is used up" do
    assert @engine.tile_activatable?(@player.tiles.first)

    @engine.select_action("palisade")
    @engine.click(Coordinate.new(6, 4))
    assert_equal [ [ 5, 2 ], [ 6, 2 ], [ 6, 6 ], [ 7, 2 ], [ 7, 3 ], [ 7, 5 ] ], TurnEngine.new(@game.reload).legal_targets.to_a.sort
    TurnEngine.new(@game).click(Coordinate.new(6, 6))
    @game.reload

    assert @game.board_contents.empty?(6, 4)
    assert_equal @player.order, @game.board_contents.player_at(6, 6)
    assert_equal 3, @game.mandatory_count
    assert @player.reload.tiles.first["used"]
  end
end
