module Tiles
  class LighthouseTile < Tiles::Tile
    CREATOR = "Icon by franc11s".freeze
    DESCRIPTION = "Place, move, or remove your ship".freeze

    def places_meeple? = true

    def on_pickup(game_player:)
      game_player.add_ships!(1)
    end

    def activatable?(player_order:, board_contents:, board:, hand: nil, warrior_supply: 0, ship_supply: 0)
      ship_supply > 0 || board_contents.ships_for(player_order).any?
    end

    # No from_row/from_col: placement hexes + own ship hex (for popup triggering).
    # With from_row/from_col: BFS move destinations through empty water up to 3 steps.
    def valid_destinations(from_row: nil, from_col: nil, board_contents:, board:, player_order:, hand: nil, warrior_supply: 0, ship_supply: 0)
      if from_row && from_col
        water_bfs(from_row, from_col, board_contents:, board:, max_depth: 3)
      else
        ships = board_contents.ships_for(player_order)
        placement = ship_supply > 0 ? placement_hexes(board_contents:, board:, player_order:) : []
        (placement + ships).uniq
      end
    end

    def selectable_ships(player_order:, board_contents:, board:)
      board_contents.ships_for(player_order).select do |r, c|
        water_bfs(r, c, board_contents:, board:, max_depth: 3).any?
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

    def water_bfs(from_row, from_col, board_contents:, board:, max_depth:)
      visited = { [ from_row, from_col ] => 0 }
      queue = [ [ from_row, from_col, 0 ] ]
      reachable = []
      while queue.any?
        r, c, depth = queue.shift
        next if depth >= max_depth
        board_contents.neighbors(r, c).each do |nr, nc|
          next if visited.key?([ nr, nc ])
          next unless board.terrain_at(nr, nc) == "W"
          next unless board_contents.empty?(nr, nc)
          visited[[ nr, nc ]] = depth + 1
          reachable << [ nr, nc ]
          queue << [ nr, nc, depth + 1 ]
        end
      end
      reachable
    end
  end
end
