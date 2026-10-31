class Scoring
  module Goals
    class Rovers < Goal
      DESCRIPTION = "1 point for each board section you build on during your turn."
      def score_for(game_player)
        { score: game_player.bonus_scores&.dig("rovers").to_i }
      end
    end
  end
end
