module Tiles
  class Location
    class MonasteryTile < Tiles::Location
      CREATOR = "Icon by Eucalyp".freeze
      DESCRIPTION = "Build on a canyon hex, adjacent if possible.".freeze

      def build_terrain = "C"
      def builds_settlement? = true
    end
  end
end
