class Turn
  module Consequences
    class SubPhasePopped
      def apply!(game)
        return unless game.current_action.is_a?(Hash) && game.current_action["turn"].is_a?(Hash)
        game.current_action["turn"]["sub_phase"] = nil
      end

      def ==(other) = other.is_a?(SubPhasePopped)
      def eql?(other) = self == other
      def hash = self.class.hash
    end
  end
end
