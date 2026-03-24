module Tiles
  class PaddockTile < Tiles::Tile
    BUILDABLE_TERRAIN = %w[C D F T G].freeze

    def location_index
      13
    end

    def valid_destinations(from_row, from_col, board_contents:, board:)
      origin_key = "[#{from_row}, #{from_col}]"
      # Collect direct neighbors
      direct = Game::ADJACENCIES[from_row % 2]
        .map { |r, c| [from_row + r, from_col + c] }
        .select { |r, c| (0..19).include?(r) && (0..19).include?(c) }
      # Collect neighbors-of-neighbors, excluding origin and direct neighbors
      excluded = direct.map { |r, c| "[#{r}, #{c}]" }.to_set << origin_key
      candidates = direct.flat_map do |r, c|
        Game::ADJACENCIES[r % 2].map { |dr, dc| [r + dr, c + dc] }
      end
      candidates.select! { |r, c| (0..19).include?(r) && (0..19).include?(c) }
      candidates.uniq!
      candidates.reject! { |r, c| excluded.include?("[#{r}, #{c}]") }
      # Filter: empty and buildable terrain
      candidates.select do |r, c|
        board_contents["[#{r}, #{c}]"].nil? &&
          BUILDABLE_TERRAIN.include?(board.terrain_at(r, c))
      end
    end

    def selectable_settlements(player_order, board_contents:, board:)
      board_contents
        .select { |_k, v| v["klass"] == "Settlement" && v["player"] == player_order }
        .keys
        .filter_map do |key|
          r, c = key.tr("[]", "").split(", ").map(&:to_i)
          [r, c] if valid_destinations(r, c, board_contents: board_contents, board: board).any?
        end
    end
  end
end
