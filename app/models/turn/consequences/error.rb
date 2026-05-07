class Turn
  module Consequences
    Error = Data.define(:message) do
      def apply!(_game)
      end

      def unapply!(_game)
      end

      def error? = true

      def to_h
        { "type" => "error", "message" => message }
      end

      def self.from_h(h)
        new(message: h["message"])
      end
    end
  end
end
