class Scoring
  module Goals
    class Noblewomen < Goal
      DESCRIPTION = "5 points for each silver or gold hex you have the most settlements adjacent to."
      # ponytail: ties count for every tied player (see majority_hexes_score)
      def score_for(game_player)
        { score: majority_hexes_score(game_player, terrain_hexes("L") + terrain_hexes("S")) }
      end
    end
  end
end
