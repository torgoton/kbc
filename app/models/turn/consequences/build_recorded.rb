class Turn
  module Consequences
    BuildRecorded = Data.define(:at) do
      def apply!(game)
        game.current_action ||= {}
        game.current_action["turn"] ||= {}
        builds = game.current_action["turn"]["builds"] || []
        game.current_action["turn"]["builds"] = builds + [ at ]
      end

      def unapply!(game)
        return unless game.current_action.is_a?(Hash) && game.current_action["turn"].is_a?(Hash)
        builds = (game.current_action["turn"]["builds"] || []).dup
        builds.pop
        if builds.empty?
          game.current_action["turn"].delete("builds")
        else
          game.current_action["turn"]["builds"] = builds
        end
      end

      def to_h
        { "type" => "build_recorded", "at" => at }
      end

      def self.from_h(h)
        new(at: h["at"])
      end
    end
  end
end
