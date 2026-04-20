class Scoring
  module Tasks
    class Fortress < Task
      DESCRIPTION = "6 points if one of your settlements is surrounded by 6 of your settlements."
      POINTS = 6

      def arrangement_met?(game_player)
        player_hexes = settlements_for(game_player.order).to_set
        player_hexes.any? do |r, c|
          ns = neighbors(r, c)
          ns.size == 6 && ns.all? { |n| player_hexes.include?(n) }
        end
      end
    end
  end
end
