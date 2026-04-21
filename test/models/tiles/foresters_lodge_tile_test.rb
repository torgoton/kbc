require "test_helper"

class Tiles::ForestersLodgeTileTest < ActiveSupport::TestCase
  # Boards [1,0],[5,0],[0,0],[4,0]: Oasis (rows 0-9, cols 0-9).
  # Timberland hexes include (0,5),(0,6),(1,5),(1,6),(1,7),(2,5),(2,6),(3,5),(5,1),(5,2),(6,1),(6,3).
  # Settlement at (2,4): board 1 row 2 "DDWFFTTLFG" col 4 = F; adjacent T at (2,5).
  # Settlement at (4,4): board 1 row 4 "WWWWGGGGFF" col 4 = G; no adjacent T — fallback applies.

  def setup_board
    game = games(:game2player)
    chris = game_players(:chris)
    game.boards = [ [ 1, 0 ], [ 5, 0 ], [ 0, 0 ], [ 4, 0 ] ]
    state = BoardState.new.tap { |s| s.place_settlement(2, 4, chris.order) }
    yield state if block_given?
    game.board_contents = state
    game.save
    game.instantiate
    { board_contents: game.board_contents, board: game.board, chris: chris }
  end

  test "valid_destinations returns adjacent Timberland hexes when available" do
    ctx = setup_board
    tile = Tiles::ForestersLodgeTile.new(0)

    result = tile.valid_destinations(board_contents: ctx[:board_contents], board: ctx[:board], player_order: ctx[:chris].order)

    assert_includes result, [ 2, 5 ], "Timberland hex adjacent to settlement must be included"
    result.each do |r, c|
      assert_equal "T", ctx[:board].terrain_at(r, c), "every destination must be Timberland"
    end
  end

  test "valid_destinations excludes occupied Timberland hexes" do
    ctx = setup_board { |s| s.place_settlement(2, 5, 1) }
    tile = Tiles::ForestersLodgeTile.new(0)

    result = tile.valid_destinations(board_contents: ctx[:board_contents], board: ctx[:board], player_order: ctx[:chris].order)

    assert_not_includes result, [ 2, 5 ], "occupied Timberland hex must be excluded"
  end

  test "valid_destinations falls back to any empty Timberland when no adjacent Timberland exists" do
    game = games(:game2player)
    chris = game_players(:chris)
    game.boards = [ [ 1, 0 ], [ 5, 0 ], [ 0, 0 ], [ 4, 0 ] ]
    # Settlement at (4,4): all neighbors are W/F/G — no adjacent Timberland
    game.board_contents = BoardState.new.tap { |s| s.place_settlement(4, 4, chris.order) }
    game.save
    game.instantiate
    tile = Tiles::ForestersLodgeTile.new(0)

    result = tile.valid_destinations(board_contents: game.board_contents, board: game.board, player_order: chris.order)

    assert_includes result, [ 0, 5 ], "fallback must include non-adjacent Timberland hex"
    assert_includes result, [ 6, 1 ], "fallback must include distant Timberland hex"
    assert_not_includes result, [ 4, 4 ], "settlement cell must not appear"
    result.each do |r, c|
      assert_equal "T", game.board.terrain_at(r, c), "every fallback destination must be Timberland"
    end
  end

  test "valid_destinations returns empty when all Timberland hexes are occupied" do
    timberland_hexes = [
      # Oasis (board 1, rows 0-9, cols 0-9)
      [ 0, 5 ], [ 0, 6 ], [ 1, 5 ], [ 1, 6 ], [ 1, 7 ], [ 2, 5 ], [ 2, 6 ], [ 3, 5 ], [ 5, 1 ], [ 5, 2 ], [ 6, 1 ], [ 6, 3 ],
      # Paddock (board 5, rows 0-9, cols 10-19)
      [ 4, 12 ], [ 4, 13 ], [ 5, 11 ], [ 5, 12 ], [ 6, 12 ], [ 6, 13 ], [ 7, 12 ], [ 7, 19 ],
      [ 8, 12 ], [ 8, 13 ], [ 8, 19 ], [ 9, 12 ], [ 9, 13 ], [ 9, 18 ], [ 9, 19 ],
      # Farm (board 0, rows 10-19, cols 0-9)
      [ 10, 5 ], [ 10, 6 ], [ 10, 7 ], [ 11, 4 ], [ 11, 5 ], [ 11, 6 ], [ 12, 6 ],
      [ 16, 3 ], [ 17, 2 ], [ 17, 3 ], [ 18, 2 ], [ 18, 3 ], [ 19, 0 ], [ 19, 1 ], [ 19, 2 ],
      # Tavern (board 4, rows 10-19, cols 10-19)
      [ 13, 16 ], [ 13, 17 ], [ 14, 17 ], [ 14, 18 ], [ 15, 15 ], [ 15, 16 ],
      [ 16, 15 ], [ 16, 16 ], [ 17, 14 ], [ 17, 15 ], [ 18, 14 ], [ 18, 15 ], [ 18, 16 ],
      [ 19, 14 ], [ 19, 15 ], [ 19, 16 ]
    ]
    game = games(:game2player)
    chris = game_players(:chris)
    game.boards = [ [ 1, 0 ], [ 5, 0 ], [ 0, 0 ], [ 4, 0 ] ]
    game.board_contents = BoardState.new.tap do |s|
      timberland_hexes.each { |r, c| s.place_settlement(r, c, 1) }
      s.place_settlement(4, 4, chris.order)
    end
    game.save
    game.instantiate
    tile = Tiles::ForestersLodgeTile.new(0)

    result = tile.valid_destinations(board_contents: game.board_contents, board: game.board, player_order: chris.order)

    assert_empty result
  end

  # --- build_terrain ---

  test "build_terrain returns T" do
    assert_equal "T", Tiles::ForestersLodgeTile.new(0).build_terrain
  end

  # --- from_hash ---

  test "from_hash returns a ForestersLodgeTile" do
    assert_instance_of Tiles::ForestersLodgeTile, Tiles::Tile.from_hash("klass" => "ForestersLodgeTile")
  end

  # --- activatable? ---

  test "activatable? is true when Timberland hexes are reachable" do
    ctx = setup_board
    tile = Tiles::ForestersLodgeTile.new(0)
    assert tile.activatable?(player_order: ctx[:chris].order, board_contents: ctx[:board_contents], board: ctx[:board])
  end

  test "activatable? is false when all Timberland hexes are occupied" do
    timberland_hexes = [
      [ 0, 5 ], [ 0, 6 ], [ 1, 5 ], [ 1, 6 ], [ 1, 7 ], [ 2, 5 ], [ 2, 6 ], [ 3, 5 ], [ 5, 1 ], [ 5, 2 ], [ 6, 1 ], [ 6, 3 ],
      [ 4, 12 ], [ 4, 13 ], [ 5, 11 ], [ 5, 12 ], [ 6, 12 ], [ 6, 13 ], [ 7, 12 ], [ 7, 19 ],
      [ 8, 12 ], [ 8, 13 ], [ 8, 19 ], [ 9, 12 ], [ 9, 13 ], [ 9, 18 ], [ 9, 19 ],
      [ 10, 5 ], [ 10, 6 ], [ 10, 7 ], [ 11, 4 ], [ 11, 5 ], [ 11, 6 ], [ 12, 6 ],
      [ 16, 3 ], [ 17, 2 ], [ 17, 3 ], [ 18, 2 ], [ 18, 3 ], [ 19, 0 ], [ 19, 1 ], [ 19, 2 ],
      [ 13, 16 ], [ 13, 17 ], [ 14, 17 ], [ 14, 18 ], [ 15, 15 ], [ 15, 16 ],
      [ 16, 15 ], [ 16, 16 ], [ 17, 14 ], [ 17, 15 ], [ 18, 14 ], [ 18, 15 ], [ 18, 16 ],
      [ 19, 14 ], [ 19, 15 ], [ 19, 16 ]
    ]
    game = games(:game2player)
    chris = game_players(:chris)
    game.boards = [ [ 1, 0 ], [ 5, 0 ], [ 0, 0 ], [ 4, 0 ] ]
    game.board_contents = BoardState.new.tap do |s|
      timberland_hexes.each { |r, c| s.place_settlement(r, c, 1) }
      s.place_settlement(4, 4, chris.order)
    end
    game.save
    game.instantiate
    tile = Tiles::ForestersLodgeTile.new(0)
    assert_not tile.activatable?(player_order: chris.order, board_contents: game.board_contents, board: game.board)
  end

  test "builds_settlement? returns true" do
    assert Tiles::ForestersLodgeTile.new(0).builds_settlement?
  end
end
