module Tiles
  class Location
    class CrossroadsTile < Tiles::Location
      CREATOR = "Icon by Gregor Cresnar".freeze
      DESCRIPTION = "Draw an extra card each turn. This happens automatically. " \
        "Choose one card to play each turn. " \
        "Both cards are discarded.".freeze

      def activatable?(**) = false
      def crossroads_tile? = true
    end
  end
end
