module Tiles
  class Location
    class VillageTile < Tiles::Location
      CREATOR = "Icon by Setitik pixel".freeze
      DESCRIPTION = "Build on an eligible hex adjacent to at least 3 of your settlements.".freeze

      def builds_settlement? = true

      def valid_destinations(from_row: nil, from_col: nil, board_contents:, player_order:, hand: nil)
        settlements = board_contents.adjacency_sources_for(player_order).to_set
        board_contents.cells.select do |r, c|
          board_contents.available_for_building?(r, c) &&
            BUILDABLE_TERRAIN.include?(board_contents.terrain_at(r, c)) &&
            board_contents.neighbors(r, c).count { |nr, nc| settlements.include?([ nr, nc ]) } >= 3
        end
      end
    end
  end
end
