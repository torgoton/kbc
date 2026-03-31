class Scoring
  module Goals
    class Discoverers < Goal
      def score_for(game_player)
        rows = settlements_for(game_player.order).map(&:first).uniq
        { score: rows.size }
      end
    end
  end
end
