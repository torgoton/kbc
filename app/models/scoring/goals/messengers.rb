class Scoring
  module Goals
    class Messengers < Goal
      DESCRIPTION = "2 points for each hex in the path between the 2 connected settlements separated by the longest distance, including both ends."
      def score_for(game_player)
        hexes = connected_components(game_player.order).map { |c| diameter_hexes(c) }.max.to_i
        { score: hexes * 2 }
      end

      private

      # Most hexes on a shortest path (ends included) between any two settlements of a component.
      def diameter_hexes(component)
        set = component.to_set
        component.map { |start| farthest_depth(start, set) + 1 }.max
      end

      def farthest_depth(start, set)
        depth = { start => 0 }
        queue = [ start ]
        until queue.empty?
          pos = queue.shift
          neighbors(*pos).each do |n|
            next if !set.include?(n) || depth.key?(n)
            depth[n] = depth[pos] + 1
            queue << n
          end
        end
        depth.values.max
      end
    end
  end
end
