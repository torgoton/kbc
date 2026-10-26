module Tiles
  class Location
    class FortTile < Tiles::Location
      CREATOR = "Icon by agus raharjo".freeze
      DESCRIPTION = "CANNOT be undone! Draw a card and build on that terrain, adjacent if possible.".freeze

      def builds_settlement? = true
      def fort_tile? = true

      def activatable?(player_order:, board_contents:, hand: nil, supply: Hash.new(0))
        true
      end

      # The drawn card may be a Marshlands dual card ("GB" => "Grass / Swamp").
      def action_message(player_handle:, terrain_names:, hand: nil)
        hand ? "#{player_handle} must build on a #{Boards::Board.card_name(hand)} hex" : "#{player_handle} must build"
      end
    end
  end
end
