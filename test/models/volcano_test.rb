require "test_helper"

class VolcanoTest < ActiveSupport::TestCase
  # The decree is drawn at random from the pool, so keep dealing until it's the Volcano.
  def volcano_game
    loop do
      game = Game.new(state: "waiting", options: { "queenies" => [ "emperors_choice" ], "decree_chance" => 100 })
      game.add_player(users(:chris))
      game.add_player(users(:jules))
      game.save!
      game.start
      return game if game.volcano?
    end
  end

  test "the Volcano starts on a Mountain hex of the main map" do
    game = volcano_game
    row, col = game.volcano_hex
    assert_equal "M", game.instantiate.terrain_at(row, col)
    assert row < 20 && col < 20
  end

  test "the Volcano's section is the 10x10 board section it sits in" do
    game = Game.new(decree: { "name" => "volcano", "hex" => [ 12, 3 ] }, board_contents: BoardState.new.tap do |s|
      s.place_settlement(10, 0, 0)  # same section
      s.place_settlement(19, 9, 0)  # same section
      s.place_settlement(9, 3, 0)   # section above
      s.place_settlement(12, 10, 0) # section to the right
    end)
    assert_equal [ [ 10, 0 ], [ 19, 9 ] ], game.volcano_pieces_for(0)
    assert_equal 1, game.volcano_due_for(0)
  end
end
