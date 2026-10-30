module Tiles
  class Location
    class PalisadeTile < Tiles::Location
      CREATOR = "Claude".freeze
      DESCRIPTION = "Move one of your settlements to a hex next to another settlement in the same connected area.".freeze

      include Tiles::MovesFromSource

      # The area is the cluster of your settlements containing the mover, taken before the move.
      def valid_destinations(from_row: nil, from_col: nil, board_contents:, player_order: nil, hand: nil, budget: nil)
        return [] if from_row.nil? || from_col.nil?
        area = area_around(board_contents, board_contents.player_at(from_row, from_col), [ from_row, from_col ])
        (area - [ [ from_row, from_col ] ]).flat_map do |r, c|
          board_contents.neighbors_where(r, c) do |nr, nc|
            board_contents.available_for_building?(nr, nc) && BUILDABLE_TERRAIN.include?(board_contents.terrain_at(nr, nc))
          end
        end.uniq
      end

      private

      def area_around(board_contents, owner, start)
        mine = board_contents.adjacency_sources_for(owner)
        area = [ start ]
        area.each do |r, c|
          board_contents.neighbors(r, c).each { |n| area << n if mine.include?(n) && !area.include?(n) }
        end
        area
      end
    end
  end
end
