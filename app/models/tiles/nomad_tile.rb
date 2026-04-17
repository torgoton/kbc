module Tiles
  class NomadTile < Tiles::Tile
    CREATOR = "".freeze
    DESCRIPTION = "A Nomad tile.".freeze

    def nomad_tile? = true
  end
end
