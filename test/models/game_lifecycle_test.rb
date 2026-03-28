require "test_helper"

class GameLifecycleTest < ActiveSupport::TestCase
  def setup
    @game = Game.create!(state: "waiting")
    @game.add_player(users(:chris))
    @game.add_player(users(:paula))
    @game.start
    @game.reload
  end

  test "board content reflects tiles after start without reload" do
    # populate_boards creates @board before placing tiles, leaving stale content.
    # Without the fix, instantiate is a no-op and content_at returns nil for
    # tile locations. Test without reload so the stale @board is still in place.
    game = Game.create!(state: "waiting")
    game.add_player(users(:chris))
    game.add_player(users(:paula))
    game.start  # no reload — @board may be stale from populate_boards

    game.instantiate
    tile_row, tile_col = game.board_contents.locations_with_remaining_tiles.first
    assert_not_nil game.board.content_at(tile_row, tile_col),
      "board.content_at should return a tile object, not nil"
  end

  test "start returns false and leaves game in waiting when fewer than 2 players have joined" do
    game = Game.create!(state: "waiting")
    game.add_player(users(:chris))

    result = game.start
    game.reload

    assert_equal false, result
    assert_equal "waiting", game.state
  end

  test "start returns false when game is not in waiting state" do
    result = @game.start  # @game is already playing from setup

    assert_equal false, result
  end

  test "start produces a playing game with boards, tiles, supplies, and dealt hands" do
    assert_equal "playing", @game.state
    assert_equal 4, @game.boards.size
    assert_equal 3, @game.mandatory_count

    # Tiles placed at all location hexes with qty 2
    @game.instantiate
    @game.board.map.each_with_index do |section, i|
      section.location_hexes.each do |loc|
        row, col = i / 2 * 10 + loc[:r], (i % 2) * 10 + loc[:c]
        assert_equal 2, @game.board_contents.tile_qty(row, col),
          "expected qty 2 at tile location [#{row}, #{col}] (section #{i})"
      end
    end

    # Both players have full supply and a terrain card
    @game.game_players.each do |gp|
      assert_equal 40, gp.supply["settlements"]
      assert_includes %w[C D F G T], gp.hand
    end
  end

end
