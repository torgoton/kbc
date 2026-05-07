class Turn
  module Consequences
    SubPhasePushed = Data.define(:phase_type, :state) do
      def apply!(game)
        game.current_action ||= {}
        game.current_action["turn"] ||= {}
        game.current_action["turn"]["sub_phase"] = { "type" => phase_type.to_s, "state" => state }
      end

      def unapply!(game)
        return unless game.current_action.is_a?(Hash)
        game.current_action.delete("turn")
      end

      def to_h
        { "type" => "sub_phase_pushed", "phase_type" => phase_type.to_s, "state" => state }
      end

      def self.from_h(h)
        new(phase_type: h["phase_type"], state: h["state"])
      end
    end
  end
end
