class Turn
  module Consequences
    NomadTileExpirySet = Data.define(:player, :klass, :from, :expires_on_turn, :prior_expires_on_turn) do
      def apply!(game)
        tiles = (gp(game).tiles || []).map do |tile|
          next tile unless tile["klass"] == klass && tile["from"] == from
          tile.merge("expires_on_turn" => expires_on_turn)
        end
        gp(game).tiles = tiles
      end

      def unapply!(game)
        tiles = (gp(game).tiles || []).map do |tile|
          next tile unless tile["klass"] == klass && tile["from"] == from
          prior_expires_on_turn ? tile.merge("expires_on_turn" => prior_expires_on_turn) : tile.except("expires_on_turn")
        end
        gp(game).tiles = tiles
      end

      def to_h
        {
          "type" => "nomad_tile_expiry_set",
          "player" => player,
          "klass" => klass,
          "from" => from,
          "expires_on_turn" => expires_on_turn,
          "prior_expires_on_turn" => prior_expires_on_turn
        }
      end

      def self.from_h(hash)
        new(
          player: hash["player"],
          klass: hash["klass"],
          from: hash["from"],
          expires_on_turn: hash["expires_on_turn"],
          prior_expires_on_turn: hash["prior_expires_on_turn"]
        )
      end

      private

      def gp(game)
        game.game_players.find { |g| g.order == player }
      end
    end
  end
end
