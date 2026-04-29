module Tiles
  class FortTile < Tiles::Tile
    CREATOR = "Icon by agus raharjo".freeze
    DESCRIPTION = "CANNOT be undone! Draw a card and build on that terrain".freeze

    def builds_settlement? = true
    def fort_tile? = true

    def activatable?(player_order:, board_contents:, board:, hand: nil, supply: Hash.new(0))
      true
    end
  end
end
