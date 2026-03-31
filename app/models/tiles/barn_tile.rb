module Tiles
  class BarnTile < Tiles::Tile
    def selectable_settlements(player_order:, board_contents:, board:, hand: nil)
      return [] unless valid_destinations(board_contents:, board:, player_order:, hand:).any?
      board_contents.settlements_for(player_order)
    end
  end
end
