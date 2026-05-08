require "test_helper"

class TurnMandatoryBuildWithGoalsTest < ActiveSupport::TestCase
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

  test "build adjacent to opponent scores ambassadors and unwinds cleanly" do
    @game.update!(goals: [ "ambassadors" ])
    target = first_buildable_hex
    nbr_r, nbr_c = @game.board_contents.neighbors(target[0], target[1]).first
    @game.board_contents.place_settlement(nbr_r, nbr_c, 1)
    @game.save!

    score_before = @player.reload.bonus_scores&.dig("ambassadors") || 0

    turn = Turn.from_game(@game.reload)
    @game.instantiate
    cs = turn.handle(:build, game: @game, row: target[0], col: target[1])
    ConsequenceApplier.apply!(@game, cs)

    @player.reload
    assert_equal score_before + 1, @player.bonus_scores["ambassadors"]

    ConsequenceApplier.unapply!(@game.reload)

    @player.reload
    assert_equal score_before, (@player.bonus_scores&.dig("ambassadors") || 0)
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
