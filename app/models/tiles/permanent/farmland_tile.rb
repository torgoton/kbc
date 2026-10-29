module Tiles
  class Permanent
    class FarmlandTile < Tiles::Permanent
      CREATOR = "Claude".freeze
      DESCRIPTION = "Build on Farmland adjacent to one of your settlements. Optional, once per turn.".freeze

      def build_terrain = "H"
      def builds_settlement? = true

      # Unlike other terrain tiles there is no "anywhere" fallback: no adjacent farmland, no action.
      def valid_destinations(from_row: nil, from_col: nil, board_contents:, player_order:, hand: nil, supply: Hash.new(0), budget: nil)
        board_contents.settlements_for(player_order).flat_map do |row, col|
          board_contents.neighbors_where(row, col) { |nr, nc| board_contents.available_for_building?(nr, nc) && board_contents.terrain_at(nr, nc) == build_terrain }
        end.uniq
      end
    end
  end
end
