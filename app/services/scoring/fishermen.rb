class Scoring
  class Fishermen < Goal
    def score_for(game_player)
      count = settlements_for(game_player.order).count do |r, c|
        board.terrain_at(r, c) != "W" &&
          neighbors(r, c).any? { |nr, nc| board.terrain_at(nr, nc) == "W" }
      end
      { score: count }
    end
  end
end
