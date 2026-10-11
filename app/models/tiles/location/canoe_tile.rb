module Tiles
  class Location
    class CanoeTile < Tiles::Location
      CREATOR = "Claude (placeholder icon)".freeze
      DESCRIPTION = "Whenever any location is emptied, you may choose a terrain and build 1 settlement on it " \
                    "(adjacent if possible). Once per turn.".freeze

      def builds_settlement? = true
      def canoe_tile? = true

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
