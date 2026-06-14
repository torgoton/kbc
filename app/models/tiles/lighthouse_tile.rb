module Tiles
  class LighthouseTile < Tiles::Tile
    CREATOR = "Icon by franc11s".freeze
    DESCRIPTION = "Place, move, or remove your ship".freeze

    def places_meeple? = true
    def meeple_kind    = "ship"

    def on_pickup(game_player:)
      game_player.add_ships!(1)
    end

    def activatable?(player_order:, board_contents:, board:, hand: nil, supply: Hash.new(0))
      supply["ship"] > 0 || board_contents.ships_for(player_order).any?
    end

    # No from_row/from_col: placement hexes + own ship hex (for popup triggering).
    # With from_row/from_col: the single move step — adjacent empty water hexes.
    def valid_destinations(from_row: nil, from_col: nil, board_contents:, board:, player_order:, hand: nil, supply: Hash.new(0))
      if from_row && from_col
        board_contents.neighbors_where(from_row, from_col) do |nr, nc|
          board_contents.available_for_building?(nr, nc) && board.terrain_at(nr, nc) == "W"
        end
      else
        ships = board_contents.ships_for(player_order)
        placement = supply["ship"] > 0 ? placement_hexes(board_contents:, board:, player_order:) : []
        (placement + ships).uniq
      end
    end

    private

    def placement_hexes(board_contents:, board:, player_order:)
      own = board_contents.settlements_for(player_order)
      adjacent = own.flat_map do |r, c|
        board_contents.neighbors_where(r, c) do |nr, nc|
          board_contents.empty?(nr, nc) && board.terrain_at(nr, nc) == "W"
        end
      end.uniq
      return adjacent unless adjacent.empty?
      (0..19).flat_map do |r|
        (0..19).filter_map { |c| [ r, c ] if board_contents.empty?(r, c) && board.terrain_at(r, c) == "W" }
      end
    end
  end
end
