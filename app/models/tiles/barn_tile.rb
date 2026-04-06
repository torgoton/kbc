module Tiles
  class BarnTile < Tiles::Tile
    CREATOR = "Icon by Cahya Kurniawan".freeze
    DESCRIPTION = "Move <em>any one of your existing settlements</em> to a space of the " \
                  "same terrain type as your played <em>terrain card</em>. Build adjacent " \
                  "if possible.".freeze
    def moves_settlement? = true
  end
end
