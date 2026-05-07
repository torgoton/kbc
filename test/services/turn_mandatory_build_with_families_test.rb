require "test_helper"

class TurnMandatoryBuildWithFamiliesTest < ActiveSupport::TestCase
  def setup
    @game = Game.create!(state: "waiting")
    @game.add_player(users(:chris))
    @game.add_player(users(:paula))
    @game.start
    @game.update!(goals: [ "families" ])
    @game.reload
    @game.instantiate
    @player = @game.current_player
    @hand_terrain = @player.hand.first
  end

  test "three builds in a straight line score Families on the third click and unwind cleanly" do
    line = three_collinear_buildable_hexes
    skip "no 3-collinear buildable line for #{@hand_terrain} on this fixture" unless line

    score_before = @player.reload.bonus_scores&.dig("families") || 0

    line.each do |row, col|
      turn = Turn.from_game(@game.reload)
      @game.instantiate
      ConsequenceApplier.apply!(@game, turn.handle(:build, game: @game, row: row, col: col))
    end

    @player.reload
    assert_equal score_before + 2, @player.bonus_scores["families"]
    assert_equal 3, TurnClick.where(game: @game).count

    3.times { ConsequenceApplier.unapply!(@game.reload) }

    @player.reload
    assert_equal score_before, (@player.bonus_scores&.dig("families") || 0)
    assert_equal 0, TurnClick.where(game: @game).count
  end

  test "three builds NOT in a straight line do not score Families" do
    target_a = first_empty_terrain(@hand_terrain)
    target_b = neighbor_in_terrain(target_a, @hand_terrain)
    skip "fixture lacks 2 connected #{@hand_terrain} hexes" unless target_b
    target_c = non_collinear_neighbor_in_terrain(target_a, target_b, @hand_terrain)
    skip "fixture lacks a 3rd non-collinear #{@hand_terrain} hex" unless target_c

    [ target_a, target_b, target_c ].each do |row, col|
      turn = Turn.from_game(@game.reload)
      @game.instantiate
      ConsequenceApplier.apply!(@game, turn.handle(:build, game: @game, row: row, col: col))
    end

    refute @player.reload.bonus_scores&.dig("families"), "should not have scored families"
  end

  private

  def first_empty_terrain(terrain)
    20.times do |r|
      20.times do |c|
        return [ r, c ] if @game.board.terrain_at(r, c) == terrain && @game.board_contents.empty?(r, c)
      end
    end
    raise "no empty #{terrain}"
  end

  def neighbor_in_terrain(seed, terrain)
    @game.board_contents.neighbors(seed[0], seed[1]).find do |nr, nc|
      @game.board.terrain_at(nr, nc) == terrain && @game.board_contents.empty?(nr, nc)
    end
  end

  def non_collinear_neighbor_in_terrain(a, b, terrain)
    # Find a neighbor of b that's NOT on the line a→b extended.
    line_extension = next_in_line(a, b)
    @game.board_contents.neighbors(b[0], b[1]).find do |nr, nc|
      [ nr, nc ] != a &&
        [ nr, nc ] != line_extension &&
        @game.board.terrain_at(nr, nc) == terrain &&
        @game.board_contents.empty?(nr, nc)
    end
  end

  def next_in_line(a, b)
    Tiles::PaddockTile::STRAIGHT_LINES.each do |steps|
      dr1, dc1 = steps[a[0] % 2]
      next unless [ a[0] + dr1, a[1] + dc1 ] == b
      dr2, dc2 = steps[b[0] % 2]
      return [ b[0] + dr2, b[1] + dc2 ]
    end
    nil
  end

  def three_collinear_buildable_hexes
    Tiles::PaddockTile::STRAIGHT_LINES.each do |steps|
      20.times do |r|
        20.times do |c|
          a = [ r, c ]
          dr1, dc1 = steps[r % 2]
          b = [ r + dr1, c + dc1 ]
          next unless (0..19).cover?(b[0]) && (0..19).cover?(b[1])
          dr2, dc2 = steps[b[0] % 2]
          c2 = [ b[0] + dr2, b[1] + dc2 ]
          next unless (0..19).cover?(c2[0]) && (0..19).cover?(c2[1])
          line = [ a, b, c2 ]
          next unless line.all? { |row, col|
            @game.board.terrain_at(row, col) == @hand_terrain && @game.board_contents.empty?(row, col)
          }
          return line
        end
      end
    end
    nil
  end
end
