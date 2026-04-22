module Tiles
  class VillageTile < Tiles::Tile
    CREATOR = "Icon by Setitik pixel".freeze
    DESCRIPTION = "Build <em>one settlement</em> on an eligible space adjacent to <em>at least 3</em> of your settlements.".freeze

    def builds_settlement? = true

    def valid_destinations(from_row: nil, from_col: nil, board_contents:, board:, player_order:, hand: nil)
      settlements = board_contents.settlements_for(player_order).to_set
      (0..19).flat_map do |r|
        (0..19).filter_map do |c|
          next unless board_contents.available_for_building?(r, c)
          next unless BUILDABLE_TERRAIN.include?(board.terrain_at(r, c))
          adj_count = board_contents.neighbors(r, c).count { |nr, nc| settlements.include?([ nr, nc ]) }
          [ r, c ] if adj_count >= 3
        end
      end
    end
  end
end
