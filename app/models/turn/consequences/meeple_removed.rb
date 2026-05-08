class Turn
  module Consequences
    MeepleRemoved = Data.define(:at, :kind, :player) do
      def apply!(game)
        game.board_contents_will_change!
        game.board_contents.remove(at.row, at.col)
        gp(game).adjust_meeple_supply!(kind, 1)
      end

      def unapply!(game)
        game.board_contents_will_change!
        game.board_contents.restore_piece(kind, at.row, at.col, player)
        gp(game).adjust_meeple_supply!(kind, -1)
      end

      def to_h
        { "type" => "meeple_removed", "at" => at.to_key, "kind" => kind, "player" => player }
      end

      def self.from_h(h)
        new(at: Coordinate.from_key(h["at"]), kind: h["kind"], player: h["player"])
      end

      private

      def gp(game)
        game.game_players.find { |g| g.order == player }
      end
    end
  end
end
