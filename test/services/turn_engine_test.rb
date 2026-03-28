require "test_helper"

class TurnEngineTest < ActiveSupport::TestCase
  def setup
    @game = Game.create!(state: "waiting")
    @game.add_player(users(:chris))
    @game.add_player(users(:paula))
    @game.start
    @game.reload
    @engine = TurnEngine.new(@game)
  end

  test "build_settlement places a settlement and decrements mandatory_count" do
    force_hand("G")
    spot = empty_hexes_of("G", 1).first

    @engine.build_settlement(*spot)
    @game.reload

    assert_equal 2, @game.mandatory_count
    assert_equal 39, @game.current_player.supply["settlements"]
  end

  test "mandatory builds gate turn_endable?" do
    force_hand("G")
    spots = empty_hexes_of("G", 3)

    assert_not @engine.turn_endable?
    @engine.build_settlement(*spots[0])
    @game.reload
    assert_not @engine.turn_endable?

    @engine.build_settlement(*spots[1])
    @game.reload
    assert_not @engine.turn_endable?

    @engine.build_settlement(*spots[2])
    @game.reload
    assert @engine.turn_endable?
  end

  test "end_turn advances to next player and resets tiles" do
    first_player = @game.current_player
    force_hand("G")
    empty_hexes_of("G", 3).each { |spot| @engine.build_settlement(*spot) }

    @game.reload
    next_player = @game.game_players.find { |gp| gp.id != first_player.id }
    next_player.update!(tiles: [ { "klass" => "FarmTile", "from" => "[0, 0]", "used" => true } ])

    @engine.end_turn
    @game.reload

    assert_not_equal first_player.id, @game.current_player_id
    assert_equal 3, @game.mandatory_count
    assert_equal({ "type" => "mandatory" }, @game.current_action)
    assert @game.current_player.reload.tiles.all? { |t| t["used"] == false }
  end

  test "undo reverses a build: settlement removed, mandatory_count restored, move deleted" do
    force_hand("G")
    spot = empty_hexes_of("G", 1).first
    player = @game.current_player

    @engine.build_settlement(*spot)
    @game.reload

    assert_equal 2, @game.mandatory_count
    assert_equal 39, player.reload.supply["settlements"]
    assert @engine.undo_allowed?

    @engine.undo_last_move
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

    @engine.build_settlement(trigger_row, trigger_col)
    @game.reload

    assert_equal 1, @game.board_contents.tile_qty(tile_row, tile_col)
    assert_equal 1, player.reload.tiles.reject { |t| t["klass"] == "MandatoryTile" }.size
    assert @game.moves.exists?(action: "pick_up_tile", deliberate: false)
  end

  private

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
