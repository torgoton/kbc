module Tiles
  class Location
    class RopeBridgeTile < Tiles::Location
      CREATOR = "Claude".freeze
      DESCRIPTION = "Move any one of your settlements to a canyon hex, adjacent if possible.".freeze
      TERRAIN = "C".freeze

      include Tiles::MovesToTerrain
    end
  end
end
