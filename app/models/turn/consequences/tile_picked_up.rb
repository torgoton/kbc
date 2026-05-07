class Turn
  module Consequences
    TilePickedUp = Data.define(:from, :klass, :player) do
      def apply!(game)
        game.board_contents_will_change!
        game.board_contents.decrement_tile(from.row, from.col)
        gp = game.game_players.find { |g| g.order == player }
        gp.receive_tile!(klass, from: from.to_key)
        gp.taken_from = (gp.taken_from || []) + [ from.to_key ]
      end
    end
  end
end
