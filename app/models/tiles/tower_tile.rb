module Tiles
  class TowerTile < Tiles::Tile
    def builds_settlement? = true

    def valid_destinations(from_row: nil, from_col: nil, board_contents:, board:, player_order:, hand: nil)
      border = ->(r, c) { r == 0 || r == 19 || c == 0 || c == 19 }
      buildable = ->(r, c) { BUILDABLE_TERRAIN.include?(board.terrain_at(r, c)) }

      adjacent = board_contents.settlements_for(player_order).flat_map do |r, c|
        board_contents.neighbors_where(r, c) do |nr, nc|
          border.(nr, nc) && board_contents.empty?(nr, nc) && buildable.(nr, nc)
        end
      end.uniq

      return adjacent unless adjacent.empty?

      (0..19).flat_map do |r|
        (0..19).filter_map do |c|
          [ r, c ] if border.(r, c) && board_contents.empty?(r, c) && buildable.(r, c)
        end
      end
    end
  end
end
