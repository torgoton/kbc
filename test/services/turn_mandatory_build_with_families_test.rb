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
    line, terrain = any_three_collinear_empty_same_terrain
    @player.update!(hand: [ terrain ])
    @hand_terrain = terrain

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
    line, terrain = any_three_collinear_empty_same_terrain
    @player.update!(hand: [ terrain ])
    @hand_terrain = terrain

    # Replace the third hex with one that breaks the line: take the first hex's neighbor in
    # a different direction. Walk all of `a`'s neighbors and pick one whose `[a, b, neighbor]`
    # is not a straight line, requiring it also be empty + matching terrain.
    a, b, _c = line
    bent = bent_third_for(a, b, terrain)
    targets = [ a, b, bent ]

    targets.each do |row, col|
      turn = Turn.from_game(@game.reload)
      @game.instantiate
      ConsequenceApplier.apply!(@game, turn.handle(:build, game: @game, row: row, col: col))
    end

    refute @player.reload.bonus_scores&.dig("families"), "should not have scored families"
  end

  private

  # Find any 3-collinear empty hexes sharing the same terrain on the actual board.
  # Returns [line, terrain]. With a 20x20 KB board this always finds a match.
  def any_three_collinear_empty_same_terrain
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
          terrains = line.map { |row, col| @game.board.terrain_at(row, col) }
          next unless terrains.uniq.size == 1
          terrain = terrains.first
          next unless Tiles::Tile::BUILDABLE_TERRAIN.include?(terrain)
          next unless line.all? { |row, col| @game.board_contents.empty?(row, col) }
          return [ line, terrain ]
        end
      end
    end
    raise "no 3-collinear same-terrain buildable line on this board"
  end

  # Given two collinear hexes a,b on the board, find a third hex that is:
  # - adjacent to b
  # - matching `terrain`
  # - empty
  # - NOT the collinear extension of a→b
  # Falls back to constructing a non-line by clearing a hex if necessary.
  def bent_third_for(a, b, terrain)
    line_extension = next_in_line(a, b)
    candidate = @game.board_contents.neighbors(b[0], b[1]).find do |nr, nc|
      [ nr, nc ] != a &&
        [ nr, nc ] != line_extension &&
        @game.board.terrain_at(nr, nc) == terrain &&
        @game.board_contents.empty?(nr, nc)
    end
    return candidate if candidate

    # No matching-terrain bent option exists naturally. Take any non-line empty neighbor
    # of b and stub its terrain via singleton override on the board.
    fallback = @game.board_contents.neighbors(b[0], b[1]).find do |nr, nc|
      [ nr, nc ] != a && [ nr, nc ] != line_extension && @game.board_contents.empty?(nr, nc)
    end
    raise "no usable bent neighbor of #{b.inspect}" unless fallback
    stub_terrain_at(fallback, terrain)
    fallback
  end

  def stub_terrain_at(coord, terrain)
    board = @game.board
    original = board.method(:terrain_at)
    board.define_singleton_method(:terrain_at) do |r, c|
      ([ r, c ] == coord) ? terrain : original.call(r, c)
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
end
