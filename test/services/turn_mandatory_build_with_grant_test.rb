require "test_helper"

class TurnMandatoryBuildWithGrantTest < ActiveSupport::TestCase
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

  test "build adjacent to a Barracks tile grants 2 warriors and unwinds cleanly" do
    target = first_buildable_hex
    nbr_r, nbr_c = @game.board_contents.neighbors(target[0], target[1]).first
    @game.board_contents.place_tile(nbr_r, nbr_c, "BarracksTile", 1)
    @game.save!

    warriors_before = @player.reload.warriors_remaining

    turn = Turn.from_game(@game.reload)
    @game.instantiate
    cs = turn.handle(:build, game: @game, row: target[0], col: target[1])
    ConsequenceApplier.apply!(@game, cs)

    @game.reload
    @player.reload
    assert_equal warriors_before + 2, @player.warriors_remaining
    assert_equal 1, TurnClick.where(game: @game).count

    ConsequenceApplier.unapply!(@game.reload)

    @player.reload
    assert_equal warriors_before, @player.warriors_remaining
    assert_equal 0, TurnClick.where(game: @game).count
  end

  test "build adjacent to a Lighthouse tile grants 1 ship" do
    target = first_buildable_hex
    nbr_r, nbr_c = @game.board_contents.neighbors(target[0], target[1]).first
    @game.board_contents.place_tile(nbr_r, nbr_c, "LighthouseTile", 1)
    @game.save!

    ships_before = @player.reload.ships_remaining

    turn = Turn.from_game(@game.reload)
    @game.instantiate
    ConsequenceApplier.apply!(@game, turn.handle(:build, game: @game, row: target[0], col: target[1]))

    assert_equal ships_before + 1, @player.reload.ships_remaining
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
