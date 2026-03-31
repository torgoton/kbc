class Scoring
  module Goals
    class Hermits < Goal
      def score_for(game_player)
        { score: connected_components(game_player.order).size }
      end
    end
  end
end
