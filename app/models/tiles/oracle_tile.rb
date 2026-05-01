module Tiles
  class OracleTile < Tiles::Tile
    CREATOR = "Icon by Cahya Kurniawan".freeze
    DESCRIPTION = "Build <em>one settlement</em> on a space of the same terrain type as your played <em>terrain card</em>. Build adjacent if possible.".freeze

    def builds_settlement? = true
    def uses_played_terrain? = true
  end
end
