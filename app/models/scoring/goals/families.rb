class Scoring
  module Goals
    class Families < Goal
      DESCRIPTION = "2 points if you built all 3 settlements of the mandatory action adjacent to each other in straight line (horizontally or diagonally)"
      def score_for(game_player)
        { score: game_player.bonus_scores&.dig("families").to_i }
      end
    end
  end
end
