module Tiles
  class WagonTile < Tiles::Tile
    CREATOR = "Icon by Chris Schumann".freeze
    DESCRIPTION = "Place, move, or remove your wagon".freeze

    SUITABLE_TERRAIN = (BUILDABLE_TERRAIN + [ "M" ]).freeze

    def places_meeple? = true
    def meeple_kind    = "wagon"

    def on_pickup(game_player:)
      game_player.add_wagons!(1)
    end

    def activatable?(player_order:, board_contents:, board:, hand: nil, supply: Hash.new(0))
      supply["wagon"] > 0 || board_contents.wagons_for(player_order).any?
    end

    # No from_row/from_col: placement hexes + own wagon hexes (for popup triggering).
    # With from_row/from_col: BFS move destinations through empty suitable terrain up to 3 steps.
    def valid_destinations(from_row: nil, from_col: nil, board_contents:, board:, player_order:, hand: nil, supply: Hash.new(0))
      if from_row && from_col
        terrain_bfs(from_row, from_col, board_contents:, board:, max_depth: 3)
      else
        wagons = board_contents.wagons_for(player_order)
        placement = supply["wagon"] > 0 ? placement_hexes(board_contents:, board:, player_order:) : []
        (placement + wagons).uniq
      end
    end

    def selectable_wagons(player_order:, board_contents:, board:)
      board_contents.wagons_for(player_order).select do |r, c|
        terrain_bfs(r, c, board_contents:, board:, max_depth: 3).any?
      end
    end

    private

    def placement_hexes(board_contents:, board:, player_order:)
      own = board_contents.settlements_for(player_order)
      adjacent = own.flat_map do |r, c|
        board_contents.neighbors_where(r, c) do |nr, nc|
          board_contents.empty?(nr, nc) && SUITABLE_TERRAIN.include?(board.terrain_at(nr, nc))
        end
      end.uniq
      return adjacent unless adjacent.empty?
      (0..19).flat_map do |r|
        (0..19).filter_map do |c|
          [ r, c ] if board_contents.empty?(r, c) && SUITABLE_TERRAIN.include?(board.terrain_at(r, c))
        end
      end
    end

    def terrain_bfs(from_row, from_col, board_contents:, board:, max_depth:)
      visited = { [ from_row, from_col ] => 0 }
      queue = [ [ from_row, from_col, 0 ] ]
      reachable = []
      while queue.any?
        r, c, depth = queue.shift
        next if depth >= max_depth
        board_contents.neighbors(r, c).each do |nr, nc|
          next if visited.key?([ nr, nc ])
          next unless SUITABLE_TERRAIN.include?(board.terrain_at(nr, nc))
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
