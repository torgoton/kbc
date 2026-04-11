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

  test "build_settlement returns 'No settlements left' when supply is exhausted" do
    force_hand("G")
    @game.current_player.update!(supply: { "settlements" => 0 })

    result = @engine.build_settlement(*empty_hexes_of("G", 1).first)

    assert_equal "No settlements left", result
  end

  test "build_settlement returns 'Not avilalable' when location not adjacent to existing settlements" do
    # Place a settlement at a Canyon hex in Tavern board, then try to build
    # at a far-away Canyon hex that cannot be adjacent
    @game.boards = [ [ "Tavern", 0 ], [ "Paddock", 0 ], [ "Oasis", 0 ], [ "Farm", 0 ] ]
    @game.save
    @game.instantiate
    player = @game.current_player
    @game.board_contents_will_change!
    @game.board_contents.place_settlement(0, 7, player.order)
    @game.save

    game2 = Game.find(@game.id)
    game2.current_player.update!(hand: "C")
    engine2 = TurnEngine.new(game2)

    # (5,1) is Canyon on Tavern board row 5 ("FCCWGTTCCC"), not adjacent to (0,7)
    result = engine2.build_settlement(5, 1)

    assert_equal "Not available", result
  end

  test "build_settlement uses neighbor adjacency when player has an existing settlement" do
    # Place a settlement at a Canyon hex, then build on an adjacent Canyon hex
    # Tavern board has Canyon at (0,7) and (0,8) — pin it to quadrant 0
    @game.boards = [ [ "Tavern", 0 ], [ "Paddock", 0 ], [ "Oasis", 0 ], [ "Farm", 0 ] ]
    @game.save
    @game.instantiate
    player = @game.current_player
    @game.board_contents_will_change!
    @game.board_contents.place_settlement(0, 7, player.order)
    @game.save

    game2 = Game.find(@game.id)
    game2.current_player.update!(hand: "C")
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
    @game.current_player.update!(tiles: [
      { "klass" => "MandatoryTile", "used" => false },
      { "klass" => "OasisTile", "from" => "[2, 7]", "used" => false }
    ])
    @game.update!(current_action: { "type" => "oasis" })

    # (3, 3) is the Castle scoring hex on Tavern — not Desert, so not in valid_destinations
    result = @engine.activate_tile_build(3, 3)

    assert_equal "Not available", result
  end

  test "turn_state returns paddock message when current_action is paddock" do
    @game.update!(current_action: { "type" => "paddock" })

    assert_match(/must move a settlement/, @engine.turn_state)
  end

  test "turn_state returns oasis message when current_action is oasis" do
    @game.update!(current_action: { "type" => "oasis" })

    assert_match(/must build on a Desert space/, @engine.turn_state)
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

  test "undo reverses a select_action: current_action resets to mandatory" do
    @engine.select_action("paddock")
    assert_equal "paddock", @game.reload.current_action["type"]

    @engine.undo_last_move
    @game.reload

    assert_equal "mandatory", @game.current_action["type"]
    assert_equal 0, @game.moves.count
  end

  test "undo reverses a select_settlement: removes 'from' from current_action" do
    @game.update!(current_action: { "type" => "paddock" })
    @engine.select_settlement(5, 5)
    assert_equal "[5, 5]", @game.reload.current_action["from"]

    @engine.undo_last_move
    @game.reload

    assert_nil @game.current_action["from"]
    assert_equal 0, @game.moves.count
  end

  test "end_turn creates an end_game move when the last player ends and game is ending" do
    paula = @game.game_players.find { |gp| gp.order == 1 }
    @game.update!(current_player: paula, ending: true, mandatory_count: 0)

    @engine.end_turn

    end_game_move = @game.moves.find_by(action: "end_game")
    assert end_game_move, "expected an end_game move to be created"
    assert_not end_game_move.deliberate
    assert_not end_game_move.reversible
    assert_equal paula, end_game_move.game_player
  end

  test "tile_activatable? returns false for a used tile" do
    tile = { "klass" => "OasisTile", "from" => "[2, 7]", "used" => true }

    assert_not @engine.tile_activatable?(tile)
  end

  test "tile_activatable? returns false for an unknown tile class" do
    tile = { "klass" => "BogusNonExistentTile", "from" => "[0, 0]", "used" => false }

    assert_not @engine.tile_activatable?(tile)
  end

  test "tile_activatable? returns false when mandatory builds are partially complete" do
    @game.update!(mandatory_count: 1)
    tile = { "klass" => "OasisTile", "from" => "[2, 7]", "used" => false }

    assert_not @engine.tile_activatable?(tile)
  end

  test "tile_activatable? returns false when a tile action is already in progress" do
    @game.update!(current_action: { "type" => "oasis" }, mandatory_count: 0)
    tile = { "klass" => "OasisTile", "from" => "[2, 7]", "used" => false }

    assert_not @engine.tile_activatable?(tile)
  end

  test "tile_activatable? returns false for a building tile when player has no settlements left" do
    @game.current_player.update!(supply: { "settlements" => 0 })
    @game.update!(mandatory_count: 0)
    tile = { "klass" => "OasisTile", "from" => "[2, 7]", "used" => false }

    assert_not @engine.tile_activatable?(tile)
  end

  test "PaddockTile#builds_settlement? returns false" do
    assert_not Tiles::PaddockTile.new(0).builds_settlement?
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
    expected = Tiles::PaddockTile.new(0).valid_destinations(
      from_row: spot[0], from_col: spot[1],
      board_contents: @game.board_contents, board: @game.board
    )
    assert_equal expected.sort, cells.sort
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

  test "buildable_cells for barn without from returns selectable settlements" do
    @game.boards = [ [ "Barn", 0 ], [ "Paddock", 0 ], [ "Farm", 0 ], [ "Tavern", 0 ] ]
    @game.update!(current_action: { "type" => "barn" }, mandatory_count: 0)
    @game.current_player.update!(
      hand: "F",
      tiles: [ { "klass" => "BarnTile", "from" => "[2, 6]", "used" => false } ]
    )
    # Place a settlement on F terrain with adjacent F terrain available
    @game.instantiate
    @game.board_contents.place_settlement(0, 0, @game.current_player.order)
    @game.save!
    @game.reload

    cells = @engine.buildable_cells

    assert cells.any?
    @game.instantiate
    player_settlements = @game.board_contents.settlements_for(@game.current_player.order).to_a
    cells.each { |r, c| assert_includes player_settlements, [ r, c ] }
  end

  test "move_settlement for barn action marks BarnTile used" do
    @game.boards = [ [ "Barn", 0 ], [ "Paddock", 0 ], [ "Farm", 0 ], [ "Tavern", 0 ] ]
    @game.update!(current_action: { "type" => "barn", "from" => "[0, 0]" })
    @game.current_player.update!(
      hand: "F",
      tiles: [ { "klass" => "BarnTile", "from" => "[2, 6]", "used" => false } ]
    )
    @game.instantiate
    order = @game.current_player.order
    # Settlement at (2,5) stays adjacent to tile location (2,6) so BarnTile won't forfeit
    @game.board_contents.place_settlement(2, 5, order)
    @game.board_contents.place_settlement(0, 0, order)
    @game.save!
    @game.reload

    @engine.move_settlement(1, 0)
    @game.current_player.reload

    barn_tile = @game.current_player.tiles.find { |t| t["klass"] == "BarnTile" }
    assert barn_tile["used"], "BarnTile must be marked used after move"
  end

  test "buildable_cells for barn with from returns matching terrain destinations" do
    @game.boards = [ [ "Barn", 0 ], [ "Paddock", 0 ], [ "Farm", 0 ], [ "Tavern", 0 ] ]
    @game.update!(current_action: { "type" => "barn", "from" => "[0, 0]" }, mandatory_count: 0)
    @game.current_player.update!(
      hand: "F",
      tiles: [ { "klass" => "BarnTile", "from" => "[2, 6]", "used" => false } ]
    )
    @game.instantiate
    @game.board_contents.place_settlement(0, 0, @game.current_player.order)
    @game.save!
    @game.reload

    cells = @engine.buildable_cells

    assert cells.any?
    @game.instantiate
    cells.each do |r, c|
      assert_equal "F", @game.board.terrain_at(r, c)
      assert @game.board_contents.empty?(r, c)
    end
  end

  test "turn_state returns barn message when current_action is barn" do
    @game.update!(current_action: { "type" => "barn" })
    @game.current_player.update!(hand: "G")

    assert_match(/must move a settlement to a Grass space/, @engine.turn_state)
  end

  test "turn_state returns oracle message when current_action is oracle" do
    @game.update!(current_action: { "type" => "oracle" })
    @game.current_player.update!(hand: "G")

    assert_match(/must build on a Grass space/, @engine.turn_state)
  end

  test "buildable_cells for oracle action returns hand-terrain hexes" do
    @game.boards = [ [ "Oracle", 0 ], [ "Paddock", 0 ], [ "Farm", 0 ], [ "Tavern", 0 ] ]
    @game.update!(current_action: { "type" => "oracle" }, mandatory_count: 0)
    @game.current_player.update!(
      hand: "G",
      tiles: [ { "klass" => "OracleTile", "from" => "[3, 7]", "used" => false } ]
    )
    @game.reload

    cells = @engine.buildable_cells

    assert cells.any?
    @game.instantiate
    cells.each do |r, c|
      assert_equal "G", @game.board.terrain_at(r, c)
      assert @game.board_contents.empty?(r, c)
    end
  end

  # ── Real-time goals ─────────────────────────────────────────────────────────

  # Helper: fresh game object from DB with Oasis boards and clean board_contents
  def fresh_oasis_game(goals:, board_contents: BoardState.new, mandatory_count: 3)
    @game.boards = [ [ "Oasis", 0 ], [ "Paddock", 0 ], [ "Farm", 0 ], [ "Tavern", 0 ] ]
    @game.goals = goals
    @game.board_contents = board_contents
    @game.mandatory_count = mandatory_count
    @game.save!
    Game.find(@game.id)
  end

  test "Ambassadors: scores 1 point when building adjacent to opponent settlement" do
    # OasisBoard row 0: "DDCWWTTGGG" — (0,0)=D, (0,1)=D
    # Place opponent at (0,0), current player builds at adjacent (0,1)
    game = fresh_oasis_game(goals: [ "ambassadors" ])
    opponent = game.game_players.find { |gp| gp.order != game.current_player.order }
    game.board_contents_will_change!
    game.board_contents.place_settlement(0, 0, opponent.order)
    game.save!
    game2 = Game.find(game.id)
    game2.current_player.update!(hand: "D")
    engine = TurnEngine.new(game2)

    engine.build_settlement(0, 1)

    game2.current_player.reload
    assert_equal 1, game2.current_player.bonus_scores&.dig("ambassadors")
    assert game2.moves.exists?(action: "score_goal", deliberate: false)
  end

  test "Ambassadors: does not score when building with no adjacent opponent" do
    # (0,0)=D on OasisBoard; no opponent neighbors
    game = fresh_oasis_game(goals: [ "ambassadors" ])
    game.current_player.update!(hand: "D")
    engine = TurnEngine.new(game)

    engine.build_settlement(0, 0)

    game.current_player.reload
    assert_equal 0, game.current_player.bonus_scores&.dig("ambassadors").to_i
  end

  test "Ambassadors: does not score when goal is not active" do
    game = fresh_oasis_game(goals: [])
    opponent = game.game_players.find { |gp| gp.order != game.current_player.order }
    game.board_contents_will_change!
    game.board_contents.place_settlement(0, 0, opponent.order)
    game.save!
    game2 = Game.find(game.id)
    game2.current_player.update!(hand: "D")
    engine = TurnEngine.new(game2)

    engine.build_settlement(0, 1)

    game2.current_player.reload
    assert_equal 0, game2.current_player.bonus_scores&.dig("ambassadors").to_i
    assert_not game2.moves.exists?(action: "score_goal")
  end

  test "Shepherds: scores 2 points when no adjacent empty same-terrain exists" do
    # OasisBoard row 8: "WWCFWWWDDW", row 9: "WWWWWWWWWW"
    # (9,0) even-row in-board neighbors of (9,0): (8,0)=W, (8,1)=W, (9,1)=W
    # Fill those with player settlements so no adjacent empty W hex remains at (9,0).
    game = fresh_oasis_game(goals: [ "shepherds" ])
    player_order = game.current_player.order
    game.board_contents_will_change!
    game.board_contents.place_settlement(8, 0, player_order)
    game.board_contents.place_settlement(8, 1, player_order)
    game.board_contents.place_settlement(9, 1, player_order)
    game.save!
    game2 = Game.find(game.id)
    game2.current_player.update!(hand: "W", supply: { "settlements" => 40 })
    engine = TurnEngine.new(game2)

    engine.build_settlement(9, 0)

    game2.current_player.reload
    assert_equal 2, game2.current_player.bonus_scores&.dig("shepherds")
  end

  test "Shepherds: does not score when adjacent empty same-terrain exists" do
    # (0,0)=D on OasisBoard; (0,1)=D is adjacent and empty
    game = fresh_oasis_game(goals: [ "shepherds" ])
    game.current_player.update!(hand: "D")
    engine = TurnEngine.new(game)

    engine.build_settlement(0, 0)

    game.current_player.reload
    assert_equal 0, game.current_player.bonus_scores&.dig("shepherds").to_i
  end

  test "Families: scores 2 points when 3 mandatory builds form a straight line" do
    # OasisBoard row 0: "DDCWWTTGGG" — G at (0,7),(0,8),(0,9)
    # Even-row E direction: (0,7)->(0,8)->(0,9) is a straight line.
    game = fresh_oasis_game(goals: [ "families" ], mandatory_count: 3)
    game.current_player.update!(hand: "G")
    engine = TurnEngine.new(game)

    engine.build_settlement(0, 7)
    game2 = Game.find(game.id)
    game2.current_player.update!(hand: "G")
    engine2 = TurnEngine.new(game2)
    engine2.build_settlement(0, 8)
    game3 = Game.find(game.id)
    game3.current_player.update!(hand: "G")
    engine3 = TurnEngine.new(game3)
    engine3.build_settlement(0, 9)

    game3.current_player.reload
    assert_equal 2, game3.current_player.bonus_scores&.dig("families")
  end

  test "Families: does not score when 3 mandatory builds do not form a straight line" do
    # OasisBoard row 0: "DDCWWTTGGG", row 1: "DCWFFTTTGG"
    # (0,7)=G, (0,8)=G, (1,8)=G — (1,8) is SE of (0,8), not E, so (0,7),(0,8),(1,8) is not a line.
    game = fresh_oasis_game(goals: [ "families" ], mandatory_count: 3)
    game.current_player.update!(hand: "G")
    engine = TurnEngine.new(game)

    engine.build_settlement(0, 7)
    game2 = Game.find(game.id)
    game2.current_player.update!(hand: "G")
    engine2 = TurnEngine.new(game2)
    engine2.build_settlement(0, 8)
    game3 = Game.find(game.id)
    game3.current_player.update!(hand: "G")
    engine3 = TurnEngine.new(game3)
    engine3.build_settlement(1, 8)

    game3.current_player.reload
    assert_equal 0, game3.current_player.bonus_scores&.dig("families").to_i
  end

  test "Families: does not score when goal is not active" do
    # Same positions as the straight-line test but no families goal
    game = fresh_oasis_game(goals: [], mandatory_count: 3)
    game.current_player.update!(hand: "G")
    engine = TurnEngine.new(game)

    engine.build_settlement(0, 7)
    game2 = Game.find(game.id)
    game2.current_player.update!(hand: "G")
    engine2 = TurnEngine.new(game2)
    engine2.build_settlement(0, 8)
    game3 = Game.find(game.id)
    game3.current_player.update!(hand: "G")
    engine3 = TurnEngine.new(game3)
    engine3.build_settlement(0, 9)

    game3.current_player.reload
    assert_equal 0, game3.current_player.bonus_scores&.dig("families").to_i
    assert_not game3.moves.exists?(action: "score_goal")
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

  # ---------------------------------------------------------------------------
  # activate_outpost
  # ---------------------------------------------------------------------------

  test "activate_outpost sets outpost_active, marks tile used, and logs a move" do
    force_hand("G")
    @game.current_player.update!(tiles: [
      { "klass" => "MandatoryTile", "used" => false },
      { "klass" => "OutpostTile", "from" => "[3, 3]", "used" => false }
    ])

    @engine.activate_outpost
    @game.reload

    assert @game.current_action["outpost_active"]
    outpost = @game.current_player.tiles.find { |t| t["klass"] == "OutpostTile" }
    assert outpost["used"]
    assert_equal 1, @game.moves.count
    assert_equal "activate_outpost", @game.moves.last.action
  end

  test "buildable_cells with outpost_active returns all terrain cells, not just adjacent" do
    force_hand("G")
    spot = empty_hexes_of("G", 1).first
    @engine.build_settlement(*spot)
    @game.reload
    @game.current_player.update!(tiles: [
      { "klass" => "MandatoryTile", "used" => false },
      { "klass" => "OutpostTile", "from" => "[3, 3]", "used" => false }
    ])
    @engine.activate_outpost
    @game.reload

    cells = TurnEngine.new(@game).buildable_cells

    @game.instantiate
    all_empty_grass = (0..19).flat_map { |r| (0..19).filter_map { |c| [ r, c ] if @game.board_contents.empty?(r, c) && @game.board.terrain_at(r, c) == "G" } }
    assert_equal all_empty_grass.sort, cells.sort
  end

  test "undo of activate_outpost clears outpost_active and marks tile unused" do
    force_hand("G")
    player = @game.current_player
    player.update!(tiles: [
      { "klass" => "MandatoryTile", "used" => false },
      { "klass" => "OutpostTile", "from" => "[3, 3]", "used" => false }
    ])

    @engine.activate_outpost
    @game.reload
    assert @game.current_action["outpost_active"]

    @engine.undo_last_move
    @game.reload

    assert_nil @game.current_action["outpost_active"]
    outpost = @game.current_player.tiles.find { |t| t["klass"] == "OutpostTile" }
    assert_equal false, outpost["used"]
    assert_equal 0, @game.moves.count
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

class TurnEngineCompletedGameTest < ActiveSupport::TestCase
  test "buildable_cells returns empty array for a completed game" do
    game = games(:game2player)
    game.update!(state: "completed", mandatory_count: 3, current_action: { "type" => "mandatory" })
    engine = TurnEngine.new(game)

    assert_equal [], engine.buildable_cells
  end
end
