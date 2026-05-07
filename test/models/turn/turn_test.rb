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

  test "build with no active sub_phase returns Error" do
    consequences = turn.handle(:build, game: @game, row: 0, col: 0)
    assert_kind_of Turn::Consequences::Error, consequences.first
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
    20.times do |row|
      20.times do |col|
        next unless @game.board.terrain_at(row, col) == "G"
        return [ row, col ] if @game.board_contents.empty?(row, col)
      end
    end
    raise "no empty grass hex"
  end
end
