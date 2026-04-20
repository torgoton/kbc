require "test_helper"

class Tiles::OasisTileTest < ActiveSupport::TestCase
  # Oasis board at index 0 occupies rows 0-9, cols 0-9.
  # Desert hexes: (0,0),(0,1),(1,0),(2,0),(2,1),(5,8),(6,8),(7,6),(7,7),(8,7),(8,8)
  # Settlement at (0,2): adjacent Desert hex is (0,1). Row 0 is even.
  # Settlement at (4,0): all neighbors are W — no adjacent Desert; fallback applies.

  def setup_board
    game = games(:game2player)
    chris = game_players(:chris)
    game.boards = [ [ 1, 0 ], [ 5, 0 ], [ 0, 0 ], [ 4, 0 ] ]
    state = BoardState.new.tap { |s| s.place_settlement(0, 2, chris.order) }
    yield state if block_given?
    game.board_contents = state
    game.save
    game.instantiate
    { board_contents: game.board_contents, board: game.board, chris: chris }
  end

  test "valid_destinations returns adjacent Desert hexes when available" do
    ctx = setup_board
    tile = Tiles::OasisTile.new(0)

    result = tile.valid_destinations(board_contents: ctx[:board_contents], board: ctx[:board], player_order: ctx[:chris].order)

    assert_includes result, [ 0, 1 ], "Desert hex adjacent to settlement must be included"
    result.each do |r, c|
      assert_equal "D", ctx[:board].terrain_at(r, c), "every destination must be Desert"
    end
  end

  test "valid_destinations excludes occupied Desert hexes" do
    ctx = setup_board { |s| s.place_settlement(0, 1, 1) }
    tile = Tiles::OasisTile.new(0)

    result = tile.valid_destinations(board_contents: ctx[:board_contents], board: ctx[:board], player_order: ctx[:chris].order)

    assert_not_includes result, [ 0, 1 ], "occupied Desert hex must be excluded"
  end

  test "valid_destinations falls back to any empty Desert when no adjacent Desert exists" do
    game = games(:game2player)
    chris = game_players(:chris)
    game.boards = [ [ 1, 0 ], [ 5, 0 ], [ 0, 0 ], [ 4, 0 ] ]
    # Settlement at (4,0): all neighbors are W terrain
    game.board_contents = BoardState.new.tap { |s| s.place_settlement(4, 0, chris.order) }
    game.save
    game.instantiate
    tile = Tiles::OasisTile.new(0)

    result = tile.valid_destinations(board_contents: game.board_contents, board: game.board, player_order: chris.order)

    assert_includes result, [ 0, 0 ], "fallback must include non-adjacent Desert hex"
    assert_includes result, [ 5, 8 ], "fallback must include distant Desert hex"
    assert_not_includes result, [ 4, 0 ], "settlement cell must not appear"
    result.each do |r, c|
      assert_equal "D", game.board.terrain_at(r, c), "every fallback destination must be Desert"
    end
  end

  test "valid_destinations returns empty when all Desert hexes are occupied" do
    # All Desert hexes across all four boards in the default First Game setup
    desert_hexes = [
      [ 0, 0 ], [ 0, 1 ], [ 1, 0 ], [ 2, 0 ], [ 2, 1 ], [ 5, 8 ], [ 6, 8 ], [ 7, 6 ], [ 7, 7 ], [ 8, 7 ], [ 8, 8 ],   # Oasis (index 0)
      [ 0, 13 ], [ 0, 14 ], [ 0, 16 ], [ 0, 17 ], [ 0, 18 ], [ 0, 19 ], [ 1, 13 ], [ 1, 14 ], [ 1, 16 ], [ 1, 17 ], [ 1, 18 ], [ 1, 19 ],  # Paddock (index 1)
      [ 2, 16 ], [ 2, 17 ], [ 3, 16 ],
      [ 10, 0 ], [ 10, 1 ], [ 10, 11 ], [ 10, 12 ], [ 10, 15 ], [ 10, 16 ], [ 11, 0 ], [ 11, 12 ], [ 11, 13 ], [ 11, 14 ],  # Farm / Tavern (rows 10-19)
      [ 13, 5 ], [ 13, 6 ], [ 14, 6 ], [ 14, 7 ], [ 15, 7 ], [ 15, 8 ], [ 16, 8 ], [ 16, 9 ], [ 16, 10 ],
      [ 17, 8 ], [ 17, 10 ], [ 17, 11 ], [ 18, 10 ], [ 18, 11 ], [ 18, 12 ], [ 19, 10 ], [ 19, 11 ]
    ]
    game = games(:game2player)
    chris = game_players(:chris)
    game.boards = [ [ 1, 0 ], [ 5, 0 ], [ 0, 0 ], [ 4, 0 ] ]
    game.board_contents = BoardState.new.tap do |s|
      desert_hexes.each { |r, c| s.place_settlement(r, c, 1) }
      s.place_settlement(4, 0, chris.order)
    end
    game.save
    game.instantiate
    tile = Tiles::OasisTile.new(0)

    result = tile.valid_destinations(board_contents: game.board_contents, board: game.board, player_order: chris.order)

    assert_empty result
  end

  # --- build_terrain ---

  test "build_terrain returns D" do
    assert_equal "D", Tiles::OasisTile.new(0).build_terrain
  end

  # --- from_hash ---

  test "from_hash returns an OasisTile" do
    assert_instance_of Tiles::OasisTile, Tiles::Tile.from_hash("klass" => "OasisTile")
  end

  # --- activatable? ---

  test "activatable? is true when desert hexes are reachable" do
    ctx = setup_board
    tile = Tiles::OasisTile.new(0)
    assert tile.activatable?(player_order: ctx[:chris].order, board_contents: ctx[:board_contents], board: ctx[:board])
  end

  test "activatable? is false when all desert hexes are occupied" do
    desert_hexes = [
      [ 0, 0 ], [ 0, 1 ], [ 1, 0 ], [ 2, 0 ], [ 2, 1 ], [ 5, 8 ], [ 6, 8 ], [ 7, 6 ], [ 7, 7 ], [ 8, 7 ], [ 8, 8 ],
      [ 0, 13 ], [ 0, 14 ], [ 0, 16 ], [ 0, 17 ], [ 0, 18 ], [ 0, 19 ], [ 1, 13 ], [ 1, 14 ], [ 1, 16 ], [ 1, 17 ], [ 1, 18 ], [ 1, 19 ],
      [ 2, 16 ], [ 2, 17 ], [ 3, 16 ],
      [ 10, 0 ], [ 10, 1 ], [ 10, 11 ], [ 10, 12 ], [ 10, 15 ], [ 10, 16 ], [ 11, 0 ], [ 11, 12 ], [ 11, 13 ], [ 11, 14 ],
      [ 13, 5 ], [ 13, 6 ], [ 14, 6 ], [ 14, 7 ], [ 15, 7 ], [ 15, 8 ], [ 16, 8 ], [ 16, 9 ], [ 16, 10 ],
      [ 17, 8 ], [ 17, 10 ], [ 17, 11 ], [ 18, 10 ], [ 18, 11 ], [ 18, 12 ], [ 19, 10 ], [ 19, 11 ]
    ]
    game = games(:game2player)
    chris = game_players(:chris)
    game.boards = [ [ 1, 0 ], [ 5, 0 ], [ 0, 0 ], [ 4, 0 ] ]
    game.board_contents = BoardState.new.tap do |s|
      desert_hexes.each { |r, c| s.place_settlement(r, c, 1) }
      s.place_settlement(4, 0, chris.order)
    end
    game.save
    game.instantiate
    tile = Tiles::OasisTile.new(0)
    assert_not tile.activatable?(player_order: chris.order, board_contents: game.board_contents, board: game.board)
  end

  test "builds_settlement? returns true" do
    assert Tiles::OasisTile.new(0).builds_settlement?
  end
end
