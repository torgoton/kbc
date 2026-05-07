class Turn
  module Consequences
    SettlementPlaced = Data.define(:at, :player, :terrain) do
      def apply!(game)
        game.board_contents_will_change!
        game.board_contents.place_settlement(at.row, at.col, player)
        game.game_players.find { |gp| gp.order == player }.decrement_supply!
      end

      def unapply!(game)
        game.board_contents_will_change!
        game.board_contents.remove(at.row, at.col)
        game.game_players.find { |gp| gp.order == player }.increment_supply!
      end

      def to_h
        { "type" => "settlement_placed", "at" => at.to_key, "player" => player, "terrain" => terrain }
      end

      def self.from_h(h)
        new(at: Coordinate.from_key(h["at"]), player: h["player"], terrain: h["terrain"])
      end
    end
  end
end
