module Tiles
  class Tile
    attr_accessor :qty

    def initialize(qty)
      @qty = qty
    end

    def valid_destinations(from_row, from_col, board_contents:, board:)
      []
    end

    def selectable_settlements(player_order, board_contents:, board:)
      []
    end
  end
end
