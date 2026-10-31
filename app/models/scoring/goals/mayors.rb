class Scoring
  module Goals
    class Mayors < Goal
      DESCRIPTION = "4 points for each of your settlements that marks a row (4 or more of yours on a row nobody had marked)."
      def score_for(game_player)
        { score: Array(game_player.supply["mayors"]).size * 4 }
      end
    end
  end
end
