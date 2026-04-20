class Scoring
  module Tasks
    class Road < Task
      DESCRIPTION = "7 points if at least 7 of your settlements form a continuous diagonal line."
      POINTS = 7

      def arrangement_met?(game_player)
        hexes = settlements_for(game_player.order)
        [ :q, :s ].any? do |axis|
          hexes.group_by { |r, c| cube_coord(r, c)[axis] }.any? do |_, positions|
            longest_run(positions.map(&:first).sort) >= 7
          end
        end
      end

      private

      def cube_coord(r, c)
        q = c - (r - (r % 2)) / 2
        { q: q, s: -q - r }
      end

      def longest_run(sorted_rows)
        return 0 if sorted_rows.empty?
        max = current = 1
        sorted_rows.each_cons(2) do |a, b|
          current = b == a + 1 ? current + 1 : 1
          max = current if current > max
        end
        max
      end
    end
  end
end
