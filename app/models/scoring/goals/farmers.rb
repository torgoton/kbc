class Scoring
  module Goals
    class Farmers < Goal
      DESCRIPTION = "3 points for each of your settlements on the board section with the fewest such settlements"
      def score_for(game_player)
        counts = quadrant_counts(game_player.order)
        fewest = counts.min
        { score: fewest * 3 }
      end

      private

      def quadrant_counts(order)
        settlements = settlements_for(order)
        4.times.map do |i|
          row_min = i / 2 * 10
          col_min = i % 2 * 10
          settlements.count { |r, c| r >= row_min && r < row_min + 10 && c >= col_min && c < col_min + 10 }
        end
      end
    end
  end
end
