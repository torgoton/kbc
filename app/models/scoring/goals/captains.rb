class Scoring
  module Goals
    class Captains < Goal
      DESCRIPTION = "1 point for each settlement next to at least 3 of your own settlements."
      def score_for(game_player)
        mine = settlements_for(game_player.order).to_set
        { score: mine.count { |r, c| neighbors(r, c).count { |n| mine.include?(n) } >= 3 } }
      end
    end
  end
end
