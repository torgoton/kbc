class Scoring
  module Goals
    class Shepherds < Goal
      DESCRIPTION = "2 points for each settlement built not adjacent to an empty space of the same terrain"
      def score_for(game_player)
        { score: 0 }
      end
    end
  end
end
