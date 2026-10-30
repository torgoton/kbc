class Scoring
  module Goals
    class Homesteaders < Goal
      DESCRIPTION = "1 point for each settlement on the board section with the most of your settlements."
      def score_for(game_player)
        sections = settlements_for(game_player.order).map { |r, c| [ r / 10, c / 10 ] }
        { score: sections.tally.values.max || 0 }
      end
    end
  end
end
