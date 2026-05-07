require "test_helper"

class TurnMandatoryBuildWithPickupTest < ActiveSupport::TestCase
  def setup
    @game = Game.create!(state: "waiting")
    @game.add_player(users(:chris))
    @game.add_player(users(:paula))
    @game.start
    @game.reload
    @game.instantiate
    @player = @game.current_player
    @hand_terrain = @player.hand.first
  end

  test "build adjacent to a location tile picks it up in the same click and unwinds cleanly" do
    target = first_buildable_hex
    nbr_r, nbr_c = @game.board_contents.neighbors(target[0], target[1]).first
    @game.board_contents.place_tile(nbr_r, nbr_c, "OracleTile", 2)
    @game.save!

    turn = Turn.from_game(@game.reload)
    @game.instantiate
    cs = turn.handle(:build, game: @game, row: target[0], col: target[1])

    assert(cs.any? { |c| c.is_a?(Turn::Consequences::SettlementPlaced) })
    assert(cs.any? { |c| c.is_a?(Turn::Consequences::TilePickedUp) })
    assert(cs.any? { |c| c.is_a?(Turn::Consequences::MandatoryRemainingDecremented) })

    ConsequenceApplier.apply!(@game, cs)

    @game.reload
    @game.instantiate
    assert_equal 1, @game.board_contents.tile_qty(nbr_r, nbr_c)
    assert(@player.reload.tiles.any? { |t| t["klass"] == "OracleTile" && t["from"] == "[#{nbr_r}, #{nbr_c}]" })
    assert_equal 1, TurnClick.where(game: @game).count

    ConsequenceApplier.unapply!(@game.reload)

    @game.reload
    @game.instantiate
    assert_nil @game.board_contents.player_at(target[0], target[1])
    assert_equal 2, @game.board_contents.tile_qty(nbr_r, nbr_c)
    refute(@player.reload.tiles.any? { |t| t["klass"] == "OracleTile" })
    assert_equal 0, TurnClick.where(game: @game).count
  end

  test "build skips pickup of tiles already in the player's taken_from" do
    target = first_buildable_hex
    nbr_r, nbr_c = @game.board_contents.neighbors(target[0], target[1]).first
    @game.board_contents.place_tile(nbr_r, nbr_c, "OracleTile", 2)
    @game.save!
    @player.update!(taken_from: [ "[#{nbr_r}, #{nbr_c}]" ])

    turn = Turn.from_game(@game.reload)
    @game.instantiate
    cs = turn.handle(:build, game: @game, row: target[0], col: target[1])

    refute(cs.any? { |c| c.is_a?(Turn::Consequences::TilePickedUp) })
  end

  private

  def first_buildable_hex
    20.times do |r|
      20.times do |c|
        return [ r, c ] if @game.board.terrain_at(r, c) == @hand_terrain && @game.board_contents.empty?(r, c)
      end
    end
    raise "no buildable #{@hand_terrain}"
  end
end
