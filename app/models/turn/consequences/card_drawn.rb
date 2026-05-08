class Turn
  module Consequences
    # Records a deck draw as a complete state replacement: deck/discard before
    # and after are both captured. Apply slams the *_after values; unapply
    # restores the *_before values. Randomness (reshuffle) is decided at
    # consequence-construction time, never at apply time.
    CardDrawn = Data.define(:card, :deck_before, :discard_before, :deck_after, :discard_after) do
      def apply!(game)
        game.deck = deck_after.dup
        game.discard = discard_after.dup
      end

      def unapply!(game)
        game.deck = deck_before.dup
        game.discard = discard_before.dup
      end

      def to_h
        {
          "type" => "card_drawn",
          "card" => card,
          "deck_before" => deck_before,
          "discard_before" => discard_before,
          "deck_after" => deck_after,
          "discard_after" => discard_after
        }
      end

      def self.from_h(h)
        new(
          card: h["card"],
          deck_before: h["deck_before"],
          discard_before: h["discard_before"],
          deck_after: h["deck_after"],
          discard_after: h["discard_after"]
        )
      end
    end
  end
end
