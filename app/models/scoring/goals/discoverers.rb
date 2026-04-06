class Scoring
  module Goals
    class Discoverers < Goal
      DESCRIPTION = "1 point for each horizontal line on which you have at least 1 settlement"
      def score_for(game_player)
        rows = settlements_for(game_player.order).map(&:first).uniq
        { score: rows.size }
      end
    end
  end
end
