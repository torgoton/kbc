module Tiles
  class Permanent
    class MandatoryTile < Tiles::Permanent
      CREATOR = "Icon by agus ragarjo".freeze
      DESCRIPTION = (
        "Build 3 settlements on the terrain of your played terrain card. " \
        "Build adjacent if possible. " \
        "You must use this action every turn."
      ).freeze

      # Mandatory placement is handled by clicking the board directly,
      # not by selecting this tile as an action.
      def activatable?(player_order:, board_contents:, hand: nil, supply: Hash.new(0)) = false
    end
  end
end
