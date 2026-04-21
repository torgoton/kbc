module Tiles
  class ForestersLodgeTile < Tiles::Tile
    CREATOR = "Icon by keenicon".freeze
    DESCRIPTION = "Build <em>one settlement</em> on a <em>timberland space.</em> Build adjacent if possible.".freeze

    def build_terrain = "T"
    def builds_settlement? = true
  end
end
