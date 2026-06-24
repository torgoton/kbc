module Tiles
  class Location
    class GardenTile < Tiles::Location
      CREATOR = "Icon by Knickknacks Design".freeze
      DESCRIPTION = "Build on a flower hex, adjacent if possible.".freeze

      def build_terrain = "F"
      def builds_settlement? = true
    end
  end
end
