require "test_helper"

class TurnMandatoryBuildTest < ActiveSupport::TestCase
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

  test "three mandatory builds each write a TurnClick and decrement remaining" do
    targets = three_buildable_targets

    targets.each_with_index do |(row, col), i|
      turn = Turn.from_game(@game.reload)
      @game.instantiate
      assert_equal 3 - i, turn.mandatory_remaining
      ConsequenceApplier.apply!(@game, turn.handle(:build, game: @game, row: row, col: col))
    end

    assert_equal 3, TurnClick.where(game: @game).count
    assert_equal 0, Turn.from_game(@game.reload).mandatory_remaining
  end

  test "4th build errors and does not write a click" do
    @game.current_action = { "turn" => { "mandatory_remaining" => 0 } }
    @game.save!

    target = first_buildable_hex
    turn = Turn.from_game(@game.reload)
    cs = turn.handle(:build, game: @game, row: target[0], col: target[1])

    assert_kind_of Turn::Consequences::Error, cs.first
    assert_raises(ConsequenceApplier::ApplyError) do
      ConsequenceApplier.apply!(@game, cs)
    end
    assert_equal 0, TurnClick.where(game: @game).count
  end

  test "three unapply! calls fully reverse three builds" do
    targets = three_buildable_targets

    targets.each do |(row, col)|
      turn = Turn.from_game(@game.reload)
      @game.instantiate
      ConsequenceApplier.apply!(@game, turn.handle(:build, game: @game, row: row, col: col))
    end

    3.times { ConsequenceApplier.unapply!(@game.reload) }

    @game.reload
    @game.instantiate
    assert_equal 0, TurnClick.where(game: @game).count
    assert_equal 3, Turn.from_game(@game).mandatory_remaining
    targets.each do |(row, col)|
      assert_nil @game.board_contents.player_at(row, col)
    end
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

  # First build can land anywhere on the matching terrain; subsequent builds must
  # be adjacent to a previous player(0) settlement on the same terrain. Walk the
  # board picking the next valid target after each placement.
  def three_buildable_targets
    placed = []
    targets = []
    seed = first_buildable_hex
    targets << seed
    placed << seed

    until targets.size == 3
      next_target = adjacent_buildable_for(placed)
      raise "could not find adjacency-valid third build" unless next_target
      targets << next_target
      placed << next_target
    end
    targets
  end

  def adjacent_buildable_for(placed)
    placed.each do |pr, pc|
      @game.board_contents.neighbors(pr, pc).each do |nr, nc|
        next unless @game.board.terrain_at(nr, nc) == @hand_terrain
        next unless @game.board_contents.empty?(nr, nc)
        next if placed.include?([ nr, nc ])
        return [ nr, nc ]
      end
    end
    nil
  end
end
