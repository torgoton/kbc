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

  test "build_settlement logs the location in the move message" do
    force_hand("G")
    spot = empty_hexes_of("G", 1).first

    @engine.build_settlement(*spot)
    @game.reload

    move = @game.moves.find_by(action: "build")
    assert_includes move.message, "[#{spot[0]}, #{spot[1]}]"
  end

  test "mandatory builds gate turn_endable?" do
    force_hand("G")

    assert_not @engine.turn_endable?
    2.times do
      @engine.build_settlement(*TurnEngine.new(@game).buildable_cells.first)
      @game.reload
      assert_not @engine.turn_endable?
    end
    @engine.build_settlement(*TurnEngine.new(@game).buildable_cells.first)
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

  test "building adjacent to a tile location picks it up and decrements qty" do
    tile_row, tile_col, trigger_row, trigger_col = find_tile_trigger_pair
    raise "No valid trigger position found" unless tile_row

    force_hand(@game.instantiate.terrain_at(trigger_row, trigger_col))
    player = @game.current_player

    @engine.build_settlement(trigger_row, trigger_col)
    @game.reload

    assert_equal 1, @game.board_contents.tile_qty(tile_row, tile_col)
    assert_equal 1, player.reload.tiles.reject { |t| t["klass"] == "MandatoryTile" }.size
    assert @game.moves.exists?(action: "pick_up_tile", deliberate: false)
  end

  test "picking up a tile records the location in taken_from" do
    tile_row, tile_col, trigger_row, trigger_col = find_tile_trigger_pair
    raise "No valid trigger position found" unless tile_row

    force_hand(@game.instantiate.terrain_at(trigger_row, trigger_col))
    player = @game.current_player

    @engine.build_settlement(trigger_row, trigger_col)
    @game.reload

    assert_includes player.reload.taken_from || [], "[#{tile_row}, #{tile_col}]"
  end

  test "undo of a meeple-granting tile pickup revokes the meeples" do
    @game.restart(include_boards: [ 12 ], max_board: 12) # ensure we have a meeple-granting tile section
    tile_row, tile_col, trigger_row, trigger_col = find_meeple_tile_trigger_pair
    raise "No meeple tile trigger position found" unless tile_row

    board = @game.instantiate
    klass = @game.board_contents.tile_klass(tile_row, tile_col)
    kind = Tiles::Tile.for_klass(klass).new(0).meeple_kind
    player = @game.current_player
    supply_before = player.reload.supply_hash[kind]

    force_hand(board.terrain_at(trigger_row, trigger_col))
    @engine.build_settlement(trigger_row, trigger_col)
    @game.reload

    assert @game.moves.exists?(action: "grant_meeple"), "expected a grant_meeple move after pickup"
    assert_operator player.reload.supply_hash[kind], :>, supply_before

    TurnEngine.new(@game).undo_last_move
    @game.reload

    assert_equal supply_before, player.reload.supply_hash[kind]
    assert_not @game.moves.exists?(action: "grant_meeple")
  end

  test "undo of a pickup removes the location from taken_from" do
    tile_row, tile_col, trigger_row, trigger_col = find_tile_trigger_pair
    raise "No valid trigger position found" unless tile_row

    force_hand(@game.instantiate.terrain_at(trigger_row, trigger_col))
    tile_key = "[#{tile_row}, #{tile_col}]"

    @engine.build_settlement(trigger_row, trigger_col)
    @game.reload
    assert_includes @game.current_player.reload.taken_from || [], tile_key

    @engine.undo_last_move
    @game.reload

    assert_not_includes @game.current_player.reload.taken_from || [], tile_key
  end

  test "forfeiting a tile preserves taken_from (cannot re-seize the same location)" do
    tile_row, tile_col, trigger_row, trigger_col = find_tile_trigger_pair
    raise "No valid trigger position found" unless tile_row

    force_hand(@game.instantiate.terrain_at(trigger_row, trigger_col))
    tile_key = "[#{tile_row}, #{tile_col}]"

    @engine.build_settlement(trigger_row, trigger_col)
    @game.reload
    assert_includes @game.current_player.reload.taken_from || [], tile_key

    @game.board_contents_will_change!
    @game.board_contents.remove(trigger_row, trigger_col)
    @game.save
    @engine.send(:apply_tile_forfeit, @game.current_player)
    @game.current_player.save
    @game.save
    reloaded = @game.current_player.reload

    assert_empty reloaded.tiles.reject { |t| t["klass"] == "MandatoryTile" },
      "tile should have been forfeited"
    assert_includes reloaded.taken_from || [], tile_key,
      "taken_from must survive forfeit so the location cannot be re-seized"
  end

  test "player cannot pick up a second tile from a location they've already seized" do
    tile_row, tile_col, trigger_row, trigger_col = find_tile_trigger_pair
    raise "No valid trigger position found" unless tile_row

    force_hand(@game.instantiate.terrain_at(trigger_row, trigger_col))
    player = @game.current_player
    tile_key = "[#{tile_row}, #{tile_col}]"
    player.update!(taken_from: [ tile_key ])

    @engine.build_settlement(trigger_row, trigger_col)
    @game.reload

    assert_equal 2, @game.board_contents.tile_qty(tile_row, tile_col),
      "tile qty should stay at 2 when player has already taken from this location"
    assert_empty player.reload.tiles.reject { |t| t["klass"] == "MandatoryTile" }
    assert_not @game.moves.exists?(action: "pick_up_tile")
  end

  test "build_settlement returns 'No settlements left' when supply is exhausted" do
    force_hand("G")
    @game.current_player.update!(supply: { "settlements" => 0 })

    result = @engine.build_settlement(*empty_hexes_of("G", 1).first)

    assert_equal "No settlements left", result
  end

  test "build_settlement returns 'Not avilalable' when location not adjacent to existing settlements" do
    # Place a settlement at a Canyon hex in Tavern board, then try to build
    # at a far-away Canyon hex that cannot be adjacent
    @game.boards = [ [ 4, 0 ], [ 5, 0 ], [ 1, 0 ], [ 0, 0 ] ]
    @game.save
    @game.instantiate
    player = @game.current_player
    @game.board_contents_will_change!
    @game.board_contents.place_settlement(0, 7, player.order)
    @game.save

    game2 = Game.find(@game.id)
    game2.current_player.update!(hand: [ "C" ])
    engine2 = TurnEngine.new(game2)

    # (5,1) is Canyon on Tavern board row 5 ("FCCWGTTCCC"), not adjacent to (0,7)
    result = engine2.build_settlement(5, 1)

    assert_equal "Not available", result
  end

  test "build_settlement uses neighbor adjacency when player has an existing settlement" do
    # Place a settlement at a Canyon hex, then build on an adjacent Canyon hex
    # Tavern board has Canyon at (0,7) and (0,8) — pin it to quadrant 0
    @game.boards = [ [ 4, 0 ], [ 5, 0 ], [ 1, 0 ], [ 0, 0 ] ]
    @game.save
    @game.instantiate
    player = @game.current_player
    @game.board_contents_will_change!
    @game.board_contents.place_settlement(0, 7, player.order)
    @game.save

    game2 = Game.find(@game.id)
    game2.current_player.update!(hand: [ "C" ])
    engine2 = TurnEngine.new(game2)

    # (0,8) is Canyon and adjacent to (0,7) on even row (offset: [0,+1])
    engine2.build_settlement(0, 8)
    game2.reload

    assert_equal player.order, game2.board_contents.player_at(0, 8)
  end

  test "activate_tile_build returns 'No settlements left' when supply is exhausted" do
    @game.current_player.update!(supply: { "settlements" => 0 })
    @game.update!(current_action: { "type" => "oasis" })

    result = @engine.activate_tile_build(0, 1)

    assert_equal "No settlements left", result
  end

  test "activate_tile_build returns 'Not available' when player has no matching tile" do
    # Player starts with only a MandatoryTile, not an OasisTile
    @game.update!(current_action: { "type" => "oasis" })

    result = @engine.activate_tile_build(0, 1)

    assert_equal "Not available", result
  end

  test "activate_tile_build returns 'Not available' when destination is not in valid_destinations" do
    @game.boards = [ [ 1, 0 ], [ 5, 0 ], [ 0, 0 ], [ 4, 0 ] ]
    @game.save!
    @game.current_player.update!(tiles: [
      { "klass" => "MandatoryTile", "used" => false },
      { "klass" => "OasisTile", "from" => "[2, 7]", "used" => false }
    ])
    @game.update!(current_action: { "type" => "oasis" })

    # (3, 3) is Forest on the Oasis board (section 1, row 3: "WWWFGTFFFF") — not Desert
    result = @engine.activate_tile_build(3, 3)

    assert_equal "Not available", result
  end

  test "turn_state returns paddock message when current_action is paddock" do
    @game.update!(current_action: { "type" => "paddock" })

    assert_match(/must move a settlement/, @engine.turn_state)
  end

  test "turn_state returns oasis message when current_action is oasis" do
    @game.update!(current_action: { "type" => "oasis" })

    assert_match(/must build on a Desert hex/, @engine.turn_state)
  end

  test "turn_state returns donation tile message for namespaced Nomad tile action" do
    @game.update!(current_action: { "type" => "donationdesert", "klass" => "DonationDesertTile", "remaining" => 3 })

    assert_match(/must build on a Desert hex/, @engine.turn_state)
  end

  test "turn_state includes remaining count for donation tile action" do
    @game.update!(current_action: { "type" => "donationdesert", "klass" => "DonationDesertTile", "remaining" => 2 })

    assert_match(/2 remaining/, @engine.turn_state)
  end

  test "turn_state includes tile option when player has an activatable tile" do
    @game.current_player.update!(tiles: [
      { "klass" => "MandatoryTile", "used" => false },
      { "klass" => "OasisTile", "from" => "[2, 7]", "used" => false }
    ])
    # mandatory_count starts at 3 (MANDATORY_COUNT), OasisTile activatable at full count

    assert_match(/or select a tile/, @engine.turn_state)
  end

  test "turn_state reports must end turn when mandatory builds complete" do
    @game.update!(mandatory_count: 0)

    assert_match(/must end their turn/, @engine.turn_state)
  end

  test "undo_allowed? returns false when there are no moves" do
    assert_not @engine.undo_allowed?
  end

  test "undo_last_move returns immediately when there are no deliberate moves" do
    assert_nil @engine.undo_last_move
  end

  test "end_turn draws 1 card when player does not hold CrossroadsTile" do
    player = @game.current_player
    @engine.end_turn
    assert_equal 1, player.reload.hand.size
  end

  test "end_turn draws 2 cards when player holds CrossroadsTile" do
    player = @game.current_player
    player.update!(tiles: [ { "klass" => "CrossroadsTile", "from" => "[4, 7]", "used" => false } ])
    @engine.end_turn
    player.reload
    assert_equal 2, player.hand.size
    player.hand.each { |card| assert_includes %w[C D F G T], card }
  end

  test "player acquires CrossroadsTile mid-turn and draws 2 cards at end of that turn" do
    player = @game.current_player
    player.update!(tiles: [ { "klass" => "CrossroadsTile", "from" => "[4, 7]", "used" => false } ])
    @game.update!(mandatory_count: 0)
    @engine.end_turn
    assert_equal 2, player.reload.hand.size
  end

  test "buildable_cells for mandatory build returns buildable cells" do
    force_hand("G")
    cells = @engine.buildable_cells
    assert cells.any?
    row, col = cells.first
    assert_not_equal "Not avilalable", @engine.build_settlement(row, col)
  end

  test "buildable_cells returns empty when mandatory_count is zero" do
    force_hand("G")
    @game.update!(mandatory_count: 0)

    assert_empty @engine.buildable_cells
  end

  test "building on the second card's terrain works and locks to that terrain" do
    use_oasis_board
    d_hex = [ 0, 0 ]
    @game.current_player.update!(hand: [ "G", "D" ])

    result = TurnEngine.new(@game.reload).build_settlement(*d_hex)

    assert_not_equal "Not available", result
    @game.reload
    assert_equal "D", @game.current_action["chosen_terrain"]
  end

  test "first mandatory build with 2 cards locks chosen_terrain" do
    use_oasis_board
    g_hex = [ 0, 7 ]
    other_terrain = (@game.board.terrain_at(g_hex[0], g_hex[1]) == "G") ? "D" : "G"
    @game.current_player.update!(hand: [ "G", other_terrain ])

    TurnEngine.new(@game.reload).build_settlement(*g_hex)

    @game.reload
    assert_equal "G", @game.current_action["chosen_terrain"]
    assert_equal [ "G", other_terrain ], @game.current_player.reload.hand
  end

  test "second mandatory build uses locked terrain and rejects other terrain" do
    use_oasis_board
    d_hex = [ 0, 0 ]
    @game.update!(current_action: { "type" => "mandatory", "chosen_terrain" => "G" })
    @game.current_player.update!(hand: [ "G", "D" ])

    result = TurnEngine.new(@game.reload).build_settlement(*d_hex)
    assert_equal "Not available", result
  end

  test "buildable_cells with 2-card hand and no chosen_terrain returns union of both terrains" do
    @game.boards = [ [ 2, 0 ], [ 5, 0 ], [ 0, 0 ], [ 4, 0 ] ]
    # OasisBoard row 0 = "DDCWWTTGGG"; hand cards G and D
    @game.current_player.update!(hand: [ "G", "D" ])
    @game.reload

    cells = TurnEngine.new(@game).buildable_cells

    @game.instantiate
    terrains = cells.map { |r, c| @game.board.terrain_at(r, c) }.uniq.sort
    assert_includes terrains, "G"
    assert_includes terrains, "D"
  end

  test "buildable_cells with 2-card hand and chosen_terrain uses only that terrain" do
    @game.boards = [ [ 2, 0 ], [ 5, 0 ], [ 0, 0 ], [ 4, 0 ] ]
    @game.current_player.update!(hand: [ "G", "D" ])
    @game.update!(current_action: { "type" => "mandatory", "chosen_terrain" => "G" })
    @game.reload

    cells = TurnEngine.new(@game).buildable_cells

    @game.instantiate
    cells.each { |r, c| assert_equal "G", @game.board.terrain_at(r, c) }
  end

  test "buildable_cells for paddock with from returns valid move destinations" do
    force_hand("G")
    spot = empty_hexes_of("G", 1).first
    @engine.build_settlement(*spot)
    @game.reload
    @game.update!(current_action: { "type" => "paddock", "from" => "[#{spot[0]}, #{spot[1]}]" })
    @game.current_player.update!(
      tiles: [ { "klass" => "PaddockTile", "from" => "[2, 0]", "used" => false } ]
    )
    @game.reload

    cells = @engine.buildable_cells

    @game.instantiate
    expected = Tiles::Location::PaddockTile.new(0).valid_destinations(
      from_row: spot[0], from_col: spot[1],
      board_contents: with_terrain(@game.board_contents, @game.board)
    )
    assert_equal expected.sort, cells.sort
  end

  test "buildable_cells for resettlement with from returns only adjacent step destinations" do
    @game.boards = [ [ 1, 1 ], [ 12, 0 ], [ 0, 0 ], [ 4, 0 ] ]
    player = @game.current_player
    @game.board_contents = BoardState.new.tap do |state|
      state.place_settlement(4, 3, player.order)
    end
    @game.save!
    player.update!(tiles: [ { "klass" => "ResettlementTile", "from" => "[3, 4]", "used" => false } ])
    @game.update!(current_action: {
      "type" => "resettlement", "klass" => "ResettlementTile",
      "budget" => 4, "moves" => 0, "from" => "[4, 3]"
    })

    cells = @engine.buildable_cells

    @game.instantiate
    assert_includes cells, [ 3, 3 ]
    assert_not_includes cells, [ 1, 2 ]
    cells.each do |r, c|
      assert_includes @game.board_contents.neighbors(4, 3), [ r, c ]
    end
  end

  test "buildable_cells for paddock without from returns settlements with valid moves" do
    force_hand("G")
    @engine.build_settlement(*empty_hexes_of("G", 1).first)
    @game.reload
    @game.update!(current_action: { "type" => "paddock" })
    @game.current_player.update!(
      tiles: [ { "klass" => "PaddockTile", "from" => "[2, 0]", "used" => false } ]
    )
    @game.reload

    cells = @engine.buildable_cells

    assert cells.any?
    @game.instantiate
    player_settlements = @game.board_contents.settlements_for(@game.current_player.order).to_a
    cells.each { |r, c| assert_includes player_settlements, [ r, c ] }
  end

  test "buildable_cells for oasis action returns empty desert hexes" do
    @game.update!(current_action: { "type" => "oasis" }, mandatory_count: 0)
    @game.current_player.update!(
      tiles: [ { "klass" => "OasisTile", "from" => "[2, 7]", "used" => false } ]
    )
    @game.reload

    cells = @engine.buildable_cells

    assert cells.any?
    @game.instantiate
    cells.each do |r, c|
      assert_equal "D", @game.board.terrain_at(r, c)
      assert @game.board_contents.empty?(r, c)
    end
  end

  test "turn_state returns barn message when current_action is barn" do
    @game.update!(current_action: { "type" => "barn" })
    @game.current_player.update!(hand: [ "G" ])

    assert_match(/must move a settlement to a Grass hex/, @engine.turn_state)
  end

  test "turn_state returns oracle message when current_action is oracle" do
    @game.update!(current_action: { "type" => "oracle" })
    @game.current_player.update!(hand: [ "G" ])

    assert_match(/must build on a Grass hex/, @engine.turn_state)
  end


  test "activate_tile_build for oracle with 2-card hand locks chosen_terrain" do
    @game.instantiate
    g_hex = empty_hexes_of("G", 1).first
    other_terrain = "D"
    @game.update!(current_action: { "type" => "oracle" }, mandatory_count: 1)
    @game.current_player.update!(
      hand: [ "G", other_terrain ],
      tiles: [ { "klass" => "OracleTile", "from" => "[3, 7]", "used" => false } ]
    )

    TurnEngine.new(@game.reload).activate_tile_build(*g_hex)

    @game.reload
    assert_equal "G", @game.current_action["chosen_terrain"]
  end

  test "place_wall for quarry with 2-card hand locks chosen_terrain" do
    use_oasis_board
    g_hex = [ 0, 7 ]
    neighbor = [ 0, 6 ]
    @game.board_contents.place_settlement(*neighbor, @game.current_player.order)
    @game.save!
    @game.update!(current_action: { "type" => "quarry", "klass" => "QuarryTile", "walls_placed" => 0 })
    @game.current_player.update!(
      hand: [ "G", "D" ],
      tiles: [ { "klass" => "QuarryTile", "from" => "[0, 0]", "used" => false } ]
    )

    TurnEngine.new(@game.reload).place_wall(*g_hex)

    @game.reload
    assert_equal "G", @game.current_action["chosen_terrain"]
  end

  private

  def use_oasis_board
    @game.boards = [ [ 1, 0 ], [ 5, 0 ], [ 0, 0 ], [ 4, 0 ] ]
    @game.board_contents = BoardState.new
    @game.save!
    @game.reload
    @game.instantiate
    @engine = TurnEngine.new(@game)
  end

  def find_meeple_tile_trigger_pair
    meeple_klasses = %w[BarracksTile LighthouseTile WagonTile]
    board = @game.instantiate
    @game.board_contents.locations_with_remaining_tiles.each do |t_row, t_col|
      klass = @game.board_contents.tile_klass(t_row, t_col)
      next unless meeple_klasses.include?(klass)
      @game.board_contents.neighbors(t_row, t_col).each do |nr, nc|
        terrain = board.terrain_at(nr, nc)
        if @game.board_contents.empty?(nr, nc) && %w[C D F G T].include?(terrain)
          return [ t_row, t_col, nr, nc ]
        end
      end
    end
    nil
  end

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

  test "turn_state with sword action tells player to select a settlement to remove" do
    opponent = @game.game_players.find { |gp| gp != @game.current_player }
    @game.update!(current_action: {
      "type" => "sword", "klass" => "SwordTile", "pending_orders" => [ opponent.order ]
    })

    assert_match(/select a settlement to remove/, @engine.turn_state)
  end

  test "placing a lighthouse ship adjacent to an oasis location picks up an Oasis tile" do
    @game.boards = [ [ 1, 1 ], [ 12, 0 ], [ 0, 0 ], [ 4, 0 ] ]
    # Start a clean board so (1, 4) is deterministically empty water. Reusing the
    # board_contents from `start` leaves randomly-placed location/nomad tiles that
    # can occupy (1, 4) and make the ship placement illegal (order-dependent flake).
    @game.board_contents = BoardState.new.tap do |state|
      state.place_tile(2, 4, "OasisTile", 2)
    end
    @game.save!
    @engine = TurnEngine.new(@game.reload)

    player = @game.current_player
    player.update!(tiles: [ { "klass" => "LighthouseTile", "from" => "[6, 16]", "used" => false } ])
    player.reload.add_ships!(1)

    @engine.select_action("lighthouse")
    @engine.execute_meeple_action(1, 4)
    @game.reload

    assert @game.board_contents.ship_at?(1, 4)
    assert_equal 1, @game.board_contents.tile_qty(2, 4)
    assert_includes player.reload.tiles, { "klass" => "OasisTile", "from" => "[2, 4]", "used" => true }
    assert @game.moves.exists?(action: "pick_up_tile", from: "[2, 4]", deliberate: false)
  end

  test "moving a lighthouse ship past a location picks up then forfeits the tile and logs each step" do
    @game.boards = [ [ 1, 1 ], [ 12, 0 ], [ 0, 0 ], [ 4, 0 ] ]
    player = @game.current_player
    @game.board_contents = BoardState.new.tap do |state|
      state.place_tile(2, 4, "OasisTile", 2)
      state.place_ship(0, 3, player.order)
    end
    @game.save!
    player.update!(tiles: [ { "klass" => "LighthouseTile", "from" => "[6, 16]", "used" => false } ])
    @game.update!(current_action: { "type" => "lighthouse", "klass" => "LighthouseTile", "budget" => 3, "moves" => 0, "from" => "[0, 3]" })

    engine = TurnEngine.new(@game.reload)
    engine.execute_meeple_action(1, 3)
    engine.execute_meeple_action(0, 4)
    engine.end_tile_action
    @game.reload

    assert @game.board_contents.ship_at?(0, 4)
    assert_empty player.reload.tiles.reject { |tile| tile["klass"] == "LighthouseTile" }
    assert @game.moves.where(action: "move_ship").all?(&:deliberate?)
    assert_equal [ [ "[0, 3]", "[1, 3]" ], [ "[1, 3]", "[0, 4]" ] ],
      @game.moves.where(action: "move_ship").order(:order).pluck(:from, :to)
    assert @game.moves.exists?(action: "pick_up_tile", from: "[2, 4]")
    assert @game.moves.exists?(action: "forfeit_tile", from: "[2, 4]")
  end

  test "moving a lighthouse ship cannot move more than one space" do
    @game.boards = [ [ 1, 1 ], [ 12, 0 ], [ 0, 0 ], [ 4, 0 ] ]
    player = @game.current_player
    @game.board_contents = BoardState.new.tap do |state|
      state.place_ship(0, 3, player.order)
    end
    @game.save!
    player.update!(tiles: [ { "klass" => "LighthouseTile", "from" => "[6, 16]", "used" => false } ])
    @game.update!(current_action: { "type" => "lighthouse", "klass" => "LighthouseTile", "budget" => 3, "moves" => 0, "from" => "[0, 3]" })

    result = TurnEngine.new(@game.reload).execute_meeple_action(2, 3)
    @game.reload

    assert_equal "Not available", result
    assert @game.board_contents.ship_at?(0, 3)
    assert_not @game.moves.exists?(action: "move_ship")
  end

  test "moving a wagon past a location picks up then forfeits the tile and logs each step" do
    @game.boards = [ [ 1, 1 ], [ 12, 0 ], [ 0, 0 ], [ 4, 0 ] ]
    player = @game.current_player
    @game.board_contents = BoardState.new.tap do |state|
      state.place_tile(2, 4, "OasisTile", 2)
      state.place_wagon(4, 3, player.order)
    end
    @game.save!
    player.update!(tiles: [ { "klass" => "WagonTile", "from" => "[6, 16]", "used" => false } ])
    @game.update!(current_action: { "type" => "wagon", "klass" => "WagonTile", "budget" => 3, "moves" => 0, "from" => "[4, 3]" })

    engine = TurnEngine.new(@game.reload)
    engine.execute_meeple_action(3, 3)
    engine.execute_meeple_action(2, 3)
    engine.execute_meeple_action(1, 2)
    @game.reload

    assert @game.board_contents.wagon_at?(1, 2)
    assert_empty player.reload.tiles.reject { |tile| tile["klass"] == "WagonTile" }
    assert @game.moves.where(action: "move_wagon").all?(&:deliberate?)
    assert_equal [ [ "[4, 3]", "[3, 3]" ], [ "[3, 3]", "[2, 3]" ], [ "[2, 3]", "[1, 2]" ] ],
      @game.moves.where(action: "move_wagon").order(:order).pluck(:from, :to)
    assert @game.moves.exists?(action: "pick_up_tile", from: "[2, 4]")
    assert @game.moves.exists?(action: "forfeit_tile", from: "[2, 4]")
  end

  test "undo after a multi-step wagon move reverses only the last step" do
    @game.boards = [ [ 1, 1 ], [ 12, 0 ], [ 0, 0 ], [ 4, 0 ] ]
    player = @game.current_player
    @game.board_contents = BoardState.new.tap do |state|
      state.place_tile(2, 4, "OasisTile", 2)
      state.place_wagon(4, 3, player.order)
    end
    @game.save!
    player.update!(tiles: [ { "klass" => "WagonTile", "from" => "[6, 16]", "used" => false } ])
    @game.update!(current_action: { "type" => "wagon", "klass" => "WagonTile", "budget" => 3, "moves" => 0, "from" => "[4, 3]" })

    engine = TurnEngine.new(@game.reload)
    engine.execute_meeple_action(3, 3)
    engine.execute_meeple_action(2, 3)
    engine.execute_meeple_action(1, 2)
    engine.undo_last_move
    @game.reload

    assert @game.board_contents.wagon_at?(2, 3)
    assert_equal({ "type" => "wagon", "klass" => "WagonTile", "budget" => 1, "moves" => 2, "from" => "[2, 3]" }, @game.current_action)
    assert_includes player.reload.tiles, { "klass" => "OasisTile", "from" => "[2, 4]", "used" => true }
  end

  test "moving a wagon away from a picked up Nomad tile does not forfeit it" do
    @game.boards = [ [ 1, 1 ], [ 12, 0 ], [ 0, 0 ], [ 4, 0 ] ]
    player = @game.current_player
    @game.board_contents = BoardState.new.tap do |state|
      state.place_tile(2, 4, "SwordTile", 1)
      state.place_wagon(4, 3, player.order)
    end
    @game.save!
    player.update!(tiles: [ { "klass" => "WagonTile", "from" => "[6, 16]", "used" => false } ])
    @game.update!(current_action: { "type" => "wagon", "klass" => "WagonTile", "budget" => 3, "moves" => 0, "from" => "[4, 3]" })

    engine = TurnEngine.new(@game.reload)
    engine.execute_meeple_action(3, 3)
    engine.execute_meeple_action(2, 3)
    engine.execute_meeple_action(1, 2)
    @game.reload

    picked_up = player.reload.tiles.find { |tile| tile["klass"] == "SwordTile" && tile["from"] == "[2, 4]" }
    assert picked_up
    assert picked_up["used"]
    assert_not @game.moves.exists?(action: "forfeit_tile", from: "[2, 4]")
  end

  test "resettlement logs each step and forfeits a location tile after moving away" do
    @game.boards = [ [ 1, 1 ], [ 12, 0 ], [ 0, 0 ], [ 4, 0 ] ]
    player = @game.current_player
    source_tile = Tiles::Nomad::ResettlementTile.new(0)
    @game.board_contents = BoardState.new.tap do |state|
      state.place_tile(2, 4, "OasisTile", 2)
      state.place_settlement(4, 3, player.order)
      state.place_settlement(2, 7, player.order)
    end
    @game.save!
    player.update!(tiles: [ { "klass" => "ResettlementTile", "from" => "[3, 4]", "used" => false } ])
    @game.update!(current_action: {
      "type" => "resettlement", "klass" => "ResettlementTile",
      "budget" => 4, "moves" => 0
    })
    @game.instantiate

    engine = TurnEngine.new(@game.reload)
    first_step = source_tile.valid_destinations(
      from_row: 4, from_col: 3,
      board_contents: with_terrain(@game.board_contents, @game.board),
      player_order: player.order,
      budget: 4
    ).first
    second_step = source_tile.valid_destinations(
      from_row: 2, from_col: 7,
      board_contents: with_terrain(@game.board_contents, @game.board),
      player_order: player.order,
      budget: 4
    ).first
    assert first_step
    assert second_step

    engine.select_settlement(4, 3)
    @game.reload
    engine.move_settlement(*first_step)
    @game.reload
    assert_equal 3, @game.current_action["budget"]
    assert_nil @game.current_action["from"]

    engine.select_settlement(2, 7)
    @game.reload
    engine.move_settlement(*second_step)
    @game.reload

    assert @game.board_contents.player_at(*second_step)
    assert @game.moves.where(action: "move_settlement").all?(&:deliberate?)
    assert_equal [
      [ "[4, 3]", Coordinate.new(*first_step).to_key ],
      [ "[2, 7]", Coordinate.new(*second_step).to_key ]
    ],
      @game.moves.where(action: "move_settlement").order(:order).pluck(:from, :to)
    assert_nil @game.current_action["from"]
    assert_equal 2, @game.current_action["budget"]
  end

  # ---------------------------------------------------------------------------
  # activate_fort_tile
  # ---------------------------------------------------------------------------

  test "activate_fort_tile records activate_fort (non-reversible deliberate) and draw_fort_card (non-reversible non-deliberate)" do
    @game.current_player.update!(tiles: [
      { "klass" => "MandatoryTile", "used" => false },
      { "klass" => "FortTile", "from" => "[3, 3]", "used" => false }
    ])

    assert_difference("@game.moves.count", 2) do
      @engine.activate_fort_tile
    end
    @game.reload

    fort_move, draw_move = @game.moves.order(:order).last(2)

    assert_equal "activate_fort", fort_move.action
    assert fort_move.deliberate
    assert_not fort_move.reversible

    assert_equal "draw_fort_card", draw_move.action
    assert_not draw_move.deliberate
    assert_not draw_move.reversible
    assert_includes %w[C D F G T], draw_move.payload["card"]
  end

  test "activate_fort_tile sets current_action to fort with fort_terrain" do
    @game.current_player.update!(tiles: [
      { "klass" => "MandatoryTile", "used" => false },
      { "klass" => "FortTile", "from" => "[3, 3]", "used" => false }
    ])

    @engine.activate_fort_tile
    @game.reload

    assert_equal "fort", @game.current_action["type"]
    assert_equal "FortTile", @game.current_action["klass"]
    assert_includes %w[C D F G T], @game.current_action["fort_terrain"]
  end

  test "activate_fort_tile removes the drawn card from the deck and adds it to discard" do
    @game.current_player.update!(tiles: [
      { "klass" => "MandatoryTile", "used" => false },
      { "klass" => "FortTile", "from" => "[3, 3]", "used" => false }
    ])
    deck_size_before = @game.deck.size
    discard_size_before = @game.discard.size

    @engine.activate_fort_tile
    @game.reload

    assert_equal deck_size_before - 1, @game.deck.size
    assert_equal discard_size_before + 1, @game.discard.size
    drawn = @game.current_action["fort_terrain"]
    assert_includes @game.discard, drawn
  end

  test "undo_allowed? is false after activate_fort_tile (card draw blocks undo)" do
    @game.current_player.update!(tiles: [
      { "klass" => "MandatoryTile", "used" => false },
      { "klass" => "FortTile", "from" => "[3, 3]", "used" => false }
    ])

    @engine.activate_fort_tile
    @game.reload

    assert_not TurnEngine.new(@game).undo_allowed?
  end

  test "activate_fort_tile returns Not available if action is not mandatory" do
    @game.current_player.update!(tiles: [
      { "klass" => "MandatoryTile", "used" => false },
      { "klass" => "FortTile", "from" => "[3, 3]", "used" => false }
    ])
    @game.update!(current_action: { "type" => "fort", "klass" => "FortTile", "fort_terrain" => "G" })

    result = nil
    assert_no_difference("@game.moves.count") do
      result = @engine.activate_fort_tile
    end

    assert_equal "Not available", result
  end

  # ---------------------------------------------------------------------------
  # Fort tile build
  # ---------------------------------------------------------------------------

  test "buildable_cells during fort action returns cells of drawn terrain, not player hand" do
    force_hand("G")
    spot = empty_hexes_of("G", 1).first
    @engine.build_settlement(*spot)
    @game.reload

    @game.current_player.update!(tiles: [
      { "klass" => "MandatoryTile", "used" => false },
      { "klass" => "FortTile", "from" => "[3, 3]", "used" => false }
    ])

    # Force a known fort terrain that differs from hand
    drawn = (@game.current_player.hand.first == "G") ? "D" : "G"
    @game.update!(
      mandatory_count: 0,
      current_action: { "type" => "fort", "klass" => "FortTile", "fort_terrain" => drawn }
    )

    cells = TurnEngine.new(@game).buildable_cells

    @game.instantiate
    cells.each do |r, c|
      assert_equal drawn, @game.board.terrain_at(r, c),
        "Expected all buildable cells to be #{drawn} terrain, got #{@game.board.terrain_at(r, c)} at [#{r},#{c}]"
    end
  end

  test "activate_tile_build on fort terrain places settlement, marks tile used, resets action" do
    use_oasis_board
    force_hand("D")
    spot = [ 0, 0 ]
    @engine.build_settlement(*spot)
    @game.reload

    @game.current_player.update!(tiles: [
      { "klass" => "MandatoryTile", "used" => false },
      { "klass" => "FortTile", "from" => "[3, 3]", "used" => false }
    ])

    drawn = "G"
    fort_spot = [ 0, 7 ]
    @game.update!(
      mandatory_count: 0,
      current_action: { "type" => "fort", "klass" => "FortTile", "fort_terrain" => drawn }
    )

    TurnEngine.new(@game).activate_tile_build(*fort_spot)
    @game.reload

    assert_equal({ "type" => "mandatory" }, @game.current_action)
    assert_not @game.board_contents.empty?(*fort_spot)
    fort = @game.current_player.tiles.find { |t| t["klass"] == "FortTile" }
    assert fort["used"]
  end

  # Drift closed by the legal_targets seam: wall targets must not be offered
  # (and place_wall must be rejected) once stone walls are exhausted.
  test "no wall targets and place_wall rejected when stone walls are exhausted" do
    @game.current_player.update!(tiles: [ { "klass" => "QuarryTile", "from" => "[2, 0]", "used" => false } ])
    @game.update!(current_action: { "type" => "quarry", "klass" => "QuarryTile" }, stone_walls: 0)
    spot = empty_hexes_of("G", 1).first

    assert_empty TurnEngine.new(@game).buildable_cells
    assert_equal "No stone walls left", @engine.place_wall(*spot)
    assert @game.reload.board_contents.empty?(*spot)
  end

  # Gap closed: a settlement move to an illegal destination is rejected instead
  # of silently mutating the board.
  test "move_settlement rejects a destination that is not a legal move" do
    @game.boards = [ [ 1, 0 ], [ 5, 0 ], [ 0, 0 ], [ 4, 0 ] ]
    @game.update!(current_action: { "type" => "paddock", "from" => "[5, 5]" })
    @game.instantiate
    @game.board_contents.place_settlement(5, 5, @game.current_player.order)
    @game.save!
    # [5, 6] is one hex away — not a legal Paddock move (which is two in a line).
    assert_equal "Not available", @engine.move_settlement(5, 6)
    assert_equal @game.current_player.order, @game.reload.board_contents.player_at(5, 5)
    assert @game.board_contents.empty?(5, 6)
  end

  # --- Timed games: clock accounting ---

  test "end_turn does not touch the clock for an untimed game" do
    force_hand("G")
    empty_hexes_of("G", 3).each { |spot| @engine.build_settlement(*spot) }
    mover = @game.current_player

    @engine.end_turn

    assert_nil mover.reload.time_remaining_ms
    assert_nil @game.reload.turn_started_at
  end

  test "record_move stamps clock_started_at on a timed player's first deliberate move" do
    game, engine = start_timed_game("blitz")
    mover = game.current_player
    assert_nil mover.clock_started_at

    force_hand("G", game: game)
    spot = empty_hexes_of("G", 1, game: game).first
    engine.build_settlement(*spot)

    assert_not_nil mover.reload.clock_started_at
  end

  test "undo_last_move does not touch the clock" do
    game, engine = start_timed_game("blitz")
    mover = game.current_player
    force_hand("G", game: game)
    spot = empty_hexes_of("G", 1, game: game).first

    engine.build_settlement(*spot)
    stamped_at = mover.reload.clock_started_at
    remaining_before_undo = mover.time_remaining_ms

    engine.undo_last_move
    mover.reload

    assert_equal stamped_at, mover.clock_started_at
    assert_equal remaining_before_undo, mover.time_remaining_ms
  end

  test "record_move does not overwrite clock_started_at on a later deliberate move" do
    game, engine = start_timed_game("blitz")
    mover = game.current_player
    force_hand("G", game: game)
    spots = empty_hexes_of("G", 2, game: game)
    engine.build_settlement(*spots[0])
    first_stamp = mover.reload.clock_started_at

    travel 5.seconds do
      engine.build_settlement(*spots[1])
    end

    assert_equal first_stamp, mover.reload.clock_started_at
  end

  test "record_move does not stamp clock_started_at for an untimed game" do
    force_hand("G")
    spot = empty_hexes_of("G", 1).first

    @engine.build_settlement(*spot)

    assert_nil @game.current_player.reload.clock_started_at
  end

  test "end_turn deducts elapsed time from the mover and credits the increment" do
    game, engine = start_timed_game("blitz")
    mover = game.current_player
    base = Time.current
    mover.update!(clock_started_at: base, time_remaining_ms: 100_000)
    game.update!(turn_started_at: base)
    force_hand("G", game: game)
    empty_hexes_of("G", 3, game: game).each { |spot| engine.build_settlement(*spot) }

    travel_to(base + 20.seconds, with_usec: true) { engine.end_turn }

    expected = 100_000 - 20_000 + Game::SPEEDS["blitz"][:increment_ms]
    assert_equal expected, mover.reload.time_remaining_ms
  end

  test "end_turn allows the bank to go negative once elapsed time exceeds it" do
    game, engine = start_timed_game("blitz")
    mover = game.current_player
    base = Time.current
    mover.update!(clock_started_at: base, time_remaining_ms: 5_000)
    game.update!(turn_started_at: base)
    force_hand("G", game: game)
    empty_hexes_of("G", 3, game: game).each { |spot| engine.build_settlement(*spot) }

    travel_to(base + 60.seconds, with_usec: true) { engine.end_turn }

    assert_operator mover.reload.time_remaining_ms, :<, 0
  end

  test "end_turn caps the credited bank at the speed's initial amount" do
    game, engine = start_timed_game("blitz")
    mover = game.current_player
    base = Time.current
    mover.update!(clock_started_at: base, time_remaining_ms: Game::SPEEDS["blitz"][:bank_ms])
    game.update!(turn_started_at: base)
    force_hand("G", game: game)
    empty_hexes_of("G", 3, game: game).each { |spot| engine.build_settlement(*spot) }

    # No time elapses; the increment alone would exceed the bank if uncapped.
    travel_to(base, with_usec: true) { engine.end_turn }

    assert_equal Game::SPEEDS["blitz"][:bank_ms], mover.reload.time_remaining_ms
  end

  test "end_turn does not deduct when the mover has not made a deliberate move yet" do
    game, engine = start_timed_game("blitz")
    mover = game.current_player
    base = Time.current
    mover.update!(time_remaining_ms: 50_000, clock_started_at: nil)
    game.update!(turn_started_at: base, mandatory_count: 0)

    travel_to(base + 30.seconds, with_usec: true) { engine.end_turn }

    assert_equal 50_000 + Game::SPEEDS["blitz"][:increment_ms], mover.reload.time_remaining_ms
  end

  test "end_turn's deduction window starts at clock_started_at when it falls mid-turn" do
    game, engine = start_timed_game("blitz")
    mover = game.current_player
    turn_start = Time.current
    game.update!(turn_started_at: turn_start)
    mover.update!(time_remaining_ms: 100_000, clock_started_at: nil)
    force_hand("G", game: game)
    spots = empty_hexes_of("G", 3, game: game)

    clock_start = turn_start + 15.seconds
    travel_to(clock_start, with_usec: true) { engine.build_settlement(*spots[0]) }
    engine.build_settlement(*spots[1])
    engine.build_settlement(*spots[2])

    travel_to(clock_start + 10.seconds, with_usec: true) { engine.end_turn }

    expected = 100_000 - 10_000 + Game::SPEEDS["blitz"][:increment_ms]
    assert_equal expected, mover.reload.time_remaining_ms
  end

  test "end_turn stamps turn_started_at to the moment the turn changes" do
    game, engine = start_timed_game("blitz")
    force_hand("G", game: game)
    empty_hexes_of("G", 3, game: game).each { |spot| engine.build_settlement(*spot) }

    travel_to(Time.current + 5.seconds, with_usec: true) do
      engine.end_turn
      assert_in_delta Time.current, game.reload.turn_started_at, 0.001
    end
  end

  def force_hand(terrain, game: @game)
    game.current_player.update!(hand: [ terrain ])
  end

  def empty_hexes_of(terrain, n, game: @game)
    game.instantiate
    spots = []
    20.times do |row|
      20.times do |col|
        next unless game.board.terrain_at(row, col) == terrain
        next unless game.board_contents.empty?(row, col)
        spots << [ row, col ]
        return spots if spots.size >= n
      end
    end
    spots
  end

  def start_timed_game(speed)
    game = Game.create!(state: "waiting", speed: speed)
    game.add_player(users(:chris))
    game.add_player(users(:paula))
    game.start
    game.reload
    [ game, TurnEngine.new(game) ]
  end

  def valid_meeple_destination(tile_klass)
    @game.instantiate
    tile = Tiles::Tile.for_klass(tile_klass).new(0)
    tile.valid_destinations(
      board_contents: with_terrain(@game.board_contents, @game.board),
      player_order: @game.current_player.order,
      supply: @game.current_player.supply_hash
    )
  end
end

class TurnEngineCompletedGameTest < ActiveSupport::TestCase
  test "buildable_cells returns empty array for a completed game" do
    game = games(:game2player)
    game.update!(state: "completed", mandatory_count: 3, current_action: { "type" => "mandatory" })
    engine = TurnEngine.new(game)

    assert_equal [], engine.buildable_cells
  end
end
