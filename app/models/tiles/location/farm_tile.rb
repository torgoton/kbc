module Tiles
  class Location
    class FarmTile < Tiles::Location
      CREATOR = "Icon by Marz Gallery".freeze
      DESCRIPTION = "Build on grass, adjacent if possible.".freeze

      def build_terrain = "G"
      def builds_settlement? = true
    end
  end
end
