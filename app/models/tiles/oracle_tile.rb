module Tiles
  class OracleTile < Tiles::Tile
    CREATOR = "Icon by Cahya Kurniawan".freeze
    DESCRIPTION = "Place a settlement on any empty space of your terrain card's type"

    def builds_settlement? = true
  end
end
