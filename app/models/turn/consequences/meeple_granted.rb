class Turn
  module Consequences
    MeepleGranted = Data.define(:player, :kind, :qty) do
      def apply!(game)
        gp(game).adjust_meeple_supply!(kind, qty)
      end

      def unapply!(game)
        gp(game).adjust_meeple_supply!(kind, -qty)
      end

      def to_h
        { "type" => "meeple_granted", "player" => player, "kind" => kind, "qty" => qty }
      end

      def self.from_h(h)
        new(player: h["player"], kind: h["kind"], qty: h["qty"])
      end

      private

      def gp(game)
        game.game_players.find { |g| g.order == player }
      end
    end
  end
end
