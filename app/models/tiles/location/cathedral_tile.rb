module Tiles
  class Location
    class CathedralTile < Tiles::Location
      CREATOR = "Claude".freeze
      DESCRIPTION = "Collecting this adds 1 to your Cathedral count. " \
                    "Add 1 to the count, or build any number of settlements on your played terrain, " \
                    "adjacent if possible, using up 1 from the count for each.".freeze

      def builds_settlement? = true
      def uses_played_terrain? = true
      def repeats_build? = true
      def cathedral_tile? = true
      def cancellable_action? = true

      def on_pickup(game_player:)
        game_player.add_cathedral!
      end

      # Adding to the count is always possible, so the build option's own limits are checked there.
      def activatable?(player_order:, board_contents:, hand: nil, supply: Hash.new(0)) = true
    end
  end
end
