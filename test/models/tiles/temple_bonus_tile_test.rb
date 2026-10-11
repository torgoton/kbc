require "test_helper"

class Tiles::TempleBonusTileTest < ActiveSupport::TestCase
  BONUS = { "klass" => "TempleBonusTile", "used" => false }.freeze

  def setup
    @game = games(:game2player)
    @game.boards = [ [ 1, 0 ], [ 5, 0 ], [ 0, 0 ], [ 4, 0 ] ]
    @chris = game_players(:chris)
    @game.board_contents = BoardState.new.tap { |s| s.place_settlement(0, 8, @chris.order) } # Grass; (0,7) and (0,9) are adjacent Grass
    @game.mandatory_count = Game::MANDATORY_COUNT
    @game.save!
    @chris.update!(hand: [ "G" ])
  end

  def targets
    @game.reload
    TurnEngine.new(@game).legal_targets.to_set
  end

  def all_grass
    @game.instantiate
    @game.board_contents.available_cells_of([ "G" ]).to_set
  end

  test "without the bonus the first settlement must be adjacent" do
    @chris.update!(tiles: [])
    assert_includes targets, [ 0, 9 ]
    assert_operator targets.size, :<, all_grass.size
  end

  test "with the bonus the first mandatory settlement can go on any Grass hex" do
    @chris.update!(tiles: [ BONUS.dup ])
    assert_equal all_grass, targets
  end

  test "the bonus applies only to the first settlement" do
    @chris.update!(tiles: [ BONUS.dup ])
    TurnEngine.new(@game).click(Coordinate.new(0, 9))
    assert_operator targets.size, :<, all_grass.size
  end

  test "a bonus tile acquired this turn does not apply yet" do
    @chris.update!(tiles: [ BONUS.merge("used" => true) ])
    assert_operator targets.size, :<, all_grass.size
  end

  test "the first settlement can be built away from the others" do
    @chris.update!(tiles: [ BONUS.dup ])
    far = (all_grass - targets_adjacent).first
    TurnEngine.new(@game).click(Coordinate.new(*far))

    assert_equal @chris.order, @game.reload.board_contents.player_at(*far)
  end

  def targets_adjacent
    @game.instantiate
    @game.board_contents.buildable_cells_for(@chris.order, "G").to_set
  end

  test "collecting the 2nd Temple awards the Temple Bonus tile" do
    @game.board_contents = BoardState.new.tap do |s|
      s.place_tile(0, 6, "TempleTile", 2)
      s.place_settlement(0, 8, @chris.order)
    end
    @game.save!
    @chris.update!(tiles: [ { "klass" => "TempleTile", "used" => false, "from" => "[9, 9]" } ], taken_from: [ "[9, 9]" ])

    TurnEngine.new(@game).click(Coordinate.new(0, 7)) # Grass next to the Temple at (0,6)

    assert_equal 1, @chris.reload.tiles.count { |t| t["klass"] == "TempleBonusTile" }
  end
end
