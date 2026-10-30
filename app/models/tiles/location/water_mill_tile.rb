module Tiles
  class Location
    class WaterMillTile < Tiles::Location
      CREATOR = "Claude".freeze
      DESCRIPTION = "Build on a hex next to water, adjacent to your settlements if possible.".freeze

      def builds_settlement? = true

      # The terrain a built hex must touch; MountainStationTile overrides it.
      def adjacent_terrain = "W"

      def valid_destinations(from_row: nil, from_col: nil, board_contents:, player_order:, hand: nil, supply: Hash.new(0), budget: nil)
        mine = board_contents.settlements_for(player_order)
        by_water = (0..19).flat_map do |r|
          (0..19).filter_map do |c|
            next unless board_contents.available_for_building?(r, c) && BUILDABLE_TERRAIN.include?(board_contents.terrain_at(r, c))
            [ r, c ] if board_contents.neighbors(r, c).any? { |nr, nc| board_contents.terrain_at(nr, nc) == adjacent_terrain }
          end
        end
        adjacent = by_water.select { |r, c| board_contents.neighbors(r, c).any? { |n| mine.include?(n) } }
        adjacent.presence || by_water
      end
    end
  end
end
