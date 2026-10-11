module Tiles
  class Location
    class RefugeTile < Tiles::Location
      CREATOR = "Claude (placeholder icon)".freeze
      DESCRIPTION = "Move one of your existing settlements to an adjacent unoccupied hex of a suitable terrain.".freeze

      def moves_settlement? = true

      def valid_destinations(from_row: nil, from_col: nil, board_contents:, player_order: nil, hand: nil, budget: nil)
        return [] if from_row.nil? || from_col.nil?
        board_contents.neighbors(from_row, from_col).select do |r, c|
          board_contents.available_for_building?(r, c) && BUILDABLE_TERRAIN.include?(board_contents.terrain_at(r, c))
        end
      end

      def activatable?(player_order:, board_contents:, hand: nil, supply: Hash.new(0))
        selectable_settlements(player_order:, board_contents:, hand:).any?
      end

      def selectable_settlements(player_order:, board_contents:, hand: nil, budget: nil)
        board_contents.settlements_for(player_order).filter_map do |r, c|
          next if board_contents.city_hall_at?(r, c)
          [ r, c ] if valid_destinations(from_row: r, from_col: c, board_contents:).any?
        end
      end
    end
  end
end
