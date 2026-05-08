class Turn
  module Consequences
    TileDiscarded = Data.define(:player, :klass, :from, :used) do
      def apply!(game)
        tiles = (gp(game).tiles || []).dup
        idx = tiles.index { |t| t["klass"] == klass && t["from"] == from }
        tiles.delete_at(idx) if idx
        gp(game).tiles = tiles
      end

      def unapply!(game)
        gp(game).restore_tile!(klass, from: from, used: used)
      end

      def to_h
        { "type" => "tile_discarded", "player" => player, "klass" => klass, "from" => from, "used" => used }
      end

      def self.from_h(h)
        new(player: h["player"], klass: h["klass"], from: h["from"], used: h["used"])
      end

      private

      def gp(game)
        game.game_players.find { |g| g.order == player }
      end
    end
  end
end
