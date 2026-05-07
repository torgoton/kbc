require "test_helper"

class TurnClickTest < ActiveSupport::TestCase
  def setup
    @game = games(:game2player)
  end

  test "stores a consequences array as JSON" do
    click = TurnClick.create!(game: @game, order: 1, consequences: [ { "type" => "error", "message" => "x" } ])
    assert_equal "x", click.reload.consequences.first["message"]
  end

  test "most_recent_for returns the highest-order click for the game" do
    TurnClick.create!(game: @game, order: 1, consequences: [])
    latest = TurnClick.create!(game: @game, order: 2, consequences: [])
    other_game = games(:paula_turn_game)
    TurnClick.create!(game: other_game, order: 99, consequences: [])

    assert_equal latest, TurnClick.most_recent_for(@game)
  end

  test "order must be unique per game" do
    TurnClick.create!(game: @game, order: 1, consequences: [])
    assert_raises(ActiveRecord::RecordNotUnique) do
      TurnClick.create!(game: @game, order: 1, consequences: [])
    end
  end
end
