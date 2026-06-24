module Tiles
  class Nomad < Tiles::Tile
    TILE_DESCRIPTION = "Override this description in subclasses.".freeze
    CLASS_DESCRIPTION = (
      "Nomad Tile - You may use this once ONLY on the turn after you acquire it. " \
      "Discard after that turn. " \
      "You do not lose this tile if you move away from the hex that granted it."
    ).freeze

    def class_description = CLASS_DESCRIPTION
    # "#{self.class.to_s.demodulize} - #{TILE_DESCRIPTION}<br><br>" \
    # "#{CLASS_DESCRIPTION}"
    def nomad_tile? = true
  end
end
