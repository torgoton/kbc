require "test_helper"

class TurnOutpostFlowTest < ActiveSupport::TestCase
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

  test "activate outpost then build a non-adjacent hex; outpost flag clears; full unwind" do
    @player.update!(tiles: [ { "klass" => "OutpostTile", "from" => "[2, 3]", "used" => false } ])
    seed = first_empty_terrain(@hand_terrain)
    @game.board_contents.place_settlement(seed[0], seed[1], 0)
    @game.save!

    far = first_empty_terrain_not_adjacent_to(seed, @hand_terrain)

    # Click 1: activate outpost
    turn = Turn.from_game(@game.reload)
    @game.instantiate
    ConsequenceApplier.apply!(@game, turn.handle(:activate_outpost, game: @game))
    assert_equal true, @game.reload.current_action.dig("turn", "outpost_active")

    # Click 2: build at non-adjacent hex (only allowed because outpost_active is true)
    turn = Turn.from_game(@game.reload)
    @game.instantiate
    cs = turn.handle(:build, game: @game, row: far[0], col: far[1])
    refute(cs.any? { |c| c.is_a?(Turn::Consequences::Error) }, "expected build success")
    ConsequenceApplier.apply!(@game, cs)

    @game.reload
    assert_equal false, @game.current_action.dig("turn", "outpost_active")
    assert_equal 0, @game.board_contents.player_at(far[0], far[1])
    assert_equal 2, TurnClick.where(game: @game).count

    # Unwind both
    2.times { ConsequenceApplier.unapply!(@game.reload) }

    @game.reload
    assert_equal 0, TurnClick.where(game: @game).count
    @player.reload
    refute @player.tiles.any? { |t| t["klass"] == "OutpostTile" && t["used"] }, "outpost should be unused after unwind"
    refute @game.current_action.dig("turn", "outpost_active"), "outpost flag clean after full unwind"
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

  def first_empty_terrain_not_adjacent_to(seed, terrain)
    seed_r, seed_c = seed
    neighbor_set = @game.board_contents.neighbors(seed_r, seed_c).to_set
    20.times do |r|
      20.times do |c|
        next unless @game.board.terrain_at(r, c) == terrain
        next unless @game.board_contents.empty?(r, c)
        next if [ r, c ] == seed
        next if neighbor_set.include?([ r, c ])
        return [ r, c ]
      end
    end
    raise "no far #{terrain} hex"
  end
end
