module Tiles
  class FortTile < Tiles::Tile
    CREATOR = "Icon by agus raharjo".freeze
    DESCRIPTION = "CANNOT be undone! Draw a card and build on that terrain".freeze

    def builds_settlement? = true
  end
end
