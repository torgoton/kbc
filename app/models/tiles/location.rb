module Tiles
  class Location < Tiles::Tile
    CLASS_DESCRIPTION = (
      "You may use this every turn after you acquire it. " \
      "Discard if you move away from the space that granted it."
    ).freeze

    def class_description = CLASS_DESCRIPTION
  end
end
