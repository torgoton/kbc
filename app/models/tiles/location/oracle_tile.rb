module Tiles
  class Location
    class OracleTile < Tiles::Location
      CREATOR = "Icon by Cahya Kurniawan".freeze
      DESCRIPTION = "Build on a hex of the same terrain type as your played terrain card, adjacent if possible.".freeze

      def builds_settlement? = true
      def uses_played_terrain? = true
    end
  end
end
