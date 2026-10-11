require "test_helper"

class Tiles::FountainTileTest < ActiveSupport::TestCase
  # Board 1 rows 0-1: "DDCWWTTGGG" / "DCWFFTTTGG" -- (0,8) and (1,8) are Grass.
  def contents(chris: [], paula: [])
    game = games(:game2player)
    game.boards = [ [ 1, 0 ], [ 5, 0 ], [ 0, 0 ], [ 4, 0 ] ]
    state = BoardState.new.tap do |s|
      chris.each { |r, c| s.place_settlement(r, c, game_players(:chris).order) }
      paula.each { |r, c| s.place_settlement(r, c, game_players(:paula).order) }
    end
    game.board_contents = state
    game.save!
    game.instantiate
    game.board_contents
  end

  def destinations(board_contents)
    Tiles::Location::FountainTile.new(0).valid_destinations(board_contents:, player_order: game_players(:chris).order)
  end

  test "hexes next to exactly 1 of your settlements" do
    bc = contents(chris: [ [ 0, 8 ] ])
    assert_includes destinations(bc), [ 0, 9 ]
    assert_not_includes destinations(bc), [ 0, 8 ], "occupied"
    assert_not_includes destinations(bc), [ 0, 0 ], "not next to any settlement"
  end

  test "excludes hexes next to 2 of your settlements" do
    bc = contents(chris: [ [ 0, 7 ], [ 0, 9 ] ])
    assert_not_includes destinations(bc), [ 0, 8 ]
  end

  test "excludes hexes next to an opponent's settlement" do
    bc = contents(chris: [ [ 0, 8 ] ], paula: [ [ 1, 9 ] ])
    assert_not_includes destinations(bc), [ 0, 9 ], "(0,9) touches paula at (1,9)"
    assert_includes destinations(bc), [ 0, 7 ]
  end

  test "excludes unbuildable terrain" do
    bc = contents(chris: [ [ 0, 5 ] ])
    assert_not_includes destinations(bc), [ 0, 4 ], "Water"
  end

  test "is activatable only when a destination exists" do
    tile = Tiles::Location::FountainTile.new(0)
    chris = game_players(:chris).order
    assert_not tile.activatable?(player_order: chris, board_contents: contents)
    assert tile.activatable?(player_order: chris, board_contents: contents(chris: [ [ 0, 8 ] ]))
  end
end
