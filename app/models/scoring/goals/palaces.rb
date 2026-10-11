class Scoring
  module Goals
    class Palaces < Goal
      DESCRIPTION = "5 points for each Palace you have the most settlements adjacent to."
      def score_for(game_player)
        { score: majority_hexes_score(game_player, silver_hexes_of("Palace")) }
      end
    end
  end
end
