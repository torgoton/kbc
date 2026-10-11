module Tiles
  class Location
    class FountainTile < Tiles::Location
      CREATOR = "Claude (placeholder icon)".freeze
      DESCRIPTION = "Build 1 settlement next to exactly 1 of your own settlements and next to no opponent's settlement.".freeze

      def builds_settlement? = true

      def valid_destinations(from_row: nil, from_col: nil, board_contents:, player_order:, hand: nil)
        (0..19).flat_map do |r|
          (0..19).filter_map do |c|
            next unless board_contents.available_for_building?(r, c)
            next unless BUILDABLE_TERRAIN.include?(board_contents.terrain_at(r, c))
            owners = board_contents.neighbors(r, c).filter_map { |nr, nc| board_contents.player_at(nr, nc) }
            [ r, c ] if owners.count(player_order) == 1 && owners.all?(player_order)
          end
        end
      end
    end
  end
end
