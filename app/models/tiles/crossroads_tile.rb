module Tiles
  class CrossroadsTile < Tiles::Tile
    CREATOR = "Icon by Gregor Cresnar".freeze
    DESCRIPTION = "Draw an extra card each turn".freeze

    def activatable?(**) = false
    def crossroads_tile? = true
  end
end
