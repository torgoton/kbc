class Scoring
  module Goals
    class Families < Goal
      DESCRIPTION = "2 points if the first 3 settlements you build in your mandatory action form a straight line (horizontally or diagonally), every turn. Only those 3 builds count: not Temple pieces, tile builds or Swamp (2 builds), and a Plateaus move doesn't change where they were built."
      def score_for(game_player)
        { score: game_player.bonus_scores&.dig("families").to_i }
      end
    end
  end
end
