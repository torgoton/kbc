module Tiles
  module Nomad
    class OutpostTile < Tiles::NomadTile
      CREATOR = "Icon by Icon from us".freeze
      DESCRIPTION = "Activate to skip adjacency requirement for the current build.".freeze

      def outpost_tile? = true

      def activatable?(player_order:, board_contents:, board:, hand: nil, supply: Hash.new(0))
        false # activated via separate route, not the normal tile action flow
      end
    end
  end
end
