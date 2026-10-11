require "test_helper"

class GameOptionsTest < ActiveSupport::TestCase
  RUNS = 30
  BASE_BOARDS = (0..7).to_a
  NOMAD_BOARDS = (8..11).to_a
  CROSSROADS_BOARDS = (12..15).to_a

  BASE_GOALS = %w[citizens discoverers farmers fishermen hermits knights merchants miners workers].freeze
  NOMAD_GOALS = %w[families shepherds ambassadors].freeze
  GOAL_RUNS = 60

  def started_game(options, start_options = {})
    game = Game.create!(state: "waiting", options:)
    game.add_player(users(:chris))
    game.add_player(users(:paula))
    game.start(true, start_options)
    game
  end

  def boards_over_runs(options)
    Array.new(RUNS) { started_game(options).boards.map(&:first) }
  end

  test "base game only uses boards 0-7" do
    boards_over_runs({}).each do |ids|
      assert_empty ids - BASE_BOARDS, "unexpected boards #{ids.inspect}"
    end
  end

  test "nomads adds boards 8-11 to the pool, and only those" do
    ids = boards_over_runs({ "expansions" => %w[nomads] }).flatten.uniq
    assert_empty ids - BASE_BOARDS - NOMAD_BOARDS
    assert_equal NOMAD_BOARDS, (ids & NOMAD_BOARDS).sort
  end

  test "crossroads adds boards 12-15 to the pool, and only those" do
    ids = boards_over_runs({ "expansions" => %w[crossroads] }).flatten.uniq
    assert_empty ids - BASE_BOARDS - CROSSROADS_BOARDS
    assert_equal CROSSROADS_BOARDS, (ids & CROSSROADS_BOARDS).sort
  end

  def goals_over_runs(options)
    Array.new(GOAL_RUNS) { started_game(options).goals - [ "castles" ] }.flatten.uniq
  end

  test "base game goals exclude families, shepherds and ambassadors" do
    assert_empty goals_over_runs({}) - BASE_GOALS
  end

  test "nomads adds families, shepherds and ambassadors to the goal pool" do
    goals = goals_over_runs({ "expansions" => %w[nomads] })
    assert_empty goals - BASE_GOALS - NOMAD_GOALS
    assert_equal NOMAD_GOALS.sort, (goals & NOMAD_GOALS).sort
  end

  test "crossroads does not change the goal pool" do
    assert_empty goals_over_runs({ "expansions" => %w[crossroads] }) - BASE_GOALS
  end

  test "marshlands adds its six goals to the goal pool" do
    marshlands = Game::MARSHLANDS_GOALS
    goals = goals_over_runs({ "expansions" => %w[marshlands] })
    assert_empty goals - BASE_GOALS - marshlands
    assert_equal marshlands.sort, (goals & marshlands).sort
  end

  def nomad_tiles_over_runs(options)
    Array.new(RUNS) do
      game = started_game(options, include_boards: NOMAD_BOARDS)
      game.moves.find_by(action: "populate_boards").payload["tiles"].map { |t| t["klass"] }
    end.flatten
  end

  test "nomads with sword on can place Sword tiles" do
    tiles = nomad_tiles_over_runs({ "expansions" => %w[nomads], "nomads_sword" => true })
    assert_includes tiles, "SwordTile"
  end

  test "nomads with sword off never places Sword tiles" do
    tiles = nomad_tiles_over_runs({ "expansions" => %w[nomads], "nomads_sword" => false })
    assert_includes tiles, "TreasureTile" # other nomad tiles still placed
    assert_not_includes tiles, "SwordTile"
  end
end
