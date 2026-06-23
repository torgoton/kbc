module Tiles
  class Location
    class BarnTile < Tiles::Location
      CREATOR = "Icon by Cahya Kurniawan".freeze
      DESCRIPTION = "Move any of your settlements to a hex of the " \
                    "same terrain type as your played terrain card, adjacent " \
                    "if possible.".freeze
      def moves_settlement? = true
      def move_terrain(hand:) = hand
      def uses_played_terrain? = true
    end
  end
end
