require "test_helper"

class TurnEndGameFlowTest < ActiveSupport::TestCase
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

  test "build that drops supply to 0 increments end_trigger_count via consequence" do
    @player.update!(supply: { "settlements" => 1 })
    target = first_empty_terrain(@hand_terrain)

    turn = Turn.from_game(@game.reload)
    @game.instantiate
    cs = turn.handle(:build, game: @game, row: target[0], col: target[1])
    ConsequenceApplier.apply!(@game, cs)

    @game.reload
    assert_equal 1, @game.end_trigger_count
    assert @game.ending?
  end

  test "end_turn after end-trigger by last player completes the game" do
    @game.update!(end_trigger_count: 1)
    last_order = @game.game_players.count - 1
    last_player = @game.game_players.find { |gp| gp.order == last_order }
    @game.update!(current_player: last_player)
    last_player.update!(hand: "G") if last_player.hand.is_a?(Array)

    turn = Turn.from_game(@game.reload)
    @game.instantiate
    cs = turn.handle(:end_turn, game: @game)
    ConsequenceApplier.apply!(@game, cs)

    @game.reload
    assert_equal "completed", @game.state
    refute_nil @game.scores
  end

  test "end_turn after end-trigger by a non-last player does NOT complete the game" do
    @game.update!(end_trigger_count: 1)
    @game.update!(current_player: @game.game_players.find { |gp| gp.order == 0 })

    turn = Turn.from_game(@game.reload)
    @game.instantiate
    cs = turn.handle(:end_turn, game: @game)
    ConsequenceApplier.apply!(@game, cs)

    @game.reload
    refute_equal "completed", @game.state
  end

  test "undo of a build that triggered ending decrements end_trigger_count" do
    @player.update!(supply: { "settlements" => 1 })
    target = first_empty_terrain(@hand_terrain)

    turn = Turn.from_game(@game.reload)
    @game.instantiate
    ConsequenceApplier.apply!(@game, turn.handle(:build, game: @game, row: target[0], col: target[1]))
    assert_equal 1, @game.reload.end_trigger_count

    ConsequenceApplier.unapply!(@game.reload)
    assert_equal 0, @game.reload.end_trigger_count
  end

  private

  def first_empty_terrain(terrain)
    20.times do |r|
      20.times do |c|
        return [ r, c ] if @game.board.terrain_at(r, c) == terrain && @game.board_contents.empty?(r, c)
      end
    end
    raise "no empty #{terrain}"
  end
end
