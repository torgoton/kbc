module Tiles
  class Location
    class TempleTile < Tiles::Location
      CREATOR = "Claude (placeholder icon)".freeze
      DESCRIPTION = "Remove 1 of your settlements from the board and build it during your next mandatory action." \
                    "<hr>When you collect a 2nd Temple tile, you will get a Temple Bonus tile." \
                    "<br>Temple Bonus: On every turn, the first build of your mandatory need not be adjacent.".freeze

      def sets_aside_settlement? = true
      def bonus_tile_klass = "TempleBonusTile"

      def action_message(player_handle:, terrain_names:, hand: nil)
        "#{player_handle} must select a settlement to set aside"
      end

      def activatable?(player_order:, board_contents:, hand: nil, supply: Hash.new(0))
        board_contents.settlements_for(player_order).any? { |r, c| !board_contents.city_hall_at?(r, c) }
      end
    end
  end
end
