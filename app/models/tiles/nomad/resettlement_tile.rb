module Tiles
  module Nomad
    class ResettlementTile < Tiles::NomadTile
      DESCRIPTION = "Move settlements using a shared budget of 4 steps. Vacated hexes are passable.".freeze

      def moves_settlement? = true

      # BFS up to `budget` steps from (from_row, from_col).
      # Vacated hexes count as empty/passable.
      def valid_destinations(from_row: nil, from_col: nil, board_contents:, board:, player_order:, hand: nil,
                             budget: 4, vacated: [])
        return [] if from_row.nil? || from_col.nil? || budget <= 0

        vacated_set = vacated.to_set
        reachable = []
        visited = {}
        queue = [ [ from_row, from_col, 0 ] ]

        until queue.empty?
          r, c, dist = queue.shift
          next if visited[[ r, c ]]
          visited[[ r, c ]] = true

          board_contents.neighbors(r, c).each do |nr, nc|
            next if visited[[ nr, nc ]]
            key = "[#{nr}, #{nc}]"
            is_empty = board_contents.empty?(nr, nc) || vacated_set.include?(key)
            next unless is_empty
            next unless BUILDABLE_TERRAIN.include?(board.terrain_at(nr, nc))

            new_dist = dist + 1
            next if new_dist > budget

            reachable << [ nr, nc ] unless reachable.include?([ nr, nc ])
            queue << [ nr, nc, new_dist ]
          end
        end

        reachable
      end

      def selectable_settlements(player_order:, board_contents:, board:, hand: nil,
                                  budget: 4, vacated: [])
        return [] if budget <= 0
        board_contents.settlements_for(player_order).filter_map do |r, c|
          [ r, c ] if valid_destinations(
            from_row: r, from_col: c,
            board_contents:, board:, player_order:,
            budget:, vacated:
          ).any?
        end
      end

      def activatable?(player_order:, board_contents:, board:, hand: nil)
        selectable_settlements(player_order:, board_contents:, board:, hand:).any?
      end
    end
  end
end
