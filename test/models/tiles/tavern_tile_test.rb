require "test_helper"

class Tiles::TavernTileTest < ActiveSupport::TestCase
  # Board layout: [Oasis(0), Paddock(1), Farm(2), Tavern(3)]
  # FarmBoard rows 10-19, cols 0-9; TavernBoard rows 10-19, cols 10-19.
  #
  # Horizontal (E/W) line on FarmBoard row 12 (even, local row 2: "CCCFFFTCFF"):
  #   C@(12,0) C@(12,1) C@(12,2) F@(12,3) F@(12,4) F@(12,5) T@(12,6)
  #
  # Diagonal (NE/SW) line: settlements (15,5)→(14,6)→(13,6)
  #   NE steps: odd[-1,+1], even[-1,0]. SW extension (16,5)=F; NE extension (12,7)=C
  #
  # Water-end line on FarmBoard row 13 (odd, local row 3: "CCFFWDDCCF"):
  #   settlements (13,5),(13,6),(13,7) = D,D,C
  #   W extension (13,4)=W (excluded); E extension (13,8)=C (included)

  def game_with_boards
    game = games(:game2player)
    game.boards = [ [ "Oasis", 0 ], [ "Paddock", 0 ], [ "Farm", 0 ], [ "Tavern", 0 ] ]
    game
  end

  def setup_game(settlements)
    game = game_with_boards
    chris = game_players(:chris)
    game.board_contents = BoardState.new.tap do |s|
      settlements.each { |r, c| s.place_settlement(r, c, chris.order) }
    end
    game.save
    game.instantiate
    { game: game, chris: chris }
  end

  # --- valid_destinations ---

  test "valid_destinations returns empty when no 3-in-a-row exists" do
    ctx = setup_game([ [ 12, 1 ], [ 12, 2 ] ])
    tile = Tiles::TavernTile.new(0)

    result = tile.valid_destinations(
      board_contents: ctx[:game].board_contents,
      board: ctx[:game].board,
      player_order: ctx[:chris].order
    )

    assert_empty result
  end

  test "valid_destinations returns both ends for a horizontal 3-in-a-row" do
    ctx = setup_game([ [ 12, 1 ], [ 12, 2 ], [ 12, 3 ] ])
    tile = Tiles::TavernTile.new(0)

    result = tile.valid_destinations(
      board_contents: ctx[:game].board_contents,
      board: ctx[:game].board,
      player_order: ctx[:chris].order
    )

    assert_includes result, [ 12, 0 ], "W end must be included"
    assert_includes result, [ 12, 4 ], "E end must be included"
  end

  test "valid_destinations returns both ends for a diagonal 3-in-a-row" do
    # NE line: (15,5)→(14,6)→(13,6); SW extension=(16,5)=F; NE extension=(12,7)=C
    ctx = setup_game([ [ 15, 5 ], [ 14, 6 ], [ 13, 6 ] ])
    tile = Tiles::TavernTile.new(0)

    result = tile.valid_destinations(
      board_contents: ctx[:game].board_contents,
      board: ctx[:game].board,
      player_order: ctx[:chris].order
    )

    assert_includes result, [ 16, 5 ], "SW extension must be included"
    assert_includes result, [ 12, 7 ], "NE extension must be included"
  end

  test "valid_destinations excludes water extensions" do
    # Row 13 (odd): D@(13,5) D@(13,6) C@(13,7); W ext=(13,4)=W; E ext=(13,8)=C
    ctx = setup_game([ [ 13, 5 ], [ 13, 6 ], [ 13, 7 ] ])
    tile = Tiles::TavernTile.new(0)

    result = tile.valid_destinations(
      board_contents: ctx[:game].board_contents,
      board: ctx[:game].board,
      player_order: ctx[:chris].order
    )

    assert_not_includes result, [ 13, 4 ], "water extension must be excluded"
    assert_includes result, [ 13, 8 ],     "buildable extension must be included"
  end

  test "valid_destinations excludes occupied extensions" do
    # 3-in-a-row at (12,1-3); block the W extension (12,0)
    game = game_with_boards
    chris = game_players(:chris)
    game.board_contents = BoardState.new.tap do |s|
      [ [ 12, 1 ], [ 12, 2 ], [ 12, 3 ] ].each { |r, c| s.place_settlement(r, c, chris.order) }
      s.place_settlement(12, 0, 1)   # opponent blocks W end
    end
    game.save
    game.instantiate
    tile = Tiles::TavernTile.new(0)

    result = tile.valid_destinations(
      board_contents: game.board_contents,
      board: game.board,
      player_order: chris.order
    )

    assert_not_includes result, [ 12, 0 ], "occupied extension must be excluded"
    assert_includes result,     [ 12, 4 ], "free extension must be included"
  end

  test "valid_destinations for a 4-in-a-row returns only the two outer ends" do
    # (12,0-3): W extension out of bounds; E extension (12,4)=F
    ctx = setup_game([ [ 12, 0 ], [ 12, 1 ], [ 12, 2 ], [ 12, 3 ] ])
    tile = Tiles::TavernTile.new(0)

    result = tile.valid_destinations(
      board_contents: ctx[:game].board_contents,
      board: ctx[:game].board,
      player_order: ctx[:chris].order
    )

    assert_includes result,     [ 12, 4 ], "E outer end must be included"
    assert_not_includes result, [ 12, 1 ], "interior hex must not be included"
    assert_not_includes result, [ 12, 2 ], "interior hex must not be included"
  end

  # --- activatable? ---

  test "activatable? is true when a qualifying line exists" do
    ctx = setup_game([ [ 12, 1 ], [ 12, 2 ], [ 12, 3 ] ])
    tile = Tiles::TavernTile.new(0)
    assert tile.activatable?(
      player_order: ctx[:chris].order,
      board_contents: ctx[:game].board_contents,
      board: ctx[:game].board
    )
  end

  test "activatable? is false when no qualifying line exists" do
    ctx = setup_game([ [ 12, 1 ], [ 12, 2 ] ])
    tile = Tiles::TavernTile.new(0)
    assert_not tile.activatable?(
      player_order: ctx[:chris].order,
      board_contents: ctx[:game].board_contents,
      board: ctx[:game].board
    )
  end

  # --- from_hash ---

  test "from_hash returns a TavernTile" do
    assert_instance_of Tiles::TavernTile, Tiles::Tile.from_hash("klass" => "TavernTile")
  end
end
