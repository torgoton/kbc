module Tiles
  class Location
    class MountainStationTile < Tiles::Location::WaterMillTile
      CREATOR = "Claude".freeze
      DESCRIPTION = "Build on a hex next to a mountain, adjacent to your settlements if possible.".freeze

      def adjacent_terrains = %w[M]
    end
  end
end
