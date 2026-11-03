module Tiles
  class Location
    class WaterMillTile < Tiles::Location
      CREATOR = "Claude".freeze
      DESCRIPTION = "Build on a hex next to water, adjacent to your settlements if possible.".freeze

      def builds_settlement? = true

      # The terrains a built hex must touch one of; Mountain Station and University override it.
      def adjacent_terrains = Boards::Board::WATER

      def valid_destinations(from_row: nil, from_col: nil, board_contents:, player_order:, hand: nil, supply: Hash.new(0), budget: nil)
        mine = board_contents.adjacency_sources_for(player_order)
        by_water = board_contents.cells.select do |r, c|
          board_contents.available_for_building?(r, c) && BUILDABLE_TERRAIN.include?(board_contents.terrain_at(r, c)) &&
            board_contents.neighbors(r, c).any? { |nr, nc| adjacent_terrains.include?(board_contents.terrain_at(nr, nc)) }
        end
        adjacent = by_water.select { |r, c| board_contents.neighbors(r, c).any? { |n| mine.include?(n) } }
        adjacent.presence || by_water
      end
    end
  end
end
