require "test_helper"

class Turn::Consequences::BuildRecordedTest < ActiveSupport::TestCase
  def setup
    @game = games(:game2player)
  end

  test "apply! appends the build coord key to current_action.turn.builds" do
    @game.current_action = { "turn" => {} }
    Turn::Consequences::BuildRecorded.new(at: "[5, 7]").apply!(@game)
    assert_equal [ "[5, 7]" ], @game.current_action.dig("turn", "builds")
  end

  test "apply! creates the turn key when missing" do
    @game.current_action = nil
    Turn::Consequences::BuildRecorded.new(at: "[5, 7]").apply!(@game)
    assert_equal [ "[5, 7]" ], @game.current_action.dig("turn", "builds")
  end

  test "apply! appends to existing builds list" do
    @game.current_action = { "turn" => { "builds" => [ "[1, 2]" ] } }
    Turn::Consequences::BuildRecorded.new(at: "[5, 7]").apply!(@game)
    assert_equal [ "[1, 2]", "[5, 7]" ], @game.current_action.dig("turn", "builds")
  end

  test "unapply! pops the most recent build" do
    @game.current_action = { "turn" => { "builds" => [ "[1, 2]" ] } }
    c = Turn::Consequences::BuildRecorded.new(at: "[5, 7]")
    c.apply!(@game)
    c.unapply!(@game)
    assert_equal [ "[1, 2]" ], @game.current_action.dig("turn", "builds")
  end

  test "unapply! clears the key when the list drains empty" do
    @game.current_action = { "turn" => {} }
    c = Turn::Consequences::BuildRecorded.new(at: "[5, 7]")
    c.apply!(@game)
    c.unapply!(@game)
    refute @game.current_action.dig("turn").key?("builds")
  end

  test "to_h round-trips through from_h" do
    c = Turn::Consequences::BuildRecorded.new(at: "[5, 7]")
    assert_equal({ "type" => "build_recorded", "at" => "[5, 7]" }, c.to_h)
    assert_equal c, Turn::Consequences::BuildRecorded.from_h(c.to_h)
  end

  test "factory dispatches by type" do
    c = Turn::Consequences::BuildRecorded.new(at: "[5, 7]")
    assert_equal c, Turn::Consequences.from_h(c.to_h)
  end
end
