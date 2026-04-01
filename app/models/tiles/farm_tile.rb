module Tiles
  class FarmTile < Tiles::Tile
    CREATOR = "Icon by Marz Gallery".freeze

    def build_terrain = "G"
    def builds_settlement? = true
  end
end
