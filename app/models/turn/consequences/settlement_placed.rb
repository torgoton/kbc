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
    end
  end
end
