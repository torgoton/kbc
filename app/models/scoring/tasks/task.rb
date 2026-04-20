class Scoring
  module Tasks
    class Task < Scoring::Scorer
      def score_for(game_player)
        { score: arrangement_met?(game_player) ? self.class::POINTS : 0 }
      end

      def arrangement_met?(_game_player)
        raise NotImplementedError, "#{self.class} must implement arrangement_met?"
      end
    end
  end
end
