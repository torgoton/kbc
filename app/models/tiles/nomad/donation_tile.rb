module Tiles
  module Nomad
    class DonationTile < Tiles::NomadTile
      CREATOR = "Icon by agus raharjo".freeze
      DESCRIPTION = "Build 3 settlements on the donation terrain. Build adjacent if possible.".freeze

      def description
        terrain_name = Boards::Board::TERRAIN_NAMES[build_terrain]
        "Build 3 settlements on #{terrain_name} spaces. Build adjacent if possible."
      end

      def builds_settlement? = true

      # build_terrain must be defined by subclasses
      def build_terrain
        raise NotImplementedError, "#{self.class} must define build_terrain"
      end

      def valid_destinations(from_row: nil, from_col: nil, board_contents:, board:, player_order:, hand: nil)
        terrain = build_terrain
        settlements = board_contents.settlements_for(player_order)

        # Adjacency-first: find empty hexes of build_terrain adjacent to player's settlements
        # Note: Donation tiles can build on W and M (unlike normal builds)
        adjacent = settlements.flat_map do |r, c|
          board_contents.neighbors_where(r, c) do |nr, nc|
            board_contents.available_for_building?(nr, nc) && board.terrain_at(nr, nc) == terrain
          end
        end.uniq

        return adjacent unless adjacent.empty?

        # Fallback: all empty hexes of that terrain anywhere on board
        (0..19).flat_map do |r|
          (0..19).filter_map do |c|
            [ r, c ] if board_contents.available_for_building?(r, c) && board.terrain_at(r, c) == terrain
          end
        end
      end

      def activatable?(player_order:, board_contents:, board:, hand: nil, warrior_supply: 0, ship_supply: 0)
        valid_destinations(board_contents:, board:, player_order:, hand:).any?
      end
    end
  end
end
