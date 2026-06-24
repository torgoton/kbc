module Tiles
  class Location
    class HarborTile < Tiles::Location
      CREATOR = "Icon by Dicky Prayudawanto".freeze
      DESCRIPTION = "Move any one of your settlements to a water hex, adjacent if possible.".freeze

      def moves_settlement? = true
      def move_terrain(hand:) = "W"

      def valid_destinations(from_row: nil, from_col: nil, board_contents:, player_order:, hand: nil, budget: nil)
        other_settlements = board_contents.settlements_for(player_order).reject { |r, c| r == from_row && c == from_col }

        adjacent = other_settlements.flat_map do |r, c|
          board_contents.neighbors_where(r, c) do |nr, nc|
            board_contents.available_for_building?(nr, nc) && board_contents.terrain_at(nr, nc) == "W"
          end
        end.uniq

        return adjacent unless adjacent.empty?

        (0..19).flat_map do |r|
          (0..19).filter_map do |c|
            [ r, c ] if board_contents.available_for_building?(r, c) && board_contents.terrain_at(r, c) == "W"
          end
        end
      end
    end
  end
end
