class Turn
  module Consequences
    CurrentPlayerAdvanced = Data.define(:prior_order, :next_order) do
      def apply!(game)
        game.current_player = game.game_players.find { |g| g.order == next_order }
      end

      def unapply!(game)
        game.current_player = game.game_players.find { |g| g.order == prior_order }
      end

      def to_h
        { "type" => "current_player_advanced", "prior_order" => prior_order, "next_order" => next_order }
      end

      def self.from_h(h)
        new(prior_order: h["prior_order"], next_order: h["next_order"])
      end
    end
  end
end
