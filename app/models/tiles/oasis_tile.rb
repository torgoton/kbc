module Tiles
  class OasisTile < Tiles::Tile
    CREATOR = "Icon by kusuma potter".freeze
    DESCRIPTION = "Place a settlement on any Desert space"

    def build_terrain = "D"
    def builds_settlement? = true
  end
end
