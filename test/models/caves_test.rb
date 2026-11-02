require "test_helper"

class CavesTest < ActiveSupport::TestCase
  def caves_game
    loop do
      game = Game.new(state: "waiting", options: { "queenies" => [ "emperors_choice" ], "decree_chance" => 100 })
      game.add_player(users(:chris))
      game.add_player(users(:jules))
      game.save!
      game.start
      return game if game.caves?
    end
  end

  test "distance counts hex steps on offset rows" do
    assert_equal 0, BoardState.distance([ 4, 4 ], [ 4, 4 ])
    assert_equal 3, BoardState.distance([ 0, 0 ], [ 0, 3 ])
    BoardState::ADJACENCIES.each_with_index do |steps, parity|
      steps.each { |dr, dc| assert_equal 1, BoardState.distance([ 4 + parity, 5 ], [ 4 + parity + dr, 5 + dc ]) }
    end
    assert_equal 2, BoardState.distance([ 0, 0 ], [ 2, 0 ])
  end

  test "caves are at most one per quadrant, on Mountains at least 3 from any S or L hex" do
    game = caves_game
    board = game.instantiate
    caves = game.cave_hexes
    assert caves.size.between?(1, 4)
    assert_equal caves.size, caves.map { |r, c| [ r / 10, c / 10 ] }.uniq.size
    special = BoardState::MAIN_CELLS.select { |r, c| %w[S L].include?(board.terrain_at(r, c)) }
    caves.each do |cave|
      assert_equal "M", board.terrain_at(*cave)
      assert special.all? { |s| BoardState.distance(cave, s) >= 3 }
    end
    game.game_players.each { |gp| assert_includes gp.tiles.map { |t| t["klass"] }, "CaveTile" }
  end

  test "placing the caves is logged with their locations" do
    game = caves_game
    move = game.moves.find_by!(action: "place_caves")
    assert_equal "Caves placed: #{game.cave_hexes.map { |r, c| "[#{r},#{c}]" }.join(", ")}", move.message
  end

  test "a cave goes where the most neighbors are buildable" do
    game = caves_game
    board = game.instantiate
    game.cave_hexes.each do |cave|
      quadrant = [ cave[0] / 10, cave[1] / 10 ]
      special = BoardState::MAIN_CELLS.select { |r, c| %w[S L].include?(board.terrain_at(r, c)) }
      score = ->(cell) { game.board_contents.neighbors(*cell).count { |n| Tiles::Tile::BUILDABLE_TERRAIN.include?(board.terrain_at(*n)) } }
      rivals = BoardState::MAIN_CELLS.select do |r, c|
        [ r / 10, c / 10 ] == quadrant && board.terrain_at(r, c) == "M" && special.all? { |s| BoardState.distance([ r, c ], s) >= 3 }
      end
      assert_equal rivals.map(&score).max, score.(cave)
    end
  end
end
