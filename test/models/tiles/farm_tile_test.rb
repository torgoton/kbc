require "test_helper"

class Tiles::FarmTileTest < ActiveSupport::TestCase
  # FarmBoard is at index 2: rows 10-19, cols 0-9.
  # Grass hexes include: (14,1),(14,2),(15,0),(15,1),(16,0-2),(17,0-1),(18,0)
  # Settlement at (14,0) = C terrain: adjacent Grass hexes are (14,1) and (15,0).
  # Settlement at (12,0) = C terrain: all neighbors are C/D — no adjacent Grass; fallback applies.

  def setup_board
    game = games(:game2player)
    chris = game_players(:chris)
    game.boards = [ [ 1, 0 ], [ 5, 0 ], [ 0, 0 ], [ 4, 0 ] ]
    state = BoardState.new.tap { |s| s.place_settlement(14, 0, chris.order) }
    yield state if block_given?
    game.board_contents = state
    game.save
    game.instantiate
    { board_contents: game.board_contents, board: game.board, chris: chris }
  end

  test "valid_destinations returns adjacent Grass hexes when available" do
    ctx = setup_board
    tile = Tiles::FarmTile.new(0)

    result = tile.valid_destinations(board_contents: ctx[:board_contents], board: ctx[:board], player_order: ctx[:chris].order)

    assert_includes result, [ 14, 1 ], "Grass hex adjacent to settlement must be included"
    assert_includes result, [ 15, 0 ], "Grass hex adjacent to settlement must be included"
    result.each do |r, c|
      assert_equal "G", ctx[:board].terrain_at(r, c), "every destination must be Grass"
    end
  end

  test "valid_destinations excludes occupied Grass hexes" do
    ctx = setup_board { |s| s.place_settlement(14, 1, 1) }
    tile = Tiles::FarmTile.new(0)

    result = tile.valid_destinations(board_contents: ctx[:board_contents], board: ctx[:board], player_order: ctx[:chris].order)

    assert_not_includes result, [ 14, 1 ], "occupied Grass hex must be excluded"
  end

  test "valid_destinations falls back to any empty Grass when no adjacent Grass exists" do
    game = games(:game2player)
    chris = game_players(:chris)
    game.boards = [ [ 1, 0 ], [ 5, 0 ], [ 0, 0 ], [ 4, 0 ] ]
    # Settlement at (12,0) = C terrain; all neighbors are C/D — no adjacent Grass
    game.board_contents = BoardState.new.tap { |s| s.place_settlement(12, 0, chris.order) }
    game.save
    game.instantiate
    tile = Tiles::FarmTile.new(0)

    result = tile.valid_destinations(board_contents: game.board_contents, board: game.board, player_order: chris.order)

    assert_includes result, [ 14, 1 ], "fallback must include non-adjacent Grass hex"
    assert_includes result, [ 16, 0 ], "fallback must include distant Grass hex"
    assert_not_includes result, [ 12, 0 ], "settlement cell must not appear"
    result.each do |r, c|
      assert_equal "G", game.board.terrain_at(r, c), "every fallback destination must be Grass"
    end
  end

  test "valid_destinations returns empty when all Grass hexes are occupied" do
    grass_hexes = [
      # OasisBoard (index 0, rows 0-9, cols 0-9)
      [ 0, 7 ], [ 0, 8 ], [ 0, 9 ], [ 1, 8 ], [ 1, 9 ], [ 2, 9 ], [ 3, 4 ], [ 4, 4 ], [ 4, 5 ], [ 4, 6 ], [ 4, 7 ], [ 5, 4 ], [ 5, 5 ], [ 6, 5 ],
      # PaddockBoard (index 1, rows 0-9, cols 10-19)
      [ 7, 10 ], [ 7, 11 ], [ 7, 14 ], [ 7, 16 ], [ 7, 18 ], [ 8, 10 ], [ 8, 11 ], [ 8, 15 ], [ 8, 16 ], [ 8, 17 ], [ 8, 18 ],
      [ 9, 10 ], [ 9, 11 ], [ 9, 15 ], [ 9, 16 ], [ 9, 17 ],
      # FarmBoard (index 2, rows 10-19, cols 0-9)
      [ 10, 8 ], [ 10, 9 ], [ 11, 8 ], [ 11, 9 ], [ 14, 1 ], [ 14, 2 ], [ 15, 0 ], [ 15, 1 ], [ 16, 0 ], [ 16, 1 ], [ 16, 2 ], [ 17, 0 ], [ 17, 1 ], [ 18, 0 ],
      # TavernBoard (index 3, rows 10-19, cols 10-19)
      [ 13, 14 ], [ 13, 15 ], [ 14, 14 ], [ 14, 15 ], [ 14, 16 ], [ 15, 14 ], [ 16, 19 ],
      [ 17, 16 ], [ 17, 17 ], [ 17, 18 ], [ 17, 19 ], [ 18, 17 ], [ 18, 18 ], [ 18, 19 ], [ 19, 17 ], [ 19, 18 ], [ 19, 19 ]
    ]
    game = games(:game2player)
    chris = game_players(:chris)
    game.boards = [ [ 1, 0 ], [ 5, 0 ], [ 0, 0 ], [ 4, 0 ] ]
    game.board_contents = BoardState.new.tap do |s|
      grass_hexes.each { |r, c| s.place_settlement(r, c, 1) }
      s.place_settlement(12, 0, chris.order)
    end
    game.save
    game.instantiate
    tile = Tiles::FarmTile.new(0)

    result = tile.valid_destinations(board_contents: game.board_contents, board: game.board, player_order: chris.order)

    assert_empty result
  end

  # --- build_terrain ---

  test "build_terrain returns G" do
    assert_equal "G", Tiles::FarmTile.new(0).build_terrain
  end

  # --- from_hash ---

  test "from_hash returns a FarmTile" do
    assert_instance_of Tiles::FarmTile, Tiles::Tile.from_hash("klass" => "FarmTile")
  end

  # --- activatable? ---

  test "activatable? is true when Grass hexes are reachable" do
    ctx = setup_board
    tile = Tiles::FarmTile.new(0)
    assert tile.activatable?(player_order: ctx[:chris].order, board_contents: ctx[:board_contents], board: ctx[:board])
  end

  test "activatable? is false when all Grass hexes are occupied" do
    grass_hexes = [
      [ 0, 7 ], [ 0, 8 ], [ 0, 9 ], [ 1, 8 ], [ 1, 9 ], [ 2, 9 ], [ 3, 4 ], [ 4, 4 ], [ 4, 5 ], [ 4, 6 ], [ 4, 7 ], [ 5, 4 ], [ 5, 5 ], [ 6, 5 ],
      [ 7, 10 ], [ 7, 11 ], [ 7, 14 ], [ 7, 16 ], [ 7, 18 ], [ 8, 10 ], [ 8, 11 ], [ 8, 15 ], [ 8, 16 ], [ 8, 17 ], [ 8, 18 ],
      [ 9, 10 ], [ 9, 11 ], [ 9, 15 ], [ 9, 16 ], [ 9, 17 ],
      [ 10, 8 ], [ 10, 9 ], [ 11, 8 ], [ 11, 9 ], [ 14, 1 ], [ 14, 2 ], [ 15, 0 ], [ 15, 1 ], [ 16, 0 ], [ 16, 1 ], [ 16, 2 ], [ 17, 0 ], [ 17, 1 ], [ 18, 0 ],
      [ 13, 14 ], [ 13, 15 ], [ 14, 14 ], [ 14, 15 ], [ 14, 16 ], [ 15, 14 ], [ 16, 19 ],
      [ 17, 16 ], [ 17, 17 ], [ 17, 18 ], [ 17, 19 ], [ 18, 17 ], [ 18, 18 ], [ 18, 19 ], [ 19, 17 ], [ 19, 18 ], [ 19, 19 ]
    ]
    game = games(:game2player)
    chris = game_players(:chris)
    game.boards = [ [ 1, 0 ], [ 5, 0 ], [ 0, 0 ], [ 4, 0 ] ]
    game.board_contents = BoardState.new.tap do |s|
      grass_hexes.each { |r, c| s.place_settlement(r, c, 1) }
      s.place_settlement(12, 0, chris.order)
    end
    game.save
    game.instantiate
    tile = Tiles::FarmTile.new(0)
    assert_not tile.activatable?(player_order: chris.order, board_contents: game.board_contents, board: game.board)
  end

  test "builds_settlement? returns true" do
    assert Tiles::FarmTile.new(0).builds_settlement?
  end
end
