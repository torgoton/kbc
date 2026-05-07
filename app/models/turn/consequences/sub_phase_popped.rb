class Turn
  module Consequences
    SubPhasePopped = Data.define(:prior_state) do
      def apply!(game)
        return unless game.current_action.is_a?(Hash) && game.current_action["turn"].is_a?(Hash)
        game.current_action["turn"]["sub_phase"] = nil
      end

      def unapply!(game)
        game.current_action ||= {}
        game.current_action["turn"] ||= {}
        game.current_action["turn"]["sub_phase"] = prior_state
      end
    end
  end
end
