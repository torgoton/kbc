require "test_helper"

class TurnFortFlowTest < ActiveSupport::TestCase
  def setup
    @game = Game.create!(state: "waiting")
    @game.add_player(users(:chris))
    @game.add_player(users(:paula))
    @game.start
    @game.reload
    @game.instantiate
    @player = @game.current_player
  end

  test "activate fort, build twice, undo blocked at the activate boundary" do
    @player.update!(tiles: [ { "klass" => "FortTile", "from" => "[3, 4]", "used" => false } ])
    # Force the deck so we know what gets drawn.
    @game.update!(deck: [ "G", "F", "T" ], discard: [ "C" ])

    # Click 1: activate_fort (irreversible).
    turn = Turn.from_game(@game.reload)
    @game.instantiate
    cs = turn.handle(:activate_fort, game: @game)
    ConsequenceApplier.apply!(@game, cs)

    @game.reload
    assert_equal "fort", @game.current_action.dig("turn", "sub_phase", "type")
    assert_equal 2, @game.current_action.dig("turn", "sub_phase", "state", "builds_remaining")
    assert_equal "G", @game.current_action.dig("turn", "sub_phase", "state", "fort_terrain")
    fort_click = TurnClick.most_recent_for(@game)
    assert_equal false, fort_click.reversible

    # Click 2: build #1 in fort phase.
    turn = Turn.from_game(@game.reload)
    @game.instantiate
    target1 = first_empty_terrain("G")
    cs = turn.handle(:build, game: @game, row: target1[0], col: target1[1])
    ConsequenceApplier.apply!(@game, cs)

    @game.reload
    assert_equal 1, @game.current_action.dig("turn", "sub_phase", "state", "builds_remaining")

    # Click 3: build #2 — completes fort phase.
    turn = Turn.from_game(@game.reload)
    @game.instantiate
    target2 = first_empty_terrain("G")
    cs = turn.handle(:build, game: @game, row: target2[0], col: target2[1])
    ConsequenceApplier.apply!(@game, cs)

    @game.reload
    assert_nil @game.current_action.dig("turn", "sub_phase")
    assert_equal 3, TurnClick.where(game: @game).count

    # Undo build #2 → reversible. Undo build #1 → reversible. Undo activate_fort → blocked.
    ConsequenceApplier.unapply!(@game.reload)
    ConsequenceApplier.unapply!(@game.reload)
    assert_raises(ConsequenceApplier::NotReversibleError) do
      ConsequenceApplier.unapply!(@game.reload)
    end

    # Activate-fort click still in the log (not consumed).
    assert_equal 1, TurnClick.where(game: @game).count
    assert_equal false, TurnClick.most_recent_for(@game).reversible
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
