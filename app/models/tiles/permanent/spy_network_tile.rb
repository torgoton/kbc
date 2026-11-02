module Tiles
  class Permanent
    class SpyNetworkTile < Tiles::Permanent
      CREATOR = "Claude".freeze
      DESCRIPTION = Game::DECREES["spy_network"][:description]

      def spy_network_tile? = true

      # Selectable when the opponent to the right holds a location tile to use
      # (TurnEngine#tile_actionable?).
      def activatable?(**) = false
    end
  end
end
