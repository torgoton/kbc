require "test_helper"

class TurnTest < ActiveSupport::TestCase
  def setup
    @game = Game.create!(state: "waiting")
    @game.add_player(users(:chris))
    @game.add_player(users(:paula))
    @game.start
    @game.reload
    @game.instantiate

    @player = @game.current_player
    @player.update!(tiles: [ { "klass" => "FarmTile", "from" => "[3, 4]", "used" => false } ])
    @game.reload
  end

  def turn = Turn.from_game(@game)

  test "from_game with no sub_phase yields a turn with no sub_phase" do
    assert_nil turn.sub_phase
    assert_equal @player.order, turn.player_order
  end

  test "select_action(:farm) emits SubPhasePushed with TileBuildPhase state" do
    consequences = turn.handle(:select_action, game: @game, tile: :farm)

    assert_equal 1, consequences.size
    pushed = consequences.first
    assert_kind_of Turn::Consequences::SubPhasePushed, pushed
    assert_equal Turn::SubPhases::TileBuildPhase::TYPE, pushed.phase_type
    assert_equal "G", pushed.state["restricted_terrain"]
    assert_equal "FarmTile", pushed.state["tile_klass"]
    assert_equal "[3, 4]", pushed.state["tile_source"]
  end

  test "select_action(:farm) with no Farm tile returns Error" do
    @player.update!(tiles: [])
    @game.reload
    consequences = turn.handle(:select_action, game: @game, tile: :farm)
    assert_kind_of Turn::Consequences::Error, consequences.first
  end

  test "select_action(:farm) when Farm already used returns Error" do
    @player.update!(tiles: [ { "klass" => "FarmTile", "from" => "[3, 4]", "used" => true } ])
    @game.reload
    consequences = turn.handle(:select_action, game: @game, tile: :farm)
    assert_kind_of Turn::Consequences::Error, consequences.first
  end

  test "select_action when sub_phase already active returns Error" do
    @game.current_action = {
      "turn" => {
        "sub_phase" => {
          "type" => Turn::SubPhases::TileBuildPhase::TYPE,
          "state" => { "restricted_terrain" => "G", "tile_klass" => "FarmTile", "tile_source" => "[3, 4]" }
        }
      }
    }
    consequences = turn.handle(:select_action, game: @game, tile: :farm)
    assert_kind_of Turn::Consequences::Error, consequences.first
  end

  test "build delegates to active sub_phase and appends SubPhasePopped on completion" do
    @game.current_action = {
      "turn" => {
        "sub_phase" => {
          "type" => Turn::SubPhases::TileBuildPhase::TYPE,
          "state" => { "restricted_terrain" => "G", "tile_klass" => "FarmTile", "tile_source" => "[3, 4]" }
        }
      }
    }
    row, col = first_empty_grass
    consequences = turn.handle(:build, game: @game, row:, col:)

    assert(consequences.any? { |c| c.is_a?(Turn::Consequences::SettlementPlaced) })
    assert(consequences.any? { |c| c.is_a?(Turn::Consequences::TileConsumed) })
    assert_kind_of Turn::Consequences::SubPhasePopped, consequences.last
    assert_equal Turn::SubPhases::TileBuildPhase::TYPE, consequences.last.prior_state["type"]
    assert_equal "G", consequences.last.prior_state.dig("state", "restricted_terrain")
  end

  test "from_game defaults mandatory_remaining to 3 when current_action is empty" do
    @game.current_action = {}
    assert_equal 3, Turn.from_game(@game).mandatory_remaining
  end

  test "from_game reads mandatory_remaining from current_action.turn" do
    @game.current_action = { "turn" => { "mandatory_remaining" => 1 } }
    assert_equal 1, Turn.from_game(@game).mandatory_remaining
  end

  test "build with no sub_phase emits SettlementPlaced + MandatoryRemainingDecremented" do
    row, col = first_empty_terrain(@player.hand.first)
    cs = turn.handle(:build, game: @game, row: row, col: col)
    assert(cs.any? { |c| c.is_a?(Turn::Consequences::SettlementPlaced) })
    assert(cs.any? { |c| c.is_a?(Turn::Consequences::MandatoryRemainingDecremented) })
    refute(cs.any? { |c| c.is_a?(Turn::Consequences::Error) })
  end

  test "build errors when mandatory_remaining is 0" do
    @game.current_action = { "turn" => { "mandatory_remaining" => 0 } }
    row, col = first_empty_terrain(@player.hand.first)
    cs = turn.handle(:build, game: @game, row: row, col: col)
    assert_kind_of Turn::Consequences::Error, cs.first
  end

  test "build errors when terrain does not match player hand" do
    hand_terrain = @player.hand.first
    row, col = first_empty_terrain_other_than(hand_terrain)
    cs = turn.handle(:build, game: @game, row: row, col: col)
    assert_kind_of Turn::Consequences::Error, cs.first
  end

  test "build errors when target is not adjacency-valid" do
    hand_terrain = @player.hand.first
    seed = first_empty_terrain(hand_terrain)
    @game.board_contents.place_settlement(seed[0], seed[1], 0)
    @game.save!
    @game.reload
    @game.instantiate

    far = first_empty_terrain_not_adjacent_to(seed, hand_terrain)
    cs = turn.handle(:build, game: @game, row: far[0], col: far[1])
    assert_kind_of Turn::Consequences::Error, cs.first
  end

  test "build that errors does not append SubPhasePopped" do
    @game.current_action = {
      "turn" => {
        "sub_phase" => {
          "type" => Turn::SubPhases::TileBuildPhase::TYPE,
          "state" => { "restricted_terrain" => "G", "tile_klass" => "FarmTile", "tile_source" => "[3, 4]" }
        }
      }
    }
    consequences = turn.handle(:build, game: @game, row: 0, col: 0) # likely not Grass
    assert_kind_of Turn::Consequences::Error, consequences.first
    refute(consequences.any? { |c| c.is_a?(Turn::Consequences::SubPhasePopped) })
  end

  test "unsupported action returns Error" do
    consequences = turn.handle(:nonsense, game: @game)
    assert_kind_of Turn::Consequences::Error, consequences.first
  end

  private

  def first_empty_grass
    first_empty_terrain("G")
  end

  def first_empty_terrain(terrain)
    20.times do |row|
      20.times do |col|
        next unless @game.board.terrain_at(row, col) == terrain
        return [ row, col ] if @game.board_contents.empty?(row, col)
      end
    end
    raise "no empty #{terrain} hex"
  end

  def first_empty_terrain_other_than(terrain)
    20.times do |row|
      20.times do |col|
        t = @game.board.terrain_at(row, col)
        next if t.nil? || t == terrain
        return [ row, col ] if @game.board_contents.empty?(row, col)
      end
    end
    raise "no empty non-#{terrain} hex"
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
