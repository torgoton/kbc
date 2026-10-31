class Scoring
  module Goals
    class Travellers < Goal
      DESCRIPTION = "1 point for each settlement at the edge of the game board."
      def score_for(game_player)
        { score: settlements_for(game_player.order).count { |r, c| [ r, c ].intersect?([ 0, 19 ]) } }
      end
    end
  end
end
