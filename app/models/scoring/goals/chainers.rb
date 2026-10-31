class Scoring
  module Goals
    class Chainers < Goal
      DESCRIPTION = "1 point for each of your settlements adjacent to exactly 2 of your settlements."
      def score_for(game_player)
        mine = settlements_for(game_player.order)
        { score: mine.count { |r, c| (neighbors(r, c) & mine).size == 2 } }
      end
    end
  end
end
