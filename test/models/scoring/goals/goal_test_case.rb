require "test_helper"

class Scoring::Goals::GoalTestCase < ActiveSupport::TestCase
  BOARDS = [ [ 1, 0 ], [ 5, 0 ], [ 0, 0 ], [ 4, 0 ] ]

  def build_game(chris_settlements: [], paula_settlements: [], goals: [], boards: BOARDS)
    game = games(:game2player)
    chris = game_players(:chris)
    paula = game_players(:paula)
    game.boards = boards
    game.goals  = goals
    game.board_contents = BoardState.new.tap do |s|
      chris_settlements.each { |r, c| s.place_settlement(r, c, chris.order) }
      paula_settlements.each { |r, c| s.place_settlement(r, c, paula.order) }
    end
    game.save
    game.instantiate
    { game: game, chris: chris, paula: paula }
  end
end
