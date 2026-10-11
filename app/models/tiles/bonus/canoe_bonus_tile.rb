module Tiles
  class Bonus
    class CanoeBonusTile < Tiles::Bonus
      CREATOR = "Claude (placeholder icon)".freeze
      DESCRIPTION = "Build 1 settlement on Water or Swamp (adjacent if possible).".freeze
      CLASS_DESCRIPTION = "Bonus Tile - Awarded with the 2nd Canoe. Selectable from the turn after you acquire it.".freeze
      TERRAINS = %w[W B].freeze

      def class_description = CLASS_DESCRIPTION
      def builds_settlement? = true

      def valid_destinations(from_row: nil, from_col: nil, board_contents:, player_order:, hand: nil, supply: Hash.new(0), budget: nil)
        board_contents.buildable_cells_for_any(player_order, TERRAINS)
      end

      def activatable?(player_order:, board_contents:, hand: nil, supply: Hash.new(0))
        valid_destinations(board_contents:, player_order:).any?
      end
    end
  end
end
