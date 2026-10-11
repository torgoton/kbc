class Scoring
  module Goals
    class Noblewomen < Goal
      DESCRIPTION = "5 points for each silver or gold hex you have the most settlements adjacent to."
      # ponytail: ties count for every tied player (see majority_hexes_score)
      def score_for(game_player)
        { score: majority_hexes_score(game_player, special_hexes) }
      end

      private

      def special_hexes
        (0..19).flat_map do |r|
          (0..19).filter_map { |c| [ r, c ] if %w[L S].include?(board_contents.terrain_at(r, c)) }
        end
      end
    end
  end
end
