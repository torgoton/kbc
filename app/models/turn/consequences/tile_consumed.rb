class Turn
  module Consequences
    TileConsumed = Data.define(:klass, :player) do
      def apply!(game)
        game.game_players.find { |gp| gp.order == player }.mark_tile_used!(klass)
      end

      def unapply!(game)
        game.game_players.find { |gp| gp.order == player }.mark_tile_unused!(klass)
      end

      def to_h
        { "type" => "tile_consumed", "klass" => klass, "player" => player }
      end

      def self.from_h(h)
        new(klass: h["klass"], player: h["player"])
      end
    end
  end
end
