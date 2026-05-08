class Turn
  module Consequences
    # Marks all non-permanent tiles on the named player as used: false.
    # Emitted at end_turn and applied to the *next* player so they can activate
    # their tiles on the upcoming turn.
    TilesReset = Data.define(:player, :prior_tiles) do
      def apply!(game)
        gp = game.game_players.find { |g| g.order == player }
        gp.reset_tiles!
      end

      def unapply!(game)
        gp = game.game_players.find { |g| g.order == player }
        gp.tiles = prior_tiles.deep_dup
      end

      def to_h
        { "type" => "tiles_reset", "player" => player, "prior_tiles" => prior_tiles }
      end

      def self.from_h(h)
        new(player: h["player"], prior_tiles: h["prior_tiles"])
      end
    end
  end
end
