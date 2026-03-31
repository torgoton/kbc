class Scoring
  module Goals
    class Fishermen < Goal
      def score_for(game_player)
        { score: count_adjacent_to(game_player.order, "W") }
      end
    end
  end
end
