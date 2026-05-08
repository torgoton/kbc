class Turn
  module Consequences
    SettlementMoved = Data.define(:from, :to, :player) do
      def apply!(game)
        game.board_contents_will_change!
        game.board_contents.move_settlement(from.row, from.col, to.row, to.col)
      end

      def unapply!(game)
        game.board_contents_will_change!
        game.board_contents.move_settlement(to.row, to.col, from.row, from.col)
      end

      def to_h
        { "type" => "settlement_moved", "from" => from.to_key, "to" => to.to_key, "player" => player }
      end

      def self.from_h(h)
        new(from: Coordinate.from_key(h["from"]), to: Coordinate.from_key(h["to"]), player: h["player"])
      end
    end
  end
end
