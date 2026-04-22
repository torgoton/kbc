module Tiles
  class PaddockTile < Tiles::Tile
    CREATOR = "Icon by M Yudi Maulana".freeze
    DESCRIPTION = "Move <em>any one of your existing settlements two spaces in a straight line</em> in any " \
                  "­direction (horizontally or diagonally) to <em>any eligible space</em>. You may jump across " \
                  "<em>any</em> space, even if occupied. ".freeze

    # Each entry is [even_row_step, odd_row_step] for one of the 6 straight-line directions.
    STRAIGHT_LINES = [
      [ [ 0, -1 ], [ 0, -1 ] ],   # W
      [ [ 0,  1 ], [ 0,  1 ] ],   # E
      [ [ -1, -1 ], [ -1, 0 ] ],  # NW
      [ [ -1,  0 ], [ -1, 1 ] ],  # NE
      [ [ 1, -1 ],  [ 1, 0 ] ],   # SW
      [ [ 1,  0 ],  [ 1, 1 ] ]    # SE
    ].freeze

    def moves_settlement? = true

    def valid_destinations(from_row: nil, from_col: nil, board_contents:, board:, player_order: nil, hand: nil)
      return [] if from_row.nil? || from_col.nil?
      STRAIGHT_LINES.filter_map do |steps|
        dr1, dc1 = steps[from_row % 2]
        r1 = from_row + dr1
        c1 = from_col + dc1
        next unless (0..19).cover?(r1) && (0..19).cover?(c1)
        dr2, dc2 = steps[r1 % 2]
        r2 = r1 + dr2
        c2 = c1 + dc2
        next unless (0..19).cover?(r2) && (0..19).cover?(c2)
        next unless board_contents.available_for_building?(r2, c2)
        next unless BUILDABLE_TERRAIN.include?(board.terrain_at(r2, c2))
        [ r2, c2 ]
      end
    end

    def activatable?(player_order:, board_contents:, board:, hand: nil, warrior_supply: 0)
      selectable_settlements(player_order:, board_contents:, board:, hand:).any?
    end

    def selectable_settlements(player_order:, board_contents:, board:, hand: nil)
      board_contents.settlements_for(player_order).filter_map do |r, c|
        [ r, c ] if valid_destinations(from_row: r, from_col: c, board_contents:, board:).any?
      end
    end
  end
end
