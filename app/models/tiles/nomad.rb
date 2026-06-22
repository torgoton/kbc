module Tiles
  class Nomad < Tiles::Tile
    CLASS_DESCRIPTION = (
      "Nomad Tile - You may use this once on the turn after you acquire it. " \
      "Discard after that turn. " \
      "You do not lose this tile if you move away from the space that granted it."
    ).freeze

    def class_description = CLASS_DESCRIPTION
    def nomad_tile? = true
  end
end
