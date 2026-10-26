module Tiles
  class Location
    class PaddockTile < Tiles::Location
      CREATOR = "Icon by M Yudi Maulana".freeze
      DESCRIPTION = "Move one of your existing settlements exactly two hexes in a straight line " \
                    "to any eligible hex. You may jump across " \
                    "<em>any</em> hex, even if occupied. ".freeze

      include Tiles::MovesFromSource

      def valid_destinations(from_row: nil, from_col: nil, board_contents:, player_order: nil, hand: nil, budget: nil)
        return [] if from_row.nil? || from_col.nil?
        BoardState::STRAIGHT_LINES.filter_map do |steps|
          dr1, dc1 = steps[from_row % 2]
          r1 = from_row + dr1
          c1 = from_col + dc1
          next unless (0..19).cover?(r1) && (0..19).cover?(c1)
          dr2, dc2 = steps[r1 % 2]
          r2 = r1 + dr2
          c2 = c1 + dc2
          next unless (0..19).cover?(r2) && (0..19).cover?(c2)
          next unless board_contents.available_for_building?(r2, c2)
          next unless BUILDABLE_TERRAIN.include?(board_contents.terrain_at(r2, c2))
          [ r2, c2 ]
        end
      end
    end
  end
end
