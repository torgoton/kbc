class Turn
  module Consequences
    HandRefreshed = Data.define(:player, :hand_before, :hand_after, :deck_before, :deck_after, :discard_before, :discard_after) do
      def apply!(game)
        gp(game).hand = hand_after.dup
        game.deck = deck_after.dup
        game.discard = discard_after.dup
      end

      def unapply!(game)
        gp(game).hand = hand_before.dup
        game.deck = deck_before.dup
        game.discard = discard_before.dup
      end

      def to_h
        {
          "type" => "hand_refreshed",
          "player" => player,
          "hand_before" => hand_before,
          "hand_after" => hand_after,
          "deck_before" => deck_before,
          "deck_after" => deck_after,
          "discard_before" => discard_before,
          "discard_after" => discard_after
        }
      end

      def self.from_h(h)
        new(
          player: h["player"],
          hand_before: h["hand_before"],
          hand_after: h["hand_after"],
          deck_before: h["deck_before"],
          deck_after: h["deck_after"],
          discard_before: h["discard_before"],
          discard_after: h["discard_after"]
        )
      end

      private

      def gp(game)
        game.game_players.find { |g| g.order == player }
      end
    end
  end
end
