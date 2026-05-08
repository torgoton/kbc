class Turn
  module Consequences
    # Removes the named expired_tiles from the named player's hand.
    # Emitted at end_turn for tiles whose `expires_on_turn` matches the turn
    # being ended. The expired tiles are carried for invertibility.
    NomadTilesExpired = Data.define(:player, :expired_tiles) do
      def apply!(game)
        gp = game.game_players.find { |g| g.order == player }
        gp.tiles = (gp.tiles || []).reject do |tile|
          expired_tiles.any? { |e| e["klass"] == tile["klass"] && e["from"] == tile["from"] }
        end
      end

      def unapply!(game)
        gp = game.game_players.find { |g| g.order == player }
        gp.tiles = (gp.tiles || []) + expired_tiles.deep_dup
      end

      def to_h
        { "type" => "nomad_tiles_expired", "player" => player, "expired_tiles" => expired_tiles }
      end

      def self.from_h(h)
        new(player: h["player"], expired_tiles: h["expired_tiles"])
      end
    end
  end
end
