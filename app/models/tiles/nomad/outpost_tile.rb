module Tiles
  class Nomad
    class OutpostTile < Tiles::Nomad
      CREATOR = "Icon by Icon from us".freeze
      def tile_description = "Use DURING a build onto a specific terrain to skip adjacency requirement.".freeze

      def outpost_tile? = true

      def activatable?(player_order:, board_contents:, hand: nil, supply: Hash.new(0))
        false # activated via separate route, not the normal tile action flow
      end
    end
  end
end
