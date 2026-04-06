class Scoring
  module Goals
    class Miners < Goal
      DESCRIPTION = "1 point for each settlement next to but not on a mountain space"
      def score_for(game_player)
        { score: count_adjacent_to(game_player.order, "M") }
      end
    end
  end
end
