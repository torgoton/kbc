module Tiles
  class Bonus
    class RefugeBonusTile < Tiles::Bonus
      CREATOR = "Claude (placeholder icon)".freeze
      DESCRIPTION = "Move one of your settlements in a straight line to the nearest suitable hex, " \
                    "jumping over any occupied or unsuitable hexes.".freeze
      CLASS_DESCRIPTION = "Bonus Tile - Awarded with the 2nd Refuge. Selectable from the turn after you acquire it.".freeze

      include Tiles::MovesFromSource

      def class_description = CLASS_DESCRIPTION

      # Along each of the 6 straight lines, the first empty buildable hex.
      def valid_destinations(from_row: nil, from_col: nil, board_contents:, player_order: nil, hand: nil, budget: nil)
        return [] if from_row.nil? || from_col.nil?
        BoardState::STRAIGHT_LINES.filter_map do |steps|
          r, c = from_row, from_col
          loop do
            dr, dc = steps[r % 2]
            r += dr
            c += dc
            break nil unless (0..19).cover?(r) && (0..19).cover?(c)
            break [ r, c ] if board_contents.available_for_building?(r, c) &&
              BUILDABLE_TERRAIN.include?(board_contents.terrain_at(r, c))
          end
        end
      end
    end
  end
end
