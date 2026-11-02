module Tiles
  class Location
    class TreeHouseTile < Tiles::Location
      CREATOR = "Claude".freeze
      DESCRIPTION = "Move any one of your settlements to a timberland hex, adjacent if possible.".freeze
      TERRAIN = "T".freeze

      include Tiles::MovesToTerrain
    end
  end
end
