class Scoring
  class Knights < Goal
    def score_for(game_player)
      rows = settlements_for(game_player.order).map(&:first)
      best = rows.tally.values.max || 0
      { score: best * 2 }
    end
  end
end
