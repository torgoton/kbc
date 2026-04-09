module Tiles
  class VillageTile < Tiles::Tile
    CREATOR = "Icon by ".freeze
    DESCRIPTION = "Build <em>one settlement</em> on an eligible space adjacent to <em>at least 3</em> of your settlements.".freeze

    def builds_settlement? = true
  end
end
