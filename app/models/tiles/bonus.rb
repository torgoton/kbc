module Tiles
  # Bonus tiles come with collecting the 2nd copy of a tile that has one. They are never
  # selected; they modify the tile they belong to.
  class Bonus < Tiles::Tile
    CLASS_DESCRIPTION = (
      "Bonus Tile - Awarded with the 2nd copy of a tile. It is never selected: it changes how that tile works, " \
      "from the turn after you acquire it."
    ).freeze

    def class_description = CLASS_DESCRIPTION

    def activatable?(player_order:, board_contents:, hand: nil, supply: Hash.new(0))
      false
    end
  end
end
