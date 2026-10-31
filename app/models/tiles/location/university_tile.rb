module Tiles
  class Location
    class UniversityTile < Tiles::Location::WaterMillTile
      CREATOR = "Claude".freeze
      DESCRIPTION = "Build on a hex next to a gold or silver hex, adjacent to your settlements if possible.".freeze

      def adjacent_terrains = %w[L S]
    end
  end
end
