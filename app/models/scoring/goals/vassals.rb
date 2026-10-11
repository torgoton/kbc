class Scoring
  module Goals
    class Vassals < Goal
      DESCRIPTION = "1 point for each settlement next to at least one inner edge of a game board section."
      INNER = [ 9, 10 ].freeze
      def score_for(game_player)
        { score: settlements_for(game_player.order).count { |r, c| INNER.include?(r) || INNER.include?(c) } }
      end
    end
  end
end
