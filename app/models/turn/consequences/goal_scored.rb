class Turn
  module Consequences
    GoalScored = Data.define(:player, :goal, :points, :prior_score) do
      def apply!(game)
        bonus = gp(game).bonus_scores || {}
        gp(game).bonus_scores = bonus.merge(goal => prior_score + points)
      end

      def unapply!(game)
        bonus = (gp(game).bonus_scores || {}).dup
        if prior_score.zero?
          bonus.delete(goal)
        else
          bonus[goal] = prior_score
        end
        gp(game).bonus_scores = bonus
      end

      def to_h
        { "type" => "goal_scored", "player" => player, "goal" => goal, "points" => points, "prior_score" => prior_score }
      end

      def self.from_h(h)
        new(player: h["player"], goal: h["goal"], points: h["points"], prior_score: h["prior_score"])
      end

      private

      def gp(game)
        game.game_players.find { |g| g.order == player }
      end
    end
  end
end
