class Scoring
  module Goals
    class Merchants < Goal
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
        l_hexes = (0..19).flat_map do |r|
          (0..19).filter_map { |c| [ r, c ] if board.terrain_at(r, c) == "L" }
        end
        (l_hexes + castle_hexes).uniq
      end

    end
  end
end
