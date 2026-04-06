module Tiles
  class BarnTile < Tiles::Tile
    CREATOR = "Icon by Cahya Kurniawan".freeze
    DESCRIPTION = "Move one of your settlements to any empty space of your terrain card's type"

    def moves_settlement? = true
  end
end
