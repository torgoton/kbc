class Scoring
  module Goals
    class Noblewomen < Goal
      DESCRIPTION = "5 points for each silver or gold hex you have the most settlements adjacent to."
      def score_for(game_player)
        orders = @game.game_players.map(&:order)
        scored = special_hexes.count do |r, c|
          counts = orders.to_h { |o| [ o, neighbors(r, c).count { |n| board_contents.player_at(*n) == o } ] }
          # ponytail: ties count for every tied player
          counts[game_player.order].positive? && counts[game_player.order] == counts.values.max
        end
        { score: scored * 5 }
      end

      private

      def special_hexes
        (0..19).flat_map do |r|
          (0..19).filter_map { |c| [ r, c ] if %w[L S].include?(board_contents.terrain_at(r, c)) }
        end
      end
    end
  end
end
