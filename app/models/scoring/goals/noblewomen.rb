class Scoring
  module Goals
    class Noblewomen < Goal
      DESCRIPTION = "Castle, Capitol, Silo, Nomad, and Location spaces score additionally like Palaces: " \
                    "5 points for each one you have the most settlements adjacent to."
      # ponytail: ties count for every tied player (see majority_hexes_score)
      # Palaces themselves are scored by the Palaces goal, not again here.
      def score_for(game_player)
        hexes = terrain_hexes("L") + terrain_hexes("S") - silver_hexes_of("Palace")
        { score: majority_hexes_score(game_player, hexes) }
      end
    end
  end
end
