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

  test "the next turn has an extra mandatory build that does not use supply" do
    @chris.update!(supply: { "settlements" => 10, "temple_due" => 1 })
    @game.update!(mandatory_count: 4)

    build(0, 8)
    build(0, 9)
    build(1, 8)
    assert_equal 7, @chris.settlements_remaining
    assert @game.temple_build_next?(@chris)

    build(1, 9)
    assert_equal 7, @chris.settlements_remaining, "temple piece is not taken from supply"
    assert_equal 0, @game.mandatory_count
  end

  test "end_turn turns the next player's set-aside pieces into extra mandatory builds" do
    paula = game_players(:paula)
    paula.update!(supply: { "settlements" => 10, "set_aside" => 2 })
    @game.update!(current_player: @chris)

    engine.end_turn
    @game.reload
    paula.reload

    assert_equal paula, @game.current_player
    assert_equal Game::MANDATORY_COUNT + 2, @game.mandatory_count
    assert_equal 2, paula.temple_due
    assert_equal 0, paula.set_aside_count
  end

  test "the game end waits for Temple pieces that are still due" do
    @chris.update!(supply: { "settlements" => 1, "temple_due" => 1 })
    @game.update!(mandatory_count: 2)

    build(0, 8)
    assert_equal 0, @game.end_trigger_count, "a piece is still due"

    build(0, 9)
    assert_equal 1, @game.end_trigger_count, "ending triggers once nothing is pending"
  end

  test "the game end waits while a piece is set aside" do
    @chris.update!(supply: { "settlements" => 1, "set_aside" => 1 })
    @game.update!(mandatory_count: 1)

    build(0, 8)
    assert_equal 0, @game.end_trigger_count
  end

  test "Temple needs a settlement that is not part of a City Hall" do
    tile = Tiles::Location::TempleTile.new(0)
    assert_not tile.activatable?(player_order: @chris.order, board_contents: BoardState.new)
    assert tile.activatable?(player_order: @chris.order, board_contents: @game.board_contents)
  end
end
