class Scoring
  module Tasks
    class HomeCountry < Task
      DESCRIPTION = "5 points if you control a complete terrain area (every hex of a connected same-terrain region occupied by your settlements)."
      POINTS = 5

      def arrangement_met?(game_player)
        player_hexes = settlements_for(game_player.order).to_set
        AREA_TERRAINS.any? do |terrain|
          terrain_components_for(terrain).any? do |component|
            component.all? { |pos| player_hexes.include?(pos) }
          end
        end
      end
    end
  end
end
