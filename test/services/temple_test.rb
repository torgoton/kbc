require "test_helper"

class TempleTest < ActiveSupport::TestCase
  def setup
    @game = games(:game2player)
    @game.boards = [ [ 1, 0 ], [ 5, 0 ], [ 0, 0 ], [ 4, 0 ] ] # board 1 row 0: G at cols 7-9, row 1: G at 8-9
    @game.board_contents = BoardState.new.tap { |s| s.place_settlement(0, 7, game_players(:chris).order) }
    @game.mandatory_count = Game::MANDATORY_COUNT
    @game.save!
    @chris = game_players(:chris)
    @chris.update!(hand: [ "G" ], supply: { "settlements" => 10 }, tiles: [ { "klass" => "TempleTile", "used" => false, "from" => "[7, 5]" } ])
  end

  def engine = TurnEngine.new(@game)

  def build(row, col)
    TurnEngine.new(@game).click(Coordinate.new(row, col))
    @game.reload
    @chris.reload
  end

  test "using Temple sets a settlement aside, outside the supply" do
    engine.select_action("temple")
    assert_equal "temple", @game.reload.turn_phase.type
    engine.click(Coordinate.new(0, 7))
    @game.reload
    @chris.reload

    assert_not_equal @chris.order, @game.board_contents.player_at(0, 7)
    assert_equal 1, @chris.set_aside_count
    assert_equal 10, @chris.settlements_remaining
    assert @chris.tiles.first["used"]
    assert_equal "mandatory", @game.turn_phase.type
  end

  def set_aside
    engine.select_action("temple")
    engine.click(Coordinate.new(0, 7))
    @game.reload
    @chris.reload
  end

  test "end_turn makes the next player's set-aside pieces extra mandatory builds, outside their supply" do
    paula = game_players(:paula)
    paula.update!(supply: { "settlements" => 10, "set_aside" => 2 })
    @game.update!(current_player: @chris)

    engine.end_turn
    @game.reload
    paula.reload

    assert_equal paula, @game.current_player
    assert_equal Game::MANDATORY_COUNT + 2, @game.mandatory_count
    assert_equal 10, paula.settlements_remaining # set-aside settlements stay out of the supply
    assert_equal 2, paula.temple_due
    assert_equal 0, paula.set_aside_count
  end

  test "a Temple piece returned to an empty supply can be built, and building it triggers the ending" do
    @chris.update!(supply: { "settlements" => 0, "temple_due" => 1 })
    @game.update!(mandatory_count: 1)

    assert @game.can_build_mandatory?(@chris)
    build(0, 8)
    assert_equal 0, @chris.settlements_remaining
    assert_equal 1, @game.end_trigger_count
    assert TurnEngine.new(@game).turn_endable?
  end

  test "the game end waits while a piece is set aside" do
    @chris.update!(supply: { "settlements" => 1, "set_aside" => 1 })
    @game.update!(mandatory_count: 1)

    build(0, 8)
    assert_equal 0, @game.end_trigger_count
  end

  test "Temple after building the last settlement withdraws that player's ending trigger" do
    @chris.update!(supply: { "settlements" => 0 })
    @game.update!(end_trigger_count: 1, mandatory_count: 0)

    set_aside
    assert_equal 1, @chris.set_aside_count
    assert_equal 0, @game.end_trigger_count
  end

  test "Temple does not withdraw another player's ending trigger" do
    @game.update!(end_trigger_count: 1)

    set_aside
    assert_equal 1, @game.end_trigger_count
  end

  test "with a Temple piece, only the first 3 mandatory builds count for Families" do
    @game.update!(goals: [ "families" ], mandatory_count: Game::MANDATORY_COUNT + 1, board_contents: BoardState.new)
    @chris.update!(supply: { "settlements" => 10, "temple_due" => 1 })

    build(1, 9)
    build(0, 9)
    build(0, 8)
    build(0, 7) # (0,7) (0,8) (0,9) are a line, but this is the 4th build
    assert_nil @chris.bonus_scores&.dig("families")
  end

  test "the build message says how many of the mandatory settlements come from Temple" do
    @chris.update!(supply: { "settlements" => 10, "temple_due" => 2 })
    @game.update!(mandatory_count: Game::MANDATORY_COUNT + 2)
    assert_match(/must build 5 settlements on Grass \(2 from Temple\)/, engine.turn_state)

    @game.update!(mandatory_count: 1)
    assert_match(/must build 1 settlement on Grass \(1 from Temple\)/, engine.turn_state)

    @chris.update!(supply: { "settlements" => 10 })
    @game.reload.update!(mandatory_count: Game::MANDATORY_COUNT)
    assert_match(/must build 3 settlements on Grass/, engine.turn_state)
  end

  test "a dual card lists each terrain with its own count" do
    @chris.update!(hand: [ "DB" ], supply: { "settlements" => 10, "temple_due" => 1 })
    @game.update!(mandatory_count: Game::MANDATORY_COUNT + 1)
    assert_match(/Chris must build 4 settlements on Desert, 3 settlements on Swamp \(1 from Temple\)/, engine.turn_state)
  end

  test "a Crossroads pair of dual cards groups the non-Swamp terrains" do
    @chris.update!(hand: [ "GB", "TB" ], tiles: [ { "klass" => "TempleTile", "used" => false, "from" => "[7, 5]" } ])
    assert_equal "Chris must build 3 settlements on Grass or Timberland, 2 settlements on Swamp, or select a tile", engine.turn_state
  end

  test "a set-aside settlement is not in the supply, so a tile cannot build with it" do
    @chris.update!(supply: { "settlements" => 0, "temple_due" => 1 },
                   tiles: [ { "klass" => "OasisTile", "used" => false, "from" => "[7, 5]" } ])
    @game.update!(mandatory_count: Game::MANDATORY_COUNT + 1)
    assert_not TurnEngine.new(@game.reload).tile_actionable?(@chris.reload.tiles.first)

    @chris.update!(supply: { "settlements" => 1, "temple_due" => 1 })
    assert TurnEngine.new(@game.reload).tile_actionable?(@chris.reload.tiles.first)
  end

  test "Temple builds follow the regular builds on the terrain they used" do
    @chris.update!(hand: [ "GT" ], supply: { "settlements" => 10, "temple_due" => 1 })
    @game.update!(mandatory_count: Game::MANDATORY_COUNT + 1)

    build(0, 8) # Grass locks the terrain
    build(0, 9)
    build(1, 9)
    assert_equal 1, @game.mandatory_count
    assert_equal "G", @game.turn_phase.chosen_terrain
  end

  test "Temple records which piece was set aside, in order" do
    @game.board_contents = BoardState.new.tap do |s|
      s.place_wagon(0, 7, @chris.order)
      s.place_settlement(0, 8, @chris.order)
    end
    @game.save!
    @chris.update!(tiles: 2.times.map { { "klass" => "TempleTile", "used" => false, "from" => "[7, 5]" } })

    [ [ 0, 7 ], [ 0, 8 ] ].each do |r, c|
      engine.select_action("temple")
      engine.click(Coordinate.new(r, c))
    end
    @chris.reload

    assert_equal %w[wagon settlement], @chris.supply["set_aside"]
    assert_equal 0, @chris.wagons_remaining
  end

  test "a set-aside wagon returns as a pending wagon, not in the supply" do
    paula = game_players(:paula)
    paula.update!(supply: { "settlements" => 10, "set_aside" => %w[wagon settlement] })
    @game.update!(current_player: @chris)

    engine.end_turn
    paula.reload

    assert_equal 10, paula.settlements_remaining
    assert_equal 0, paula.wagons_remaining
    assert_equal %w[wagon settlement], paula.supply["temple_due"]
    assert_equal Game::MANDATORY_COUNT + 2, @game.reload.mandatory_count
  end

  test "with no choice made, the earliest set-aside piece is built first, after the regular builds" do
    @chris.update!(supply: { "settlements" => 10, "temple_due" => %w[settlement wagon] })
    assert_equal [ nil, nil, nil, "settlement", "settlement" ],
      (Game::MANDATORY_COUNT + 2).downto(1).map { |n| @chris.next_temple_piece(n) }
  end

  test "a Temple wagon is built on the played terrain next to your settlements, without using a settlement" do
    @chris.update!(supply: { "settlements" => 3, "temple_due" => %w[wagon] })
    @game.update!(mandatory_count: Game::MANDATORY_COUNT + 1)

    build(0, 8)
    build(0, 9)
    build(1, 9)
    assert_equal 0, @chris.settlements_remaining
    assert_not @game.board_contents.wagon_at?(1, 9)
    assert_equal 1, @game.end_trigger_count # the settlement supply is empty; the owed wagon is not a settlement
    assert @game.can_build_mandatory?(@chris)
    assert_not_includes engine.legal_targets, [ 0, 7 ] # occupied
    assert_includes engine.legal_targets, [ 1, 8 ]
    assert engine.legal_targets.all? { |r, c| @game.board_contents.terrain_at(r, c) == "G" } # played terrain

    build(1, 8)
    assert @game.board_contents.wagon_at?(1, 8)
    assert_equal 0, @chris.settlements_remaining
    assert_equal 0, @game.mandatory_count
  end

  test "the Wagon tile cannot place a wagon that Temple still owes" do
    @chris.update!(supply: { "settlements" => 10, "temple_due" => %w[wagon] },
                   tiles: [ { "klass" => "WagonTile", "used" => false, "from" => "[7, 5]" } ])
    @game.update!(mandatory_count: Game::MANDATORY_COUNT + 1)
    assert_not TurnEngine.new(@game.reload).tile_actionable?(@chris.reload.tiles.first)
  end

  test "Temple records ships and warriors as their own pieces" do
    @game.board_contents = BoardState.new.tap do |s|
      s.place_ship(0, 4, @chris.order)
      s.place_warrior(0, 8, @chris.order)
    end
    @game.save!
    @chris.update!(tiles: 2.times.map { { "klass" => "TempleTile", "used" => false, "from" => "[7, 5]" } })

    [ [ 0, 4 ], [ 0, 8 ] ].each do |r, c|
      engine.select_action("temple")
      engine.click(Coordinate.new(r, c))
    end

    assert_equal %w[ship warrior], @chris.reload.supply["set_aside"]
  end

  test "a Temple ship is built like any mandatory build: played terrain, next to your settlements" do
    @chris.update!(supply: { "settlements" => 3, "temple_due" => %w[ship] })
    @game.update!(mandatory_count: Game::MANDATORY_COUNT + 1)

    build(0, 8)
    build(0, 9)
    build(1, 9)
    assert_includes engine.legal_targets, [ 1, 8 ]
    assert engine.legal_targets.all? { |r, c| @game.board_contents.terrain_at(r, c) == "G" }

    build(1, 8)
    assert @game.board_contents.ship_at?(1, 8)
    assert_equal 0, @game.mandatory_count
  end

  test "a Temple warrior is built on the played terrain next to your settlements" do
    @chris.update!(supply: { "settlements" => 3, "temple_due" => %w[warrior] })
    @game.update!(mandatory_count: Game::MANDATORY_COUNT + 1)

    build(0, 8)
    build(0, 9)
    build(1, 9)
    assert_includes engine.legal_targets, [ 1, 8 ]
    build(1, 8)
    assert @game.board_contents.warrior_at?(1, 8)
    assert_equal 0, @game.mandatory_count
  end

  test "undoing an owed Temple build puts the piece back to be built again" do
    @chris.update!(supply: { "settlements" => 3, "temple_due" => %w[settlement wagon] })
    @game.update!(mandatory_count: Game::MANDATORY_COUNT + 2)

    build(0, 8)
    build(0, 9)
    build(1, 9)
    build(1, 8) # owed settlement
    build(2, 9) # owed wagon
    assert @game.board_contents.wagon_at?(2, 9)

    2.times do
      engine.undo_last_move
      @game.reload
      @chris.reload
    end
    assert_not @game.board_contents.wagon_at?(2, 9)
    assert_nil @game.board_contents.player_at(1, 8)
    assert_equal 2, @game.mandatory_count
    assert_equal 0, @chris.settlements_remaining
    assert_equal %w[settlement wagon], @chris.supply["temple_due"]
    assert_equal "settlement", @chris.next_temple_piece(@game.mandatory_count)

    build(1, 8)
    build(2, 9)
    assert @game.board_contents.wagon_at?(2, 9)
  end

  test "owed pieces are still built when the supply runs out during the regular builds" do
    @chris.update!(supply: { "settlements" => 1, "temple_due" => %w[wagon] })
    @game.update!(mandatory_count: Game::MANDATORY_COUNT + 1)

    build(0, 8) # the last settlement; the other 2 regular builds are not possible
    assert_equal 1, @game.mandatory_count
    assert @game.can_build_mandatory?(@chris)
    assert_not engine.turn_endable?

    build(0, 9)
    assert @game.board_contents.wagon_at?(0, 9)
    assert_equal 0, @game.mandatory_count
  end

  test "owed pieces are still owed at the start of a turn with an empty supply" do
    paula = game_players(:paula)
    paula.update!(supply: { "settlements" => 0, "set_aside" => %w[wagon] })
    @game.update!(current_player: @chris)

    engine.end_turn

    assert_equal 1, @game.reload.mandatory_count
    assert @game.can_build_mandatory?(paula.reload)
  end

  test "locking Swamp costs no build when only owed Temple pieces remain" do
    @chris.update!(hand: [ "GB" ], supply: { "settlements" => 0, "temple_due" => %w[wagon] })
    @game.update!(mandatory_count: 1)
    @game.instantiate
    engine = TurnEngine.new(@game)

    engine.lock_terrain!("B", nil)

    assert_equal 1, @game.mandatory_count
  end

  test "locking Swamp still costs a regular build while regular builds remain" do
    @chris.update!(hand: [ "GB" ], supply: { "settlements" => 5, "temple_due" => %w[wagon] })
    @game.update!(mandatory_count: Game::MANDATORY_COUNT + 1)
    @game.instantiate
    TurnEngine.new(@game).lock_terrain!("B", nil)

    assert_equal Game::MANDATORY_COUNT, @game.mandatory_count
  end

  test "with an empty supply and owed pieces, a tile can still move pieces before the mandatory action" do
    paula = game_players(:paula)
    @game.board_contents = BoardState.new.tap { |s| s.place_settlement(0, 7, paula.order) }
    @game.save!
    paula.update!(supply: { "settlements" => 0, "set_aside" => %w[wagon] },
                  tiles: [ { "klass" => "PaddockTile", "used" => false, "from" => "[7, 5]" } ])
    @game.update!(current_player: @chris)

    engine.end_turn
    @game.reload

    assert_equal 1, @game.mandatory_count
    assert TurnEngine.new(@game).tile_actionable?(paula.reload.tiles.first)
  end

  test "Mayors takes only from the supply, so an owed settlement still holds the ending off" do
    @game.update!(goals: [ "mayors" ], mandatory_count: Game::MANDATORY_COUNT + 1,
                  board_contents: BoardState.new.tap { |s| [ 5, 6, 7 ].each { |c| s.place_settlement(0, c, @chris.order) } })
    @chris.update!(supply: { "settlements" => 2, "temple_due" => %w[settlement] })

    build(0, 8) # 4 on row 0: Mayors takes the last supply settlement

    assert_equal [ 0 ], @chris.supply["mayors"]
    assert_equal 0, @chris.settlements_remaining
    assert_equal 0, @game.end_trigger_count
    assert @game.can_build_mandatory?(@chris)
  end

  test "with different owed pieces left, you may build them in any order" do
    @chris.update!(supply: { "settlements" => 3, "temple_due" => %w[settlement wagon] })
    @game.update!(mandatory_count: Game::MANDATORY_COUNT + 2)

    build(0, 8)
    build(0, 9)
    build(1, 9)
    assert_equal %w[settlement wagon], engine.temple_piece_choices

    assert_nil engine.choose_temple_piece("wagon")
    build(1, 8)
    assert @game.board_contents.wagon_at?(1, 8)
    assert_equal %w[settlement], engine.temple_piece_choices

    build(2, 9)
    assert_equal @chris.order, @game.board_contents.player_at(2, 9)
    assert_not @game.board_contents.wagon_at?(2, 9)
    assert_equal 0, @game.mandatory_count
  end

  test "identical owed pieces need no choice, and a piece that is not owed cannot be chosen" do
    @chris.update!(supply: { "settlements" => 3, "temple_due" => %w[ship ship] })
    @game.update!(mandatory_count: Game::MANDATORY_COUNT + 2)
    build(0, 8)
    build(0, 9)
    build(1, 9)

    assert_equal %w[ship], engine.temple_piece_choices
    assert_equal "Not available", engine.choose_temple_piece("wagon")
  end

  test "owed pieces cannot be chosen while regular builds remain" do
    @chris.update!(supply: { "settlements" => 3, "temple_due" => %w[settlement wagon] })
    @game.update!(mandatory_count: Game::MANDATORY_COUNT + 2)

    assert_empty engine.temple_piece_choices
    assert_equal "Not available", engine.choose_temple_piece("wagon")
  end

  test "undo takes back the choice of piece" do
    @chris.update!(supply: { "settlements" => 3, "temple_due" => %w[settlement wagon] })
    @game.update!(mandatory_count: Game::MANDATORY_COUNT + 2)
    build(0, 8)
    build(0, 9)
    build(1, 9)

    engine.choose_temple_piece("wagon")
    engine.undo_last_move
    @game.reload
    @chris.reload

    assert_equal "settlement", @chris.next_temple_piece(@game.mandatory_count)
  end

  def mayors_row_of_three
    @game.update!(goals: [ "mayors" ], board_contents: BoardState.new.tap { |s| [ 5, 6, 7 ].each { |c| s.place_settlement(0, c, @chris.order) } })
  end

  test "Mayors cannot be claimed with an empty supply, even with owed settlements" do
    mayors_row_of_three
    @chris.update!(supply: { "settlements" => 1, "temple_due" => %w[settlement] })
    @game.update!(mandatory_count: Game::MANDATORY_COUNT + 1)

    build(0, 8) # last supply settlement: 4 in a row, but the marker needs a supply settlement of its own
    assert_nil @chris.supply["mayors"]
  end

  test "Mayors cannot be claimed by building an owed piece" do
    mayors_row_of_three
    @chris.update!(supply: { "settlements" => 0, "temple_due" => %w[settlement] })
    @game.update!(mandatory_count: 1)

    build(0, 8)
    assert_nil @chris.supply["mayors"]
  end

  test "Mayors cannot be claimed with an empty supply and a piece set aside this turn" do
    mayors_row_of_three
    @chris.update!(supply: { "settlements" => 1, "set_aside" => %w[settlement] })
    @game.update!(mandatory_count: 1)

    build(0, 8)
    assert_nil @chris.supply["mayors"]
  end

  test "claiming Mayors with the last supply settlement ends the game only once the owed settlements are built" do
    mayors_row_of_three
    @chris.update!(supply: { "settlements" => 2, "temple_due" => %w[settlement] })
    @game.update!(mandatory_count: Game::MANDATORY_COUNT + 1)

    build(0, 8)
    assert_equal [ 0 ], @chris.supply["mayors"]
    assert_equal 0, @game.end_trigger_count

    build(0, 9) # the owed settlement
    assert_equal 1, @game.end_trigger_count
  end

  test "owed meeples do not delay the end of the game" do
    mayors_row_of_three
    @chris.update!(supply: { "settlements" => 2, "temple_due" => %w[wagon] })
    @game.update!(mandatory_count: Game::MANDATORY_COUNT + 1)

    build(0, 8)
    assert_equal [ 0 ], @chris.supply["mayors"]
    assert_equal 1, @game.end_trigger_count
  end

  test "a meeple set aside this turn does not delay the end of the game" do
    @chris.update!(supply: { "settlements" => 1, "set_aside" => %w[wagon] })
    @game.update!(mandatory_count: 1)

    build(0, 8)
    assert_equal 1, @game.end_trigger_count
  end

  test "setting aside a meeple does not withdraw the ending trigger" do
    @game.update!(end_trigger_count: 1, mandatory_count: 0,
                  board_contents: BoardState.new.tap { |s| s.place_wagon(0, 7, @chris.order) })
    @chris.update!(supply: { "settlements" => 0 })

    set_aside
    assert_equal 1, @game.end_trigger_count
  end

  test "Temple needs a settlement that is not part of a City Hall" do
    tile = Tiles::Location::TempleTile.new(0)
    assert_not tile.activatable?(player_order: @chris.order, board_contents: BoardState.new)
    assert tile.activatable?(player_order: @chris.order, board_contents: @game.board_contents)
  end
end
