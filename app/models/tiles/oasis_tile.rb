module Tiles
  class OasisTile < Tiles::Tile
    CREATOR = "Icon by kusuma potter".freeze

    def build_terrain = "D"
    def builds_settlement? = true
  end
end
