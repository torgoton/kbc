require "test_helper"

class Turn::Consequences::HandRefreshedTest < ActiveSupport::TestCase
  def setup
    @game = games(:game2player)
    @gp = @game.game_players.find { |g| g.order == 0 }
    @gp.hand = [ "G" ]
    @game.deck = [ "F", "T", "C" ]
    @game.discard = [ "D" ]
  end

  test "apply! sets player hand to hand_after and game deck/discard to *_after" do
    Turn::Consequences::HandRefreshed.new(
      player: 0,
      hand_before: [ "G" ],
      hand_after: [ "F" ],
      deck_before: [ "F", "T", "C" ],
      deck_after: [ "T", "C" ],
      discard_before: [ "D" ],
      discard_after: [ "D", "G" ]
    ).apply!(@game)
    assert_equal [ "F" ], @gp.hand
    assert_equal [ "T", "C" ], @game.deck
    assert_equal [ "D", "G" ], @game.discard
  end

  test "unapply! restores hand_before, deck_before, discard_before" do
    c = Turn::Consequences::HandRefreshed.new(
      player: 0,
      hand_before: [ "G" ],
      hand_after: [ "F" ],
      deck_before: [ "F", "T", "C" ],
      deck_after: [ "T", "C" ],
      discard_before: [ "D" ],
      discard_after: [ "D", "G" ]
    )
    c.apply!(@game)
    c.unapply!(@game)
    assert_equal [ "G" ], @gp.hand
    assert_equal [ "F", "T", "C" ], @game.deck
    assert_equal [ "D" ], @game.discard
  end

  test "to_h round-trips through from_h" do
    c = Turn::Consequences::HandRefreshed.new(
      player: 0,
      hand_before: [ "G" ],
      hand_after: [ "F" ],
      deck_before: [ "F" ],
      deck_after: [],
      discard_before: [],
      discard_after: [ "G" ]
    )
    assert_equal "hand_refreshed", c.to_h["type"]
    assert_equal c, Turn::Consequences::HandRefreshed.from_h(c.to_h)
  end

  test "factory dispatches by type" do
    c = Turn::Consequences::HandRefreshed.new(
      player: 0,
      hand_before: [ "G" ],
      hand_after: [ "F" ],
      deck_before: [ "F" ],
      deck_after: [],
      discard_before: [],
      discard_after: [ "G" ]
    )
    assert_equal c, Turn::Consequences.from_h(c.to_h)
  end
end
