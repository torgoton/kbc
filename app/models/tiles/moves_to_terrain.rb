module Tiles
  # Settlement movers with a fixed destination terrain (Rope Bridge, Tree House): move one of your
  # settlements to a hex of TERRAIN, adjacent to another of your settlements if possible.
  module MovesToTerrain
    def moves_settlement? = true
    def move_terrain(hand:) = self.class::TERRAIN

    def valid_destinations(from_row: nil, from_col: nil, board_contents:, player_order:, hand: nil, budget: nil)
      excluding = (from_row && from_col) ? [ from_row, from_col ] : nil
      board_contents.buildable_cells_for(player_order, self.class::TERRAIN, excluding:)
    end
  end
end
