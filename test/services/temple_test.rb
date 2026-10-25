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

  test "end_turn puts the next player's set-aside pieces into their supply as extra mandatory builds" do
    paula = game_players(:paula)
    paula.update!(supply: { "settlements" => 10, "set_aside" => 2 })
    @game.update!(current_player: @chris)

    engine.end_turn
    @game.reload
    paula.reload

    assert_equal paula, @game.current_player
    assert_equal Game::MANDATORY_COUNT + 2, @game.mandatory_count
    assert_equal 12, paula.settlements_remaining
    assert_equal 2, paula.temple_due
    assert_equal 0, paula.set_aside_count
  end

  test "a Temple piece returned to an empty supply can be built, and building it triggers the ending" do
    @chris.update!(supply: { "settlements" => 1, "temple_due" => 1 })
    @game.update!(mandatory_count: Game::MANDATORY_COUNT + 1)

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

  test "with a Temple piece, any 3 of the mandatory builds in a line score Families, once" do
    @game.update!(goals: [ "families" ], mandatory_count: Game::MANDATORY_COUNT + 1, board_contents: BoardState.new)
    @chris.update!(supply: { "settlements" => 10, "temple_due" => 1 })

    build(1, 9)
    build(0, 9)
    build(0, 8)
    assert_nil @chris.bonus_scores&.dig("families"), "the first 3 are not in a line"

    build(0, 7)
    assert_equal 2, @chris.bonus_scores["families"], "(0,7) (0,8) (0,9) are"
  end

  test "Families scores once even when a later build makes another line" do
    @game.update!(goals: [ "families" ], mandatory_count: Game::MANDATORY_COUNT + 2, board_contents: BoardState.new)
    @chris.update!(supply: { "settlements" => 10, "temple_due" => 2 })

    build(0, 7)
    build(0, 8)
    build(0, 9)
    assert_equal 2, @chris.bonus_scores["families"]

    build(1, 8)
    build(2, 9)
    assert TurnEngine.new(@game).send(:straight_line?, [ [ 0, 8 ], [ 1, 8 ], [ 2, 9 ] ]), "a second line"
    assert_equal 2, @chris.bonus_scores["families"]
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

  test "Temple needs a settlement that is not part of a City Hall" do
    tile = Tiles::Location::TempleTile.new(0)
    assert_not tile.activatable?(player_order: @chris.order, board_contents: BoardState.new)
    assert tile.activatable?(player_order: @chris.order, board_contents: @game.board_contents)
  end
end
