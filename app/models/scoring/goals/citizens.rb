class Scoring
  module Goals
    class Citizens < Goal
      def score_for(game_player)
        largest = connected_components(game_player.order).map(&:size).max || 0
        { score: largest / 2 }
      end
    end
  end
end
