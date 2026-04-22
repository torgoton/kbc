module Tiles
  class CaravanTile < Tiles::Tile
    CREATOR = "Icon by Smalllike".freeze
    DESCRIPTION = "Move one of your own settlements in a straight line, either horizontally or diagonally, until it is blocked by an obstacle.".freeze

    STRAIGHT_LINES = Tiles::PaddockTile::STRAIGHT_LINES

    def moves_settlement? = true

    def valid_destinations(from_row: nil, from_col: nil, board_contents:, board:, player_order: nil, hand: nil)
      return [] if from_row.nil? || from_col.nil?
      STRAIGHT_LINES.filter_map do |steps|
        last = nil
        r, c = from_row, from_col
        loop do
          dr, dc = steps[r % 2]
          nr, nc = r + dr, c + dc
          break unless (0..19).cover?(nr) && (0..19).cover?(nc) &&
                       board_contents.available_for_building?(nr, nc) &&
                       BUILDABLE_TERRAIN.include?(board.terrain_at(nr, nc))
          last = [ nr, nc ]
          r, c = nr, nc
        end
        last
      end
    end

    def selectable_settlements(player_order:, board_contents:, board:, hand: nil)
      board_contents.settlements_for(player_order).filter_map do |r, c|
        [ r, c ] if valid_destinations(from_row: r, from_col: c, board_contents:, board:).any?
      end
    end

    def activatable?(player_order:, board_contents:, board:, hand: nil, warrior_supply: 0)
      selectable_settlements(player_order:, board_contents:, board:, hand:).any?
    end
  end
end
