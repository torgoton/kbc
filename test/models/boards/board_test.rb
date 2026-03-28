require "test_helper"

class BoardTest < ActiveSupport::TestCase
  GameStub = Struct.new(:boards, :board_contents)

  def game_with_boards(*names)
    contents = BoardState.new
    GameStub.new(names.map { |n| [ n, 0 ] }, contents)
  end

  test "terrain_at delegates to the correct section based on row/col quadrant" do
    # Sections: 0=Farm (rows 0-9, cols 0-9), 1=Oasis (rows 0-9, cols 10-19),
    #           2=Paddock (rows 10-19, cols 0-9), 3=Tavern (rows 10-19, cols 10-19)
    board = Boards::Board.new(game_with_boards("Farm", "Oasis", "Paddock", "Tavern"))

    assert_equal "D", board.terrain_at(0, 0)   # Farm row 0: "DDCWWTTTGG"
    assert_equal "D", board.terrain_at(0, 10)  # Oasis row 0: "DDCWWTTGGG"
    assert_equal "C", board.terrain_at(10, 0)  # Paddock row 0: "CCCDDWDDDD"
    assert_equal "F", board.terrain_at(10, 10) # Tavern row 0: "FDDMMDDCCC"
  end

  test "terrain_at uses local coordinates within each section" do
    board = Boards::Board.new(game_with_boards("Farm", "Oasis", "Paddock", "Tavern"))

    # Farm section 0: local (1,7) = "L"; global (1,7)
    assert_equal "L", board.terrain_at(1, 7)
    # Oasis section 1: local (2,7) = "L"; global (2, 10+7=17)
    assert_equal "L", board.terrain_at(2, 17)
    # Paddock section 2: local (2,8) = "L"; global (10+2=12, 8)
    assert_equal "L", board.terrain_at(12, 8)
    # Tavern section 3: local (6,2) = "L"; global (10+6=16, 10+2=12)
    assert_equal "L", board.terrain_at(16, 12)
  end

  test "Board.new raises ArgumentError for unknown board type" do
    assert_raises(ArgumentError) { Boards::Board.new(game_with_boards("Swamp")) }
  end

  test "Board.new creates a Tile object for a valid tile class in board contents" do
    contents = BoardState.new
    contents.place_tile(0, 0, "OasisTile", 2)
    game = GameStub.new([], contents)
    board = Boards::Board.new(game)
    assert_instance_of Tiles::OasisTile, board.content_at(0, 0)
  end

  test "Board.new raises ArgumentError for unknown tile class in board contents" do
    contents = BoardState.new
    contents.place_tile(0, 0, "GoblinTile", 2)
    game = GameStub.new([], contents)
    assert_raises(ArgumentError) { Boards::Board.new(game) }
  end
end
