module Tiles
  # Settlement movers between the hexes of a decree's "shore" (Ferry, Caves): a settlement on the
  # shore moves to any empty buildable hex on the shore. Includers define `shore(board_contents)`.
  module MovesAlongShore
    include Tiles::MovesFromSource

    def selectable_settlements(player_order:, board_contents:, hand: nil, budget: nil)
      on_shore = shore(board_contents)
      super.select { |cell| on_shore.include?(cell) }
    end

    def valid_destinations(from_row: nil, from_col: nil, board_contents:, player_order: nil, hand: nil, budget: nil)
      shore(board_contents).select do |r, c|
        board_contents.available_for_building?(r, c) && Tiles::Tile::BUILDABLE_TERRAIN.include?(board_contents.terrain_at(r, c))
      end
    end
  end
end
