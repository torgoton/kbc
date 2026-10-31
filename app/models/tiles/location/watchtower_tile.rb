module Tiles
  class Location
    class WatchtowerTile < Tiles::Location
      CREATOR = "Claude".freeze
      DESCRIPTION = "Build on a hex next to an opponent's settlement, adjacent to your settlements if possible.".freeze

      def builds_settlement? = true

      def valid_destinations(from_row: nil, from_col: nil, board_contents:, player_order:, hand: nil, supply: Hash.new(0), budget: nil)
        mine = board_contents.adjacency_sources_for(player_order)
        by_opponent = (0..19).flat_map do |r|
          (0..19).filter_map do |c|
            next unless board_contents.available_for_building?(r, c) && BUILDABLE_TERRAIN.include?(board_contents.terrain_at(r, c))
            [ r, c ] if board_contents.neighbors(r, c).any? { |nr, nc| (owner = board_contents.player_at(nr, nc)) && owner != player_order }
          end
        end
        adjacent = by_opponent.select { |r, c| board_contents.neighbors(r, c).any? { |n| mine.include?(n) } }
        adjacent.presence || by_opponent
      end
    end
  end
end
