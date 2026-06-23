class Scoring
  module Goals
    class Workers < Goal
      DESCRIPTION = "1 point for each settlement next to a silver or gold hex."
      def score_for(game_player)
        count = settlements_for(game_player.order).count do |r, c|
          neighbors(r, c).any? { |nr, nc| %w[S L].include?(board_contents.terrain_at(nr, nc)) }
        end
        { score: count }
      end
    end
  end
end
