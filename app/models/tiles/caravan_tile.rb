module Tiles
  class CaravanTile < Tiles::Tile
    CREATOR = "Icon by ".freeze
    DESCRIPTION = "Move one of your own settlements in a straight line, either horizontally or diagonally, until it is blocked by an obstacle.".freeze

    def moves_settlement? = true
  end
end
