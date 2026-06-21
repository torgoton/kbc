module Tiles
  class Location
    class FarmTile < Tiles::Location
      CREATOR = "Icon by Marz Gallery".freeze
      DESCRIPTION = "Build <em>one settlement</em> on a <em>grass space.</em> Build adjacent if possible.".freeze

      def build_terrain = "G"
      def builds_settlement? = true
    end
  end
end
