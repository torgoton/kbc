class Scoring
  module Tasks
    class Advance < Task
      DESCRIPTION = "9 points if any 1 of the 4 edges of the board has at least 7 of your settlements."
      POINTS = 9

      THRESHOLD = 7

      def arrangement_met?(game_player)
        hexes = settlements_for(game_player.order)
        [
          hexes.count { |r, _| r == 0 },
          hexes.count { |r, _| r == 19 },
          hexes.count { |_, c| c == 0 },
          hexes.count { |_, c| c == 19 }
        ].any? { |n| n >= THRESHOLD }
      end
    end
  end
end
