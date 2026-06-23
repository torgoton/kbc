module Tiles
  class Location
    class OasisTile < Tiles::Location
      CREATOR = "Icon by kusuma potter".freeze
      DESCRIPTION = "Build on desert, adjacent if possible.".freeze

      def build_terrain = "D"
      def builds_settlement? = true
    end
  end
end
