require "test_helper"

class FerryTest < ActiveSupport::TestCase
  def ferry_game
    loop do
      game = Game.new(state: "waiting", options: { "queenies" => [ "emperors_choice" ], "decree_chance" => 100 })
      game.add_player(users(:chris))
      game.add_player(users(:jules))
      game.save!
      game.start
      return game if game.ferry?
    end
  end

  test "the ferry sits in the largest body of water, and every player gets the Ferry tile" do
    game = ferry_game
    state = game.board_contents.tap { game.instantiate }
    bodies = state.water_bodies
    ferry_body = state.water_body(*game.ferry_hex)
    assert_equal "W", game.instantiate.terrain_at(*game.ferry_hex)
    assert_equal bodies.map(&:size).max, ferry_body.size
    game.game_players.each { |gp| assert_includes gp.tiles.map { |t| t["klass"] }, "FerryTile" }
  end

  test "the shore is every non-water hex touching the ferry's water" do
    game = ferry_game
    game.instantiate
    body = game.board_contents.water_body(*game.ferry_hex)
    shore = game.board_contents.ferry_shore
    assert shore.any?
    shore.each do |cell|
      assert_not_includes body, cell
      assert game.board_contents.neighbors(*cell).any? { |n| body.include?(n) }
    end
  end

  test "center_of picks the cell nearest the middle" do
    assert_equal [ 2, 2 ], BoardState.center_of([ [ 2, 0 ], [ 2, 1 ], [ 2, 2 ], [ 2, 3 ], [ 2, 4 ] ])
  end
end
