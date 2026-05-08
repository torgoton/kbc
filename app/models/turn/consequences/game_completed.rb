class Turn
  module Consequences
    GameCompleted = Data.define(:prior_state, :prior_scores) do
      def apply!(game)
        game.state = "completed"
        game.scores = Scoring.new(game).compute
      end

      def unapply!(game)
        game.state = prior_state
        game.scores = prior_scores
      end

      def to_h
        { "type" => "game_completed", "prior_state" => prior_state, "prior_scores" => prior_scores }
      end

      def self.from_h(h)
        new(prior_state: h["prior_state"], prior_scores: h["prior_scores"])
      end
    end
  end
end
