module Tiles
  module Nomad
    class ResettlementTile < Tiles::NomadTile
      CREATOR = "Icon by Icon from us".freeze
      DESCRIPTION = "Move settlements using a shared budget of 4 steps.".freeze

      def moves_settlement? = true
      def resettles? = true

      # The single move step from (from_row, from_col): adjacent empty buildable
      # hexes. `budget` gates whether any step remains this turn.
      def valid_destinations(from_row: nil, from_col: nil, board_contents:, player_order:, hand: nil,
                             budget: 4)
        return [] if from_row.nil? || from_col.nil? || budget <= 0

        board_contents.neighbors_where(from_row, from_col) do |nr, nc|
          board_contents.available_for_building?(nr, nc) && BUILDABLE_TERRAIN.include?(board_contents.terrain_at(nr, nc))
        end
      end

      def selectable_settlements(player_order:, board_contents:, hand: nil, budget: 4)
        return [] if budget <= 0
        board_contents.settlements_for(player_order).filter_map do |r, c|
          next if board_contents.city_hall_at?(r, c)
          [ r, c ] if valid_destinations(
            from_row: r, from_col: c,
            board_contents:, player_order:,
            budget:
          ).any?
        end
      end

      def activatable?(player_order:, board_contents:, hand: nil, supply: Hash.new(0))
        selectable_settlements(player_order:, board_contents:, hand:).any?
      end
    end
  end
end
