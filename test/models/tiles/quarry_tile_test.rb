require "test_helper"

class Tiles::QuarryTileTest < ActiveSupport::TestCase
  # Quarry board at index 0 occupies rows 0–9, cols 0–9.
  # Row 0: GGGWWWMCCC
  # Row 1: GGWTDWWWCC
  # Settlement at (0,0)=G. Neighbors (even row adjacencies: [0,-1],[0,1],[-1,-1],[-1,0],[1,-1],[1,0]):
  #   (0,1)=G, (1,0)=G — valid with hand='G'
  #   (0,-1), (-1,-1), (-1,0), (1,-1) — out of bounds
  def setup_board
    game = games(:game2player)
    chris = game_players(:chris)
    game.boards = [ [ "Quarry", 0 ], [ "Paddock", 0 ], [ "Oasis", 0 ], [ "Farm", 0 ] ]
    state = BoardState.new.tap { |s| s.place_settlement(0, 0, chris.order) }
    yield state if block_given?
    game.board_contents = state
    game.save
    game.instantiate
    { board_contents: game.board_contents, board: game.board, chris: chris }
  end

  test "places_wall? returns true" do
    assert Tiles::QuarryTile.new(0).places_wall?
  end

  test "valid_destinations returns empty terrain hexes of hand terrain adjacent to player settlements" do
    ctx = setup_board
    tile = Tiles::QuarryTile.new(0)

    result = tile.valid_destinations(
      board_contents: ctx[:board_contents], board: ctx[:board],
      player_order: ctx[:chris].order, hand: "G"
    )

    assert_includes result, [ 0, 1 ], "(0,1) is G terrain adjacent to settlement"
    assert_includes result, [ 1, 0 ], "(1,0) is G terrain adjacent to settlement"
    assert_not_includes result, [ 0, 3 ], "(0,3) is W terrain — wrong terrain"
    assert_not_includes result, [ 0, 0 ], "settlement hex itself not included"
  end

  test "valid_destinations does not return hexes not adjacent to any settlement" do
    ctx = setup_board
    tile = Tiles::QuarryTile.new(0)

    result = tile.valid_destinations(
      board_contents: ctx[:board_contents], board: ctx[:board],
      player_order: ctx[:chris].order, hand: "G"
    )

    # (0,2)=G is Grass but not adjacent to settlement at (0,0)
    assert_not_includes result, [ 0, 2 ], "(0,2) is not adjacent to any settlement"
  end

  test "valid_destinations does not return occupied hexes" do
    ctx = setup_board { |s| s.place_settlement(0, 1, 1) }
    tile = Tiles::QuarryTile.new(0)

    result = tile.valid_destinations(
      board_contents: ctx[:board_contents], board: ctx[:board],
      player_order: ctx[:chris].order, hand: "G"
    )

    assert_not_includes result, [ 0, 1 ], "occupied hex excluded"
    assert_includes result, [ 1, 0 ], "other valid neighbors still included"
  end

  test "valid_destinations returns empty when hand is nil" do
    ctx = setup_board
    tile = Tiles::QuarryTile.new(0)

    result = tile.valid_destinations(
      board_contents: ctx[:board_contents], board: ctx[:board],
      player_order: ctx[:chris].order, hand: nil
    )

    assert_empty result
  end
end
