require "test_helper"

class Tiles::Nomad::DonationTileTest < ActiveSupport::TestCase
  # QuarryBoard at index 0: rows 0-9, cols 0-9
  # Row 0: GGGWWWMCCC  → Canyon(C) at (0,7..9); Water(W) at (0,3..5); Mountain(M) at (0,6)
  # Row 1: GGWTDWWWCC  → Water(W) at (1,3),(1,5),(1,6),(1,7)
  # Settlement at (0,2) [G] is adjacent to (0,3) [W] and (1,2) [G] — adjacent W exists.
  # Settlement at (0,8) [C] is adjacent to (0,7) [C] and (0,9) [C] — no adjacent C empty below,
  #   but (0,7) is C — let's use Canyon tile.
  # For Canyon adjacency: settlement at (1,8) [C] → adjacent Canyon hexes include (0,7),(0,8),(0,9),(1,7) check terrain
  #   Row 1: GGWTDWWWCC → (1,8)=C,(1,9)=C
  # Let's pick: settlement at (0,8) [C], adjacent Canyon hex at (0,7) [C] and (0,9) [C] (if empty)

  def setup
    @game = games(:game2player)
    @chris = game_players(:chris)
  end

  def setup_board_with_settlement(row, col, boards: [ [ "Quarry", 0 ], [ "Paddock", 0 ], [ "Farm", 0 ], [ "Tavern", 0 ] ])
    @game.boards = boards
    state = BoardState.new.tap { |s| s.place_settlement(row, col, @chris.order) }
    yield state if block_given?
    @game.board_contents = state
    @game.save
    @game.instantiate
    { board_contents: @game.board_contents, board: @game.board, chris: @chris }
  end

  # --- DonationCanyonTile (terrain "C") ---

  test "DonationCanyonTile valid_destinations returns adjacent Canyon hexes when available" do
    # QuarryBoard row 0: GGGWWWMCCC → (0,7),(0,8),(0,9) are C
    # Settlement at (0,8): adjacent C hexes are (0,7) and (0,9)
    ctx = setup_board_with_settlement(0, 8)
    tile = Tiles::Nomad::DonationCanyonTile.new(0)

    result = tile.valid_destinations(board_contents: ctx[:board_contents], board: ctx[:board], player_order: ctx[:chris].order)

    assert_includes result, [ 0, 7 ], "adjacent Canyon hex must be included"
    assert_includes result, [ 0, 9 ], "adjacent Canyon hex must be included"
    result.each do |r, c|
      assert_equal "C", ctx[:board].terrain_at(r, c), "every destination must be Canyon"
    end
  end

  test "DonationCanyonTile valid_destinations falls back to any Canyon when no adjacent Canyon" do
    # QuarryBoard row 2: GMWTLDDDWM → no C
    # Settlement at (2,0) [G]: neighbors are (1,0)[G],(1,1)[G],(2,1)[M],(3,0)[F],(3,1)[W] — no adjacent C
    ctx = setup_board_with_settlement(2, 0)
    tile = Tiles::Nomad::DonationCanyonTile.new(0)

    result = tile.valid_destinations(board_contents: ctx[:board_contents], board: ctx[:board], player_order: ctx[:chris].order)

    assert_not_empty result, "fallback should find Canyon hexes on the board"
    result.each do |r, c|
      assert_equal "C", ctx[:board].terrain_at(r, c), "every fallback destination must be Canyon"
    end
    # (0,7) is Canyon and not adjacent to (2,0), must appear in fallback
    assert_includes result, [ 0, 7 ]
  end

  # --- DonationWaterTile (terrain "W") ---

  test "DonationWaterTile can build on Water terrain (adjacent)" do
    # QuarryBoard row 0: GGGWWWMCCC → W at (0,3),(0,4),(0,5)
    # Settlement at (0,2) [G]: adjacent hex (0,3) is W
    ctx = setup_board_with_settlement(0, 2)
    tile = Tiles::Nomad::DonationWaterTile.new(0)

    result = tile.valid_destinations(board_contents: ctx[:board_contents], board: ctx[:board], player_order: ctx[:chris].order)

    assert_includes result, [ 0, 3 ], "adjacent Water hex must be included"
    result.each do |r, c|
      assert_equal "W", ctx[:board].terrain_at(r, c), "every destination must be Water"
    end
  end

  test "DonationWaterTile falls back to any Water when no adjacent Water" do
    # QuarryBoard row 0: GGGWWWMCCC → settlement at (0,8) [C], no adjacent W
    ctx = setup_board_with_settlement(0, 8)
    tile = Tiles::Nomad::DonationWaterTile.new(0)

    result = tile.valid_destinations(board_contents: ctx[:board_contents], board: ctx[:board], player_order: ctx[:chris].order)

    assert_not_empty result, "fallback should find Water hexes on the board"
    result.each do |r, c|
      assert_equal "W", ctx[:board].terrain_at(r, c), "every fallback destination must be Water"
    end
  end

  # --- DonationMountainTile (terrain "M") ---

  test "DonationMountainTile can build on Mountain terrain (adjacent)" do
    # QuarryBoard row 0: GGGWWWMCCC → M at (0,6)
    # Settlement at (0,5) [W]: adjacent to (0,6) [M] (same row adjacency)
    # Actually (0,5) is W. Adjacent to (0,6)? Even row adjacency: neighbors of (0,5) include (0,4),(0,6),(1,4),(1,5)
    # But (0,5) is W — player settlement there.
    # neighbors of (0,5): row 0 even: [r-1,c-1],[r-1,c],[r,c-1],[r,c+1],[r+1,c-1],[r+1,c] = N/A(row -1), (0,4),(0,6),(1,4),(1,5)
    # (0,6) = M — adjacent! But we need an empty M adjacent to the settlement.
    # Settlement at (0,5): adjacent M hex at (0,6)
    ctx = setup_board_with_settlement(0, 5)
    tile = Tiles::Nomad::DonationMountainTile.new(0)

    result = tile.valid_destinations(board_contents: ctx[:board_contents], board: ctx[:board], player_order: ctx[:chris].order)

    assert_includes result, [ 0, 6 ], "adjacent Mountain hex must be included"
    result.each do |r, c|
      assert_equal "M", ctx[:board].terrain_at(r, c), "every destination must be Mountain"
    end
  end

  test "DonationMountainTile falls back to any Mountain when no adjacent Mountain" do
    # Settlement at (0,8) [C]: no adjacent M
    ctx = setup_board_with_settlement(0, 8)
    tile = Tiles::Nomad::DonationMountainTile.new(0)

    result = tile.valid_destinations(board_contents: ctx[:board_contents], board: ctx[:board], player_order: ctx[:chris].order)

    assert_not_empty result, "fallback should find Mountain hexes on the board"
    result.each do |r, c|
      assert_equal "M", ctx[:board].terrain_at(r, c), "every fallback destination must be Mountain"
    end
  end

  # --- build_terrain ---

  test "DonationCanyonTile build_terrain returns C" do
    assert_equal "C", Tiles::Nomad::DonationCanyonTile.new(0).build_terrain
  end

  test "DonationDesertTile build_terrain returns D" do
    assert_equal "D", Tiles::Nomad::DonationDesertTile.new(0).build_terrain
  end

  test "DonationFlowerTile build_terrain returns F" do
    assert_equal "F", Tiles::Nomad::DonationFlowerTile.new(0).build_terrain
  end

  test "DonationGrassTile build_terrain returns G" do
    assert_equal "G", Tiles::Nomad::DonationGrassTile.new(0).build_terrain
  end

  test "DonationTimberTile build_terrain returns T" do
    assert_equal "T", Tiles::Nomad::DonationTimberTile.new(0).build_terrain
  end

  test "DonationWaterTile build_terrain returns W" do
    assert_equal "W", Tiles::Nomad::DonationWaterTile.new(0).build_terrain
  end

  test "DonationMountainTile build_terrain returns M" do
    assert_equal "M", Tiles::Nomad::DonationMountainTile.new(0).build_terrain
  end

  # --- builds_settlement? ---

  test "builds_settlement? returns true" do
    assert Tiles::Nomad::DonationCanyonTile.new(0).builds_settlement?
  end

  # --- DonationTile base class raises NotImplementedError ---

  test "DonationTile#build_terrain raises NotImplementedError" do
    assert_raises(NotImplementedError) { Tiles::Nomad::DonationTile.new(0).build_terrain }
  end
end
