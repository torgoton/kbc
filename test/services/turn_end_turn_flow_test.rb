require "test_helper"

class TurnEndTurnFlowTest < ActiveSupport::TestCase
  def setup
    @game = Game.create!(state: "waiting")
    @game.add_player(users(:chris))
    @game.add_player(users(:paula))
    @game.start
    @game.reload
    @game.instantiate
    @player = @game.current_player
  end

  test "build then end_turn advances current_player; undo blocked at the end_turn boundary" do
    hand_terrain = @player.hand.first
    target = first_empty_terrain(hand_terrain)

    # Click 1: build (reversible).
    turn = Turn.from_game(@game.reload)
    @game.instantiate
    ConsequenceApplier.apply!(@game, turn.handle(:build, game: @game, row: target[0], col: target[1]))

    @game.reload
    assert_equal @player.order, @game.current_player.order
    assert_equal 2, @game.current_action.dig("turn", "mandatory_remaining")

    # Click 2: end_turn (irreversible).
    turn = Turn.from_game(@game.reload)
    @game.instantiate
    ConsequenceApplier.apply!(@game, turn.handle(:end_turn, game: @game))

    @game.reload
    refute_equal @player.order, @game.current_player.order
    refute @game.current_action.key?("turn"), "turn state cleared after end_turn"
    end_turn_click = TurnClick.most_recent_for(@game)
    assert_equal false, end_turn_click.reversible

    # Undo end_turn → blocked.
    assert_raises(ConsequenceApplier::NotReversibleError) do
      ConsequenceApplier.unapply!(@game.reload)
    end
  end

  test "end_turn draws 2 cards when player holds CrossroadsTile and resets next player tiles" do
    @game.update!(deck: [ "G", "F", "T" ], discard: [ "C" ])
    @player.update!(hand: [ "T" ], tiles: [ { "klass" => "CrossroadsTile", "from" => "[5, 5]", "used" => false } ])
    next_player = @game.game_players.find { |g| g.order != @player.order }
    next_player.update!(tiles: [ { "klass" => "FarmTile", "from" => "[3, 4]", "used" => true } ])
    @game.reload
    @game.instantiate

    turn = Turn.from_game(@game)
    ConsequenceApplier.apply!(@game, turn.handle(:end_turn, game: @game))

    @player.reload
    assert_equal [ "G", "F" ], @player.hand
    next_player.reload
    assert_equal false, next_player.tiles.first["used"]
  end

  test "end_turn drops nomad tiles whose expires_on_turn matches the ending turn" do
    @game.update!(turn_number: 4)
    @player.update!(tiles: [
      { "klass" => "FarmTile", "from" => "[3, 4]", "used" => true },
      { "klass" => "DonationGrassTile", "from" => "[5, 6]", "used" => true, "expires_on_turn" => 4 }
    ])
    @game.reload
    @game.instantiate

    turn = Turn.from_game(@game)
    ConsequenceApplier.apply!(@game, turn.handle(:end_turn, game: @game))

    @player.reload
    klasses = @player.tiles.map { |t| t["klass"] }
    assert_includes klasses, "FarmTile"
    refute_includes klasses, "DonationGrassTile"
  end

  test "end_turn refreshes hand by drawing one card" do
    @game.update!(deck: [ "G", "F" ], discard: [ "C" ])
    @player.update!(hand: [ "T" ])
    @game.reload
    @game.instantiate

    turn = Turn.from_game(@game)
    ConsequenceApplier.apply!(@game, turn.handle(:end_turn, game: @game))

    @player.reload
    assert_equal [ "G" ], @player.hand
    @game.reload
    assert_equal [ "F" ], @game.deck
    assert_equal [ "C", "T" ], @game.discard
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
