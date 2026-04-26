class Scoring
  module Goals
    class Knights < Goal
      DESCRIPTION = "2 points for each settlement on the horizontal line with the most of your settlements"
      def score_for(game_player)
        rows = settlements_for(game_player.order).map(&:first)
        best = rows.tally.values.max || 0
        { score: best * 2 }
      end
    end
  end
end
