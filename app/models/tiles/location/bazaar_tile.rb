module Tiles
  class Location
    class BazaarTile < Tiles::Location
      CREATOR = "Claude".freeze
      DESCRIPTION = "Copy the action of another of your location tiles.".freeze

      def bazaar_tile? = true
      def bazaar_copyable? = false

      # Selectable when there is something to copy, which only the holder's tiles can tell
      # (TurnEngine#tile_actionable?).
      def activatable?(player_order:, board_contents:, hand: nil, supply: Hash.new(0)) = false
    end
  end
end
