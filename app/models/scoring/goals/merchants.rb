class Scoring
  module Goals
    class Merchants < Goal
      DESCRIPTION = "4 points for each silver or gold hex connected to any other such hex with your settlements."
      def score_for(game_player)
        specials = special_hexes
        components = connected_components(game_player.order)
        total = components.sum do |component|
          adjacent_specials = component.flat_map { |r, c| neighbors(r, c) }
                                       .select { |pos| specials.include?(pos) }
                                       .uniq
          adjacent_specials.length >= 2 ? adjacent_specials.length * 4 : 0
        end
        { score: total }
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
