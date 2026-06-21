module Tiles
  class Location
    class WagonTile < Tiles::Location
      CREATOR = "Icon by Chris Schumann".freeze
      DESCRIPTION = "Place, move, or remove your wagon".freeze

      SUITABLE_TERRAIN = (BUILDABLE_TERRAIN + [ "M" ]).freeze

      def places_meeple? = true
      def meeple_kind    = "wagon"

      def on_pickup(game_player:)
        game_player.add_wagons!(1)
      end

      def activatable?(player_order:, board_contents:, hand: nil, supply: Hash.new(0))
        supply["wagon"] > 0 || board_contents.wagons_for(player_order).any?
      end

      # No from_row/from_col: placement hexes + own wagon hexes (for popup triggering).
      # With from_row/from_col: the single move step — adjacent empty suitable-terrain hexes.
      def valid_destinations(from_row: nil, from_col: nil, board_contents:, player_order:, hand: nil, supply: Hash.new(0))
        if from_row && from_col
          board_contents.neighbors_where(from_row, from_col) do |nr, nc|
            board_contents.available_for_building?(nr, nc) && SUITABLE_TERRAIN.include?(board_contents.terrain_at(nr, nc))
          end
        else
          wagons = board_contents.wagons_for(player_order)
          placement = supply["wagon"] > 0 ? placement_hexes(board_contents:, player_order:) : []
          (placement + wagons).uniq
        end
      end

      private

      def placement_hexes(board_contents:, player_order:)
        own = board_contents.settlements_for(player_order)
        adjacent = own.flat_map do |r, c|
          board_contents.neighbors_where(r, c) do |nr, nc|
            board_contents.empty?(nr, nc) && SUITABLE_TERRAIN.include?(board_contents.terrain_at(nr, nc))
          end
        end.uniq
        return adjacent unless adjacent.empty?
        (0..19).flat_map do |r|
          (0..19).filter_map do |c|
            [ r, c ] if board_contents.empty?(r, c) && SUITABLE_TERRAIN.include?(board_contents.terrain_at(r, c))
          end
        end
      end
    end
  end
end
