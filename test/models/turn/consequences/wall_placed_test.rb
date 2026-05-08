require "test_helper"

class Turn::Consequences::WallPlacedTest < ActiveSupport::TestCase
  def setup
    @game = Game.create!(state: "waiting")
    @game.add_player(users(:chris))
    @game.add_player(users(:paula))
    @game.start
    @game.reload
    @game.instantiate
  end

  test "apply places wall and decrements stone walls" do
    before = @game.stone_walls

    Turn::Consequences::WallPlaced.new(at: Coordinate.new(4, 4)).apply!(@game)

    assert_equal "Wall", @game.board_contents.tile_klass(4, 4)
    assert_equal before - 1, @game.stone_walls
  end

  test "unapply removes wall and increments stone walls" do
    @game.board_contents.place_wall(4, 4)
    @game.stone_walls = 20

    Turn::Consequences::WallPlaced.new(at: Coordinate.new(4, 4)).unapply!(@game)

    assert @game.board_contents.empty?(4, 4)
    assert_equal 21, @game.stone_walls
  end

  test "to_h round-trips through from_h" do
    consequence = Turn::Consequences::WallPlaced.new(at: Coordinate.new(4, 4))

    assert_equal consequence, Turn::Consequences::WallPlaced.from_h(consequence.to_h)
  end
end
