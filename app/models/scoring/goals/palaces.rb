class Scoring
  module Goals
    class Palaces < Goal
      DESCRIPTION = "5 points for each Palace you have the most settlements adjacent to."
      # Noblewomen scores every special hex, Palaces included, so Palaces scores 0 when it is in play.
      def score_for(game_player)
        return { score: 0 } if Array(@game.goals).include?("noblewomen")

        { score: majority_hexes_score(game_player, silver_hexes_of("Palace")) }
      end
    end
  end
end
