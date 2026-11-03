require "test_helper"

class IslandTest < ActiveSupport::TestCase
  test "terrain_at maps board coordinates onto the map; void and off-island are empty" do
    island = Boards::Island.new(0)
    assert_equal "X", island.terrain_at(20, 2)    # sea rim, map row 0
    assert_equal "", island.terrain_at(20, -1)    # void corner
    assert_equal "G", island.terrain_at(21, 1)    # map row 1, col 2
    assert_equal "", island.terrain_at(19, 1)     # main map's row, not the island's
  end

  test "cells are only the playable hexes, within rows 21-25 and cols 0-6" do
    Boards::Island::SECTIONS.each_index do |id|
      cells = Boards::Island.new(id).cells
      assert cells.all? { |r, c| (21..25).cover?(r) && (0..6).cover?(c) }
      assert cells.none? { |r, c| %w[X].include?(Boards::Island.new(id).terrain_at(r, c)) }
    end
  end

  test "silver and location hexes are reported in board coordinates" do
    island = Boards::Island.new(0)
    assert_equal [ { r: 22, c: 1, k: "Castle" } ], island.silver_hexes
    assert_equal [ { r: 23, c: 4, k: "RopeBridge" } ], island.location_hexes
  end

  test "the island and the main map are never adjacent" do
    state = BoardState.new
    assert state.neighbors(19, 5).none? { |r, _| r >= 20 }
    assert state.neighbors(21, 0).none? { |r, _| r < 20 }
    assert_not state.in_bounds?(20, 5, from: 19)
  end

  def started_game(options)
    game = Game.new(state: "waiting", options:)
    game.add_player(users(:chris))
    game.add_player(users(:jules))
    game.save!
    game.start
    game
  end

  test "the Island decree puts the Island in play, places its tiles, and sea hexes count as water" do
    game = started_game("decree" => "island")
    assert game.island?
    game.instantiate
    loc = game.board.island.location_hexes.first
    assert_equal "#{loc[:k]}Tile", game.board_contents.tile_klass(loc[:r], loc[:c])
    assert_includes game.board.silver_hexes_of("Castle"), game.board.island.silver_hexes.map { |h| [ h[:r], h[:c] ] }.first
    game.board_contents.place_settlement(*game.board.island.cells.first, game.game_players.first.order) # first playable hex touches the sea rim
    assert_equal 1, Scoring::Goals::Fishermen.new(game).score_for(game.game_players.first)[:score]
  end

  test "no chosen decree means no decree" do
    assert_not started_game({}).island?
  end
end
