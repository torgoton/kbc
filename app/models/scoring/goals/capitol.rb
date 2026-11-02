class Scoring
  module Goals
    class Capitol < Goal
      DESCRIPTION = "1 point for each of your settlements 1 or 2 hexes away from a Capitol."
      RANGE = (1..2)

      def score_for(game_player)
        capitols = silver_hexes_of("Capitol")
        { score: settlements_for(game_player.order).count { |s| capitols.any? { |c| RANGE.cover?(BoardState.distance(s, c)) } } }
      end
    end
  end
end
