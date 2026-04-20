class Scoring
  module Tasks
    class CompassPoints < Task
      DESCRIPTION = "10 points if every edge of the board has at least 1 of your settlements."
      POINTS = 10

      def arrangement_met?(game_player)
        hexes = settlements_for(game_player.order)
        hexes.any? { |r, _| r == 0 } &&
          hexes.any? { |r, _| r == 19 } &&
          hexes.any? { |_, c| c == 0 } &&
          hexes.any? { |_, c| c == 19 }
      end
    end
  end
end
