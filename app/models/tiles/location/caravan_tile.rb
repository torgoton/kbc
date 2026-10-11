module Tiles
  class Location
    class CaravanTile < Tiles::Location
      CREATOR = "Icon by Smalllike".freeze
      DESCRIPTION = "Move one of your own settlements in a straight line until it is blocked by an obstacle.".freeze

      include Tiles::MovesFromSource

      def valid_destinations(from_row: nil, from_col: nil, board_contents:, player_order: nil, hand: nil, budget: nil)
        return [] if from_row.nil? || from_col.nil?
        BoardState::STRAIGHT_LINES.filter_map do |steps|
          last = nil
          r, c = from_row, from_col
          loop do
            dr, dc = steps[r % 2]
            nr, nc = r + dr, c + dc
            break unless (0..19).cover?(nr) && (0..19).cover?(nc) &&
                         board_contents.available_for_building?(nr, nc) &&
                         BUILDABLE_TERRAIN.include?(board_contents.terrain_at(nr, nc))
            last = [ nr, nc ]
            r, c = nr, nc
          end
          last
        end
      end
    end
  end
end
