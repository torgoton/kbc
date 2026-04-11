module Tiles
  class QuarryTile < Tiles::Tile
    CREATOR = "Icon by Maan Icons".freeze
    DESCRIPTION = "Build 1 or 2 stone walls on empty terrain spaces of the same type as your played terrain card, adjacent to at least one of your settlements.".freeze

    def places_wall? = true

    def valid_destinations(from_row: nil, from_col: nil, board_contents:, board:, player_order:, hand: nil)
      terrain = hand
      return [] unless terrain

      settlements = board_contents.settlements_for(player_order)
      settlements.flat_map do |r, c|
        board_contents.neighbors_where(r, c) do |nr, nc|
          board_contents.empty?(nr, nc) && board.terrain_at(nr, nc) == terrain
        end
      end.uniq
    end

    def activatable?(player_order:, board_contents:, board:, hand: nil)
      valid_destinations(board_contents:, board:, player_order:, hand:).any?
    end

    def action_message(player_handle:, terrain_names:, hand: nil)
      terrain = hand
      terrain ? "#{player_handle} must place a stone wall on a #{terrain_names[terrain]} space" : "#{player_handle} must place a stone wall"
    end
  end
end
