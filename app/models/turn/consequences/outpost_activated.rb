class Turn
  module Consequences
    OutpostActivated = Data.define(:prior_active) do
      def apply!(game)
        game.current_action ||= {}
        game.current_action["turn"] ||= {}
        game.current_action["turn"]["outpost_active"] = true
      end

      def unapply!(game)
        return unless game.current_action.is_a?(Hash) && game.current_action["turn"].is_a?(Hash)
        game.current_action["turn"]["outpost_active"] = prior_active
      end

      def to_h
        { "type" => "outpost_activated", "prior_active" => prior_active }
      end

      def self.from_h(h)
        new(prior_active: h["prior_active"])
      end
    end
  end
end
