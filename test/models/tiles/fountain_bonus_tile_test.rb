require "test_helper"

class Tiles::FountainBonusTileTest < ActiveSupport::TestCase
  # Board 1 (Oasis): (0,5) is Timberland, (1,2) is Water... use a Mountain from board 2: row 5 "MMCGGWWWDD".
  def setup
    @game = games(:game2player)
    @game.boards = [ [ 2, 0 ], [ 5, 0 ], [ 0, 0 ], [ 4, 0 ] ] # board 2 row 5: (5,0)=M, (5,1)=M, (5,2)=C
    @chris = game_players(:chris)
    @game.board_contents = BoardState.new.tap { |s| s.place_settlement(5, 2, @chris.order) }
    @game.save!
  end

  def fountain_destinations(tiles)
    @chris.update!(tiles: tiles)
    @game.instantiate
    Tiles::Location::FountainTile.new(0).with_player(@chris)
      .valid_destinations(board_contents: @game.board_contents, player_order: @chris.order)
  end

  test "without the bonus tile Mountain is not buildable by Fountain" do
    assert_not_includes fountain_destinations([]), [ 5, 1 ]
  end

  test "with an unused bonus tile Fountain can build on Mountain" do
    assert_includes fountain_destinations([ { "klass" => "FountainBonusTile", "used" => false } ]), [ 5, 1 ]
  end

  test "a bonus tile acquired this turn (used) does not apply until the next turn" do
    assert_not_includes fountain_destinations([ { "klass" => "FountainBonusTile", "used" => true } ]), [ 5, 1 ]
  end

  test "the bonus tile is never selectable and is not forfeited" do
    assert_not Tiles::Bonus::FountainBonusTile.new(0).activatable?(player_order: 0, board_contents: BoardState.new)
    assert_equal "bonus", Tiles::Bonus::FountainBonusTile.new(0).tile_category
  end

  test "collecting the 2nd Fountain awards the bonus tile, once" do
    @game.board_contents = BoardState.new.tap do |s|
      s.place_tile(5, 3, "FountainTile", 2)
      s.place_tile(7, 3, "FountainTile", 2)
      s.place_settlement(5, 2, @chris.order)
    end
    @game.mandatory_count = 3
    @game.save!
    @chris.update!(hand: [ "G" ], tiles: [ { "klass" => "FountainTile", "used" => false, "from" => "[7, 3]" } ], taken_from: [ "[7, 3]" ])
    engine = TurnEngine.new(@game)

    engine.click(Coordinate.new(5, 4)) # Grass next to the Fountain at (5,3)
    @chris.reload

    assert_equal 2, @chris.tiles.count { |t| t["klass"] == "FountainTile" }
    bonus = @chris.tiles.select { |t| t["klass"] == "FountainBonusTile" }
    assert_equal 1, bonus.size
    assert_nil bonus.first["from"]
    assert bonus.first["used"], "acquired this turn, so inactive until the next"
  end

  test "the first Fountain alone awards nothing" do
    @game.board_contents = BoardState.new.tap do |s|
      s.place_tile(5, 3, "FountainTile", 2)
      s.place_settlement(5, 2, @chris.order)
    end
    @game.mandatory_count = 3
    @game.save!
    @chris.update!(hand: [ "G" ], tiles: [])
    TurnEngine.new(@game).click(Coordinate.new(5, 4))

    assert_empty @chris.reload.tiles.select { |t| t["klass"] == "FountainBonusTile" }
  end

  test "the Fountain action offers Mountain with the bonus tile and builds there" do
    @game.mandatory_count = 3
    @game.save!
    @chris.update!(hand: [ "G" ], tiles: [
      { "klass" => "FountainTile", "used" => false, "from" => "[5, 3]" },
      { "klass" => "FountainBonusTile", "used" => false }
    ])
    engine = TurnEngine.new(@game)

    engine.select_action("fountain")
    @game.reload
    assert_includes engine.legal_targets, [ 5, 1 ]
    engine.click(Coordinate.new(5, 1))

    assert_equal @chris.order, @game.reload.board_contents.player_at(5, 1)
  end
end
