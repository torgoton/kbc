require "test_helper"

class Turn::Consequences::CardDrawnTest < ActiveSupport::TestCase
  def setup
    @game = games(:game2player)
  end

  test "apply! sets game.deck and game.discard to the *_after values" do
    @game.deck = [ "G", "F", "T" ]
    @game.discard = [ "C" ]
    Turn::Consequences::CardDrawn.new(
      card: "G",
      deck_before: [ "G", "F", "T" ],
      discard_before: [ "C" ],
      deck_after: [ "F", "T" ],
      discard_after: [ "C", "G" ]
    ).apply!(@game)
    assert_equal [ "F", "T" ], @game.deck
    assert_equal [ "C", "G" ], @game.discard
  end

  test "unapply! restores deck_before and discard_before" do
    @game.deck = [ "G", "F", "T" ]
    @game.discard = [ "C" ]
    c = Turn::Consequences::CardDrawn.new(
      card: "G",
      deck_before: [ "G", "F", "T" ],
      discard_before: [ "C" ],
      deck_after: [ "F", "T" ],
      discard_after: [ "C", "G" ]
    )
    c.apply!(@game)
    c.unapply!(@game)
    assert_equal [ "G", "F", "T" ], @game.deck
    assert_equal [ "C" ], @game.discard
  end

  test "to_h round-trips through from_h" do
    c = Turn::Consequences::CardDrawn.new(
      card: "G",
      deck_before: [ "G", "F" ],
      discard_before: [ "C" ],
      deck_after: [ "F" ],
      discard_after: [ "C", "G" ]
    )
    h = c.to_h
    assert_equal "card_drawn", h["type"]
    assert_equal "G", h["card"]
    assert_equal c, Turn::Consequences::CardDrawn.from_h(h)
  end

  test "factory dispatches by type" do
    c = Turn::Consequences::CardDrawn.new(
      card: "G",
      deck_before: [ "G" ],
      discard_before: [],
      deck_after: [],
      discard_after: [ "G" ]
    )
    assert_equal c, Turn::Consequences.from_h(c.to_h)
  end
end
