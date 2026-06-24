module Tiles
  class Nomad
    class DonationTile < Tiles::Nomad
      CREATOR = "".freeze

      def tile_description
        terrain_name = Boards::Board::TERRAIN_NAMES[build_terrain]
        "Build 3 settlements on #{terrain_name}, adjacent if possible."
      end

      def builds_settlement? = true
      def repeats_build? = true
      def build_quota = 3

      # build_terrain must be defined by subclasses
      def build_terrain
        raise NotImplementedError, "#{self.class} must define build_terrain"
      end

      def valid_destinations(from_row: nil, from_col: nil, board_contents:, player_order:, hand: nil)
        terrain = build_terrain
        settlements = board_contents.settlements_for(player_order)

        # Adjacency-first: find empty hexes of build_terrain adjacent to player's settlements
        # Note: Donation tiles can build on W and M (unlike normal builds)
        adjacent = settlements.flat_map do |r, c|
          board_contents.neighbors_where(r, c) do |nr, nc|
            board_contents.available_for_building?(nr, nc) && board_contents.terrain_at(nr, nc) == terrain
          end
        end.uniq

        return adjacent unless adjacent.empty?

        # Fallback: all empty hexes of that terrain anywhere on board
        (0..19).flat_map do |r|
          (0..19).filter_map do |c|
            [ r, c ] if board_contents.available_for_building?(r, c) && board_contents.terrain_at(r, c) == terrain
          end
        end
      end

      def activatable?(player_order:, board_contents:, hand: nil, supply: Hash.new(0))
        valid_destinations(board_contents:, player_order:, hand:).any?
      end
    end
  end
end
