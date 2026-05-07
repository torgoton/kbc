require "test_helper"

class TurnMandatoryBuildWithTreasureTest < ActiveSupport::TestCase
  def setup
    @game = Game.create!(state: "waiting")
    @game.add_player(users(:chris))
    @game.add_player(users(:paula))
    @game.start
    @game.reload
    @game.instantiate
    @player = @game.current_player
    @hand_terrain = @player.hand.first
  end

  test "build adjacent to a Treasure tile scores 3 points and removes the tile, then unwinds cleanly" do
    target = first_buildable_hex
    nbr_r, nbr_c = @game.board_contents.neighbors(target[0], target[1]).first
    @game.board_contents.place_tile(nbr_r, nbr_c, "TreasureTile", 1)
    @game.save!

    score_before = @player.reload.bonus_scores&.dig("treasure") || 0

    turn = Turn.from_game(@game.reload)
    @game.instantiate
    cs = turn.handle(:build, game: @game, row: target[0], col: target[1])
    ConsequenceApplier.apply!(@game, cs)

    @game.reload
    @player.reload
    assert_equal score_before + 3, @player.bonus_scores["treasure"]
    refute @player.tiles.any? { |t| t["klass"] == "TreasureTile" }, "treasure tile should be discarded after pickup"
    assert_equal 0, @game.board_contents.tile_qty(nbr_r, nbr_c)

    ConsequenceApplier.unapply!(@game.reload)

    @game.reload
    @player.reload
    assert_equal score_before, (@player.bonus_scores&.dig("treasure") || 0)
    refute @player.tiles.any? { |t| t["klass"] == "TreasureTile" }, "treasure tile fully gone after unwind"
    assert_equal 1, @game.board_contents.tile_qty(nbr_r, nbr_c)
    assert_equal 0, TurnClick.where(game: @game).count
  end

  private

  def first_buildable_hex
    20.times do |r|
      20.times do |c|
        return [ r, c ] if @game.board.terrain_at(r, c) == @hand_terrain && @game.board_contents.empty?(r, c)
      end
    end
    raise "no buildable #{@hand_terrain}"
  end
end
