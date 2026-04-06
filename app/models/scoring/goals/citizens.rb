class Scoring
  module Goals
    class Citizens < Goal
      DESCRIPTION = "1 point for every 2 settlements in your largest settlement group"
      def score_for(game_player)
        largest = connected_components(game_player.order).map(&:size).max || 0
        { score: largest / 2 }
      end
    end
  end
end
