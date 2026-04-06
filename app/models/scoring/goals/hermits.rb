class Scoring
  module Goals
    class Hermits < Goal
      DESCRIPTION = "1 point for each of your settlement areas"
      def score_for(game_player)
        { score: connected_components(game_player.order).size }
      end
    end
  end
end
