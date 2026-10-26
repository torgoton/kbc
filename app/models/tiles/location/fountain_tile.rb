module Tiles
  class Location
    class FountainTile < Tiles::Location
      CREATOR = "Claude (placeholder icon)".freeze
      DESCRIPTION = "Build 1 settlement next to exactly 1 of your own settlements and next to no opponent's settlement." \
                    "<hr>When you collect a 2nd Fountain tile, you will get a Fountain Bonus tile." \
                    "<br>Fountain Bonus: Your Fountain tile builds may be on a mountain hex.".freeze

      def builds_settlement? = true
      def bonus_tile_klass = "FountainBonusTile"

      def buildable_terrain
        bonus_active?("FountainBonusTile") ? BUILDABLE_TERRAIN + [ "M" ] : BUILDABLE_TERRAIN
      end

      def valid_destinations(from_row: nil, from_col: nil, board_contents:, player_order:, hand: nil)
        board_contents.available_cells_of(buildable_terrain).select do |r, c|
          owners = board_contents.neighbors(r, c).filter_map { |nr, nc| board_contents.player_at(nr, nc) }
          owners.count(player_order) == 1 && owners.all?(player_order)
        end
      end
    end
  end
end
