require "test_helper"

class Tiles::MonasteryTileTest < ActiveSupport::TestCase
  # Boards [1,0],[5,0],[0,0],[4,0]: Oasis (rows 0-9, cols 0-9).
  # Canyon hexes include (0,2),(1,1),(5,6),(5,7),(5,9),(6,2),(6,6),(6,7),(6,9),(7,2),(7,8),(8,2).
  # Settlement at (5,5): board 1 row 5 "WTTWGGCCDC" col 5 = G; adjacent C at (5,6) and (6,6).
  # Settlement at (0,7): board 1 row 0 "DDCWWTTGGG" col 7 = G; no adjacent C — fallback applies.

  def setup_board
    game = games(:game2player)
    chris = game_players(:chris)
    game.boards = [ [ 1, 0 ], [ 5, 0 ], [ 0, 0 ], [ 4, 0 ] ]
    state = BoardState.new.tap { |s| s.place_settlement(5, 5, chris.order) }
    yield state if block_given?
    game.board_contents = state
    game.save
    game.instantiate
    { board_contents: game.board_contents, board: game.board, chris: chris }
  end

  test "valid_destinations returns adjacent Canyon hexes when available" do
    ctx = setup_board
    tile = Tiles::MonasteryTile.new(0)

    result = tile.valid_destinations(board_contents: ctx[:board_contents], board: ctx[:board], player_order: ctx[:chris].order)

    assert_includes result, [ 5, 6 ], "Canyon hex adjacent to settlement must be included"
    result.each do |r, c|
      assert_equal "C", ctx[:board].terrain_at(r, c), "every destination must be Canyon"
    end
  end

  test "valid_destinations excludes occupied Canyon hexes" do
    ctx = setup_board { |s| s.place_settlement(5, 6, 1) }
    tile = Tiles::MonasteryTile.new(0)

    result = tile.valid_destinations(board_contents: ctx[:board_contents], board: ctx[:board], player_order: ctx[:chris].order)

    assert_not_includes result, [ 5, 6 ], "occupied Canyon hex must be excluded"
  end

  test "valid_destinations falls back to any empty Canyon when no adjacent Canyon exists" do
    game = games(:game2player)
    chris = game_players(:chris)
    game.boards = [ [ 1, 0 ], [ 5, 0 ], [ 0, 0 ], [ 4, 0 ] ]
    # Settlement at (0,7): all neighbors are T/G — no adjacent Canyon
    game.board_contents = BoardState.new.tap { |s| s.place_settlement(0, 7, chris.order) }
    game.save
    game.instantiate
    tile = Tiles::MonasteryTile.new(0)

    result = tile.valid_destinations(board_contents: game.board_contents, board: game.board, player_order: chris.order)

    assert_includes result, [ 0, 2 ], "fallback must include non-adjacent Canyon hex"
    assert_includes result, [ 5, 6 ], "fallback must include distant Canyon hex"
    assert_not_includes result, [ 0, 7 ], "settlement cell must not appear"
    result.each do |r, c|
      assert_equal "C", game.board.terrain_at(r, c), "every fallback destination must be Canyon"
    end
  end

  test "valid_destinations returns empty when all Canyon hexes are occupied" do
    canyon_hexes = [
      # Oasis (board 1, rows 0-9, cols 0-9)
      [ 0, 2 ], [ 1, 1 ], [ 5, 6 ], [ 5, 7 ], [ 5, 9 ], [ 6, 2 ], [ 6, 6 ], [ 6, 7 ], [ 6, 9 ], [ 7, 2 ], [ 7, 8 ], [ 8, 2 ],
      # Paddock (board 5, rows 0-9, cols 10-19)
      [ 0, 10 ], [ 0, 11 ], [ 0, 12 ], [ 1, 12 ], [ 2, 12 ], [ 3, 11 ],
      [ 4, 10 ], [ 4, 11 ], [ 4, 17 ], [ 5, 10 ], [ 5, 14 ], [ 5, 15 ], [ 5, 16 ], [ 6, 10 ],
      # Farm (board 0, rows 10-19, cols 0-9)
      [ 10, 2 ], [ 11, 2 ], [ 12, 0 ], [ 12, 1 ], [ 12, 2 ], [ 12, 7 ],
      [ 13, 0 ], [ 13, 1 ], [ 13, 7 ], [ 13, 8 ], [ 14, 0 ], [ 14, 8 ], [ 14, 9 ], [ 15, 9 ],
      # Tavern (board 4, rows 10-19, cols 10-19)
      [ 10, 17 ], [ 10, 18 ], [ 10, 19 ], [ 11, 17 ], [ 11, 18 ], [ 11, 19 ],
      [ 14, 19 ], [ 15, 11 ], [ 15, 12 ], [ 15, 17 ], [ 15, 18 ], [ 15, 19 ],
      [ 16, 13 ], [ 16, 18 ], [ 17, 12 ]
    ]
    game = games(:game2player)
    chris = game_players(:chris)
    game.boards = [ [ 1, 0 ], [ 5, 0 ], [ 0, 0 ], [ 4, 0 ] ]
    game.board_contents = BoardState.new.tap do |s|
      canyon_hexes.each { |r, c| s.place_settlement(r, c, 1) }
      s.place_settlement(0, 7, chris.order)
    end
    game.save
    game.instantiate
    tile = Tiles::MonasteryTile.new(0)

    result = tile.valid_destinations(board_contents: game.board_contents, board: game.board, player_order: chris.order)

    assert_empty result
  end

  # --- build_terrain ---

  test "build_terrain returns C" do
    assert_equal "C", Tiles::MonasteryTile.new(0).build_terrain
  end

  # --- from_hash ---

  test "from_hash returns a MonasteryTile" do
    assert_instance_of Tiles::MonasteryTile, Tiles::Tile.from_hash("klass" => "MonasteryTile")
  end

  # --- activatable? ---

  test "activatable? is true when Canyon hexes are reachable" do
    ctx = setup_board
    tile = Tiles::MonasteryTile.new(0)
    assert tile.activatable?(player_order: ctx[:chris].order, board_contents: ctx[:board_contents], board: ctx[:board])
  end

  test "activatable? is false when all Canyon hexes are occupied" do
    canyon_hexes = [
      [ 0, 2 ], [ 1, 1 ], [ 5, 6 ], [ 5, 7 ], [ 5, 9 ], [ 6, 2 ], [ 6, 6 ], [ 6, 7 ], [ 6, 9 ], [ 7, 2 ], [ 7, 8 ], [ 8, 2 ],
      [ 0, 10 ], [ 0, 11 ], [ 0, 12 ], [ 1, 12 ], [ 2, 12 ], [ 3, 11 ],
      [ 4, 10 ], [ 4, 11 ], [ 4, 17 ], [ 5, 10 ], [ 5, 14 ], [ 5, 15 ], [ 5, 16 ], [ 6, 10 ],
      [ 10, 2 ], [ 11, 2 ], [ 12, 0 ], [ 12, 1 ], [ 12, 2 ], [ 12, 7 ],
      [ 13, 0 ], [ 13, 1 ], [ 13, 7 ], [ 13, 8 ], [ 14, 0 ], [ 14, 8 ], [ 14, 9 ], [ 15, 9 ],
      [ 10, 17 ], [ 10, 18 ], [ 10, 19 ], [ 11, 17 ], [ 11, 18 ], [ 11, 19 ],
      [ 14, 19 ], [ 15, 11 ], [ 15, 12 ], [ 15, 17 ], [ 15, 18 ], [ 15, 19 ],
      [ 16, 13 ], [ 16, 18 ], [ 17, 12 ]
    ]
    game = games(:game2player)
    chris = game_players(:chris)
    game.boards = [ [ 1, 0 ], [ 5, 0 ], [ 0, 0 ], [ 4, 0 ] ]
    game.board_contents = BoardState.new.tap do |s|
      canyon_hexes.each { |r, c| s.place_settlement(r, c, 1) }
      s.place_settlement(0, 7, chris.order)
    end
    game.save
    game.instantiate
    tile = Tiles::MonasteryTile.new(0)
    assert_not tile.activatable?(player_order: chris.order, board_contents: game.board_contents, board: game.board)
  end

  test "builds_settlement? returns true" do
    assert Tiles::MonasteryTile.new(0).builds_settlement?
  end
end
