class Scoring
  module Goals
    class Geologists < Goal
      DESCRIPTION = "2 points for each mountain area connected to another mountain area with your settlements."
      def score_for(game_player)
        areas = terrain_components_for("M")
        area_of = areas.each_with_index.flat_map { |hexes, i| hexes.map { |h| [ h, i ] } }.to_h
        scoring = connected_components(game_player.order).flat_map do |component|
          touched = component.flat_map { |r, c| neighbors(r, c) }.filter_map { |pos| area_of[pos] }.uniq
          touched.length >= 2 ? touched : []
        end.uniq
        { score: scoring.length * 2 }
      end
    end
  end
end
