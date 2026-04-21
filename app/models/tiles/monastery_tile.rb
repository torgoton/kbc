module Tiles
  class MonasteryTile < Tiles::Tile
    CREATOR = "Icon by Eucalyp".freeze
    DESCRIPTION = "Build <em>one settlement</em> on a <em>canyon space.</em> Build adjacent if possible.".freeze

    def build_terrain = "C"
    def builds_settlement? = true
  end
end
