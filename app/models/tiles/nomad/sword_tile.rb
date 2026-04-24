module Tiles
  module Nomad
    class SwordTile < Tiles::NomadTile
      CREATOR = "Icon by Muhammad Naufal Subhiansyah".freeze
      DESCRIPTION = "Remove one settlement from each opponent.".freeze

      def sword_tile? = true

      def action_message(player_handle:, terrain_names:, hand: nil)
        "#{player_handle} must select a settlement to remove"
      end

      def activatable?(player_order:, board_contents:, board:, hand: nil, supply: Hash.new(0))
        # Activatable if any opponent has settlements; full validation done in select_action
        true
      end
    end
  end
end
