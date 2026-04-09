class Scoring
  module Goals
    class Ambassadors < Goal
      DESCRIPTION = "1 point for each settlement built adjacent to at least 1 settlement of another player"
      def score_for(game_player)
        { score: 0 }
      end
    end
  end
end
