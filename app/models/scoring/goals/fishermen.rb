class Scoring
  module Goals
    class Fishermen < Goal
      DESCRIPTION = "1 point for each settlement next to but not on water"
      def score_for(game_player)
        { score: count_adjacent_to(game_player.order, "W") }
      end
    end
  end
end
