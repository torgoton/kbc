module Tiles
  class Location
    class ForestersLodgeTile < Tiles::Location
      CREATOR = "Icon by keenicon".freeze
      DESCRIPTION = "Build on timberland, adjacent if possible.".freeze

      def build_terrain = "T"
      def builds_settlement? = true
    end
  end
end
