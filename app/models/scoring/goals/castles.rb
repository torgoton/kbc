class Scoring
  module Goals
    class Castles < Goal
      def score_for(game_player)
        order = game_player.order
        scored = castle_hexes.count do |cr, cc|
          neighbors(cr, cc).any? { |nr, nc| board_contents.player_at(nr, nc) == order }
        end
        { score: scored * 3 }
      end
    end
  end
end
