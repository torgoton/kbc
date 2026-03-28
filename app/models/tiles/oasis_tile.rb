module Tiles
  class OasisTile < Tiles::Tile
    def build_terrain = "D"
    def builds_settlement? = true

    def valid_destinations(from_row: nil, from_col: nil, board_contents:, board:, player_order:)
      adjacent_desert = board_contents.settlements_for(player_order).flat_map do |r, c|
        board_contents.neighbors_where(r, c) do |nr, nc|
          board_contents.empty?(nr, nc) && board.terrain_at(nr, nc) == "D"
        end
      end.uniq

      return adjacent_desert unless adjacent_desert.empty?

      (0..19).flat_map do |r|
        (0..19).filter_map do |c|
          [ r, c ] if board_contents.empty?(r, c) && board.terrain_at(r, c) == "D"
        end
      end
    end

    def activatable?(player_order:, board_contents:, board:)
      valid_destinations(board_contents:, board:, player_order:).any?
    end
  end
end
