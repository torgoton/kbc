class Scoring
  module Goals
    class Miners < Goal
      def score_for(game_player)
        { score: count_adjacent_to(game_player.order, "M") }
      end
    end
  end
end
