module Tiles
  class OasisTile < Tiles::Tile
    CREATOR = "Icon by kusuma potter".freeze
    DESCRIPTION = "Build <em>one settlement</em> on a <em>desert space.</em> Build adjacent if possible.".freeze

    def build_terrain = "D"
    def builds_settlement? = true
  end
end
