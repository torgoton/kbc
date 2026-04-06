module Tiles
  class FarmTile < Tiles::Tile
    CREATOR = "Icon by Marz Gallery".freeze
    DESCRIPTION = "Place a settlement on any Grassland space"

    def build_terrain = "G"
    def builds_settlement? = true
  end
end
