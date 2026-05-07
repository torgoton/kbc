class Turn
  module Consequences
    MandatoryRemainingDecremented = Data.define(:prior_remaining) do
      def apply!(game)
        game.current_action ||= {}
        game.current_action["turn"] ||= {}
        game.current_action["turn"]["mandatory_remaining"] = prior_remaining - 1
      end

      def unapply!(game)
        game.current_action ||= {}
        game.current_action["turn"] ||= {}
        game.current_action["turn"]["mandatory_remaining"] = prior_remaining
      end

      def to_h
        { "type" => "mandatory_remaining_decremented", "prior_remaining" => prior_remaining }
      end

      def self.from_h(h)
        new(prior_remaining: h["prior_remaining"])
      end
    end
  end
end
