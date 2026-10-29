module Tiles
  class Location
    class UniversityTile < Tiles::Location
      CREATOR = "Claude".freeze
      DESCRIPTION = "Not yet implemented.".freeze

      # Harvest tiles are placeholders until their rules are built.
      def activatable?(player_order:, board_contents:, hand: nil, supply: Hash.new(0)) = false
    end
  end
end
