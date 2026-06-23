module Tiles
  class Location < Tiles::Tile
    CLASS_DESCRIPTION = (
      "Location Tile - You may use this any turn after you acquire it. " \
      "Discard if you move away from the hex that granted it."
    ).freeze

    def class_description = CLASS_DESCRIPTION
  end
end
