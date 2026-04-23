module Tiles
  class MandatoryTile < Tiles::Tile
    DESCRIPTION = "Build 3 settlements on the terrain of your played terrain card. Build adjacent if possible.".freeze

    # Mandatory placement is handled by clicking the board directly,
    # not by selecting this tile as an action.
    def activatable?(player_order:, board_contents:, board:, hand: nil, warrior_supply: 0, ship_supply: 0) = false
  end
end
