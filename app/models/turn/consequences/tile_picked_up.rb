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

      def unapply!(game)
        game.board_contents_will_change!
        gp = game.game_players.find { |g| g.order == player }
        taken = (gp.taken_from || []).dup
        taken.pop if taken.last == from.to_key
        gp.taken_from = taken
        gp.remove_tile_from!(from.to_key)
        game.board_contents.increment_tile(from.row, from.col)
      end
    end
  end
end
