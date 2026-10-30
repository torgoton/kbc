class Scoring
  module Goals
    class Rangers < Goal
      DESCRIPTION = "2 points for each horizontal line which has exactly 1 of your settlements."
      def score_for(game_player)
        rows = settlements_for(game_player.order).map(&:first)
        { score: rows.tally.values.count(1) * 2 }
      end
    end
  end
end
