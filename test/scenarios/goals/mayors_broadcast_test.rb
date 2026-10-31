require "test_helper"
require_relative "mayors_test"

# The controller broadcasts right after the engine mutates the in-memory game,
# so the board must show the new Mayor marker without a page refresh.
class MayorsBroadcastTest < ActiveSupport::TestCase
  test "broadcast board includes the marker claimed in the same request" do
    t = MayorsScenarioTest.new("x").setup_row
    game = Game.find(t.scenario.game.id)
    game.instantiate
    TurnEngine.new(game).click(Coordinate.new(*t.last))

    board = nil
    game.define_singleton_method(:broadcast_update_to) do |*, **opts|
      board = ApplicationController.render(partial: opts[:partial], locals: opts[:locals]) if opts[:target] == "board"
    end
    game.broadcast_game_update

    assert_includes board, "mayor-marker\""
  end
end
