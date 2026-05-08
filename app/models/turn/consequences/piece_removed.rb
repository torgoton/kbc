class Turn
  module Consequences
    PieceRemoved = Data.define(:at, :kind, :player) do
      def apply!(game)
        game.board_contents_will_change!
        game.board_contents.remove(at.row, at.col)
        gp(game).return_piece_to_supply!(kind)
      end

      def unapply!(game)
        game.board_contents_will_change!
        game.board_contents.restore_piece(kind, at.row, at.col, player)
        gp(game).remove_piece_from_supply!(kind)
      end

      def to_h
        { "type" => "piece_removed", "at" => at.to_key, "kind" => kind, "player" => player }
      end

      def self.from_h(hash)
        new(at: Coordinate.from_key(hash["at"]), kind: hash["kind"], player: hash["player"])
      end

      private

      def gp(game)
        game.game_players.find { |g| g.order == player }
      end
    end
  end
end
