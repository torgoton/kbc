module Tiles
  class OasisTile < Tiles::Tile
    def valid_destinations(board_contents:, board:, player_order:)
      player_settlements = board_contents
        .select { |_k, v| v["klass"] == "Settlement" && v["player"] == player_order }
        .keys
        .map { |k| k.tr("[]", "").split(", ").map(&:to_i) }

      adjacent_desert = player_settlements.flat_map do |r, c|
        Game::ADJACENCIES[r % 2].filter_map do |dr, dc|
          nr, nc = r + dr, c + dc
          next unless (0..19).cover?(nr) && (0..19).cover?(nc)
          next unless board_contents["[#{nr}, #{nc}]"].nil?
          next unless board.terrain_at(nr, nc) == "D"
          [ nr, nc ]
        end
      end.uniq

      return adjacent_desert unless adjacent_desert.empty?

      (0..19).flat_map do |r|
        (0..19).filter_map do |c|
          next unless board_contents["[#{r}, #{c}]"].nil?
          next unless board.terrain_at(r, c) == "D"
          [ r, c ]
        end
      end
    end
  end
end
