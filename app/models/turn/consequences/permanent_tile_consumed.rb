class Turn
  module Consequences
    PermanentTileConsumed = Data.define(:klass, :player) do
      def apply!(game)
        gp(game).mark_tile_permanently_used!(klass)
      end

      def unapply!(game)
        gp(game).mark_tile_unpermanent!(klass)
      end

      def to_h
        { "type" => "permanent_tile_consumed", "klass" => klass, "player" => player }
      end

      def self.from_h(hash)
        new(klass: hash["klass"], player: hash["player"])
      end

      private

      def gp(game)
        game.game_players.find { |g| g.order == player }
      end
    end
  end
end
