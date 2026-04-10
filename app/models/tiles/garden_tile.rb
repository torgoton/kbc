module Tiles
  class GardenTile < Tiles::Tile
    CREATOR = "Icon by ".freeze
    DESCRIPTION = "Build <em>one settlement</em> on a <em>flower space.</em> Build adjacent if possible.".freeze

    def build_terrain = "F"
    def builds_settlement? = true
  end
end
