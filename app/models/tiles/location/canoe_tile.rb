module Tiles
  class Location
    class CanoeTile < Tiles::Location
      CREATOR = "Claude (placeholder icon)".freeze
      DESCRIPTION = "Whenever another player takes the last tile from a location, " \
                    "you may build 1 settlement on Water or Swamp (adjacent if possible)." \
                    "<hr>When you collect a 2nd Canoe tile, you will get a Canoe Bonus tile." \
                    "<br>Canoe Bonus: Build 1 settlement on Water or Swamp, adjacent if possible.".freeze
      TERRAINS = %w[W B].freeze

      def builds_settlement? = true
      def canoe_tile? = true
      def bonus_tile_klass = "CanoeBonusTile"

      # A reaction to a location emptying, never a normal tile action.
      def activatable?(player_order:, board_contents:, hand: nil, supply: Hash.new(0))
        false
      end

      def action_message(player_handle:, terrain_names:, hand: nil)
        "#{player_handle} may use the Canoe"
      end
    end
  end
end
