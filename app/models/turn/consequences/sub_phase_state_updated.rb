class Turn
  module Consequences
    # Replaces the active sub_phase's state in-place. Used when a multi-step
    # sub-phase (like FortPhase across two builds) needs to persist a counter
    # decrement without popping/re-pushing.
    SubPhaseStateUpdated = Data.define(:prior_state, :new_state) do
      def apply!(game)
        return unless sub_phase(game)
        sub_phase(game)["state"] = new_state
      end

      def unapply!(game)
        return unless sub_phase(game)
        sub_phase(game)["state"] = prior_state
      end

      def to_h
        { "type" => "sub_phase_state_updated", "prior_state" => prior_state, "new_state" => new_state }
      end

      def self.from_h(h)
        new(prior_state: h["prior_state"], new_state: h["new_state"])
      end

      private

      def sub_phase(game)
        return nil unless game.current_action.is_a?(Hash) && game.current_action["turn"].is_a?(Hash)
        game.current_action["turn"]["sub_phase"]
      end
    end
  end
end
