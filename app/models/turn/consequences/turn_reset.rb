class Turn
  module Consequences
    # Marks the end of a turn: increments turn_number and clears the per-turn
    # state under current_action["turn"]. The next player's turn starts fresh.
    TurnReset = Data.define(:prior_turn_number, :prior_turn_state) do
      def apply!(game)
        game.turn_number = prior_turn_number + 1
        game.current_action ||= {}
        game.current_action.delete("turn")
      end

      def unapply!(game)
        game.turn_number = prior_turn_number
        game.current_action ||= {}
        if prior_turn_state.nil?
          game.current_action.delete("turn")
        else
          game.current_action["turn"] = prior_turn_state
        end
      end

      def to_h
        { "type" => "turn_reset", "prior_turn_number" => prior_turn_number, "prior_turn_state" => prior_turn_state }
      end

      def self.from_h(h)
        new(prior_turn_number: h["prior_turn_number"], prior_turn_state: h["prior_turn_state"])
      end
    end
  end
end
