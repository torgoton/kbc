class Scoring
  module Tasks
    class PlaceOfRefuge < Task
      DESCRIPTION = "8 points if a special space is completely surrounded by your own settlements."
      POINTS = 8

      SPECIAL_TERRAINS = %w[L S].freeze

      def arrangement_met?(game_player)
        player_hexes = settlements_for(game_player.order).to_set
        special_hexes.any? do |r, c|
          ns = neighbors(r, c)
          ns.size == 6 && ns.all? { |n| player_hexes.include?(n) }
        end
      end

      private

      def special_hexes
        20.times.flat_map do |r|
          20.times.filter_map { |c| [ r, c ] if SPECIAL_TERRAINS.include?(board.terrain_at(r, c)) }
        end
      end
    end
  end
end
