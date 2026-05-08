class Turn
  module Consequences
    # Marker consequence: when present in a click's consequence list, the click
    # is recorded with reversible: false. Apply/unapply are no-ops; the applier
    # raises on attempting to unapply a non-reversible click.
    class IrreversibleBoundary
      def apply!(_game); end
      def unapply!(_game); end

      def to_h
        { "type" => "irreversible_boundary" }
      end

      def self.from_h(_h)
        new
      end

      def ==(other) = other.is_a?(IrreversibleBoundary)
      def eql?(other) = self == other
      def hash = self.class.hash
    end
  end
end
