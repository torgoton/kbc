module Tiles
  class Location
    class RefugeTile < Tiles::Location
      CREATOR = "Claude (placeholder icon)".freeze
      DESCRIPTION = "Move one of your existing settlements to an adjacent unoccupied hex of a suitable terrain." \
                    "<hr>When you collect a 2nd Refuge tile, you will get a Refuge Bonus tile." \
                    "<br>Refuge Bonus: Move one of your settlements in a straight line to the next empty suitable hex.".freeze

      include Tiles::MovesFromSource

      def bonus_tile_klass = "RefugeBonusTile"

      def valid_destinations(from_row: nil, from_col: nil, board_contents:, player_order: nil, hand: nil, budget: nil)
        return [] if from_row.nil? || from_col.nil?
        board_contents.neighbors(from_row, from_col).select do |r, c|
          board_contents.available_for_building?(r, c) && BUILDABLE_TERRAIN.include?(board_contents.terrain_at(r, c))
        end
      end
    end
  end
end
