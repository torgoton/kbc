class Turn
  module Consequences
    TileConsumed = Data.define(:klass, :player) do
      def apply!(game)
        game.game_players.find { |gp| gp.order == player }.mark_tile_used!(klass)
      end
    end
  end
end
