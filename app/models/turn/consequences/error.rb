class Turn
  module Consequences
    Error = Data.define(:message) do
      def apply!(_game)
      end

      def unapply!(_game)
      end

      def error? = true
    end
  end
end
