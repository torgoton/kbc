require "test_helper"

class TurnRoundTripTest < ActiveSupport::TestCase
  def setup
    @game = Game.create!(state: "waiting")
    @game.add_player(users(:chris))
    @game.add_player(users(:paula))
    @game.start
    @game.reload
    @game.instantiate

    @player = @game.current_player
    @player.update!(tiles: [ { "klass" => "FarmTile", "from" => "[3, 4]", "used" => false } ])
    @game.board_contents.place_tile(3, 4, "FarmTile", 1)
    @game.save!
  end

  def snapshot
    @game.reload
    {
      board_contents: BoardState.dump(@game.board_contents),
      current_action: @game.current_action.deep_dup,
      players: @game.game_players.map { |g|
        g.reload
        {
          order: g.order,
          supply: g.settlements_remaining,
          tiles: g.tiles&.deep_dup,
          taken_from: g.taken_from&.dup
        }
      }
    }
  end

  test "select_action then build round-trips back to the starting snapshot" do
    before = snapshot

    turn = Turn.from_game(@game)
    cs1 = turn.handle(:select_action, game: @game, tile: "FarmTile")
    ConsequenceApplier.apply!(@game, cs1)

    @game.reload
    @game.instantiate
    turn = Turn.from_game(@game)
    row, col = first_empty_grass
    cs2 = turn.handle(:build, game: @game, row: row, col: col)
    ConsequenceApplier.apply!(@game, cs2)

    ConsequenceApplier.unapply!(@game.reload)
    ConsequenceApplier.unapply!(@game.reload)

    assert_equal before, snapshot
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
