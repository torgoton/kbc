class Turn
  module Consequences
    SubPhasePushed = Data.define(:phase_type, :state) do
      def apply!(game)
        game.current_action ||= {}
        game.current_action["turn"] ||= {}
        game.current_action["turn"]["sub_phase"] = { "type" => phase_type.to_s, "state" => state }
      end
    end
  end
end
