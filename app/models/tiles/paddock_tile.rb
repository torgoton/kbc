module Tiles
  class PaddockTile < Tiles::Tile
    BUILDABLE_TERRAIN = %w[C D F T G].freeze
    # Each entry is [even_row_step, odd_row_step] for one of the 6 straight-line directions.
    STRAIGHT_LINES = [
      [ [ 0, -1 ], [ 0, -1 ] ],   # W
      [ [ 0,  1 ], [ 0,  1 ] ],   # E
      [ [ -1, -1 ], [ -1, 0 ] ],  # NW
      [ [ -1,  0 ], [ -1, 1 ] ],  # NE
      [ [ 1, -1 ],  [ 1, 0 ] ],   # SW
      [ [ 1,  0 ],  [ 1, 1 ] ]    # SE
    ].freeze

    def valid_destinations(from_row, from_col, board_contents:, board:)
      STRAIGHT_LINES.filter_map do |steps|
        dr1, dc1 = steps[from_row % 2]
        r1 = from_row + dr1
        c1 = from_col + dc1
        next unless (0..19).cover?(r1) && (0..19).cover?(c1)
        dr2, dc2 = steps[r1 % 2]
        r2 = r1 + dr2
        c2 = c1 + dc2
        next unless (0..19).cover?(r2) && (0..19).cover?(c2)
        next unless board_contents.empty?(r2, c2)
        next unless BUILDABLE_TERRAIN.include?(board.terrain_at(r2, c2))
        [ r2, c2 ]
      end
    end

    def selectable_settlements(player_order, board_contents:, board:)
      board_contents.settlements_for(player_order).filter_map do |r, c|
        [ r, c ] if valid_destinations(r, c, board_contents: board_contents, board: board).any?
      end
    end
  end
end
