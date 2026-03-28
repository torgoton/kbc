require "test_helper"

class GameLifecycleTest < ActiveSupport::TestCase
  def setup
    @game = Game.create!(state: "waiting")
    @game.add_player(users(:chris))
    @game.add_player(users(:paula))
    @game.start
    @game.reload
  end

  test "mandatory builds decrement mandatory_count and gate turn_endable?" do
    force_hand("G")
    spots = empty_hexes_of("G", 3)

    assert_not @game.turn_endable?
    @game.build_settlement(*spots[0])
    @game.reload
    assert_equal 2, @game.mandatory_count
    assert_not @game.turn_endable?

    @game.build_settlement(*spots[1])
    @game.reload
    assert_equal 1, @game.mandatory_count
    assert_not @game.turn_endable?

    @game.build_settlement(*spots[2])
    @game.reload
    assert_equal 0, @game.mandatory_count
    assert @game.turn_endable?
  end

  test "end_turn advances to next player and resets state for the new turn" do
    first_player = @game.current_player
    force_hand("G")
    empty_hexes_of("G", 3).each { |spot| @game.build_settlement(*spot) }

    @game.reload
    # Give the next player a used tile — end_turn resets tiles for the incoming player
    next_player = @game.game_players.find { |gp| gp.id != first_player.id }
    next_player.update!(tiles: [ { "klass" => "FarmTile", "from" => "[0, 0]", "used" => true } ])

    @game.end_turn
    @game.reload

    assert_not_equal first_player.id, @game.current_player_id
    assert_equal 3, @game.mandatory_count
    assert_equal({ "type" => "mandatory" }, @game.current_action)

    # Incoming player's tiles are reset to unused
    assert @game.current_player.reload.tiles.all? { |t| t["used"] == false }
  end

  test "undo reverses a build: settlement removed, mandatory_count restored, move deleted" do
    force_hand("G")
    spot = empty_hexes_of("G", 1).first
    player = @game.current_player

    @game.build_settlement(*spot)
    @game.reload

    assert_equal 2, @game.mandatory_count
    assert_equal 39, player.reload.supply["settlements"]
    assert @game.undo_allowed?

    @game.undo_last_move
    @game.reload

    assert_equal 3, @game.mandatory_count
    assert_equal 40, player.reload.supply["settlements"]
    assert @game.board_contents.empty?(*spot)
    assert_equal 0, @game.moves.count
  end

  test "building adjacent to a tile location picks it up and decrements qty" do
    tile_row, tile_col, trigger_row, trigger_col = find_tile_trigger_pair
    skip "No valid trigger position found" unless tile_row

    force_hand(@game.instantiate.terrain_at(trigger_row, trigger_col))
    player = @game.current_player

    @game.build_settlement(trigger_row, trigger_col)
    @game.reload

    assert_equal 1, @game.board_contents.tile_qty(tile_row, tile_col)
    assert_equal 1, player.reload.tiles.reject { |t| t["klass"] == "MandatoryTile" }.size
    assert @game.moves.exists?(action: "pick_up_tile", deliberate: false)
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

  private

  # Returns [tile_row, tile_col, trigger_row, trigger_col] where trigger is an empty
  # hex adjacent to the tile location with buildable terrain, or nil if none found.
  def find_tile_trigger_pair
    board = @game.instantiate
    @game.board_contents.locations_with_remaining_tiles.each do |t_row, t_col|
      @game.board_contents.neighbors(t_row, t_col).each do |nr, nc|
        terrain = board.terrain_at(nr, nc)
        if @game.board_contents.empty?(nr, nc) && %w[C D F G T].include?(terrain)
          return [ t_row, t_col, nr, nc ]
        end
      end
    end
    nil
  end

  def force_hand(terrain)
    @game.current_player.update!(hand: terrain)
  end

  # Returns up to n empty hexes of the given terrain on the current board.
  def empty_hexes_of(terrain, n)
    @game.instantiate
    spots = []
    20.times do |row|
      20.times do |col|
        next unless @game.board.terrain_at(row, col) == terrain
        next unless @game.board_contents.empty?(row, col)
        spots << [ row, col ]
        return spots if spots.size >= n
      end
    end
    spots
  end
end
