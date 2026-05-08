class Turn
  module Consequences
    EndTriggered = Data.define(:player) do
      def apply!(game)
        game.end_trigger_count += 1
      end

      def unapply!(game)
        game.end_trigger_count -= 1
      end

      def to_h
        { "type" => "end_triggered", "player" => player }
      end

      def self.from_h(h)
        new(player: h["player"])
      end
    end
  end
end
