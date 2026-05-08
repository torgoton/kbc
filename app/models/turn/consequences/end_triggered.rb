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

      # Returns [EndTriggered] if the named player's next build will exhaust their settlement
      # supply, else []. Caller appends the result to a build's consequence list.
      def self.maybe(game:, player_order:)
        gp = game.game_players.find { |g| g.order == player_order }
        return [] unless gp && gp.settlements_remaining == 1
        [ new(player: player_order) ]
      end
    end
  end
end
